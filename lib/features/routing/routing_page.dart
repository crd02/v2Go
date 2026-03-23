import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:v2go/core/database/database_helper.dart';

/// 流量模式枚举
enum TrafficMode { auto, globalProxy, globalDirect }

/// 规则动作枚举
enum RuleAction { proxy, direct }

/// 规则匹配类型
enum MatchType { appName, ip, domain }

/// 单条规则条目
class RuleEntry {
  MatchType matchType;
  String value;
  RuleAction action;

  RuleEntry({
    required this.matchType,
    required this.value,
    this.action = RuleAction.proxy,
  });
}

/// 路由规则
class RoutingRuleGroup {
  int? id; // 数据库主键
  String name;
  TrafficMode inheritFrom;
  List<RuleEntry> entries;

  RoutingRuleGroup({
    this.id,
    required this.name,
    this.inheritFrom = TrafficMode.auto,
    List<RuleEntry>? entries,
  }) : entries = entries ?? [];
}

// ---------------------------------------------------------------------------
// 枚举与数据库字符串互转
// ---------------------------------------------------------------------------

TrafficMode _trafficModeFromString(String s) {
  switch (s) {
    case 'globalProxy': return TrafficMode.globalProxy;
    case 'globalDirect': return TrafficMode.globalDirect;
    default: return TrafficMode.auto;
  }
}

String _trafficModeToString(TrafficMode m) {
  switch (m) {
    case TrafficMode.globalProxy: return 'globalProxy';
    case TrafficMode.globalDirect: return 'globalDirect';
    case TrafficMode.auto: return 'auto';
  }
}

MatchType _matchTypeFromString(String s) {
  switch (s) {
    case 'appName': return MatchType.appName;
    case 'ip': return MatchType.ip;
    default: return MatchType.domain;
  }
}

String _matchTypeToString(MatchType m) {
  switch (m) {
    case MatchType.appName: return 'appName';
    case MatchType.ip: return 'ip';
    case MatchType.domain: return 'domain';
  }
}

RuleAction _ruleActionFromString(String s) =>
    s == 'direct' ? RuleAction.direct : RuleAction.proxy;


class RoutingPage extends StatefulWidget {
  const RoutingPage({super.key});

