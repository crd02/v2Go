import 'dart:io';
import 'system_proxy.dart';
import 'system_proxy_windows.dart' as windows;
import 'system_proxy_linux.dart' as linux;
import 'system_proxy_macos.dart' as macos;
import 'system_proxy_stub.dart' as stub;

SystemProxy createSystemProxy() {
  if (Platform.isWindows) {
    return windows.SystemProxyWindows();
  } else if (Platform.isLinux) {
    return linux.SystemProxyLinux();
  } else if (Platform.isMacOS) {
    return macos.SystemProxyMacOS();
  } else {
    return stub.SystemProxyStub();
  }
}

