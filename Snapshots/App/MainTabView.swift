import SwiftUI

struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSection: AppSection? = .inspections

    var body: some View {
        Group {
            if prefersSidebarLayout {
                sidebarLayout
            } else {
                compactTabLayout
            }
        }
    }

    private var compactTabLayout: some View {
        TabView {
            Tab("Inspections", systemImage: AppSection.inspections.systemImage) {
                InspectionsView()
            }
            Tab("Properties", systemImage: AppSection.properties.systemImage) {
                PropertyView()
            }
            Tab("Settings", systemImage: AppSection.settings.systemImage) {
                SettingsView()
            }
        }
    }

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Snapshots")
            .listStyle(.sidebar)
            .frame(minWidth: 220)
        } detail: {
            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.platformGroupedBackground)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection ?? .inspections {
        case .inspections:
            InspectionsView()
        case .properties:
            PropertyView()
        case .settings:
            SettingsView()
        }
    }

    private var prefersSidebarLayout: Bool {
#if os(macOS)
        true
#else
        horizontalSizeClass == .regular
#endif
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case inspections
    case properties
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .inspections:
            return "Inspections"
        case .properties:
            return "Properties"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .inspections:
            return "checklist"
        case .properties:
            return "building.2.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

#Preview {
    MainTabView()
}
