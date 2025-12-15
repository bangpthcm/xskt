// lib/data/models/app_config.dart

import 'api_account.dart';
import 'probability_config.dart';

class DurationConfig {
  // 🔵 Hiện tại: Duration cơ bản (Farming)
  final int cycleDuration; // Chu kỳ (default: 10, min: 5)
  final int trungDuration; // Miền Trung (default: 26, min: 14)
  final int bacDuration; // Miền Bắc (default: 43, min: 20)
  final int xienDuration; // Xiên (default: 234, min: 156)

  // ✨ MỚI: Threshold Rebetting
  final int thresholdCycleDuration; // Default: 4
  final int thresholdTrungDuration; // Default: 14
  final int thresholdBacDuration; // Default: 18

  DurationConfig({
    this.cycleDuration = 10,
    this.trungDuration = 26,
    this.bacDuration = 43,
    this.xienDuration = 234,
    // ✨ THÊM
    this.thresholdCycleDuration = 5,
    this.thresholdTrungDuration = 14,
    this.thresholdBacDuration = 16,
  });

  bool get isValid {
    return cycleDuration > 4 &&
        trungDuration > 13 &&
        bacDuration > 19 &&
        xienDuration > 155 &&
        // ✨ THÊM validation cho Threshold
        thresholdCycleDuration > 5 &&
        thresholdTrungDuration > 5 &&
        thresholdBacDuration > 5;
  }

  Map<String, dynamic> toJson() {
    return {
      'cycleDuration': cycleDuration,
      'trungDuration': trungDuration,
      'bacDuration': bacDuration,
      'xienDuration': xienDuration,
      // ✨ THÊM
      'thresholdCycleDuration': thresholdCycleDuration,
      'thresholdTrungDuration': thresholdTrungDuration,
      'thresholdBacDuration': thresholdBacDuration,
    };
  }

  factory DurationConfig.fromJson(Map<String, dynamic> json) {
    return DurationConfig(
      cycleDuration: json['cycleDuration'] ?? 10,
      trungDuration: json['trungDuration'] ?? 26,
      bacDuration: json['bacDuration'] ?? 43,
      xienDuration: json['xienDuration'] ?? 234,
      // ✨ THÊM
      thresholdCycleDuration: json['thresholdCycleDuration'] ?? 4,
      thresholdTrungDuration: json['thresholdTrungDuration'] ?? 14,
      thresholdBacDuration: json['thresholdBacDuration'] ?? 18,
    );
  }

  factory DurationConfig.defaults() {
    return DurationConfig(
      cycleDuration: 10,
      trungDuration: 26,
      bacDuration: 43,
      xienDuration: 234,
      // ✨ THÊM
      thresholdCycleDuration: 4,
      thresholdTrungDuration: 14,
      thresholdBacDuration: 18,
    );
  }

  DurationConfig copyWith({
    int? cycleDuration,
    int? trungDuration,
    int? bacDuration,
    int? xienDuration,
    // ✨ THÊM
    int? thresholdCycleDuration,
    int? thresholdTrungDuration,
    int? thresholdBacDuration,
  }) {
    return DurationConfig(
      cycleDuration: cycleDuration ?? this.cycleDuration,
      trungDuration: trungDuration ?? this.trungDuration,
      bacDuration: bacDuration ?? this.bacDuration,
      xienDuration: xienDuration ?? this.xienDuration,
      // ✨ THÊM
      thresholdCycleDuration:
          thresholdCycleDuration ?? this.thresholdCycleDuration,
      thresholdTrungDuration:
          thresholdTrungDuration ?? this.thresholdTrungDuration,
      thresholdBacDuration: thresholdBacDuration ?? this.thresholdBacDuration,
    );
  }
}

class BettingConfig {
  final String domain;

  BettingConfig({
    this.domain = 'sin88.pro',
  });

  Map<String, dynamic> toJson() {
    return {
      'domain': domain,
    };
  }

  factory BettingConfig.fromJson(Map<String, dynamic> json) {
    return BettingConfig(
      domain: json['domain'] ?? 'sin88.pro',
    );
  }

  factory BettingConfig.empty() {
    return BettingConfig(
      domain: 'sin88.pro',
    );
  }

  BettingConfig copyWith({
    String? domain,
  }) {
    return BettingConfig(
      domain: domain ?? this.domain,
    );
  }
}

