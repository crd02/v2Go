import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:v2go/utils/platform_binary.dart';

/// 流量统计数据
class TrafficStats {
  final int totalDownlink;  // 总下载字节数
  final int totalUplink;    // 总上传字节数
  final double downloadSpeed; // 下载速度 KB/s
  final double uploadSpeed;   // 上传速度 KB/s

  const TrafficStats({
    this.totalDownlink = 0,
    this.totalUplink = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
  });

  TrafficStats copyWith({
    int? totalDownlink,
    int? totalUplink,
    double? downloadSpeed,
    double? uploadSpeed,
  }) {
    return TrafficStats(
      totalDownlink: totalDownlink ?? this.totalDownlink,
      totalUplink: totalUplink ?? this.totalUplink,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
    );
  }

  /// 格式化流量显示（自动转换单位：MB/GB）
  String formatTraffic(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(2)} MB';
  }

  /// 获取格式化的下载流量
  String get formattedDownload => formatTraffic(totalDownlink);

  /// 获取格式化的上传流量
  String get formattedUpload => formatTraffic(totalUplink);
}

/// 流量统计服务 - 单例模式
class TrafficStatsService {
  static final TrafficStatsService _instance = TrafficStatsService._internal();
  factory TrafficStatsService() => _instance;
  TrafficStatsService._internal();

  Timer? _timer;
  int _previousDownlink = 0;
  int _previousUplink = 0;
  
  final String _xrayPath = PlatformBinary.xray;
  final String _apiServer = '127.0.0.1:10085';

  // 流量统计数据通知器
  final ValueNotifier<TrafficStats> statsNotifier = ValueNotifier(const TrafficStats());

  /// 启动流量统计
  void startStats() {
    stopStats();
    _resetStats();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchStats());
  }

  /// 停止流量统计
  void stopStats() {
    _timer?.cancel();
    _timer = null;
  }

  /// 重置统计数据
  void _resetStats() {
    _previousDownlink = 0;
    _previousUplink = 0;
    statsNotifier.value = const TrafficStats();
  }

  /// 获取流量统计
  Future<void> _fetchStats() async {
    try {
      final downlink = await _getTrafficStats('downlink');
      final uplink = await _getTrafficStats('uplink');

      if (downlink != null && uplink != null) {
        // 计算速度（字节/秒）
        final downloadSpeed = _previousDownlink == 0 
            ? 0.0 
            : (downlink - _previousDownlink).toDouble();
        final uploadSpeed = _previousUplink == 0 
            ? 0.0 
            : (uplink - _previousUplink).toDouble();

        _previousDownlink = downlink;
        _previousUplink = uplink;

        // 转换为 KB/s
        final downloadSpeedKB = downloadSpeed / 1024;
        final uploadSpeedKB = uploadSpeed / 1024;

        // 更新统计数据
        statsNotifier.value = TrafficStats(
          totalDownlink: downlink,
          totalUplink: uplink,
          downloadSpeed: downloadSpeedKB,
          uploadSpeed: uploadSpeedKB,
        );
      }
    } catch (e) {
      debugPrint('获取流量统计失败: $e');
    }
  }

  /// 调用 xray API 获取流量统计
  Future<int?> _getTrafficStats(String direction) async {
    try {
      final statName = 'outbound>>>proxy>>>traffic>>>$direction';
      final result = await Process.run(
        _xrayPath,
        ['api', 'stats', '--server=$_apiServer', '-name', statName],
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final jsonData = jsonDecode(output) as Map<String, dynamic>;
        final stat = jsonData['stat'] as Map<String, dynamic>?;
        if (stat != null) {
          final value = stat['value'];
          if (value is int) {
            return value;
          } else if (value is String) {
            return int.tryParse(value);
          }
        }
      }
    } catch (e) {
      debugPrint('调用 xray API 失败 ($direction): $e');
    }
    return null;
  }

  /// 释放资源
  void dispose() {
    stopStats();
    statsNotifier.dispose();
  }
}
