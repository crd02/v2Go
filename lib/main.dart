import 'package:fluent_ui/fluent_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v2go/features/main_frame/main_frame.dart';
import 'package:v2go/managers/theme_manager.dart';
import 'package:v2go/managers/connect_manager.dart';
import 'package:v2go/managers/app_settings_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:http/http.dart' as http;


void main(List<String> args) async {
  final bool hideWindow = args.contains('--hidewindow');

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(900, 650),
    center: true,
    title: 'V2Go',
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);

    if (!hideWindow) {
      await windowManager.show();
      await windowManager.focus();
    } else {
      await windowManager.setSkipTaskbar(true);
    }
    _initSystemTray();
  });

  runApp(const MyApp());
}

Future<void> _initSystemTray() async {
  String iconPath;
  if (Platform.isWindows) {
    iconPath = 'assets/app_icon.ico';
  } else if (Platform.isMacOS) {
    iconPath = 'assets/app_icon.png';
  } else {
    iconPath = 'assets/app_icon.png';
  }

  await trayManager.setIcon(iconPath);
  Menu menu = Menu(
    items: [
      MenuItem(key: 'show', label: '显示窗口'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: '退出'),
    ],
  );
  await trayManager.setContextMenu(menu);
}

Future<void> _cleanup() async {
  try {
    final connectManager = ConnectManager();
    await connectManager.dispose();
    print('资源清理完成');
  } catch (e) {
    print('清理资源时出错: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
    with WidgetsBindingObserver, TrayListener, WindowListener {
  final ThemeManager _themeManager = ThemeManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    trayManager.addListener(this);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      _showWindow();
    } else if (menuItem.key == 'exit') {
      _exitApp();
    }
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> _showWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exitApp() async {
    await _cleanup();
    await windowManager.destroy();
    exit(0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      print('应用即将退出，清理资源...');
      _cleanup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeManager,
      builder: (context, _) {
        return FluentApp(
          title: 'V2Go',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return DefaultTextStyle(
              style: const TextStyle(fontFamily: 'Microsoft YaHei'),
              child: child!,
            );
          },
          theme: _themeManager.getThemeData(),
          home: const MainFrame(),
        );
      },
    );
  }
}
