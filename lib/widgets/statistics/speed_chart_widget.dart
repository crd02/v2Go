import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:v2go/services/traffic_stats_service.dart';

/// 速度历史数据点
class SpeedHistoryPoint {
  final DateTime time;
  final double downloadSpeed;
  final double uploadSpeed;

  SpeedHistoryPoint({
    required this.time,
    required this.downloadSpeed,
    required this.uploadSpeed,
  });
}

/// 折线图组件 - 显示下载和上传速度历史
class SpeedChartWidget extends StatefulWidget {
  final ValueNotifier<List<SpeedHistoryPoint>> historyNotifier;

  const SpeedChartWidget({
    super.key,
    required this.historyNotifier,
  });

  @override
  State<SpeedChartWidget> createState() => _SpeedChartWidgetState();
}

class _SpeedChartWidgetState extends State<SpeedChartWidget> {
  final int _maxHistoryPoints = 60; // 保留60秒的历史数据
  final TrafficStatsService _trafficStatsService = TrafficStatsService();

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _trafficStatsService.statsNotifier.removeListener(_onTrafficStatsChanged);
    super.dispose();
  }

  void _startListening() {
    _trafficStatsService.statsNotifier.addListener(_onTrafficStatsChanged);
  }

  void _onTrafficStatsChanged() {
    final stats = _trafficStatsService.statsNotifier.value;
    final now = DateTime.now();
    
    // 只有当有速度数据时才添加到历史记录
    if (stats.downloadSpeed > 0 || stats.uploadSpeed > 0 || widget.historyNotifier.value.isNotEmpty) {
      // 添加新数据点
      final newPoint = SpeedHistoryPoint(
        time: now,
        downloadSpeed: stats.downloadSpeed,
        uploadSpeed: stats.uploadSpeed,
      );

      final history = List<SpeedHistoryPoint>.from(widget.historyNotifier.value);
      history.add(newPoint);

      // 基于时间清理超过1分钟的旧数据（而不是简单的点数限制）
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      history.removeWhere((point) => point.time.isBefore(oneMinuteAgo));
      
      // 额外保护：即使时间未超过1分钟，也限制最大点数防止异常情况
      while (history.length > _maxHistoryPoints) {
        history.removeAt(0);
      }

      widget.historyNotifier.value = history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和图例
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '速度历史',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem('下载', Colors.green, isDark),
                  const SizedBox(width: 16),
                  _buildLegendItem('上传', Colors.blue, isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 折线图
          Expanded(
            child: ValueListenableBuilder<List<SpeedHistoryPoint>>(
              valueListenable: widget.historyNotifier,
              builder: (context, history, child) {
                if (history.isEmpty) {
                  return Center(
                    child: Text(
                      '暂无数据',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return _SpeedChart(
                  history: history,
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? Colors.white.withOpacity(0.7)
                : Colors.black.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 折线图绘制组件
class _SpeedChart extends StatelessWidget {
  final List<SpeedHistoryPoint> history;
  final bool isDark;

  const _SpeedChart({
    required this.history,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpeedChartPainter(
        history: history,
        isDark: isDark,
      ),
      child: Container(),
    );
  }
}

/// 折线图画笔
class _SpeedChartPainter extends CustomPainter {
  final List<SpeedHistoryPoint> history;
  final bool isDark;

  // 复用 TextPainter 以避免内存泄漏
  static final TextPainter _sharedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  _SpeedChartPainter({
    required this.history,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    // 找出最大速度值用于缩放
    double maxSpeed = 1.0;
    for (var point in history) {
      maxSpeed = math.max(maxSpeed, math.max(point.downloadSpeed, point.uploadSpeed));
    }
    maxSpeed = maxSpeed * 1.2; // 留出20%的空间

    // 绘制下载速度曲线
    _drawSpeedLine(
      canvas,
      size,
      history.map((p) => p.downloadSpeed).toList(),
      Colors.green,
      maxSpeed,
    );

    // 绘制上传速度曲线
    _drawSpeedLine(
      canvas,
      size,
      history.map((p) => p.uploadSpeed).toList(),
      Colors.blue,
      maxSpeed,
    );

    // 绘制Y轴标签
    _drawYAxisLabels(canvas, size, maxSpeed);
    
    // 绘制X轴时间标签
    _drawXAxisLabels(canvas, size);
  }

  void _drawSpeedLine(
    Canvas canvas,
    Size size,
    List<double> speeds,
    Color color,
    double maxSpeed,
  ) {
    if (speeds.isEmpty) return;

    final chartWidth = size.width - 40; // 留出Y轴空间
    final chartHeight = size.height - 25; // 留出X轴标签空间
    final maxPoints = 60; // 与 _maxHistoryPoints 保持一致
    final pointSpacing = chartWidth / (maxPoints - 1);

    // 计算起始X位置，使最新数据点始终在右侧
    final startX = 40 + chartWidth - (speeds.length - 1) * pointSpacing;

    // 构建曲线路径
    final path = Path();
    for (int i = 0; i < speeds.length; i++) {
      final x = startX + pointSpacing * i;
      final y = chartHeight - (speeds[i] / maxSpeed * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // 绘制渐变填充（先绘制填充，这样曲线会在上面）
    final gradientPath = Path()..addPath(path, Offset.zero);
    final endX = startX + (speeds.length - 1) * pointSpacing;
    gradientPath.lineTo(endX, chartHeight);
    gradientPath.lineTo(startX, chartHeight);
    gradientPath.close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));

    canvas.drawPath(gradientPath, gradientPaint);

    // 绘制曲线
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // 绘制数据点
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < speeds.length; i++) {
      final x = startX + pointSpacing * i;
      final y = chartHeight - (speeds[i] / maxSpeed * chartHeight);
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  void _drawYAxisLabels(Canvas canvas, Size size, double maxSpeed) {
    final chartHeight = size.height - 25; // 留出X轴标签空间

    for (int i = 0; i <= 5; i++) {
      final value = maxSpeed / 5 * i;
      final y = chartHeight - (chartHeight / 5 * i);

      _sharedTextPainter.text = TextSpan(
        text: value.toStringAsFixed(1),
        style: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
          fontSize: 10,
        ),
      );
      _sharedTextPainter.layout();
      _sharedTextPainter.paint(canvas, Offset(0, y - _sharedTextPainter.height / 2));
    }
  }

  void _drawXAxisLabels(Canvas canvas, Size size) {
    final chartWidth = size.width - 40; // 留出Y轴空间
    final chartHeight = size.height - 25; // 留出X轴标签空间
    final maxPoints = 60; // 与 _maxHistoryPoints 保持一致
    final pointSpacing = chartWidth / (maxPoints - 1);

    // 计算起始X位置
    final startX = 40 + chartWidth - (history.length - 1) * pointSpacing;

    // 每10个数据点显示一个时间标签
    final labelInterval = 10;
    
    for (int i = 0; i < history.length; i += labelInterval) {
      final x = startX + pointSpacing * i;
      final time = history[i].time;
      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

      _sharedTextPainter.text = TextSpan(
        text: timeStr,
        style: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
          fontSize: 9,
        ),
      );
      _sharedTextPainter.layout();
      
      // 将时间标签绘制在图表底部，居中对齐
      _sharedTextPainter.paint(
        canvas,
        Offset(x - _sharedTextPainter.width / 2, chartHeight + 5),
      );
    }

    // 始终显示最后一个数据点的时间（最新时间）
    if (history.isNotEmpty && history.length % labelInterval != 1) {
      final lastIndex = history.length - 1;
      final x = startX + pointSpacing * lastIndex;
      final time = history[lastIndex].time;
      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

      _sharedTextPainter.text = TextSpan(
        text: timeStr,
        style: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
          fontSize: 9,
        ),
      );
      _sharedTextPainter.layout();
      _sharedTextPainter.paint(
        canvas,
        Offset(x - _sharedTextPainter.width / 2, chartHeight + 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedChartPainter oldDelegate) {
    return oldDelegate.history != history || oldDelegate.isDark != isDark;
  }
}
