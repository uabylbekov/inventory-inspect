import Foundation
import Supabase

@Observable
final class ManageTeamViewModel {
    let propertyId: UUID
    var newMemberEmail = ""
    var newMemberRole = "maintainer"
    
    var isSaving = false
    var errorMessage: String?
    var successMessage: String?
    
    init(propertyId: UUID) {
        self.propertyId = propertyId
    }
    
    var isValidEmail: Bool {
        let email = newMemberEmail.trimmingCharacters(in: .whitespaces)
        return email.contains("@") && email.contains(".") && email.count > 4
    }
    
    var isInviteDisabled: Bool {
        !isValidEmail || isSaving
    }
    

    
    func inviteMember() async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        
        let email = newMemberEmail.trimmingCharacters(in: .whitespaces).lowercased()
        if !email.contains("@") || !email.contains(".") {
            self.errorMessage = "Please enter a valid email address."
            self.isSaving = false
            return false
        }
        
        do {
            let session = try await supabase.auth.session
            let canInvite = try await remoteCanInviteMember(
                propertyId: propertyId,
                userId: session.user.id
            )
            if !canInvite {
                self.errorMessage = "Team member limit reached for this property's plan."
                self.isSaving = false
                return false
            }

            struct InvitePayload: Encodable {
                let email: String
                let property_id: String
                let role: String
            }
            struct InviteResponse: Decodable {
                let success: Bool?
                let status: String?
                let error: String?
            }

            let response: InviteResponse = try await supabase.functions
                .invoke("send-property-invite", options: .init(body: InvitePayload(
                    email: email,
                    property_id: propertyId.uuidString.lowercased(),
                    role: newMemberRole
                )))

            if let serverError = response.error {
                self.errorMessage = serverError
                self.isSaving = false
                return false
            }

            self.isSaving = false
            self.successMessage = response.status == "pending_created"
                ? "Invite sent! \(email) will receive an email to download the app."
                : "Successfully added \(email) to the team!"
            self.newMemberEmail = ""
            return true

        } catch is CancellationError {
            self.isSaving = false
            return false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isSaving = false
            return false
        }
    }

    private func remoteCanInviteMember(propertyId: UUID, userId: UUID) async throws -> Bool {
        let params: [String: AnyJSON] = [
            "p_property_id": .string(propertyId.uuidString.lowercased()),
            "p_user_id": .string(userId.uuidString.lowercased())
        ]
        do {
            let allowed: Bool = try await supabase
                .rpc("can_invite_property_member", params: params)
                .execute()
                .value
            return allowed
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("could not find the function")
                || message.contains("function public.can_invite_property_member")
                || message.contains("schema cache") {
                throw NSError(
                    domain: "ManageTeamViewModel",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Invite rules are unavailable in this environment. Apply the latest database migrations before sending invites."]
                )
            }
            throw error
        }
    }
    
    // Add arrays to track existing members
    var members: [TeamMemberModel] = []
    var isLoadingMembers = false
    

    
    func fetchMembers() async {
        isLoadingMembers = true
        do {
            let params: [String: AnyJSON] = [
                "p_property_id": .string(propertyId.uuidString.lowercased())
            ]
            
            let fetched: [TeamMemberModel] = try await supabase
                .rpc("get_property_team_members", params: params)
                .execute()
                .value
                
            self.members = fetched
            self.isLoadingMembers = false
        } catch is CancellationError {
            self.isLoadingMembers = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoadingMembers = false
        }
    }
    
    func removeMember(memberId: UUID) async {
        do {
            try await supabase.from("property_members")
                .delete()
                .eq("id", value: memberId)
                .execute()
            
            await fetchMembers() // Refresh list
        } catch is CancellationError {
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func leaveProperty() async -> Bool {
        do {
            let session = try await supabase.auth.session
            try await supabase.from("property_members")
                .delete()
                .eq("user_id", value: session.user.id)
                .eq("property_id", value: propertyId)
                .execute()
            return true
        } catch is CancellationError {
            return false
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
