import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/lottery_result.dart';
import '../../core/utils/date_utils.dart' as date_utils;  // ← Đảm bảo đúng
import '../../core/utils/number_utils.dart';  // ← Đảm bảo đúng

class RssParserService {
  static const Map<String, String> _rssSources = {
    "Nam": "http://xskt.me/rssfeed/xsmn.rss",
    "Trung": "http://xskt.me/rssfeed/xsmt.rss",
    "Bắc": "http://xskt.me/rssfeed/xsmb.rss",
  };

  Future<Map<String, XmlDocument?>> fetchAllFeeds() async {
    final results = <String, XmlDocument?>{};
    
    for (final entry in _rssSources.entries) {
      try {
        final response = await http.get(
          Uri.parse(entry.value),
          headers: {'Accept': 'application/xml'},
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          results[entry.key] = XmlDocument.parse(response.body);
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
      
      final linkText = linkElement.text;
      final description = descriptionElement.text;
      
      final dateStr = date_utils.DateUtils.getDateFromRssLink(linkText);
      
      if (dateStr != targetDate) continue;
      
      // Parse provinces data
      final provincesData = _parseProvincesData(description, mien);
      
      for (final entry in provincesData.entries) {
        final tinh = entry.key;
        final numbers = NumberUtils.processResultString(entry.value);
        
        if (numbers.isNotEmpty) {
          results.add(LotteryResult(
            ngay: dateStr!,
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
      // Miền Bắc không có phân tỉnh
      data["Miền Bắc"] = description;
    } else {
      // Miền Nam và Trung có format [Tỉnh] Kết quả
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
}