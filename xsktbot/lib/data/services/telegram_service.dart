// lib/data/services/telegram_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/app_config.dart';  // ✅ ADD
import '../models/betting_row.dart';

class TelegramService {
  TelegramConfig? _config;

  void initialize(TelegramConfig config) {
    _config = config;
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

  String formatXienTableMessage(List<BettingRow> table, String capSo, int soNgayGan, String lanCuoiVe) {
    final buffer = StringBuffer();
    buffer.writeln('<b>💰 Bảng Cược Xiên Mới</b>\n');
    buffer.writeln('<b>Cặp:</b> $capSo');
    buffer.writeln('<b>Gan:</b> $soNgayGan ngày');
    buffer.writeln('<b>Lần cuối:</b> $lanCuoiVe\n');
    buffer.writeln('<pre>');

    // Header
    buffer.writeln('Ngày      | Cược      | Tổng      | Lời');
    buffer.writeln('----------|-----------|-----------|----------');

    // Rows
    for (final row in table) {
      final ngay = row.ngay.substring(0, 5); // dd/mm
      final cuoc = _formatNumber(row.cuocMien);
      final tong = _formatNumber(row.tongTien);
      final loi = _formatNumber(row.loi1So);

      buffer.writeln('${ngay.padRight(10)}|${cuoc.padLeft(11)}|${tong.padLeft(11)}|${loi.padLeft(10)}');
    }

    buffer.writeln('</pre>');
    return buffer.toString();
  }

  String formatCycleTableMessage(
    List<BettingRow> table,
    String nhomGan,
    String soMucTieu,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('<b>💰 Bảng Cược Chu Kỳ Mới</b>\n');
    buffer.writeln('<b>Nhóm gan:</b> $nhomGan');
    buffer.writeln('<b>Số mục tiêu:</b> $soMucTieu\n');
    buffer.writeln('<pre>');

    // Header
    buffer.writeln('Ngày      |Miền |Cược/số  |Tổng      |Lời(1số)');
    buffer.writeln('----------|-----|---------|----------|----------');

    // Rows (chỉ hiển thị một số dòng để không quá dài)
    final displayRows = table.length > 20 ? table.take(20).toList() : table;
    
    for (final row in displayRows) {
      final ngay = row.ngay.substring(0, 5);
      final mien = row.mien.padRight(5);
      final cuoc = _formatNumber(row.cuocSo);
      final tong = _formatNumber(row.tongTien);
      final loi = _formatNumber(row.loi1So);

      buffer.writeln('${ngay.padRight(10)}|$mien|${cuoc.padLeft(9)}|${tong.padLeft(10)}|${loi.padLeft(10)}');
    }

    if (table.length > 20) {
      buffer.writeln('... (${table.length - 20} dòng nữa)');
    }

    buffer.writeln('</pre>');
    return buffer.toString();
  }

  String _formatNumber(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}