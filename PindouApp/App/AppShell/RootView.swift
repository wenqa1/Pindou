import SwiftUI

struct RootView: View {
    @State private var selection: AppSection? = .inventory

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("豆图")
        } detail: {
            if let selection {
                FeaturePlaceholderView(section: selection)
            } else {
                PlaceholderView(
                    title: "选择功能",
                    systemImage: "circle.grid.3x3",
                    description: nil
                )
            }
        }
    }
}

private struct FeaturePlaceholderView: View {
    let section: AppSection

    var body: some View {
        PlaceholderView(
            title: section.title,
            systemImage: section.systemImage,
            description: Text("模块入口已建立，功能将在对应 Feature 中实现。")
        )
        .navigationTitle(section.title)
    }
}

private struct PlaceholderView: View {
    let title: String
    let systemImage: String
    let description: Text?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.semibold))

            if let description {
                description
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}
