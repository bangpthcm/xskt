// lib/data/services/backfill_service.dart
import '../models/lottery_result.dart';
import 'google_sheets_service.dart';
import 'rss_parser_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart' as date_utils;

class BackfillService {
  final GoogleSheetsService _sheetsService;
  final RssParserService _rssService;

  BackfillService({
    required GoogleSheetsService sheetsService,
    required RssParserService rssService,
  })  : _sheetsService = sheetsService,
        _rssService = rssService;

  /// Đồng bộ tất cả dữ liệu từ RSS vào Google Sheet
  Future<BackfillResult> syncAllFromRSS() async {
    try {
      print('🔄 Starting RSS backfill...');

      // 1. Lấy dữ liệu hiện có trong sheet
      final existingData = await _sheetsService.getAllValues('KQXS');
      final existingResults = <LotteryResult>[];
      
      if (existingData.length > 1) {
        for (int i = 1; i < existingData.length; i++) {
          try {
            existingResults.add(LotteryResult.fromSheetRow(existingData[i]));
          } catch (e) {
            print('⚠️ Skip invalid row $i: $e');
          }
        }
      }
      
      print('📊 Found ${existingResults.length} existing results in sheet');

      // 2. Lấy dữ liệu từ RSS theo thứ tự Nam -> Trung -> Bắc
      final allRssResults = <LotteryResult>[];
      
      for (final mien in AppConstants.mienOrder) {
        print('🌐 Fetching RSS for Miền $mien...');
        final rssUrl = AppConstants.rssSources[mien]!;
        final rssResults = await _rssService.parseRSS(rssUrl, mien);
        allRssResults.addAll(rssResults);
        print('   Found ${rssResults.length} results');
      }

      print('📥 Total RSS results: ${allRssResults.length}');

      // 3. Lọc ra những kết quả mới (chưa có trong sheet)
      final newResults = <LotteryResult>[];
      
      for (final rssResult in allRssResults) {
        final isDuplicate = existingResults.any((existing) {
          return existing.ngay == rssResult.ngay &&
                 existing.mien == rssResult.mien &&
                 existing.tinh == rssResult.tinh;
        });
        
        if (!isDuplicate) {
          newResults.add(rssResult);
        }
      }

      print('✨ New results to add: ${newResults.length}');

      // 4. Nếu có dữ liệu mới, thêm vào sheet
      if (newResults.isEmpty) {
        print('✅ No new data to sync');
        return BackfillResult(
          totalFetched: allRssResults.length,
          newAdded: 0,
          message: 'Không có dữ liệu mới',
        );
      }

      // Sắp xếp theo ngày (cũ -> mới)
      newResults.sort((a, b) {
        final dateA = date_utils.DateUtils.parseDate(a.ngay);
        final dateB = date_utils.DateUtils.parseDate(b.ngay);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      // 5. Thêm header nếu sheet trống
      if (existingData.isEmpty) {
        await _sheetsService.updateRange(
          'KQXS',
          'A1:D1',
          [
            ['ngay', 'mien', 'tinh', 'ket_qua']
          ],
        );
      }

      // 6. Thêm dữ liệu mới vào sheet
      final startRow = existingData.length + 1;
      final newRows = newResults.map((r) => r.toSheetRow()).toList();
      
      await _sheetsService.updateRange(
        'KQXS',
        'A$startRow',
        newRows,
      );

      print('✅ Backfill completed successfully!');
      print('   Added ${newResults.length} new results');

      return BackfillResult(
        totalFetched: allRssResults.length,
        newAdded: newResults.length,
        message: 'Đã thêm ${newResults.length} kết quả mới',
      );

    } catch (e) {
      print('❌ Backfill error: $e');
      return BackfillResult(
        totalFetched: 0,
        newAdded: 0,
        message: 'Lỗi đồng bộ: $e',
        hasError: true,
      );
    }
  }

  /// Đồng bộ dữ liệu của một miền cụ thể
  Future<BackfillResult> syncByMien(String mien) async {
    try {
      print('🔄 Syncing Miền $mien...');

      final existingData = await _sheetsService.getAllValues('KQXS');
      final existingResults = <LotteryResult>[];
      
      if (existingData.length > 1) {
        for (int i = 1; i < existingData.length; i++) {
          try {
            final result = LotteryResult.fromSheetRow(existingData[i]);
            if (result.mien == mien) {
              existingResults.add(result);
            }
          } catch (e) {
            // Skip
          }
        }
      }

      final rssUrl = AppConstants.rssSources[mien]!;
      final rssResults = await _rssService.parseRSS(rssUrl, mien);

      final newResults = rssResults.where((rssResult) {
        return !existingResults.any((existing) {
          return existing.ngay == rssResult.ngay &&
                 existing.mien == rssResult.mien &&
                 existing.tinh == rssResult.tinh;
        });
      }).toList();

      if (newResults.isEmpty) {
        return BackfillResult(
          totalFetched: rssResults.length,
          newAdded: 0,
          message: 'Không có dữ liệu mới cho Miền $mien',
        );
      }

      newResults.sort((a, b) {
        final dateA = date_utils.DateUtils.parseDate(a.ngay);
        final dateB = date_utils.DateUtils.parseDate(b.ngay);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      final startRow = existingData.length + 1;
      final newRows = newResults.map((r) => r.toSheetRow()).toList();
      
      await _sheetsService.updateRange('KQXS', 'A$startRow', newRows);

      return BackfillResult(
        totalFetched: rssResults.length,
        newAdded: newResults.length,
        message: 'Đã thêm ${newResults.length} kết quả mới cho Miền $mien',
      );

    } catch (e) {
      return BackfillResult(
        totalFetched: 0,
        newAdded: 0,
        message: 'Lỗi đồng bộ Miền $mien: $e',
        hasError: true,
      );
    }
  }
}

class BackfillResult {
  final int totalFetched;
  final int newAdded;
  final String message;
  final bool hasError;

  BackfillResult({
    required this.totalFetched,
    required this.newAdded,
    required this.message,
    this.hasError = false,
  });
}