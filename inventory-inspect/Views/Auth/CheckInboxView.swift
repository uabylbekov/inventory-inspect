import SwiftUI

struct CheckInboxView: View {
    let email: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("✉️")
                .font(.system(size: 72))
                .padding(.bottom, 24)
                .padding(.top, 40)
            
            Text("Check your inbox")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 12)
            
            Text("We've sent a magic link to **\(email)**. Click the link to log in instantly.")
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
