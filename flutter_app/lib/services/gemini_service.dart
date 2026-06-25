import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// Sends the model's label + confidence to Gemini and gets back a
/// plain-language explanation to show alongside the raw result.
class GeminiService {
  Future<String> explainResult({
    required String status,
    required bool isPolypDetected,
    required double confidence,
  }) async {
    final uri =
        Uri.parse('${AppConfig.geminiEndpoint}?key=${AppConfig.geminiApiKey}');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _buildPrompt(status, isPolypDetected, confidence)}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 256,
      },
    });

    http.Response response;
    try {
      response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw GeminiException('Gemini took too long to respond.');
    } catch (e) {
      throw GeminiException('Could not reach Gemini: $e');
    }

    if (response.statusCode != 200) {
      throw GeminiException(_extractErrorMessage(response.body) ??
          'Gemini request failed (${response.statusCode}).');
    }

    return _extractText(response.body);
  }

  String _buildPrompt(String status, bool isPolypDetected, double confidence) {
    return '''
You are a brief explanatory assistant inside a GI (gastrointestinal) endoscopy
screening app. The app's machine learning model just produced this output:

- Predicted label: $status
- Flagged as abnormal: $isPolypDetected
- Confidence: ${confidence.toStringAsFixed(1)}%

Write a short, plain-language explanation (3-5 sentences, no markdown, no
headings) for a patient or care team viewing this result. Cover:
1. What "$status" generally means in simple terms.
2. Whether ${confidence.toStringAsFixed(1)}% confidence is high, moderate, or
   low, and what that implies about reliability.
3. A brief closing reminder that this is an AI screening aid, not a medical
   diagnosis, and a qualified clinician should review the actual image.

Keep it concise and reassuring in tone without being alarmist or definitive.
''';
  }

  String _extractText(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('no candidates');
      }
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw const FormatException('no parts');
      }
      final text = parts.map((p) => p['text']?.toString() ?? '').join().trim();
      if (text.isEmpty) throw const FormatException('empty text');
      return text;
    } catch (_) {
      throw GeminiException('Unexpected response format from Gemini.');
    }
  }

  String? _extractErrorMessage(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      return error?['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);

  @override
  String toString() => message;
}
