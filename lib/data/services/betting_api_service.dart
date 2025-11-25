// lib/data/services/betting_api_service.dart
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '../models/api_account.dart';

class BettingApiService {
  final Dio _dio = Dio();
  final CookieJar _cookieJar = CookieJar();
  String? _cachedToken;

  BettingApiService() {
    // ✅ Thêm cookie manager và interceptor
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🔄 API Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ API Response: ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (error, handler) {
          print('❌ API Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  /// ✅ STEP 1: Login và lấy cookies
  Future<bool> login(ApiAccount account) async {
    try {
      print('🔐 Logging in with username: ${account.username}');

      final headers = {
        'accept': 'application/json',
        'accept-language': 'en-US,en;q=0.9,vi;q=0.8',
        'content-type': 'application/json',
        'origin': 'https://sin88.sx',
        'priority': 'u=1, i',
        'sec-ch-ua': '"Chromium";v="142", "Google Chrome";v="142", "Not_A Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
      };

      final response = await _dio.post(
        'https://sin88.sx/api/v1/login',
        options: Options(headers: headers),
        data: {
          'username': account.username,
          'password': account.password,
        },
      );

      if (response.statusCode == 200) {
        print('✅ Login successful!');
        print('   Data: ${response.data}');
        return true;
      } else {
        print('❌ Login failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  /// ✅ STEP 2: Lấy TP Token
  Future<String?> getTPToken() async {
    try {
      print('🎫 Getting TP Token...');

      final headers = {
        'accept': '*/*',
        'accept-language': 'en-US,en;q=0.9,vi;q=0.8',
        'priority': 'u=1, i',
        'sec-ch-ua': '"Chromium";v="142", "Google Chrome";v="142", "Not_A Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
      };

      final response = await _dio.get(
        'https://sin88.sx/api/v2/user/tp-token',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        // ✅ Giả sử API trả về {token: "..."} hoặc {tp_token: "..."}
        final token = response.data['token'] ?? 
                     response.data['tp_token'] ?? 
                     response.data['access_token'];
        
        if (token != null) {
          _cachedToken = token;
          print('✅ TP Token received: ${token.substring(0, 20)}...');
          return token;
        }
        
        print('❌ No token in response: ${response.data}');
        return null;
      } else {
        print('❌ Failed to get TP Token: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ TP Token error: $e');
      return null;
    }
  }

  /// ✅ STEP 3: Complete flow - Login + Get Token
  Future<String?> authenticateAndGetToken(ApiAccount account) async {
    try {
      print('🔄 Starting authentication flow...');

      // ✅ Bước 1: Login
      final loginSuccess = await login(account);
      if (!loginSuccess) {
        print('❌ Authentication failed at login step');
        return null;
      }

      // ✅ Bước 2: Get TP Token
      final token = await getTPToken();
      if (token == null) {
        print('❌ Authentication failed at token step');
        return null;
      }

      print('✅ Authentication completed successfully');
      return token;
    } catch (e) {
      print('❌ Authentication error: $e');
      return null;
    }
  }

  /// ✅ Get cached token
  String? getCachedToken() => _cachedToken;

  /// ✅ Clear cache
  void clearCache() {
    _cachedToken = null;
    _cookieJar.deleteAll();
    print('🗑️ Cache cleared');
  }
}