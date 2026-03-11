import SwiftUI

struct CheckInboxView: View {
    let email: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("✉️")
                .font(.system(size: 72))
                .padding(.bottom, 24)
                .padding(.top, 40)
            
            Text("auth.check_inbox.title")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 12)
            
            Text(String(format: NSLocalizedString("auth.check_inbox.message", comment: ""), email))
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
            
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Hide the back button to make it feel like a completed step
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    CheckInboxView(email: "test@example.com")
}
