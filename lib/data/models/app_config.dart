// lib/data/models/app_config.dart

import 'api_account.dart';
import 'probability_config.dart';

class BettingConfig {
  final String domain;

  BettingConfig({
    this.domain = 'sin88.pro',
  });

  Map<String, dynamic> toJson() => {'domain': domain};

  factory BettingConfig.fromJson(Map<String, dynamic> json) {
    return BettingConfig(domain: json['domain'] ?? 'sin88.pro');
  }

  factory BettingConfig.empty() => BettingConfig(domain: 'sin88.pro');

  BettingConfig copyWith({String? domain}) {
    return BettingConfig(domain: domain ?? this.domain);
  }
}

class BudgetConfig {
  final double totalCapital;
  final double namBudget; // ✅ THÊM
  final double trungBudget;
  final double bacBudget;
  final double xienBudget;

  BudgetConfig({
    required this.totalCapital,
    required this.namBudget, // ✅ THÊM
    required this.trungBudget,
    required this.bacBudget,
    required this.xienBudget,
  });

  // ✅ CẬP NHẬT Logic tính toán bao gồm namBudget
  bool get isValid {
    return (namBudget + trungBudget + bacBudget + xienBudget) <= totalCapital;
  }

  double get remainingCapital {
    return totalCapital - (namBudget + trungBudget + bacBudget + xienBudget);
  }

  double get allocatedCapital {
    return namBudget + trungBudget + bacBudget + xienBudget;
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCapital': totalCapital,
      'namBudget': namBudget, // ✅ THÊM
      'trungBudget': trungBudget,
      'bacBudget': bacBudget,
      'xienBudget': xienBudget,
    };
  }

  factory BudgetConfig.fromJson(Map<String, dynamic> json) {
    return BudgetConfig(
      totalCapital: (json['totalCapital'] ?? 700000).toDouble(),
      namBudget: (json['namBudget'] ?? 350000).toDouble(), // ✅ THÊM
      trungBudget: (json['trungBudget'] ?? 300000).toDouble(),
      bacBudget: (json['bacBudget'] ?? 200000).toDouble(),
      xienBudget: (json['xienBudget'] ?? 200000).toDouble(),
    );
  }

  factory BudgetConfig.defaultBudget() {
    return BudgetConfig(
      totalCapital: 700000,
      namBudget: 350000, // ✅ Mặc định 0
      trungBudget: 300000,
      bacBudget: 200000,
      xienBudget: 200000,
    );
  }

  BudgetConfig copyWith({
    double? totalCapital,
    double? namBudget, // ✅ THÊM
    double? trungBudget,
    double? bacBudget,
    double? xienBudget,
  }) {
    return BudgetConfig(
      totalCapital: totalCapital ?? this.totalCapital,
      namBudget: namBudget ?? this.namBudget, // ✅ THÊM
      trungBudget: trungBudget ?? this.trungBudget,
      bacBudget: bacBudget ?? this.bacBudget,
      xienBudget: xienBudget ?? this.xienBudget,
    );
  }
}

class AppConfig {
  final GoogleSheetsConfig googleSheets;
  final TelegramConfig telegram;
  final BudgetConfig budget;
  final ProbabilityConfig probability;
  final List<ApiAccount> apiAccounts;
  final BettingConfig betting;

  AppConfig({
    required this.googleSheets,
    required this.telegram,
    required this.budget,
    ProbabilityConfig? probability,
    List<ApiAccount>? apiAccounts,
    BettingConfig? betting,
  })  : probability = probability ?? ProbabilityConfig.defaults(),
        apiAccounts = apiAccounts ?? [],
        betting = betting ?? BettingConfig.empty();

  Map<String, dynamic> toJson() {
    return {
      'googleSheets': googleSheets.toJson(),
      'telegram': telegram.toJson(),
      'budget': budget.toJson(),
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
      probability: ProbabilityConfig.defaults(),
      apiAccounts: [],
      betting: BettingConfig.empty(),
    );
  }

  AppConfig copyWith({
    GoogleSheetsConfig? googleSheets,
    TelegramConfig? telegram,
    BudgetConfig? budget,
    ProbabilityConfig? probability,
    List<ApiAccount>? apiAccounts,
    BettingConfig? betting,
  }) {
    return AppConfig(
      googleSheets: googleSheets ?? this.googleSheets,
      telegram: telegram ?? this.telegram,
      budget: budget ?? this.budget,
      probability: probability ?? this.probability,
      apiAccounts: apiAccounts ?? this.apiAccounts,
      betting: betting ?? this.betting,
    );
  }
}

// ... (Giữ nguyên class GoogleSheetsConfig và TelegramConfig như file cũ của bạn)
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
