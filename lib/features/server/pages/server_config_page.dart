import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:v2go/core/config/v2_config.dart';
import 'package:v2go/models/v2ray_config_model.dart';
import 'package:v2go/core/database/database_helper.dart';

// 服务器数据模型
class ServerConfig {
  final String id;
  final String name;
  final String protocol;
  final String address;
  final String location;
  final int latency; // 延时，单位ms
  bool isSelected;
  final V2RayConfig? v2rayConfig; // 完整的 V2Ray 配置

  ServerConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.address,
    required this.location,
    required this.latency,
    this.isSelected = false,
    this.v2rayConfig,
  });
}

class ServerConfigPage extends StatefulWidget {
  const ServerConfigPage({super.key});

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  // 服务器数据列表
  List<ServerConfig> servers = [];
  bool isLoading = true; // 添加加载状态

  @override
  void initState() {
    super.initState();
    _loadServersFromDatabase();
  }

  /// 从数据库加载服务器列表
  Future<void> _loadServersFromDatabase() async {
    print('[ServerConfigPage] 开始加载服务器列表...');
    try {
      final dbServers = await DatabaseHelper().getAllServers();
      print('[ServerConfigPage] 查询到 ${dbServers.length} 个服务器');
      final loadedServers = <ServerConfig>[];

      for (var serverData in dbServers) {
        final id = serverData['id'] as String;
        final name = serverData['name'] as String;
        final protocol = serverData['protocol'] as String;
        final configJsonString = serverData['config_json'] as String;

        // 解析 JSON 配置
        final configJson = jsonDecode(configJsonString) as Map<String, dynamic>;
        final v2rayConfig = V2RayConfig.fromJson(configJson);

        // 创建 ServerConfig
        final serverConfig = ServerConfig(
          id: id,
          name: name,
          protocol: protocol,
          address:
              '${v2rayConfig.serverSettings.address}:${v2rayConfig.serverSettings.port}',
          location: '未知',
          latency: 0,
          v2rayConfig: v2rayConfig,
        );

        loadedServers.add(serverConfig);
      }

      setState(() {
        servers = loadedServers;
        isLoading = false;
      });
    } catch (e) {
      print('[ServerConfigPage] 加载服务器列表失败: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  bool get hasSelectedItems => servers.any((s) => s.isSelected);
  bool get isAllSelected =>
      servers.isNotEmpty && servers.every((s) => s.isSelected);

  void toggleSelectAll() {
    setState(() {
      if (isAllSelected) {
        for (var server in servers) {
          server.isSelected = false;
        }
      } else {
        for (var server in servers) {
          server.isSelected = true;
        }
      }
    });
  }

  void deleteSelected() async {
    final selectedServers = servers
        .where((server) => server.isSelected)
        .toList();
    if (selectedServers.isEmpty) return;

    final selectedIds = selectedServers.map((s) => s.id).toList();

    try {
      // 从数据库删除
      await DatabaseHelper().deleteServers(selectedIds);

      // 从列表中删除
      setState(() {
        servers.removeWhere((server) => server.isSelected);
      });

      displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: Text('已删除 ${selectedIds.length} 个服务器'),
            severity: InfoBarSeverity.success,
          );
        },
      );
    } catch (e) {
      displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: Text('删除服务器失败: $e'),
            severity: InfoBarSeverity.error,
          );
        },
      );
    }
  }

  void addNewServer() async {
    // 显示配置对话框
    final result = await showDialog<V2RayConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const V2RayConfigPage(isDialog: true),
    );

    // 如果用户完成了配置
    if (result != null) {
      final serverId = DateTime.now().millisecondsSinceEpoch.toString();
      final serverName = result.name.isNotEmpty
          ? result.name
          : '${result.protocol} - ${result.serverSettings.address}';

      final newServer = ServerConfig(
        id: serverId,
        name: serverName,
        protocol: result.protocol,
        address:
            '${result.serverSettings.address}:${result.serverSettings.port}',
        location: '未知',
        latency: 0,
        v2rayConfig: result,
      );

      // 保存到数据库
      try {
        await DatabaseHelper().insertServer(
          id: serverId,
          name: serverName,
          protocol: result.protocol,
          config: result,
        );

        setState(() {
          servers.add(newServer);
        });

        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: Text('已添加服务器: ${result.serverSettings.address}'),
              severity: InfoBarSeverity.success,
            );
          },
        );
      } catch (e) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: Text('保存服务器失败: $e'),
              severity: InfoBarSeverity.error,
            );
          },
        );
      }
    }
  }

  void editServer(ServerConfig server) async {
    if (server.v2rayConfig == null) {
      displayInfoBar(
        context,
        builder: (context, close) {
          return const InfoBar(
            title: Text('该服务器无法编辑（缺少配置信息）'),
            severity: InfoBarSeverity.warning,
          );
        },
      );
      return;
    }

    // 显示配置对话框（编辑模式）
    final result = await showDialog<V2RayConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          V2RayConfigPage(isDialog: true, initialConfig: server.v2rayConfig),
    );

    // 如果用户完成了配置
    if (result != null) {
      try {
        final serverName = result.name.isNotEmpty
            ? result.name
            : '${result.protocol} - ${result.serverSettings.address}';

        // 更新数据库
        await DatabaseHelper().updateServer(
          id: server.id,
          name: serverName,
          protocol: result.protocol,
          config: result,
        );

        // 更新界面
        setState(() {
          final index = servers.indexWhere((s) => s.id == server.id);
          if (index != -1) {
            servers[index] = ServerConfig(
              id: server.id,
              name: serverName,
              protocol: result.protocol,
              address:
                  '${result.serverSettings.address}:${result.serverSettings.port}',
              location: server.location,
              latency: server.latency,
              v2rayConfig: result,
            );
          }
        });

        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: Text('已更新服务器: ${result.serverSettings.address}'),
              severity: InfoBarSeverity.success,
            );
          },
        );
      } catch (e) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: Text('更新服务器失败: $e'),
              severity: InfoBarSeverity.error,
            );
          },
        );
      }
    }
  }

  void importServers() {
    // TODO: 实现导入服务器逻辑
    displayInfoBar(
      context,
      builder: (context, close) {
        return const InfoBar(
          title: Text('导入服务器功能待实现'),
          severity: InfoBarSeverity.info,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 顶部工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '服务器配置',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black.withOpacity(0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${servers.length} 个服务器',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.black.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // 删除按钮（仅在有选中项时显示）
                if (hasSelectedItems) ...[
                  _IconButton(
                    icon: FluentIcons.delete,
                    color: Colors.red,
                    onPressed: deleteSelected,
                    tooltip: '删除',
                  ),
                  const SizedBox(width: 8),
                ],
                _IconButton(
                  icon: FluentIcons.download,
                  onPressed: importServers,
                  tooltip: '导入',
                ),
                const SizedBox(width: 8),
                _IconButton(
                  icon: FluentIcons.add,
                  isPrimary: true,
                  onPressed: addNewServer,
                  tooltip: '新建',
                ),
              ],
            ),
          ),
          // 表格
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ProgressRing(activeColor: Colors.orange),
                        const SizedBox(height: 16),
                        Text(
                          '加载中...',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : servers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.server,
                          size: 64,
                          color: isDark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无服务器配置',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        // 表头
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // 全选复选框
                              SizedBox(
                                child: Checkbox(
                                  checked: isAllSelected,
                                  onChanged: (value) => toggleSelectAll(),
                                ),
                              ),
                              // 表头列
                              Expanded(
                                flex: 3,
                                child: _TableHeader('名称', isDark: isDark),
                              ),
                              Expanded(
                                flex: 2,
                                child: _TableHeader('协议类型', isDark: isDark),
                              ),
                              Expanded(
                                flex: 3,
                                child: _TableHeader('服务器地址', isDark: isDark),
                              ),
                              Expanded(
                                flex: 2,
                                child: _TableHeader('位置', isDark: isDark),
                              ),
                              Expanded(
                                flex: 1,
                                child: _TableHeader('延时', isDark: isDark),
                              ),
                            ],
                          ),
                        ),
                        // 表格数据行
                        ...servers.map(
                          (server) => _ServerRow(
                            server: server,
                            onChanged: (value) {
                              setState(() {
                                server.isSelected = value ?? false;
                              });
                            },
                            onDoubleTap: () => editServer(server),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// 表头组件
class _TableHeader extends StatelessWidget {
  final String text;
  final bool isDark;

  const _TableHeader(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: isDark
              ? Colors.white.withOpacity(0.6)
              : Colors.black.withOpacity(0.6),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// 服务器行组件
class _ServerRow extends StatefulWidget {
  final ServerConfig server;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onDoubleTap;

  const _ServerRow({
    required this.server,
    required this.onChanged,
    this.onDoubleTap,
  });

  @override
  State<_ServerRow> createState() => _ServerRowState();
}

class _ServerRowState extends State<_ServerRow> {
  bool _isHovered = false;

  Color _getLatencyColor() {
    if (widget.server.latency < 100) {
      return Colors.green;
    } else if (widget.server.latency < 200) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: widget.server.isSelected
                ? Colors.orange.withOpacity(0.15)
                : (_isHovered
                      ? (isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03))
                      : Colors.transparent),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                checked: widget.server.isSelected,
                onChanged: (value) => widget.onChanged(value),
              ),
              // 名称
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    widget.server.name,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.9)
                          : Colors.black.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // 协议类型
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.server.protocol,
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              // 服务器地址
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    widget.server.address,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black.withOpacity(0.7),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              // 位置
              Expanded(
                flex: 2,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.location,
                        size: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.server.location,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 延时
              Expanded(
                flex: 1,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getLatencyColor(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.server.latency}ms',
                        style: TextStyle(
                          color: _getLatencyColor(),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 图标按钮组件
class _IconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final Color? color;
  final String? tooltip;

  const _IconButton({
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.color,
    this.tooltip,
  });

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? (widget.isPrimary ? Colors.orange : Colors.white);

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? color
                : (_isHovered ? color.withOpacity(0.1) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isPrimary
                  ? Colors.transparent
                  : (_isHovered ? color : color.withOpacity(0.3)),
              width: 1,
            ),
          ),
          child: Icon(
            widget.icon,
            color: widget.isPrimary
                ? Colors.white
                : (_isHovered ? color : color.withOpacity(0.7)),
            size: 18,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

// 正方形复选框组件
class _SquareCheckbox extends StatelessWidget {
  final bool? checked;
  final ValueChanged<bool?>? onChanged;

  const _SquareCheckbox({required this.checked, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isChecked = checked == true;
    final isIndeterminate = checked == null;

    return GestureDetector(
      onTap: onChanged != null
          ? () {
              if (isIndeterminate || !isChecked) {
                onChanged!(true);
              } else {
                onChanged!(false);
              }
            }
          : null,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: isChecked || isIndeterminate
              ? Colors.orange
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isChecked || isIndeterminate
                ? Colors.orange
                : Colors.white.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: isChecked
            ? const Icon(FluentIcons.check_mark, size: 12, color: Colors.white)
            : (isIndeterminate
                  ? Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )
                  : null),
      ),
    );
  }
}

// 操作按钮组件
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered ? Colors.white : Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: _isHovered
                    ? Colors.white
                    : Colors.white.withOpacity(0.7),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isHovered
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
