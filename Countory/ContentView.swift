//
//  ContentView.swift
//  Countory
//
//  Created by Hibiki Tsuboi on 2025/12/15.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    
    @State private var isShowingAddItemSheet = false

    var body: some View {
        NavigationView {
            List {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Items Yet",
                        systemImage: "shippingbox.fill",
                        description: Text("Tap the + button to add your first item.")
                    )
                } else {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                Text("Last updated: \(item.createdAt, format: .relative(presentation: .named))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack {
                                Stepper(value: Binding(
                                    get: { item.quantity },
                                    set: { newQuantity in
                                        item.quantity = newQuantity
                                        // Optional: Add auto-save logic here if needed,
                                        // or rely on SwiftData's automatic saving.
                                    }
                                ), in: 0...999) {
                                    Text("\(item.quantity)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .padding(.horizontal)
                                        .foregroundColor(item.quantity <= 2 ? .red : .primary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Countory")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddItemSheet = true
                    }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $isShowingAddItemSheet) {
                AddItemSheet()
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

struct AddItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var quantity: Int = 1
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...999)
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addItem()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func addItem() {
        withAnimation {
            let newItem = Item(name: name, quantity: quantity) // Changed from StockItem
            modelContext.insert(newItem)
        }
    }
}


#Preview {
    // Setting up a sample container for the preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Item.self, configurations: config) // Changed from StockItem
    
    // Add sample data
    let sampleItems = [
        Item(name: "Toilet Paper", quantity: 3), // Changed from StockItem
        Item(name: "Shampoo", quantity: 1),      // Changed from StockItem
        Item(name: "Milk", quantity: 0)          // Changed from StockItem
    ]
    sampleItems.forEach { container.mainContext.insert($0) }
    
    return ContentView()
        .modelContainer(container)
}