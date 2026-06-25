import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/detection_result.dart';
import '../widgets/confidence_indicator.dart';
import '../widgets/gemini_explanation_card.dart';
import '../widgets/status_badge.dart';

class ResultScreen extends StatelessWidget {
  final DetectionResult result;

  const ResultScreen({super.key, required this.result});

  static const double _minConfidence = 90.0;

  @override
  Widget build(BuildContext context) {
    final bool lowConfidence = result.confidence < _minConfidence;

    return Scaffold(
      appBar: AppBar(title: const Text('Detection result')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: lowConfidence
              ? _buildLowConfidenceView(context)
              : _buildResultView(context),
        ),
      ),
    );
  }

  Widget _buildLowConfidenceView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.help_outline_rounded, size: 72, color: Colors.orange),
        const SizedBox(height: 24),
        const Text(
          "Sorry, I can't detect this image",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          'The model confidence is too low (${result.confidence.toStringAsFixed(1)}%) '
          'to make a reliable prediction. Please try a clearer endoscopy image.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 40),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.refresh),
          label: const Text('Try another image'),
        ),
      ],
    );
  }

  Widget _buildResultView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: StatusBadge(
            isPolypDetected: result.isPolypDetected,
            status: result.status,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ConfidenceIndicator(
            confidence: result.confidence,
            isPolypDetected: result.isPolypDetected,
          ),
        ),
        const SizedBox(height: 28),
        _buildImageComparison(),
        const SizedBox(height: 20),
        _buildMetadataCard(),
        const SizedBox(height: 20),
        GeminiExplanationCard(
          status: result.status,
          isPolypDetected: result.isPolypDetected,
          confidence: result.confidence,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.refresh),
            label: const Text('Analyze another image'),
          ),
        ),
      ],
    );
  }

  Widget _buildImageComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Original vs. annotated',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child:
                    _buildLabeledImage('Original', result.originalImageBytes)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildLabeledImage(
                    'Annotated', result.annotatedImageBytes)),
          ],
        ),
      ],
    );
  }

  Widget _buildLabeledImage(String label, Uint8List imageBytes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.memory(
              imageBytes,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildMetadataCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _metadataItem('Status', result.status),
          _metadataItem('Inference time',
              '${result.inferenceTimeMs.toStringAsFixed(0)} ms'),
        ],
      ),
    );
  }

  Widget _metadataItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
  }
}
