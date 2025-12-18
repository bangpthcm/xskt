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

  /// Lấy lịch sử Win của loại Tất cả (Cycle)
  Future<List<CycleWinHistory>> getAllWinHistoryCycle() async {
    return getAllCycleWinHistory();
  }

  /// Lấy lịch sử Win của loại Nam
  Future<List<CycleWinHistory>> getAllWinHistoryNam() async {
    print('📚 Loading Nam win history...');

    try {
      final values = await _sheetsService.getAllValues('namWinHistory');

      if (values.length < 2) {
        print('   ⚠️ Nam win history is empty');
        return [];
      }

      final histories = <CycleWinHistory>[];
      for (int i = 1; i < values.length; i++) {
        try {
          histories.add(CycleWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing Nam row $i: $e');
        }
      }

      print('   ✅ Loaded ${histories.length} Nam win records');
      return histories;
    } catch (e) {
      print('❌ Error loading Nam win history: $e');
      return [];
    }
  }

  /// Lấy lịch sử Win của loại Trung
  Future<List<CycleWinHistory>> getAllWinHistoryTrung() async {
    print('📚 Loading Trung win history...');

    try {
      final values = await _sheetsService.getAllValues('trungWinHistory');

      if (values.length < 2) {
        print('   ⚠️ Trung win history is empty');
        return [];
      }

      final histories = <CycleWinHistory>[];
      for (int i = 1; i < values.length; i++) {
        try {
          histories.add(CycleWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing Trung row $i: $e');
        }
      }

      print('   ✅ Loaded ${histories.length} Trung win records');
      return histories;
    } catch (e) {
      print('❌ Error loading Trung win history: $e');
      return [];
    }
  }

  /// Lấy lịch sử Win của loại Bắc
  Future<List<CycleWinHistory>> getAllWinHistoryBac() async {
    print('📚 Loading Bac win history...');

    try {
      final values = await _sheetsService.getAllValues('bacWinHistory');

      if (values.length < 2) {
        print('   ⚠️ Bac win history is empty');
        return [];
      }

      final histories = <CycleWinHistory>[];
      for (int i = 1; i < values.length; i++) {
        try {
          histories.add(CycleWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing Bac row $i: $e');
        }
      }

      print('   ✅ Loaded ${histories.length} Bac win records');
      return histories;
    } catch (e) {
      print('❌ Error loading Bac win history: $e');
      return [];
    }
  }

  /// Load tất cả 4 loại lịch sử song song (Rebetting use)
  Future<Map<String, List<CycleWinHistory>>>
      getAllWinHistoriesParallel() async {
    print('🔄 Loading all win histories in parallel...');

    try {
      final results = await Future.wait([
        getAllWinHistoryCycle(), // Tất cả
        getAllWinHistoryNam(), // Nam
        getAllWinHistoryTrung(), // Trung
        getAllWinHistoryBac(), // Bắc
      ]);

      return {
        'tatCa': results[0],
        'nam': results[1],
        'trung': results[2],
        'bac': results[3],
      };
    } catch (e) {
      print('❌ Error loading all win histories: $e');
      return {
        'tatCa': [],
        'nam': [],
        'trung': [],
        'bac': [],
      };
    }
  }
}
