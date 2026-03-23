import 'system_proxy_io.dart' if (dart.library.html) 'system_proxy_stub.dart';

abstract class SystemProxy {
  Future<bool> enableProxy(String host, int port);
  Future<bool> disableProxy();
  
  factory SystemProxy.create() {
    return createSystemProxy();
  }
}

