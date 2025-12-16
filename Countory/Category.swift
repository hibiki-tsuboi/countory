import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var name: String
    
    init(name: String) {
        self.name = name
    }
}