class AppConfig {
  final GoogleSheetsConfig googleSheets;
  final TelegramConfig telegram;
  final BudgetConfig budget;
  final DurationConfig duration; // ✅ THÊM
  final ProbabilityConfig probability;
  final List<ApiAccount> apiAccounts;
  final BettingConfig betting;

  AppConfig({
    required this.googleSheets,
    required this.telegram,
    required this.budget,
    DurationConfig? duration, // ✅ THÊM (optional)
    ProbabilityConfig? probability,
    List<ApiAccount>? apiAccounts,
    BettingConfig? betting,
  })  : duration = duration ?? DurationConfig.defaults(), // ✅ THÊM
        probability = probability ?? ProbabilityConfig.defaults(),
        apiAccounts = apiAccounts ?? [],
        betting = betting ?? BettingConfig.empty();

  Map<String, dynamic> toJson() {
    return {
      'googleSheets': googleSheets.toJson(),
      'telegram': telegram.toJson(),
      'budget': budget.toJson(),
      'duration': duration.toJson(), // ✅ THÊM
      'probability': probability.toJson(),
      'apiAccounts': apiAccounts.map((a) => a.toJson()).toList(),
      'betting': betting.toJson(),
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      googleSheets: GoogleSheetsConfig.fromJson(json['googleSheets'] ?? {}),
      telegram: TelegramConfig.fromJson(json['telegram'] ?? {}),
      budget: BudgetConfig.fromJson(json['budget'] ?? {}),
      duration: DurationConfig.fromJson(json['duration'] ?? {}), // ✅ THÊM
      probability: ProbabilityConfig.fromJson(json['probability'] ?? {}),
      apiAccounts: (json['apiAccounts'] as List<dynamic>?)
              ?.map((item) => ApiAccount.fromJson(item))
              .toList() ??
          [],
      betting: BettingConfig.fromJson(json['betting'] ?? {}),
    );
  }

  factory AppConfig.defaultConfig() {
    return AppConfig(
      googleSheets: GoogleSheetsConfig.withHardcodedCredentials(
        sheetName: '1P7SitHUhauI8-4E-LxykqDERrQN6c-Dgx9UGnbGvVbs',
      ),
      telegram: TelegramConfig.empty(),
      budget: BudgetConfig.defaultBudget(),
      duration: DurationConfig.defaults(), // ✅ Giữ nguyên, defaults() đã update
      probability: ProbabilityConfig.defaults(),
      apiAccounts: [],
      betting: BettingConfig.empty(),
    );
  }

  AppConfig copyWith({
    GoogleSheetsConfig? googleSheets,
    TelegramConfig? telegram,
    BudgetConfig? budget,
    DurationConfig? duration, // ✅ THÊM
    ProbabilityConfig? probability,
    List<ApiAccount>? apiAccounts,
    BettingConfig? betting,
  }) {
    return AppConfig(
      googleSheets: googleSheets ?? this.googleSheets,
      telegram: telegram ?? this.telegram,
      budget: budget ?? this.budget,
      duration: duration ?? this.duration, // ✅ THÊM
      probability: probability ?? this.probability,
      apiAccounts: apiAccounts ?? this.apiAccounts,
      betting: betting ?? this.betting,
    );
  }
}

class GoogleSheetsConfig {
  final String projectId;
  final String privateKeyId;
  final String privateKey;
  final String clientEmail;
  final String clientId;
  final String sheetName;
  final String worksheetName;

  GoogleSheetsConfig({
    required this.projectId,
    required this.privateKeyId,
    required this.privateKey,
    required this.clientEmail,
    required this.clientId,
    required this.sheetName,
    required this.worksheetName,
  });

