import 'package:fluent_ui/fluent_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v2go/managers/app_settings_manager.dart';

/// 主题模式枚举
enum AppThemeMode { light, dark }

/// 主题管理器 - 单例模式
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();

  factory ThemeManager() {
    return _instance;
  }

  ThemeManager._internal() {
    _loadTheme();
  }

  // 当前主题模式
  AppThemeMode _themeMode = AppThemeMode.dark;
  AppThemeMode get themeMode => _themeMode;

  // SharedPreferences 键
  static const String _themeModeKey = 'theme_mode';

  /// 获取 FluentThemeData
  FluentThemeData getThemeData() {
    return _themeMode == AppThemeMode.light ? _lightTheme : _darkTheme;
  }

  /// 浅色主题
  static final FluentThemeData _lightTheme = FluentThemeData(
    brightness: Brightness.light,
    accentColor: Colors.blue,
    fontFamily: 'Microsoft YaHei', // 设置全局字体
    scaffoldBackgroundColor: Colors.white,
    navigationPaneTheme: NavigationPaneThemeData(
      backgroundColor: Colors.white,
      overlayBackgroundColor: Colors.transparent,
      highlightColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(
      decoration: BoxDecoration(color: Colors.transparent),
      thickness: 0,
      verticalMargin: EdgeInsets.zero,
      horizontalMargin: EdgeInsets.zero,
    ),
  );

  /// 深色主题
  static final FluentThemeData _darkTheme = FluentThemeData(
    brightness: Brightness.dark,
    accentColor: Colors.blue,
    fontFamily: 'Microsoft YaHei', // 设置全局字体
    scaffoldBackgroundColor: const Color(0xFF1E1E1E),
    navigationPaneTheme: NavigationPaneThemeData(
      backgroundColor: const Color(0xFF2D2D30),
      overlayBackgroundColor: Colors.transparent,
      highlightColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(
      decoration: BoxDecoration(color: Colors.transparent),
      verticalMargin: EdgeInsets.zero,
      horizontalMargin: EdgeInsets.zero,
    ),
  );

  /// 切换主题
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    // 保存到本地存储
    await _saveTheme();
  }

  /// 从本地存储加载主题
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString(_themeModeKey);

      if (themeModeString != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.toString() == themeModeString,
          orElse: () => AppThemeMode.dark,
        );
        notifyListeners();
      }
    } catch (e) {
      print('加载主题失败: $e');
    }
  }

  /// 保存主题到本地存储
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, _themeMode.toString());
    } catch (e) {
      print('保存主题失败: $e');
    }
  }

  /// 是否为深色主题
  bool get isDarkMode => _themeMode == AppThemeMode.dark;

  /// 是否为浅色主题
  bool get isLightMode => _themeMode == AppThemeMode.light;
}
