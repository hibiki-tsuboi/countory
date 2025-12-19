import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID
    var name: String
    var quantity: Int
    var createdAt: Date
    var notes: String?
    
    // Relationship to Category
    var category: Category?

    init(name: String, quantity: Int, createdAt: Date = .now, notes: String? = nil, category: Category? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.createdAt = createdAt
        self.notes = notes
        self.category = category
    }
}