  bool get isValid =>
      projectId.isNotEmpty &&
      privateKey.isNotEmpty &&
      clientEmail.isNotEmpty &&
      clientId.isNotEmpty &&
      sheetName.isNotEmpty &&
      worksheetName.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'sheetName': sheetName,
    };
  }

  factory GoogleSheetsConfig.fromJson(Map<String, dynamic> json) {
    return GoogleSheetsConfig(
      projectId: _defaultProjectId,
      privateKeyId: _defaultPrivateKeyId,
      privateKey: _defaultPrivateKey,
      clientEmail: _defaultClientEmail,
      clientId: _defaultClientId,
      sheetName: json['sheetName'] ?? _defaultSheetName,
      worksheetName: _defaultWorksheetName,
    );
  }

  factory GoogleSheetsConfig.withHardcodedCredentials({
    required String sheetName,
  }) {
    return GoogleSheetsConfig(
      projectId: _defaultProjectId,
      privateKeyId: _defaultPrivateKeyId,
      privateKey: _defaultPrivateKey,
      clientEmail: _defaultClientEmail,
      clientId: _defaultClientId,
      sheetName: sheetName,
      worksheetName: _defaultWorksheetName,
    );
  }

  factory GoogleSheetsConfig.empty() {
    return GoogleSheetsConfig(
      projectId: _defaultProjectId,
      privateKeyId: _defaultPrivateKeyId,
      privateKey: _defaultPrivateKey,
      clientEmail: _defaultClientEmail,
      clientId: _defaultClientId,
      sheetName: '',
      worksheetName: _defaultWorksheetName,
    );
  }

  static const String _defaultProjectId = "fresh-heuristic-469212-h6";
  static const String _defaultPrivateKeyId =
      "cf577e77874a18e644093da3a81dcfe53b49796e";
  static const String _defaultPrivateKey = "-----BEGIN PRIVATE KEY-----\n"
      "MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQClGOjZt6bmTqxX\n"
      "DdpT3MQ/4ulQafPnUgO7eGxUKGmszAXpY4AdFOd5wHFjVM99v3AvRRHXwMZfzisg\n"
      "NfxoJpcWWkPKevwzEd5NLDhCTaGB+w0kv72kjeu5/I7PqAMWiak3uhHMRGvEJpMK\n"
      "fVkN0qAQDzOEMIvqzpM9KYtGrZtnhrb5ShEUKdqxC60KuGBguGnky8pzCbyXuwA9\n"
      "7IZ40suZaLLTBf9a5SoGtaka2TcwvlvgjJFqrx1N710+gZV0MKWhK/QnMk6OTp7Q\n"
      "uDBvYzx4ULciRAAQkwY8O5CY0f3+gYHxNk1iBIE0kTIlO6DWmbWLkUVt5trn2pN6\n"
      "nWFeVhIFAgMBAAECggEABqoWQC+jK5nSaCM1hHwdaezJeUcFovlTED7AtLb66RBF\n"
      "TtIG6mWdIHONwDI8u/k92JKjsT9lYpmqcP7s5PFl2O+k2+gSBSe7/waBcN+8XMhb\n"
      "E/gvehSGhvf0ddp04XSGIas/q6y5Yu4hsmMz9JRjhLJwZG4nP7+9/tKN/jjk1I1x\n"
      "eEv+7j6az1SojLMnmHAk2yNrKbbdMGnXSCjSuEeVs/ERmt0cT1N2LlJBiJQsrPyI\n"
      "Wb2FMM4ZwFV+OtNDq8dgM/uHHPGCwiSEfQ4F4iGQ3drhAJ5ojlwKhetofHhBjJyI\n"
      "8EnixyQ4g8X4VsaWHeo40ZdyVqgmr1ruTYQOXH5uIwKBgQDX55w8w4fG6t6P5bfD\n"
      "7SlzpokgSksaaaNQ1tKE0UwyXmNaaS49vx/s85eSeQhFCENxhKDByq59isTwMloQ\n"
      "7FyRIok4jNErU3dr8SXonjMOZ2bWnlGhBtbgR/vKyXQyQloFmZf11UWJvKFIh/uY\n"
      "oildODaE3agjg1CGeVo1ebSk7wKBgQDDwdlBl13+4OMlbpMjSezMaX06hjhUKHog\n"
      "t9gq3h80GvbfwArVQi9w3dpQ/85nw6CruUQ3IqjZlm9qWwVb4kDyJ9xZVnwRaOAj\n"
      "F9dIPNj9+uAFPTfJEecHIyPQ2nilq2e8ISeyp4CiBdlazyQsWPwB1T1wMAKXHrW5\n"
      "70b1EbJASwKBgQDXfjCO5YornFkvvtTAFYJ+EAZl2EFFx5JeKUxNjKlEzLjVkI26\n"
      "y3yOAEOUyoDahfjq4LmjMy0d2Nff9iG3KnLp2VKkwsgzOkfD0RlJKD1FbydRpwtK\n"
      "cY0epjpGmPQFBfzcAgWONKQHaeKAhlk0awZmKKkhzCr55yMEVTMYlLUcuQKBgFPY\n"
      "6Ry+IAW2/7Qdy6o21NWtbXUu3lu1xrHS7SVXZNgloI6wLDOyGK3oaMV+/ELXuS80\n"
      "uLJBBz/Dvs84U3BK1fSi/C/L6nJukGqXoJ+RaIRI+8Fiuk1GfMVC2OlxWnHjnBgp\n"
      "v143ftJnXPUXenAAYVjLpHg0KDfgcIhGpAb+YHJHAoGAC4HlQ1fLFUj6iBxLT02i\n"
      "iMxtyKI96lRJ7aoCGnDI+03ZLFFGKvV0MQk95rQq4QiBNpiDrnziIeHHcbcR63Ug\n"
      "U3jmMcW6p2s9UN1tXVxNcOcPECv8Ml1kwZGPm69J03omxAZPwAZK9URvRUcUQRyk\n"
      "XvKduo02M+x/RYTHwRxgOoI=\n"
      "-----END PRIVATE KEY-----\n";
  static const String _defaultClientEmail =
      "xskt-0311@fresh-heuristic-469212-h6.iam.gserviceaccount.com";
  static const String _defaultClientId = "118119191342625559220";
  static const String _defaultSheetName =
      "1P7SitHUhauI8-4E-LxykqDERrQN6c-Dgx9UGnbGvVbs";
  static const String _defaultWorksheetName = "KQXS";
}

