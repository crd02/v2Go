import 'system_proxy.dart';

class SystemProxyStub implements SystemProxy {
  @override
  Future<bool> enableProxy(String host, int port) async {
    print('当前平台不支持系统代理设置');
    return false;
  }

  @override
  Future<bool> disableProxy() async {
    print('当前平台不支持系统代理设置');
    return false;
  }
}

SystemProxy createSystemProxy() => SystemProxyStub();

