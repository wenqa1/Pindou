# 拼豆 App 工程骨架

此目录承载 iOS/iPadOS 16+ 应用工程。当前已建立 XcodeGen 工程描述、构建配置、iPhone/iPad 通用 AppShell 和最小单元测试；生成的 Xcode 工程与签名配置不进入仓库。

## 目录原则

- `App` 只负责应用生命周期、依赖组装、根导航和资源入口。
- `Features` 按业务领域拆分，每个领域统一采用 `Domain / Application / Infrastructure / Presentation` 四层。
- `Platform` 放置 Core Data、文件、网络、签名校验、图像处理等 Apple 平台适配器。
- `Shared` 仅保存稳定的跨模块 UI、导航类型和无业务语义工具。
- `Packages` 保存可独立测试、可版本化的图纸格式与在线内容契约。
- `Extensions` 保存 Share Extension 等独立 target。
- `Tests` 按测试级别组织，`Fixtures` 保存可重复使用的本地样本。
- `ContentPipeline` 是在线图纸发布侧工具的预留目录，不进入 iOS App 运行时。
- `Configurations` 与 `Scripts` 分别保存构建配置和可复现开发脚本。

## 编译依赖

```text
Presentation ──> Application ──> Domain
Infrastructure ────────────────> Application / Domain 中定义的 Ports
AppShell ──────────────────────> 各模块公开组装入口
Platform ──────────────────────> 基础设施协议实现
```

领域层不得引用 SwiftUI、Core Data、URLSession、文件路径或 CDN 类型。页面不得直接写数据库、文件系统和网络。

详细树状图见 [项目目录与架构树](../docs/11-项目目录与架构树.md)。

## Windows 与 Codemagic

Windows 提交前运行：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\PindouApp\Scripts\validate-windows.ps1
```

仓库根目录 `codemagic.yaml` 在 Codemagic 云端生成 Xcode 工程、运行测试并输出 IPA。完整配置见 [Windows 开发与 Codemagic 构建工作流](../docs/12-Windows开发与macOS构建工作流.md)。
