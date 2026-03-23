/// Sing-box 配置模型
library;

import 'dart:convert';

/// Sing-box 主配置
class SingBoxConfig {
  final LogConfig log;
  final DnsConfig dns;
  final List<InboundConfig> inbounds;
  final List<OutboundConfig> outbounds;
  final RouteConfig route;

  SingBoxConfig({
    required this.log,
    required this.dns,
    required this.inbounds,
    required this.outbounds,
    required this.route,
  });

  Map<String, dynamic> toJson() {
    return {
      'log': log.toJson(),
      'dns': dns.toJson(),
      'inbounds': inbounds.map((e) => e.toJson()).toList(),
      'outbounds': outbounds.map((e) => e.toJson()).toList(),
      'route': route.toJson(),
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }
}

/// 日志配置
class LogConfig {
  final String level;
  final bool timestamp;

  LogConfig({this.level = 'info', this.timestamp = true});

  Map<String, dynamic> toJson() {
    return {'level': level, 'timestamp': timestamp};
  }
}

/// DNS 配置
class DnsConfig {
  final List<DnsServer> servers;
  final List<DnsRule>? rules;
  final String? strategy;
  final String? final_;

  DnsConfig({required this.servers, this.rules, this.strategy, this.final_});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'servers': servers.map((e) => e.toJson()).toList(),
    };
    if (rules != null) map['rules'] = rules!.map((e) => e.toJson()).toList();
    if (strategy != null) map['strategy'] = strategy;
    if (final_ != null) map['final'] = final_;
    return map;
  }
}

/// DNS 服务器配置
class DnsServer {
  final String tag;
  final String? type;
  final String server;
  final String? detour;

  DnsServer({required this.tag, this.type, required this.server, this.detour});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'tag': tag, 'server': server};
    if (type != null) map['type'] = type;
    if (detour != null) map['detour'] = detour;
    return map;
  }
}

/// DNS 规则配置
class DnsRule {
  final String? server;
  final List<String>? domain;
  final bool? ipAcceptAny;
  final String? clashMode;

  DnsRule({this.server, this.domain, this.ipAcceptAny, this.clashMode});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (server != null) map['server'] = server;
    if (domain != null) map['domain'] = domain;
    if (ipAcceptAny != null) map['ip_accept_any'] = ipAcceptAny;
    if (clashMode != null) map['clash_mode'] = clashMode;
    return map;
  }
}

/// 入站配置
class InboundConfig {
  final String type;
  final String tag;
  final List<String>? address;
  final bool? autoRoute;
  final bool? strictRoute;
  final String? stack;
  final bool? sniff;

  InboundConfig({
    required this.type,
    required this.tag,
    this.address,
    this.autoRoute,
    this.strictRoute,
    this.stack,
    this.sniff,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type, 'tag': tag};
    if (address != null) map['address'] = address;
    if (autoRoute != null) map['auto_route'] = autoRoute;
    if (strictRoute != null) map['strict_route'] = strictRoute;
    if (stack != null) map['stack'] = stack;
    if (sniff != null) map['sniff'] = sniff;
    return map;
  }
}

/// 出站配置
class OutboundConfig {
  final String type;
  final String tag;
  final String? server;
  final int? serverPort;
  final String? version;

  OutboundConfig({
    required this.type,
    required this.tag,
    this.server,
    this.serverPort,
    this.version,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type, 'tag': tag};
    if (server != null) map['server'] = server;
    if (serverPort != null) map['server_port'] = serverPort;
    if (version != null) map['version'] = version;
    return map;
  }
}

/// 路由配置
class RouteConfig {
  final List<RouteRule> rules;
  final DomainResolver? defaultDomainResolver;
  final bool? autoDetectInterface;
  final String finalOutbound;

  RouteConfig({
    required this.rules,
    this.defaultDomainResolver,
    this.autoDetectInterface,
    required this.finalOutbound,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'rules': rules.map((e) => e.toJson()).toList(),
      'final': finalOutbound,
    };
    if (defaultDomainResolver != null) {
      map['default_domain_resolver'] = defaultDomainResolver!.toJson();
    }
    if (autoDetectInterface != null) {
      map['auto_detect_interface'] = autoDetectInterface;
    }
    return map;
  }
}

/// 域名解析器配置
class DomainResolver {
  final String server;
  final String strategy;

  DomainResolver({required this.server, this.strategy = ''});

  Map<String, dynamic> toJson() {
    return {'server': server, 'strategy': strategy};
  }
}

/// 路由规则
class RouteRule {
  final String? action;
  final List<String>? protocol;
  final List<String>? ipCidr;
  final bool? ipIsPrivate;
  final String? outbound;
  final List<String>? processName;

  RouteRule({
    this.action,
    this.protocol,
    this.ipCidr,
    this.ipIsPrivate,
    this.outbound,
    this.processName,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (action != null) map['action'] = action;
    if (protocol != null) map['protocol'] = protocol;
    if (ipCidr != null) map['ip_cidr'] = ipCidr;
    if (ipIsPrivate != null) map['ip_is_private'] = ipIsPrivate;
    if (outbound != null) map['outbound'] = outbound;
    if (processName != null) map['process_name'] = processName;
    return map;
  }
}
