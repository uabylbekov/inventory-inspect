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
                // MARK: - Properties Section
                Section("Your Properties") {
                    if viewModel.isLoading && viewModel.properties.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if viewModel.properties.isEmpty {
                        EmptyView()
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
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingProperty = property
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.accentColor)
                            }
                            .contextMenu {
                                Button { editingProperty = property } label: { Label("Edit", systemImage: "pencil") }
                                Button(role: .destructive) { initiateDelete(for: property) } label: { Label("Delete", systemImage: "trash") }
                            }
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        }
                    }
                }
                
                // MARK: - Add Section
                Section {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        viewModel.showingAddProperty = true
                    }) {
                        Label("Add Property", systemImage: "plus.circle.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Properties")
            .navigationBarTitleDisplayMode(.large)
                .refreshable {
                    await viewModel.fetchProperties()
                }
                .task {
                    await viewModel.fetchProperties()
                }
                .alert("Active Inspections Found", isPresented: $showingActiveInspectionWarning) {
                    Button("Cancel", role: .cancel) { propertyToDelete = nil }
                    Button("Delete Anyway", role: .destructive) { showingPropertyDeleteAlert = true }
                } message: {
                    Text("\(activeInspectionWarningCount) active inspection(s) are still in progress for this property. Deleting will remove them permanently.")
                }
                .alert("Delete Property?", isPresented: $showingPropertyDeleteAlert) {
                    TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                    Button("Cancel", role: .cancel) {
                        propertyToDelete = nil
                        deleteConfirmationText = ""
                    }
                    Button("Delete", role: .destructive) {
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
                    Text("This is a permanent action and will remove '\(propertyToDelete?.name ?? "this property")' and all its rooms and items.")
                }
                .sheet(isPresented: $viewModel.showingAddProperty, onDismiss: {
                    Task { await viewModel.fetchProperties() }
                }) {
                    AddPropertySheet()
                }
                .sheet(item: $editingProperty, onDismiss: {
                    Task { await viewModel.fetchProperties() }
                }) { property in
                    EditPropertySheet(propertyId: property.id)
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
                
                Text(property.address_line1 ?? "No address provided")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
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
