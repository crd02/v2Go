import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:v2go/managers/app_settings_manager.dart';
import 'package:v2go/utils/platform_binary.dart';
import '../models/v2ray_config_model.dart';
import "../core/database/database_helper.dart";
import '../services/singbox_service.dart';
import '../services/system_proxy/system_proxy.dart';
import '../utils/xray_config_generator.dart';
import 'log_manager.dart';
import 'process_manager.dart';

enum ProxyConnectionState { disconnected, connecting, connected, disconnecting }

enum ProxyMode { noProxy, proxy, tun }

class ConnectManager extends ChangeNotifier {
  static final ConnectManager _instance = ConnectManager._internal();

  factory ConnectManager() {
    return _instance;
  }

  ConnectManager._internal() {
    _systemProxy = SystemProxy.create();
    _logManager = LogManager();
    _processManager = ProcessManager();
  }

  ProxyConnectionState _state = ProxyConnectionState.disconnected;
  ProxyConnectionState get state => _state;

  String? _currentServerId;
  String? get currentServerId => _currentServerId;

  static const String _xrayProcessName = 'xray';
  final String _xrayPath = PlatformBinary.xray;

  final String _configFileName = 'config-running.json';
  String get _configPath =>
      '${Directory.current.path}${Platform.pathSeparator}config${Platform.pathSeparator}$_configFileName';

  int get proxyPort => AppSettingsManager().socksPort;

  String get proxyAddress => '127.0.0.1';

  ProxyMode _currentMode = ProxyMode.noProxy;
  ProxyMode get currentMode => _currentMode;

  ProxyMode? _switchingToMode;
  ProxyMode? get switchingToMode => _switchingToMode;

  bool get isTunMode => _currentMode == ProxyMode.tun;

  SingBoxService? _singBoxService;
  bool _isIntentionalSingBoxStop = false;

  late final SystemProxy _systemProxy;
  late final LogManager _logManager;
  late final ProcessManager _processManager;

  Function(String)? onError;

