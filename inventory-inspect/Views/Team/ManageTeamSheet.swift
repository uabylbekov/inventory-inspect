import SwiftUI

struct ManageTeamSheet: View {
    @Environment(\.dismiss) private var dismiss
    let propertyId: UUID
    
    // In a real app, this would fetch the actual team members from Supabase
    // For now, we are adding the UI framework for inviting a new member.
    @State private var newMemberEmail = ""
    @State private var newMemberRole = "cleaner"
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Invite Team Member")) {
                    TextField("Email Address", text: $newMemberEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    Picker("Role", selection: $newMemberRole) {
                        Text("Manager").tag("manager")
                        Text("Cleaner").tag("cleaner")
                    }
                    
                    Button(action: {
                        // TODO: Implement Supabase Invitation Logic
                        // Need Supabase Edge Functions or Backend Endpoint to properly resolve email-to-id mapping
                        dismiss()
                    }) {
                        Text("Send Invite")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(newMemberEmail.isEmpty)
                }
                
                Section(header: Text("Current Members")) {
                    Text("Support for viewing and removing team members coming soon!")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("Manage Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
