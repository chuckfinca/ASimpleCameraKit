import SwiftUI
import Combine

// MARK: - View Extensions for CameraKit

public extension View {
    /// Adds an orientation guide to the view
    /// - Parameters:
    ///   - orientationManager: The orientation manager to use
    ///   - size: Size of the orientation guide
    ///   - color: Color of the orientation guide
    ///   - position: Position of the orientation guide (default: top)
    /// - Returns: View with the orientation guide added
    func withOrientationGuide(
        orientationManager: OrientationManager? = nil,
        size: CGFloat = 50, 
        color: Color = .white,
        position: OrientationGuidePosition = .top
    ) -> some View {
        let guide = OrientationGuideView.ceilingIndicator(
            orientationManager: orientationManager,
            size: size,
            color: color
        )
        
        return self.overlay(alignment: position.alignment) {
            guide.padding(position.padding)
        }
    }
    
    /// Applies automatic image orientation correction
    /// - Parameter orientationManager: Optional orientation manager to use
    /// - Returns: View that maintains proper orientation regardless of device rotation
    func withOrientationCorrection(orientationManager: OrientationManager? = nil) -> some View {
        let manager = orientationManager ?? OrientationManager()
        
        return self.modifier(OrientationCorrectionModifier(orientationManager: manager))
    }
}

// MARK: - Orientation Guide Position

/// Represents positions where an orientation guide can be placed
public enum OrientationGuidePosition {
    case top
    case bottom
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    
    var alignment: Alignment {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        case .topLeading:
            return .topLeading
        case .topTrailing:
            return .topTrailing
        case .bottomLeading:
            return .bottomLeading
        case .bottomTrailing:
            return .bottomTrailing
        }
    }
    
    var padding: EdgeInsets {
        switch self {
        case .top:
            return EdgeInsets(top: 50, leading: 0, bottom: 0, trailing: 0)
        case .bottom:
            return EdgeInsets(top: 0, leading: 0, bottom: 30, trailing: 0)
        case .topLeading:
            return EdgeInsets(top: 50, leading: 20, bottom: 0, trailing: 0)
        case .topTrailing:
            return EdgeInsets(top: 50, leading: 0, bottom: 0, trailing: 20)
        case .bottomLeading:
            return EdgeInsets(top: 0, leading: 20, bottom: 30, trailing: 0)
        case .bottomTrailing:
            return EdgeInsets(top: 0, leading: 0, bottom: 30, trailing: 20)
        }
    }
}

// MARK: - Orientation Correction Modifier

/// View modifier that applies automatic orientation correction
public struct OrientationCorrectionModifier: ViewModifier {
    @ObservedObject var orientationManager: OrientationManager
    
    public init(orientationManager: OrientationManager) {
        self.orientationManager = orientationManager
    }
    
    public func body(content: Content) -> some View {
        content
            .rotationEffect(orientationManager.currentOrientation.counterRotationAngle)
            // Adjust the frame if needed for landscape/portrait
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - CameraKit Integration Modifiers

public extension View {
    /// Adds standard camera UI elements (orientation guide, capture button)
    /// - Parameters:
    ///   - cameraService: The camera service to use
    ///   - onCapture: Action to perform when the capture button is tapped
    /// - Returns: View with camera UI elements added
    func withCameraUI(
        cameraService: CameraServiceProtocol,
        onCapture: @escaping () -> Void
    ) -> some View {
        return self.overlay {
            // Orientation guide at the top
            VStack {
                cameraService.createOrientationGuide(size: 40, color: Color.red)
                    .padding(.top, 50)
                
                Spacer()
                
                // Capture button at the bottom
                CaptureButton(action: onCapture)
                    .padding(.bottom, 30)
            }
        }
    }
    
    /// Adds normalized image capture capability to a view
    /// - Parameters:
    ///   - cameraService: The camera service to use
    ///   - isCapturing: Binding to track capture state
    ///   - onImageCaptured: Action to perform with the captured and normalized image
    /// - Returns: View with normalized image capture capability
    func withNormalizedCapture(
        cameraService: CameraServiceProtocol,
        isCapturing: Binding<Bool>,
        onImageCaptured: @escaping (UIImage) -> Void
    ) -> some View {
        return self.onChange(of: cameraService.capturedImage.value) { newImage in
            if let image = newImage {
                // Normalize the image
                if let normalizedImage = ImageOrientationService.shared.normalizeImage(image) {
                    onImageCaptured(normalizedImage)
                } else {
                    onImageCaptured(image) // Fallback to original if normalization fails
                }
                
                // Reset the captured image
                cameraService.capturedImage.send(nil)
                isCapturing.wrappedValue = false
            }
        }
    }
}
