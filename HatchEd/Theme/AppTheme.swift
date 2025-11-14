//
//  AppTheme.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI

extension Color {
    // MARK: - Light Mode Colors
    static let hatchEdWhite = Color(white: 1.0)
    static let hatchEdDarkGray = Color(white: 0.15) // Almost black
    static let hatchEdCoral = Color(red: 1.0, green: 0.35, blue: 0.35) // Vibrant coral/red
    static let hatchEdLightBlue = Color(red: 0.2, green: 0.6, blue: 1.0) // Vibrant blue
    static let hatchEdLightGreen = Color(red: 0.2, green: 0.85, blue: 0.4) // Vibrant green
    static let hatchEdLightOrange = Color(red: 1.0, green: 0.65, blue: 0.2) // Vibrant orange
    
    // MARK: - Dark Mode Colors
    static let hatchEdDarkGrayDark = Color(white: 0.3) // Dark gray for dark mode
    static let hatchEdBlack = Color(white: 0.0) // Black
    static let hatchEdWhiteDark = Color(white: 1.0) // White (same in both modes)
    static let hatchEdCoralDark = Color(red: 1.0, green: 0.5, blue: 0.5) // Coral/light red (slightly brighter for dark mode)
    static let hatchEdLightBlueDark = Color(red: 0.5, green: 0.8, blue: 1.0) // Light blue (slightly brighter for dark mode)
    
    // MARK: - Adaptive Colors (automatically switch based on color scheme)
    static var hatchEdBackground: Color {
        Color(light: hatchEdWhite, dark: hatchEdBlack)
    }
    
    static var hatchEdSecondaryBackground: Color {
        Color(light: Color(red: 0.98, green: 0.98, blue: 1.0), dark: hatchEdDarkGrayDark)
    }
    
    static var hatchEdCardBackground: Color {
        Color(light: hatchEdWhite, dark: Color(white: 0.15))
    }
    
    static var hatchEdAccentBackground: Color {
        Color(light: Color(red: 0.9, green: 0.95, blue: 1.0), dark: Color(red: 0.1, green: 0.15, blue: 0.25))
    }
    
    static var hatchEdText: Color {
        Color(light: hatchEdDarkGray, dark: hatchEdWhiteDark)
    }
    
    static var hatchEdSecondaryText: Color {
        Color(light: Color(white: 0.5), dark: Color(white: 0.7))
    }
    
    static var hatchEdAccent: Color {
        Color(light: hatchEdLightBlue, dark: hatchEdLightBlueDark)
    }
    
    static var hatchEdCoralAccent: Color {
        Color(light: hatchEdCoral, dark: hatchEdCoralDark)
    }
    
    static var hatchEdSuccess: Color {
        Color(light: hatchEdLightGreen, dark: hatchEdLightGreen)
    }
    
    static var hatchEdWarning: Color {
        Color(light: hatchEdLightOrange, dark: hatchEdLightOrange)
    }
    
    // Helper initializer for adaptive colors
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Theme Environment
struct AppTheme {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
}

