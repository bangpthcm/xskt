// lib/data/services/win_tracking_service.dart

import '../models/cycle_win_history.dart';
import '../models/xien_win_history.dart';
import 'google_sheets_service.dart';

class WinTrackingService {
  final GoogleSheetsService _sheetsService;

  WinTrackingService({required GoogleSheetsService sheetsService})
      : _sheetsService = sheetsService;

  GoogleSheetsService get sheetsService => _sheetsService;

  // ============================================
  // READ-ONLY METHODS (Giữ lại để xem lịch sử)
  // ============================================

  Future<List<CycleWinHistory>> getAllCycleWinHistory() async {
    print('📚 Loading all cycle win history...');
    
    final values = await _sheetsService.getAllValues('cycleWinHistory');
    
    if (values.length < 2) {
      print('   ⚠️ No cycle win history found');
      return [];
    }
    
    final histories = <CycleWinHistory>[];
    for (int i = 1; i < values.length; i++) {
      try {
        histories.add(CycleWinHistory.fromSheetRow(values[i]));
      } catch (e) {
        print('⚠️ Error parsing cycle win history row $i: $e');
      }
    }
    
    print('   ✅ Loaded ${histories.length} cycle win records');
    return histories;
  }

  Future<List<XienWinHistory>> getAllXienWinHistory() async {
    print('📚 Loading all xien win history...');
    
    final values = await _sheetsService.getAllValues('xienWinHistory');
    
    if (values.length < 2) {
      print('   ⚠️ No xien win history found');
      return [];
    }
    
    final histories = <XienWinHistory>[];
    for (int i = 1; i < values.length; i++) {
      try {
        histories.add(XienWinHistory.fromSheetRow(values[i]));
      } catch (e) {
        print('⚠️ Error parsing xien win history row $i: $e');
      }
    }
    
    print('   ✅ Loaded ${histories.length} xien win records');
    return histories;
  }
}