import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill") {
                DashboardView()
            }
            Tab("Properties", systemImage: "building.2.fill") {
                PropertyView()
            }
            Tab("Inspections", systemImage: "checklist") {
                InspectionsView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
