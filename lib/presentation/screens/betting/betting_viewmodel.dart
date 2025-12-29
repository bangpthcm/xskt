// lib/presentation/screens/betting/betting_viewmodel.dart
import 'package:flutter/material.dart';

import '../../../data/models/betting_row.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/services/telegram_service.dart';

// ✅ CẬP NHẬT ENUM: Thêm nam
enum BettingTableType { xien, cycle, nam, trung, bac }

class BettingViewModel extends ChangeNotifier {
  final GoogleSheetsService _sheetsService;
  final TelegramService _telegramService;

  BettingViewModel({
    required GoogleSheetsService sheetsService,
    required TelegramService telegramService,
  })  : _sheetsService = sheetsService,
        _telegramService = telegramService;

  bool _isLoading = false;
  String? _errorMessage;
  List<BettingRow>? _xienTable;
  List<BettingRow>? _cycleTable;
  List<BettingRow>? _namTable; // ✅ MỚI
  List<BettingRow>? _trungTable;
  List<BettingRow>? _bacTable;
  Map<String, dynamic>? _xienMetadata;
  Map<String, dynamic>? _cycleMetadata;
  Map<String, dynamic>? _namMetadata; // ✅ MỚI
  Map<String, dynamic>? _trungMetadata;
  Map<String, dynamic>? _bacMetadata;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BettingRow>? get xienTable => _xienTable;
  List<BettingRow>? get cycleTable => _cycleTable;
  List<BettingRow>? get namTable => _namTable; // ✅ MỚI
  List<BettingRow>? get trungTable => _trungTable;
  List<BettingRow>? get bacTable => _bacTable;
  Map<String, dynamic>? get xienMetadata => _xienMetadata;
  Map<String, dynamic>? get cycleMetadata => _cycleMetadata;
  Map<String, dynamic>? get namMetadata => _namMetadata; // ✅ MỚI
  Map<String, dynamic>? get trungMetadata => _trungMetadata;
  Map<String, dynamic>? get bacMetadata => _bacMetadata;

  // 1. Getter lấy danh sách cược Chu kỳ hôm nay (đã gộp và sắp xếp)
  List<BettingRow> get todayCycleRows {
    final now = DateTime.now();
    final today =
        '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';

    final rows = <BettingRow>[
      ...cycleTable?.where((r) => r.ngay == today) ?? [],
      ...namTable?.where((r) => r.ngay == today) ?? [], // ✅ MỚI
      ...trungTable?.where((r) => r.ngay == today) ?? [],
      ...bacTable?.where((r) => r.ngay == today) ?? [],
    ];

    rows.sort((a, b) {
      const mienOrder = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
      return (mienOrder[a.mien] ?? 0).compareTo(mienOrder[b.mien] ?? 0);
    });

    return rows;
  }

  // 2. Getter lấy danh sách cược Xiên hôm nay
  List<BettingRow> get todayXienRows {
    final now = DateTime.now();
    final today =
        '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
    return xienTable?.where((r) => r.ngay == today).toList() ?? [];
  }

  /// Parse number từ Google Sheets
  static double _parseSheetNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();

    String str = value.toString().trim();
    if (str.isEmpty) return 0.0;

    int dotCount = '.'.allMatches(str).length;
    int commaCount = ','.allMatches(str).length;

