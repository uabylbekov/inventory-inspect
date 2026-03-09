import Foundation
import Supabase

@Observable
final class ManageTeamViewModel {
    let propertyId: UUID
    var newMemberEmail = ""
    var newMemberRole = "cleaner"
    
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
            let params: [String: AnyJSON] = [
                "p_email": .string(email),
                "p_property_id": .string(propertyId.uuidString.lowercased()),
                "p_role": .string(newMemberRole)
            ]
            
            // Calls a custom Postgres function (RPC) we setup in Supabase
            try await supabase.rpc("invite_user_to_property", params: params).execute()
            
            self.isSaving = false
            self.successMessage = "Successfully added \(email) to the team!"
            self.newMemberEmail = ""
            return true
            
        } catch is CancellationError {
            self.isSaving = false
            return false
        } catch let error as PostgrestError {
            self.errorMessage = error.message
            self.isSaving = false
            return false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isSaving = false
            return false
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

