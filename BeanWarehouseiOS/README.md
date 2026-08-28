# 豆仓 iOS 独立应用

这是面向 iOS/iPadOS 16+ 的独立豆量管理应用。它直接复用 `PindouApp/Features/Inventory` 的领域规则、应用层、Core Data 适配器和 SwiftUI 页面；不会读取或写入“豆图”应用的数据文件。

## 本地数据

SQLite 数据库文件名为 `BeanWarehouse.sqlite`，由系统保存至本应用自己的 Application Support 沙盒。即使与“豆图”安装在同一设备上，两者也不共享用户库存。

## Windows 开发与云端构建

在 macOS/Codemagic 工作机中执行：

```bash
cd BeanWarehouseiOS
xcodegen generate
xcodebuild test -project BeanWarehouseApp.xcodeproj -scheme BeanWarehouseApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

IPA 签名与分发沿用仓库根目录的 Codemagic 工作流；发布前需要设置独立的 `BEAN_WAREHOUSE_BUNDLE_ID`、证书和描述文件。
