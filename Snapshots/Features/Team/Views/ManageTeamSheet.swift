import SwiftUI

struct ManageTeamSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ManageTeamViewModel
    let property: PropertyModel
    let isOwner: Bool
    let isManager: Bool
    @Binding var didLeave: Bool
    private let accessManager = SnapshotsAccessManager.shared

    init(property: PropertyModel, isOwner: Bool, isManager: Bool = false, didLeave: Binding<Bool>) {
        self.property = property
        self.isOwner = isOwner
        self.isManager = isManager
        self._didLeave = didLeave
        _viewModel = State(initialValue: ManageTeamViewModel(propertyId: property.id))
    }

    private var canInvite: Bool { isOwner || isManager }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: accessManager.hasDirectPaidAccess ? "star.circle.fill" : "person.crop.circle.badge.checkmark")
                            .foregroundColor(.accentColor)
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(accessManager.hasDirectPaidAccess ? "team.unlocked_by_your_plan" : "inspection_item.included_here")
                                .font(.subheadline.weight(.semibold))
                            Text(teamAccessDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }

                if canInvite {
                    let canAddMore = accessManager.canAddTeamMember(for: property, currentMemberCount: viewModel.members.count)
                    
                    Section(header: Text("team.invite_member")) {
                        if canAddMore {
                            TextField("auth.login.email_section", text: $viewModel.newMemberEmail)
                                .platformEmailTextInput()
                                .autocorrectionDisabled()
                            
                            Picker("team.role", selection: $viewModel.newMemberRole) {
                                if isOwner || isManager {
                                    Text("team.role.manager").tag("manager")
                                }
                                Text("team.role.maintainer").tag("maintainer")
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("team.limit_reached", systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text("team.limit_message")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    if canAddMore {
                        Section {
                            Button(action: {
                                Task {
                                    HapticManager.shared.impact(style: .medium)
                                    let success = await viewModel.inviteMember()
                                    if success {
                                        HapticManager.shared.notification(type: .success)
                                        await viewModel.fetchMembers()
                                    } else {
                                        HapticManager.shared.notification(type: .error)
                                    }
                                }
                            }) {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    Text("team.send_invite")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(viewModel.isInviteDisabled)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                
                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.footnote)
                    }
                }
                
                Section(header: Text("team.current_members")) {
                    if viewModel.isLoadingMembers {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if viewModel.members.isEmpty {
                        Text("team.no_other_members")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.members) { member in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(member.name ?? member.email)
                                        .font(.headline)
                                    Text(displayRole(member.role))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if member.role == "owner" {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            if isOwner {
                                for index in indexSet {
                                    let member = viewModel.members[index]
                                    // Make sure owner isn't deleting themselves accidently
                                        if member.role != "owner" { 
                                            Task { 
                                                HapticManager.shared.impact(style: .medium)
                                                await viewModel.removeMember(memberId: member.id) 
                                                HapticManager.shared.notification(type: .success)
                                            }
                                        }                              }
                            }
                        }
                    }
                }
                
                // Allow non-owners to remove themselves from a property completely
                if !isOwner {
                    Section {
                        Button(role: .destructive, action: {
                            Task {
                                HapticManager.shared.impact(style: .medium)
                                let left = await viewModel.leaveProperty()
                                if left {
                                    HapticManager.shared.notification(type: .success)
                                    didLeave = true
                                    dismiss()
                                } else {
                                    HapticManager.shared.notification(type: .error)
                                }
                            }
                        }) {
                            Text("team.leave_property")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("team.title")
            .platformInlineNavigationTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .task {
                await viewModel.fetchMembers()
            }
        }
    }

    private var teamAccessDescription: String {
        if accessManager.hasDirectPaidAccess {
            return String.localizedStringWithFormat(
                NSLocalizedString("team.access.direct", comment: ""),
                accessManager.hasBusinessAccess ? String(localized: "plan.business") : String(localized: "plan.professional")
            )
        }
        if property.ownerTier == "free" {
            return String(localized: "team.access.free_owner")
        }
        return String.localizedStringWithFormat(
            NSLocalizedString("team.access.inherited", comment: ""),
            property.ownerDisplayName,
            ownerPlanDisplayName
        )
    }

    private func displayRole(_ role: String) -> String {
        switch role {
        case "owner":
            return String(localized: "team.role.owner")
        case "manager":
            return String(localized: "team.role.manager")
        case "cleaner", "maintainer":
            return String(localized: "team.role.maintainer")
        default:
            return role.capitalized
        }
    }

    private var ownerPlanDisplayName: String {
        switch property.ownerTier.lowercased() {
        case "business":
            return String(localized: "plan.business")
        case "professional", "pro":
            return String(localized: "plan.professional")
        case "standard", "free":
            return String(localized: "plan.standard")
        default:
            return property.ownerTier.capitalized
        }
    }
}
