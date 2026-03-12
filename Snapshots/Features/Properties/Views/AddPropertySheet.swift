import SwiftUI

struct AddPropertySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddPropertyViewModel()
    @State private var showValidation = false
    let onSaved: (() -> Void)?

    init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("property_sheet.basic_details") {
                    TextField("property_sheet.name_placeholder", text: $viewModel.name)
                        .onChange(of: viewModel.name) { _, _ in
                            if showValidation { }
                        }

                    if showValidation, let error = viewModel.nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }

                    TextField("property_sheet.description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section("property_sheet.classification") {
                    Picker("property_sheet.property_type", selection: $viewModel.type) {
                        Text("property_type.apartment").tag("Apartment")
                        Text("property_type.house").tag("House")
                        Text("property_type.condo").tag("Condo")
                        Text("property_type.townhouse").tag("Townhouse")
                        Text("property_type.other").tag("Other")
                    }
                }

                Section("property_sheet.location") {
                    TextField("property_sheet.address1", text: $viewModel.addressLine1)
                        .platformStreetAddressLine1TextContentType()
                    TextField("property_sheet.address2", text: $viewModel.addressLine2)
                        .platformStreetAddressLine2TextContentType()
                    TextField("property_sheet.city", text: $viewModel.city)
                        .platformAddressCityTextContentType()
                    TextField("property_sheet.state_region", text: $viewModel.stateRegion)
                        .platformAddressStateTextContentType()

                    TextField("property_sheet.postal_code", text: $viewModel.postalCode)
                        .platformPostalCodeTextContentType()
                        .autocorrectionDisabled()
                    
                    if showValidation, let error = viewModel.postalCodeError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }

                    Picker("property_sheet.country", selection: $viewModel.country) {
                        ForEach(AddPropertyViewModel.allCountries, id: \.code) { country in
                            Text(country.name).tag(country.name)
                        }
                    }
                }

                Section("property_sheet.interior_details") {
                    Stepper {
                        Text(String.localizedStringWithFormat(NSLocalizedString("property_sheet.bedrooms", comment: ""), viewModel.bedroomsCount))
                    } onIncrement: {
                        guard viewModel.bedroomsCount < 50 else { return }
                        viewModel.bedroomsCount += 1
                        HapticManager.shared.selection()
                    } onDecrement: {
                        guard viewModel.bedroomsCount > 0 else { return }
                        viewModel.bedroomsCount -= 1
                        HapticManager.shared.selection()
                    }
                    Stepper {
                        Text(String.localizedStringWithFormat(NSLocalizedString("property_sheet.bathrooms", comment: ""), viewModel.bathroomsCount))
                    } onIncrement: {
                        guard viewModel.bathroomsCount < 50 else { return }
                        viewModel.bathroomsCount += 0.5
                        HapticManager.shared.selection()
                    } onDecrement: {
                        guard viewModel.bathroomsCount > 0 else { return }
                        viewModel.bathroomsCount -= 0.5
                        HapticManager.shared.selection()
                    }

                    HStack {
                        Text("property_sheet.max_guests")
                        Spacer()
                        TextField("property_sheet.count", text: $viewModel.maxGuests)
                            .platformNumberPadKeyboard()
                            .multilineTextAlignment(TextAlignment.trailing)
                            .frame(width: 80)
                    }
                    
                    if showValidation, let error = viewModel.maxGuestsError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }

                Section("property_sheet.external_listings") {
                    TextField("property_sheet.airbnb_id", text: $viewModel.airbnbListingId)
                        .platformNoAutocapitalization()
                        .autocorrectionDisabled()
                    TextField("property_sheet.vrbo_id", text: $viewModel.vrboListingId)
                        .platformNoAutocapitalization()
                        .autocorrectionDisabled()
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("property.add")
                        .font(.body)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .font(.body)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: handleSave) {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("common.save")
                                .font(.body)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

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
                onSaved?()
                dismiss()
            } else {
                HapticManager.shared.notification(type: .error)
            }
        }
    }
}
