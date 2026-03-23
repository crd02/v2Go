import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:v2go/managers/app_settings_manager.dart';
import 'package:v2go/managers/process_manager.dart';
import 'package:v2go/models/singbox_config_model.dart';
import 'package:v2go/utils/platform_binary.dart';

/// Sing-box 服务管理
class SingBoxService {
  static String get singBoxExePath => PlatformBinary.singBox;
  static const String _processName = 'sing-box';

  final ProcessManager _processManager = ProcessManager();
  String? _configFilePath;

  /// 进程退出回调
  Function(int exitCode)? onProcessExit;
  
  /// 标准输出回调
  Function(String data)? onStdout;
  
  /// 标准错误输出回调
  Function(String data)? onStderr;

  /// 是否正在运行
  bool get isRunning => _processManager.isProcessRunning(_processName);

  /// 生成配置文件
  /// 所有配置都是固定的
  Future<String> generateTunConfig() async {
    // 使用结构体定义配置，便于将来动态增加节点
    final config = SingBoxConfig(
      log: LogConfig(level: 'debug', timestamp: true),
      dns: DnsConfig(
        servers: [
          DnsServer(
            tag: 'google',
            type: 'tls',
            server: '8.8.8.8',
            detour: 'proxy',
          ),
          DnsServer(server: '223.5.5.5', type: 'udp', tag: 'local_local'),
        ],
        rules: [
          DnsRule(server: 'local_local', domain: ['vpn2.tingfengshiye.top']),
          DnsRule(server: 'hosts_dns', ipAcceptAny: true),
          DnsRule(server: 'remote_dns', clashMode: 'Global'),
          DnsRule(server: 'direct_dns', clashMode: 'Direct'),
        ],
        final_: 'local_local',
      ),
      inbounds: [
        InboundConfig(
          type: 'tun',
          tag: 'tun-in',
          address: ['172.19.0.1/30'],
          autoRoute: true,
          strictRoute: true,
          stack: 'system',
          sniff: true,
        ),
      ],
      outbounds: [
        OutboundConfig(
          server: '127.0.0.1',
          serverPort: AppSettingsManager().socksPort,
          version: '5',
          type: 'socks',
          tag: 'proxy',
        ),
        OutboundConfig(type: 'direct', tag: 'direct'),
      ],
      route: RouteConfig(
        defaultDomainResolver: DomainResolver(server: 'google', strategy: ''),
        rules: [
          RouteRule(
            outbound: 'direct',
            processName: _getProxyProcessNames(),
          ),
          RouteRule(action: 'sniff'),
          RouteRule(protocol: ['dns'], action: 'hijack-dns'),
        ],
        finalOutbound: 'proxy',
        autoDetectInterface: true,
      ),
    );

    // 获取程序运行目录下的 config 目录
    final configDir = Directory(path.join(Directory.current.path, 'config'));

    // 如果目录不存在，则创建
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    final configFile = File(
      path.join(configDir.path, 'v2go_singbox_config.json'),
    );

    // 写入配置文件
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
    );

    _configFilePath = configFile.path;
    return configFile.path;
  }

  /// 启动 sing-box
  ///
  /// [configPath] 配置文件路径
  Future<bool> start(String configPath) async {
    if (isRunning) {
      print('Sing-box 已经在运行');
      return false;
    }

    try {
      final success = await _processManager.startProcess(
        name: _processName,
        executable: singBoxExePath,
        arguments: ['run', '-c', configPath],
        onStdout: (data) {
          print('[Sing-box] $data');
          if (onStdout != null) {
            onStdout!(data);
          }
        },
        onStderr: (data) {
          print('[Sing-box Error] $data');
          if (onStderr != null) {
            onStderr!(data);
          }
        },
        onExit: (code) {
          print('Sing-box 进程退出，退出码: $code');
          final hadCallback = onProcessExit != null;
          if (hadCallback) {
            print('调用 onProcessExit 回调');
            Future(() {
              onProcessExit!(code);
            });
          } else {
            print('警告: onProcessExit 回调未设置');
          }
        },
      );

      if (!success) {
        print('启动 Sing-box 失败');
        return false;
      }

      print('Sing-box 启动成功');
      return true;
    } catch (e) {
      print('启动 Sing-box 失败: $e');
      return false;
    }
  }

  /// 停止 sing-box
  Future<void> stop() async {
    if (!isRunning) {
      print('Sing-box 未运行');
      return;
    }

    try {
      print('正在停止 Sing-box...');
      await _processManager.stopProcess(_processName);
      print('Sing-box 已停止');

      // 清理配置文件
      if (_configFilePath != null) {
        final configFile = File(_configFilePath!);
        if (await configFile.exists()) {
          await configFile.delete();
          print('配置文件已删除');
        }
        _configFilePath = null;
      }
    } catch (e) {
      print('停止 Sing-box 失败: $e');
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    await stop();
  }

  List<String> _getProxyProcessNames() {
    final baseNames = [
      'v2ray',
      'xray',
      'mihomo-windows-amd64-v1',
      'mihomo-windows-amd64-compatible',
      'mihomo-windows-amd64',
      'mihomo-linux-amd64',
      'clash',
      'mihomo',
      'hysteria',
      'naive',
      'naiveproxy',
      'tuic-client',
      'tuic',
      'sing-box-client',
      'sing-box',
      'juicity-client',
      'juicity',
      'hysteria-windows-amd64',
      'hysteria-linux-amd64',
      'brook_windows_amd64',
      'brook_linux_amd64',
      'brook',
      'overtls-bin',
      'overtls',
      'shadowquic',
      'mieru',
    ];

    if (Platform.isWindows) {
      return baseNames.map((name) => '$name.exe').toList();
    } else {
      return baseNames;
    }
  }
}
