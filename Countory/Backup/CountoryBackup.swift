import Foundation

nonisolated struct CountoryBackup: Codable, Sendable {
    struct ItemRecord: Codable, Sendable {
        let id: UUID
        let name: String
        let quantity: Int
        let createdAt: Date
        let notes: String?
        let categoryName: String?
    }

    enum BackupError: LocalizedError {
        case invalidFile
        case unsupportedVersion
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "有効なカウントリーのバックアップではありません。ファイルを確認してください。"
            case .unsupportedVersion:
                return "このバックアップの形式には対応していません。アプリを更新してからお試しください。"
            case .fileTooLarge:
                return "バックアップファイルのサイズが上限の20 MBを超えています。"
            }
        }
    }

    static let maximumFileSize = 20 * 1024 * 1024

    let format: String
    let version: Int
    let exportedAt: Date
    let categories: [String]
    let items: [ItemRecord]

    init(categories: [String], items: [ItemRecord], exportedAt: Date = .now) {
        self.format = "countory-backup"
        self.version = 1
        self.exportedAt = exportedAt
        self.categories = categories
        self.items = items
    }

    func validate() throws {
        guard format == "countory-backup" else { throw BackupError.invalidFile }
        guard version == 1 else { throw BackupError.unsupportedVersion }

        let categoryNames = Set(categories)
        guard exportedAt.timeIntervalSince1970.isFinite,
              categoryNames.count == categories.count,
              categories.allSatisfy({ !$0.isEmpty }),
              Set(items.map(\.id)).count == items.count else {
            throw BackupError.invalidFile
        }

        for item in items {
            guard !item.name.isEmpty,
                  (0...999).contains(item.quantity),
                  item.createdAt.timeIntervalSince1970.isFinite else {
                throw BackupError.invalidFile
            }
            if let categoryName = item.categoryName, !categoryNames.contains(categoryName) {
                throw BackupError.invalidFile
            }
        }
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumFileSize else { throw BackupError.fileTooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumFileSize else { throw BackupError.fileTooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let backup: Self
        do {
            backup = try decoder.decode(Self.self, from: data)
        } catch {
            throw BackupError.invalidFile
        }
        try backup.validate()
        return backup
    }

    static func read(from url: URL) throws -> Self {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }

        var coordinationError: NSError?
        var result: Result<Self, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { fileURL in
            result = Result {
                let handle = try FileHandle(forReadingFrom: fileURL)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: maximumFileSize + 1) ?? Data()
                return try decode(data)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw BackupError.invalidFile }
        return try result.get()
    }
}
