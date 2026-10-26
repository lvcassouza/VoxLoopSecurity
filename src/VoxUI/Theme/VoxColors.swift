import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Paleta oficial de tokens de cor do Vox conforme especificado em `docs/ui-visual-spec.md`.
/// Oferece suporte nativo automático aos modos claro e escuro.
public enum VoxColors {
    public static var canvas: Color {
        dynamicColor(light: "#F6F8F6", dark: "#101A1C")
    }

    public static var surface: Color {
        dynamicColor(light: "#FFFFFF", dark: "#182528")
    }

    public static var surfaceMuted: Color {
        dynamicColor(light: "#EDF2EF", dark: "#223236")
    }

    public static var ink: Color {
        dynamicColor(light: "#173238", dark: "#F2F7F4")
    }

    public static var inkSecondary: Color {
        dynamicColor(light: "#52656A", dark: "#B5C4C0")
    }

    public static var brand: Color {
        dynamicColor(light: "#087D70", dark: "#70D9BE")
    }

    public static var brandText: Color {
        dynamicColor(light: "#FFFFFF", dark: "#101A1C")
    }

    public static var brandPressed: Color {
        dynamicColor(light: "#06665C", dark: "#A3EBD7")
    }

    public static var brandSoft: Color {
        dynamicColor(light: "#DDF7EE", dark: "#193D38")
    }

    public static var border: Color {
        dynamicColor(light: "#D9E3DF", dark: "#34484A")
    }

    public static var success: Color {
        dynamicColor(light: "#176B50", dark: "#75D6A7")
    }

    public static var warning: Color {
        dynamicColor(light: "#8A5A00", dark: "#F1C56E")
    }

    public static var danger: Color {
        dynamicColor(light: "#B42318", dark: "#FF8C82")
    }

    // MARK: - Auxiliares de Adaptação Dinâmica

    private static func dynamicColor(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark)
                : NSColor(hex: light)
        })
        #else
        return Color(hex: light)
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#elseif canImport(AppKit)
extension NSColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
