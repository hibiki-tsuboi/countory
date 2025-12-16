import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID
    var name: String
    var quantity: Int
    var createdAt: Date

    init(name: String, quantity: Int, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.createdAt = createdAt
    }
}