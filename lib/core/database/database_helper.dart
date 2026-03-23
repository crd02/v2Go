import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:v2go/models/v2ray_config_model.dart';

/// 数据库帮助类
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    print('[DatabaseHelper] 初始化数据库...');
    _database = await _initDatabase();
    print('[DatabaseHelper] 数据库初始化完成');
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    // 获取数据库路径
    String dbPath;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 桌面端：使用当前目录或用户文档目录
      final directory = Directory.current;
      dbPath = join(directory.path, 'v2ray_servers.db');
    } else {
      // 移动端：使用 getDatabasesPath
      dbPath = join(await getDatabasesPath(), 'v2ray_servers.db');
    }

    print('[DatabaseHelper] 数据库路径: $dbPath');

    return await openDatabase(
      dbPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    print('[DatabaseHelper] 创建数据库表...');
    await db.execute('''
      CREATE TABLE servers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        protocol TEXT NOT NULL,
        config_json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE routing_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        inherit_from TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE routing_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rule_id INTEGER NOT NULL,
        match_type TEXT NOT NULL,
        value TEXT NOT NULL,
        action TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (rule_id) REFERENCES routing_rules(id) ON DELETE CASCADE
      )
    ''');
    print('[DatabaseHelper] 数据库表创建完成');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('[DatabaseHelper] 升级数据库 $oldVersion -> $newVersion');
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE servers ADD COLUMN name TEXT DEFAULT ""');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS routing_rules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          inherit_from TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS routing_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rule_id INTEGER NOT NULL,
          match_type TEXT NOT NULL,
          value TEXT NOT NULL,
          action TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (rule_id) REFERENCES routing_rules(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  /// 插入服务器配置
  Future<int> insertServer({
    required String id,
    required String name,
    required String protocol,
    required V2RayConfig config,
  }) async {
    final db = await database;

    // 使用 toFullJson() 保存完整配置（包含 outbounds 数组）
    final configJson = jsonEncode(config.toFullJson());

    return await db.insert('servers', {
      'id': id,
      'name': name,
      'protocol': protocol,
      'config_json': configJson,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 查询所有服务器配置
  Future<List<Map<String, dynamic>>> getAllServers() async {
    print('[DatabaseHelper] 查询所有服务器...');
    final db = await database;
    final result = await db.query('servers', orderBy: 'created_at DESC');
    print('[DatabaseHelper] 查询完成，共 ${result.length} 条记录');
    return result;
  }

  /// 根据 ID 查询服务器配置
  Future<Map<String, dynamic>?> getServerById(String id) async {
    final db = await database;
    final results = await db.query('servers', where: 'id = ?', whereArgs: [id]);

    if (results.isEmpty) return null;
    return results.first;
  }

  /// 更新服务器配置
  Future<int> updateServer({
    required String id,
    required String name,
    required String protocol,
    required V2RayConfig config,
  }) async {
    final db = await database;

    // 使用 toFullJson() 保存完整配置（包含 outbounds 数组）
    final configJson = jsonEncode(config.toFullJson());

    return await db.update(
      'servers',
      {'name': name, 'protocol': protocol, 'config_json': configJson},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除服务器配置
  Future<int> deleteServer(String id) async {
    final db = await database;
    return await db.delete('servers', where: 'id = ?', whereArgs: [id]);
  }

  /// 批量删除服务器配置
  Future<int> deleteServers(List<String> ids) async {
    final db = await database;
    return await db.delete(
      'servers',
      where: 'id IN (${ids.map((_) => '?').join(',')})',
      whereArgs: ids,
    );
  }

  /// 清空所有服务器配置
  Future<int> clearAllServers() async {
    final db = await database;
    return await db.delete('servers');
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // ---------------------------------------------------------------------------
  // 路由规则 CRUD
  // ---------------------------------------------------------------------------

  /// 插入一条路由规则（含条目），返回规则 id
  Future<int> insertRoutingRule({
    required String name,
    required String inheritFrom,
    required int sortOrder,
    required List<Map<String, dynamic>> entries,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      final ruleId = await txn.insert('routing_rules', {
        'name': name,
        'inherit_from': inheritFrom,
        'sort_order': sortOrder,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      for (var i = 0; i < entries.length; i++) {
        await txn.insert('routing_entries', {
          'rule_id': ruleId,
          'match_type': entries[i]['match_type'] as String,
          'value': entries[i]['value'] as String,
          'action': entries[i]['action'] as String,
          'sort_order': i,
        });
      }
      return ruleId;
    });
  }

  /// 更新路由规则（先删条目再重建）
  Future<void> updateRoutingRule({
    required int id,
    required String name,
    required String inheritFrom,
    required int sortOrder,
    required List<Map<String, dynamic>> entries,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'routing_rules',
        {'name': name, 'inherit_from': inheritFrom, 'sort_order': sortOrder},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete('routing_entries',
          where: 'rule_id = ?', whereArgs: [id]);
      for (var i = 0; i < entries.length; i++) {
        await txn.insert('routing_entries', {
          'rule_id': id,
          'match_type': entries[i]['match_type'] as String,
          'value': entries[i]['value'] as String,
          'action': entries[i]['action'] as String,
          'sort_order': i,
        });
      }
    });
  }

  /// 删除路由规则（条目级联删除）
  Future<void> deleteRoutingRule(int id) async {
    final db = await database;
    await db.delete('routing_rules', where: 'id = ?', whereArgs: [id]);
  }

  /// 查询所有路由规则及其条目
  Future<List<Map<String, dynamic>>> getAllRoutingRules() async {
    final db = await database;
    final rules = await db.query('routing_rules', orderBy: 'sort_order ASC, created_at ASC');
    final result = <Map<String, dynamic>>[];
    for (final rule in rules) {
      final entries = await db.query(
        'routing_entries',
        where: 'rule_id = ?',
        whereArgs: [rule['id']],
        orderBy: 'sort_order ASC',
      );
      result.add({...rule, 'entries': entries});
    }
    return result;
  }
}
