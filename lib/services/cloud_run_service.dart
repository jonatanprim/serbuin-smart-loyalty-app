import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudRunService {
  static final CloudRunService _instance = CloudRunService._internal();
  factory CloudRunService() => _instance;
  CloudRunService._internal();

  // In production on Firebase Hosting, rewrites send /api/** directly to Cloud Run
  String _baseUrl = '';

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String get baseUrl => _baseUrl;

  Uri _resolveUrl(String path) {
    if (_baseUrl.isNotEmpty) {
      return Uri.parse('$_baseUrl$path');
    }
    return Uri.parse('https://serbuin-backend-398979153007.us-central1.run.app$path');
  }

  /// Check health of Cloud Run service
  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final url = _resolveUrl('/api/health');
      final resp = await http.get(url).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (e) {
      debugPrint('Cloud Run health check note: $e');
    }
    return null;
  }

  /// Call Cloud Run Gemini AI to generate loyalty program template
  Future<Map<String, dynamic>?> generateProgramTemplate({
    required String businessPrompt,
    String? businessName,
    String? businessCategory,
    String? programGoal,
  }) async {
    try {
      final url = _resolveUrl('/api/ai/generate-program');
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'businessPrompt': businessPrompt,
              'businessName': businessName,
              'businessCategory': businessCategory,
              'programGoal': programGoal,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Cloud Run generateProgramTemplate note: $e');
    }
    return null;
  }

  /// Call Cloud Run Gemini AI to scan member churn and recommend retention voucher
  Future<Map<String, dynamic>?> scanMemberChurn({
    required String customerName,
    required int stampsCollected,
    required int totalStamps,
    required int daysInactive,
    required String programTitle,
  }) async {
    try {
      final url = _resolveUrl('/api/ai/scan-churn');
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'customerName': customerName,
              'stampsCollected': stampsCollected,
              'totalStamps': totalStamps,
              'daysInactive': daysInactive,
              'programTitle': programTitle,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Cloud Run scanMemberChurn note: $e');
    }
    return null;
  }

  /// Trigger push notification via Cloud Run FCM dispatcher
  Future<bool> sendFcmNotification({
    required String customerId,
    required String title,
    required String body,
  }) async {
    try {
      final url = _resolveUrl('/api/notifications/send-fcm');
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'customerId': customerId,
              'title': title,
              'body': body,
            }),
          )
          .timeout(const Duration(seconds: 5));

      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('Cloud Run sendFcmNotification note: $e');
      return false;
    }
  }
}
