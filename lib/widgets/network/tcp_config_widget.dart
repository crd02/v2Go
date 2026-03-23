import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../../models/v2ray_config_model.dart';
import '../common/form_widgets.dart';
import '../dialogs/http_request_dialog.dart';
import '../dialogs/http_response_dialog.dart';
import 'network_config_widget.dart';

/// TCP 配置组件
class TcpConfigWidget extends NetworkConfigWidget {
  const TcpConfigWidget({
    super.key,
    required super.config,
    required super.onChanged,
  });

  @override
  NetworkConfig createDefaultConfig() => TcpConfig();

  @override
  Widget build(BuildContext context) {
    final tcpConfig = config as TcpConfig? ?? TcpConfig();

    return Column(
      children: [
        // Accept Proxy Protocol 复选框
        _buildCheckbox(
          label: 'Accept Proxy Protocol',
          value: tcpConfig.acceptProxyProtocol,
          onChanged: (value) {
            onChanged(TcpConfig(
              acceptProxyProtocol: value ?? false,
              header: tcpConfig.header,
            ));
          },
        ),
        const SizedBox(height: 12),
        // Header Type 下拉框
        CustomDropdown<String>(
          label: 'Header Type (伪装类型)',
          value: tcpConfig.header.type,
          items: const ['none', 'http'],
          onChanged: (value) {
            if (value != null) {
              TcpHeaderConfig newHeader;
              if (value == 'http') {
                newHeader = HttpHeaderConfig(
                  request: HttpRequest(),
                  response: HttpResponse(),
                );
              } else {
                newHeader = NoneHeaderConfig();
              }
              onChanged(TcpConfig(
                acceptProxyProtocol: tcpConfig.acceptProxyProtocol,
                header: newHeader,
              ));
            }
          },
        ),
        // 如果是 HTTP 伪装，显示配置按钮
        if (tcpConfig.header is HttpHeaderConfig) ...[
          const SizedBox(height: 16),
          _buildHttpConfigButtons(
            context,
            tcpConfig.header as HttpHeaderConfig,
            (newHeader) {
              onChanged(TcpConfig(
                acceptProxyProtocol: tcpConfig.acceptProxyProtocol,
                header: newHeader,
              ));
            },
          ),
        ],
      ],
    );
  }

  Widget _buildHttpConfigButtons(
    BuildContext context,
    HttpHeaderConfig header,
    ValueChanged<HttpHeaderConfig> onChanged,
  ) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return NestedConfigSection(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await showHttpRequestDialog(
                  context,
                  header.request ?? HttpRequest(),
                );
                if (result != null) {
                  onChanged(HttpHeaderConfig(
                    request: result,
                    response: header.response,
                  ));
                }
              },
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: const Text('配置 Request'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(
                  color: Colors.orange.shade600.withOpacity(0.5),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await showHttpResponseDialog(
                  context,
                  header.response ?? HttpResponse(),
                );
                if (result != null) {
                  onChanged(HttpHeaderConfig(
                    request: header.request,
                    response: result,
                  ));
                }
              },
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('配置 Response'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(
                  color: Colors.orange.shade600.withOpacity(0.5),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
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