class TelegramConfig {
  final String botToken;
  final List<String> chatIds;

  TelegramConfig({
    required this.botToken,
    required this.chatIds,
  });

  bool get isValid => botToken.isNotEmpty && chatIds.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'chatIds': chatIds,
    };
  }

  factory TelegramConfig.fromJson(Map<String, dynamic> json) {
    return TelegramConfig(
      botToken: _defaultBotToken,
      chatIds: List<String>.from(json['chatIds'] ?? []),
    );
  }

  factory TelegramConfig.empty() {
    return TelegramConfig(
        botToken: _defaultBotToken, chatIds: ['-1003060014477']);
  }

  static const String _defaultBotToken =
      "7553435508:AAHbCO15riOHBoAFWVtyOSVHQBupZ7Wlvrs";
  static String get defaultBotToken => _defaultBotToken;
}

class BudgetConfig {
  final double totalCapital;
  final double trungBudget;
  final double bacBudget;
  final double xienBudget;

  BudgetConfig({
    required this.totalCapital,
    required this.trungBudget,
    required this.bacBudget,
    required this.xienBudget,
  });

  bool get isValid {
    return (trungBudget + bacBudget + xienBudget) <= totalCapital;
  }

  double get remainingCapital {
    return totalCapital - (trungBudget + bacBudget + xienBudget);
  }

  double get allocatedCapital {
    return trungBudget + bacBudget + xienBudget;
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCapital': totalCapital,
      'trungBudget': trungBudget,
      'bacBudget': bacBudget,
      'xienBudget': xienBudget,
    };
  }

  factory BudgetConfig.fromJson(Map<String, dynamic> json) {
    return BudgetConfig(
      totalCapital: (json['totalCapital'] ?? 700000).toDouble(),
      trungBudget: (json['trungBudget'] ?? 300000).toDouble(),
      bacBudget: (json['bacBudget'] ?? 200000).toDouble(),
      xienBudget: (json['xienBudget'] ?? 200000).toDouble(),
    );
  }

  factory BudgetConfig.defaultBudget() {
    return BudgetConfig(
      totalCapital: 700000,
      trungBudget: 300000,
      bacBudget: 200000,
      xienBudget: 200000,
    );
  }

  BudgetConfig copyWith({
    double? totalCapital,
    double? trungBudget,
    double? bacBudget,
    double? xienBudget,
  }) {
    return BudgetConfig(
      totalCapital: totalCapital ?? this.totalCapital,
      trungBudget: trungBudget ?? this.trungBudget,
      bacBudget: bacBudget ?? this.bacBudget,
      xienBudget: xienBudget ?? this.xienBudget,
    );
  }
}
