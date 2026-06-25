import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Pill-shaped badge showing the predicted GI class with a clear color
/// signal — red for pathological findings, green for normal.
class StatusBadge extends StatelessWidget {
  final bool isPolypDetected; // true = any pathological class (Polyp / GERD)
  final String
      status; // exact class name from the API e.g. "Polyp", "GERD Normal"

  const StatusBadge({
    super.key,
    required this.isPolypDetected,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPolypDetected ? AppColors.danger : AppColors.safe;
    final icon =
        isPolypDetected ? Icons.warning_rounded : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            status, // "Polyp", "Polyp Normal", "GERD", "GERD Normal"
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
