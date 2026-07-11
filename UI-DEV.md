# 天璇 (Tianxuan) UI 开发指南

> 给 UI 同学 — 项目结构、组件库、路由、设计规范
> 版本: 0.2.0 | 2026-06-22

---

## 目录

1. [项目概述](#1-项目概述)
2. [技术栈](#2-技术栈)
3. [目录结构](#3-目录结构)
4. [路由与页面](#4-路由与页面)
5. [页面详解](#5-页面详解)
6. [组件库](#6-组件库)
7. [状态管理](#7-状态管理)
8. [设计规范](#8-设计规范)
9. [开发环境](#9-开发环境)
10. [设计稿对照](#10-设计稿对照)

---

## 1. 项目概述

天璇是 1Panel Linux 面板的第三方移动管理器。通过 API 远程管理 1Panel 服务器。

**目标用户**: 1Panel 用户，移动端管理服务器
**平台**: Android (APK) + Web (开发测试)
**当前阶段**: v0.2.0，基础功能已完成，UI 待美化

---

## 2. 技术栈

| 技术 | 用途 | 版本 |
|------|------|------|
| Flutter | 跨平台框架 | 3.44.1 |
| Dart | 编程语言 | 3.12 |
| Riverpod | 状态管理 | 2.6.1 |
| Dio | HTTP 网络库 | 5.4.0 |
| Material 3 | UI 组件库 | 内置 |

**状态管理**: Riverpod (替代 Provider/Bloc)
- `AsyncNotifierProvider` — 异步数据 (列表/详情)
- `FutureProvider.family` — 带参数的异步数据
- `StateNotifierProvider` — 同步状态 (设置/连接)

---

## 3. 目录结构

```
lib/
├── main.dart                  # 入口 + InitPage (启动检查)
├── api/                       # 网络层 (Dio + API 调用)
│   ├── client.dart            # Dio 单例, Auth 拦截器, 配置持久化
│   ├── dashboard_api.dart     # 仪表盘 API
│   ├── website_api.dart       # 网站管理 API
│   └── file_api.dart          # 文件管理 API
├── models/                    # 数据模型
│   ├── server_status.dart     # 服务器状态模型
│   ├── website.dart           # 网站 + 域名 + SSL + 备份记录模型
│   └── file_item.dart         # 文件条目模型
├── providers/                 # Riverpod 状态
│   ├── settings_provider.dart # 连接配置 + 自动重连
│   ├── dashboard_provider.dart# 服务器状态 + 运行时间 tick
│   ├── website_provider.dart  # 网站列表/详情/备份
│   ├── file_provider.dart     # 文件管理器状态
│   └── server_list_provider.dart # 多服务器列表
├── pages/                     # UI 页面
│   ├── home_page.dart         # 底部导航 (概览/文件/网站)
│   ├── login_page.dart        # 登录页
│   ├── dashboard/             # 概览页
│   │   └── dashboard_page.dart
│   ├── website/               # 网站管理
│   │   ├── website_list_page.dart
│   │   ├── website_create_page.dart
│   │   └── website_detail_page.dart
│   └── file/                  # 文件管理
│       ├── file_list_page.dart
│       └── file_editor_page.dart
├── widgets/                   # 可复用组件
│   └── ring_chart.dart        # 环状图 (CPU/内存/磁盘)
└── services/                  # 服务层
    └── storage_service.dart   # 本地存储 (加密/明文)
```

---

## 4. 路由与页面

### 4.1 路由表

| 路由 | 页面 | 说明 |
|------|------|------|
| `/init` | `InitPage` | 启动页，检查配置，自动跳转 |
| `/login` | `LoginPage` | 输入服务器地址 + API Key |
| `/home` | `HomePage` | 主页面 (底部导航) |

### 4.2 底部导航 (HomePage)

3 个 Tab:

| Tab | 页面 | 图标 |
|-----|------|------|
| 概览 | `DashboardPage` | `Icons.dashboard` |
| 文件 | `FileListPage` | `Icons.folder` |
| 网站 | `WebsiteListPage` | `Icons.language` |

### 4.3 导航栈

```
HomePage (BottomNav)
├── DashboardPage           # 默认首页
│   └── → 服务器切换弹窗
├── FileListPage
│   └── → FileEditorPage   # 点击文件
└── WebsiteListPage
    ├── → WebsiteCreatePage  # FAB "+"
    └── → WebsiteDetailPage  # 点击列表项
         └── TabBar (概览 | SSL | 日志 | 备份)
```

---

## 5. 页面详解

### 5.1 InitPage (`main.dart`)

**启动页** — 短暂显示后自动跳转。

```dart
// 逻辑: 检查本地是否有已保存的配置
// 有 → /home
// 无 → /login
// 5秒超时 → /login (安全兜底)
```

**UI**: `Scaffold(body: Center(child: CircularProgressIndicator()))`

**给 UI 同学**: 可以做 Splash 动画 / Logo 展示。

---

### 5.2 LoginPage (`pages/login_page.dart`)

**登录页** — 输入服务器信息。

**现有 UI 元素**:
- 服务器地址输入框 (IP + 端口)
- HTTPS 开关 (影响 URL 协议)
- API Key 输入框 (密码模式)
- 连接测试按钮
- 登录按钮

**建议改进**:
- 应用 Logo / 品牌展示
- 输入框样式美化
- 加载状态动画
- 错误提示样式
- 历史服务器快速选择

---

### 5.3 DashboardPage (`pages/dashboard/`)

**概览页** — 服务器状态总览。

**现有 UI 元素**:
- 服务器信息卡片 (hostname/OS/CPU/内核/IP)
  - 点击弹出服务器切换列表
- 环状图卡片 × 3 (CPU / 内存 / 磁盘)
  - 使用 `RingChart` 组件 (`widgets/ring_chart.dart`)
- 运行时间显示 (每秒 tick)
- 下拉刷新
- 最后更新时间 + 刷新错误反馈 (snackbar)

**现有配色**:
```
CPU:     Color(0xFF4CAF50)  // 绿色
内存:    Color(0xFF2196F3)  // 蓝色
磁盘:    Color(0xFFFF9800)  // 橙色
```

**建议改进**:
- 环状图样式 (渐变、动画、厚度)
- 信息卡片布局 (网格 vs 列表)
- 监控趋势图 (小 Sparkline)
- 服务器卡片展开更多信息
- 深色模式适配

---

### 5.4 WebsiteListPage (`pages/website/`)

**网站列表页** — 显示所有网站。

**现有 UI 元素**:
- ListTile 列表
  - 头像 CircleAvatar + 域名
  - 状态标签 (运行中/已停止/异常)
  - 类型标签 (反向代理/静态网站/...)
  - 网站路径
- 滑动删除 (Dismissible → 红色背景)
- PopupMenu 操作 (启动/停止/重启)
- 下拉刷新
- FAB "+" → 创建网站
- 空状态提示

**建议改进**:
- 卡片式布局 (比平铺列表更现代)
- 状态指示灯更明显 (绿/红/灰圆点)
- 搜索/筛选栏
- 长按进入编辑模式
- 空状态插画

---

### 5.5 WebsiteCreatePage (`pages/website/`)

**创建网站页** — 三步表单。

**Step 1 — 基本信息**:
- 网站类型选择: ChoiceChip (静态/反向代理/重定向/部署)
  - 带图标: description/swap_horiz/redo/rocket_launch
- 域名输入框
- 别名输入框 (自动跟随域名)
- 备注输入框
- 端口输入框

**Step 2 — 网站配置**:
- 类型相关字段 (动态显示):
  - 反向代理: 代理地址
  - 重定向: 目标 URL
  - 部署: 部署方式下拉
- 资源选项 (CheckboxListTile):
  - ☐ 创建数据库 (展开: 类型/库名/用户名/密码)
  - ☐ 创建 FTP (展开: 用户名/密码/路径)

**Step 3 — 确认页**:
- 信息汇总
- 错误提示

**建议改进**:
- Stepper 改用 PageView + 底部进度条 (更美观)
- 类型选择用更大的卡片/按钮
- 字段分组 + 标题
- 确认页用卡片/列表展示

---

### 5.6 WebsiteDetailPage (`pages/website/`)

**网站详情页** — TabBar 页面。

**顶部卡片**:
- 域名 (大标题) + 状态标签
- 类型 / 别名 / 路径 / 创建时间
- 操作按钮行:
  - 启动/停止 (根据状态切换)
  - 重启
  - 📁 网站目录 (跳转文件管理器)
  - ⚙ 配置文件 (下载 → 外部编辑)
  - ❌ 删除

**Tab 1 — 概览 (基本信息)**:

卡片分区:
- **基本配置**: 状态 / 类型 / 域名 / 别名 / 备注 / 代理地址 / 路径 / 端口
- **高级配置**: 运行用户 / 网站目录 / basedir / IPv6 / 默认站点
- **绑定域名**: 域名列表 (端口 + SSL 标记)
- **日志路径**: 访问日志 / 错误日志 路径

**Tab 2 — SSL**:

- HTTPS 启用状态 (lock/lock_open 图标)
- 证书信息卡片: 域名 / 颁发者 / 状态 / 过期时间 / 自动续签

**Tab 3 — 日志**:
- SegmentedButton: 访问日志 | 错误日志
- 日志内容 (monospace, 可选文本)
- 刷新按钮

**Tab 4 — 备份**:
- 备份列表 (fileName / size / createAt)
- 操作: 下载 / 删除
- FAB "+" → 创建备份
- 空状态: 暂无备份记录

**建议改进**:
- 顶部卡片布局美化 (圆角阴影)
- Tab 样式定制
- 概览信息用更清晰的分组/图标
- SSL 状态可视化 (过期倒计时)
- 日志行号 / 高亮 / 分页
- 备份列表改卡片
- 操作按钮改图标+文字 (大按钮)

---

### 5.7 FileListPage (`pages/file/`)

**文件浏览器** — 目录导航 + 文件操作。

**UI 元素**:
- 面包屑导航 (路径)
- 文件列表 (图标 + 名称 + 大小/修改时间)
- 类型图标:
  - 📄 文本: `.txt .md .json .yaml .xml .log`
  - 🖼 图片: `.png .jpg .jpeg .gif .svg .webp`
  - 📦 压缩: `.zip .tar .gz .bz2 .rar .7z`
  - ▶ 视频: `.mp4 .avi .mkv .mov .flv`
  - 🎵 音频: `.mp3 .wav .flac .aac .ogg`
  - 📂 文件夹: Icons.folder
  - 📄 其他: Icons.insert_drive_file
- 多选模式 (checkbox)
- 底部操作栏 (多选时): 删除/移动/压缩/下载
- 右上角菜单: 创建文件夹/上传文件/刷新
- 下拉刷新
- 空文件夹提示

**建议改进**:
- 列表/网格视图切换
- 缩略图预览 (图片)
- 文件信息弹窗 (权限/所有者)
- 拖动排序
- 搜索栏

### 5.8 FileEditorPage (`pages/file/`)

**文本编辑器** — 查看/编辑文本文件。

**UI 元素**:
- 文件名 AppBar
- 文件内容 TextField (多行 monospace)
- 保存按钮

**建议改进**:
- 代码高亮
- 行号
- 撤销/重做
- 查找/替换
- 字体大小调节

---

## 6. 组件库

### 6.1 已有组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `RingChart` | `widgets/ring_chart.dart` | CustomPainter 环状进度图 |
| `_StatusBadge` | `website_detail_page.dart` | 状态标签 (运行中/已停止/异常) |
| `_ActionChip` | `website_detail_page.dart` | 操作按钮 (图标+文字) |

### 6.2 建议提取的通用组件

以下组件当前在各页面内联实现，建议提取到 `widgets/`:

- **LoadingWidget** — 居中加载指示器 + 消息
- **ErrorWidget** — 错误提示 + 重试按钮
- **EmptyStateWidget** — 空状态插画 + 文案 + 操作按钮
- **InfoCard** — 信息展示卡片 (标题 + 键值对)
- **InfoRow** — 标签 + 值的行
- **ConfirmDialog** — 确认弹窗 (标题 + 内容 + 取消/确认)
- **SectionHeader** — 分区标题 (带更多按钮)

---

## 7. 状态管理

### 7.1 Provider 概览

| Provider | 类型 | 数据 |
|----------|------|------|
| `settingsProvider` | StateNotifier | 连接状态/服务器 URL/错误 |
| `dashboardProvider` | StreamProvider? | 服务器状态 (自动刷新) |
| `tickingUptimeProvider` | Provider | 实时运行时间 |
| `websitesProvider` | AsyncNotifier | 网站列表 (30s 自动刷新) |
| `websiteDetailProvider(id)` | FutureProvider.family | 网站详情 |
| `websiteConfigProvider(id)` | FutureProvider.family | Nginx 配置 |
| `websiteHttpsProvider(id)` | FutureProvider.family | HTTPS 配置 |
| `websiteLogProvider({id, logType})` | FutureProvider.family | 网站日志 |
| `backupRecordsProvider` | AsyncNotifier | 备份记录列表 |
| `fileTreeProvider(path)` | FutureProvider.family | 文件列表 |
| `serverListProvider` | StateNotifier | 多服务器列表 |

### 7.2 使用方式

```dart
// 读取数据
final websites = ref.watch(websitesProvider);
websites.when(
  data: (list) => ...,
  loading: () => CircularProgressIndicator(),
  error: (e, st) => ErrorWidget(e),
);

// 操作数据
ref.read(websitesProvider.notifier).deleteWebsite(id);

// 带参数
final detail = ref.watch(websiteDetailProvider(websiteId));
```

### 7.3 刷新模式

| 数据 | 刷新方式 | 间隔 |
|------|---------|------|
| 网站列表 | 自动 + 下拉 | 30s |
| 服务器状态 | 自动 + 下拉 | 10s |
| 文件列表 | 操作后自动刷新 | - |
| 备份列表 | 操作后自动刷新 | - |

---

## 8. 设计规范

### 8.1 当前主题

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  useMaterial3: true,
)
```

基于 Material 3，蓝色种子色。所有组件使用 Material 3 风格。

### 8.2 配色方案 (建议)

**主色调**:
- Primary: `#1565C0` (深蓝) — 品牌色
- Secondary: `#42A5F5` (浅蓝) — 辅助色
- Background: `#F5F5F5` (浅灰) — 背景
- Surface: `#FFFFFF` (白色) — 卡片

**语义色**:
- 成功/运行中: `#4CAF50` (绿色)
- 警告/停止: `#FF9800` (橙色)
- 错误/异常: `#F44336` (红色)
- 信息: `#2196F3` (蓝色)

**图表色** (环状图):
- CPU: `#4CAF50` → `#81C784` 渐变色
- 内存: `#2196F3` → `#64B5F6` 渐变色
- 磁盘: `#FF9800` → `#FFCC80` 渐变色

### 8.3 字体

- 正文: Material 默认 (Roboto/Noto Sans SC)
- 代码/日志: `monospace` (monospace)
- 标题: Material 3 标题样式

### 8.4 间距

| 层级 | 值 | 用途 |
|------|-----|------|
| xs | 4px | 图标与文字间距 |
| sm | 8px | 列表项内部间距 |
| md | 12px | 卡片内边距 |
| lg | 16px | 卡片间距、表单间距 |
| xl | 24px | 分区间距、大间距 |

---

## 9. 开发环境

### 9.1 启动 Web

```bash
cd "C:\Users\岚汐\Desktop\Tianxuan"
flutter run -d chrome
```

### 9.2 使用代理服务器 (避免 CORS)

```bash
# 1. 先构建 Web
flutter build web

# 2. 启动同源代理
node server.mjs

# 3. 浏览器访问
http://localhost:25568
```

修改 `.env` 配置:

```
API_HOST=你的服务器IP
API_PORT=25567
PORT=25568
```

### 9.3 构建 APK

```bash
# 确保 Java 21
export JAVA_HOME="/c/Program Files/Zulu/zulu-21"

flutter build apk --release
```

### 9.4 代码检查

```bash
dart analyze lib/
```

---

## 10. 设计稿对照

### 10.1 需要 UI 设计的页面 (按优先级)

| 优先级 | 页面 | 定位 |
|--------|------|------|
| P0 | 登录页 | 品牌首印象，需要专业设计 |
| P0 | 仪表盘 | 首页，数据显示核心 |
| P1 | 网站详情 | 功能最丰富的页面 |
| P1 | 网站列表 | 常用页面 |
| P2 | 文件管理器 | 操作密集型页面 |
| P2 | 创建网站表单 | 长度表单优化 |
| P3 | 文本编辑器 | 工具型页面 |
| P3 | 深色模式 | 全应用 |

### 10.2 当前缺失的 UI 元素

- 应用 Logo / 品牌图标
- 启动页 Splash 动画
- 空状态插画
- 加载骨架屏 (shimmer)
- 页面过渡动画
- Toast/Snackbar 样式

### 10.3 设计参考

- **品牌色**: `#1565C0` (深蓝)
- **名称**: 天璇 (Tianxuan) — 北斗七星之一
- **受众**: 服务器管理员，技术用户
- **风格**: 简洁、专业、信息密集

---

## 附录

### 文件清单 (UI 相关)

| 文件 | 行数 | 说明 |
|------|------|------|
| `lib/main.dart` | ~60 | 入口 + InitPage |
| `lib/pages/login_page.dart` | ~120 | 登录页 |
| `lib/pages/home_page.dart` | ~40 | 底部导航 |
| `lib/pages/dashboard/dashboard_page.dart` | ~200 | 仪表盘 |
| `lib/pages/website/website_list_page.dart` | ~180 | 网站列表 |
| `lib/pages/website/website_create_page.dart` | ~450 | 创建网站表单 |
| `lib/pages/website/website_detail_page.dart` | ~630 | 网站详情+4 Tab |
| `lib/pages/file/file_list_page.dart` | ~340 | 文件浏览器 |
| `lib/pages/file/file_editor_page.dart` | ~100 | 文本编辑器 |
| `lib/widgets/ring_chart.dart` | ~80 | 环状图组件 |
