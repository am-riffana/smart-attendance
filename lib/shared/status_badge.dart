import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Reusable status badge chip
class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, textColor) = _resolveColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color, Color) _resolveColors(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case AppConstants.statusPresent:
        return ('Present', AppColors.present.withValues(alpha: 0.15), AppColors.present);
      case AppConstants.statusCheckedIn:
        return ('Checked In', AppColors.checkedIn.withValues(alpha: 0.15), AppColors.checkedIn);
      case AppConstants.statusCheckedOut:
        return ('Checked Out', AppColors.checkedOut.withValues(alpha: 0.15), AppColors.checkedOut);
      case AppConstants.statusLate:
        return ('Late', AppColors.lateStatus.withValues(alpha: 0.15), AppColors.lateStatus);
      case AppConstants.statusAbsent:
        return ('Absent', AppColors.absent.withValues(alpha: 0.15), AppColors.absent);
      case AppConstants.sessionActive:
        return ('Active', AppColors.present.withValues(alpha: 0.15), AppColors.present);
      case AppConstants.sessionExpired:
        return ('Expired', AppColors.absent.withValues(alpha: 0.15), AppColors.absent);
      default:
        return (rawStatus.toUpperCase(), Colors.grey.withValues(alpha: 0.15), Colors.grey);
    }
  }
}
