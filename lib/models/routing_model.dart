/// Xray 路由配置模型

/// 路由配置
class RoutingConfig {
  final String domainStrategy;
  final List<RoutingRule> rules;

  RoutingConfig({required this.domainStrategy, required this.rules});

  Map<String, dynamic> toJson() {
    return {
      'domainStrategy': domainStrategy,
      'rules': rules.map((rule) => rule.toJson()).toList(),
    };
  }

  factory RoutingConfig.fromJson(Map<String, dynamic> json) {
    return RoutingConfig(
      domainStrategy: json['domainStrategy'] as String,
      rules: (json['rules'] as List<dynamic>)
          .map((rule) => RoutingRule.fromJson(rule as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 路由规则
class RoutingRule {
  final String type;
  final List<String>? ip;
  final List<String>? domain;
  final List<String>? process;
  final String? port;
  final String outboundTag;
  final String? inboundTag;
  RoutingRule({
    required this.type,
    this.ip,
    this.domain,
    this.process,
    this.port,
    this.inboundTag,
    required this.outboundTag,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': type, 'outboundTag': outboundTag};
    if (inboundTag != null) {
      json['inboundTag'] = inboundTag;
    }
    if (ip != null && ip!.isNotEmpty) {
      json['ip'] = ip;
    }
    if (domain != null && domain!.isNotEmpty) {
      json['domain'] = domain;
    }
    if (process != null && process!.isNotEmpty) {
      json['process'] = process;
    }
    if (port != null && port!.isNotEmpty) {
      json['port'] = port;
    }

    return json;
  }

  factory RoutingRule.fromJson(Map<String, dynamic> json) {
    return RoutingRule(
      type: json['type'] as String,
      ip: json['ip'] != null
          ? (json['ip'] as List<dynamic>).map((e) => e as String).toList()
          : null,
      domain: json['domain'] != null
          ? (json['domain'] as List<dynamic>).map((e) => e as String).toList()
          : null,
      port: json['port'] as String?,
      outboundTag: json['outboundTag'] as String,
    );
  }
}

/// Direct Outbound 配置（freedom 协议）
class DirectOutbound {
  final String tag;
  final String protocol;

  DirectOutbound({required this.tag, required this.protocol});

  Map<String, dynamic> toJson() {
    return {'tag': tag, 'protocol': protocol};
  }

  factory DirectOutbound.fromJson(Map<String, dynamic> json) {
    return DirectOutbound(
      tag: json['tag'] as String,
      protocol: json['protocol'] as String,
    );
  }
}
