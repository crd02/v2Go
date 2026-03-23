import 'dart:convert';

/// V2Ray 配置数据模型
class V2RayConfig {
  String name;
  String protocol;
  ServerSettings serverSettings;
  UserSettings userSettings;
  StreamSettings streamSettings;

  V2RayConfig({
    this.name = '',
    this.protocol = 'VLESS',
    ServerSettings? serverSettings,
    UserSettings? userSettings,
    StreamSettings? streamSettings,
  })  : serverSettings = serverSettings ?? ServerSettings(),
        userSettings = userSettings ?? UserSettings(),
        streamSettings = streamSettings ?? StreamSettings();

  /// 从 JSON 创建配置（支持完整配置和简化配置）
  factory V2RayConfig.fromJson(Map<String, dynamic> json) {
    // 检查是否是完整配置（包含 outbounds）
    Map<String, dynamic> outboundConfig;
    if (json.containsKey('outbounds')) {
      // 从 outbounds 数组中获取第一个配置
      final outbounds = json['outbounds'] as List;
      if (outbounds.isEmpty) {
        throw Exception('outbounds 数组为空');
      }
      outboundConfig = outbounds[0] as Map<String, dynamic>;
    } else {
      // 直接使用传入的配置
      outboundConfig = json;
    }

    // 解析服务器设置
    final settings = outboundConfig['settings'] as Map<String, dynamic>?;
    final vnext = settings?['vnext'] as List?;
    final firstVnext = vnext?.isNotEmpty == true ? vnext![0] as Map<String, dynamic> : null;
    final users = firstVnext?['users'] as List?;
    final firstUser = users?.isNotEmpty == true ? users![0] as Map<String, dynamic> : null;

    // 解析流设置
    final streamSettingsJson = outboundConfig['streamSettings'] as Map<String, dynamic>?;
    final network = streamSettingsJson?['network'] as String? ?? 'tcp';
    final security = streamSettingsJson?['security'] as String? ?? 'none';

    NetworkConfig? networkConfig;
    if (streamSettingsJson != null) {
      if (network == 'tcp' && streamSettingsJson.containsKey('tcpSettings')) {
        final tcp = streamSettingsJson['tcpSettings'] as Map<String, dynamic>;
        final headerJson = tcp['header'] as Map<String, dynamic>?;
        TcpHeaderConfig header = NoneHeaderConfig();
        
        if (headerJson != null && headerJson['type'] == 'http') {
          final requestJson = headerJson['request'] as Map<String, dynamic>?;
          final responseJson = headerJson['response'] as Map<String, dynamic>?;
          
          HttpRequest? request;
          if (requestJson != null) {
            request = HttpRequest(
              version: requestJson['version'] as String? ?? '1.1',
              method: requestJson['method'] as String? ?? 'GET',
              path: (requestJson['path'] as List?)?.cast<String>() ?? ['/'],
              headers: (requestJson['headers'] as Map?)?.map(
                (key, value) => MapEntry(
                  key.toString(),
                  (value as List).cast<String>(),
                ),
              ) ?? HttpRequest().headers,
            );
          }
          
          HttpResponse? response;
          if (responseJson != null) {
            response = HttpResponse(
              version: responseJson['version'] as String? ?? '1.1',
              status: responseJson['status'] as String? ?? '200',
              reason: responseJson['reason'] as String? ?? 'OK',
              headers: (responseJson['headers'] as Map?)?.map(
                (key, value) => MapEntry(
                  key.toString(),
                  (value as List).cast<String>(),
                ),
              ) ?? HttpResponse().headers,
            );
          }
          
          header = HttpHeaderConfig(request: request, response: response);
        }
        
        networkConfig = TcpConfig(
          acceptProxyProtocol: tcp['acceptProxyProtocol'] as bool? ?? false,
          header: header,
        );
      } else if (network == 'ws' && streamSettingsJson.containsKey('wsSettings')) {
        final ws = streamSettingsJson['wsSettings'] as Map<String, dynamic>;
        networkConfig = WsConfig(
          acceptProxyProtocol: ws['acceptProxyProtocol'] as bool? ?? false,
          path: ws['path'] as String? ?? '/',
          headers: Map<String, String>.from(ws['headers'] as Map? ?? {'Host': 'v2ray.com'}),
          maxEarlyData: ws['maxEarlyData'] as int? ?? 1024,
          useBrowserForwarding: ws['useBrowserForwarding'] as bool? ?? false,
          earlyDataHeaderName: ws['earlyDataHeaderName'] as String? ?? '',
        );
      }
    }

    return V2RayConfig(
      name: '', // name 不保存在 JSON 中
      protocol: outboundConfig['protocol'] as String? ?? 'VLESS',
      serverSettings: ServerSettings(
        address: firstVnext?['address'] as String? ?? '',
        port: firstVnext?['port'] as int? ?? 443,
      ),
      userSettings: UserSettings(
        userId: firstUser?['id'] as String? ?? '',
        flow: firstUser?['flow'] as String? ?? '',
        encryption: firstUser?['encryption'] as String? ?? 'none',
      ),
      streamSettings: StreamSettings(
        network: network,
        security: security,
        networkConfig: networkConfig,
      ),
    );
  }

  /// 转换为 JSON 配置（outbound 对象）
  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol,
      'settings': {
        'vnext': [
          {
            'address': serverSettings.address,
            'port': serverSettings.port,
            'users': [
              {
                'id': userSettings.userId,
                if (userSettings.flow.isNotEmpty) 'flow': userSettings.flow,
                'encryption': userSettings.encryption,
              }
            ]
          }
        ]
      },
      'streamSettings': streamSettings.toJson(),
    };
  }

  /// 转换为完整 V2Ray 配置（包含 outbounds 数组）
  Map<String, dynamic> toFullJson() {
    return {
      'outbounds': [
        toJson(),
      ],
    };
  }

  /// 生成格式化的 JSON 字符串（完整配置）
  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toFullJson());
  }
}

