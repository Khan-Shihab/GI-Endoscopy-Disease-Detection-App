import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/gemini_service.dart';

/// Fetches a plain-language explanation from Gemini for the given
/// label/confidence and renders it as a card. Handles its own
/// loading / error / retry state so the parent screen stays simple.
class GeminiExplanationCard extends StatefulWidget {
  final String status;
  final bool isPolypDetected;
  final double confidence;

  const GeminiExplanationCard({
    super.key,
    required this.status,
    required this.isPolypDetected,
    required this.confidence,
  });

  @override
  State<GeminiExplanationCard> createState() => _GeminiExplanationCardState();
}

class _GeminiExplanationCardState extends State<GeminiExplanationCard> {
  final _gemini = GeminiService();
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<String> _fetch() {
    return _gemini.explainResult(
      status: widget.status,
      isPolypDetected: widget.isPolypDetected,
      confidence: widget.confidence,
    );
  }

  void _retry() {
    setState(() => _future = _fetch());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              const Text(
                'AI explanation',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingRow();
              }
              if (snapshot.hasError) {
                final message = snapshot.error is GeminiException
                    ? (snapshot.error as GeminiException).message
                    : 'Something went wrong fetching the explanation.';
                return _ErrorRow(message: message, onRetry: _retry);
              }
              return Text(
                snapshot.data ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text(
          'Generating explanation…',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRow({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
