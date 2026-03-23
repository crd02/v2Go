import 'package:flutter/material.dart';
import 'dart:async';
import '../services/latency_tester.dart';

/// 延迟指示器组件
/// 每隔指定时间自动测试服务器延迟并显示
class LatencyIndicatorWidget extends StatefulWidget {
  final String address;
  final int port;
  final Duration testInterval;
  final bool isActive; // 是否激活测试

  const LatencyIndicatorWidget({
    super.key,
    required this.address,
    required this.port,
    this.testInterval = const Duration(seconds: 5),
    this.isActive = true,
    this.backgroundColor,
  });

  final Color? backgroundColor;

  @override
  State<LatencyIndicatorWidget> createState() => _LatencyIndicatorWidgetState();
}

class _LatencyIndicatorWidgetState extends State<LatencyIndicatorWidget> {
  int _currentLatency = -1;
  Timer? _timer;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _startLatencyTest();
    }
  }

  @override
  void didUpdateWidget(LatencyIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果激活状态改变或服务器地址改变，重新开始测试
    if (widget.isActive != oldWidget.isActive ||
        widget.address != oldWidget.address ||
        widget.port != oldWidget.port) {
      _stopLatencyTest();
      if (widget.isActive) {
        _currentLatency = -1;
        _startLatencyTest();
      } else {
        setState(() {
          _currentLatency = -1;
        });
      }
    }
  }

  @override
  void dispose() {
    _stopLatencyTest();
    super.dispose();
  }

  void _startLatencyTest() {
    if (_isTesting) return;
    _isTesting = true;

    // 立即执行一次测试
    _testLatency();

    // 启动定时器
    _timer = Timer.periodic(widget.testInterval, (_) {
      _testLatency();
    });
  }

  void _stopLatencyTest() {
    _isTesting = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _testLatency() async {
    if (!_isTesting || !mounted) return;
    if (widget.address.isEmpty) {
      setState(() {
        _currentLatency = -1;
      });
      return;
    }

    final latency = await LatencyTester.testLatency(
      widget.address,
      widget.port,
    );
    if (mounted && _isTesting) {
      setState(() {
        _currentLatency = latency < 0 ? 9999 : latency;
      });
    }
  }

  Color _getLatencyColor() {
    final colorIndex = LatencyTester.getLatencyColorIndex(_currentLatency);
    switch (colorIndex) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      default:
        return Colors.red.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getLatencyColor();
    final signalStrength = LatencyTester.getSignalStrength(_currentLatency);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? const Color.fromARGB(255, 63, 63, 62),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态指示灯
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isActive ? color : Colors.grey.shade600,
              boxShadow: widget.isActive && _currentLatency > 0
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
          // 信号强度图标
          _SignalStrengthIcon(
            strength: signalStrength,
            color: widget.isActive ? color : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          // 延迟文本
          Text(
            widget.isActive
                ? LatencyTester.formatLatency(_currentLatency)
                : '0 ms',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 信号强度图标组件
class _SignalStrengthIcon extends StatelessWidget {
  final int strength; // 0-3
  final Color color;

  const _SignalStrengthIcon({required this.strength, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SignalBar(height: 4, isActive: strength >= 1, color: color),
          _SignalBar(height: 8, isActive: strength >= 2, color: color),
          _SignalBar(height: 12, isActive: strength >= 3, color: color),
        ],
      ),
    );
  }
}

/// 信号柱组件
class _SignalBar extends StatelessWidget {
  final double height;
  final bool isActive;
  final Color color;

  const _SignalBar({
    required this.height,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// 用于在 ServerCard 中显示的紧凑延迟指示器
class CompactLatencyIndicator extends StatefulWidget {
  final String address;
  final int port;
  final Duration testInterval;
  final int? initialLatency; // 可选的初始延迟值

  const CompactLatencyIndicator({
    super.key,
    required this.address,
    required this.port,
    this.testInterval = const Duration(seconds: 5),
    this.initialLatency,
  });

  @override
  State<CompactLatencyIndicator> createState() =>
      _CompactLatencyIndicatorState();
}

class _CompactLatencyIndicatorState extends State<CompactLatencyIndicator> {
  int _currentLatency = -1;
  Timer? _timer;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _currentLatency = widget.initialLatency ?? -1;
    _startLatencyTest();
  }

  @override
  void didUpdateWidget(CompactLatencyIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.address != oldWidget.address || widget.port != oldWidget.port) {
      _stopLatencyTest();
      _currentLatency = widget.initialLatency ?? -1;
      _startLatencyTest();
    }
  }

  @override
  void dispose() {
    _stopLatencyTest();
    super.dispose();
  }

  void _startLatencyTest() {
    if (_isTesting) return;
    _isTesting = true;

    // 如果没有初始延迟值，立即执行一次测试
    if (widget.initialLatency == null) {
      _testLatency();
    }

    // 启动定时器
    _timer = Timer.periodic(widget.testInterval, (_) {
      _testLatency();
    });
  }

  void _stopLatencyTest() {
    _isTesting = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _testLatency() async {
    if (!_isTesting || !mounted) return;
    if (widget.address.isEmpty) return;

    final latency = await LatencyTester.testLatency(
      widget.address,
      widget.port,
    );
    if (mounted && _isTesting) {
      setState(() {
        _currentLatency = latency < 0 ? 9999 : latency;
      });
    }
  }

  Color _getLatencyColor() {
    final colorIndex = LatencyTester.getLatencyColorIndex(_currentLatency);
    switch (colorIndex) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      default:
        return Colors.red.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getLatencyColor();
    final signalStrength = LatencyTester.getSignalStrength(_currentLatency);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LatencyTester.formatLatency(_currentLatency),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        _SignalStrengthIcon(strength: signalStrength, color: color),
      ],
    );
  }
}
