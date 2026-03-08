import SwiftUI
import SwiftData
import Supabase

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    @State private var editingProperty: PropertyModel?
    @State private var propertyToDeleteOffsets: IndexSet?
    @State private var showingPropertyDeleteAlert = false
    @State private var showingActiveInspectionWarning = false
    @State private var activeInspectionWarningCount = 0
    @State private var deleteConfirmationText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.properties.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await viewModel.fetchProperties() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if viewModel.properties.isEmpty {
                    ContentUnavailableView {
                        Label("No Properties", systemImage: "house")
                    } description: {
                        Text("Add your first property to start tracking inventory.")
                    } actions: {
                        Button {
                            viewModel.showingAddProperty = true
                        } label: {
                            Label("Add Property", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(viewModel.properties) { property in
                            NavigationLink(destination: PropertyDetailView(property: property)) {
                                PropertyRow(property: property)
                            }
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingProperty = property
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete { offsets in
                            propertyToDeleteOffsets = offsets
                            deleteConfirmationText = ""
                            Task {
                                let count = await viewModel.activeInspectionCount(at: offsets)
                                if count > 0 {
                                    activeInspectionWarningCount = count
                                    showingActiveInspectionWarning = true
                                } else {
                                    showingPropertyDeleteAlert = true
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    // Warning: active inspections exist
                    .alert("Active Inspections Found", isPresented: $showingActiveInspectionWarning) {
                        Button("Cancel", role: .cancel) {
                            propertyToDeleteOffsets = nil
                        }
                        Button("Delete Anyway", role: .destructive) {
                            showingPropertyDeleteAlert = true
                        }
                    } message: {
                        Text("\(activeInspectionWarningCount) active inspection(s) are still in progress for this property. Deleting will remove them permanently.")
                    }
                    // Main delete confirmation
                    .alert("Delete Property?", isPresented: $showingPropertyDeleteAlert) {
                        TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                        Button("Cancel", role: .cancel) {
                            propertyToDeleteOffsets = nil
                            deleteConfirmationText = ""
                        }
                        Button("Delete", role: .destructive) {
                            if let offsets = propertyToDeleteOffsets, deleteConfirmationText == "DELETE" {
                                HapticManager.shared.impact(style: .medium)
                                viewModel.deleteProperties(at: offsets)
                                HapticManager.shared.notification(type: .success)
                            }
                            propertyToDeleteOffsets = nil
                            deleteConfirmationText = ""
                        }
                        .disabled(deleteConfirmationText != "DELETE")
                    } message: {
                        Text("This is a permanent action and will remove this property and all its rooms and items. Type DELETE to confirm.")
                    }
                }
            }
            .animation(.default, value: viewModel.isLoading)
            .navigationTitle("Properties")
            .refreshable {
                await viewModel.fetchProperties()
            }
            .task {
                await viewModel.fetchProperties()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showingAddProperty = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add Property")
                        }
                    }
                }
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
}

// MARK: - Property Row

struct PropertyRow: View {
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
        HStack(spacing: 14) {
            // Icon
            Image(systemName: typeIcon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(typeColor.gradient)
                )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(property.name)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    if let address = property.address_line1, !address.isEmpty {
                        Text(address)
                            .lineLimit(1)
                    } else {
                        Text(property.country)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContentView()
}
