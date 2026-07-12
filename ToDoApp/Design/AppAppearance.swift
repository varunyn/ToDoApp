//
//  AppAppearance.swift
//  ToDoApp
//

import SwiftUI

/// Shared visual constants so spacing, tint, and shapes stay consistent across screens.
enum AppAppearance {
    static let accent = Color(red: 0.8471, green: 0.3804, blue: 0.3725)
    static let taskBackground = Color(red: 0.985, green: 0.975, blue: 0.955)
    static let taskSurface = Color.white.opacity(0.76)
    static let taskBorder = Color.white.opacity(0.92)

    static let gridSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let cardMinHeight: CGFloat = 120

    /// Minimum tap target per HIG (~44×44 pt).
    static let minimumTapTarget: CGFloat = 44
}
