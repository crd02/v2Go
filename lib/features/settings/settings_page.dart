import 'package:fluent_ui/fluent_ui.dart';
import 'package:v2go/managers/app_settings_manager.dart';
import 'package:v2go/managers/theme_manager.dart';

/// 设置页面组件
class SettingsPage extends StatelessWidget {
  final PaneDisplayMode displayMode;
  final ValueChanged<PaneDisplayMode> onDisplayModeChanged;

  const SettingsPage({
    super.key,
    required this.displayMode,
    required this.onDisplayModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final settingsManager = AppSettingsManager();

    return ScaffoldPage(
      header: const PageHeader(title: Text('设置')),
      content: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 外观设置
          Text('外观', style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 主题切换
                ListenableBuilder(
                  listenable: themeManager,
                  builder: (context, _) {
                    return ListTile(
                      leading: Icon(
                        themeManager.isDarkMode
                            ? FluentIcons.clear_night
                            : FluentIcons.sunny,
                      ),
                      title: const Text('主题模式'),
                      subtitle: const Text('选择应用的主题外观'),
                      trailing: ComboBox<AppThemeMode>(
                        value: themeManager.themeMode,
                        items: const [
                          ComboBoxItem(
                            value: AppThemeMode.light,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.sunny, size: 16),
                                SizedBox(width: 8),
                                Text('浅色'),
                              ],
                            ),
                          ),
                          ComboBoxItem(
                            value: AppThemeMode.dark,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.clear_night, size: 16),
                                SizedBox(width: 8),
                                Text('深色'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (mode) {
                          if (mode != null) {
                            themeManager.setThemeMode(mode);
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 连接设置
          Text('连接', style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: settingsManager,
            builder: (context, _) {
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(FluentIcons.play),
                      title: const Text('开机自启'),
                      subtitle: const Text('系统启动时自动运行'),
                      trailing: ToggleSwitch(
                        checked: settingsManager.autoStart,
                        onChanged: (value) {
                          settingsManager.setAutoStart(value);
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(FluentIcons.plug_connected),
                      title: const Text('自动连接'),
                      subtitle: const Text('启动时自动连接上次使用的服务器'),
                      trailing: ToggleSwitch(
                        checked: settingsManager.autoConnect,
                        onChanged: (value) {
                          settingsManager.setAutoConnect(value);
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(FluentIcons.diagnostic),
                      title: const Text('系统代理'),
                      subtitle: const Text('连接时自动设置系统代理'),
                      trailing: ToggleSwitch(
                        checked: settingsManager.systemProxy,
                        onChanged: (value) {
                          settingsManager.setSystemProxy(value);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // 代理设置
          Text('代理端口', style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: settingsManager,
            builder: (context, _) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: InfoLabel(
                          label: 'HTTP 端口',
                          child: NumberBox<int>(
                            value: settingsManager.httpPort,
                            min: 1024,
                            max: 65535,
                            onChanged: (value) {
                              if (value != null) {
                                settingsManager.setHttpPort(value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InfoLabel(
                          label: 'SOCKS 端口',
                          child: NumberBox<int>(
                            value: settingsManager.socksPort,
                            min: 1024,
                            max: 65535,
                            onChanged: (value) {
                              if (value != null) {
                                settingsManager.setSocksPort(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
