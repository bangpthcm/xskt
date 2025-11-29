// lib/data/services/telegram_service.dart
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/app_config.dart';
import '../models/betting_row.dart';

// ✅ THÊM ENUM ĐỂ PHÂN BIỆT LOẠI BẢNG
enum TelegramTableType {
  tatCa,   // Chu kỳ tất cả miền
  trung,   // Chu kỳ miền Trung
  bac,     // Chu kỳ miền Bắc
  xien,    // Xiên miền Bắc
}

class TelegramService {
  TelegramConfig? _config;

  void initialize(TelegramConfig config) {
    _config = config;
  }

  Future<bool> testConnection() async {
    if (_config == null || !_config!.isValid) {
      print('❌ Telegram config invalid');
      return false;
    }

    try {
      // ✅ Dùng API getMe để kiểm tra bot token
      final url = 'https://api.telegram.org/bot${_config!.botToken}/getMe';
      
      print('🔄 Testing Telegram connection...');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['ok'] == true) {
          final botInfo = data['result'];
          print('✅ Telegram connected successfully!');
          print('   Bot name: ${botInfo['first_name']}');
          print('   Bot username: @${botInfo['username']}');
          return true;
        } else {
          print('❌ Telegram API returned error: ${data['description']}');
          return false;
        }
      } else {
        print('❌ Telegram connection failed: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error testing Telegram connection: $e');
      return false;
    }
  }

  Future<void> sendMessage(String message) async {
    if (_config == null || !_config!.isValid) {
      throw Exception('Telegram chưa được cấu hình');
    }

    final url = 'https://api.telegram.org/bot${_config!.botToken}/sendMessage';

    for (final chatId in _config!.chatIds) {
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chat_id': chatId,
            'text': message,
            'parse_mode': 'HTML',
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          print('Failed to send to $chatId: ${response.body}');
        }
      } catch (e) {
        print('Error sending to $chatId: $e');
      }
    }
  }

  // ✅ FORMAT XIÊN - GIỮ NGUYÊN NHƯNG CẬP NHẬT TIÊU ĐỀ
// ✅ FORMAT XIÊN - ĐÃ SỬA LỖI HIỂN THỊ CỘT MIỀN
  String formatXienTableMessage(List<BettingRow> table, String capSo, int soNgayGan, String lanCuoiVe) {
    final buffer = StringBuffer();
    buffer.writeln('<b>💎 BẢNG CƯỢC XIÊN BẮC 💎</b>\n');
    buffer.writeln('<b>Cặp:</b> $capSo');
    buffer.writeln('<b>Gan:</b> $soNgayGan ngày');
    buffer.writeln('<b>Lần cuối:</b> $lanCuoiVe\n');
    buffer.writeln('<pre>');

    // Header
    buffer.writeln('Ngày |Miền| Cược  |  Tổng | Lời ');
    buffer.writeln('-----|----|-------|-------|------');

    // Rows
    for (final row in table) {
      final ngay = row.ngay.substring(0, 5); // dd/mm
      final mien = row.mien.padRight(5);
      final cuoc = _formatNumber(row.cuocMien);
      final tong = _formatNumber(row.tongTien);
      final loi = _formatNumber(row.loi1So);

      // ✅ Đã thêm biến $mien vào chuỗi in ra
      buffer.writeln('${ngay.padRight(5)}|$mien|${cuoc.padLeft(7)}|${tong.padLeft(7)}|${loi.padLeft(6)}');
    }

    buffer.writeln('</pre>');
    return buffer.toString();
  }

  // ✅ METHOD CŨ - GIỮ ĐỂ BACKWARD COMPATIBLE (DEFAULT = TẤT CẢ)
  String formatCycleTableMessage(
    List<BettingRow> table,
    String nhomGan,
    String soMucTieu,
  ) {
    return formatCycleTableMessageWithType(
      table,
      nhomGan,
      soMucTieu,
      TelegramTableType.tatCa,
    );
  }

  // ✅ METHOD MỚI - NHẬN THÊM TYPE ĐỂ CHỌN TIÊU ĐỀ
  String formatCycleTableMessageWithType(
    List<BettingRow> table,
    String nhomGan,
    String soMucTieu,
    TelegramTableType type,
  ) {
    final buffer = StringBuffer();
    
    // ✅ CHỌN TIÊU ĐỀ THEO TYPE
    switch (type) {
      case TelegramTableType.tatCa:
        buffer.writeln('<b>💰 BẢNG CƯỢC CHU KỲ (TẤT CẢ) 💰</b>\n');
        break;
      case TelegramTableType.trung:
        buffer.writeln('<b>📋 BẢNG CƯỢC MIỀN TRUNG 📋</b>\n');
        break;
      case TelegramTableType.bac:
        buffer.writeln('<b>📊 BẢNG CƯỢC MIỀN BẮC 📊</b>\n');
        break;
      case TelegramTableType.xien:
        buffer.writeln('<b>💎 BẢNG CƯỢC XIÊN BẮC 💎</b>\n');
        break;
    }
    
    buffer.writeln('<b>Nhóm gan:</b> $nhomGan');
    buffer.writeln('<b>Số mục tiêu:</b> $soMucTieu\n');
    buffer.writeln('<pre>');

    // Header
    buffer.writeln('Ngày |Miền |Cược/s|Tổng   |Lời1số');
    buffer.writeln('-----|-----|------|-------|------');

    // Rows (chỉ hiển thị một số dòng để không quá dài)
    final displayRows = table.length > 20 ? table.take(20).toList() : table;
    
    for (final row in displayRows) {
      final ngay = row.ngay.substring(0, 5);
      final mien = row.mien.padRight(5);
      final cuoc = _formatNumber(row.cuocSo);
      final tong = _formatNumber(row.tongTien);
      final loi = _formatNumber(row.loi1So);

      buffer.writeln('${ngay.padRight(5)}|$mien|${cuoc.padLeft(6)}|${tong.padLeft(7)}|${loi.padLeft(6)}');
    }

    if (table.length > 20) {
      buffer.writeln('... (${table.length - 20} dòng nữa)');
    }

    buffer.writeln('</pre>');
    return buffer.toString();
  }

  // ✅ FIX: Hiển thị số đầy đủ với 2 chữ số thập phân, KHÔNG viết tắt
  String _formatNumber(double value) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value.round());
  }
}