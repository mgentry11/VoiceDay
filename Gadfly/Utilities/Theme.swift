import SwiftUI
import UIKit

struct Theme {
    static let background = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "000000") : UIColor(hex: "F2F2F7") // Pure Black vs System Grouped Background
    })
    
    static let secondary = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "2D3436") : UIColor(hex: "FFFFFF") // Slate Gray vs White
    })
    
    static let accent = Color(hex: "FFBF00")     // Electric Amber (Kept consistent)
    
    static let text = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ? .white : .black
    })
    
    static let subtext = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "B2BEC3") : UIColor(hex: "636E72")
    })
    
    // Semantic aliases
    static let success = Color(hex: "2ecc71")
    static let warning = Color(hex: "e67e22")
    static let error = Color(hex: "e74c3c")
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

extension Color {
    static let themeBackground = Theme.background
    static let themeSecondary = Theme.secondary
    static let themeAccent = Theme.accent
    static let themeText = Theme.text
    static let themeSubtext = Theme.subtext
    
    static let themeSuccess = Theme.success
    static let themeWarning = Theme.warning
    static let themeError = Theme.error
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
