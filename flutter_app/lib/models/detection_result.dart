import 'dart:convert';
import 'dart:typed_data';

/// Parsed response from the /predict endpoint.
class DetectionResult {
  final bool isPolypDetected;
  final String status; // "Detected" | "Not Detected"
  final double confidence; // 0-100
  final Uint8List originalImageBytes;
  final Uint8List annotatedImageBytes;
  final double inferenceTimeMs;

  DetectionResult({
    required this.isPolypDetected,
    required this.status,
    required this.confidence,
    required this.originalImageBytes,
    required this.annotatedImageBytes,
    required this.inferenceTimeMs,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      isPolypDetected: json['is_polyp_detected'] as bool,
      status: json['status'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      originalImageBytes: base64Decode(json['original_image'] as String),
      annotatedImageBytes: base64Decode(json['annotated_image'] as String),
      inferenceTimeMs: (json['inference_time_ms'] as num).toDouble(),
    );
  }
}

/// Typed exception so the UI layer can show specific, actionable
/// messages instead of a generic "something went wrong".
class DetectionException implements Exception {
  final String message;
  final DetectionErrorType type;

  DetectionException(this.message, this.type);

  @override
  String toString() => message;
}

enum DetectionErrorType {
  network, // no internet / can't reach server
  timeout, // request took too long
  invalidImage, // server rejected the image (corrupt / wrong format)
  serverError, // 5xx, model failure
  unknown,
}
