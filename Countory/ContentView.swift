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
    
    var body: some View {
        NavigationView {
            List {
                Group {
                    if filteredAndSortedItems.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "アイテムがありません" : "検索結果がありません",
                            systemImage: "shippingbox.fill",
                            description: Text(searchText.isEmpty ? "右上の「+」ボタンから最初のアイテムを追加してください。" : "")
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
                                                .background(Color.accentColor.opacity(0.8))
                                                .cornerRadius(8)
                                        }
                                        Text("最終更新: \(item.createdAt, format: .relative(presentation: .named))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
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
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("在庫リスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Picker("カテゴリで絞り込み", selection: $filterCategoryName) {
                        Text("すべてのカテゴリ").tag(nil as String?)
                        ForEach(categories) { category in
                            Text(category.name).tag(category.name as String?)
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
        item == nil ? "新規アイテム" : "アイテムを編集"
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
                Section(header: Text("詳細")) {
                    TextField("アイテム名", text: $name)
                    Stepper("数量: \(quantity)", value: $quantity, in: 0...999)
                }
                
                Section(header: Text("カテゴリ")) {
                    Picker("カテゴリを選択", selection: $selectedCategory) {
                        Text("なし").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text(category.name).tag(category as Category?)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Button("新しいカテゴリを追加") {
                        isShowingAddCategoryAlert = true
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
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
        }
    }
    
    private func saveItem() {
        withAnimation {
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
