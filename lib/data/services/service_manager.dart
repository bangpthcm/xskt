// lib/core/services/service_manager.dart

/// ✅ Global service manager để track services ready state
class ServiceManager {
  static bool _servicesReady = false;
  
  static bool get isReady => _servicesReady;
  
  static void markReady() {
    _servicesReady = true;
    print('✅ ServiceManager: Services marked as ready');
  }
  
  static void markNotReady() {
    _servicesReady = false;
    print('⚠️ ServiceManager: Services marked as not ready');
  }
  
  /// ✅ Wait for services to be ready (with timeout)
  static Future<void> waitForReady({
    Duration timeout = const Duration(seconds: 10),
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    final startTime = DateTime.now();
    
    print('⏳ ServiceManager: Waiting for services to be ready...');
    
    while (!_servicesReady) {
      await Future.delayed(checkInterval);
      
      // Timeout safety
      if (DateTime.now().difference(startTime) > timeout) {
        print('⚠️ ServiceManager: Timeout after ${timeout.inSeconds}s');
        throw Exception('Services initialization timeout');
      }
    }
    
    print('✅ ServiceManager: Services confirmed ready');
  }
}