  @override
  State<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  final List<RoutingRuleGroup> _rules = [];
  final _db = DatabaseHelper();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final rows = await _db.getAllRoutingRules();
    final rules = rows.map((row) {
      final entries = (row['entries'] as List<Map<String, dynamic>>)
          .map((e) => RuleEntry(
                matchType: _matchTypeFromString(e['match_type'] as String),
                value: e['value'] as String,
                action: _ruleActionFromString(e['action'] as String),
              ))
          .toList();
      return RoutingRuleGroup(
        id: row['id'] as int,
        name: row['name'] as String,
        inheritFrom: _trafficModeFromString(row['inherit_from'] as String),
        entries: entries,
      );
    }).toList();
    if (mounted) setState(() { _rules
      ..clear()
      ..addAll(rules);
      _loading = false;
    });
  }

  Future<void> _saveRule(RoutingRuleGroup rule, {int? listIndex}) async {
    final entryMaps = rule.entries
        .map((e) => {
              'match_type': _matchTypeToString(e.matchType),
              'value': e.value,
              'action': e.action == RuleAction.proxy ? 'proxy' : 'direct',
            })
        .toList();

    if (rule.id == null) {
      final newId = await _db.insertRoutingRule(
        name: rule.name,
        inheritFrom: _trafficModeToString(rule.inheritFrom),
        sortOrder: _rules.length,
        entries: entryMaps,
      );
      rule.id = newId;
      setState(() => _rules.add(rule));
    } else {
      await _db.updateRoutingRule(
        id: rule.id!,
        name: rule.name,
        inheritFrom: _trafficModeToString(rule.inheritFrom),
        sortOrder: listIndex ?? _rules.indexOf(rule),
        entries: entryMaps,
      );
      setState(() => _rules[listIndex!] = rule);
    }
  }

  Future<void> _deleteRule(int index) async {
    final rule = _rules[index];
    if (rule.id != null) await _db.deleteRoutingRule(rule.id!);
    setState(() => _rules.removeAt(index));
  }

  void _openDialog({RoutingRuleGroup? existing, int? index}) async {
    final result = await showDialog<RoutingRuleGroup>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _RuleEditDialog(existing: existing),
    );
    if (result != null) {
      await _saveRule(result, listIndex: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('路由规则'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('新建规则'),
              onPressed: () => _openDialog(),
            ),
          ],
        ),
      ),
      content: _loading
          ? const Center(child: ProgressRing())
          : _rules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.branch_fork,
                      size: 64,
                      color: FluentTheme.of(context).inactiveColor),
                  const SizedBox(height: 16),
                  Text('暂无路由规则',
                      style: FluentTheme.of(context).typography.subtitle),
                  const SizedBox(height: 8),
                  Text(
                    '点击右上角「新建规则」添加',
                    style: FluentTheme.of(context)
                        .typography
                        .body
                        ?.copyWith(
                            color: FluentTheme.of(context).inactiveColor),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rules.length,
              itemBuilder: (context, i) {
                final rule = _rules[i];
                return _RuleCard(
                  rule: rule,
                  onEdit: () => _openDialog(existing: rule, index: i),
                  onDelete: () => _deleteRule(i),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 规则卡片
// ---------------------------------------------------------------------------

class _RuleCard extends StatelessWidget {
  final RoutingRuleGroup rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleCard(
      {required this.rule, required this.onEdit, required this.onDelete});

  String _modeLabel(TrafficMode m) {
    switch (m) {
      case TrafficMode.auto:
        return '自动分流';
      case TrafficMode.globalProxy:
        return '全局代理';
      case TrafficMode.globalDirect:
        return '全局直连';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D30) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child:
                        Text(rule.name, style: theme.typography.bodyStrong)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_modeLabel(rule.inheritFrom),
                      style:
                          TextStyle(fontSize: 12, color: theme.accentColor)),
                ),
                const SizedBox(width: 8),
                IconButton(
                    icon: const Icon(FluentIcons.edit, size: 14),
                    onPressed: onEdit),
                IconButton(
                    icon: const Icon(FluentIcons.delete, size: 14),
                    onPressed: onDelete),
              ],
            ),
            if (rule.entries.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...rule.entries.map((e) => _EntryChip(entry: e, isDark: isDark)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EntryChip extends StatelessWidget {
  final RuleEntry entry;
  final bool isDark;

  const _EntryChip({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isProxy = entry.action == RuleAction.proxy;
    final actionColor = isProxy ? Colors.blue : Colors.green;
    String typeLabel;
    switch (entry.matchType) {
      case MatchType.appName: typeLabel = '程序'; break;
      case MatchType.ip: typeLabel = 'IP'; break;
      case MatchType.domain: typeLabel = '域名'; break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(typeLabel,
                style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.5))),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(entry.value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(isProxy ? '代理' : '直连',
                style: TextStyle(fontSize: 11, color: actionColor)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 编辑规则 Dialog
// ---------------------------------------------------------------------------

class _RuleEditDialog extends StatefulWidget {
  final RoutingRuleGroup? existing;

  const _RuleEditDialog({this.existing});

  @override
  State<_RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<_RuleEditDialog> {
  final _nameController = TextEditingController();
  TrafficMode _inheritFrom = TrafficMode.auto;
  final List<RuleEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _inheritFrom = e.inheritFrom;
      _entries.addAll(e.entries.map((r) =>
          RuleEntry(matchType: r.matchType, value: r.value, action: r.action)));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addEntry() async {
    final entry = await showDialog<RuleEntry>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      barrierDismissible: true,
      builder: (ctx) => const _AddEntryDialog(),
    );
    if (entry != null) setState(() => _entries.add(entry));
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(RoutingRuleGroup(
      id: widget.existing?.id,
      name: name,
      inheritFrom: _inheritFrom,
      entries: List.from(_entries),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return material.Theme(
      data: material.ThemeData.dark(),
      child: material.BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: ContentDialog(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          title: Text(widget.existing == null ? '新建规则' : '编辑规则'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 规则名称
              const Text('规则名称',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextBox(
                  controller: _nameController,
                  placeholder: '输入规则名称'),
              const SizedBox(height: 14),

              // 继承自
              const Text('继承自',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              ComboBox<TrafficMode>(
                isExpanded: true,
                value: _inheritFrom,
                onChanged: (v) {
                  if (v != null) setState(() => _inheritFrom = v);
                },
                items: const [
                  ComboBoxItem(
                      value: TrafficMode.auto, child: Text('自动分流')),
                  ComboBoxItem(
                      value: TrafficMode.globalProxy, child: Text('全局代理')),
                  ComboBoxItem(
                      value: TrafficMode.globalDirect, child: Text('全局直连')),
                ],
              ),
              const SizedBox(height: 14),

              // 条目列表头
              Row(
                children: [
                  const Expanded(
                    child: Text('规则条目',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  Button(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4)),
                    ),
                    onPressed: _addEntry,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('添加', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 条目列表
              Expanded(
                child: _entries.isEmpty
                    ? Center(
                        child: Text(
                          '暂无条目，点击添加',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.35)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => Divider(
                          style: DividerThemeData(
                            thickness: 1,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                        itemBuilder: (context, i) {
                          final entry = _entries[i];
                          return _EntryListItem(
                            entry: entry,
                            isDark: isDark,
                            theme: theme,
                            onActionChanged: (a) =>
                                setState(() => entry.action = a),
                            onDelete: () =>
                                setState(() => _entries.removeAt(i)),
                          );
                        },
                      ),
              ),
            ],
          ),
          actions: [
            Button(
                child: const Text('取消'),
                onPressed: () => Navigator.of(context).pop()),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.existing == null ? '创建' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 条目行（Dialog 内）
// ---------------------------------------------------------------------------

class _EntryListItem extends StatelessWidget {
  final RuleEntry entry;
  final bool isDark;
  final FluentThemeData theme;
  final ValueChanged<RuleAction> onActionChanged;
  final VoidCallback onDelete;

  const _EntryListItem({
    required this.entry,
    required this.isDark,
    required this.theme,
    required this.onActionChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String typeLabel;
    Color typeBg;
    Color typeColor;
    switch (entry.matchType) {
      case MatchType.appName:
        typeLabel = '程序';
        typeBg = Colors.orange.withValues(alpha: 0.18);
        typeColor = Colors.orange;
        break;
      case MatchType.ip:
        typeLabel = 'IP';
        typeBg = Colors.blue.withValues(alpha: 0.15);
        typeColor = Colors.blue;
        break;
      case MatchType.domain:
        typeLabel = '域名';
        typeBg = Colors.purple.withValues(alpha: 0.18);
        typeColor = Colors.purple;
        break;
    }

    final isProxy = entry.action == RuleAction.proxy;
    final actionColor = isProxy ? Colors.blue : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 类型角标
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: typeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(typeLabel,
                style: TextStyle(
                    fontSize: 11,
                    color: typeColor,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          // 内容
          Expanded(
            child: Text(
              entry.value,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.black.withValues(alpha: 0.85)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // 代理/直连无边框下拉（右侧，删除按钮左侧）
          _NoBorderActionDropdown(
            value: entry.action,
            onChanged: onActionChanged,
            actionColor: actionColor,
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          // 删除
          IconButton(
            icon: Icon(FluentIcons.delete,
                size: 13,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.4)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 无边框代理/直连下拉
// ---------------------------------------------------------------------------

class _NoBorderActionDropdown extends StatelessWidget {
  final RuleAction value;
  final ValueChanged<RuleAction> onChanged;
  final Color actionColor;
  final bool isDark;

  const _NoBorderActionDropdown({
    required this.value,
    required this.onChanged,
    required this.actionColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isProxy = value == RuleAction.proxy;
    final label = isProxy ? '代理' : '直连';
    return GestureDetector(
      onTapDown: (details) => _showMenu(context, details.globalPosition),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: actionColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: actionColor),
          ),
          const SizedBox(width: 2),
          Icon(FluentIcons.chevron_down, size: 10, color: actionColor),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context, Offset position) async {
    final result = await material.showMenu<RuleAction>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: isDark ? const Color(0xFF2D2D30) : const Color(0xFFF5F5F5),
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      items: [
        material.PopupMenuItem(
          value: RuleAction.proxy,
          height: 36,
          child: Row(
            children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: Colors.blue, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('代理',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black)),
            ],
          ),
        ),
        material.PopupMenuItem(
          value: RuleAction.direct,
          height: 36,
          child: Row(
            children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('直连',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black)),
            ],
          ),
        ),
      ],
    );
    if (result != null) onChanged(result);
  }
}

// ---------------------------------------------------------------------------
// 添加条目 Dialog（独立 StatefulWidget，避免 StatefulBuilder 状态问题）
// ---------------------------------------------------------------------------

class _AddEntryDialog extends StatefulWidget {
  const _AddEntryDialog();

  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  MatchType _matchType = MatchType.appName;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _placeholder {
    switch (_matchType) {
      case MatchType.appName: return '如 chrome.exe';
      case MatchType.ip: return '如 8.8.8.8 或 192.168.1.0/24';
      case MatchType.domain: return '如 google.com';
    }
  }

  @override
  Widget build(BuildContext context) {
    return material.BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: ContentDialog(
        constraints: const BoxConstraints(maxWidth: 380),
        title: const Text('添加条目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('类型',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                RadioButton(
                  checked: _matchType == MatchType.appName,
                  onChanged: (_) =>
                      setState(() => _matchType = MatchType.appName),
                  content: const Text('程序名'),
                ),
                const SizedBox(width: 16),
                RadioButton(
                  checked: _matchType == MatchType.ip,
                  onChanged: (_) =>
                      setState(() => _matchType = MatchType.ip),
                  content: const Text('IP'),
                ),
                const SizedBox(width: 16),
                RadioButton(
                  checked: _matchType == MatchType.domain,
                  onChanged: (_) =>
                      setState(() => _matchType = MatchType.domain),
                  content: const Text('域名'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextBox(
              controller: _controller,
              autofocus: true,
              placeholder: _placeholder,
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            child: const Text('添加'),
            onPressed: () {
              final v = _controller.text.trim();
              if (v.isNotEmpty) {
                Navigator.of(context)
                    .pop(RuleEntry(matchType: _matchType, value: v));
              }
            },
          ),
        ],
      ),
    );
  }
}
