import SwiftUI

struct EditPropertySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditPropertyViewModel
    
    init(propertyId: UUID) {
        _viewModel = State(initialValue: EditPropertyViewModel(propertyId: propertyId))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isLoading {
                    ProgressView("Loading Property...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Section(header: Text("Basic Details")) {
                        TextField("Property Name *", text: $viewModel.name)
                        TextField("Description", text: $viewModel.description)
                    }
                    
                    Section(header: Text("Classification")) {
                        Picker("Property Type *", selection: $viewModel.type) {
                            Text("Apartment").tag("Apartment")
                            Text("House").tag("House")
                            Text("Condo").tag("Condo")
                            Text("Townhouse").tag("Townhouse")
                            Text("Other").tag("Other")
                        }
                        
                        Picker("Status", selection: $viewModel.status) {
                            Text("Active").tag("active")
                            Text("Inactive").tag("inactive")
                            Text("Draft").tag("draft")
                        }
                    }
                    
                    Section(header: Text("Location")) {
                        TextField("Address Line 1", text: $viewModel.addressLine1)
                            .textContentType(.streetAddressLine1)
                        TextField("Address Line 2", text: $viewModel.addressLine2)
                            .textContentType(.streetAddressLine2)
                        TextField("City", text: $viewModel.city)
                            .textContentType(.addressCity)
                        TextField("State / Region", text: $viewModel.stateRegion)
                            .textContentType(.addressState)
                        TextField("Postal Code", text: $viewModel.postalCode)
                            .textContentType(.postalCode)
                        
                        Picker("Country *", selection: $viewModel.country) {
                            Text("United States").tag("United States")
                            Text("Canada").tag("Canada")
                            Text("United Kingdom").tag("United Kingdom")
                            Text("Australia").tag("Australia")
                        }
                    }
                    
                    Section(header: Text("Details")) {
                        Stepper("Bedrooms: \(viewModel.bedroomsCount)", value: $viewModel.bedroomsCount, in: 0...50)
                        Stepper("Bathrooms: \(viewModel.bathroomsCount, specifier: "%.1f")", value: $viewModel.bathroomsCount, in: 0...50, step: 0.5)
                        TextField("Max Guests", text: $viewModel.maxGuests)
                            .keyboardType(.numberPad)
                    }
                    
                    Section(header: Text("Listings")) {
                        TextField("Airbnb Listing ID", text: $viewModel.airbnbListingId)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        TextField("VRBO Listing ID", text: $viewModel.vrboListingId)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    if let error = viewModel.errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("Edit Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        Task {
                            HapticManager.shared.impact(style: .medium)
                            let success = await viewModel.saveToSupabase()
                            if success {
                                HapticManager.shared.notification(type: .success)
                                dismiss()
                            } else {
                                HapticManager.shared.notification(type: .error)
                            }
                        }
                    }) {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isSaveDisabled)
                }
            }
            .task {
                await viewModel.fetchProperty()
            }
        }
    }
}
