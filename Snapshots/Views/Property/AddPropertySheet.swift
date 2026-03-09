import SwiftUI

struct AddPropertySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddPropertyViewModel()
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Basic Details
                Section("Basic Details") {
                    TextField("Property Name (e.g. Sunset Villa)", text: $viewModel.name)
                        .onChange(of: viewModel.name) { _, _ in
                            if showValidation { } 
                        }

                    if showValidation, let error = viewModel.nameError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...10)
                }

                // MARK: - Classification
                Section("Classification") {
                    Picker("Property Type", selection: $viewModel.type) {
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

                // MARK: - Location
                Section("Location") {
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
                        .autocorrectionDisabled()
                    
                    if showValidation, let error = viewModel.postalCodeError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Picker("Country", selection: $viewModel.country) {
                        ForEach(AddPropertyViewModel.allCountries, id: \.code) { country in
                            Text(country.name).tag(country.name)
                        }
                    }
                }

                // MARK: - Details
                Section("Interior Details") {
                    Stepper("Bedrooms: \(viewModel.bedroomsCount)", value: $viewModel.bedroomsCount, in: 0...50)
                    Stepper("Bathrooms: \(viewModel.bathroomsCount, specifier: "%.1f")", value: $viewModel.bathroomsCount, in: 0...50, step: 0.5)

                    HStack {
                        Text("Max Guests")
                        Spacer()
                        TextField("Count", text: $viewModel.maxGuests)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    if showValidation, let error = viewModel.maxGuestsError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // MARK: - Listings
                Section("External Listings") {
                    TextField("Airbnb Listing ID", text: $viewModel.airbnbListingId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    TextField("VRBO Listing ID", text: $viewModel.vrboListingId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                // MARK: - Action Section
                Section {
                    Button(action: handleSave) {
                        HStack(spacing: 8) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Add Property")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isSaving)
                    .listRowBackground(Color.accentColor)
                    .foregroundColor(.white)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func handleSave() {
        showValidation = true
        guard viewModel.isFormValid else {
            HapticManager.shared.notification(type: .error)
            return
        }
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
    }
}
