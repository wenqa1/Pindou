# Windows 开发与 Codemagic 构建工作流

文档版本：0.2  
适用平台：Windows 主开发机 + Codemagic 云端 macOS 构建机  
目标平台：iOS/iPadOS 16+

## 1. 固定开发方式

本项目采用纯 Windows 日常开发，Codemagic 是唯一 Apple 构建节点：

```text
Windows
├─ VS Code / Git
├─ Swift、YAML、JSON、资源与文档
├─ PowerShell 静态门禁
└─ Push 到 GitHub
          │
          ▼
Codemagic
├─ 读取仓库根目录 codemagic.yaml
├─ XcodeGen 生成 PindouApp.xcodeproj
├─ Xcode 编译与 Simulator XCTest
├─ Apple 签名与 Archive
├─ 生成 Ad Hoc / App Store IPA
└─ 可选上传 TestFlight
          │
          ▼
iPhone / iPad
└─ Ad Hoc 安装或 TestFlight 安装、真机验收
```

`PindouApp/project.yml` 是 Xcode 工程真值，生成的 `.xcodeproj` 不提交。Codemagic 在每次构建时重新生成工程，Windows 端不编辑 PBX 工程文件。

## 2. 仓库内三条工作流

根目录 [codemagic.yaml](../codemagic.yaml) 定义：

| Workflow ID | 触发 | 签名 | 产物/目的 |
|---|---|---|---|
| `ios-validation` | push、pull request | 无 | XcodeGen、模拟器编译、XCTest |
| `ios-ipa-adhoc` | Codemagic 手动运行 | Ad Hoc | 可安装到已登记 UDID 的 IPA |
| `ios-testflight` | Codemagic 手动运行 | App Store | IPA artifact，并上传 App Store Connect |

App Store 签名 IPA 通过 TestFlight 安装；Ad Hoc IPA 只安装到描述文件中已登记的设备。

## 3. Codemagic 首次配置

1. 登录 [Codemagic](https://codemagic.io/start/)，连接 GitHub 账号并添加 `wenqa1/Pindou`。
2. 选择仓库根目录的 `codemagic.yaml` 配置。
3. 在 Apple Developer Portal 注册最终 App ID。
4. 在 App Store Connect 创建对应 App 记录。
5. 创建 App Store Connect API Key，并在 Codemagic Team integrations 中保存，集成名称固定为 `codemagic`，与 YAML 一致。
6. 在 Codemagic 的 iOS code signing identities 中生成或上传 Apple Distribution 证书及 provisioning profile。
7. Ad Hoc 构建前先登记需要安装的 iPhone/iPad UDID，并生成覆盖这些设备的 Ad Hoc profile。
8. 先运行 `ios-validation`；通过后再运行签名工作流。

官方依据：

- [Codemagic 原生 iOS 构建](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/)
- [codemagic.yaml 配置](https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/)
- [iOS 签名配置](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
- [App Store Connect 发布](https://docs.codemagic.io/yaml-publishing/app-store-connect/)

## 4. 构建前必须替换的值

当前 Bundle ID 是占位值 `com.yourcompany.pindou`。确定正式 ID 后同时修改：

1. `PindouApp/Configurations/Base.xcconfig` 的 `PINDOU_BUNDLE_ID`。
2. `codemagic.yaml` 中 Ad Hoc 工作流的 `bundle_identifier`。
3. `codemagic.yaml` 中 TestFlight 工作流的 `bundle_identifier`。
4. Apple Developer Portal 的 App ID、profiles 和 App Store Connect App 使用同一 ID。

四处不一致会导致 Codemagic 找不到匹配 profile 或 Archive 签名失败。

## 5. Windows 日常门禁

每次提交前运行：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\PindouApp\Scripts\validate-windows.ps1
```

它检查：

- iOS deployment target 为 16.0。
- target 同时覆盖 iPhone 与 iPad。
- App、测试 target 和 Swift 模块名存在。
- Codemagic 三条工作流及 XcodeGen/XCTest/IPA 命令存在。
- iOS 16 代码没有混入已知 iOS 17 专属 API。
- Domain 没有引用 SwiftUI、UIKit、Core Data、Vision 或 Core Image。

Windows 可选安装 Swift for Windows + Visual Studio C++ Build Tools，用于后续纯 Swift Package；SwiftUI、Core Data、Vision 与 iOS Simulator 的结论以 Codemagic 为准。

## 6. 提交到构建的闭环

1. Windows 编写测试、源码、资源和文档。
2. 运行 `validate-windows.ps1`。
3. Commit 并 push 到 GitHub。
4. Codemagic 自动运行 `ios-validation`。
5. 根据 Codemagic 的 Xcode 日志修复编译或测试问题。
6. 需要安装包时手动选择 `ios-ipa-adhoc` 或 `ios-testflight`。
7. 在实际 iPhone/iPad 验证相册、Share Extension、Core Data、Vision、横竖屏、Split View、大画布性能和内存压力。

## 7. Windows 开发特别注意

- Git 文本统一为 LF，文件名大小写与 import 完全一致。
- 生成的 Xcode 工程、DerivedData、证书、profiles、API 私钥不进入仓库。
- iOS 16 页面状态使用兼容方案；Observation 的 `@Observable` 属于更高系统版本。
- Codemagic `xcode: latest` 适合首次跑通；首次绿色构建后记录实际 Xcode 版本并改为固定版本，减少云端镜像升级造成的变化。
- 每次 IPA 使用 `PROJECT_BUILD_NUMBER` 更新 build number，避免重复上传版本。
- Codemagic 承担本地 Mac 的编译签名环节，摄像头、色彩、热状态、内存和 iPad 交互仍以真实设备为验收依据。
- Ad Hoc 和 App Store/TestFlight 是两种不同 profile；下载到的 IPA 是否可直接安装取决于所选工作流。

## 8. 当前验证状态

Windows 静态门禁已通过。Codemagic 首次运行将验证 XcodeGen schema、Swift 编译、XCTest、签名文件匹配和 IPA 归档。首个业务模块进入实现前，`ios-validation` 应先达到绿色。
