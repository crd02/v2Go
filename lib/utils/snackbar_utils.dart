import 'package:flutter/material.dart';
import 'package:v2go/widgets/common/custom_snackbar.dart';

/// SnackBar 工具类
class SnackBarUtils {
  SnackBarUtils._(); // 私有构造函数，防止实例化

  /// 显示错误提示
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: const Color(0xFFE53935), // Material Red 600
      icon: Icons.error_outline,
      duration: duration,
    );
  }

  /// 显示成功提示
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: const Color(0xFF43A047), // Material Green 600
      icon: Icons.check_circle_outline,
      duration: duration,
    );
  }

  /// 显示警告提示
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: const Color(0xFFFB8C00), // Material Orange 600
      icon: Icons.warning_amber_outlined,
      duration: duration,
    );
  }

  /// 显示信息提示
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: const Color(0xFF1E88E5), // Material Blue 600
      icon: Icons.info_outline,
      duration: duration,
    );
  }

  /// 内部方法：显示 SnackBar
  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required Duration duration,
  }) {
    // 确保在下一帧执行，避免在 build 过程中操作 overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => CustomSnackBar(
          message: message,
          backgroundColor: backgroundColor,
          icon: icon,
          displayDuration: duration,
          onDismiss: () {
            overlayEntry.remove();
          },
        ),
      );

      overlay.insert(overlayEntry);
    });
  }
}

