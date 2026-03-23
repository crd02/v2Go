import 'dart:io';
import 'system_proxy.dart';

class SystemProxyMacOS implements SystemProxy {
  @override
  Future<bool> enableProxy(String host, int port) async {
    try {
      print('正在启用 macOS 系统代理...');

      final networkService = await _getNetworkService();
      if (networkService == null) {
        print('无法获取网络服务');
        return false;
      }

      final proxyTypes = [
        'webproxy',
        'securewebproxy',
        'socksfirewallproxy',
        'ftpproxy',
      ];

      for (var proxyType in proxyTypes) {
        await Process.run('networksetup', [
          '-set$proxyType',
          networkService,
          host,
          port.toString(),
        ]);

        await Process.run('networksetup', [
          '-set${proxyType}state',
          networkService,
          'on',
        ]);
      }

      print('macOS 系统代理已启用: $host:$port');
      return true;
    } catch (e) {
      print('启用 macOS 系统代理失败: $e');
      return false;
    }
  }

  @override
  Future<bool> disableProxy() async {
    try {
      print('正在禁用 macOS 系统代理...');

      final networkService = await _getNetworkService();
      if (networkService == null) {
        print('无法获取网络服务');
        return false;
      }

      final proxyTypes = [
        'webproxy',
        'securewebproxy',
        'socksfirewallproxy',
        'ftpproxy',
      ];

      for (var proxyType in proxyTypes) {
        await Process.run('networksetup', [
          '-set${proxyType}state',
          networkService,
          'off',
        ]);
      }

      print('macOS 系统代理已禁用');
      return true;
    } catch (e) {
      print('禁用 macOS 系统代理失败: $e');
      return false;
    }
  }

  Future<String?> _getNetworkService() async {
    try {
      final result = await Process.run('networksetup', ['-listallnetworkservices']);
      if (result.exitCode != 0) {
        return null;
      }

      final services = (result.stdout as String)
          .split('\n')
          .where((line) => line.isNotEmpty && !line.startsWith('*'))
          .toList();

      if (services.isEmpty) {
        return null;
      }

      for (var service in services) {
        if (service.toLowerCase().contains('wi-fi') ||
            service.toLowerCase().contains('ethernet')) {
          return service;
        }
      }

      return services.first;
    } catch (e) {
      print('获取网络服务失败: $e');
      return null;
    }
  }
}

