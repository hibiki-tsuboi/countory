import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID
    var name: String
    var quantity: Int
    var createdAt: Date
    
    // Relationship to Category
    var category: Category?

    init(name: String, quantity: Int, createdAt: Date = .now, category: Category? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.createdAt = createdAt
        self.category = category
    }
}