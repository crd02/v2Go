# V2Ray 配置模块使用说明

## 功能概述

这是一个完整的 V2Ray 客户端配置表单系统，支持：

- VLESS / VMess 协议配置
- 服务器地址和端口配置
- 用户 ID、Flow、Encryption 配置
- Stream Settings（网络传输设置）
- WebSocket 详细配置
- JSON 配置预览和导出
- 服务器列表管理（新建、编辑、删除）

## 文件结构

```
lib/
├── v2_config.dart                              # 主配置页面
├── server_config_page.dart                     # 服务器列表管理页面
├── models/
│   └── v2ray_config_model.dart                # V2Ray 配置数据模型
└── widgets/
    ├── common/
    │   └── form_widgets.dart                  # 通用表单组件
    ├── config/
    │   ├── protocol_config_widget.dart        # 协议配置组件
    │   ├── server_config_widget.dart          # 服务器配置组件
    │   ├── user_config_widget.dart            # 用户配置组件
    │   └── stream_settings_config_widget.dart # 流设置配置组件
    └── network/
        ├── network_config_widget.dart         # 网络配置抽象基类
        └── ws_config_widget.dart              # WebSocket 配置组件
```

## 使用方法

### 1. 在服务器列表页面新建服务器

点击 `server_config_page.dart` 中的"新建"按钮，会弹出配置对话框：

```dart
// 代码已集成在 server_config_page.dart 中
// 点击新建按钮后会自动弹出配置表单
```

### 2. 编辑现有服务器

双击服务器行即可编辑配置：

```dart
// 双击任意服务器行会打开编辑对话框
// 原有配置会自动填充到表单中
```

### 3. 独立使用配置页面

如果需要在其他地方使用配置页面：

```dart
import 'package:your_app/v2_config.dart';

// 作为独立页面
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const V2RayConfigPage(),
  ),
);

// 作为对话框
final config = await showDialog<V2RayConfig>(
  context: context,
  builder: (context) => const V2RayConfigPage(isDialog: true),
);
```

## 配置表单说明

### 1. 协议配置
- **协议类型**: 下拉选择 VLESS 或 VMess

### 2. 服务器配置
- **服务器地址**: 域名或 IP 地址（例如: example.com）
- **服务器端口**: 数字端口（例如: 443）

### 3. 用户配置
- **用户 ID (UUID)**: 标准 UUID 格式
- **Flow**:
  - 支持自动完成输入
  - 可选值: `xtls-rprx-vision`, `xtls-rprx-vision-udp443`
  - 也可以手动输入其他值
- **Encryption**: 下拉选择
  - `none`
  - `auto`
  - `aes-128-gcm`
  - `chacha20-poly1305`

### 4. Stream Settings 配置

#### Network 类型
下拉选择网络传输协议：
- `tcp`
- `kcp`
- `ws` (WebSocket)
- `http`
- `domainsocket`
- `quic`
- `grpc`

#### Security
- `none`: 无加密
- `tls`: TLS 加密
- `reality`: Reality 协议

#### WebSocket 配置（当 Network = ws 时显示）

以下字段会在选择 WebSocket 时自动展开：

- **Path**: WebSocket 路径（默认: `/`）
- **Host (Header)**: 主机名 header（默认: `v2ray.com`）
- **Max Early Data**: 最大早期数据量（默认: `1024`）
- **Early Data Header Name**: 早期数据 header 名称（可选）
- **Accept Proxy Protocol**: 是否接受代理协议（复选框）
- **Use Browser Forwarding**: 是否使用浏览器转发（复选框）

## JSON 配置生成

点击 OK 按钮后：

### 对话框模式
- 直接返回 `V2RayConfig` 对象
- 调用代码可以获取配置并进一步处理

### 独立页面模式
- 显示 JSON 预览对话框
- 可以复制到剪贴板
- 可以保存为 `v2ray_config.json` 文件

### 生成的 JSON 格式示例

```json
{
  "protocol": "VLESS",
  "settings": {
    "vnext": [
      {
        "address": "example.com",
        "port": 443,
        "users": [
          {
            "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            "flow": "xtls-rprx-vision",
            "encryption": "none"
          }
        ]
      }
    ]
  },
  "streamSettings": {
    "network": "ws",
    "security": "tls",
    "wsSettings": {
      "acceptProxyProtocol": false,
      "path": "/",
      "headers": {
        "Host": "v2ray.com"
      },
      "maxEarlyData": 1024,
      "useBrowserForwarding": false
    }
  }
}
```

## 设计模式

### 1. 面向对象设计
- 清晰的数据模型层次结构
- `V2RayConfig` 包含 `ServerSettings`、`UserSettings`、`StreamSettings`
- 抽象基类 `NetworkConfig` 支持多态

### 2. Strategy 模式
- 根据 `network` 类型动态显示不同的配置表单
- 便于扩展新的网络类型

### 3. 组件化设计
- 每个配置模块都是独立的 Widget
- 通过回调函数实现数据双向绑定
- 易于维护和测试

## 扩展指南

### 添加新的网络类型（以 gRPC 为例）

1. **创建数据模型** (`lib/models/v2ray_config_model.dart`)
```dart
class GrpcConfig extends NetworkConfig {
  String serviceName;

  GrpcConfig({this.serviceName = ''});

  @override
  String get configKey => 'grpcSettings';

  @override
  Map<String, dynamic> toJson() {
    return {'serviceName': serviceName};
  }
}
```

2. **创建配置组件** (`lib/widgets/network/grpc_config_widget.dart`)
```dart
class GrpcConfigWidget extends NetworkConfigWidget {
  // 实现配置表单
}
```

3. **在 StreamSettings 中添加条件** (`lib/widgets/config/stream_settings_config_widget.dart`)
```dart
if (streamSettings.network == 'grpc')
  GrpcConfigWidget(
    config: streamSettings.networkConfig as GrpcConfig?,
    onChanged: (config) { ... },
  ),
```

## UI 设计规范

- **圆角输入框**: `BorderRadius.circular(8)`
- **背景颜色**: 浅灰色 `Color(0xFFE8E8E8).withOpacity(0.1)`
- **文本对齐**: 左对齐
- **聚焦边框**: 橙色高亮 `Colors.orange.shade600`
- **间距**: 模块之间 24px，字段之间 16px

## 注意事项

1. **数据验证**: 目前未实现完整的数据验证，建议在生产环境中添加
2. **UUID 生成**: 未提供 UUID 自动生成功能，需要用户手动输入
3. **服务器位置**: 新建服务器时位置默认为"未知"，可以后续添加 IP 定位功能
4. **延迟测试**: 新建服务器时延迟为 0，可以添加 ping 测试功能
5. **其他网络类型**: 目前只实现了 WebSocket 配置，其他网络类型的配置表单待扩展

## 常见问题

**Q: 如何保存配置到本地文件？**
A: 在独立页面模式下，点击 OK 后会弹出预览对话框，可以保存为 JSON 文件。在对话框模式下，配置会返回给调用代码，由调用代码决定如何处理。

**Q: 如何导入现有的 V2Ray 配置？**
A: 可以在 `V2RayConfigPage` 中传入 `initialConfig` 参数来加载现有配置。

**Q: 双击编辑时为什么提示"缺少配置信息"？**
A: 旧版本的服务器可能没有保存完整的 `V2RayConfig`，只有新建或重新编辑的服务器才有完整配置。

## 许可证

此代码为开源代码，可自由使用和修改。
