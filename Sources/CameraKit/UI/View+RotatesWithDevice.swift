//
//  View+RotatesWithDevice.swift
//  ContactCapture
//
//  Created by Charles Feinn on 7/12/25.
//

import SwiftUI
import ASimpleCameraKit

// The ViewModifier that observes orientation and wraps the content in our rotatable container.
struct RotatesWithDevice: ViewModifier {
    // The modifier holds the state for the current orientation.
    @State private var currentOrientation: UIDeviceOrientation = .portrait
    // A reference to the single source of truth for orientation.
    let orientationManager: OrientationManager

    func body(content: Content) -> some View {
        RotatableContainerView(content: { content }, orientation: currentOrientation)
        // Listen for updates from the manager and update the local state.
        .onReceive(orientationManager.$lastValidOrientation) { newOrientation in
            self.currentOrientation = newOrientation
        }
    }
}

extension View {
    /// Applies a view modifier that rotates the view to match the physical device orientation,
    /// while the parent view remains locked in portrait.
    ///
    /// - Parameter orientationManager: The app's central `OrientationManager`.
    /// - Returns: A view that animates its rotation based on device orientation.
    public func rotatesWithDevice(orientationManager: OrientationManager) -> some View {
        self.modifier(RotatesWithDevice(orientationManager: orientationManager))
    }
}
