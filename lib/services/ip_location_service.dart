import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:v2go/models/ip_location_model.dart';

abstract class IpLocationProvider {
  String get url;
  Future<IpLocationInfo> fetchLocation({
    required String proxyHost,
    required int proxyPort,
  });
}

class IpWhoisProvider implements IpLocationProvider {
  @override
  String get url => 'https://ipwhois.app/json/?lang=zh-CN';

  @override
  Future<IpLocationInfo> fetchLocation({
    required String proxyHost,
    required int proxyPort,
  }) async {
    final httpClient = HttpClient();
    httpClient.findProxy = (uri) {
      return 'PROXY $proxyHost:$proxyPort';
    };
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    
    final client = IOClient(httpClient);
    
    try {
      final response = await client.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (json['success'] == true) {
          return IpLocationInfo.fromJson(json);
        } else {
          throw Exception('API返回失败状态');
        }
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } finally {
      client.close();
      httpClient.close();
    }
  }
}

class IpBaseProvider implements IpLocationProvider {
  @override
  String get url => 'https://api.ipbase.com/v1/json';

  @override
  Future<IpLocationInfo> fetchLocation({
    required String proxyHost,
    required int proxyPort,
  }) async {
    final httpClient = HttpClient();
    httpClient.findProxy = (uri) {
      return 'PROXY $proxyHost:$proxyPort';
    };
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    
    final client = IOClient(httpClient);
    
    try {
      final response = await client.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        
        return IpLocationInfo(
          ip: json['ip'] ?? '',
          country: json['country_name'] ?? '',
          city: json['city'] ?? '',
          countryCode: json['country_code'] ?? '',
          countryFlag: '',
          region: json['region_name'] ?? '',
          isp: '',
          timezone: json['time_zone'] ?? '',
        );
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } finally {
      client.close();
      httpClient.close();
    }
  }
}

class IpApiCoProvider implements IpLocationProvider {
  @override
  String get url => 'https://ipapi.co/json';

  @override
  Future<IpLocationInfo> fetchLocation({
    required String proxyHost,
    required int proxyPort,
  }) async {
    final httpClient = HttpClient();
    httpClient.findProxy = (uri) {
      return 'PROXY $proxyHost:$proxyPort';
    };
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    
    final client = IOClient(httpClient);
    
    try {
      final response = await client.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        
        return IpLocationInfo(
          ip: json['ip'] ?? '',
          country: json['country_name'] ?? '',
          city: json['city'] ?? '',
          countryCode: json['country_code'] ?? '',
          countryFlag: '',
          region: json['region'] ?? '',
          isp: json['org'] ?? '',
          timezone: json['timezone'] ?? '',
        );
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } finally {
      client.close();
      httpClient.close();
    }
  }
}

class IpLocationService {
  final List<IpLocationProvider> _providers = [
    IpWhoisProvider(),
    IpBaseProvider(),
    IpApiCoProvider(),
  ];

  Future<IpLocationInfo?> fetchLocation({
    required String proxyHost,
    required int proxyPort,
  }) async {
    for (final provider in _providers) {
      try {
        final result = await provider.fetchLocation(
          proxyHost: proxyHost,
          proxyPort: proxyPort,
        );
        return result;
      } catch (e) {
        continue;
      }
    }
    
    return null;
  }

  void addProvider(IpLocationProvider provider) {
    _providers.add(provider);
  }

  void removeProvider(IpLocationProvider provider) {
    _providers.remove(provider);
  }

  List<IpLocationProvider> get providers => List.unmodifiable(_providers);
}
