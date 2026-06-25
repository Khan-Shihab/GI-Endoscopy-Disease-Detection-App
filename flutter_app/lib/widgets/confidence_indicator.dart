import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Circular confidence meter, color-coded by the detection status.
class ConfidenceIndicator extends StatelessWidget {
  final double confidence; // 0-100
  final bool isPolypDetected;

  const ConfidenceIndicator({
    super.key,
    required this.confidence,
    required this.isPolypDetected,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPolypDetected ? AppColors.danger : AppColors.safe;

    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: confidence / 100,
                  strokeWidth: 8,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text(
                '${confidence.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Confidence',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
