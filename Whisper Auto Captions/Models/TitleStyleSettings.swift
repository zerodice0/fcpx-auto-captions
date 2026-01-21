import Foundation
import SwiftUI

// MARK: - Codable Color
/// A Codable wrapper for Color/NSColor
struct CodableColor: Codable, Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1.0) {
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }

    init(color: NSColor) {
        let converted = color.usingColorSpace(.sRGB) ?? color
        self.red = converted.redComponent
        self.green = converted.greenComponent
        self.blue = converted.blueComponent
        self.alpha = converted.alphaComponent
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Convert to FCPXML color string format: "r g b a"
    func toFCPXMLString() -> String {
        return "\(red) \(green) \(blue) \(alpha)"
    }

    // MARK: - Preset Colors
    static let white = CodableColor(r: 1, g: 1, b: 1, a: 1)
    static let black = CodableColor(r: 0, g: 0, b: 0, a: 1)
    static let blackShadow = CodableColor(r: 0, g: 0, b: 0, a: 0.75)
}

// MARK: - Position Preset
enum PositionPreset: String, CaseIterable, Codable, Identifiable {
    case bottomCenter = "Bottom Center"
    case topCenter = "Top Center"
    case center = "Center"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    case custom = "Custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottomCenter: return String(localized: "Bottom Center", comment: "Position preset")
        case .topCenter: return String(localized: "Top Center", comment: "Position preset")
        case .center: return String(localized: "Center", comment: "Position preset")
        case .bottomLeft: return String(localized: "Bottom Left", comment: "Position preset")
        case .bottomRight: return String(localized: "Bottom Right", comment: "Position preset")
        case .custom: return String(localized: "Custom", comment: "Position preset")
        }
    }

    /// Get default position for this preset based on resolution
    func position(for height: Int) -> (x: CGFloat, y: CGFloat) {
        // Y position is calculated relative to video height
        // In FCPXML, 0 is center, negative is down, positive is up
        let bottomY = CGFloat(-height / 2 + 75)  // 75 pixels from bottom edge
        let topY = CGFloat(height / 2 - 75)      // 75 pixels from top edge
        let leftX = CGFloat(-300)
        let rightX = CGFloat(300)

        switch self {
        case .bottomCenter: return (0, bottomY)
        case .topCenter: return (0, topY)
        case .center: return (0, 0)
        case .bottomLeft: return (leftX, bottomY)
        case .bottomRight: return (rightX, bottomY)
        case .custom: return (0, bottomY)  // Default to bottom center for custom
        }
    }
}

// MARK: - Font Weight
enum TitleFontWeight: String, CaseIterable, Codable, Identifiable {
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .regular: return String(localized: "Regular", comment: "Font weight")
        case .medium: return String(localized: "Medium", comment: "Font weight")
        case .semibold: return String(localized: "Semibold", comment: "Font weight")
        case .bold: return String(localized: "Bold", comment: "Font weight")
        }
    }
}

// MARK: - Text Alignment
enum TitleTextAlignment: String, CaseIterable, Codable, Identifiable {
    case left = "Left"
    case center = "Center"
    case right = "Right"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return String(localized: "Left", comment: "Text alignment")
        case .center: return String(localized: "Center", comment: "Text alignment")
        case .right: return String(localized: "Right", comment: "Text alignment")
        }
    }

    /// FCPXML alignment param value
    var fcpxmlParamValue: String {
        switch self {
        case .left: return "0 (Left)"
        case .center: return "1 (Center)"
        case .right: return "2 (Right)"
        }
    }

    /// FCPXML text-style alignment value
    var fcpxmlStyleValue: String {
        rawValue.lowercased()
    }
}

// MARK: - Title Style Settings
struct TitleStyleSettings: Codable, Equatable {
    // MARK: - Position
    var positionPreset: PositionPreset = .bottomCenter
    var positionX: CGFloat = 0
    var positionY: CGFloat = -465

    // MARK: - Font
    var fontName: String = "Helvetica"
    var fontSize: CGFloat = 45
    var fontWeight: TitleFontWeight = .regular

    // MARK: - Text Color
    var textColor: CodableColor = .white

    // MARK: - Stroke (Outline)
    var strokeEnabled: Bool = false
    var strokeColor: CodableColor = .black
    var strokeWidth: CGFloat = 2

    // MARK: - Shadow
    var shadowColor: CodableColor = .blackShadow
    var shadowOffsetX: CGFloat = 4
    var shadowOffsetY: CGFloat = 315

    // MARK: - Alignment
    var alignment: TitleTextAlignment = .center

    // MARK: - Default Instance
    static let `default` = TitleStyleSettings()

    // MARK: - Methods

    /// Update position based on preset and resolution
    mutating func updatePositionFromPreset(height: Int) {
        guard positionPreset != .custom else { return }
        let position = positionPreset.position(for: height)
        positionX = position.x
        positionY = position.y
    }

    /// Get position string for FCPXML
    var positionString: String {
        return "\(Int(positionX)) \(Int(positionY))"
    }

    /// Get shadow offset string for FCPXML
    var shadowOffsetString: String {
        return "\(Int(shadowOffsetX)) \(Int(shadowOffsetY))"
    }
}
