import SwiftUI
import SwiftData
import Supabase

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    @State private var editingProperty: PropertyModel?
    @State private var propertyToDelete: PropertyModel?
    @State private var showingPropertyDeleteAlert = false
    @State private var showingActiveInspectionWarning = false
    @State private var activeInspectionWarningCount = 0
    @State private var deleteConfirmationText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Header
                    headerSection
                    
                    // MARK: - Properties List
                    if viewModel.isLoading && viewModel.properties.isEmpty {
                        loadingState
                    } else if let error = viewModel.errorMessage {
                        errorState(error)
                    } else if viewModel.properties.isEmpty {
                        emptyState
                    } else {
                        propertiesSection
                    }
                    
                    Spacer().frame(height: 32)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Properties")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        viewModel.showingAddProperty = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .symbolRenderingMode(.hierarchical)
                            Text("Add Property")
                        }
                    }
                }
            }
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
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        Text("\(viewModel.properties.count) \(viewModel.properties.count == 1 ? "Property" : "Properties") Managed")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal)
    }
    
    private var propertiesSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.properties) { property in
                NavigationLink {
                    PropertyDetailView(property: property)
                } label: {
                    PropertyCard(property: property)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { editingProperty = property } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { initiateDelete(for: property) } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .padding(.horizontal)
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
    
    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func errorState(_ error: String) -> some View {
        ContentUnavailableView("Sync Error", systemImage: "wifi.exclamationmark", description: Text(error))
    }
    
    private var emptyState: some View {
        ContentUnavailableView("No Properties", systemImage: "house.fill", description: Text("Add your first property to start tracking inventory."))
            .padding(.top, 40)
    }
}

// MARK: - Refined Property Card

struct PropertyCard: View {
    let property: PropertyModel
    
    private var typeIcon: String {
        switch property.property_type.lowercased() {
        case "apartment": return "building.2.fill"
        case "house": return "house.fill"
        case "condo": return "building.fill"
        case "townhouse": return "house.and.flag.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    private var typeColor: Color {
        switch property.property_type.lowercased() {
        case "apartment": return .blue
        case "house": return .green
        case "condo": return .purple
        case "townhouse": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Placeholder - Consistent with Dashboard & Inventory
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(typeColor.opacity(0.12))
                    .frame(width: 60, height: 60)
                
                Image(systemName: typeIcon)
                    .font(.title3)
                    .foregroundColor(typeColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(property.name)
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label {
                        Text("\(property.bedrooms_count)")
                    } icon: {
                        Image(systemName: "bed.double.fill")
                    }
                    
                    Text("•")
                    
                    Label {
                        Text("\(property.bathrooms_count, specifier: "%.1f")")
                    } icon: {
                        Image(systemName: "shower.fill")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
                
                if let address = property.address_line1, !address.isEmpty {
                    Text(address)
                        .font(.footnote)
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(14)
        .contentShape(Rectangle())
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
