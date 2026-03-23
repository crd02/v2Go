import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:v2go/core/database/database_helper.dart';
import 'package:v2go/services/latency_tester.dart';

// 服务器节点数据模型
class ServerNode {
  final String id;
  final String name;
  final String address;
  final int port;
  final String countryCode;
  final String countryFlag;
  int latency;

  ServerNode({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.countryCode,
    required this.countryFlag,
    required this.latency,
  });
}

class ServerSelectorDialog extends StatefulWidget {
  final String? currentServerId;

  const ServerSelectorDialog({super.key, this.currentServerId});

  @override
  State<ServerSelectorDialog> createState() => _ServerSelectorDialogState();
}

class _ServerSelectorDialogState extends State<ServerSelectorDialog> {
  late String? selectedServerId;
  List<ServerNode> servers = [];
  bool isLoading = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    selectedServerId = widget.currentServerId;
    _loadServers();
  }

  @override
  void dispose() {
    _isTesting = false;
    super.dispose();
  }

  Future<void> _loadServers() async {
    print('[ServerSelectorDialog] 开始加载服务器列表...');
    try {
      final dbHelper = DatabaseHelper();
      final serverList = await dbHelper.getAllServers();
      print('[ServerSelectorDialog] 查询到 ${serverList.length} 个服务器');

      setState(() {
        servers = serverList.map((serverData) {
          String address = '';
          int port = 443; // 默认端口
          try {
            final configJson = serverData['config_json'] as String;
            final config = jsonDecode(configJson);
            final outbounds = config['outbounds'] as List?;
            if (outbounds != null && outbounds.isNotEmpty) {
              final settings = outbounds[0]['settings'];
              final vnext = settings?['vnext'] as List?;
              if (vnext != null && vnext.isNotEmpty) {
                address = vnext[0]['address'] as String? ?? '';
                port = vnext[0]['port'] as int? ?? 443;
              }
            }
          } catch (e) {
            address = '';
            port = 443;
          }

          return ServerNode(
            id: serverData['id'] as String,
            name: serverData['name'] as String,
            address: address,
            port: port,
            countryCode: 'CN',
            countryFlag: '🌐',
            latency: -1,
          );
        }).toList();
        isLoading = false;
      });

      _startLatencyTest();
    } catch (e) {
      print('[ServerSelectorDialog] 加载服务器列表失败: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _startLatencyTest() {
    if (_isTesting) return;
    _isTesting = true;
    for (var server in servers) {
      if (server.address.isNotEmpty) {
        _startServerLatencyLoop(server);
      }
    }
  }

  /// 为单个服务器启动持续延迟测试循环
  Future<void> _startServerLatencyLoop(ServerNode server) async {
    while (_isTesting && mounted) {
      print("testing ${server.name}");
      await _testServerLatency(server);
      // 测试完成后等待5秒再次测试
      if (_isTesting && mounted) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  /// 使用 LatencyTester 测试服务器延迟
  Future<void> _testServerLatency(ServerNode server) async {
    final latency = await LatencyTester.testLatency(
      server.address,
      server.port,
    );
    if (mounted) {
      setState(() {
        server.latency = latency < 0 ? 9999 : latency;
      });
    }
  }

  int _getSignalStrength(int latency) {
    return LatencyTester.getSignalStrength(latency);
  }

  Color _getLatencyColor(int latency) {
    final colorIndex = LatencyTester.getLatencyColorIndex(latency);
    switch (colorIndex) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      default:
        return Colors.red.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark 
        ? const Color(0xFF2B2D30).withOpacity(0.85)
        : Colors.white.withOpacity(0.95);
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark 
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.dns_rounded,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '选择服务器',
                      style: TextStyle(
                        color: textColor.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: textColor.withOpacity(0.7),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: dividerColor),
              Flexible(
                child: isLoading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: Colors.orange.shade600,
                          ),
                        ),
                      )
                    : servers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text(
                            '暂无服务器',
                            style: TextStyle(
                              color: textColor.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: servers.length,
                        itemBuilder: (context, index) {
                          final server = servers[index];
                          final isSelected = server.id == selectedServerId;

                          return _ServerCard(
                            server: server,
                            isSelected: isSelected,
                            signalStrength: _getSignalStrength(server.latency),
                            latencyColor: _getLatencyColor(server.latency),
                            isDark: isDark,
                            onTap: () {
                              setState(() {
                                selectedServerId = server.id;
                              });
                            },
                          );
                        },
                      ),
              ),
              // 底部按钮
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor.withOpacity(0.7),
                          side: BorderSide(
                            color: textColor.withOpacity(0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: servers.isEmpty
                            ? null
                            : () {
                                if (selectedServerId != null) {
                                  final selected = servers.firstWhere(
                                    (s) => s.id == selectedServerId,
                                    orElse: () => servers[0],
                                  );
                                  Navigator.of(context).pop(selected);
                                } else if (servers.isNotEmpty) {
                                  Navigator.of(context).pop(servers[0]);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('确认'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 服务器卡片组件
class _ServerCard extends StatefulWidget {
  final ServerNode server;
  final bool isSelected;
  final int signalStrength;
  final Color latencyColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ServerCard({
    required this.server,
    required this.isSelected,
    required this.signalStrength,
    required this.latencyColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cardBackgroundColor = widget.isSelected
        ? Colors.orange.shade600.withOpacity(0.25)
        : (_isHovered
            ? (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08))
            : (widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)));
    
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final iconBackgroundColor = widget.isDark 
        ? Colors.black.withOpacity(0.2)
        : Colors.grey.withOpacity(0.1);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cardBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? Colors.orange.shade600.withOpacity(0.15)
                    : Colors.black.withOpacity(0.05),
                blurRadius: widget.isSelected ? 12 : 6,
                spreadRadius: widget.isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // 国旗图标
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.server.countryFlag,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              // 服务器名称
              Expanded(
                child: Text(
                  widget.server.name,
                  style: TextStyle(
                    color: textColor.withOpacity(0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 延迟显示
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        LatencyTester.formatLatency(widget.server.latency),
                        style: TextStyle(
                          color: widget.latencyColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 信号强度图标
                      _SignalStrengthIcon(
                        strength: widget.signalStrength,
                        color: widget.latencyColor,
                        isDark: widget.isDark,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // 选中图标
              if (widget.isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
              if (!widget.isSelected)
                Icon(
                  Icons.circle_outlined,
                  color: textColor.withOpacity(0.3),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 信号强度图标组件
class _SignalStrengthIcon extends StatelessWidget {
  final int strength; // 1-3
  final Color color;
  final bool isDark;

  const _SignalStrengthIcon({
    required this.strength, 
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SignalBar(height: 4, isActive: strength >= 1, color: color, isDark: isDark),
          _SignalBar(height: 8, isActive: strength >= 2, color: color, isDark: isDark),
          _SignalBar(height: 12, isActive: strength >= 3, color: color, isDark: isDark),
        ],
      ),
    );
  }
}

// 信号柱组件
class _SignalBar extends StatelessWidget {
  final double height;
  final bool isActive;
  final Color color;
  final bool isDark;

  const _SignalBar({
    required this.height,
    required this.isActive,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark 
        ? Colors.white.withOpacity(0.2)
        : Colors.black.withOpacity(0.2);
    
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: isActive ? color : inactiveColor,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
