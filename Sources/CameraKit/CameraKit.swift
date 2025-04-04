import SwiftUI

/// Main entry point for CameraKit functionality
public enum CameraKit {
    /// Creates a configured camera view with orientation guide and capture button
    /// - Parameters:
    ///   - onImageCaptured: Callback for when an image is captured and normalized
    ///   - onError: Optional callback for errors
    ///   - captureButtonSize: Size of the capture button
    ///   - orientationGuideSize: Size of the orientation guide
    ///   - overlayContent: Optional custom overlay content
    /// - Returns: A fully configured camera view
    public static func createCameraView<Content: View>(
        onImageCaptured: @escaping (UIImage) -> Void,
        onError: ((Error) -> Void)? = nil,
        captureButtonSize: CGFloat = 70,
        orientationGuideSize: CGFloat = 50,
        overlayContent: (() -> Content)? = nil
    ) -> CameraView<Content> {
        return CameraView(
            onImageCaptured: onImageCaptured,
            onError: onError,
            captureButtonSize: captureButtonSize,
            overlayContent: overlayContent
        )
    }
    
    /// Creates a standalone orientation manager for use across views
    /// - Returns: A new orientation manager
    public static func createOrientationManager() -> OrientationManager {
        return OrientationManager()
    }
    
    /// Creates an orientation guide view
    /// - Parameters:
    ///   - orientationManager: Optional orientation manager to use
    ///   - size: Size of the guide
    ///   - color: Color of the guide
    /// - Returns: An orientation guide view
    public static func createOrientationGuide(
        orientationManager: OrientationManager? = nil,
        size: CGFloat = 50,
        color: Color = .white
    ) -> OrientationGuideView {
        return OrientationGuideView.ceilingIndicator(
            orientationManager: orientationManager,
            size: size,
            color: color
        )
    }
    
    /// Creates a shared camera service instance
    /// - Returns: A new camera service
    public static func createCameraService() -> CameraServiceProtocol {
        return CameraService()
    }
    
    /// Normalizes an image's orientation
    /// - Parameter image: The image to normalize
    /// - Returns: A normalized copy of the image, or nil if normalization fails
    public static func normalizeImage(_ image: UIImage) -> UIImage? {
        return ImageOrientationService.shared.normalizeImage(image)
    }
}
