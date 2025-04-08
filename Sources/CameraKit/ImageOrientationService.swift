import UIKit
import AVFoundation

/// Service for handling image orientation
public class ImageOrientationService {
    
    // MARK: - Singleton Instance
    
    public static let shared = ImageOrientationService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Converts device orientation to AVCaptureVideoOrientation
    /// - Parameter deviceOrientation: The device orientation to convert
    /// - Returns: The corresponding AVCaptureVideoOrientation
    public func videoOrientationFrom(deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight // Reversed for back camera
        case .landscapeRight:
            return .landscapeLeft // Reversed for back camera
        case .faceUp, .faceDown, .unknown:
            return .portrait // Default to portrait
        @unknown default:
            return .portrait
        }
    }
    
    /// Converts UIInterfaceOrientation to AVCaptureVideoOrientation
    /// - Parameter interfaceOrientation: The interface orientation to convert
    /// - Returns: The corresponding AVCaptureVideoOrientation
    public func videoOrientationFrom(interfaceOrientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch interfaceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .unknown:
            return .portrait
        @unknown default:
            return .portrait
        }
    }
}
