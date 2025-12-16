//
//  ContentView.swift
//  Countory
//
//  Created by Hibiki Tsuboi on 2025/12/15.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    enum SortOption {
        case byDate, byQuantity
    }
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var currentSort: SortOption = .byDate
    @State private var filterCategory: Category? = nil
    
    @State private var isShowingItemSheet = false
    @State private var itemToEdit: Item?
    
    private var filteredAndSortedItems: [Item] {
        // Filter first
        let filteredItems: [Item]
        if let category = filterCategory {
            filteredItems = items.filter { $0.category == category }
        } else {
            filteredItems = items
        }
        
        // Then sort
        switch currentSort {
        case .byDate:
            return filteredItems
        case .byQuantity:
            return filteredItems.sorted {
                if $0.quantity == $1.quantity {
                    return $0.createdAt > $1.createdAt
                }
                return $0.quantity < $1.quantity
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Group {
                    if filteredAndSortedItems.isEmpty {
                        ContentUnavailableView(
                            "No Items",
                            systemImage: "shippingbox.fill",
                            description: Text(filterCategory == nil ? "Tap the + button to add your first item." : "No items in this category.")
                        )
                    } else {
                        ForEach(filteredAndSortedItems) { item in
                            Button(action: {
                                itemToEdit = item
                                isShowingItemSheet = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.headline)
                                        if let categoryName = item.category?.name {
                                            Text(categoryName)
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.accentColor)
                                                .cornerRadius(8)
                                        }
                                        Text("Last updated: \(item.createdAt, format: .relative(presentation: .named))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // This HStack is for the stepper, separate from the main content tappable area
                                    HStack {
                                        Stepper(value: Binding(
                                            get: { item.quantity },
                                            set: { newQuantity in
                                                item.quantity = newQuantity
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
                            .buttonStyle(.plain) // Make the button look like a normal list row
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("Countory")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Picker("Filter by Category", selection: $filterCategory) {
                        Text("All Categories").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text(category.name).tag(category as Category?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            withAnimation {
                                currentSort = (currentSort == .byDate) ? .byQuantity : .byDate
                            }
                        }) {
                            Label("Sort", systemImage: currentSort == .byDate ? "calendar" : "number")
                        }
                        
                        Button(action: {
                            itemToEdit = nil
                            isShowingItemSheet = true
                        }) {
                            Label("Add Item", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingItemSheet) {
                ItemEditView(item: itemToEdit)
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            let itemsToDelete = offsets.map { filteredAndSortedItems[$0] }
            for item in itemsToDelete {
                modelContext.delete(item)
            }
        }
    }
}

struct ItemEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.name) private var categories: [Category]
    
    let item: Item?
    
    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var selectedCategory: Category?

    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""
    
    private var navigationTitle: String {
        item == nil ? "New Item" : "Edit Item"
    }
    
    init(item: Item?) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _quantity = State(initialValue: item?.quantity ?? 1)
        _selectedCategory = State(initialValue: item?.category)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...999)
                }
                
                Section(header: Text("Category")) {
                    Picker("Select Category", selection: $selectedCategory) {
                        Text("None").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text(category.name).tag(category as Category?)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Button("Add New Category") {
                        isShowingAddCategoryAlert = true
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("New Category", isPresented: $isShowingAddCategoryAlert) {
                TextField("Category Name", text: $newCategoryName)
                Button("Add") {
                    addCategory()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter a name for the new category.")
            }
        }
    }
    
    private func saveItem() {
        withAnimation {
            if let item {
                // Edit existing item
                item.name = name
                item.quantity = quantity
                item.category = selectedCategory
            } else {
                // Create new item
                let newItem = Item(name: name, quantity: quantity, category: selectedCategory)
                modelContext.insert(newItem)
            }
        }
    }
    
    private func addCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        let newCategory = Category(name: trimmedName)
        modelContext.insert(newCategory)
        
        selectedCategory = newCategory
        newCategoryName = ""
    }
}


struct ContentView_PreviewProvider: View {
    let container: ModelContainer
    
    init() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(for: Item.self, Category.self, configurations: config)
            
            let category1 = Category(name: "Food")
            let category2 = Category(name: "Household")
            container.mainContext.insert(category1)
            container.mainContext.insert(category2)
            
            let sampleItems = [
                Item(name: "Milk", quantity: 0, category: category1),
                Item(name: "Toilet Paper", quantity: 3, category: category2),
                Item(name: "Shampoo", quantity: 1, category: category2)
            ]
            sampleItems.forEach { container.mainContext.insert($0) }
        } catch {
            fatalError("Failed to create ModelContainer for preview: \(error)")
        }
    }
    
    var body: some View {
        ContentView()
            .modelContainer(container)
    }
}

#Preview {
    ContentView_PreviewProvider()
}