/// 服务器配置
class ServerSettings {
  String address;
  int port;

  ServerSettings({
    this.address = '',
    this.port = 443,
  });
}

/// 用户配置
class UserSettings {
  String userId;
  String flow;
  String encryption;

  UserSettings({
    this.userId = '',
    this.flow = '',
    this.encryption = 'none',
  });
}

/// 流设置配置
class StreamSettings {
  String network;
  String security;
  NetworkConfig? networkConfig;

  StreamSettings({
    this.network = 'tcp',
    this.security = 'none',
    this.networkConfig,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'network': network,
      'security': security,
    };

    // 添加特定网络类型的配置
    if (networkConfig != null) {
      json[networkConfig!.configKey] = networkConfig!.toJson();
    }

    return json;
  }
}

/// 网络配置抽象基类
abstract class NetworkConfig {
  String get configKey;
  Map<String, dynamic> toJson();
}

/// WebSocket 配置
class WsConfig extends NetworkConfig {
  bool acceptProxyProtocol;
  String path;
  Map<String, String> headers;
  int maxEarlyData;
  bool useBrowserForwarding;
  String earlyDataHeaderName;

  WsConfig({
    this.acceptProxyProtocol = false,
    this.path = '/',
    Map<String, String>? headers,
    this.maxEarlyData = 1024,
    this.useBrowserForwarding = false,
    this.earlyDataHeaderName = '',
  }) : headers = headers ?? {'Host': 'v2ray.com'};

  @override
  String get configKey => 'wsSettings';

  @override
  Map<String, dynamic> toJson() {
    return {
      'acceptProxyProtocol': acceptProxyProtocol,
      'path': path,
      'headers': headers,
      'maxEarlyData': maxEarlyData,
      'useBrowserForwarding': useBrowserForwarding,
      if (earlyDataHeaderName.isNotEmpty)
        'earlyDataHeaderName': earlyDataHeaderName,
    };
  }
}

/// TCP 配置
class TcpConfig extends NetworkConfig {
  bool acceptProxyProtocol;
  TcpHeaderConfig header;

  TcpConfig({
    this.acceptProxyProtocol = false,
    TcpHeaderConfig? header,
  }) : header = header ?? NoneHeaderConfig();

  @override
  String get configKey => 'tcpSettings';

  @override
  Map<String, dynamic> toJson() {
    return {
      'acceptProxyProtocol': acceptProxyProtocol,
      'header': header.toJson(),
    };
  }
}

/// TCP Header 配置抽象基类
abstract class TcpHeaderConfig {
  String get type;
  Map<String, dynamic> toJson();
}

/// None Header 配置（不进行伪装）
class NoneHeaderConfig extends TcpHeaderConfig {
  @override
  String get type => 'none';

  @override
  Map<String, dynamic> toJson() {
    return {'type': type};
  }
}

/// HTTP Header 配置（HTTP 伪装）
class HttpHeaderConfig extends TcpHeaderConfig {
  HttpRequest? request;
  HttpResponse? response;

  HttpHeaderConfig({
    this.request,
    this.response,
  });

  @override
  String get type => 'http';

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': type};
    if (request != null) {
      json['request'] = request!.toJson();
    }
    if (response != null) {
      json['response'] = response!.toJson();
    }
    return json;
  }
}

/// HTTP 请求配置
class HttpRequest {
  String version;
  String method;
  List<String> path;
  Map<String, List<String>> headers;

  HttpRequest({
    this.version = '1.1',
    this.method = 'GET',
    List<String>? path,
    Map<String, List<String>>? headers,
  })  : path = path ?? ['/'],
        headers = headers ??
            {
              'Host': ['www.baidu.com', 'www.bing.com'],
              'User-Agent': [
                'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.143 Safari/537.36',
                'Mozilla/5.0 (iPhone; CPU iPhone OS 10_0_2 like Mac OS X) AppleWebKit/601.1 (KHTML, like Gecko) CriOS/53.0.2785.109 Mobile/14A456 Safari/601.1.46'
              ],
              'Accept-Encoding': ['gzip, deflate'],
              'Connection': ['keep-alive'],
              'Pragma': ['no-cache'],
            };

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'method': method,
      'path': path,
      'headers': headers,
    };
  }
}

/// HTTP 响应配置
class HttpResponse {
  String version;
  String status;
  String reason;
  Map<String, List<String>> headers;

  HttpResponse({
    this.version = '1.1',
    this.status = '200',
    this.reason = 'OK',
    Map<String, List<String>>? headers,
  }) : headers = headers ??
            {
              'Content-Type': ['application/octet-stream', 'video/mpeg'],
              'Transfer-Encoding': ['chunked'],
              'Connection': ['keep-alive'],
              'Pragma': ['no-cache'],
            };

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'status': status,
      'reason': reason,
      'headers': headers,
    };
  }
}

/// KCP 配置
class KcpConfig extends NetworkConfig {
  @override
  String get configKey => 'kcpSettings';

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

/// HTTP 配置
class HttpConfig extends NetworkConfig {
  @override
  String get configKey => 'httpSettings';

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

/// DomainSocket 配置
class DomainSocketConfig extends NetworkConfig {
  @override
  String get configKey => 'dsSettings';

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

/// QUIC 配置
class QuicConfig extends NetworkConfig {
  @override
  String get configKey => 'quicSettings';

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

/// gRPC 配置
class GrpcConfig extends NetworkConfig {
  @override
  String get configKey => 'grpcSettings';

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}
