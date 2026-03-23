import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:v2go/features/server/widgets/server_selector_dialog.dart';
import 'package:v2go/managers/app_settings_manager.dart';
import 'package:v2go/managers/connect_manager.dart';
import 'package:v2go/services/latency_tester.dart';
import 'package:v2go/services/ip_location_service.dart';
import 'package:v2go/services/traffic_stats_service.dart';
import 'package:v2go/widgets/statistics/data_statistics_section.dart';
import 'package:v2go/widgets/statistics/speed_chart_widget.dart';
import 'package:v2go/utils/snackbar_utils.dart';
import 'package:v2go/core/database/database_helper.dart';

const Color _kStatusCardColor = Color.fromARGB(255, 59, 59, 59);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool isConnected = false;
  late AnimationController _animationController;
  ServerNode? selectedServer;
  bool isLoadingData = false;

  late ConnectManager _connectManager;

  bool _isProcessing = false;
  bool _hasTestedSpeed = false;
  bool _hasLoadedLastServer = false; // 标记是否已加载上次选择的服务器

  late final ValueNotifier<bool> _isConnectedNotifier;
  late final ValueNotifier<SpeedData> _speedDataNotifier;
  late final ValueNotifier<String?> _locationNotifier;
  late final ValueNotifier<bool> _isLoadingLocationNotifier;
  late final ValueNotifier<List<SpeedHistoryPoint>> _speedHistoryNotifier;
  late final ValueNotifier<int> _latencyNotifier;
  late final ValueNotifier<bool> _isTestingLatencyNotifier;

  final IpLocationService _ipLocationService = IpLocationService();
  final AppSettingsManager _settingsManager = AppSettingsManager();
  final TrafficStatsService _trafficStatsService = TrafficStatsService();

  Timer? _latencyTestTimer; // 延迟测试定时器

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _isConnectedNotifier = ValueNotifier(false);
    _speedDataNotifier = ValueNotifier(const SpeedData());
    _locationNotifier = ValueNotifier(null);
    _isLoadingLocationNotifier = ValueNotifier(false);
    _speedHistoryNotifier = ValueNotifier([]);
    _latencyNotifier = ValueNotifier(-1);
    _isTestingLatencyNotifier = ValueNotifier(false);

    _connectManager = ConnectManager();
    _connectManager.onError = (message) {
      if (mounted) {
        SnackBarUtils.showError(context, message);
      }
    };

    _connectManager.addListener(_onConnectionStateChanged);
    _settingsManager.addListener(_onSettingsChanged); // 监听设置管理器的变化

    _syncConnectionState();

    // 检查设置是否已加载完成
    _checkAndLoadLastServer();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _connectManager.removeListener(_onConnectionStateChanged);
    _settingsManager.removeListener(_onSettingsChanged); // 移除设置管理器监听
    _latencyTestTimer?.cancel();
    _trafficStatsService.stopStats();
    _isConnectedNotifier.dispose();
    _speedDataNotifier.dispose();
    _locationNotifier.dispose();
    _isLoadingLocationNotifier.dispose();
    _speedHistoryNotifier.dispose();
    _latencyNotifier.dispose();
    _isTestingLatencyNotifier.dispose();
    super.dispose();
  }

  void _onConnectionStateChanged() {
    if (!mounted) return;

    setState(() {
      _syncConnectionState();
    });
  }

  /// 当设置管理器状态改变时调用
  void _onSettingsChanged() {
    _checkAndLoadLastServer();
  }

  /// 检查并加载上次选择的服务器
  void _checkAndLoadLastServer() {
    if (!mounted || _hasLoadedLastServer) return;

    final lastServerId = _settingsManager.lastSelectedServerId;
    if (lastServerId != null && lastServerId.isNotEmpty) {
      _hasLoadedLastServer = true;
      // 等待页面加载成功后，异步加载上次选择的服务器
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLastSelectedServer();
      });
    }
  }

  void _syncConnectionState() {
    switch (_connectManager.state) {
      case ProxyConnectionState.disconnected:
        isConnected = false;
        isLoadingData = false;
        _isProcessing = false;
        _hasTestedSpeed = false;
        _isConnectedNotifier.value = false;
        _speedDataNotifier.value = const SpeedData();
        _locationNotifier.value = null;
        _isLoadingLocationNotifier.value = false;
        _speedHistoryNotifier.value = []; // 清空历史数据
        _latencyNotifier.value = -1;
        _isTestingLatencyNotifier.value = false;
        // 停止延迟测试定时器和流量统计
        _latencyTestTimer?.cancel();
        _latencyTestTimer = null;
        _trafficStatsService.stopStats();
        break;
      case ProxyConnectionState.connecting:
        isLoadingData = true;
        _isProcessing = true;
        break;
      case ProxyConnectionState.connected:
        final wasConnected = isConnected;
        isConnected = true;
        isLoadingData = false;
        _isProcessing = false;
        _isConnectedNotifier.value = true;
        _speedDataNotifier.value = _speedDataNotifier.value.copyWith(
          isConnected: true,
        );

        if (!wasConnected && !_hasTestedSpeed) {
          _hasTestedSpeed = true;
          _testLatency();
          _startSpeedTest();
          _fetchIpLocation();
          // 启动流量统计服务
          _trafficStatsService.startStats();
          // 启动延迟测试定时器（每1分钟测试一次）
          _startLatencyTimer();
        }
        break;
      case ProxyConnectionState.disconnecting:
        _isProcessing = true;
        break;
    }
  }

  /// 启动延迟测试定时器（每1分钟测试一次）
  void _startLatencyTimer() {
    _latencyTestTimer?.cancel();
    _latencyTestTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (isConnected) {
        _testLatency();
      }
    });
  }

  Future<void> _testLatency() async {
    if (_isTestingLatencyNotifier.value) return;

    _isTestingLatencyNotifier.value = true;
    _latencyNotifier.value = -1;

    try {
      final latency = await LatencyTester.testLatency(
        selectedServer?.address ?? '',
        selectedServer?.port ?? 443,
      );

      if (mounted) {
        _latencyNotifier.value = latency;
      }
    } catch (e) {
      if (mounted) {
        _latencyNotifier.value = -1;
      }
    } finally {
      if (mounted) {
        _isTestingLatencyNotifier.value = false;
      }
    }
  }

  Future<void> _startSpeedTest() async {
    if (_speedDataNotifier.value.isTestingSpeed) return;

    _speedDataNotifier.value = _speedDataNotifier.value.copyWith(
      isTestingSpeed: true,
      downloadSpeed: 0,
      uploadSpeed: 0,
    );

    final proxyAddress = _connectManager.proxyAddress;
    final proxyPort = _connectManager.proxyPort;

    final results = await Future.wait([
      LatencyTester.testDownloadSpeed(
        proxyAddress,
        proxyPort,
        testDuration: const Duration(seconds: 5),
      ),
      LatencyTester.testUploadSpeed(
        proxyAddress,
        proxyPort,
        testDuration: const Duration(seconds: 5),
      ),
    ]);

    if (!mounted) return;

    final downloadSpeed = results[0] > 0 ? results[0].toDouble() : 0.0;
    final uploadSpeed = results[1] > 0 ? results[1].toDouble() : 0.0;

    _speedDataNotifier.value = _speedDataNotifier.value.copyWith(
      isTestingSpeed: false,
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
    );
  }

  /// 将速度数据添加到历史记录
  void _addSpeedToHistory(double downloadSpeed, double uploadSpeed) {
    final newPoint = SpeedHistoryPoint(
      time: DateTime.now(),
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
    );

    final history = List<SpeedHistoryPoint>.from(_speedHistoryNotifier.value);
    history.add(newPoint);

    // 保留最近30个数据点
    if (history.length > 30) {
      history.removeAt(0);
    }

    _speedHistoryNotifier.value = history;
  }

  Future<void> _fetchIpLocation() async {
    _isLoadingLocationNotifier.value = true;

    final proxyAddress = _connectManager.proxyAddress;
    final proxyPort = _connectManager.proxyPort;

    try {
      final location = await _ipLocationService.fetchLocation(
        proxyHost: proxyAddress,
        proxyPort: proxyPort,
      );

      if (location != null && mounted) {
        _locationNotifier.value = location.displayLocation;
      }
    } catch (e) {
      _locationNotifier.value = null;
    } finally {
      if (mounted) {
        _isLoadingLocationNotifier.value = false;
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showError(context, message);
  }

  /// 从数据库根据ID加载服务器
  Future<ServerNode?> _loadServerById(String serverId) async {
    try {
      final dbHelper = DatabaseHelper();
      final serverData = await dbHelper.getServerById(serverId);

      if (serverData == null) {
        return null;
      }

      String address = '';
      int port = 443;

      try {
        final configJsonString = serverData['config_json'] as String;
        final configJson = jsonDecode(configJsonString);
        final outbounds = configJson['outbounds'] as List?;

        if (outbounds != null && outbounds.isNotEmpty) {
          final settings = outbounds[0]['settings'];
          final vnext = settings?['vnext'] as List?;

          if (vnext != null && vnext.isNotEmpty) {
            address = vnext[0]['address'] as String? ?? '';
            port = vnext[0]['port'] as int? ?? 443;
          }
        }
      } catch (e) {
        print('解析服务器配置失败: $e');
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
    } catch (e) {
      print('加载服务器失败: $e');
      return null;
    }
  }

  /// 加载上次选择的服务器并自动连接
  Future<void> _loadLastSelectedServer() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final lastServerId = _settingsManager.lastSelectedServerId;
    if (lastServerId == null || lastServerId.isEmpty) {
      return;
    }

    final server = await _loadServerById(lastServerId);

    if (server != null && mounted) {
      setState(() {
        selectedServer = server;
      });

      // 延迟300毫秒后启动连接
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted && !isConnected && !_isProcessing) {
        print('自动连接到上次选择的服务器: ${server.name}');
        await _toggleConnection();
      }
    }
  }

  Future<void> _showServerSelector() async {
    final result = await showDialog<ServerNode>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      barrierDismissible: true,
      builder: (context) =>
          ServerSelectorDialog(currentServerId: selectedServer?.id),
    );

    if (result != null && result.id != selectedServer?.id) {
      final oldServer = selectedServer;
      setState(() {
        selectedServer = result;
      });

      // 保存选择的服务器ID
      _settingsManager.setLastSelectedServerId(result.id);

      if (oldServer != null) {
        print('服务器从 ${oldServer.name} 切换到 ${result.name}');
        await _connectManager.serverChanged(result.id);
      }
    }
  }

  Future<void> _toggleConnection() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      if (!isConnected) {
        isLoadingData = true;
      }
    });

    try {
      if (isConnected) {
        await _connectManager.stop();
      } else {
        if (selectedServer == null) {
          setState(() {
            _isProcessing = false;
            isLoadingData = false;
          });
          _showErrorSnackBar('请先选择一个服务器');
          return;
        }

        await _connectManager.start(selectedServer!.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          isLoadingData = false;
        });
        _showErrorSnackBar('操作失败: $e');
      }
    }
  }

  Future<void> _copyProxyAddress() async {
    final proxyAddress = _connectManager.proxyAddress;
    final proxyPort = _connectManager.proxyPort;
    final proxyUrl = '$proxyAddress:$proxyPort';

    String textToCopy;
    if (Platform.isWindows) {
      textToCopy =
          'set http_proxy=http://$proxyUrl\nset https_proxy=http://$proxyUrl';
    } else if (Platform.isLinux || Platform.isMacOS) {
      textToCopy =
          'export http_proxy=http://$proxyUrl\nexport https_proxy=http://$proxyUrl';
    } else {
      textToCopy = 'http://$proxyUrl';
    }

    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (mounted) {
      SnackBarUtils.showSuccess(context, '代理地址已复制到剪贴板');
    }
  }

  void _onRoutingModeChanged(RoutingMode mode) {
    _settingsManager.setRoutingMode(mode);
    setState(() {});
    // 如果当前已连接，切换路由模式后自动重连
    if (isConnected && selectedServer != null) {
      _connectManager.serverChanged(selectedServer!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 上半部分：左右布局
          Expanded(
            child: Row(
              children: [
                // 左侧：连接按钮和服务器选择
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _isProcessing ? null : _toggleConnection,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isProcessing
                                  ? Colors.grey.shade600
                                  : (isConnected
                                        ? Colors.orange.shade600
                                        : _kStatusCardColor),
                              boxShadow: [
                                BoxShadow(
                                  color: _isProcessing
                                      ? Colors.black.withOpacity(0.3)
                                      : (isConnected
                                            ? Colors.orange.withOpacity(0.4)
                                            : Colors.black.withOpacity(0.3)),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: _isProcessing
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(
                                    Icons.power_settings_new,
                                    color: Colors.white,
                                    size: 56,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ServerSelectorButton(
                          selectedServer: selectedServer,
                          onTap: _showServerSelector,
                        ),
                        const SizedBox(height: 12),
                        RoutingSelectorButton(
                          currentMode: _settingsManager.routingMode,
                          onModeChanged: _onRoutingModeChanged,
                        ),
                      ],
                    ),
                  ),
                ),
                // 右侧：信息卡片
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildInfoCards(isDark),
                  ),
                ),
              ],
            ),
          ),
          // 中间部分：图表
          Expanded(
            child: SpeedChartWidget(historyNotifier: _speedHistoryNotifier),
          ),
          // 底部固定栏：代理地址和模式切换
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ProxyAddressDisplay(
                  isConnected: isConnected,
                  proxyAddress: _connectManager.proxyAddress,
                  proxyPort: _connectManager.proxyPort,
                  onCopy: _copyProxyAddress,
                ),
                const Spacer(),
                ModeSwitcher(
                  currentMode: _connectManager.currentMode,
                  switchingToMode: _connectManager.switchingToMode,
                  onChanged: (mode) async {
                    _connectManager.switchMode(mode);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(bool isDark) {
    final cardColor = isDark ? _kStatusCardColor : Colors.white;
    final textColor = isDark
        ? Colors.white.withOpacity(0.9)
        : Colors.black.withOpacity(0.8);
    final subtextColor = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.5);

    return Column(
      children: [
        // 第一行：延迟和服务器
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isTestingLatencyNotifier,
                  builder: (context, isTesting, child) {
                    return ValueListenableBuilder<int>(
                      valueListenable: _latencyNotifier,
                      builder: (context, latency, child) {
                        return _buildLatencyCard(
                          latency: latency,
                          isLoading: isTesting,
                          cardColor: cardColor,
                          textColor: textColor,
                          subtextColor: subtextColor,
                          isDark: isDark,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<TrafficStats>(
                  valueListenable: _trafficStatsService.statsNotifier,
                  builder: (context, stats, child) {
                    return _buildTrafficCard(
                      stats: stats,
                      cardColor: cardColor,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      isDark: isDark,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 第二行：速度和位置
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<SpeedData>(
                  valueListenable: _speedDataNotifier,
                  builder: (context, speedData, child) {
                    return _buildSpeedCard(
                      speedData: speedData,
                      cardColor: cardColor,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      isDark: isDark,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isLoadingLocationNotifier,
                  builder: (context, isLoading, child) {
                    return ValueListenableBuilder<String?>(
                      valueListenable: _locationNotifier,
                      builder: (context, location, _) {
                        return _buildInfoCard(
                          icon: Icons.location_on_rounded,
                          title: '位置',
                          value: location ?? '--',
                          color: Colors.orange.shade600,
                          cardColor: cardColor,
                          textColor: textColor,
                          subtextColor: subtextColor,
                          isLoading: isLoading,
                          isDark: isDark,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
    required bool isLoading,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (isLoading)
            _buildLoadingSkeleton(isDark, width: 80, height: 18)
          else
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildTrafficCard({
    required TrafficStats stats,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.shade600.withOpacity(0.15),
                ),
                child: Icon(
                  Icons.data_usage_rounded,
                  color: Colors.purple.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '流量',
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (stats.totalDownlink == 0 && stats.totalUplink == 0)
            Text(
              '--',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.green.shade600,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        stats.formattedDownload,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.blue.shade600,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        stats.formattedUpload,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard({
    required SpeedData speedData,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade600.withOpacity(0.15),
                ),
                child: Icon(
                  Icons.swap_vert_rounded,
                  color: Colors.green.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '速度',
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (speedData.isTestingSpeed)
            _buildLoadingSkeleton(isDark, width: double.infinity, height: 18)
          else if (speedData.isConnected)
            Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.green.shade600,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${speedData.downloadSpeed.toStringAsFixed(1)} MB/s',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.blue.shade600,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${speedData.uploadSpeed.toStringAsFixed(1)} MB/s',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Text(
              '--',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  /// 根据延迟值获取颜色和信号强度
  ({Color color, IconData icon, String quality}) _getLatencyInfo(int latency) {
    if (latency < 0) {
      return (
        color: Colors.grey.shade600,
        icon: Icons.signal_cellular_off_rounded,
        quality: '未知',
      );
    } else if (latency < 50) {
      return (
        color: Colors.green.shade600,
        icon: Icons.signal_cellular_alt_rounded,
        quality: '优秀',
      );
    } else if (latency < 100) {
      return (
        color: Colors.lightGreen.shade600,
        icon: Icons.signal_cellular_alt_rounded,
        quality: '良好',
      );
    } else if (latency < 200) {
      return (
        color: Colors.orange.shade600,
        icon: Icons.signal_cellular_alt_2_bar_rounded,
        quality: '一般',
      );
    } else if (latency < 300) {
      return (
        color: Colors.deepOrange.shade600,
        icon: Icons.signal_cellular_alt_1_bar_rounded,
        quality: '较差',
      );
    } else {
      return (
        color: Colors.red.shade600,
        icon: Icons.signal_cellular_alt_1_bar_rounded,
        quality: '很差',
      );
    }
  }

  Widget _buildLatencyCard({
    required int latency,
    required bool isLoading,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
  }) {
    final latencyInfo = _getLatencyInfo(latency);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: latencyInfo.color.withOpacity(0.15),
                ),
                child: Icon(
                  latencyInfo.icon,
                  color: latencyInfo.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '延迟',
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (isLoading)
            _buildLoadingSkeleton(isDark, width: 80, height: 18)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  latency >= 0 ? '${latency}ms' : '--',
                  style: TextStyle(
                    color: latencyInfo.color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(
    bool isDark, {
    required double width,
    required double height,
  }) {
    return _ShimmerLoadingWidget(
      isDark: isDark,
      width: width,
      height: height,
    );
  }
}

/// 带有光照划过效果的骨架屏组件
class _ShimmerLoadingWidget extends StatefulWidget {
  final bool isDark;
  final double width;
  final double height;

  const _ShimmerLoadingWidget({
    required this.isDark,
    required this.width,
    required this.height,
  });

  @override
  State<_ShimmerLoadingWidget> createState() => _ShimmerLoadingWidgetState();
}

class _ShimmerLoadingWidgetState extends State<_ShimmerLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    while (mounted) {
      await _shimmerController.forward(from: 0.0);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        // 将 progress (0.0 ~ 1.0) 映射到 (-0.3 ~ 1.3)
        // 这样光照会从左边完全外部开始，到右边完全外部结束
        final progress = _shimmerAnimation.value * 1.6 - 0.3;
        
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: widget.isDark
                  ? [
                      const Color(0xFF3C3F41),
                      const Color(0xFF4A4D50),
                      const Color(0xFF5A5D60),
                      const Color(0xFF4A4D50),
                      const Color(0xFF3C3F41),
                    ]
                  : [
                      Colors.grey.shade300,
                      Colors.grey.shade200,
                      Colors.grey.shade100,
                      Colors.grey.shade200,
                      Colors.grey.shade300,
                    ],
              stops: [
                (progress - 0.3).clamp(0.0, 1.0),
                (progress - 0.15).clamp(0.0, 1.0),
                progress.clamp(0.0, 1.0),
                (progress + 0.15).clamp(0.0, 1.0),
                (progress + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ModeSwitcher extends StatelessWidget {
  final ProxyMode currentMode;
  final ProxyMode? switchingToMode;
  final ValueChanged<ProxyMode> onChanged;

  const ModeSwitcher({
    super.key,
    required this.currentMode,
    this.switchingToMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? _kStatusCardColor : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            context,
            mode: ProxyMode.proxy,
            icon: Icons.router_rounded,
            label: '系统代理',
            isDark: isDark,
          ),
          const SizedBox(width: 3),
          _buildModeButton(
            context,
            mode: ProxyMode.tun,
            icon: Icons.tune_rounded,
            label: 'TUN',
            isDark: isDark,
          ),
          const SizedBox(width: 3),
          _buildModeButton(
            context,
            mode: ProxyMode.noProxy,
            icon: Icons.block_rounded,
            label: '无代理',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required ProxyMode mode,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = currentMode == mode;
    final isSwitching = switchingToMode == mode;
    final hasAnySwitching = switchingToMode != null;
    final isDisabled = hasAnySwitching && !isSwitching && !isSelected;

    return GestureDetector(
      onTap: () {
        // 防抖：如果有任何切换正在进行，禁止点击
        if (hasAnySwitching) return;
        if (!isSelected) {
          onChanged(mode);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSwitching)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color.fromARGB(255, 219, 219, 219),
                  ),
                ),
              )
            else
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDisabled
                          ? (isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.2))
                          : (isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.4))),
                size: 14,
              ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDisabled
                          ? (isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.2))
                          : (isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.4))),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 服务器选择按钮组件
class ServerSelectorButton extends StatefulWidget {
  final ServerNode? selectedServer;
  final VoidCallback onTap;

  const ServerSelectorButton({
    super.key,
    required this.selectedServer,
    required this.onTap,
  });

  @override
  State<ServerSelectorButton> createState() => _ServerSelectorButtonState();
}

class _ServerSelectorButtonState extends State<ServerSelectorButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasSelection = widget.selectedServer != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? const Color(0xFF3C3F41) : Colors.grey.shade200)
                : (isDark ? const Color(0xFF343638) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 左侧图标/国旗
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2B2D30)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: hasSelection
                    ? Text(
                        widget.selectedServer!.countryFlag,
                        style: const TextStyle(fontSize: 14),
                      )
                    : Icon(
                        Icons.dns_rounded,
                        color: Colors.white.withOpacity(0.5),
                        size: 14,
                      ),
              ),
              const SizedBox(width: 10),
              // 服务器名称
              Text(
                hasSelection ? widget.selectedServer!.name : '选择服务器',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              // 右侧切换图标
              Icon(
                Icons.swap_horiz_rounded,
                color: hasSelection
                    ? Colors.orange.shade600
                    : Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 代理地址显示组件
class ProxyAddressDisplay extends StatefulWidget {
  final bool isConnected;
  final String proxyAddress;
  final int proxyPort;
  final VoidCallback onCopy;

  const ProxyAddressDisplay({
    super.key,
    required this.isConnected,
    required this.proxyAddress,
    required this.proxyPort,
    required this.onCopy,
  });

  @override
  State<ProxyAddressDisplay> createState() => _ProxyAddressDisplayState();
}

class _ProxyAddressDisplayState extends State<ProxyAddressDisplay> {
  bool _isCopyHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final proxyUrl = '${widget.proxyAddress}:${widget.proxyPort}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.router_rounded,
            size: 16,
            color: isDark
                ? Colors.white.withOpacity(0.7)
                : Colors.black.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            proxyUrl,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.85)
                  : Colors.black.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            onEnter: (_) => setState(() => _isCopyHovered = true),
            onExit: (_) => setState(() => _isCopyHovered = false),
            child: GestureDetector(
              onTap: widget.onCopy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _isCopyHovered
                      ? Colors.orange.shade600.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.content_copy_rounded,
                  size: 14,
                  color: _isCopyHovered
                      ? Colors.orange.shade600
                      : (isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 路由选择按钮组件
class RoutingSelectorButton extends StatefulWidget {
  final RoutingMode currentMode;
  final ValueChanged<RoutingMode> onModeChanged;

  const RoutingSelectorButton({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  State<RoutingSelectorButton> createState() => _RoutingSelectorButtonState();
}

class _RoutingSelectorButtonState extends State<RoutingSelectorButton> {
  bool _isHovered = false;
  List<Map<String, dynamic>> _userRules = [];
  String? _selectedUserRuleName; // 当前选中的用户规则名称

  @override
  void initState() {
    super.initState();
    _loadUserRules();
  }

  Future<void> _loadUserRules() async {
    final rows = await DatabaseHelper().getAllRoutingRules();
    if (mounted) setState(() => _userRules = rows);
  }

  IconData _getModeIcon(RoutingMode mode) {
    switch (mode) {
      case RoutingMode.rule:
        return Icons.alt_route_rounded;
      case RoutingMode.global:
        return Icons.public_rounded;
      case RoutingMode.direct:
        return Icons.link_rounded;
    }
  }

  PopupMenuItem<String> _buildBuiltinItem(RoutingMode mode, bool isDark) {
    final isSelected = mode == widget.currentMode;
    return PopupMenuItem<String>(
      value: 'builtin:${mode.name}',
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Colors.orange.shade600.withOpacity(0.15)
                  : (isDark ? const Color(0xFF3C3F41) : Colors.grey.shade200),
            ),
            alignment: Alignment.center,
            child: Icon(_getModeIcon(mode),
                size: 14,
                color: isSelected
                    ? Colors.orange.shade600
                    : (isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.6))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mode.displayName,
                    style: TextStyle(
                        color: isSelected
                            ? Colors.orange.shade600
                            : (isDark
                                ? Colors.white.withOpacity(0.9)
                                : Colors.black.withOpacity(0.8)),
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal)),
                Text(mode.description,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.4),
                        fontSize: 11)),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 16, color: Colors.orange.shade600),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildUserRuleItem(
      Map<String, dynamic> row, bool isDark) {
    final id = row['id'] as int;
    final name = row['name'] as String;
    return PopupMenuItem<String>(
      value: 'user:$id',
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF3C3F41) : Colors.grey.shade200,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.tune_rounded,
                size: 14,
                color: isDark
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black.withOpacity(0.8))),
          ),
        ],
      ),
    );
  }

  void _showRoutingMenu() async {
    await _loadUserRules();
    if (!mounted) return;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    final Size size = button.size;
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = <PopupMenuEntry<String>>[
      _buildBuiltinItem(RoutingMode.rule, isDark),
      _buildBuiltinItem(RoutingMode.global, isDark),
      _buildBuiltinItem(RoutingMode.direct, isDark),
      if (_userRules.isNotEmpty) ...[const PopupMenuDivider(height: 1),
        ..._userRules.map((row) => _buildUserRuleItem(row, isDark)),
      ],
    ];

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        offset.dy + size.height + 200,
      ),
      color: isDark ? const Color(0xFF2B2D30) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: items,
    );

    if (value == null || !mounted) return;
    if (value.startsWith('builtin:')) {
      final modeName = value.substring('builtin:'.length);
      final mode = RoutingMode.values.firstWhere((m) => m.name == modeName);
      setState(() => _selectedUserRuleName = null);
      widget.onModeChanged(mode);
    } else if (value.startsWith('user:')) {
      final id = int.parse(value.substring('user:'.length));
      final row = _userRules.firstWhere((r) => r['id'] == id);
      setState(() => _selectedUserRuleName = row['name'] as String);
      widget.onModeChanged(RoutingMode.rule);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _showRoutingMenu,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? const Color(0xFF3C3F41) : Colors.grey.shade200)
                : (isDark ? const Color(0xFF343638) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.orange.shade600.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _selectedUserRuleName != null
                      ? Icons.tune_rounded
                      : _getModeIcon(widget.currentMode),
                  color: Colors.orange.shade600,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _selectedUserRuleName ?? widget.currentMode.displayName,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.expand_more_rounded,
                color: Colors.orange.shade600,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
