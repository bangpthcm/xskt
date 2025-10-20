//lib/data/models/app_config.dart

class AppConfig {
  final GoogleSheetsConfig googleSheets;
  final TelegramConfig telegram;
  final BudgetConfig budget;

  AppConfig({
    required this.googleSheets,
    required this.telegram,
    required this.budget,
  });

  Map<String, dynamic> toJson() {
    return {
      'googleSheets': googleSheets.toJson(),
      'telegram': telegram.toJson(),
      'budget': budget.toJson(),
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      googleSheets: GoogleSheetsConfig.fromJson(json['googleSheets'] ?? {}),
      telegram: TelegramConfig.fromJson(json['telegram'] ?? {}),
      budget: BudgetConfig.fromJson(json['budget'] ?? {}),
    );
  }

  factory AppConfig.defaultConfig() {
    return AppConfig(
      googleSheets: GoogleSheetsConfig.withHardcodedCredentials(
        sheetName: '1P7SitHUhauI8-4E-LxykqDERrQN6c-Dgx9UGnbGvVbs',
        worksheetName: 'KQXS',
      ),
      telegram: TelegramConfig.empty(),
      budget: BudgetConfig.defaultBudget(),
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
      'worksheetName': worksheetName,
    };
  }

  factory GoogleSheetsConfig.fromJson(Map<String, dynamic> json) {
    return GoogleSheetsConfig(
      projectId: _defaultProjectId,
      privateKeyId: _defaultPrivateKeyId,
      privateKey: _defaultPrivateKey,
      clientEmail: _defaultClientEmail,
      clientId: _defaultClientId,
      sheetName: json['sheetName'] ?? '1P7SitHUhauI8-4E-LxykqDERrQN6c-Dgx9UGnbGvVbs',
      worksheetName: json['worksheetName'] ?? 'KQXS',
    );
  }

  factory GoogleSheetsConfig.withHardcodedCredentials({
    required String sheetName,
    required String worksheetName,
  }) {
    return GoogleSheetsConfig(
      projectId: _defaultProjectId,
      privateKeyId: _defaultPrivateKeyId,
      privateKey: _defaultPrivateKey,
      clientEmail: _defaultClientEmail,
      clientId: _defaultClientId,
      sheetName: sheetName,
      worksheetName: worksheetName,
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
      worksheetName: '',
    );
  }

  static const String _defaultProjectId = "fresh-heuristic-469212-h6";
  static const String _defaultPrivateKeyId = "cf577e77874a18e644093da3a81dcfe53b49796e";
  static const String _defaultPrivateKey = 
      "-----BEGIN PRIVATE KEY-----\n"
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
      'botToken': botToken,
      'chatIds': chatIds,
    };
  }

  factory TelegramConfig.fromJson(Map<String, dynamic> json) {
    return TelegramConfig(
      botToken: json['botToken'] ?? '7553435508:AAHbCO15riOHBoAFWVtyOSVHQBupZ7Wlvrs',
      chatIds: List<String>.from(json['chatIds'] ?? []),
    );
  }

  factory TelegramConfig.empty() {
    return TelegramConfig(
      botToken: '7553435508:AAHbCO15riOHBoAFWVtyOSVHQBupZ7Wlvrs', 
      chatIds: ['-1003060014477']
    );
  }
}

// ✅ UPDATED: BudgetConfig
class BudgetConfig {
  final double cycleTarget;        // ✅ NEW: Thay budgetMin/Max
  final double xienBudget;
  final double tuesdayExtraBudget;  // ✅ NEW: Thêm budget cho Tuesday

  BudgetConfig({
    required this.cycleTarget,
    required this.xienBudget,
    required this.tuesdayExtraBudget,
  });

  // ✅ Tính budgetMin/Max từ cycleTarget
  double get budgetMin => cycleTarget * 0.95;  // -5%
  double get budgetMax => cycleTarget * 1.05;  // +5%

  Map<String, dynamic> toJson() {
    return {
      'cycleTarget': cycleTarget,
      'xienBudget': xienBudget,
      'tuesdayExtraBudget': tuesdayExtraBudget,
    };
  }

  factory BudgetConfig.fromJson(Map<String, dynamic> json) {
    return BudgetConfig(
      cycleTarget: (json['cycleTarget'] ?? 340000.0).toDouble(),
      xienBudget: (json['xienBudget'] ?? 19000.0).toDouble(),
      tuesdayExtraBudget: (json['tuesdayExtraBudget'] ?? 200000.0).toDouble(),
    );
  }

  factory BudgetConfig.defaultBudget() {
    return BudgetConfig(
      cycleTarget: 330000.0,      // Trung bình của 330k-350k
      xienBudget: 19000.0,
      tuesdayExtraBudget: 200000.0,
    );
  }
}