import UIKit
import AVFoundation

/// Service for handling image orientation and normalization
public class ImageOrientationService {
    
    // MARK: - Singleton Instance
    
    public static let shared = ImageOrientationService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Normalizes image orientation to `.up` (0)
    /// - Parameter image: The image to normalize
    /// - Returns: A normalized copy of the image with proper orientation
    public func normalizeImage(_ image: UIImage) -> UIImage? {
        // Check if already normalized
        if image.imageOrientation == .up { return image }
        
        // Determine new size based on orientation
        let newSize = (image.imageOrientation == .left || image.imageOrientation == .right) ?
            CGSize(width: image.size.height, height: image.size.width) : image.size
        
        // Create graphics context
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        // Apply transform based on orientation
        guard let cgImage = image.cgImage,
              let ctx = UIGraphicsGetCurrentContext() else { return nil }
        
        // Set up transformation
        let transform = getTransformForOrientation(image.imageOrientation, size: newSize)
        
        // Apply the transform
        ctx.concatenate(transform)
        
        // Draw the image
        let drawRect = getDrawRectForOrientation(image.imageOrientation, size: image.size)
        ctx.draw(cgImage, in: drawRect)
        
        // Get the new image
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Creates a normalized JPEG representation of an image
    /// - Parameters:
    ///   - image: The image to process
    ///   - compressionQuality: The JPEG compression quality (0-1)
    /// - Returns: JPEG data of the normalized image
    public func createNormalizedJPEGData(_ image: UIImage, compressionQuality: CGFloat = 0.9) -> Data? {
        guard let normalizedImage = normalizeImage(image) else { return nil }
        return normalizedImage.jpegData(compressionQuality: compressionQuality)
    }
    
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
    
    // MARK: - Private Methods
    
    private func getTransformForOrientation(_ orientation: UIImage.Orientation, size: CGSize) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        
        switch orientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2.0)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2.0)
        case .up, .upMirrored:
            break // No rotation needed
        @unknown default:
            break
        }
        
        // Handle mirroring
        switch orientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        return transform
    }
    
    private func getDrawRectForOrientation(_ orientation: UIImage.Orientation, size: CGSize) -> CGRect {
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGRect(x: 0, y: 0, width: size.height, height: size.width)
        default:
            return CGRect(x: 0, y: 0, width: size.width, height: size.height)
        }
    }
}

// MARK: - UIImage Extension

public extension UIImage {
    /// Returns a new image with the orientation normalized to `.up` (0)
    func normalizedImage() -> UIImage? {
        return ImageOrientationService.shared.normalizeImage(self)
    }
    
    /// Creates JPEG data from the normalized image
    /// - Parameter compressionQuality: The JPEG compression quality (0-1)
    /// - Returns: JPEG data of the normalized image
    func normalizedJPEGData(compressionQuality: CGFloat = 0.9) -> Data? {
        return ImageOrientationService.shared.createNormalizedJPEGData(self, compressionQuality: compressionQuality)
    }
}
