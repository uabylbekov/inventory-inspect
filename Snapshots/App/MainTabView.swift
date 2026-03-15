import SwiftUI

struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSection: AppSection? = .inspections
    @State private var inspectionBadgeStore = InspectionBadgeStore.shared

    var body: some View {
        Group {
            if prefersSidebarLayout {
                sidebarLayout
            } else {
                compactTabLayout
            }
        }
        .task {
            inspectionBadgeStore.startMonitoring()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                inspectionBadgeStore.startMonitoring()
            default:
                inspectionBadgeStore.stopMonitoring()
            }
        }
    }

    private var compactTabLayout: some View {
        TabView {
            Tab("inspections.title", systemImage: AppSection.inspections.systemImage) {
                InspectionsView()
            }
            .badge(inspectionBadgeStore.ongoingCount > 0 ? inspectionBadgeStore.ongoingCount : 0)
            Tab("property.title", systemImage: AppSection.properties.systemImage) {
                PropertyView()
            }
            Tab("settings.title", systemImage: AppSection.settings.systemImage) {
                SettingsView()
            }
        }
    }

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                sidebarLabel(for: section)
                    .tag(section)
            }
            .navigationTitle("auth.login.app_name")
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

    @ViewBuilder
    private func sidebarLabel(for section: AppSection) -> some View {
        HStack {
            Label(section.title, systemImage: section.systemImage)

            if section == .inspections, inspectionBadgeStore.ongoingCount > 0 {
                Spacer()
                Text("\(inspectionBadgeStore.ongoingCount)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
            }
        }
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
            return "inspections.title"
        case .properties:
            return "property.title"
        case .settings:
            return "settings.title"
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
