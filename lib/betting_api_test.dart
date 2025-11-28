import 'package:flutter_test/flutter_test.dart';
import 'data/models/api_account.dart';
import 'data/services/betting_api_service.dart';

void main() {
  late BettingApiService apiService;

  setUp(() {
    apiService = BettingApiService();
  });

  test('Full authentication flow', () async {
    // ✅ Thay username/password thật của bạn
    final account = ApiAccount(
      username: 'azvua123',
      password: 'bPT021220',
    );

    print('\n🚀 Starting authentication test...\n');

    // Test login
    final loginSuccess = await apiService.login(account);
    expect(loginSuccess, true, reason: 'Login should succeed');

    // Đợi 1 giây để đảm bảo cookie được lưu
    await Future.delayed(const Duration(seconds: 1));

    // Test get token
    final token = await apiService.getTPToken();
    expect(token, isNotNull, reason: 'Token should not be null');
    expect(token!.length, greaterThan(10), reason: 'Token should be valid');

    print('\n✅ Test passed! Token: ${token.substring(0, 20)}...\n');
  });
}