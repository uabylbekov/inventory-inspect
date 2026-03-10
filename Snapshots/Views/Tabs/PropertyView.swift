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
            Group {
                if !viewModel.isLoading && viewModel.properties.isEmpty {
                    ScrollView {
                        ContentUnavailableView(
                            "property.empty.title",
                            systemImage: "building.2",
                            description: Text("property.empty.subtitle")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 96)
                    }
                    .refreshable {
                        await viewModel.fetchProperties(showLoadingState: false)
                    }
                } else {
                    List {
                        Section("property.your_properties") {
                            if viewModel.isLoading && viewModel.properties.isEmpty {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                            } else {
                                ForEach(viewModel.properties) { property in
                                    NavigationLink {
                                        PropertyDetailView(property: property)
                                    } label: {
                                        PropertyRow(property: property)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            initiateDelete(for: property)
                                        } label: {
                                            Label("common.delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            editingProperty = property
                                        } label: {
                                            Label("common.edit", systemImage: "pencil")
                                        }
                                        .tint(.accentColor)
                                    }
                                    .contextMenu {
                                        Button { editingProperty = property } label: { Label("common.edit", systemImage: "pencil") }
                                        Button(role: .destructive) { initiateDelete(for: property) } label: { Label("common.delete", systemImage: "trash") }
                                    }
                                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await viewModel.fetchProperties(showLoadingState: false)
                    }
                }
            }
            .navigationTitle("property.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        guard !viewModel.isResolvingAddPropertyAccess else { return }
                        HapticManager.shared.impact(style: .light)
                        if viewModel.canAddProperty() {
                            viewModel.showingAddProperty = true
                        } else {
                            viewModel.showingPaywall = true
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
                    await viewModel.fetchProperties()
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

struct PropertyRow: View {
    let property: PropertyModel
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PropertyUI.color(for: property.property_type).opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: PropertyUI.icon(for: property.property_type))
                    .foregroundColor(PropertyUI.color(for: property.property_type))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(property.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(property.address_line1 ?? String(localized: "property.no_address"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 10) {
                    Label("\(property.bedrooms_count)", systemImage: "bed.double")
                    Label("\(property.bathrooms_count, specifier: "%.1f")", systemImage: "shower")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