  void _updateState(ProxyConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  void _notifyError(String message) {
    _logManager.error(message);
    if (onError != null) {
      onError!(message);
    }
  }

  Future<void> switchMode(ProxyMode newMode) async {
    if (_switchingToMode != null) {
      _logManager.warning('模式切换中，请稍后再试');
      return;
    }

    if (_currentMode == newMode) return;

    _logManager.info('开始切换模式: ${_currentMode.name} -> ${newMode.name}');
    final oldMode = _currentMode;
    _currentMode = newMode;

    if (_state == ProxyConnectionState.connected) {
      _switchingToMode = newMode;
      notifyListeners();
      _applyModeChangeInBackground(oldMode, newMode);
    } else {
      _logManager.info('模式切换完成: ${newMode.name}（未连接状态）');
      notifyListeners();
    }
  }

  void _applyModeChangeInBackground(ProxyMode oldMode, ProxyMode newMode) {
    Future(() async {
      try {
        await _cleanupOldMode(oldMode);
        await _activateNewMode(newMode);
        _switchingToMode = null;
        _logManager.info('模式切换完成: ${newMode.name}');
        notifyListeners();
      } catch (e) {
        _logManager.error('切换模式失败: $e');
        _switchingToMode = null;
        notifyListeners();
        _notifyError('切换模式失败: $e');
      }
    });
  }

  void _activateNewModeInBackground(ProxyMode mode) {
    Future(() async {
      try {
        await _activateNewMode(mode);
      } catch (e) {
        print('激活模式失败: $e');
        _notifyError('激活模式失败: $e');
      }
    });
  }

  Future<void> _cleanupOldMode(ProxyMode mode) async {
    switch (mode) {
      case ProxyMode.proxy:
        _systemProxy.disableProxy();
        break;
      case ProxyMode.tun:
        await _stopSingBoxIntentionally();
        _logManager.info('sing-box 已停止');
        break;
      case ProxyMode.noProxy:
        break;
    }
  }

  Future<void> _activateNewMode(ProxyMode mode) async {
    switch (mode) {
      case ProxyMode.noProxy:
        _logManager.info('切换到无代理模式');
        break;
      case ProxyMode.proxy:
        _logManager.info('切换到代理模式');
        _systemProxy.enableProxy(proxyAddress, proxyPort);
        break;
      case ProxyMode.tun:
        _logManager.info('切换到 TUN 模式，启动 sing-box');
        await _startSingBox();
        break;
    }
  }

  Future<void> _startSingBox() async {
    _singBoxService = SingBoxService();
    _singBoxService!.onProcessExit = (exitCode) {
      if (_isIntentionalSingBoxStop) {
        _isIntentionalSingBoxStop = false;
        return;
      }
      _logManager.error('sing-box 进程异常退出 (退出码: $exitCode)');
      _handleSingBoxCrash();
    };

    _singBoxService!.onStdout = (data) {
      _logManager.debug('[sing-box] $data');
    };
    _singBoxService!.onStderr = (data) {
      _logManager.error('[sing-box] $data');
    };

    final configPath = await _singBoxService!.generateTunConfig();
    final success = await _singBoxService!.start(configPath);
    if (!success) {
      _logManager.error('启动 sing-box 失败');
      throw Exception('启动 sing-box 失败');
    }
    _logManager.info('sing-box 启动成功');
  }

  void _handleSingBoxCrash() {
    _logManager.warning('sing-box 异常退出，自动切换到无代理模式');
    _currentMode = ProxyMode.noProxy;
    notifyListeners();
    _notifyError('TUN 模式异常退出，已切换到无代理模式');
  }

  Future<bool> start(String serverId) async {
    if (_state == ProxyConnectionState.connected ||
        _state == ProxyConnectionState.connecting) {
      _logManager.warning('已经在连接状态，无法启动新连接');
      return false;
    }

    try {
      _updateState(ProxyConnectionState.connecting);
      _logManager.info('========== 开始连接服务器 ==========');

      final serverData = await DatabaseHelper().getServerById(serverId);
      if (serverData == null) {
        throw Exception('未找到服务器配置: $serverId');
      }
      _logManager.info('正在连接服务器: ${serverData['name']}');
      final configJsonString = serverData['config_json'] as String;
      final configJson = jsonDecode(configJsonString) as Map<String, dynamic>;
      final v2rayConfig = V2RayConfig.fromJson(configJson);
      final fullConfig = await XrayConfigGenerator.generateFullConfig(v2rayConfig);
      await _saveConfigToFile(fullConfig);
      await Future.delayed(Duration.zero);
      await _startXrayProcess();
      _currentServerId = serverId;

      if (AppSettingsManager().systemProxy && currentMode != ProxyMode.tun) {
        switchMode(ProxyMode.proxy);
      }
      _activateNewModeInBackground(_currentMode);
      _updateState(ProxyConnectionState.connected);
      _logManager.info(
        '连接成功: ${serverData['name']} (模式: ${_currentMode.name})',
      );
      return true;
    } catch (e) {
      _logManager.error('连接失败: $e');
      _notifyError('连接失败: $e');
      await stop();
      return false;
    }
  }

  Future<void> stop() async {
    if (_state == ProxyConnectionState.disconnected) {
      return;
    }
    try {
      _updateState(ProxyConnectionState.disconnecting);
      _switchingToMode = null;

      await _cleanupOldMode(_currentMode);
      await _stopXrayProcess();
      _currentServerId = null;
      _updateState(ProxyConnectionState.disconnected);
    } catch (e) {
      _notifyError('断开连接失败: $e');
      _switchingToMode = null;
      _updateState(ProxyConnectionState.disconnected);
    }
  }

  Future<void> serverChanged(String newServerId) async {
    _logManager.info('服务器改变: $newServerId');
    if (_state == ProxyConnectionState.connected ||
        _state == ProxyConnectionState.connecting) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 500));
      await start(newServerId);
    } else {
      _logManager.info('当前未连接，仅更新服务器选择');
      _currentServerId = newServerId;
      notifyListeners();
    }
  }

  Future<void> _stopSingBoxIntentionally() async {
    if (_singBoxService != null) {
      _isIntentionalSingBoxStop = true;
      await _singBoxService!.stop();
      _singBoxService = null;
    }
  }

  Future<void> _saveConfigToFile(Map<String, dynamic> config) async {
    try {
      final configFile = File(_configPath);
      final configDir = configFile.parent;
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }
      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(config);
      await configFile.writeAsString(jsonString);
    } catch (e) {
      throw Exception('保存配置文件失败: $e');
    }
  }

  Future<void> _startXrayProcess() async {
    try {
      final success = await _processManager.startProcess(
        name: _xrayProcessName,
        executable: _xrayPath,
        arguments: ['run', '-c', _configPath],
        onStdout: (data) {
          if(data.contains("[api -> api]")){
            return;
          }
          _logManager.info('[Xray] $data');
        },
        onStderr: (data) {
          _logManager.error('[Xray] $data');
        },
        onExit: (exitCode) {
          if (_state == ProxyConnectionState.connected) {
            Future(() {
              _logManager.error('Xray 进程意外退出 (退出码: $exitCode)');
              _notifyError('Xray 进程意外退出 (退出码: $exitCode)');
              _updateState(ProxyConnectionState.disconnected);
            });
          }
        },
      );

      if (!success) {
        throw Exception('启动 Xray 进程失败');
      }

      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      throw Exception('启动 Xray 进程失败: $e');
    }
  }

  Future<void> _stopXrayProcess() async {
    if (_processManager.isProcessRunning(_xrayProcessName)) {
      await _processManager.stopProcess(_xrayProcessName);
      _logManager.info('Xray 进程已停止');
    }
  }

  Future<void> dispose() async {
    try {
      if (_singBoxService != null) {
        _isIntentionalSingBoxStop = true;
        await _singBoxService!.stop();
        _singBoxService = null;
      }
    } catch (e) {
      print('停止 sing-box 时出错: $e');
    }

    try {
      await _stopXrayProcess();
      print('Xray 已停止');
    } catch (e) {
      print('停止 Xray 时出错: $e');
    }

    try {
      await _systemProxy.disableProxy();
      print('系统代理已禁用');
    } catch (e) {
      print('禁用系统代理时出错: $e');
    }

    // 使用进程管理器停止所有进程
    try {
      await _processManager.stopAllProcesses();
      print('所有进程已通过进程管理器停止');
    } catch (e) {
      print('停止进程时出错: $e');
    }

    _currentServerId = null;
    _state = ProxyConnectionState.disconnected;

    print('ConnectManager 资源清理完成');
    super.dispose();
  }
}
