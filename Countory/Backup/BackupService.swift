import Foundation
import SwiftData

@MainActor
enum BackupService {
    struct ImportSummary {
        let addedItems: Int
        let skippedItems: Int
        let addedCategories: Int
    }

    static func export(from context: ModelContext) throws -> CountoryBackup {
        try context.save()
        let categories = try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)]))
        let items = try context.fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.createdAt)]))
        let backup = CountoryBackup(
            categories: categories.map(\.name),
            items: items.map { item in
                CountoryBackup.ItemRecord(
                    id: item.id,
                    name: item.name,
                    quantity: item.quantity,
                    createdAt: item.createdAt,
                    notes: item.notes,
                    categoryName: item.category?.name
                )
            }
        )
        try backup.validate()
        return backup
    }

    static func preview(_ backup: CountoryBackup, in context: ModelContext) throws -> ImportSummary {
        try backup.validate()
        let itemIDs = Set(try context.fetch(FetchDescriptor<Item>()).map(\.id))
        let categoryNames = Set(try context.fetch(FetchDescriptor<Category>()).map(\.name))
        let addedItems = backup.items.filter { !itemIDs.contains($0.id) }.count
        return ImportSummary(
            addedItems: addedItems,
            skippedItems: backup.items.count - addedItems,
            addedCategories: backup.categories.filter { !categoryNames.contains($0) }.count
        )
    }

    @discardableResult
    static func restore(_ backup: CountoryBackup, into context: ModelContext) throws -> ImportSummary {
        let summary = try preview(backup, in: context)
        // Preserve pending edits before starting a separately saved import.
        try context.save()
        let itemIDs = Set(try context.fetch(FetchDescriptor<Item>()).map(\.id))
        let categories = try context.fetch(FetchDescriptor<Category>())
        var categoriesByName = Dictionary(categories.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let wasAutosaveEnabled = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = wasAutosaveEnabled }

        do {
            for name in backup.categories where categoriesByName[name] == nil {
                let category = Category(name: name)
                context.insert(category)
                categoriesByName[name] = category
            }
            for record in backup.items where !itemIDs.contains(record.id) {
                let item = Item(
                    name: record.name,
                    quantity: record.quantity,
                    createdAt: record.createdAt,
                    notes: record.notes,
                    category: record.categoryName.flatMap { categoriesByName[$0] }
                )
                item.id = record.id
                context.insert(item)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return summary
    }
}
