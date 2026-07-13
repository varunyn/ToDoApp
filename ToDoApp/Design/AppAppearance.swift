//
//  AppAppearance.swift
//  ToDoApp
//

import SwiftUI
import UIKit

/// Shared visual constants so spacing, tint, and shapes stay consistent across screens.
enum AppAppearance {
    static let accent = Color(red: 0.8471, green: 0.3804, blue: 0.3725)
    static let taskBackground = adaptiveColor(
        light: UIColor(red: 0.985, green: 0.975, blue: 0.955, alpha: 1),
        dark: UIColor(red: 0.075, green: 0.075, blue: 0.07, alpha: 1)
    )
    static let taskSurface = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.76),
        dark: UIColor(white: 0.16, alpha: 0.86)
    )
    static let taskBorder = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.92),
        dark: UIColor.white.withAlphaComponent(0.16)
    )
    static let softHighlight = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.65),
        dark: UIColor.white.withAlphaComponent(0.10)
    )

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let gridSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let cardMinHeight: CGFloat = 120

    /// Minimum tap target per HIG (~44×44 pt).
    static let minimumTapTarget: CGFloat = 44
}
