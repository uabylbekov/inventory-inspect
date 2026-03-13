import SwiftUI

import Supabase

struct PropertyView: View {
    @State private var viewModel = PropertyViewModel()
    @State private var editingProperty: PropertyModel?
    @State private var propertyToDelete: PropertyModel?
    @State private var showingPropertyDeleteAlert = false
    @State private var showingActiveInspectionWarning = false
    @State private var activeInspectionWarningCount = 0
    @State private var deleteConfirmationText = ""

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section("property.your_properties") {
                    if !viewModel.hasLoadedInitialState {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if viewModel.isLoading && viewModel.properties.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if viewModel.properties.isEmpty {
                        ContentUnavailableView(
                            "property.empty.title",
                            systemImage: "building.2",
                            description: Text("property.empty.subtitle")
                        )
                    } else {
                        ForEach(viewModel.properties) { property in
                            NavigationLink {
                                PropertyDetailView(property: property)
                            } label: {
                                PropertyRow(property: property)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if property.canDeleteProperty {
                                    Button(role: .destructive) {
                                        initiateDelete(for: property)
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if property.canEditProperty {
                                    Button {
                                        editingProperty = property
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                    }
                                    .tint(.accentColor)
                                }
                            }
                            .contextMenu {
                                if property.canEditProperty {
                                    Button { editingProperty = property } label: { Label("common.edit", systemImage: "pencil") }
                                }
                                if property.canDeleteProperty {
                                    Button(role: .destructive) { initiateDelete(for: property) } label: { Label("common.delete", systemImage: "trash") }
                                }
                            }
                        }
                    }
                }
            }
            .applyPropertyListStyle()
            .refreshable {
                await viewModel.fetchProperties(showLoadingState: false)
            }
            .navigationTitle("property.title")
            .applyLargeNavigationTitleIfSupported()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        switch viewModel.destinationForAddProperty() {
                        case .addProperty?:
                            viewModel.showingAddProperty = true
                        case .paywall?:
                            viewModel.showingPaywall = true
                        case nil:
                            break
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("property.add")
                        }
                    }
                    .disabled(viewModel.isResolvingAddPropertyAccess)
                }
            }
                .task {
                    await viewModel.loadInitialData()
                }
                .alert("property.delete.active_title", isPresented: $showingActiveInspectionWarning) {
                    Button("common.cancel", role: .cancel) { propertyToDelete = nil }
                    Button("property.delete.anyway", role: .destructive) { showingPropertyDeleteAlert = true }
                } message: {
                    Text(String.localizedStringWithFormat(
                        NSLocalizedString("property.delete.active_message", comment: ""),
                        activeInspectionWarningCount
                    ))
                }
                .alert("property.delete.title", isPresented: $showingPropertyDeleteAlert) {
                    TextField("property.delete.confirm_placeholder", text: $deleteConfirmationText)
                    Button("common.cancel", role: .cancel) {
                        propertyToDelete = nil
                        deleteConfirmationText = ""
                    }
                    Button("common.delete", role: .destructive) {
                        if let property = propertyToDelete, deleteConfirmationText == "DELETE" {
                            HapticManager.shared.impact(style: .medium)
                            if let index = viewModel.properties.firstIndex(where: { $0.id == property.id }) {
                                viewModel.deleteProperties(at: IndexSet(integer: index))
                            }
                            HapticManager.shared.notification(type: .success)
                        }
                        propertyToDelete = nil
                        deleteConfirmationText = ""
                    }
                    .disabled(deleteConfirmationText != "DELETE")
                } message: {
                    Text(String.localizedStringWithFormat(
                        NSLocalizedString("property.delete.message", comment: ""),
                        propertyToDelete?.name ?? String(localized: "property.this_property")
                    ))
                }
                .sheet(isPresented: $viewModel.showingAddProperty) {
                    AddPropertySheet {
                        Task { await viewModel.fetchProperties(showLoadingState: false) }
                    }
                }
                .sheet(isPresented: $viewModel.showingPaywall) {
                    PremiumPaywallView()
                }
                .sheet(item: $editingProperty) { property in
                    EditPropertySheet(propertyId: property.id) {
                        Task { await viewModel.fetchProperties(showLoadingState: false) }
                    }
                }
            }
        }


    
    private func initiateDelete(for property: PropertyModel) {
        propertyToDelete = property
        deleteConfirmationText = ""
        Task {
            let count = await viewModel.activeInspectionCount(for: property.id)
            if count > 0 {
                activeInspectionWarningCount = count
                showingActiveInspectionWarning = true
            } else {
                showingPropertyDeleteAlert = true
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func applyLargeNavigationTitleIfSupported() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
#else
        self
#endif
    }

    @ViewBuilder
    func applyPropertyListStyle() -> some View {
#if os(macOS)
        self.listStyle(.inset(alternatesRowBackgrounds: false))
#else
        self
#endif
    }
}

struct PropertyRow: View {
    let property: PropertyModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(property.name)
                .lineLimit(1)

            Text(property.address_line1 ?? String(localized: "property.no_address"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Text(property.property_type)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
