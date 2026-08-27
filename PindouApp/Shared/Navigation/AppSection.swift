import Foundation

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case library
    case inventory
    case importPattern
    case build
    case planning
    case procurement
    case projects
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: "图纸库"
        case .inventory: "豆仓"
        case .importPattern: "上传图纸"
        case .build: "辅助拼豆"
        case .planning: "消耗计算"
        case .procurement: "补豆"
        case .projects: "我的图纸"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .library: "square.grid.2x2"
        case .inventory: "shippingbox"
        case .importPattern: "square.and.arrow.down"
        case .build: "circle.grid.3x3"
        case .planning: "function"
        case .procurement: "cart"
        case .projects: "folder"
        case .settings: "gearshape"
        }
    }
}

