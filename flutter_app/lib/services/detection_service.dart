import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/app_config.dart';
import '../models/detection_result.dart';

/// Handles all network communication with the polyp detection backend.
class DetectionService {
  Future<DetectionResult> analyzeImage(File imageFile) async {
    final sizeMb = await imageFile.length() / (1024 * 1024);
    if (sizeMb > AppConfig.maxImageSizeMb) {
      throw DetectionException(
        'Image is too large (${sizeMb.toStringAsFixed(1)} MB). '
        'Please choose an image under ${AppConfig.maxImageSizeMb} MB.',
        DetectionErrorType.invalidImage,
      );
    }

    final uri = Uri.parse(AppConfig.predictEndpoint);
    final request = http.MultipartRequest('POST', uri);

    final mimeType = _inferMimeType(imageFile.path);
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: mimeType,
      ),
    );

    try {
      final streamedResponse =
          await request.send().timeout(AppConfig.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on TimeoutException {
      throw DetectionException(
        'The server took too long to respond. Please try again.',
        DetectionErrorType.timeout,
      );
    } on SocketException {
      throw DetectionException(
        'Could not reach the detection server. Check your internet '
        'connection and that the server is running.',
        DetectionErrorType.network,
      );
    } on http.ClientException {
      throw DetectionException(
        'Network error while uploading the image. Please try again.',
        DetectionErrorType.network,
      );
    } catch (e) {
      throw DetectionException(
        'An unexpected error occurred: $e',
        DetectionErrorType.unknown,
      );
    }
  }

  DetectionResult _handleResponse(http.Response response) {
    final body = response.body;

    switch (response.statusCode) {
      case 200:
        final json = jsonDecode(body) as Map<String, dynamic>;
        return DetectionResult.fromJson(json);

      case 400:
      case 415:
        final detail = _extractDetail(body) ??
            'The uploaded image could not be processed. '
                'Please try a different image.';
        throw DetectionException(detail, DetectionErrorType.invalidImage);

      case 413:
        throw DetectionException(
          _extractDetail(body) ?? 'Image is too large.',
          DetectionErrorType.invalidImage,
        );

      case 503:
        throw DetectionException(
          'The detection model is currently unavailable on the server. '
          'Please try again shortly.',
          DetectionErrorType.serverError,
        );

      default:
        if (response.statusCode >= 500) {
          throw DetectionException(
            _extractDetail(body) ??
                'The server encountered an error while analyzing the image.',
            DetectionErrorType.serverError,
          );
        }
        throw DetectionException(
          'Unexpected response from server (${response.statusCode}).',
          DetectionErrorType.unknown,
        );
    }
  }

  String? _extractDetail(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail'] as String?;
    } catch (_) {
      return null;
    }
  }

  MediaType? _inferMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return null; // let http infer it
  }
}
