import 'dart:io';
import 'system_proxy.dart';

class SystemProxyWindows implements SystemProxy {
  @override
  Future<bool> enableProxy(String host, int port) async {
    try {
      print('正在启用 Windows 系统代理...');
      final proxyServer = '$host:$port';

      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyServer',
        '/t',
        'REG_SZ',
        '/d',
        proxyServer,
        '/f',
      ]);

      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '1',
        '/f',
      ]);

      await _refreshSystemProxy();

      print('Windows 系统代理已启用: $proxyServer');
      return true;
    } catch (e) {
      print('启用 Windows 系统代理失败: $e');
      return false;
    }
  }

  @override
  Future<bool> disableProxy() async {
    try {
      print('正在禁用 Windows 系统代理...');

      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '0',
        '/f',
      ]);

      await Process.run('reg', [
        'delete',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyServer',
        '/f',
      ]);

      await _refreshSystemProxy();

      print('Windows 系统代理已禁用');
      return true;
    } catch (e) {
      print('禁用 Windows 系统代理失败: $e');
      return false;
    }
  }

  Future<void> _refreshSystemProxy() async {
    try {
      await Process.run('powershell', [
        '-Command',
        r'''
        $signature = @'
        [DllImport("wininet.dll", SetLastError = true, CharSet=CharSet.Auto)]
        public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@
        $INTERNET_OPTION_SETTINGS_CHANGED = 39
        $INTERNET_OPTION_REFRESH = 37
        $type = Add-Type -MemberDefinition $signature -Name WinINet -Namespace InternetSettings -PassThru
        $type::InternetSetOption([IntPtr]::Zero, $INTERNET_OPTION_SETTINGS_CHANGED, [IntPtr]::Zero, 0) | Out-Null
        $type::InternetSetOption([IntPtr]::Zero, $INTERNET_OPTION_REFRESH, [IntPtr]::Zero, 0) | Out-Null
        ''',
      ]);
      print('系统代理设置已刷新');
    } catch (e) {
      print('刷新系统代理设置失败: $e');
    }
  }
}

