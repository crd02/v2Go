/// Inbounds 配置模型
class InboundConfig {
  String tag;
  int port;
  String listen;
  String protocol;
  SniffingConfig sniffing;
  InboundSettings settings;

  InboundConfig({
    this.tag = 'socks',
    this.port = 10809,
    this.listen = '127.0.0.1',
    this.protocol = 'mixed',
    SniffingConfig? sniffing,
    InboundSettings? settings,
  })  : sniffing = sniffing ?? SniffingConfig(),
        settings = settings ?? InboundSettings();

  Map<String, dynamic> toJson() {
    return {
      'tag': tag,
      'port': port,
      'listen': listen,
      'protocol': protocol,
      'sniffing': sniffing.toJson(),
      'settings': settings.toJson(),
    };
  }

  factory InboundConfig.fromJson(Map<String, dynamic> json) {
    return InboundConfig(
      tag: json['tag'] as String? ?? 'socks',
      port: json['port'] as int? ?? 10809,
      listen: json['listen'] as String? ?? '127.0.0.1',
      protocol: json['protocol'] as String? ?? 'mixed',
      sniffing: json['sniffing'] != null
          ? SniffingConfig.fromJson(json['sniffing'] as Map<String, dynamic>)
          : SniffingConfig(),
      settings: json['settings'] != null
          ? InboundSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : InboundSettings(),
    );
  }
}

/// Sniffing 配置
class SniffingConfig {
  bool enabled;
  List<String> destOverride;
  bool routeOnly;

  SniffingConfig({
    this.enabled = true,
    List<String>? destOverride,
    this.routeOnly = false,
  }) : destOverride = destOverride ?? ['http', 'tls'];

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'destOverride': destOverride,
      'routeOnly': routeOnly,
    };
  }

  factory SniffingConfig.fromJson(Map<String, dynamic> json) {
    return SniffingConfig(
      enabled: json['enabled'] as bool? ?? true,
      destOverride: (json['destOverride'] as List?)?.cast<String>() ?? ['http', 'tls'],
      routeOnly: json['routeOnly'] as bool? ?? false,
    );
  }
}

/// Inbound Settings 配置
class InboundSettings {
  String auth;
  bool udp;
  bool allowTransparent;

  InboundSettings({
    this.auth = 'noauth',
    this.udp = true,
    this.allowTransparent = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'auth': auth,
      'udp': udp,
      'allowTransparent': allowTransparent,
    };
  }

  factory InboundSettings.fromJson(Map<String, dynamic> json) {
    return InboundSettings(
      auth: json['auth'] as String? ?? 'noauth',
      udp: json['udp'] as bool? ?? true,
      allowTransparent: json['allowTransparent'] as bool? ?? false,
    );
  }
}
