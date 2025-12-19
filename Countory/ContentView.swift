//
//  ContentView.swift
//  Countory
//
//  Created by Hibiki Tsuboi on 2025/12/15.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    // MARK: - Properties
    enum SortOption {
        case byDate, byQuantity
    }
    
    // Pantry-style color palette
    private let pantryBackgroundColor = Color(red: 0.93, green: 0.89, blue: 0.84) // Darker Beige
    private let pantryRowColor = Color(red: 0.98, green: 0.96, blue: 0.92) // Light creamy beige
    private let pantryAccentColor = Color(red: 0.36, green: 0.2, blue: 0.12)    // Dark Brown
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var currentSort: SortOption = .byDate
    @State private var filterCategoryName: String? = nil
    
    @State private var isShowingItemSheet = false
    @State private var itemToEdit: Item?
    @State private var searchText = ""
    
    private var filteredAndSortedItems: [Item] {
        var processedItems = items
        if !searchText.isEmpty {
            processedItems = processedItems.filter { $0.name.localizedStandardContains(searchText) }
        }
        
        if let categoryName = filterCategoryName {
            processedItems = processedItems.filter { $0.category?.name == categoryName }
        }
        
        switch currentSort {
        case .byDate:
            return processedItems
        case .byQuantity:
            return processedItems.sorted {
                if $0.quantity == $1.quantity {
                    return $0.createdAt > $1.createdAt
                }
                return $0.quantity < $1.quantity
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                pantryBackgroundColor.ignoresSafeArea()
                
                List {
                    if filteredAndSortedItems.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "アイテムがありません" : "検索結果がありません",
                            systemImage: "shippingbox.fill",
                            description: Text(searchText.isEmpty ? "右上の「+」ボタンから最初のアイテムを追加してください。" : "")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredAndSortedItems) { item in
                            Button(action: {
                                itemToEdit = item
                                isShowingItemSheet = true
                            }) {
                                HStack(alignment: .center, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(item.name)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(pantryAccentColor)
                                        
                                        if let categoryName = item.category?.name {
                                            Text(categoryName)
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(pantryAccentColor.opacity(0.8))
                                                .cornerRadius(8)
                                        }
                                        
                                        // Removed "最終更新" Text view
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(item.quantity)")
                                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                        .foregroundColor(item.quantity <= 2 ? .red.opacity(0.8) : pantryAccentColor)
                                        .padding(.horizontal)
                                }
                                .padding()
                                .background(pantryRowColor)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .background(pantryBackgroundColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker(selection: $filterCategoryName, label: EmptyView()) {
                            Text("すべてのカテゴリ").tag(nil as String?)
                            ForEach(categories) { category in
                                Text(category.name).tag(category.name as String?)
                            }
                        }
                    } label: {
                        HStack {
                            Text(filterCategoryName ?? "すべてのカテゴリ")
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(pantryAccentColor)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            withAnimation {
                                currentSort = (currentSort == .byDate) ? .byQuantity : .byDate
                            }
                        }) {
                            Image(systemName: currentSort == .byDate ? "calendar" : "arrow.up.arrow.down.circle")
                        }
                        
                        Button(action: {
                            itemToEdit = nil
                            isShowingItemSheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingItemSheet) {
                ItemEditView(item: itemToEdit)
            }
            .searchable(text: $searchText, prompt: "アイテムを検索")
            .tint(pantryAccentColor)
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
    @State private var selectedCategoryName: String?

    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""
    
    private var navigationTitle: String {
        item == nil ? "新規アイテム" : "アイテムを編集"
    }
    
    // Color palette to match ContentView
    private let pantryBackgroundColor = Color(red: 0.93, green: 0.89, blue: 0.84)
    private let pantryAccentColor = Color(red: 0.36, green: 0.2, blue: 0.12)
    
    init(item: Item?) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _quantity = State(initialValue: item?.quantity ?? 1)
        _selectedCategoryName = State(initialValue: item?.category?.name)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                pantryBackgroundColor.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("アイテム名", text: $name)
                        HStack {
                            Text("数量")
                            Spacer()
                            Text("\(quantity)")
                            Stepper("数量", value: $quantity, in: 0...999)
                                .labelsHidden()
                        }
                    }
                    .listRowBackground(pantryBackgroundColor.opacity(0.8))
                    
                    Section(header: Text("カテゴリ").foregroundColor(pantryAccentColor)) {
                        Picker(selection: $selectedCategoryName) { // No explicit label here, using Image below
                            Text("なし").tag(nil as String?)
                            ForEach(categories) { category in
                                Text(category.name).tag(category.name as String?)
                            }
                        } label: { // Custom label with icon
                            Image(systemName: "tag.fill")
                        }
                        .pickerStyle(.menu)
                        
                        Button(action: {
                            isShowingAddCategoryAlert = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("新規カテゴリ")
                            }
                        }
                    }
                    .listRowBackground(pantryBackgroundColor.opacity(0.8))
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill") // Icon for Cancel
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: {
                            saveItem()
                            dismiss()
                        }) {
                            Image(systemName: "checkmark")
                        }
                        .disabled(name.isEmpty)
                    }
                }
                .alert("新規カテゴリ", isPresented: $isShowingAddCategoryAlert) {
                    TextField("カテゴリ名", text: $newCategoryName)
                    Button("追加") {
                        addCategory()
                    }
                    Button("キャンセル", role: .cancel) { }
                } message: {
                    Text("新しいカテゴリの名前を入力してください。")
                }
                .tint(pantryAccentColor)
            }
        }
    }
    
    private func saveItem() {
        withAnimation {
            let selectedCategory = categories.first { $0.name == selectedCategoryName }
            
            if let item {
                item.name = name
                item.quantity = quantity
                item.category = selectedCategory
            } else {
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
        newCategoryName = ""
        
        DispatchQueue.main.async {
            selectedCategoryName = newCategory.name
        }
    }
}


struct ContentView_PreviewProvider: View {
    let container: ModelContainer
    
    init() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(for: Item.self, Category.self, configurations: config)
            
            let category1 = Category(name: "食品")
            let category2 = Category(name: "日用品")
            container.mainContext.insert(category1)
            container.mainContext.insert(category2)
            
            let sampleItems = [
                Item(name: "牛乳", quantity: 0, category: category1),
                Item(name: "トイレットペーパー", quantity: 3, category: category2),
                Item(name: "シャンプー", quantity: 1, category: category2)
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
