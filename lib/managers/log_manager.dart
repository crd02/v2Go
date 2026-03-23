import 'package:flutter/foundation.dart';

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  String get formattedTimestamp {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}

/// 日志级别
enum LogLevel { info, warning, error, debug }

/// 日志管理器
/// 管理应用程序的所有日志，支持订阅日志更新
class LogManager extends ChangeNotifier {
  static final LogManager _instance = LogManager._internal();

  factory LogManager() {
    return _instance;
  }

  LogManager._internal();

  final List<LogEntry> _logs = [];
  final int _maxLogCount = 100; // 最多保存1000条日志

  List<LogEntry> get logs => List.unmodifiable(_logs);

  /// 添加信息日志
  void info(String message) {
    _addLog(message, LogLevel.info);
  }

  /// 添加警告日志
  void warning(String message) {
    _addLog(message, LogLevel.warning);
  }

  /// 添加错误日志
  void error(String message) {
    _addLog(message, LogLevel.error);
  }

  /// 添加调试日志
  void debug(String message) {
    _addLog(message, LogLevel.debug);
  }

  /// 添加日志
  void _addLog(String message, LogLevel level) {

    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    );
    _logs.add(entry);
    if (_logs.length > _maxLogCount) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }

  /// 清空所有日志
  void clear() {
    _logs.clear();
    notifyListeners();
  }

  /// 获取最新的 n 条日志
  List<LogEntry> getRecentLogs(int count) {
    if (_logs.length <= count) {
      return List.unmodifiable(_logs);
    }
    return List.unmodifiable(_logs.sublist(_logs.length - count));
  }
}
