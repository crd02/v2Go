import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 进程信息
class ManagedProcess {
  final Process process;
  final String name;
  final DateTime startTime;

  ManagedProcess({
    required this.process,
    required this.name,
    required this.startTime,
  });

  int get pid => process.pid;
}

class ProcessManager {
  static final ProcessManager _instance = ProcessManager._internal();

  factory ProcessManager() {
    return _instance;
  }

  ProcessManager._internal();

  final Map<String, ManagedProcess> _processes = {};

  /// 启动进程
  ///
  /// [name] 进程标识名称（唯一）
  /// [executable] 可执行文件路径
  /// [arguments] 命令行参数
  /// [onStdout] 标准输出回调
  /// [onStderr] 标准错误输出回调
  /// [onExit] 进程退出回调
  Future<bool> startProcess({
    required String name,
    required String executable,
    required List<String> arguments,
    Function(String data)? onStdout,
    Function(String data)? onStderr,
    Function(int exitCode)? onExit,
  }) async {
    if (_processes.containsKey(name)) {
      return false;
    }

    try {
      if (!await File(executable).exists()) {
        print('可执行文件不存在: $executable');
        return false;
      }

      final process = await Process.start(executable, arguments);
      final managedProcess = ManagedProcess(
        process: process,
        name: name,
        startTime: DateTime.now(),
      );

      _processes[name] = managedProcess;
      process.stdout.transform(utf8.decoder).listen(
        (data) {
          if (onStdout != null) {
            onStdout(data);
          }
        },
        onError: (error) {
          print('[$name] stdout error: $error');
        },
      );

      process.stderr.transform(utf8.decoder).listen(
        (data) {
          if (onStderr != null) {
            onStderr(data);
          }
        },
        onError: (error) {
          print('[$name] stderr error: $error');
        },
      );

      process.exitCode.then((exitCode) {
        _processes.remove(name);
        if (onExit != null) {
          Future(() {
            onExit(exitCode);
          });
        }
      });
      return true;
    } catch (e) {
      _processes.remove(name);
      return false;
    }
  }

  /// 停止进程
  ///
  /// [name] 进程标识名称
  /// [gracefulTimeout] 优雅关闭的超时时间
  /// [forceTimeout] 强制终止后等待的超时时间
  Future<void> stopProcess(
    String name, {
    Duration gracefulTimeout = const Duration(seconds: 3),
    Duration forceTimeout = const Duration(seconds: 2),
  }) async {
    final managedProcess = _processes[name];
    if (managedProcess == null) {
      return;
    }

    final process = managedProcess.process;
    final pid = process.pid;
    try {
      if (Platform.isWindows) {
        try {
          Process.killPid(pid, ProcessSignal.sigterm);
        } catch (e) {
          print('[$name] 发送 SIGTERM 失败: $e');
        }

        final exitedGracefully = await _waitForProcessExit(process, gracefulTimeout);

        if (!exitedGracefully) {
          print('[$name] 进程未在规定时间内退出，尝试强制终止...');
          try {
            Process.killPid(pid, ProcessSignal.sigkill);
            print('[$name] 发送 SIGKILL 信号');
          } catch (e) {
            print('[$name] 发送 SIGKILL 失败: $e');
          }
          await _waitForProcessExit(process, forceTimeout);
        }
      } else {
        try {
          Process.killPid(pid, ProcessSignal.sigkill);
        } catch (e) {
          print('[$name] 发送 SIGTERM 失败: $e');
        }
      }
    } catch (e) {
      print('停止进程 $name 时出错: $e');
    } finally {
      _processes.remove(name);
    }
  }

  Future<bool> _waitForProcessExit(Process process, Duration timeout) async {
    try {
      await process.exitCode.timeout(timeout);
      return true;
    } catch (e) {
      return false;
    }
  }

  bool isProcessRunning(String name) {
    return _processes.containsKey(name);
  }

  ManagedProcess? getProcess(String name) {
    return _processes[name];
  }

  List<String> getRunningProcessNames() {
    return _processes.keys.toList();
  }

  Future<void> stopAllProcesses() async {
    final processNames = _processes.keys.toList();
    print('停止所有进程，共 ${processNames.length} 个');

    for (final name in processNames) {
      await stopProcess(name);
    }

    print('所有进程已停止');
  }

  int get runningProcessCount => _processes.length;
}
