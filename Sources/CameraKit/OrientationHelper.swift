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
