class IpLocationInfo {
  final String ip;
  final String country;
  final String city;
  final String countryCode;
  final String countryFlag;
  final String region;
  final String isp;
  final String timezone;

  const IpLocationInfo({
    required this.ip,
    required this.country,
    required this.city,
    required this.countryCode,
    required this.countryFlag,
    required this.region,
    required this.isp,
    required this.timezone,
  });

  factory IpLocationInfo.fromJson(Map<String, dynamic> json) {
    return IpLocationInfo(
      ip: json['ip'] ?? '',
      country: json['country'] ?? '',
      city: json['city'] ?? '',
      countryCode: json['country_code'] ?? '',
      countryFlag: json['country_flag'] ?? '',
      region: json['region'] ?? '',
      isp: json['isp'] ?? '',
      timezone: json['timezone'] ?? '',
    );
  }

  String get displayLocation => '$country $city';

  @override
  String toString() => displayLocation;
}
