import Foundation
import SwiftUI

enum SeedFactory {

    // ✅ SF Symbol -> PNG Data (demo foto üretmek için)
    static func symbolPNGData(systemName: String, pointSize: CGFloat = 240) -> Data? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        let image = UIImage(systemName: systemName, withConfiguration: config)

        guard let uiImage = image else { return nil }

        // Beyaz arka planlı render
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600))
        let rendered = renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 600))

            let rect = CGRect(x: 0, y: 0, width: 600, height: 600)
            let inset = rect.insetBy(dx: 140, dy: 140)
            uiImage.withTintColor(.label, renderingMode: .alwaysOriginal)
                .draw(in: inset)
        }

        return rendered.pngData()
    }
}
