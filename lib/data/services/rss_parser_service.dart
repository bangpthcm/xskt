import 'package:dio/dio.dart'; // ✅ Thay thế http
import 'package:xml/xml.dart';
import '../models/lottery_result.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/number_utils.dart';

class RssParserService {
  final Dio _dio = Dio(); // ✅ Khởi tạo Dio

  static const Map<String, String> _rssSources = {
    "Nam": "http://xskt.me/rssfeed/xsmn.rss",
    "Trung": "http://xskt.me/rssfeed/xsmt.rss",
    "Bắc": "http://xskt.me/rssfeed/xsmb.rss",
  };

  Future<Map<String, XmlDocument?>> fetchAllFeeds() async {
    final results = <String, XmlDocument?>{};
    
    for (final entry in _rssSources.entries) {
      try {
        // ✅ Dùng Dio get
        final response = await _dio.get(
          entry.value,
          options: Options(
            headers: {'Accept': 'application/xml'},
            responseType: ResponseType.plain, // ✅ Quan trọng: Lấy text thô để XML parse
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
        
        if (response.statusCode == 200) {
          results[entry.key] = XmlDocument.parse(response.data.toString());
        } else {
          results[entry.key] = null;
        }
      } catch (e) {
        print('Error fetching RSS for ${entry.key}: $e');
        results[entry.key] = null;
      }
    }
    
    return results;
  }

  Future<List<LotteryResult>> parseRSS(String url, String mien) async {
    try {
      print('📡 Fetching RSS from: $url');
      
      // ✅ Dùng Dio
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/xml'},
          responseType: ResponseType.plain, // Lấy dữ liệu dạng chuỗi
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final xml = XmlDocument.parse(response.data.toString());
      final results = <LotteryResult>[];
      final items = xml.findAllElements('item');
      
      print('   Found ${items.length} items in RSS');

      for (final item in items) {
        final linkElement = item.findElements('link').firstOrNull;
        final descriptionElement = item.findElements('description').firstOrNull;
        
        if (linkElement == null || descriptionElement == null) continue;
        
        final linkText = linkElement.innerText;
        final description = descriptionElement.innerText;
        
        final rawDateStr = date_utils.DateUtils.getDateFromRssLink(linkText);
        if (rawDateStr == null) continue;
        
        final dateStr = _formatDateWith2Digits(rawDateStr);
        final provincesData = _parseProvincesData(description, mien);
        
        for (final entry in provincesData.entries) {
          final tinh = entry.key;
          final numbers = NumberUtils.processResultString(entry.value);
          
          if (numbers.isNotEmpty) {
            results.add(LotteryResult(
              ngay: dateStr,
              mien: mien,
              tinh: tinh,
              numbers: numbers,
            ));
          }
        }
      }
      return results;

    } catch (e) {
      print('❌ Error parsing RSS: $e');
      return [];
    }
  }

  List<LotteryResult> parseRssToResults(
    XmlDocument xml,
    String mien,
    String targetDate,
  ) {
    final results = <LotteryResult>[];
    final items = xml.findAllElements('item');
    
    for (final item in items) {
      final linkElement = item.findElements('link').firstOrNull;
      final descriptionElement = item.findElements('description').firstOrNull;
      
      if (linkElement == null || descriptionElement == null) continue;
      
      final linkText = linkElement.innerText;
      final description = descriptionElement.innerText;
      
      final rawDateStr = date_utils.DateUtils.getDateFromRssLink(linkText);
      if (rawDateStr == null) continue;
      
      // ✅ FIX: Format lại với 2 chữ số
      final dateStr = _formatDateWith2Digits(rawDateStr);
      
      if (dateStr != targetDate) continue;
      
      final provincesData = _parseProvincesData(description, mien);
      
      for (final entry in provincesData.entries) {
        final tinh = entry.key;
        final numbers = NumberUtils.processResultString(entry.value);
        
        if (numbers.isNotEmpty) {
          results.add(LotteryResult(
            ngay: dateStr,
            mien: mien,
            tinh: tinh,
            numbers: numbers,
          ));
        }
      }
    }
    
    return results;
  }

  Map<String, String> _parseProvincesData(String description, String mien) {
    final data = <String, String>{};
    
    if (mien == "Bắc") {
      data["Miền Bắc"] = description;
    } else {
      final regex = RegExp(r'\[([^\]]+)\]\s*([^\[]+)');
      final matches = regex.allMatches(description);
      
      for (final match in matches) {
        final tinh = match.group(1)!.trim();
        final ketQua = match.group(2)!.trim();
        data[tinh] = ketQua;
      }
    }
    
    return data;
  }

  // ✅ NEW METHOD: Format ngày với 2 chữ số
  String _formatDateWith2Digits(String rawDate) {
    // Input: "4/11/2025" hoặc "04/11/2025"
    // Output: "04/11/2025" (luôn 2 chữ số)
    
    try {
      final parts = rawDate.split('/');
      if (parts.length != 3) return rawDate; // Giữ nguyên nếu format lạ
      
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      
      // Format lại với 2 chữ số cho ngày và tháng
      return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
      
    } catch (e) {
      print('   ⚠️ Error formatting date "$rawDate": $e');
      return rawDate; // Fallback: giữ nguyên
    }
  }
}