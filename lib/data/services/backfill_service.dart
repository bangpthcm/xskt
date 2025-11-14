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

  /// ✅ OPTIMIZED: Đồng bộ tất cả dữ liệu từ RSS vào Google Sheet
  /// Sử dụng batch operations để giảm API calls
  Future<BackfillResult> syncAllFromRSS() async {
    try {
      print('📄 Starting RSS backfill with batch optimization...');

      // ✅ 1. Lấy dữ liệu hiện có trong sheet (1 API call)
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

      // ✅ 2. Lấy dữ liệu từ RSS theo thứ tự Nam -> Trung -> Bắc
      // Sử dụng parallel fetching để tăng tốc
      final allRssResults = <LotteryResult>[];
      
      print('🌐 Fetching RSS from all regions in parallel...');
      final rssFutures = AppConstants.mienOrder.map((mien) async {
        print('  📡 Fetching Miền $mien...');
        final rssUrl = AppConstants.rssSources[mien]!;
        final results = await _rssService.parseRSS(rssUrl, mien);
        print('  ✓ Miền $mien: ${results.length} results');
        return results;
      });
      
      final rssResultsList = await Future.wait(rssFutures);
      for (final results in rssResultsList) {
        allRssResults.addAll(results);
      }

      print('🔥 Total RSS results: ${allRssResults.length}');

      // ✅ 3. Lọc ra những kết quả mới (chưa có trong sheet)
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

      // ✅ 4. Nếu không có dữ liệu mới, return sớm
      if (newResults.isEmpty) {
        print('✅ No new data to sync');
        return BackfillResult(
          totalFetched: allRssResults.length,
          newAdded: 0,
          message: 'Không có dữ liệu mới',
        );
      }

      // ✅ 5. Sắp xếp theo ngày (cũ -> mới)
      newResults.sort((a, b) {
        final dateA = date_utils.DateUtils.parseDate(a.ngay);
        final dateB = date_utils.DateUtils.parseDate(b.ngay);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      // ✅ 6. Thêm header nếu sheet trống
      final batchUpdates = <String, BatchUpdateData>{};
      
      if (existingData.isEmpty) {
        batchUpdates['KQXS'] = BatchUpdateData(
          range: 'A1:D1',
          values: [
            ['ngay', 'mien', 'tinh', 'ket_qua']
          ],
        );
      }

      // ✅ 7. Thêm dữ liệu mới vào sheet
      // Sử dụng appendRows để tự động mở rộng sheet
      final newRows = newResults.map((r) => r.toSheetRow()).toList();
      
      // ✅ Nếu có header cần thêm, dùng batch update
      if (batchUpdates.isNotEmpty) {
        await _sheetsService.batchUpdateRanges(batchUpdates);
        print('✅ Header added');
      }
      
      // ✅ Append rows (1 API call)
      await _sheetsService.appendRows('KQXS', newRows);

      // ✅ Clear cache để đảm bảo dữ liệu mới được đọc
      _sheetsService.clearBatchCache();

      print('✅ Backfill completed successfully!');
      print('   Added ${newResults.length} new results');
      print('   API calls saved: ${AppConstants.mienOrder.length - 1} (parallel fetch)');

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

  /// ✅ OPTIMIZED: Đồng bộ dữ liệu của một miền cụ thể
  Future<BackfillResult> syncByMien(String mien) async {
    try {
      print('📄 Syncing Miền $mien with optimization...');

      // ✅ 1. Lấy dữ liệu hiện có (1 API call)
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
            // Skip invalid rows
          }
        }
      }

      print('📊 Found ${existingResults.length} existing results for Miền $mien');

      // ✅ 2. Fetch RSS cho miền cụ thể
      final rssUrl = AppConstants.rssSources[mien]!;
      final rssResults = await _rssService.parseRSS(rssUrl, mien);

      print('🔥 Fetched ${rssResults.length} results from RSS');

      // ✅ 3. Lọc kết quả mới
      final newResults = rssResults.where((rssResult) {
        return !existingResults.any((existing) {
          return existing.ngay == rssResult.ngay &&
                 existing.mien == rssResult.mien &&
                 existing.tinh == rssResult.tinh;
        });
      }).toList();

      print('✨ New results to add: ${newResults.length}');

      if (newResults.isEmpty) {
        return BackfillResult(
          totalFetched: rssResults.length,
          newAdded: 0,
          message: 'Không có dữ liệu mới cho Miền $mien',
        );
      }

      // ✅ 4. Sắp xếp theo ngày
      newResults.sort((a, b) {
        final dateA = date_utils.DateUtils.parseDate(a.ngay);
        final dateB = date_utils.DateUtils.parseDate(b.ngay);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      // ✅ 5. Append rows (1 API call)
      final newRows = newResults.map((r) => r.toSheetRow()).toList();
      await _sheetsService.appendRows('KQXS', newRows);

      // ✅ Clear cache
      _sheetsService.clearBatchCache();

      print('✅ Sync completed for Miền $mien');
      print('   Added ${newResults.length} new results');

      return BackfillResult(
        totalFetched: rssResults.length,
        newAdded: newResults.length,
        message: 'Đã thêm ${newResults.length} kết quả mới cho Miền $mien',
      );

    } catch (e) {
      print('❌ Sync error for Miền $mien: $e');
      return BackfillResult(
        totalFetched: 0,
        newAdded: 0,
        message: 'Lỗi đồng bộ Miền $mien: $e',
        hasError: true,
      );
    }
  }

  /// ✅ NEW: Đồng bộ nhiều miền cùng lúc (batch optimization)
  Future<Map<String, BackfillResult>> syncMultipleMien(
    List<String> mienList,
  ) async {
    try {
      print('📄 Batch syncing ${mienList.length} regions...');

      // ✅ 1. Lấy tất cả dữ liệu hiện có một lần
      final existingData = await _sheetsService.getAllValues('KQXS');
      final existingByMien = <String, List<LotteryResult>>{};
      
      // Group existing data by mien
      for (final mien in mienList) {
        existingByMien[mien] = [];
      }
      
      if (existingData.length > 1) {
        for (int i = 1; i < existingData.length; i++) {
          try {
            final result = LotteryResult.fromSheetRow(existingData[i]);
            if (mienList.contains(result.mien)) {
              existingByMien[result.mien]?.add(result);
            }
          } catch (e) {
            // Skip
          }
        }
      }

      // ✅ 2. Fetch RSS từ tất cả miền song song
      print('🌐 Fetching RSS from ${mienList.length} regions in parallel...');
      
      final rssFutures = mienList.map((mien) async {
        final rssUrl = AppConstants.rssSources[mien]!;
        final results = await _rssService.parseRSS(rssUrl, mien);
        return MapEntry(mien, results);
      });
      
      final rssResultsMap = Map.fromEntries(await Future.wait(rssFutures));

      // ✅ 3. Tìm kết quả mới cho từng miền
      final allNewResults = <LotteryResult>[];
      final results = <String, BackfillResult>{};
      
      for (final mien in mienList) {
        final rssResults = rssResultsMap[mien] ?? [];
        final existingResults = existingByMien[mien] ?? [];
        
        final newResults = rssResults.where((rssResult) {
          return !existingResults.any((existing) {
            return existing.ngay == rssResult.ngay &&
                   existing.mien == rssResult.mien &&
                   existing.tinh == rssResult.tinh;
          });
        }).toList();
        
        allNewResults.addAll(newResults);
        
        results[mien] = BackfillResult(
          totalFetched: rssResults.length,
          newAdded: newResults.length,
          message: newResults.isEmpty
              ? 'Không có dữ liệu mới'
              : 'Đã thêm ${newResults.length} kết quả',
        );
      }

      // ✅ 4. Nếu có dữ liệu mới, append tất cả cùng lúc
      if (allNewResults.isNotEmpty) {
        // Sort by date
        allNewResults.sort((a, b) {
          final dateA = date_utils.DateUtils.parseDate(a.ngay);
          final dateB = date_utils.DateUtils.parseDate(b.ngay);
          if (dateA == null || dateB == null) return 0;
          return dateA.compareTo(dateB);
        });
        
        final newRows = allNewResults.map((r) => r.toSheetRow()).toList();
        await _sheetsService.appendRows('KQXS', newRows);
        
        _sheetsService.clearBatchCache();
        
        print('✅ Batch sync completed!');
        print('   Total new results: ${allNewResults.length}');
        print('   API calls: 1 read + ${mienList.length} RSS + 1 write');
      } else {
        print('✅ No new data to sync');
      }

      return results;

    } catch (e) {
      print('❌ Batch sync error: $e');
      return Map.fromEntries(
        mienList.map((mien) => MapEntry(
          mien,
          BackfillResult(
            totalFetched: 0,
            newAdded: 0,
            message: 'Lỗi đồng bộ: $e',
            hasError: true,
          ),
        )),
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