//
//  View+RotatesWithDevice.swift
//  ContactCapture
//
//  Created by Charles Feinn on 7/12/25.
//

import SwiftUI
import ASimpleCameraKit

/// An enum to define the rotation behavior.
public enum RotationStyle {
    /// Rotates in discrete 90-degree steps.
    case discrete
    /// Rotates smoothly and continuously with the device.
    case continuous
}

// The ViewModifier that observes orientation and wraps the content in our rotatable container.
struct RotatesWithDevice: ViewModifier {
    @State private var currentAngle: Angle = .zero

    // A reference to the single source of truth for orientation.
    let orientationManager: OrientationManager
    // The rotation style to use.
    let style: RotationStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        // The container now receives the angle directly.
        let view = RotatableContainerView(content: { content }, angle: currentAngle)

        if style == .continuous {
            view.onReceive(orientationManager.$continuousAngleRadians) { newAngleInRadians in
                // The publisher sends a Double, so we convert it to an Angle.
                self.currentAngle = Angle(radians: newAngleInRadians)
            }
        } else {
            view.onReceive(orientationManager.$lastValidOrientation) { newOrientation in
                // The publisher sends a UIDeviceOrientation. We get the Angle from our helper.
                self.currentAngle = newOrientation.rotationAngle
            }
        }
    }
}

extension View {
    /// Applies a view modifier that rotates the view to match the physical device orientation,
    /// while the parent view remains locked in portrait.
    ///
    /// - Parameters:
    ///   - orientationManager: The app's central `OrientationManager`.
    ///   - style: The rotation behavior. Defaults to `.discrete` (90-degree steps).
    /// - Returns: A view that animates its rotation based on device orientation.
    public func rotatesWithDevice(orientationManager: OrientationManager, style: RotationStyle = .discrete) -> some View {
        self.modifier(RotatesWithDevice(orientationManager: orientationManager, style: style))
    }
}
