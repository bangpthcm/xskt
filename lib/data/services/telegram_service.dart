// lib/data/services/telegram_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/app_config.dart';
import '../models/betting_row.dart';

// ✅ Enum loại bảng cược – dùng để chọn đúng topic khi gửi
enum TelegramTableType {
  tatCa, // Chu kỳ tất cả miền  → topic: cycle
  nam, // Chu kỳ miền Nam      → topic: nam
  trung, // Chu kỳ miền Trung    → topic: trung
  bac, // Chu kỳ miền Bắc      → topic: bac
  xien, // Xiên miền Bắc        → topic: xien
}

// ✅ Enum topic – map 1-1 với TelegramTopicConfig
enum TelegramTopic { cycle, xien, nam, trung, bac, error }

class TelegramService {
  TelegramConfig? _config;

  void initialize(TelegramConfig config) {
    _config = config;
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE: Lấy thread_id tương ứng với topic
  // ─────────────────────────────────────────────────────────
  int? _threadId(TelegramTopic topic) {
    final t = _config?.topics;
    if (t == null) return null;
    return switch (topic) {
      TelegramTopic.cycle => t.cycle,
      TelegramTopic.xien => t.xien,
      TelegramTopic.nam => t.nam,
      TelegramTopic.trung => t.trung,
      TelegramTopic.bac => t.bac,
      TelegramTopic.error => t.error,
    };
  }

  // Tự động chọn topic từ TelegramTableType
  TelegramTopic _topicFromTableType(TelegramTableType type) {
    return switch (type) {
      TelegramTableType.tatCa => TelegramTopic.cycle,
      TelegramTableType.nam => TelegramTopic.nam,
      TelegramTableType.trung => TelegramTopic.trung,
      TelegramTableType.bac => TelegramTopic.bac,
      TelegramTableType.xien => TelegramTopic.xien,
    };
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC: Test connection
  // ─────────────────────────────────────────────────────────
  Future<bool> testConnection() async {
    if (_config == null || !_config!.isValid) {
      print('❌ Telegram config invalid');
      return false;
    }

    try {
      final url = 'https://api.telegram.org/bot${_config!.botToken}/getMe';
      print('🔄 Testing Telegram connection...');

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          final botInfo = data['result'];
          print('✅ Telegram connected: @${botInfo['username']}');
          return true;
        }
      }
      print('❌ Telegram connection failed: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error testing Telegram connection: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC: Gửi message (có hoặc không có topic)
  // ─────────────────────────────────────────────────────────
  /// [topic] nếu null → gửi vào general chat (không dùng message_thread_id)
  Future<void> sendMessage(String message, {TelegramTopic? topic}) async {
    if (_config == null || !_config!.isValid) {
      throw Exception('Telegram chưa được cấu hình');
    }

    final url = 'https://api.telegram.org/bot${_config!.botToken}/sendMessage';
    final threadId = topic != null ? _threadId(topic) : null;

    for (final chatId in _config!.chatIds) {
      try {
        final body = <String, dynamic>{
          'chat_id': chatId,
          'text': message,
          'parse_mode': 'HTML',
        };

        // ✅ Thêm message_thread_id nếu có topic
        if (threadId != null) {
          body['message_thread_id'] = threadId;
          print('📤 Gửi → chat=$chatId  topic=$topic  thread=$threadId');
        } else {
          print('📤 Gửi → chat=$chatId  (general)');
        }

        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          print('❌ Failed to send to $chatId: ${response.body}');
        }
      } catch (e) {
        print('❌ Error sending to $chatId: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC: Gửi thông báo lỗi vào topic error
  // ─────────────────────────────────────────────────────────
  Future<void> sendError(String errorMessage) async {
    await sendMessage(
      '⚠️ <b>LỖI HỆ THỐNG</b>\n\n$errorMessage',
      topic: TelegramTopic.error,
    );
  }

  // ─────────────────────────────────────────────────────────
  // FORMAT: Bảng Xiên
  // ─────────────────────────────────────────────────────────
  String formatXienTableMessage(
      List<BettingRow> table, String capSo, int soNgayGan, String lanCuoiVe) {
    final buffer = StringBuffer();
    buffer.writeln('<b>💎 BẢNG CƯỢC XIÊN BẮC 💎</b>\n');
    buffer.writeln('<b>Cặp:</b> $capSo');
    buffer.writeln('<b>Gan:</b> $soNgayGan ngày');
    buffer.writeln('<b>Lần cuối:</b> $lanCuoiVe\n');
    buffer.writeln('<pre>');
    buffer.writeln('Ngày |Miền | Cược |  Tổng | Lời  ');
    buffer.writeln('-----|-----|------|-------|------');
    for (final row in table) {
      final ngay = row.ngay.substring(0, 5);
      final mien = row.mien.padRight(5);
      final cuoc = _formatNumber(row.cuocMien);
      final tong = _formatNumber(row.tongTien);
      final loi = _formatNumber(row.loi1So);
      buffer.writeln(
          '${ngay.padRight(5)}|$mien|${cuoc.padLeft(6)}|${tong.padLeft(7)}|${loi.padLeft(6)}');
    }
    buffer.writeln('</pre>');
    return buffer.toString();
  }

  // ─────────────────────────────────────────────────────────
  // FORMAT: Bảng Chu kỳ (wrapper cũ – giữ tương thích)
  // ─────────────────────────────────────────────────────────
  String formatCycleTableMessage(
    List<BettingRow> table,
    String nhomGan,
    String soMucTieu,
  ) {
    return formatCycleTableMessageWithType(
        table, nhomGan, soMucTieu, TelegramTableType.tatCa);
  }

  String formatCycleTableMessageWithType(
    List<BettingRow> table,
    String nhomGan,
    String soMucTieu,
    TelegramTableType type,
  ) {
    final buffer = StringBuffer();

    switch (type) {
      case TelegramTableType.tatCa:
        buffer.writeln('<b>💰 BẢNG CƯỢC CHU KỲ (TẤT CẢ) 💰</b>\n');
        break;
      case TelegramTableType.nam:
        buffer.writeln('<b>🌴 BẢNG CƯỢC MIỀN NAM 🌴</b>\n');
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
    buffer.writeln('Ngày |Miền |Cược/s|Tổng   |Lời1số');
    buffer.writeln('-----|-----|------|-------|------');

    final displayRows = table.length > 20 ? table.take(20).toList() : table;

    for (final row in displayRows) {
      final ngay = row.ngay.substring(0, 5);
      final mien = row.mien.padRight(5);
      final cuoc = _formatNumber(row.cuocSo);
      final tong = _formatNumber(row.tongTien);
      final loi = _formatNumber(row.loi1So);
      buffer.writeln(
          '${ngay.padRight(5)}|$mien|${cuoc.padLeft(6)}|${tong.padLeft(7)}|${loi.padLeft(6)}');
    }
    if (table.length > 20) {
      buffer.writeln('... (${table.length - 20} dòng nữa)');
    }
    buffer.writeln('</pre>');
    return buffer.toString();
  }

  // ─────────────────────────────────────────────────────────
  // HELPER: Gửi bảng cược có routing topic tự động
  // ─────────────────────────────────────────────────────────
  /// Dùng hàm này thay vì gọi sendMessage thủ công khi gửi bảng cược.
  Future<void> sendTableMessage(
    String message,
    TelegramTableType tableType,
  ) async {
    final topic = _topicFromTableType(tableType);
    await sendMessage(message, topic: topic);
  }

  String _formatNumber(double value) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value.round());
  }
}
