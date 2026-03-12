import SwiftUI

struct EditPropertySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditPropertyViewModel
    @State private var showValidation = false
    let onSaved: (() -> Void)?

    init(propertyId: UUID, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: EditPropertyViewModel(propertyId: propertyId))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isLoading {
                    ProgressView("property_sheet.loading_property")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    // MARK: - Basic Details
                    Section(header: Text("property_sheet.basic_details")) {
                        TextField("property_sheet.property_name", text: $viewModel.name)
                            .onChange(of: viewModel.name) { _, _ in
                                if showValidation { }  // triggers re-render
                            }

                        if showValidation, let error = viewModel.nameError {
                            validationText(error)
                        }

                        TextField("property_sheet.description", text: $viewModel.description, axis: .vertical)
                            .lineLimit(3...10)
                    }

                    // MARK: - Classification
                    Section(header: Text("property_sheet.classification")) {
                        Picker("property_sheet.property_type", selection: $viewModel.type) {
                            Text("property_type.apartment").tag("Apartment")
                            Text("property_type.house").tag("House")
                            Text("property_type.condo").tag("Condo")
                            Text("property_type.townhouse").tag("Townhouse")
                            Text("property_type.other").tag("Other")
                        }

                        Picker("property_sheet.status", selection: $viewModel.status) {
                            Text("status.active").tag("active")
                            Text("status.inactive").tag("inactive")
                            Text("status.draft").tag("draft")
                        }
                    }

                    // MARK: - Location
                    Section(header: Text("property_sheet.location")) {
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
                            validationText(error)
                        }

                        Picker("property_sheet.country", selection: $viewModel.country) {
                            ForEach(AddPropertyViewModel.allCountries, id: \.code) { country in
                                Text(country.name).tag(country.name)
                            }
                        }
                    }

                    // MARK: - Details
                    Section(header: Text("property_sheet.details")) {
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

                        TextField("property_sheet.max_guests", text: $viewModel.maxGuests)
                            .platformNumberPadKeyboard()
                        if showValidation, let error = viewModel.maxGuestsError {
                            validationText(error)
                        }
                    }

                    // MARK: - Listings
                    Section(header: Text("property_sheet.listings")) {
                        TextField("property_sheet.airbnb_id", text: $viewModel.airbnbListingId)
                            .platformNoAutocapitalization()
                            .autocorrectionDisabled()
                        TextField("property_sheet.vrbo_id", text: $viewModel.vrboListingId)
                            .platformNoAutocapitalization()
                            .autocorrectionDisabled()
                    }

                    // MARK: - Server Error
                    if let error = viewModel.errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("property_sheet.edit_title")
            .platformInlineNavigationTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: handleSave) {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("common.save")
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.isLoading)
                }
            }
            .task {
                await viewModel.fetchProperty()
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
                onSaved?()
                dismiss()
            } else {
                HapticManager.shared.notification(type: .error)
            }
        }
    }

    private func validationText(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
    }
}
