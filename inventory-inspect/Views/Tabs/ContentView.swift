//
//  ContentView.swift
//  inventory-inspect
//
//  Created by Uluk Abylbekov on 3/2/26.
//

import SwiftUI
import SwiftData
import Supabase

struct ContentView: View {
    @State private var viewModel = ContentViewModel()

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.properties.isEmpty {
                    VStack {
                        ProgressView()
                            .padding()
                        Text("Loading properties...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("⚠️")
                            .font(.largeTitle)
                        Text("Failed to load")
                            .font(.headline)
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                        
                        Button("Try Again") {
                            Task { await viewModel.fetchProperties() }
                        }
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                } else if viewModel.properties.isEmpty {
                    VStack(spacing: 12) {
                        Text("🏡")
                            .font(.system(size: 48))
                        Text("No Properties")
                            .font(.headline)
                        Text("Tap + to add your first property.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.properties) { property in
                        NavigationLink(destination: PropertyDetailView(property: property)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(property.name)
                                    .font(.headline)
                                if let address = property.address_line1, !address.isEmpty {
                                    Text(address)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(property.property_type) in \(property.country)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: viewModel.deleteProperties)
                }
            }
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
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Property")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddProperty, onDismiss: {
                // Refresh list when the sheet dismisses (either added or cancelled)
                Task { await viewModel.fetchProperties() }
            }) {
                AddPropertySheet()
            }
        }
    }
}

#Preview {
    ContentView()
}
