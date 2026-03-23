import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

const Color _kStatusCardColor = Color.fromARGB(255, 59, 59, 59);

/// 速度数据模型
class SpeedData {
  final double downloadSpeed;
  final double uploadSpeed;
  final bool isTestingSpeed;
  final bool isConnected;

  const SpeedData({
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.isTestingSpeed = false,
    this.isConnected = false,
  });

  SpeedData copyWith({
    double? downloadSpeed,
    double? uploadSpeed,
    bool? isTestingSpeed,
    bool? isConnected,
  }) {
    return SpeedData(
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      isTestingSpeed: isTestingSpeed ?? this.isTestingSpeed,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpeedData &&
        other.downloadSpeed == downloadSpeed &&
        other.uploadSpeed == uploadSpeed &&
        other.isTestingSpeed == isTestingSpeed &&
        other.isConnected == isConnected;
  }

  @override
  int get hashCode =>
      downloadSpeed.hashCode ^
      uploadSpeed.hashCode ^
      isTestingSpeed.hashCode ^
      isConnected.hashCode;
}

/// 数据统计区组件 - 使用 ValueNotifier 优化性能
class DataStatisticsSection extends StatelessWidget {
  final ValueNotifier<SpeedData> speedDataNotifier;

  const DataStatisticsSection({
    super.key,
    required this.speedDataNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 70,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return Row(
              children: [
                Expanded(
                  child: _DownloadSpeedCard(speedDataNotifier: speedDataNotifier),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _UploadSpeedCard(speedDataNotifier: speedDataNotifier),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                _DownloadSpeedCard(speedDataNotifier: speedDataNotifier),
                const SizedBox(height: 16),
                _UploadSpeedCard(speedDataNotifier: speedDataNotifier),
              ],
            );
          }
        },
      ),
    );
  }
}

/// 下载速度卡片 - 只监听需要的数据变化
class _DownloadSpeedCard extends StatelessWidget {
  final ValueNotifier<SpeedData> speedDataNotifier;

  const _DownloadSpeedCard({required this.speedDataNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SpeedData>(
      valueListenable: speedDataNotifier,
      builder: (context, data, child) {
        final speedText = data.isTestingSpeed
            ? '测试中...'
            : '${data.downloadSpeed.toStringAsFixed(2)} MB/s';
        final statusText = data.isTestingSpeed
            ? '正在测试速度'
            : (data.isConnected ? '测试完成' : '未连接');

        return DataStatisticsCard(
          title: '下载速度',
          speed: speedText,
          total: statusText,
          icon: Icons.arrow_downward_rounded,
          color: Colors.green,
          isLoading: data.isTestingSpeed,
        );
      },
    );
  }
}

/// 上传速度卡片 - 只监听需要的数据变化
class _UploadSpeedCard extends StatelessWidget {
  final ValueNotifier<SpeedData> speedDataNotifier;

  const _UploadSpeedCard({required this.speedDataNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SpeedData>(
      valueListenable: speedDataNotifier,
      builder: (context, data, child) {
        final speedText = data.isTestingSpeed
            ? '测试中...'
            : '${data.uploadSpeed.toStringAsFixed(2)} MB/s';
        final statusText = data.isTestingSpeed
            ? '正在测试速度'
            : (data.isConnected ? '测试完成' : '未连接');

        return DataStatisticsCard(
          title: '上传速度',
          speed: speedText,
          total: statusText,
          icon: Icons.arrow_upward_rounded,
          color: Colors.blue,
          isLoading: data.isTestingSpeed,
        );
      },
    );
  }
}

/// 数据统计卡片组件
class DataStatisticsCard extends StatelessWidget {
  final String title;
  final String speed;
  final String total;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const DataStatisticsCard({
    super.key,
    required this.title,
    required this.speed,
    required this.total,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _kStatusCardColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const _ShimmerLoading()
          else
            _SpeedDisplay(speed: speed, total: total, isDark: isDark),
        ],
      ),
    );
  }
}

/// 速度显示组件 - 避免不必要的重绘
class _SpeedDisplay extends StatelessWidget {
  final String speed;
  final String total;
  final bool isDark;

  const _SpeedDisplay({
    required this.speed,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          speed,
          style: TextStyle(
            color: isDark ? Colors.white : _kStatusCardColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          total,
          style: TextStyle(
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : Colors.black.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 骨架屏加载动画组件 - 使用 RepaintBoundary 隔离重绘
class _ShimmerLoading extends StatefulWidget {
  const _ShimmerLoading();

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(animation: _animation, width: 120, height: 24, borderRadius: 6),
          const SizedBox(height: 8),
          _ShimmerBox(animation: _animation, width: 80, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// 单个骨架屏盒子
class _ShimmerBox extends StatelessWidget {
  final Animation<double> animation;
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.animation,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? const [
                      Color(0xFF2B2D30),
                      Color(0xFF3C3F41),
                      Color(0xFF2B2D30),
                    ]
                  : const [
                      Color(0xFFE0E0E0),
                      Color(0xFFF0F0F0),
                      Color(0xFFE0E0E0),
                    ],
              stops: [
                (animation.value - 0.3).clamp(0.0, 1.0),
                animation.value.clamp(0.0, 1.0),
                (animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

