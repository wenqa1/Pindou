import SwiftUI

struct InventoryDashboardView: View {
    @ObservedObject var model: InventoryDashboardModel

    @State private var entryMode: InventoryEntryMode?

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InventorySummaryView(model: model)

                if model.skuOverviews.isEmpty {
                    InventoryEmptyState(
                        title: "还没有库存",
                        systemImage: "shippingbox",
                        description: "先记录一次入库，之后可以随时查看色号余额和流水。"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("库存色号")
                            .font(.title3.weight(.semibold))

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(model.skuOverviews) { overview in
                                NavigationLink(value: overview.sku) {
                                    InventorySKUCard(
                                        overview: overview,
                                        lowStockThreshold: model.lowStockThreshold
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !model.movements.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最近流水")
                                .font(.title3.weight(.semibold))

                            ForEach(model.movements.sorted { $0.occurredAt > $1.occurredAt }.prefix(6)) { movement in
                                InventoryMovementRow(movement: movement)
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("豆仓")
        .navigationDestination(for: BeadSKU.self) { sku in
            InventorySKUDetailView(model: model, sku: sku)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("入库", systemImage: "plus.circle") {
                        entryMode = .inbound
                    }
                    Button("出库", systemImage: "minus.circle") {
                        entryMode = .outbound
                    }
                } label: {
                    Label("库存操作", systemImage: "plus")
                }
            }
        }
        .sheet(item: $entryMode) { mode in
            InventoryEntrySheet(mode: mode, model: model)
        }
        .alert(
            "库存操作未完成",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.clearError()
                    }
                }
            )
        ) {
            Button("知道了", role: .cancel) {
                model.clearError()
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

private struct InventorySummaryView: View {
    @ObservedObject var model: InventoryDashboardModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                metricCards
            }
            VStack(spacing: 12) {
                metricCards
            }
        }
    }

    private var metricCards: some View {
        Group {
            InventoryMetricCard(title: "现存", value: model.totalOnHand, systemImage: "shippingbox.fill")
            InventoryMetricCard(title: "可用", value: model.totalAvailable, systemImage: "checkmark.circle.fill")
            InventoryMetricCard(title: "低库存", value: Int64(model.lowStockCount), systemImage: "exclamationmark.triangle.fill")
        }
    }
}

private struct InventoryMetricCard: View {
    let title: String
    let value: Int64
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.title2.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct InventorySKUCard: View {
    let overview: InventorySKUOverview
    let lowStockThreshold: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(overview.sku.colorCode)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text("\(overview.sku.brandID) · \(overview.sku.seriesID)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("可用 \(overview.balance.available.formatted())")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            if overview.balance.available < lowStockThreshold {
                Label("低于阈值", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct InventorySKUDetailView: View {
    @ObservedObject var model: InventoryDashboardModel
    let sku: BeadSKU

    var body: some View {
        Group {
            if let overview = model.overview(for: sku) {
                List {
                    Section("库存") {
                        LabeledContent("现存", value: overview.balance.onHand.formatted())
                        LabeledContent("预留", value: overview.balance.reserved.formatted())
                        LabeledContent("可用", value: overview.balance.available.formatted())
                        LabeledContent("在途", value: overview.balance.inTransit.formatted())
                    }

                    Section("流水") {
                        ForEach(model.movements(for: sku)) { movement in
                            InventoryMovementRow(movement: movement)
                        }
                    }
                }
            } else {
                InventoryEmptyState(
                    title: "找不到色号",
                    systemImage: "shippingbox",
                    description: "该色号可能已被移除。"
                )
            }
        }
        .navigationTitle(sku.colorCode)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InventoryEmptyState: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct InventoryMovementRow: View {
    let movement: StockMovement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: movement.kind.systemImage)
                .foregroundStyle(movement.kind == .outbound ? Color.orange : Color.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(movement.kind.title)
                    .font(.body.weight(.medium))
                Text("\(movement.sku.brandID) · \(movement.sku.seriesID) · \(movement.sku.colorCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(movement.signedQuantityText)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                Text(movement.occurredAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct InventoryEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: InventoryEntryMode
    @ObservedObject var model: InventoryDashboardModel

    @State private var brandID = ""
    @State private var seriesID = ""
    @State private var colorCode = ""
    @State private var quantityText = ""
    @State private var idempotencyKey = UUID().uuidString

    private var draft: InventoryEntryDraft? {
        guard let quantity = Int64(quantityText) else {
            return nil
        }
        return InventoryEntryDraft(
            brandID: brandID,
            seriesID: seriesID,
            colorCode: colorCode,
            quantity: quantity
        )
    }

    private var preview: InventoryBalance? {
        guard let draft else {
            return nil
        }
        return model.preview(kind: mode.movementKind, draft: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("色号") {
                    TextField("品牌", text: $brandID)
                    TextField("系列", text: $seriesID)
                    TextField("色号，例如 F22", text: $colorCode)
                        .textInputAutocapitalization(.characters)
                }

                Section("数量") {
                    TextField("颗数", text: $quantityText)
                        .keyboardType(.numberPad)
                    Text("仅支持正整数。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let preview {
                    Section("提交预览") {
                        LabeledContent("现存") {
                            Text(preview.onHand.formatted())
                                .monospacedDigit()
                        }
                        LabeledContent("可用") {
                            Text(preview.available.formatted())
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        submit()
                    }
                    .disabled(draft == nil)
                }
            }
        }
    }

    private func submit() {
        guard let draft else {
            return
        }
        if model.record(kind: mode.movementKind, draft: draft, idempotencyKey: idempotencyKey) {
            dismiss()
        }
    }
}

private enum InventoryEntryMode: Hashable, Identifiable {
    case inbound
    case outbound

    var id: Self { self }

    var title: String {
        switch self {
        case .inbound: "入库"
        case .outbound: "出库"
        }
    }

    var movementKind: StockMovementKind {
        switch self {
        case .inbound: .inbound
        case .outbound: .outbound
        }
    }
}

private extension StockMovementKind {
    var title: String {
        switch self {
        case .inbound: "入库"
        case .outbound: "出库"
        case .stocktakeIncrease: "盘盈"
        case .stocktakeDecrease: "盘亏"
        case .outboundReversal: "出库冲销"
        case .inboundReversal: "入库冲销"
        }
    }

    var systemImage: String {
        switch self {
        case .inbound, .stocktakeIncrease, .outboundReversal:
            "arrow.down.circle.fill"
        case .outbound, .stocktakeDecrease, .inboundReversal:
            "arrow.up.circle.fill"
        }
    }
}

private extension StockMovement {
    var signedQuantityText: String {
        switch kind {
        case .inbound, .stocktakeIncrease, .outboundReversal:
            return "+\(quantity.formatted())"
        case .outbound, .stocktakeDecrease, .inboundReversal:
            return "−\(quantity.formatted())"
        }
    }
}
