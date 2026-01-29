import SwiftData
import Foundation

enum AppModelContainer {

    /// Model değiştikçe bunu arttır (eski store’u okumaya çalışmasın)
    private static let storeName = "DateApp_v5"   // 👈 v5 yapıldı

    static func make(inMemory: Bool = false) -> ModelContainer {

        let schema = Schema([
            Profile.self,
            ProfilePhoto.self,
            MediaItem.self,
            ProfileMedia.self,
            LikeEdge.self,
            Match.self,
            ChatThread.self,
            ChatMessage.self
        ])

        // ✅ Senin sürümde name: String? var (url yok)
        let config = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("❌ SwiftData ModelContainer init failed: \(error)")
        }
    }
}
