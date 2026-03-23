import 'package:flutter/material.dart';
import '../../models/v2ray_config_model.dart';

/// 网络配置组件抽象基类
abstract class NetworkConfigWidget extends StatelessWidget {
  final NetworkConfig? config;
  final ValueChanged<NetworkConfig> onChanged;

  const NetworkConfigWidget({
    super.key,
    required this.config,
    required this.onChanged,
  });

  /// 创建默认配置
  NetworkConfig createDefaultConfig();
}
