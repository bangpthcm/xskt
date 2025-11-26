class ApiAccount {
  final String username;
  final String password;

  ApiAccount({
    required this.username,
    required this.password,
  });

  bool get isValid => username.isNotEmpty && password.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }

  factory ApiAccount.fromJson(Map<String, dynamic> json) {
    return ApiAccount(
      username: json['username'] ?? '',
      password: json['password'] ?? '',
    );
  }

  factory ApiAccount.empty() {
    return ApiAccount(
      username: '',
      password: '',
    );
  }

  ApiAccount copyWith({
    String? username,
    String? password,
  }) {
    return ApiAccount(
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}