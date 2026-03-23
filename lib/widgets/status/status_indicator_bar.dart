import 'package:flutter/material.dart';
import 'package:v2go/widgets/latency_indicator_widget.dart';

const Color kStatusCardColor = Color.fromARGB(255, 59, 59, 59);

/// 状态指示器组件
class StatusIndicator extends StatelessWidget {
  final String label;
  final bool isActive;
  final IconData icon;
  final Color? statusColor;
  final bool isLoading;
  final VoidCallback? onTap;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.isActive,
    required this.icon,
    this.statusColor,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor ?? Colors.green;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: kStatusCardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? color : Colors.grey.shade600,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                    ),
                  )
                : Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 状态指示器栏 - 包含延迟指示器和多个状态指示器
/// 使用 ValueListenableBuilder 优化性能，只重绘变化的部分
class StatusIndicatorBar extends StatelessWidget {
  final ValueNotifier<bool> isConnectedNotifier;
  final String? serverAddress;
  final int? serverPort;
  final ValueNotifier<String?> locationNotifier;
  final ValueNotifier<bool> isLoadingLocationNotifier;
  final VoidCallback? onRefreshLocation;

  const StatusIndicatorBar({
    super.key,
    required this.isConnectedNotifier,
    this.serverAddress,
    this.serverPort,
    required this.locationNotifier,
    required this.isLoadingLocationNotifier,
    this.onRefreshLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ValueListenableBuilder<bool>(
        valueListenable: isConnectedNotifier,
        builder: (context, isConnected, child) {
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              // 延迟指示器
              LatencyIndicatorWidget(
                address: serverAddress ?? '',
                port: serverPort ?? 0,
                testInterval: const Duration(seconds: 5),
                isActive: isConnected && serverAddress != null,
                backgroundColor: kStatusCardColor,
              ),
              ValueListenableBuilder<String?>(
                valueListenable: locationNotifier,
                builder: (context, location, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: isLoadingLocationNotifier,
                    builder: (context, isLoadingLocation, child) {
                      return StatusIndicator(
                        label: location ?? (isConnected ? '服务器' : '未知'),
                        isActive: isConnected,
                        icon: Icons.location_on_rounded,
                        isLoading: isLoadingLocation,
                        onTap: isConnected && !isLoadingLocation && onRefreshLocation != null
                            ? onRefreshLocation
                            : null,
                      );
                    },
                  );
                },
              ),
              StatusIndicator(
                label: '代理',
                isActive: isConnected,
                icon: Icons.security_rounded,
                statusColor:  Colors.green,
              ),
            ],
          );
        },
      ),
    );
  }
}