    if (dotCount > 0 && commaCount > 0) {
      str = str.replaceAll('.', '').replaceAll(',', '.');
    } else if (dotCount > 0) {
      if (dotCount > 1) {
        str = str.replaceAll('.', '');
      } else {
        final dotIndex = str.indexOf('.');
        final afterDot = str.length - dotIndex - 1;
        if (afterDot == 3) {
          str = str.replaceAll('.', '');
        }
      }
    } else if (commaCount > 0) {
      if (commaCount > 1) {
        str = str.replaceAll(',', '');
      } else {
        final commaIndex = str.indexOf(',');
        final afterComma = str.length - commaIndex - 1;
        if (afterComma <= 2) {
          str = str.replaceAll(',', '.');
        } else if (afterComma == 3) {
          str = str.replaceAll(',', '');
        }
      }
    }
    str = str.replaceAll(' ', '');
    try {
      return double.parse(str);
    } catch (e) {
      return 0.0;
    }
  }

  static int _parseSheetInt(dynamic value) {
    return _parseSheetNumber(value).round();
  }

  Future<void> loadBettingTables() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load từng bảng song song nhưng notify sau mỗi bảng
      final futures = <Future<void>>[];

      futures.add(_loadXienTable().then((_) => notifyListeners()));
      futures.add(_loadCycleTable().then((_) => notifyListeners()));
      futures.add(_loadNamTable().then((_) => notifyListeners())); // ✅ MỚI
      futures.add(_loadTrungTable().then((_) => notifyListeners()));
      futures.add(_loadBacTable().then((_) => notifyListeners()));

      await Future.wait(futures);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tải bảng cược: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadXienTable() async {
    try {
      final values = await _sheetsService.getAllValues('xienBot');
      if (values.isEmpty || values.length < 4) {
        _xienTable = null;
        _xienMetadata = null;
        return;
      }
      _xienMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_cap_so': values[0].length > 2 ? values[0][2] : '',
        'cap_so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };
      _xienTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 7) continue;
        try {
          _xienTable!.add(BettingRow.forXien(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            cuocMien: _parseSheetNumber(row[4]),
            tongTien: _parseSheetNumber(row[5]),
            loi: _parseSheetNumber(row[6]),
          ));
        } catch (e) {
          print('❌ Error parsing xien row $i: $e');
        }
      }
    } catch (e) {
      print('❌ Error loading xien table: $e');
      _xienTable = null;
    }
  }

  Future<void> _loadCycleTable() async {
    try {
      final values = await _sheetsService.getAllValues('xsktBot1');
      if (values.isEmpty || values.length < 4) {
        _cycleTable = null;
        _cycleMetadata = null;
        return;
      }
      _cycleMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_so_gan': values[0].length > 2 ? values[0][2] : '',
        'so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };
      _cycleTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 10) continue;
        try {
          _cycleTable!.add(BettingRow.forCycle(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            soLo: _parseSheetInt(row[4]),
            cuocSo: _parseSheetNumber(row[5]),
            cuocMien: _parseSheetNumber(row[6]),
            tongTien: _parseSheetNumber(row[7]),
            loi1So: _parseSheetNumber(row[8]),
            loi2So: _parseSheetNumber(row[9]),
          ));
        } catch (e) {
          print('❌ Error parsing cycle row $i: $e');
        }
      }
    } catch (e) {
      print('❌ Error loading cycle table: $e');
      _cycleTable = null;
    }
  }

  // ✅ MỚI: Load bảng Nam (namBot)
  Future<void> _loadNamTable() async {
    try {
      print('🔍 Loading nam table from namBot...');
      final values = await _sheetsService.getAllValues('namBot');

      if (values.isEmpty || values.length < 4) {
        _namTable = null;
        _namMetadata = null;
        return;
      }

      _namMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_so_gan': values[0].length > 2 ? values[0][2] : '',
        'so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };

      _namTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 10) continue;

        try {
          _namTable!.add(BettingRow.forCycle(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            soLo: _parseSheetInt(row[4]),
            cuocSo: _parseSheetNumber(row[5]),
            cuocMien: _parseSheetNumber(row[6]),
            tongTien: _parseSheetNumber(row[7]),
            loi1So: _parseSheetNumber(row[8]),
            loi2So: _parseSheetNumber(row[9]),
          ));
        } catch (e) {
          print('❌ Error parsing nam row $i: $e');
        }
      }
    } catch (e) {
      print('❌ Error loading nam table: $e');
      _namTable = null;
      _namMetadata = null;
    }
  }

  Future<void> _loadTrungTable() async {
    try {
      final values = await _sheetsService.getAllValues('trungBot');
      if (values.isEmpty || values.length < 4) {
        _trungTable = null;
        _trungMetadata = null;
        return;
      }
      _trungMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_so_gan': values[0].length > 2 ? values[0][2] : '',
        'so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };
      _trungTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 10) continue;
        try {
          _trungTable!.add(BettingRow.forCycle(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            soLo: _parseSheetInt(row[4]),
            cuocSo: _parseSheetNumber(row[5]),
            cuocMien: _parseSheetNumber(row[6]),
            tongTien: _parseSheetNumber(row[7]),
            loi1So: _parseSheetNumber(row[8]),
            loi2So: _parseSheetNumber(row[9]),
          ));
        } catch (e) {
          print('❌ Error parsing trung row $i: $e');
        }
      }
    } catch (e) {
      print('❌ Error loading trung table: $e');
      _trungTable = null;
    }
  }

  Future<void> _loadBacTable() async {
    try {
      final values = await _sheetsService.getAllValues('bacBot');
      if (values.isEmpty || values.length < 4) {
        _bacTable = null;
        _bacMetadata = null;
        return;
      }
      _bacMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_so_gan': values[0].length > 2 ? values[0][2] : '',
        'so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };
      _bacTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 10) continue;
        try {
          _bacTable!.add(BettingRow.forCycle(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            soLo: _parseSheetInt(row[4]),
            cuocSo: _parseSheetNumber(row[5]),
            cuocMien: _parseSheetNumber(row[6]),
            tongTien: _parseSheetNumber(row[7]),
            loi1So: _parseSheetNumber(row[8]),
            loi2So: _parseSheetNumber(row[9]),
          ));
        } catch (e) {
          print('❌ Error parsing bac row $i: $e');
        }
      }
    } catch (e) {
      print('❌ Error loading bac table: $e');
      _bacTable = null;
    }
  }

  Future<void> sendToTelegram(BettingTableType type) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (type == BettingTableType.xien) {
        if (_xienTable == null || _xienMetadata == null)
          throw Exception('Chưa có bảng xiên');
        final message = _telegramService.formatXienTableMessage(
          _xienTable!,
          _xienMetadata!['cap_so_muc_tieu'],
          int.parse(_xienMetadata!['so_ngay_gan']),
          _xienMetadata!['lan_cuoi_ve'],
        );
        await _telegramService.sendMessage(message);
      } else if (type == BettingTableType.cycle) {
        if (_cycleTable == null || _cycleMetadata == null)
          throw Exception('Chưa có bảng chu kỳ');
        final message = _telegramService.formatCycleTableMessageWithType(
          _cycleTable!,
          _cycleMetadata!['nhom_so_gan'],
          _cycleMetadata!['so_muc_tieu'],
          TelegramTableType.tatCa,
        );
        await _telegramService.sendMessage(message);
      } else if (type == BettingTableType.nam) {
        // ✅ MỚI
        if (_namTable == null || _namMetadata == null)
          throw Exception('Chưa có bảng Miền Nam');
        final message = _telegramService.formatCycleTableMessageWithType(
          _namTable!,
          _namMetadata!['nhom_so_gan'],
          _namMetadata!['so_muc_tieu'],
          TelegramTableType.nam,
        );
        await _telegramService.sendMessage(message);
      } else if (type == BettingTableType.trung) {
        if (_trungTable == null || _trungMetadata == null)
          throw Exception('Chưa có bảng Miền Trung');
        final message = _telegramService.formatCycleTableMessageWithType(
          _trungTable!,
          _trungMetadata!['nhom_so_gan'],
          _trungMetadata!['so_muc_tieu'],
          TelegramTableType.trung,
        );
        await _telegramService.sendMessage(message);
      } else if (type == BettingTableType.bac) {
        if (_bacTable == null || _bacMetadata == null)
          throw Exception('Chưa có bảng Miền Bắc');
        final message = _telegramService.formatCycleTableMessageWithType(
          _bacTable!,
          _bacMetadata!['nhom_so_gan'],
          _bacMetadata!['so_muc_tieu'],
          TelegramTableType.bac,
        );
        await _telegramService.sendMessage(message);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi gửi Telegram: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTable(BettingTableType type) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (type == BettingTableType.xien) {
        await _sheetsService.clearSheet('xienBot');
        _xienTable = null;
        _xienMetadata = null;
      } else if (type == BettingTableType.cycle) {
        await _sheetsService.clearSheet('xsktBot1');
        _cycleTable = null;
        _cycleMetadata = null;
      } else if (type == BettingTableType.nam) {
        // ✅ MỚI
        await _sheetsService.clearSheet('namBot');
        _namTable = null;
        _namMetadata = null;
      } else if (type == BettingTableType.trung) {
        await _sheetsService.clearSheet('trungBot');
        _trungTable = null;
        _trungMetadata = null;
      } else if (type == BettingTableType.bac) {
        await _sheetsService.clearSheet('bacBot');
        _bacTable = null;
        _bacMetadata = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi xóa bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
