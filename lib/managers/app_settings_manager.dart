import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// 路由模式枚举
enum RoutingMode {
  /// 规则分流 - 国内直连，国外代理
  rule,
  /// 全局代理 - 所有流量走代理
  global,
  /// 全局直连 - 所有流量直连
  direct,
}

/// 路由模式扩展
extension RoutingModeExtension on RoutingMode {
  String get displayName {
    switch (this) {
      case RoutingMode.rule:
        return '规则分流';
      case RoutingMode.global:
        return '全局代理';
      case RoutingMode.direct:
        return '全局直连';
    }
  }

  String get description {
    switch (this) {
      case RoutingMode.rule:
        return '国内直连，国外代理';
      case RoutingMode.global:
        return '所有流量走代理';
      case RoutingMode.direct:
        return '所有流量直连';
    }
  }
}

/// App Settings Manager
/// Manages application-wide settings using SharedPreferences
class AppSettingsManager extends ChangeNotifier {
  static final AppSettingsManager _instance = AppSettingsManager._internal();

  factory AppSettingsManager() {
    return _instance;
  }

  AppSettingsManager._internal() {
    _loadSettings();
  }

  // --- Keys ---
  static const String _autoStartKey = 'auto_start';
  static const String _autoConnectKey = 'auto_connect';
  static const String _systemProxyKey = 'system_proxy';
  static const String _httpPortKey = 'http_port';
  static const String _socksPortKey = 'socks_port';
  static const String _lastSelectedServerIdKey = 'last_selected_server_id';
  static const String _routingModeKey = 'routing_mode';

  // --- Default Values ---
  static const bool _defaultAutoStart = false;
  static const bool _defaultAutoConnect = false;
  static const bool _defaultSystemProxy = true;
  static const int _defaultHttpPort = 20809;
  static const int _defaultSocksPort = 20808;
  static const RoutingMode _defaultRoutingMode = RoutingMode.rule;

  // --- State Properties ---
  bool _autoStart = _defaultAutoStart;
  bool _autoConnect = _defaultAutoConnect;
  bool _systemProxy = _defaultSystemProxy;
  int _httpPort = _defaultHttpPort;
  int _socksPort = _defaultSocksPort;
  String? _lastSelectedServerId;
  RoutingMode _routingMode = _defaultRoutingMode;

  // --- Getters ---
  bool get autoStart => _autoStart;
  bool get autoConnect => _autoConnect;
  bool get systemProxy => _systemProxy;
  int get httpPort => _httpPort;
  int get socksPort => _socksPort;
  String? get lastSelectedServerId => _lastSelectedServerId;
  RoutingMode get routingMode => _routingMode;

  // --- Loading ---
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoStart = prefs.getBool(_autoStartKey) ?? _defaultAutoStart;
      _autoConnect = prefs.getBool(_autoConnectKey) ?? _defaultAutoConnect;
      _systemProxy = prefs.getBool(_systemProxyKey) ?? _defaultSystemProxy;
      _httpPort = prefs.getInt(_httpPortKey) ?? _defaultHttpPort;
      _socksPort = prefs.getInt(_socksPortKey) ?? _defaultSocksPort;
      _lastSelectedServerId = prefs.getString(_lastSelectedServerIdKey);
      final routingModeIndex = prefs.getInt(_routingModeKey);
      if (routingModeIndex != null && routingModeIndex >= 0 && routingModeIndex < RoutingMode.values.length) {
        _routingMode = RoutingMode.values[routingModeIndex];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
  }

  // --- Setters ---

  Future<void> setAutoStart(bool value) async {
    if (_autoStart == value) return;
    _autoStart = value;
    notifyListeners();
    await _saveBool(_autoStartKey, value);
    await _updateRegistry(value);
  }

  Future<void> setAutoConnect(bool value) async {
    if (_autoConnect == value) return;
    _autoConnect = value;
    notifyListeners();
    await _saveBool(_autoConnectKey, value);
  }

  Future<void> setSystemProxy(bool value) async {
    if (_systemProxy == value) return;
    _systemProxy = value;
    notifyListeners();
    await _saveBool(_systemProxyKey, value);
  }

  Future<void> setHttpPort(int value) async {
    if (_httpPort == value) return;
    _httpPort = value;
    notifyListeners();
    await _saveInt(_httpPortKey, value);
  }

  Future<void> setSocksPort(int value) async {
    if (_socksPort == value) return;
    _socksPort = value;
    notifyListeners();
    await _saveInt(_socksPortKey, value);
  }

  Future<void> setLastSelectedServerId(String? value) async {
    if (_lastSelectedServerId == value) return;
    _lastSelectedServerId = value;
    notifyListeners();
    await _saveString(_lastSelectedServerIdKey, value);
  }

  Future<void> setRoutingMode(RoutingMode value) async {
    if (_routingMode == value) return;
    _routingMode = value;
    notifyListeners();
    await _saveInt(_routingModeKey, value.index);
  }

  // --- Private Helpers ---
  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Failed to save bool setting ($key): $e');
    }
  }

  Future<void> _saveInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (e) {
      debugPrint('Failed to save int setting ($key): $e');
    }
  }

  Future<void> _saveString(String key, String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('Failed to save string setting ($key): $e');
    }
  }

  /// 更新注册表以实现开机自启
  Future<void> _updateRegistry(bool enable) async {
    if (!Platform.isWindows) return;

    const keyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
    const appName = 'V2Go';

    try {
      if (enable) {
        String appPath = Platform.resolvedExecutable;
        // 添加 --hidewindow 参数，开机启动时隐藏窗口
        String command = '"$appPath" --hidewindow';

        await Process.run('reg', [
          'add',
          'HKCU\\$keyPath',
          '/v',
          appName,
          '/t',
          'REG_SZ',
          '/d',
          command,
          '/f',
        ]);
        debugPrint('Added to registry: $command');
      } else {
        await Process.run('reg', [
          'delete',
          'HKCU\\$keyPath',
          '/v',
          appName,
          '/f',
        ]);
        debugPrint('Removed from registry');
      }
    } catch (e) {
      debugPrint('Registry update failed: $e');
    }
  }

  /// 在应用启动时自动设置开机自启动
  Future<void> ensureAutoStartEnabled() async {
    if (!Platform.isWindows) return;

    const keyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
    const appName = 'V2Go';

    try {
      await _updateRegistry(true);
      _autoStart = true;
      await _saveBool(_autoStartKey, true);
      debugPrint('自动添加开机自启动');
    } catch (e) {
      debugPrint('检查开机自启动状态失败: $e');
    }
  }
}
