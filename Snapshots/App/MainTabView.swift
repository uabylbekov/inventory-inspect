import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Inspections", systemImage: "checklist") {
                InspectionsView()
            }
            Tab("Properties", systemImage: "building.2.fill") {
                PropertyView()
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
