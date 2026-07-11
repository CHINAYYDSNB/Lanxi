# Changelog

## v0.0.11 (2026-07-11)

### ✨ 新功能

#### AI 助手 (#9)
- OpenAI 兼容接口 (可配 endpoint/key/model)
- 流式聊天 (SSE 打字机效果)
- 自动注入服务器状态到上下文
- 三种入口模式: 底部 Tab / 悬浮球 / 侧边栏 (设置切换)

#### 脚本商店 (#10)
- 索引+详情分离结构 (`index.json` + `details/*.json`)
- 搜索脚本 (名称/作者过滤)
- 脚本预览 (加载原始内容)
- 下载到 1Panel 服务器 + 确认执行
- `POST /api/script/exec` 代理端点

### 🔧 增强

#### 网站管理
- **Nginx 在线编辑器**: 加载配置 → 修改 → 保存 (`updateNginx`)
- **SSL 操作按钮**: 申请 Let's Encrypt, 启用/禁用 HTTPS
- **mounted 守卫**: 修复 async gap 潜在崩溃

#### 应用商店
- **一键安装**: 版本选择 + Docker Compose YAML 编辑器
- **默认 Compose 模板**: API 取不到时自动生成
- **已安装应用**: 编辑 Compose + 检查更新 + 升级

#### 文件管理
- 防随机 back 箭头 (`automaticallyImplyLeading: false`)
- home 按钮 (pop 回上一页)

### 🐛 Bug 修复
- 入口模式切换白屏 → `_stablePages` 固定列表 + index 映射
- Tab 切换闪退 → `_Guard` 实例非 `static const`
- Back 箭头乱入 → 去 `Scaffold` 改用自定义顶栏
- 未配服务器时报错 → `_Guard` 阻止请求 + 添加按钮
- CORS → server.mjs 代理 `/api/v2/*`
- `website.dart` `toJson()` 11→40 字段补全
- 清理: `lib/lib/` 重复文件, `lib/pages"` 截断文件, `web/web/` 重复目录

### 📦 依赖
- 新增: `ws`, `ssh2` (npm, server.mjs 代理)
- 版本: `0.3.1+1`

### 📝 文档
- README 更新功能进度
- 新增 `CHANGELOG.md`

---

## v0.0.10 (2026-07-04)
仓库迁移 Tianxuan_panel → Tianxuan, SSH terminal, cloud backup

## v0.3.1+1 (2026-06-28)
Logto 登录修复, SVG logo, adaptive icon

## v0.3.0 (2026-06-23)
WAF 管理模块, BottomNav 6 Tab

## v0.2.2 (2026-06-22)
Docker 模块, 健康检测, Logto 部分实现

## v0.2.1 (2026-06-21)
文件管理器, 服务器切换, API Key 加密存储

## v0.1.0 (2026-06-21)
初版: 服务器状态, 网站管理, 基础框架
