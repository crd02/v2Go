import 'package:v2go/core/database/database_helper.dart';
import 'package:v2go/managers/app_settings_manager.dart';


import '../models/v2ray_config_model.dart';
import '../models/inbounds_model.dart';
import '../models/routing_model.dart';

/// Xray 配置生成器
class XrayConfigGenerator {
  /// 生成完整的 Xray 配置（异步，包含用户路由规则）
  static Future<Map<String, dynamic>> generateFullConfig(
      V2RayConfig v2rayConfig) async {
    final userRules = await DatabaseHelper().getAllRoutingRules();
    final v2rayConfigJson = v2rayConfig.toJson();
    v2rayConfigJson["tag"] = "proxy";
    return {
      'stats': {},
      "api": {
        "tag": "api",
        "services": [
          "HandlerService",
          "LoggerService",
          "StatsService",
          "RoutingService",
        ],
      },
      'log': _generateLogConfig(),
      'dns': _generateDnsConfig(),
      'policy': generatorPolicy(),
      'inbounds': [_generateInboundConfig().toJson(), generatorSta()],
      'outbounds': [v2rayConfigJson, _generateDirectOutbound().toJson()],
      'routing': _generateRoutingConfig(userRules, AppSettingsManager().routingMode).toJson(),
    };
  }

  static Map<String, dynamic> generatorSta() {
    return     {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    };
  }

  static Map<String, dynamic> generatorPolicy() {
    return {
      "system": {
        "statsInboundUplink": true,
        "statsInboundDownlink": true,
        "statsOutboundUplink": true,
        "statsOutboundDownlink": true,
      },
    };
  }

  static Map<String, dynamic> _generateLogConfig() {
    return {'level': 'info', 'timestamp': true};
  }

  static Map<String, dynamic> _generateDnsConfig() {
    return {
      'hosts': {
        'dns.google': [
          '8.8.8.8',
          '8.8.4.4',
          '2001:4860:4860::8888',
          '2001:4860:4860::8844',
        ],
        'dns.alidns.com': [
          '223.5.5.5',
          '223.6.6.6',
          '2400:3200::1',
          '2400:3200:baba::1',
        ],
        'one.one.one.one': [
          '1.1.1.1',
          '1.0.0.1',
          '2606:4700:4700::1111',
          '2606:4700:4700::1001',
        ],
        '1dot1dot1dot1.cloudflare-dns.com': [
          '1.1.1.1',
          '1.0.0.1',
          '2606:4700:4700::1111',
          '2606:4700:4700::1001',
        ],
        'cloudflare-dns.com': [
          '104.16.249.249',
          '104.16.248.249',
          '2606:4700::6810:f8f9',
          '2606:4700::6810:f9f9',
        ],
        'dns.cloudflare.com': [
          '104.16.132.229',
          '104.16.133.229',
          '2606:4700::6810:84e5',
          '2606:4700::6810:85e5',
        ],
        'dot.pub': ['1.12.12.12', '120.53.53.53'],
        'doh.pub': ['1.12.12.12', '120.53.53.53'],
        'dns.quad9.net': [
          '9.9.9.9',
          '149.112.112.112',
          '2620:fe::fe',
          '2620:fe::9',
        ],
        'dns.yandex.net': [
          '77.88.8.8',
          '77.88.8.1',
          '2a02:6b8::feed:0ff',
          '2a02:6b8:0:1::feed:0ff',
        ],
        'dns.sb': ['185.222.222.222', '2a09::'],
        'dns.umbrella.com': [
          '208.67.220.220',
          '208.67.222.222',
          '2620:119:35::35',
          '2620:119:53::53',
        ],
        'dns.sse.cisco.com': [
          '208.67.220.220',
          '208.67.222.222',
          '2620:119:35::35',
          '2620:119:53::53',
        ],
        'engage.cloudflareclient.com': [
          '162.159.192.1',
          '2606:4700:d0::a29f:c001',
        ],
      },
      'servers': [
        {
          'address': 'https://dns.alidns.com/dns-query',
          'domains': [
            'domain:alidns.com',
            'domain:doh.pub',
            'domain:dot.pub',
            'domain:360.cn',
            'domain:onedns.net',
          ],
          'skipFallback': true,
        },
        {
          'address': 'https://cloudflare-dns.com/dns-query',
          'domains': ['geosite:google'],
          'skipFallback': true,
        },
        {
          'address': 'https://dns.alidns.com/dns-query',
          'domains': ['geosite:private', 'geosite:cn'],
          'skipFallback': true,
        },
        {
          'address': '223.5.5.5',
          'domains': ['full:dns.alidns.com', 'full:cloudflare-dns.com'],
          'skipFallback': true,
        },
        'https://cloudflare-dns.com/dns-query',
      ],
    };
  }

