import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

/// 自定义 Tab 项
class CustomTab {
  final String label;
  final IconData icon;

  const CustomTab({
    required this.label,
    required this.icon,
  });
}

/// 自定义扁平化 Tab Bar
class CustomTabBar extends StatelessWidget {
  final List<CustomTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const CustomTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF2B2D30)
            : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          return _TabItem(
            tab: tabs[index],
            isSelected: currentIndex == index,
            isDark: isDark,
            onTap: () => onTabChanged(index),
          );
        }),
      ),
    );
  }
}

/// Tab 项组件
class _TabItem extends StatefulWidget {
  final CustomTab tab;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabItem({
    required this.tab,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isSelected
        ? Colors.orange.shade600
        : (widget.isDark
            ? Colors.white.withOpacity(_isHovered ? 0.8 : 0.6)
            : Colors.black.withOpacity(_isHovered ? 0.7 : 0.5));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.tab.icon,
                    size: 18,
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.tab.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: widget.isSelected 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 激活指示器横线
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2,
                width: widget.isSelected ? 40 : 0,
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
