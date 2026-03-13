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
                        propertyTypeOption("property_type.apartment", value: "Apartment")
                        propertyTypeOption("property_type.house", value: "House")
                        propertyTypeOption("property_type.condo", value: "Condo")
                        propertyTypeOption("property_type.townhouse", value: "Townhouse")
                        propertyTypeOption("property_type.other", value: "Other")
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
                        Label(
                            String.localizedStringWithFormat(NSLocalizedString("property_sheet.bedrooms", comment: ""), viewModel.bedroomsCount),
                            systemImage: "bed.double.fill"
                        )
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
                        Label(
                            String.localizedStringWithFormat(NSLocalizedString("property_sheet.bathrooms", comment: ""), viewModel.bathroomsCount),
                            systemImage: "bathtub.fill"
                        )
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
                        Label("property_sheet.max_guests", systemImage: "person.2.fill")
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

    @ViewBuilder
    private func propertyTypeOption(_ titleKey: LocalizedStringKey, value: String) -> some View {
        Label {
            Text(titleKey)
        } icon: {
            Image(systemName: PropertyUI.icon(for: value))
                .foregroundStyle(PropertyUI.color(for: value))
        }
        .tag(value)
    }
}
