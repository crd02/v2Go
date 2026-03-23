import 'package:fluent_ui/fluent_ui.dart';
import 'package:v2go/features/home/home_page.dart';
import 'package:v2go/features/logs/logs_page.dart';
import 'package:v2go/features/routing/routing_page.dart';
import 'package:v2go/features/server/pages/server_config_page.dart';
import 'package:v2go/features/settings/settings_page.dart';
import 'package:window_manager/window_manager.dart';

/// 主框架组件
/// 使用 fluent_ui 的 NavigationPane 实现侧边导航
class MainFrame extends StatefulWidget {
  const MainFrame({super.key});

  @override
  State<MainFrame> createState() => _MainFrameState();
}

class _MainFrameState extends State<MainFrame> {
  int _selectedIndex = 0;

  PaneDisplayMode _displayMode = PaneDisplayMode.compact;

  final _homePageKey = GlobalKey();
  final _serverConfigPageKey = GlobalKey();
  final _logsPageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildContent() {
    return RepaintBoundary(
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          _PageWrapper(key: _homePageKey, child: const HomePage()),
          _PageWrapper(
            key: _serverConfigPageKey,
            child: const ServerConfigPage(),
          ),
          const _PageWrapper(child: RoutingPage()),
          _PageWrapper(key: _logsPageKey, child: const LogsPage()),
          const _AboutPage(),
          SettingsPage(
            displayMode: _displayMode,
            onDisplayModeChanged: (mode) {
              setState(() {
                _displayMode = mode;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    return NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        leading: () {
          return DragToMoveArea(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.light, Colors.orange.dark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        FluentIcons.globe,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'V2Go',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        }(),
        title: const DragToMoveArea(
          child: SizedBox.expand(),
        ),
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WindowButton(
              icon: FluentIcons.chrome_minimize,
              onPressed: () => windowManager.minimize(),
            ),
            const _MaximizeButton(),
            _WindowButton(
              icon: FluentIcons.chrome_close,
              onPressed: () => windowManager.hide(),
              isClose: true,
            ),
          ],
        ),
      ),
      pane: NavigationPane(
        selected: _selectedIndex,
        onChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        displayMode: _displayMode,
        size: const NavigationPaneSize(openWidth: 200, compactWidth: 50),
        header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.light, Colors.orange.dark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  FluentIcons.globe,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              if (_displayMode == PaneDisplayMode.open) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'V2Ray',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('首页'),
            body: content,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.server),
            title: const Text('服务器'),
            body: content,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.globe),
            title: const Text('路由'),
            body: content,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.history),
            title: const Text('日志'),
            body: content,
          ),
        ],
        footerItems: [
          PaneItem(
            icon: const Icon(FluentIcons.info),
            title: const Text('关于'),
            body: content,
          ),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('设置'),
            body: content,
          ),
        ],
      ),
    );
  }
}

/// 页面包装器，用于统一页面样式
class _PageWrapper extends StatelessWidget {
  final Widget child;

  const _PageWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}


/// 关于页面
class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(title: Text('关于')),
      content: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.light, Colors.purple.light],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    FluentIcons.streaming,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text('V2Go', style: FluentTheme.of(context).typography.title),
                const SizedBox(height: 8),
                Text(
                  '版本 1.0.0',
                  style: FluentTheme.of(
                    context,
                  ).typography.body?.copyWith(color: Colors.grey[120]),
                ),
                const SizedBox(height: 16),
                const Text('一个简洁的 V2Ray 客户端', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.open_source, size: 16),
                          SizedBox(width: 8),
                          Text('GitHub'),
                        ],
                      ),
                      onPressed: () {
                        // 打开 GitHub 链接
                      },
                    ),
                    const SizedBox(width: 12),
                    Button(
                      child: const Text('检查更新'),
                      onPressed: () {
                        // 检查更新
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 最大化/还原按钮，使用自定义图标避免与系统图标冲突
class _MaximizeButton extends StatefulWidget {
  const _MaximizeButton();

  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> with WindowListener {
  bool _isHovered = false;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _updateMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _updateMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () async {
          if (_isMaximized) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        },
        child: Container(
          width: 46,
          height: 40,
          color: _isHovered
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          child: Icon(
            _isMaximized ? FluentIcons.chrome_restore : FluentIcons.square_shape,
            size: 12,
          ),
        ),
      ),
    );
  }
}

/// 窗口控制按钮
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 40,
          color: _isHovered
              ? (widget.isClose
                    ? const Color(0xFFE81123)
                    : Colors.white.withValues(alpha: 0.1))
              : Colors.transparent,
          child: Icon(widget.icon, size: 12),
        ),
      ),
    );
  }
}
