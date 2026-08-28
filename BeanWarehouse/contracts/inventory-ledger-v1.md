# Inventory Ledger v1 契约

## SKU

一个 SKU 由 `brandID`、`seriesID`、`colorCode` 组成。三个字段均为去除首尾空白后的非空字符串；大小写规范由具体色卡处理，账本不得把跨品牌/跨系列的同色号合并。

## 流水

| 字段 | 规则 |
|---|---|
| `id` | UUID，创建后不可修改 |
| `kind` | `inbound`、`outbound`、`stocktakeIncrease`、`stocktakeDecrease`、`outboundReversal`、`inboundReversal` |
| `quantity` | 1 到 1,000,000,000 的整数 |
| `occurredAt` | ISO 8601 UTC 时间 |
| `idempotencyKey` | 单个库存库内唯一，重复提交返回已有结果，不再写入 |

正向类型为 `inbound`、`stocktakeIncrease`、`outboundReversal`；其他类型为负向。现存量是所有生效流水的有符号和；流水不可直接编辑，只能以反向流水冲销。

## 首版出库规则

- 交互式手工出库必须先检查 `available >= quantity`。
- 拒绝出库时不写流水，返回可用量和请求量。
- 预留与在途保留在 iOS 领域模型中，NAS v1 尚未开放编辑入口；NAS 仅以现存量作为可用量。

## 飞牛 OS HTTP API

| 方法 | 路径 | 说明 |
|---|---|---|
| `GET` | `/api/health` | 容器健康检查 |
| `GET` | `/api/inventory` | 余额和低库存状态 |
| `GET` | `/api/movements` | 最近最多 200 条流水，可按 SKU 查询 |
| `POST` | `/api/movements` | 新建流水；处理幂等和出库校验 |
| `GET/PUT` | `/api/settings` | 读取/更新低库存阈值 |

API 只为同源 NAS Web UI 提供服务。首版不启用跨域访问、远程账户或公网暴露。
