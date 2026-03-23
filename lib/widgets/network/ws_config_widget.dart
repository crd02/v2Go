import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/v2ray_config_model.dart';
import '../common/form_widgets.dart';
import 'network_config_widget.dart';

/// WebSocket 配置组件
class WsConfigWidget extends NetworkConfigWidget {
  const WsConfigWidget({
    super.key,
    required super.config,
    required super.onChanged,
  });

  @override
  NetworkConfig createDefaultConfig() => WsConfig();

  @override
  Widget build(BuildContext context) {
    final wsConfig = config as WsConfig? ?? WsConfig();

    return Column(
      children: [
        CustomTextField(
          label: 'Path',
          value: wsConfig.path,
          hint: '例如: /',
          onChanged: (value) {
            onChanged(WsConfig(
              acceptProxyProtocol: wsConfig.acceptProxyProtocol,
              path: value,
              headers: wsConfig.headers,
              maxEarlyData: wsConfig.maxEarlyData,
              useBrowserForwarding: wsConfig.useBrowserForwarding,
              earlyDataHeaderName: wsConfig.earlyDataHeaderName,
            ));
          },
        ),
        const SizedBox(height: 12),
        CustomTextField(
          label: 'Host (Header)',
          value: wsConfig.headers['Host'] ?? '',
          hint: '例如: v2ray.com',
          onChanged: (value) {
            final newHeaders = Map<String, String>.from(wsConfig.headers);
            newHeaders['Host'] = value;
            onChanged(WsConfig(
              acceptProxyProtocol: wsConfig.acceptProxyProtocol,
              path: wsConfig.path,
              headers: newHeaders,
              maxEarlyData: wsConfig.maxEarlyData,
              useBrowserForwarding: wsConfig.useBrowserForwarding,
              earlyDataHeaderName: wsConfig.earlyDataHeaderName,
            ));
          },
        ),
        const SizedBox(height: 12),
        CustomTextField(
          label: 'Max Early Data',
          value: wsConfig.maxEarlyData.toString(),
          hint: '例如: 1024',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) {
            final maxEarlyData = int.tryParse(value) ?? 1024;
            onChanged(WsConfig(
              acceptProxyProtocol: wsConfig.acceptProxyProtocol,
              path: wsConfig.path,
              headers: wsConfig.headers,
              maxEarlyData: maxEarlyData,
              useBrowserForwarding: wsConfig.useBrowserForwarding,
              earlyDataHeaderName: wsConfig.earlyDataHeaderName,
            ));
          },
        ),
        const SizedBox(height: 12),
        CustomTextField(
          label: 'Early Data Header Name',
          value: wsConfig.earlyDataHeaderName,
          hint: '留空或输入 header 名称',
          onChanged: (value) {
            onChanged(WsConfig(
              acceptProxyProtocol: wsConfig.acceptProxyProtocol,
              path: wsConfig.path,
              headers: wsConfig.headers,
              maxEarlyData: wsConfig.maxEarlyData,
              useBrowserForwarding: wsConfig.useBrowserForwarding,
              earlyDataHeaderName: value,
            ));
          },
        ),
        const SizedBox(height: 10),
        _buildCheckbox(
          label: 'Accept Proxy Protocol',
          value: wsConfig.acceptProxyProtocol,
          onChanged: (value) {
            onChanged(WsConfig(
              acceptProxyProtocol: value ?? false,
              path: wsConfig.path,
              headers: wsConfig.headers,
              maxEarlyData: wsConfig.maxEarlyData,
              useBrowserForwarding: wsConfig.useBrowserForwarding,
              earlyDataHeaderName: wsConfig.earlyDataHeaderName,
            ));
          },
        ),
        const SizedBox(height: 6),
        _buildCheckbox(
          label: 'Use Browser Forwarding',
          value: wsConfig.useBrowserForwarding,
          onChanged: (value) {
            onChanged(WsConfig(
              acceptProxyProtocol: wsConfig.acceptProxyProtocol,
              path: wsConfig.path,
              headers: wsConfig.headers,
              maxEarlyData: wsConfig.maxEarlyData,
              useBrowserForwarding: value ?? false,
              earlyDataHeaderName: wsConfig.earlyDataHeaderName,
            ));
          },
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            fillColor: WidgetStateProperty.resolveWith(
              (states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.orange.shade600;
                }
                return Colors.white.withOpacity(0.3);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
