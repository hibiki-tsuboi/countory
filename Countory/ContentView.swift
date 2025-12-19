//
//  ContentView.swift
//  Countory
//
//  Created by Hibiki Tsuboi on 2025/12/15.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    enum EditSheetItem: Identifiable {
        case new
        case edit(Item)
        
        var id: String {
            switch self {
            case .new:
                return "new"
            case .edit(let item):
                return item.id.storeIdentifier ?? UUID().uuidString
            }
        }
    }
    
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
    
    @State private var sheetItem: EditSheetItem?
    @State private var searchText = ""
    
    @State private var displayedItems: [Item] = []
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                pantryBackgroundColor.ignoresSafeArea()
                
                List {
                    if displayedItems.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "アイテムがありません" : "検索結果がありません",
                            systemImage: "shippingbox.fill",
                            description: Text(searchText.isEmpty ? "右上の「+」ボタンから最初のアイテムを追加してください。" : "")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(displayedItems) { item in
                            Button(action: {
                                sheetItem = .edit(item)
                            }) {
                                HStack(alignment: .center, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(item.name)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(pantryAccentColor)
                                        
                                        if let notes = item.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.subheadline)
                                                .foregroundColor(pantryAccentColor.opacity(0.8))
                                                .lineLimit(2)
                                                .padding(.top, 2)
                                        }
                                        
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

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            sheetItem = .new
                        }) {
                            Image(systemName: "plus")
                                .font(.title.weight(.semibold))
                                .padding()
                                .background(pantryAccentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4, x: 0, y: 4)
                        }
                        .padding()
                    }
                }
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
                                if let categoryName = filterCategoryName {
                                    Text(categoryName)
                                } else {
                                    Image(systemName: "tag.fill")
                                }
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(pantryAccentColor)
                        }                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            currentSort = (currentSort == .byDate) ? .byQuantity : .byDate
                        }
                    }) {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(item: $sheetItem) { sheetItem in
                switch sheetItem {
                case .new:
                    ItemEditView(item: nil)
                case .edit(let item):
                    ItemEditView(item: item)
                }
            }
            .searchable(text: $searchText, prompt: "アイテムを検索")
            .onAppear {
                applySortingAndFiltering()
            }
            .onChange(of: items) { oldItems, newItems in
                // アイテムの数が変わった（追加・削除）場合は、リスト全体を再計算
                if oldItems.count != newItems.count {
                    applySortingAndFiltering()
                    return
                }

                // アイテムの数が同じ（プロパティ編集）の場合
                if currentSort == .byQuantity {
                    // 順序を維持しつつ、データだけ更新する
                    let newItemsDict = Dictionary(uniqueKeysWithValues: newItems.map { ($0.id, $0) })
                    var updatedList: [Item] = []
                    for item in displayedItems {
                        if let updatedItem = newItemsDict[item.id] {
                            // フィルタリング条件もここでチェック
                            var passesFilter = true
                            if !searchText.isEmpty && !updatedItem.name.localizedStandardContains(searchText) {
                                passesFilter = false
                            }
                            if let categoryName = filterCategoryName, updatedItem.category?.name != categoryName {
                                passesFilter = false
                            }
                            
                            if passesFilter {
                                updatedList.append(updatedItem)
                            }
                        }
                    }
                    displayedItems = updatedList
                } else {
                    // .byDate の場合は、リスト全体を再計算（更新されたものが上に来る）
                    applySortingAndFiltering()
                }
            }
            .onChange(of: currentSort) {
                applySortingAndFiltering()
            }
            .onChange(of: searchText) {
                applySortingAndFiltering()
            }
            .onChange(of: filterCategoryName) {
                applySortingAndFiltering()
            }
            .tint(pantryAccentColor)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            let itemsToDelete = offsets.map { displayedItems[$0] }
            for item in itemsToDelete {
                modelContext.delete(item)
            }
        }
    }
    
    private func applySortingAndFiltering() {
        var tempItems = items
        
        // Filtering
        if !searchText.isEmpty {
            tempItems = tempItems.filter { $0.name.localizedStandardContains(searchText) }
        }
        if let categoryName = filterCategoryName {
            tempItems = tempItems.filter { $0.category?.name == categoryName }
        }
        
        // Sorting
        switch currentSort {
        case .byDate:
            tempItems.sort { $0.createdAt > $1.createdAt }
        case .byQuantity:
            tempItems.sort {
                if $0.quantity == $1.quantity {
                    return $0.createdAt > $1.createdAt
                }
                return $0.quantity < $1.quantity
            }
        }
        
        displayedItems = tempItems
    }
}

struct ItemEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.name) private var categories: [Category]
    
    let item: Item?
    
    @State private var name: String
    @State private var quantity: Int
    @State private var notes: String
    @State private var selectedCategoryName: String?

    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""
    
    private var navigationTitle: String {
        item == nil ? "新規アイテム" : "アイテムを編集"
    }
    
    // Color palette to match ContentView
    private let pantryBackgroundColor = Color(red: 0.93, green: 0.89, blue: 0.84)
    private let pantryRowColor = Color(red: 0.98, green: 0.96, blue: 0.92) // Light creamy beige
    private let pantryAccentColor = Color(red: 0.36, green: 0.2, blue: 0.12)
    
    init(item: Item?) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _quantity = State(initialValue: item?.quantity ?? 1)
        _notes = State(initialValue: item?.notes ?? "")
        _selectedCategoryName = State(initialValue: item?.category?.name)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                pantryBackgroundColor.ignoresSafeArea()
                
                Form {
                                        Section {
                                            TextField("アイテム名", text: $name)
                                            VStack { // VStackで囲む
                                                HStack {
                                                    Spacer()
                                                    Text("\(quantity)")
                                                    Stepper("数量", value: $quantity, in: 0...999)
                                                        .labelsHidden()
                                                }
                                                
                                                ZStack(alignment: .topLeading) {
                                                    if notes.isEmpty {
                                                        Text("備考")
                                                            .foregroundColor(Color(uiColor: .placeholderText))
                                                            .padding(.horizontal, 4)
                                                            .padding(.vertical, 8)
                                                    }
                                                    TextEditor(text: $notes)
                                                        .frame(minHeight: 100)
                                                        .scrollContentBackground(.hidden)
                                                }
                                                .background(pantryRowColor)
                                                .cornerRadius(12)
                                            } // VStack終わり
                                        }                    .listRowBackground(pantryBackgroundColor.opacity(0.8))
                    
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
            let notesToSave = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            
            if let item {
                item.name = name
                item.quantity = quantity
                item.notes = notesToSave
                item.category = selectedCategory
            } else {
                let newItem = Item(name: name, quantity: quantity, notes: notesToSave, category: selectedCategory)
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
