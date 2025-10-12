class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập email';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email không hợp lệ';
    }
    
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    return null;
  }

  static String? validateNumber(String? value, {double? min, double? max}) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập số';
    }
    
    final number = double.tryParse(value);
    if (number == null) {
      return 'Số không hợp lệ';
    }
    
    if (min != null && number < min) {
      return 'Phải lớn hơn hoặc bằng $min';
    }
    
    if (max != null && number > max) {
      return 'Phải nhỏ hơn hoặc bằng $max';
    }
    
    return null;
  }

  static String? validateTelegramToken(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập Bot Token';
    }
    
    if (!value.contains(':')) {
      return 'Bot Token không hợp lệ';
    }
    
    return null;
  }

  static String? validatePrivateKey(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập Private Key';
    }
    
    if (!value.contains('BEGIN PRIVATE KEY')) {
      return 'Private Key không hợp lệ';
    }
    
    return null;
  }
}