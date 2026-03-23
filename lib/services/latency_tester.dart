import 'dart:io';
import 'dart:typed_data';

class LatencyTester {
  /// 测试单个服务器的延迟
  /// [address] 服务器地址
  /// [port] 服务器端口
  /// [timeout] 超时时间，默认5秒
  /// 返回延迟毫秒数，失败返回 -1
  static Future<int> testLatency(
    String address,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (address.isEmpty) return -1;

    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(
        address,
        port,
        timeout: timeout,
      );
      stopwatch.stop();
      await socket.close();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return -1; // 连接失败
    }
  }

  /// 获取延迟对应的信号强度
  /// 返回 0-3，0 表示未测试/超时，3 表示最佳
  static int getSignalStrength(int latency) {
    if (latency < 0) return 0; // 未测试/失败
    if (latency < 100) return 3; // 优秀
    if (latency < 300) return 2; // 良好
    return 1; // 一般
  }

  /// 获取延迟对应的颜色（返回颜色索引）
  /// 0: grey (未测试), 1: green (优秀), 2: orange (良好), 3: red (较差)
  static int getLatencyColorIndex(int latency) {
    if (latency < 0) return 0; // grey - 未测试
    if (latency < 100) return 1; // green - 优秀
    if (latency < 300) return 2; // orange - 良好
    return 3; // red - 较差
  }

  /// 格式化延迟显示文本
  static String formatLatency(int latency) {
    if (latency < 0) return '测试中...';
    if (latency >= 9999) return '超时';
    return '$latency ms';
  }

  static Future<double> testDownloadSpeed(
    String proxyAddress,
    int proxyPort, {
    Duration testDuration = const Duration(seconds: 10),
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final client = HttpClient();
      client.findProxy = (uri) {
        return 'PROXY $proxyAddress:$proxyPort';
      };
      client.badCertificateCallback = (cert, host, port) => true;

      // 请求 25MB 的数据
      final request = await client
          .getUrl(Uri.parse('https://speed.cloudflare.com/__down?bytes=26214400'))
          .timeout(timeout);

      request.headers.set('Accept-Encoding', 'identity');

      final response = await request.close().timeout(timeout);

      if (response.statusCode != 200) {
        print('[SpeedTest] 下载测试失败: HTTP ${response.statusCode}');
        client.close();
        return -1;
      }

      final stopwatch = Stopwatch()..start();
      int totalBytes = 0;

      await for (var chunk in response.timeout(testDuration)) {
        totalBytes += chunk.length;
        if (stopwatch.elapsed >= testDuration) {
          break;
        }
      }

      stopwatch.stop();
      client.close();

      if (totalBytes == 0 || stopwatch.elapsedMilliseconds == 0) {
        print('[SpeedTest] 下载测试失败: 无数据');
        return -1;
      }

      // 计算每秒速度: 总字节数 / 秒数 / 1024 / 1024 = MB/s
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      final bytesPerSecond = totalBytes / seconds;
      final speedMBps = bytesPerSecond / 1024 / 1024;

      print('[SpeedTest] 下载: 总共 ${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB');
      print('[SpeedTest] 下载: 耗时 ${seconds.toStringAsFixed(2)} 秒');
      print('[SpeedTest] 下载: 每秒 ${speedMBps.toStringAsFixed(2)} MB/s');
      return speedMBps;
    } catch (e) {
      print('[SpeedTest] 下载测试异常: $e');
      return -1;
    }
  }

  static Future<double> testUploadSpeed(
    String proxyAddress,
    int proxyPort, {
    Duration testDuration = const Duration(seconds: 10),
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final client = HttpClient();
      client.findProxy = (uri) {
        return 'PROXY $proxyAddress:$proxyPort';
      };
      client.badCertificateCallback = (cert, host, port) => true;

      // 准备上传数据 (1MB)
      final uploadSize = 1024 * 1024;
      final uploadData = Uint8List(uploadSize);

      final stopwatch = Stopwatch()..start();

      // 发送多次请求来测试上传速度
      int totalBytes = 0;
      int successfulRequests = 0;

      while (stopwatch.elapsed < testDuration) {
        try {
          final request = await client
              .postUrl(Uri.parse('https://speed.cloudflare.com/__up'))
              .timeout(const Duration(seconds: 10));

          request.headers.set('Content-Type', 'application/octet-stream');
          request.contentLength = uploadSize;
          request.add(uploadData);

          final response = await request.close().timeout(const Duration(seconds: 10));

          // 消费响应体
          await response.drain();

          if (response.statusCode == 200) {
            totalBytes += uploadSize;
            successfulRequests++;
          }
        } catch (e) {
          // 单次请求失败，继续尝试
          print('[SpeedTest] 单次上传请求失败: $e');
        }
      }

      stopwatch.stop();
      client.close();

      if (totalBytes == 0 || stopwatch.elapsedMilliseconds == 0) {
        print('[SpeedTest] 上传测试失败: 无成功请求');
        return -1;
      }

      // 计算每秒速度: 总字节数 / 秒数 / 1024 / 1024 = MB/s
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      final bytesPerSecond = totalBytes / seconds;
      final speedMBps = bytesPerSecond / 1024 / 1024;

      print('[SpeedTest] 上传: 成功 $successfulRequests 次请求');
      print('[SpeedTest] 上传: 总共 ${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB');
      print('[SpeedTest] 上传: 耗时 ${seconds.toStringAsFixed(2)} 秒');
      print('[SpeedTest] 上传: 每秒 ${speedMBps.toStringAsFixed(2)} MB/s');
      return speedMBps;
    } catch (e) {
      print('[SpeedTest] 上传测试异常: $e');
      return -1;
    }
  }
}
