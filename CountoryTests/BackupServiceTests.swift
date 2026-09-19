import XCTest
import SwiftData
@testable import Countory

@MainActor
final class BackupServiceTests: XCTestCase {
    func testRoundTripPreservesEveryFieldAndUnusedCategories() throws {
        // Given
        let source = try makeContainer()
        let category = Category(name: "食品 🥛")
        source.mainContext.insert(category)
        source.mainContext.insert(Category(name: "未使用カテゴリ"))
        let date = Date(timeIntervalSince1970: 1_750_000_000.123)
        let original = Item(name: "牛乳", quantity: 0, createdAt: date, notes: "1行目\n2行目", category: category)
        source.mainContext.insert(original)
        source.mainContext.insert(Item(name: "カテゴリなし", quantity: 999))
        let destination = try makeContainer()

        // When
        let data = try BackupService.export(from: source.mainContext).encoded()
        let backup = try CountoryBackup.decode(data)
        let summary = try BackupService.restore(backup, into: destination.mainContext)

        // Then
        let restored = try destination.mainContext.fetch(FetchDescriptor<Item>())
        let milk = try XCTUnwrap(restored.first { $0.id == original.id })
        XCTAssertEqual(milk.name, original.name)
        XCTAssertEqual(milk.quantity, 0)
        XCTAssertEqual(milk.notes, "1行目\n2行目")
        XCTAssertEqual(milk.createdAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.000001)
        XCTAssertEqual(milk.category?.name, "食品 🥛")
        let uncategorized = try XCTUnwrap(restored.first { $0.name == "カテゴリなし" })
        XCTAssertNil(uncategorized.category)
        XCTAssertNil(uncategorized.notes)
        XCTAssertEqual(uncategorized.quantity, 999)
        XCTAssertEqual(summary.addedItems, 2)
        XCTAssertEqual(summary.addedCategories, 2)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<Countory.Category>()), 2)
    }

    func testRepeatedImportKeepsCurrentEditsAndDoesNotDuplicateRecords() throws {
        // Given
        let container = try makeContainer()
        let backup = makeBackup()
        try BackupService.restore(backup, into: container.mainContext)
        let item = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Item>()).first)
        item.name = "移行先で変更した名前"
        item.quantity = 12
        item.notes = "移行先のメモ"
        item.category = nil

        // When
        let summary = try BackupService.restore(backup, into: container.mainContext)

        // Then
        XCTAssertEqual(summary.addedItems, 0)
        XCTAssertEqual(summary.skippedItems, 1)
        XCTAssertEqual(summary.addedCategories, 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Item>()), 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Countory.Category>()), 1)
        XCTAssertEqual(item.name, "移行先で変更した名前")
        XCTAssertEqual(item.quantity, 12)
        XCTAssertEqual(item.notes, "移行先のメモ")
        XCTAssertNil(item.category)
    }

    func testImportReusesCategoryAndKeepsDistinctItemsWithTheSameName() throws {
        // Given
        let container = try makeContainer()
        let category = Category(name: "食品")
        container.mainContext.insert(category)
        let existing = Item(name: "牛乳", quantity: 8, category: category)
        container.mainContext.insert(existing)
        let backup = makeBackup()

        // When
        let summary = try BackupService.restore(backup, into: container.mainContext)

        // Then
        let items = try container.mainContext.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(existing.quantity, 8)
        XCTAssertEqual(summary.addedItems, 1)
        XCTAssertEqual(summary.addedCategories, 0)
        XCTAssertTrue(items.allSatisfy { $0.category?.persistentModelID == category.persistentModelID })
    }

    func testPreviewDoesNotWriteAnything() throws {
        // Given
        let container = try makeContainer()

        // When
        let summary = try BackupService.preview(makeBackup(), in: container.mainContext)

        // Then
        XCTAssertEqual(summary.addedItems, 1)
        XCTAssertEqual(summary.addedCategories, 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Item>()), 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Countory.Category>()), 0)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testInvalidBackupIsRejectedBeforeAnyChanges() throws {
        // Given
        let container = try makeContainer()
        let existing = Item(name: "既存商品", quantity: 5)
        container.mainContext.insert(existing)
        try container.mainContext.save()
        let valid = makeBackup().items[0]
        let invalid = CountoryBackup.ItemRecord(
            id: UUID(), name: "不正な商品", quantity: -1, createdAt: .now, notes: nil, categoryName: nil
        )
        let backup = CountoryBackup(categories: ["食品", "新規カテゴリ"], items: [valid, invalid])

        // When / Then
        XCTAssertThrowsError(try BackupService.restore(backup, into: container.mainContext))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Item>()), 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Countory.Category>()), 0)
        XCTAssertEqual(existing.quantity, 5)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testRejectsMalformedFilesAndUnsupportedVersions() throws {
        // Given
        let data = try makeBackup().encoded()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        // When / Then
        XCTAssertThrowsError(try CountoryBackup.decode(Data("not JSON".utf8)))
        for (key, value) in [("format", "another-app" as Any), ("version", 2 as Any)] {
            var invalid = object
            invalid[key] = value
            XCTAssertThrowsError(try CountoryBackup.decode(JSONSerialization.data(withJSONObject: invalid)))
        }
        var missingFields = object
        missingFields.removeValue(forKey: "items")
        XCTAssertThrowsError(try CountoryBackup.decode(JSONSerialization.data(withJSONObject: missingFields)))
    }

    func testRejectsDuplicateIDsCategoriesAndMissingCategoryReferences() throws {
        // Given
        let record = makeBackup().items[0]
        let backups = [
            CountoryBackup(categories: ["食品"], items: [record, record]),
            CountoryBackup(categories: ["食品", "食品"], items: [record]),
            CountoryBackup(categories: [], items: [record])
        ]

        // When / Then
        for backup in backups {
            XCTAssertThrowsError(try backup.validate())
        }
    }

    func testEmptyBackupLeavesExistingDataUntouched() throws {
        // Given
        let container = try makeContainer()
        container.mainContext.insert(Item(name: "既存商品", quantity: 1))
        let backup = CountoryBackup(categories: [], items: [])

        // When
        let decoded = try CountoryBackup.decode(backup.encoded())
        let summary = try BackupService.restore(decoded, into: container.mainContext)

        // Then
        XCTAssertEqual(summary.addedItems, 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Item>()), 1)
    }

    func testImportSurvivesReopeningPersistentStore() throws {
        // Given
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("test.store")
        let backup = makeBackup()

        // When
        try autoreleasepool {
            let container = try ModelContainer(
                for: Item.self, Category.self,
                configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            )
            try BackupService.restore(backup, into: container.mainContext)
        }

        // Then
        let reopened = try ModelContainer(
            for: Item.self, Category.self,
            configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        )
        let item = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Item>()).first)
        XCTAssertEqual(item.id, backup.items[0].id)
        XCTAssertEqual(item.category?.name, "食品")
        XCTAssertEqual(try BackupService.restore(backup, into: reopened.mainContext).skippedItems, 1)
    }

    func testReadsBackupFileAndRejectsOversizedInput() throws {
        // Given
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let backup = makeBackup()
        try backup.encoded().write(to: url)

        // When / Then
        XCTAssertEqual(try CountoryBackup.read(from: url).items[0].id, backup.items[0].id)
        try Data(repeating: 0, count: CountoryBackup.maximumFileSize + 1).write(to: url)
        XCTAssertThrowsError(try CountoryBackup.read(from: url))
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Item.self, Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func makeBackup() -> CountoryBackup {
        CountoryBackup(
            categories: ["食品"],
            items: [CountoryBackup.ItemRecord(
                id: UUID(), name: "牛乳", quantity: 2, createdAt: .now, notes: "メモ", categoryName: "食品"
            )]
        )
    }
}
