import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AvatarView extends StatelessWidget {
  final String avatar;
  final double size;
  final double fontSize;
  final double borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;

  const AvatarView({
    super.key,
    required this.avatar,
    this.size = 48,
    this.fontSize = 22,
    this.borderWidth = 1.5,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemeManager.currentTheme;
    final isBase64 = avatar.length > 8;
    final displayBorderColor = borderColor ?? palette.border.withOpacity(0.3);
    final displayBgColor = backgroundColor ?? palette.secondary.withOpacity(0.4);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: displayBgColor,
        border: Border.all(
          color: displayBorderColor,
          width: borderWidth,
        ),
      ),
      child: ClipOval(
        child: isBase64
            ? _buildBase64Image(avatar)
            : _buildEmojiText(avatar.isNotEmpty ? avatar : '👤'),
      ),
    );
  }

  Widget _buildBase64Image(String base64Str) {
    try {
      final bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          return _buildEmojiText('👤');
        },
      );
    } catch (e) {
      return _buildEmojiText('👤');
    }
  }

  Widget _buildEmojiText(String emoji) {
    return Center(
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.1,
        ),
      ),
    );
  }
}
