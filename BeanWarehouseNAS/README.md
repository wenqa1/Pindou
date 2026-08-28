# 豆仓飞牛 OS 应用

这是飞牛 OS 的 Docker Compose 部署版本：单容器、SQLite、本地 Web UI，不依赖云端账户或通用 AI 服务。

## 在飞牛 OS 安装

1. 在飞牛 OS 的 Docker 页面新建 Compose 项目，并选择一个持久化目录。
2. 导入本目录的 `compose.yaml`，点击构建并启动。
3. 访问 `http://飞牛设备IP:8786`。

`./data` 映射为容器内 `/data`，其中的 `bean-warehouse.sqlite` 是全部库存真值；更新容器前请备份该目录。

## 首版边界

- 已实现：本地入库、出库、重复提交去重、低库存阈值、库存汇总和最近 200 条流水。
- 暂不包含：账户、外网暴露、图纸消耗预留、采购在途、iOS/NAS 自动同步。
- 飞牛原生 FPK 打包将在 Compose 版真机验收后进行；届时按官方 `fnpack` 与 manifest 规范生成，避免使用未经验证的第三方格式。
