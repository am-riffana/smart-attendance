import 'package:flutter/material.dart';

enum AppButtonType { primary, secondary, outlined, danger }

/// Reusable application button supporting loading indicator, icons, and variants
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData? icon;
  final AppButtonType type;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
    this.icon,
    this.type = AppButtonType.primary,
    this.width,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget child;
    if (isBusy) {
      child = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: Colors.white,
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    } else {
      child = Text(label);
    }

    final buttonStyle = switch (type) {
      AppButtonType.primary => ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
      AppButtonType.secondary => ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: theme.colorScheme.onSecondary,
        ),
      AppButtonType.outlined => OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
        ),
      AppButtonType.danger => ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
    };

    Widget buttonWidget;
    if (type == AppButtonType.outlined) {
      buttonWidget = OutlinedButton(
        onPressed: isBusy ? null : onPressed,
        style: buttonStyle,
        child: child,
      );
    } else {
      buttonWidget = ElevatedButton(
        onPressed: isBusy ? null : onPressed,
        style: buttonStyle,
        child: child,
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: buttonWidget,
    );
  }
}
