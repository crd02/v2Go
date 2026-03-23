import 'package:fluent_ui/fluent_ui.dart';
import '../../managers/log_manager.dart';

/// 日志页面
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final LogManager _logManager = LogManager();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    // 初始化文本内容
    _textController.text = _formatLogText();
    // 监听日志更新
    _logManager.addListener(_onLogUpdated);
    // 在下一帧滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _logManager.removeListener(_onLogUpdated);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onLogUpdated() {
    if (mounted) {
      setState(() {
        _textController.text = _formatLogText();
      });
      // 当日志更新时，自动滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _getLogLevelLabel(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.debug:
        return 'DEBUG';
    }
  }

  String _formatLogText() {
    return _logManager.logs.map((log) {
      return '${log.formattedTimestamp} [${_getLogLevelLabel(log.level).padRight(5)}] ${log.message}';
    }).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('连接日志'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 自动滚动开关
            ToggleSwitch(
              checked: _autoScroll,
              onChanged: (value) {
                setState(() {
                  _autoScroll = value;
                });
              },
              content: const Text('自动滚动'),
            ),
            const SizedBox(width: 12),
            // 清空日志按钮
            FilledButton(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.clear, size: 16),
                  SizedBox(width: 6),
                  Text('清空日志'),
                ],
              ),
              onPressed: () {
                _logManager.clear();
              },
            ),
          ],
        ),
      ),
      content: _logManager.logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.info_solid,
                    size: 64,
                    color: Colors.grey[100],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无日志',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '连接服务器后将显示日志信息',
                    style: FluentTheme.of(context)
                        .typography
                        .body
                        ?.copyWith(color: Colors.grey[120]),
                  ),
                ],
              ),
            )
          : Container(
              padding: const EdgeInsets.all(12),
              child: Card(
                backgroundColor: FluentTheme.of(context).micaBackgroundColor,
                padding: const EdgeInsets.all(8),
                child: TextBox(
                  controller: _textController,
                  maxLines: null,
                  readOnly: true,
                  scrollController: _scrollController,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                  ),
                  decoration: WidgetStateProperty.all(
                    BoxDecoration(
                      color: FluentTheme.of(context).micaBackgroundColor,
                      border: Border.all(
                        color: Colors.transparent,
                        width: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
