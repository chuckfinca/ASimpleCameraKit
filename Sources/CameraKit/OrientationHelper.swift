import UIKit
import AVFoundation
import SwiftUI

/// Helper extensions for device orientation handling
public extension UIDeviceOrientation {
//    /// Returns whether the orientation is landscape (left or right)
//    var isLandscape: Bool {
//        return self == .landscapeLeft || self == .landscapeRight
//    }
    
    /// Returns whether the orientation is portrait (normal or upside down)
    var isPortrait: Bool {
        return self == .portrait || self == .portraitUpsideDown
    }
    
    /// Converts a UIDeviceOrientation to the corresponding AVCaptureVideoOrientation
    /// - Returns: The matching AVCaptureVideoOrientation
    func toAVCaptureVideoOrientation() -> AVCaptureVideoOrientation {
        switch self {
        case .landscapeLeft:
            return .landscapeRight // Reversed because camera is on back of device
        case .landscapeRight:
            return .landscapeLeft // Reversed because camera is on back of device
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .faceUp, .faceDown, .unknown:
            return .portrait // Default to portrait for these non-standard orientations
        default:
            return .portrait
        }
    }
}

/// A SwiftUI view that displays an orientation indicator arrow
public struct OrientationArrow: View {
    public var orientation: UIDeviceOrientation
    public var size: CGFloat = 50
    public var color: Color = .white
    
    public init(orientation: UIDeviceOrientation, size: CGFloat = 50, color: Color = .white) {
        self.orientation = orientation
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: size))
            .foregroundColor(color)
            .rotationEffect(rotationAngle)
    }
    
    private var rotationAngle: Angle {
        switch orientation {
        case .portraitUpsideDown:
            return .degrees(180)
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        default:
            return .degrees(0)
        }
    }
}
