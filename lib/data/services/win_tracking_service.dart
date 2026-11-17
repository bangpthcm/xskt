// lib/data/services/win_tracking_service.dart

import '../models/cycle_win_history.dart';
import 'google_sheets_service.dart';

class WinTrackingService {
  final GoogleSheetsService _sheetsService;

  WinTrackingService({required GoogleSheetsService sheetsService})
      : _sheetsService = sheetsService;

  GoogleSheetsService get sheetsService => _sheetsService;

  // ============================================
  // READ-ONLY METHODS (Giữ lại để xem lịch sử)
  // ============================================
}
