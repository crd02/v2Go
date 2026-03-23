import 'dart:io';

/// 获取平台对应的可执行文件路径
class PlatformBinary {
  static String get xray {
    final name = Platform.isWindows ? 'xray.exe' : 'xray';
    return 'bin${Platform.pathSeparator}$name';
  }

  static String get singBox {
    final name = Platform.isWindows ? 'sing-box.exe' : 'sing-box';
    return 'bin${Platform.pathSeparator}$name';
  }
}
