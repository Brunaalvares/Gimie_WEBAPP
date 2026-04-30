import 'package:flutter/foundation.dart';

class DebugHelper {
  static void log(String message, [String? tag]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final formattedTag = tag != null ? '[$tag]' : '[DEBUG]';
      print('$timestamp $formattedTag $message');
    }
  }
  
  static void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('$timestamp [ERROR] $message');
      if (error != null) {
        print('$timestamp [ERROR] Error: $error');
      }
      if (stackTrace != null) {
        print('$timestamp [ERROR] StackTrace: $stackTrace');
      }
    }
  }
  
  static void logShareContent(Map<String, dynamic> content) {
    if (kDebugMode) {
      log('Share content received:', 'SHARE');
      content.forEach((key, value) {
        if (key == 'imageBytes') {
          log('  $key: [${(value as List<int>?)?.length ?? 0} bytes]', 'SHARE');
        } else {
          log('  $key: $value', 'SHARE');
        }
      });
    }
  }
}