  /// 生成入站配置
  static InboundConfig _generateInboundConfig() {
    return InboundConfig(
      tag: 'socks',

      port: AppSettingsManager().socksPort,
      listen: '127.0.0.1',
      protocol: 'mixed',
      sniffing: SniffingConfig(
        enabled: true,
        destOverride: ['http', 'tls'],
        routeOnly: false,
      ),
      settings: InboundSettings(
        auth: 'noauth',
        udp: true,
        allowTransparent: false,
      ),
    );
  }

  /// 生成直连出站配置
  static DirectOutbound _generateDirectOutbound() {
    return DirectOutbound(tag: 'direct-out', protocol: 'freedom');
  }

  /// 生成路由配置（含用户自定义规则）
  static RoutingConfig _generateRoutingConfig(
      List<Map<String, dynamic>> userRules, RoutingMode mode) {
        print(mode);
    // 全局直连：所有流量直连
    if (mode == RoutingMode.direct) {
      return RoutingConfig(
        domainStrategy: 'AsIs',
        rules: [
          RoutingRule(type: "field", outboundTag: "api", inboundTag: "api"),
          RoutingRule(type: 'field', port: '0-65535', outboundTag: 'direct-out'),
        ],
      );
    }

    // 全局代理：所有流量走代理
    if (mode == RoutingMode.global) {
      return RoutingConfig(
        domainStrategy: 'AsIs',
        rules: [
          RoutingRule(type: "field", outboundTag: "api", inboundTag: "api"),
          RoutingRule(type: 'field', port: '0-65535', outboundTag: 'proxy'),
        ],
      );
    }

    // 规则分流：用户规则 + 内置规则
    final userRoutingRules = <RoutingRule>[];
    for (final rule in userRules) {
      final entries =
          rule['entries'] as List<Map<String, dynamic>>? ?? [];
      final proxyIps = <String>[];
      final proxyDomains = <String>[];
      final proxyProcesses = <String>[];
      final directIps = <String>[];
      final directDomains = <String>[];
      final directProcesses = <String>[];

      for (final entry in entries) {
        final isProxy = (entry['action'] as String) == 'proxy';
        final matchType = entry['match_type'] as String;
        final value = entry['value'] as String;

        if (matchType == 'appName') {
          if (isProxy) proxyProcesses.add(value); else directProcesses.add(value);
        } else if (matchType == 'ip') {
          if (isProxy) proxyIps.add(value); else directIps.add(value);
        } else {
          if (isProxy) proxyDomains.add(value); else directDomains.add(value);
        }
      }

      if (proxyProcesses.isNotEmpty) {
        userRoutingRules.add(RoutingRule(
            type: 'field', process: proxyProcesses, outboundTag: 'proxy'));
      }
      if (proxyDomains.isNotEmpty) {
        userRoutingRules.add(RoutingRule(
            type: 'field',
            domain: proxyDomains,
            outboundTag: 'proxy'));
      }
      if (proxyIps.isNotEmpty) {
        userRoutingRules.add(RoutingRule(
            type: 'field', ip: proxyIps, outboundTag: 'proxy'));
      }
      if (directProcesses.isNotEmpty) {
        userRoutingRules.add(RoutingRule(
            type: 'field', process: directProcesses, outboundTag: 'direct-out'));
      }
      if (directDomains.isNotEmpty) {
        userRoutingRules.add(RoutingRule(
            type: 'field',
            domain: directDomains,
            outboundTag: 'direct-out'));
      }
      if (directIps.isNotEmpty) {
        userRoutingRules.add(RoutingRule(
            type: 'field', ip: directIps, outboundTag: 'direct-out'));
      }
    }

    return RoutingConfig(
      domainStrategy: 'AsIs',
      rules: [
        RoutingRule(type: "field", outboundTag: "api", inboundTag: "api"),
        // 用户自定义规则（优先级高于内置）
        ...userRoutingRules,
        // 内置代理规则
        RoutingRule(
          type: 'field',
          domain: [
            'geosite:google',
            'geosite:facebook',
            'geosite:twitter',
            'geosite:telegram',
          ],
          outboundTag: 'proxy',
        ),
        RoutingRule(
          type: 'field',
          ip: [
            'geoip:google',
            'geoip:facebook',
            'geoip:twitter',
            'geoip:telegram',
          ],
          outboundTag: 'proxy',
        ),
        // 直连规则
        RoutingRule(
          type: 'field',
          ip: ['geoip:private', 'geoip:cn'],
          outboundTag: 'direct-out',
        ),
        RoutingRule(
          type: 'field',
          domain: ['geosite:cn'],
          outboundTag: 'direct-out',
        ),
        // 默认代理
        RoutingRule(type: 'field', port: '0-65535', outboundTag: 'proxy'),
      ],
    );
  }
}
