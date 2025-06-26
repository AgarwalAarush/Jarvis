import SwiftUI

extension Color {
    // MARK: - Initialization
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    init(rgb: (red: Double, green: Double, blue: Double), alpha: Double = 1.0) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: alpha)
    }
    
    init(hsv: (hue: Double, saturation: Double, value: Double), alpha: Double = 1.0) {
        self.init(.sRGB, red: hsv.hue, green: hsv.saturation, blue: hsv.value, opacity: alpha)
    }
    
    // MARK: - Color Components
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        NSColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
    
    var red: Double {
        return components.red
    }
    
    var green: Double {
        return components.green
    }
    
    var blue: Double {
        return components.blue
    }
    
    var alpha: Double {
        return components.alpha
    }
    
    // MARK: - Color Formats
    var hex: String {
        let components = self.components
        let r = Int(components.red * 255)
        let g = Int(components.green * 255)
        let b = Int(components.blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    var hexWithAlpha: String {
        let components = self.components
        let r = Int(components.red * 255)
        let g = Int(components.green * 255)
        let b = Int(components.blue * 255)
        let a = Int(components.alpha * 255)
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
    
    var rgb: (red: Double, green: Double, blue: Double) {
        let components = self.components
        return (components.red, components.green, components.blue)
    }
    
    var rgba: (red: Double, green: Double, blue: Double, alpha: Double) {
        return self.components
    }
    
    // MARK: - Color Manipulation
    func lighter(by percentage: Double = 0.1) -> Color {
        let components = self.components
        let factor = 1.0 + percentage
        return Color(
            red: min(components.red * factor, 1.0),
            green: min(components.green * factor, 1.0),
            blue: min(components.blue * factor, 1.0),
            alpha: components.alpha
        )
    }
    
    func darker(by percentage: Double = 0.1) -> Color {
        let components = self.components
        let factor = 1.0 - percentage
        return Color(
            red: max(components.red * factor, 0.0),
            green: max(components.green * factor, 0.0),
            blue: max(components.blue * factor, 0.0),
            alpha: components.alpha
        )
    }
    
    func withAlpha(_ alpha: Double) -> Color {
        let components = self.components
        return Color(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: alpha
        )
    }
    
    func withBrightness(_ brightness: Double) -> Color {
        let components = self.components
        let factor = brightness / (components.red * 0.299 + components.green * 0.587 + components.blue * 0.114)
        return Color(
            red: min(components.red * factor, 1.0),
            green: min(components.green * factor, 1.0),
            blue: min(components.blue * factor, 1.0),
            alpha: components.alpha
        )
    }
    
    func withSaturation(_ saturation: Double) -> Color {
        let components = self.components
        let gray = components.red * 0.299 + components.green * 0.587 + components.blue * 0.114
        return Color(
            red: gray + (components.red - gray) * saturation,
            green: gray + (components.green - gray) * saturation,
            blue: gray + (components.blue - gray) * saturation,
            alpha: components.alpha
        )
    }
    
    // MARK: - Color Blending
    func blend(with color: Color, ratio: Double) -> Color {
        let components1 = self.components
        let components2 = color.components
        
        return Color(
            red: components1.red * (1 - ratio) + components2.red * ratio,
            green: components1.green * (1 - ratio) + components2.green * ratio,
            blue: components1.blue * (1 - ratio) + components2.blue * ratio,
            alpha: components1.alpha * (1 - ratio) + components2.alpha * ratio
        )
    }
    
    func multiply(by color: Color) -> Color {
        let components1 = self.components
        let components2 = color.components
        
        return Color(
            red: components1.red * components2.red,
            green: components1.green * components2.green,
            blue: components1.blue * components2.blue,
            alpha: components1.alpha * components2.alpha
        )
    }
    
    func screen(with color: Color) -> Color {
        let components1 = self.components
        let components2 = color.components
        
        return Color(
            red: 1 - (1 - components1.red) * (1 - components2.red),
            green: 1 - (1 - components1.green) * (1 - components2.green),
            blue: 1 - (1 - components1.blue) * (1 - components2.blue),
            alpha: components1.alpha
        )
    }
    
    // MARK: - Color Analysis
    var brightness: Double {
        let components = self.components
        return components.red * 0.299 + components.green * 0.587 + components.blue * 0.114
    }
    
    var luminance: Double {
        let components = self.components
        return 0.2126 * components.red + 0.7152 * components.green + 0.0722 * components.blue
    }
    
    var isLight: Bool {
        return brightness > 0.5
    }
    
    var isDark: Bool {
        return brightness <= 0.5
    }
    
    var isTransparent: Bool {
        return alpha < 0.1
    }
    
    var isOpaque: Bool {
        return alpha > 0.9
    }
    
    // MARK: - Contrast
    func contrastRatio(with color: Color) -> Double {
        let luminance1 = self.luminance
        let luminance2 = color.luminance
        
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    func isAccessibleOn(_ backgroundColor: Color) -> Bool {
        return contrastRatio(with: backgroundColor) >= 4.5
    }
    
    func accessibleTextColor(on backgroundColor: Color) -> Color {
        return isAccessibleOn(backgroundColor) ? self : (isLight ? .black : .white)
    }
    
    // MARK: - Color Schemes
    var complementary: Color {
        let components = self.components
        return Color(
            red: 1.0 - components.red,
            green: 1.0 - components.green,
            blue: 1.0 - components.blue,
            alpha: components.alpha
        )
    }
    
    var triadic: [Color] {
        let components = self.components
        let hsv = rgbToHsv(components.red, components.green, components.blue)
        let hue1 = (hsv.hue + 120).truncatingRemainder(dividingBy: 360)
        let hue2 = (hsv.hue + 240).truncatingRemainder(dividingBy: 360)
        
        let rgb1 = hsvToRgb(hue1, hsv.saturation, hsv.value)
        let rgb2 = hsvToRgb(hue2, hsv.saturation, hsv.value)
        
        return [
            Color(rgb: rgb1, alpha: components.alpha),
            Color(rgb: rgb2, alpha: components.alpha)
        ]
    }
    
    var analogous: [Color] {
        let components = self.components
        let hsv = rgbToHsv(components.red, components.green, components.blue)
        let hue1 = (hsv.hue - 30).truncatingRemainder(dividingBy: 360)
        let hue2 = (hsv.hue + 30).truncatingRemainder(dividingBy: 360)
        
        let rgb1 = hsvToRgb(hue1, hsv.saturation, hsv.value)
        let rgb2 = hsvToRgb(hue2, hsv.saturation, hsv.value)
        
        return [
            Color(rgb: rgb1, alpha: components.alpha),
            Color(rgb: rgb2, alpha: components.alpha)
        ]
    }
    
    // MARK: - Predefined Colors
    static let systemBackground = Color(NSColor.controlBackgroundColor)
    static let systemText = Color(NSColor.labelColor)
    static let systemSecondaryText = Color(NSColor.secondaryLabelColor)
    static let systemTertiaryText = Color(NSColor.tertiaryLabelColor)
    static let systemSeparator = Color(NSColor.separatorColor)
    static let systemAccent = Color(NSColor.controlAccentColor)
    
    // MARK: - Semantic Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
    
    // MARK: - Material Colors
    static let primary = Color.blue
    static let secondary = Color.gray
    static let tertiary = Color.gray.opacity(0.6)
    static let deepPurple = Color(hex: "#673AB7")
    static let lightBlue = Color(hex: "#03A9F4")
    static let lightGreen = Color(hex: "#8BC34A")
    static let lime = Color(hex: "#CDDC39")
    static let amber = Color(hex: "#FFC107")
    static let deepOrange = Color(hex: "#FF5722")
    static let brown = Color(hex: "#795548")
    static let grey = Color(hex: "#9E9E9E")
    static let blueGrey = Color(hex: "#607D8B")
    
    // MARK: - Utility Colors
    static let transparent = Color.clear
    static var random: Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
    
    // MARK: - Color Palettes
    static let materialColors: [Color] = [
        .red, .pink, .purple, .deepPurple, .indigo, .blue, .lightBlue, .cyan,
        .teal, .green, .lightGreen, .lime, .yellow, .amber, .orange, .deepOrange,
        .brown, .grey, .blueGrey
    ]
    
    static let flatColors: [Color] = [
        Color(hex: "#E74C3C"), Color(hex: "#E67E22"), Color(hex: "#F1C40F"),
        Color(hex: "#2ECC71"), Color(hex: "#27AE60"), Color(hex: "#3498DB"),
        Color(hex: "#2980B9"), Color(hex: "#9B59B6"), Color(hex: "#8E44AD"),
        Color(hex: "#34495E"), Color(hex: "#2C3E50"), Color(hex: "#95A5A6")
    ]
    
    // MARK: - Helper Functions
    private func rgbToHsv(_ r: Double, _ g: Double, _ b: Double) -> (hue: Double, saturation: Double, value: Double) {
        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        let diff = max - min
        
        let hue: Double
        if diff == 0 {
            hue = 0
        } else if max == r {
            hue = (60 * ((g - b) / diff) + 360).truncatingRemainder(dividingBy: 360)
        } else if max == g {
            hue = (60 * ((b - r) / diff) + 120).truncatingRemainder(dividingBy: 360)
        } else {
            hue = (60 * ((r - g) / diff) + 240).truncatingRemainder(dividingBy: 360)
        }
        
        let saturation = max == 0 ? 0 : diff / max
        let value = max
        
        return (hue, saturation, value)
    }
    
    private func hsvToRgb(_ h: Double, _ s: Double, _ v: Double) -> (red: Double, green: Double, blue: Double) {
        let c = v * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        
        let (r, g, b): (Double, Double, Double)
        switch Int(h) / 60 {
        case 0:
            (r, g, b) = (c, x, 0)
        case 1:
            (r, g, b) = (x, c, 0)
        case 2:
            (r, g, b) = (0, c, x)
        case 3:
            (r, g, b) = (0, x, c)
        case 4:
            (r, g, b) = (x, 0, c)
        default:
            (r, g, b) = (c, 0, x)
        }
        
        return (r + m, g + m, b + m)
    }
}

// MARK: - Color Extensions for Specific Use Cases
extension Color {
    // MARK: - Status Colors
    static let statusOnline = Color.green
    static let statusOffline = Color.gray
    static let statusAway = Color.orange
    static let statusBusy = Color.red
    
    // MARK: - Priority Colors
    static let priorityLow = Color.green
    static let priorityMedium = Color.orange
    static let priorityHigh = Color.red
    static let priorityCritical = Color.purple
    
    // MARK: - Theme Colors
    static let themePrimary = Color.blue
    static let themeSecondary = Color.gray
    static let themeBackground = Color.systemBackground
    static let themeSurface = Color.white
    static let themeError = Color.red
    static let themeSuccess = Color.green
    static let themeWarning = Color.orange
    static let themeInfo = Color.blue
    
    // MARK: - UI Element Colors
    static let buttonPrimary = Color.blue
    static let buttonSecondary = Color.gray
    static let buttonSuccess = Color.green
    static let buttonWarning = Color.orange
    static let buttonDanger = Color.red
    
    static let borderLight = Color.gray.opacity(0.3)
    static let borderMedium = Color.gray.opacity(0.5)
    static let borderDark = Color.gray.opacity(0.7)
    
    static let shadowLight = Color.black.opacity(0.1)
    static let shadowMedium = Color.black.opacity(0.2)
    static let shadowDark = Color.black.opacity(0.3)
}

// MARK: - Color Gradients
extension Color {
    static func gradient(colors: [Color], startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) -> LinearGradient {
        return LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }
    
    static func radialGradient(colors: [Color], center: UnitPoint = .center, startRadius: CGFloat = 0, endRadius: CGFloat = 1) -> RadialGradient {
        return RadialGradient(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius)
    }
    
    static func angularGradient(colors: [Color], center: UnitPoint = .center, startAngle: Angle = .zero, endAngle: Angle = .degrees(360)) -> AngularGradient {
        return AngularGradient(colors: colors, center: center, startAngle: startAngle, endAngle: endAngle)
    }
}

// MARK: - Color Presets
extension Color {
    // MARK: - Brand Colors
    static let appleBlue = Color(hex: "#007AFF")
    static let appleGreen = Color(hex: "#34C759")
    static let appleOrange = Color(hex: "#FF9500")
    static let appleRed = Color(hex: "#FF3B30")
    static let applePink = Color(hex: "#FF2D92")
    static let applePurple = Color(hex: "#AF52DE")
    static let appleYellow = Color(hex: "#FFCC00")
    static let appleGray = Color(hex: "#8E8E93")
    
    // MARK: - Social Media Colors
    static let facebook = Color(hex: "#1877F2")
    static let twitter = Color(hex: "#1DA1F2")
    static let instagram = Color(hex: "#E4405F")
    static let linkedin = Color(hex: "#0A66C2")
    static let youtube = Color(hex: "#FF0000")
    static let github = Color(hex: "#181717")
    static let discord = Color(hex: "#5865F2")
    static let slack = Color(hex: "#4A154B")
} 