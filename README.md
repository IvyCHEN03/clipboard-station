# AI Clipboard Station

一个本地运行的 macOS 菜单栏剪贴板中转站，用来在并行多个 AI 工具时快速收集、搜索、复制和自动粘贴文本片段。

## 功能

- 菜单栏浮窗中转站
- `Cmd+Shift+C` 拉取当前选中文本
- 屏幕边缘浅蓝小泡泡打开/关闭中转站浮窗
- 监听普通文本复制并自动收集
- 搜索、删除、清空、编辑片段标题
- 可选 AI 生成标题和标签，支持 OpenAI-compatible Chat Completions 接口
- 拖拽整张片段卡片调整排序
- 每条片段左侧可用上下键或数字序号快速排序
- 底部组合框：把片段拖成彩色数字积木块，按顺序复制组合后的全文
- 点击粘贴图标后写入剪贴板并模拟 `Cmd+V`
- 本地 Keychain 密钥 + AES-GCM 加密持久化
- 默认不接入云端；只有开启 AI 生成并配置 API Key 后，才会把新片段发给你填写的模型接口

## 运行

开发运行：

```bash
swift run
```

打包为 `.app`：

```bash
./Scripts/package-app.sh
open .build/ClipboardStation.app
```

首次使用“拉取选中文本”和“自动粘贴”时，macOS 会要求开启辅助功能权限。打开/关闭浮窗可以使用屏幕边缘的浅蓝小泡泡或菜单栏图标，不依赖全局双击键。

## AI 标题和标签

设置里打开“AI 生成标题和标签”，填写：

- `AI Base URL`：OpenAI-compatible `/chat/completions` 地址
- `模型名`：默认 `gpt-4o-mini`，也可换成你的兼容模型名
- `API Key`

API Key 保存在 macOS Keychain。AI 生成默认关闭。

## 默认设置

- 监听普通复制：开启
- 点击粘贴图标后自动粘贴：开启
- 屏幕边缘浅蓝小泡泡：开启
- AI 生成标题和标签：关闭
- 本地加密持久化：开启
- 全局快捷键：`Cmd+Shift+C`
- 开机启动：关闭

## 数据位置

片段数据保存在：

```text
~/Library/Application Support/ClipboardStation/state.enc
```

加密密钥保存在 macOS Keychain 中，service 为 `com.local.clipboard-station`。
