import SwiftUI

struct ManageTeamSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ManageTeamViewModel
    let isOwner: Bool
    let isManager: Bool
    @Binding var didLeave: Bool

    init(propertyId: UUID, isOwner: Bool, isManager: Bool = false, didLeave: Binding<Bool>) {
        self.isOwner = isOwner
        self.isManager = isManager
        self._didLeave = didLeave
        _viewModel = State(initialValue: ManageTeamViewModel(propertyId: propertyId))
    }

    private var canInvite: Bool { isOwner || isManager }
    
    var body: some View {
        NavigationStack {
            Form {
                if canInvite {
                    Section(header: Text("Invite Team Member")) {
                        TextField("Email Address", text: $viewModel.newMemberEmail)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        Picker("Role", selection: $viewModel.newMemberRole) {
                            if isOwner {
                                Text("Manager").tag("manager")
                            }
                            Text("Cleaner").tag("cleaner")
                        }
                    }
                    
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
                                Text("Send Invite")
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
                
                Section(header: Text("Current Members")) {
                    if viewModel.isLoadingMembers {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if viewModel.members.isEmpty {
                        Text("No other members on this team.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.members) { member in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(member.name ?? member.email)
                                        .font(.headline)
                                    Text(member.role.capitalized)
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
                            Text("Leave Property")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.fetchMembers()
            }
        }
    }
}
