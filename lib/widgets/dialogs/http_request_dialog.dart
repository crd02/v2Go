import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../../models/v2ray_config_model.dart';
import '../common/form_widgets.dart';

/// 显示 HTTP Request 配置对话框
Future<HttpRequest?> showHttpRequestDialog(
  BuildContext context,
  HttpRequest request,
) async {
  return showDialog<HttpRequest>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _HttpRequestDialog(request: request);
    },
  );
}

class _HttpRequestDialog extends StatefulWidget {
  final HttpRequest request;

  const _HttpRequestDialog({required this.request});

  @override
  State<_HttpRequestDialog> createState() => _HttpRequestDialogState();
}

class _HttpRequestDialogState extends State<_HttpRequestDialog> {
  late String version;
  late String method;
  late List<String> path;
  late Map<String, List<String>> headers;

  @override
  void initState() {
    super.initState();
    version = widget.request.version;
    method = widget.request.method;
    path = List.from(widget.request.path);
    headers = Map.from(widget.request.headers.map(
      (key, value) => MapEntry(key, List<String>.from(value)),
    ));
  }

  void _addHeader() {
    setState(() {
      headers['New-Header'] = ['value'];
    });
  }

  void _removeHeader(String key) {
    setState(() {
      headers.remove(key);
    });
  }

  void _updateHeaderKey(String oldKey, String newKey) {
    if (oldKey == newKey) return;
    setState(() {
      final value = headers[oldKey];
      headers.remove(oldKey);
      if (value != null) {
        headers[newKey] = value;
      }
    });
  }

  void _updateHeaderValue(String key, String value) {
    setState(() {
      final values = value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      headers[key] = values.isEmpty ? [''] : values;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark 
              ? Colors.white.withOpacity(0.15) 
              : Colors.black.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.http,
                  color: theme.accentColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'HTTP Request 配置',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Version 和 Method
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'Version',
                            value: version,
                            hint: '例如: 1.1',
                            onChanged: (value) {
                              setState(() {
                                version = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomAutocomplete(
                            label: 'Method',
                            value: method,
                            hint: '选择或输入',
                            suggestions: const ['GET', 'POST', 'PUT', 'DELETE', 'HEAD'],
                            onChanged: (value) {
                              setState(() {
                                method = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Path
                    CustomTextField(
                      label: 'Path (多个用逗号分隔)',
                      value: path.join(', '),
                      hint: '例如: /, /api',
                      onChanged: (value) {
                        setState(() {
                          final paths = value
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          path = paths.isEmpty ? ['/'] : paths;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // Headers 表格
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Headers',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addHeader,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('添加 Header'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.accentColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildHeadersTable(isDark),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final result = HttpRequest(
                      version: version,
                      method: method,
                      path: path,
                      headers: headers,
                    );
                    Navigator.of(context).pop(result);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      '保存',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadersTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.15),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 表头
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Header',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Value (多个用逗号分隔)',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          // 表格内容
          ...headers.entries.map((entry) {
            return _buildHeaderRow(entry.key, entry.value, isDark);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(String key, List<String> values, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Header 名称
          Expanded(
            flex: 2,
            child: Builder(
              builder: (context) {
                final theme = fluent.FluentTheme.of(context);
                return TextField(
                  controller: TextEditingController(text: key),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: isDark 
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: theme.accentColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (newKey) => _updateHeaderKey(key, newKey),
                );
              }
            ),
          ),
          const SizedBox(width: 12),
          // Header 值
          Expanded(
            flex: 3,
            child: Builder(
              builder: (context) {
                final theme = fluent.FluentTheme.of(context);
                return TextField(
                  controller: TextEditingController(text: values.join(', ')),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: isDark 
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: theme.accentColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (value) => _updateHeaderValue(key, value),
                );
              }
            ),
          ),
          const SizedBox(width: 8),
          // 删除按钮
          IconButton(
            onPressed: () => _removeHeader(key),
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red.shade400,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
