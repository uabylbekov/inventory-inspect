import SwiftUI

struct SubscriptionPlanRow: View {
    @Environment(SnapshotsAccessManager.self) private var accessManager

    var body: some View {
        NavigationLink {
            SubscriptionCenterView(showsDismissButton: false)
        } label: {
            LabeledContent {
                if accessManager.hasDirectPaidAccess {
                    PlanBadge()
                } else {
                    Text(currentPlanTitle)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Label("plan.your", systemImage: iconName)
            }
        }
    }

    private var currentPlanTitle: String {
        if accessManager.hasBusinessAccess { return String(localized: "plan.business") }
        if accessManager.hasDirectPaidAccess { return String(localized: "plan.professional") }
        return String(localized: "plan.standard")
    }
    private var iconName: String {
        if accessManager.hasBusinessAccess { return "briefcase.fill" }
        if accessManager.hasDirectPaidAccess { return "star.fill" }
        return "person.fill"
    }
}
