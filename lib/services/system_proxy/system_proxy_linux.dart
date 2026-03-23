import 'dart:io';
import 'system_proxy.dart';

class SystemProxyLinux implements SystemProxy {
  @override
  Future<bool> enableProxy(String host, int port) async {
    try {
      print('正在启用 Linux KDE 系统代理...');
      final proxyUrl = 'http://$host $port';

      final proxySettings = {
        'ProxyType': '1',
        'ftpProxy': proxyUrl,
        'httpProxy': proxyUrl,
        'httpsProxy': proxyUrl,
        'socksProxy': proxyUrl,
      };

      for (var entry in proxySettings.entries) {
        final result = await Process.run('kwriteconfig6', [
          '--file',
          'kioslaverc',
          '--group',
          'Proxy Settings',
          '--key',
          entry.key,
          entry.value,
        ]);

        if (result.exitCode != 0) {
          print('设置 ${entry.key} 失败: ${result.stderr}');
        }
      }

      await _notifyKDE();

      print('Linux KDE 系统代理已启用: $host:$port');
      return true;
    } catch (e) {
      print('启用 Linux 系统代理失败: $e');
      return false;
    }
  }

  @override
  Future<bool> disableProxy() async {
    try {
      print('正在禁用 Linux KDE 系统代理...');

      final result = await Process.run('kwriteconfig6', [
        '--file',
        'kioslaverc',
        '--group',
        'Proxy Settings',
        '--key',
        'ProxyType',
        '0',
      ]);

      if (result.exitCode != 0) {
        print('禁用代理失败: ${result.stderr}');
        return false;
      }

      final keysToDelete = ['ftpProxy', 'httpProxy', 'httpsProxy', 'socksProxy'];
      for (var key in keysToDelete) {
        await Process.run('kwriteconfig6', [
          '--file',
          'kioslaverc',
          '--group',
          'Proxy Settings',
          '--key',
          key,
          '--delete',
        ]);
      }

      await _notifyKDE();

      print('Linux KDE 系统代理已禁用');
      return true;
    } catch (e) {
      print('禁用 Linux 系统代理失败: $e');
      return false;
    }
  }

  Future<void> _notifyKDE() async {
    try {
      await Process.run('dbus-send', [
        '--type=signal',
        '/KIO/Scheduler',
        'org.kde.KIO.Scheduler.reparseSlaveConfiguration',
        'string:',
      ]);
      print('KDE 代理设置已刷新');
    } catch (e) {
      print('刷新 KDE 代理设置失败: $e');
    }
  }
}

