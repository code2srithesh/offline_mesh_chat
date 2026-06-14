import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomToast {
  static void show(BuildContext context, String message, {Duration duration = const Duration(milliseconds: 1500)}) {
    final palette = ThemeManager.currentTheme;
    
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.15),
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, anim1, anim2) {
        // Automatically dismiss toast after duration
        Timer(duration, () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
        
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: AppTheme.glassCardDecoration(
                color: palette.secondary.withOpacity(0.9),
                borderRadius: 20,
                borderColor: palette.border,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = 0.95 + (0.05 * anim1.value);
        return Opacity(
          opacity: anim1.value,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }

  static void showDialogBox({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = "OK",
    String cancelText = "Cancel",
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    final palette = ThemeManager.currentTheme;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassCardDecoration(
                color: palette.secondary.withOpacity(0.95),
                borderRadius: 24,
                borderColor: palette.border,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.45,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onCancel != null || cancelText.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (onCancel != null) onCancel();
                          },
                          child: Text(
                            cancelText,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmText.contains("Erase") || confirmText.contains("Delete") || confirmText.contains("RESET") || confirmText.contains("ERASE") || confirmText.contains("ROTATE")
                              ? palette.error
                              : palette.accent,
                          foregroundColor: confirmText.contains("Erase") || confirmText.contains("Delete") || confirmText.contains("RESET") || confirmText.contains("ERASE") || confirmText.contains("ROTATE")
                              ? Colors.white
                              : palette.background,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onConfirm();
                        },
                        child: Text(
                          confirmText,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = 0.94 + (0.06 * anim1.value);
        return Opacity(
          opacity: anim1.value,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }
}
