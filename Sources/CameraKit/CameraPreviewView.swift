import SwiftUI
import AVFoundation

/// A SwiftUI wrapper around AVCaptureVideoPreviewLayer for displaying camera input
public struct CameraPreviewView: UIViewRepresentable {
    /// The capture session to display
    public let session: AVCaptureSession
    
    /// The current device orientation
    @Binding public var orientation: UIDeviceOrientation
    
    /// Whether to fix the preview orientation regardless of device rotation
    public let fixedOrientation: Bool
    
    /// The orientation to use when fixed mode is enabled
    public let fixedOrientationValue: AVCaptureVideoOrientation
    
    /// Creates a new camera preview view
    /// - Parameters:
    ///   - session: The AVCaptureSession to display
    ///   - orientation: Binding to the current device orientation
    ///   - fixedOrientation: Whether to keep orientation fixed regardless of device rotation
    ///   - fixedOrientationValue: The orientation to use when fixed (default: .portrait)
    public init(
        session: AVCaptureSession, 
        orientation: Binding<UIDeviceOrientation>,
        fixedOrientation: Bool = false,
        fixedOrientationValue: AVCaptureVideoOrientation = .portrait
    ) {
        self.session = session
        self._orientation = orientation
        self.fixedOrientation = fixedOrientation
        self.fixedOrientationValue = fixedOrientationValue
    }
    
    /// Creates a coordinator to manage the preview layer
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Coordinator class for managing the preview layer
    public class Coordinator: NSObject {
        var parent: CameraPreviewView
        var previewLayer: AVCaptureVideoPreviewLayer?
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }
    }
    
    /// Creates the UIView for the camera preview
    public func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        // Set the initial orientation
        if previewLayer.connection?.isVideoOrientationSupported == true {
            if fixedOrientation {
                previewLayer.connection?.videoOrientation = fixedOrientationValue
            } else {
                previewLayer.connection?.videoOrientation = orientation.toAVCaptureVideoOrientation()
            }
        }
        
        // Store in coordinator for future updates
        context.coordinator.previewLayer = previewLayer
        
        // Important: Set initial frame before adding to view
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    /// Updates the UIView when properties change
    public func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = context.coordinator.previewLayer else { return }
        
        // Disable animations for frame updates
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Update frame to fill the entire view
        previewLayer.frame = uiView.bounds
        
        // Only update orientation if not fixed
        if !fixedOrientation, previewLayer.connection?.isVideoOrientationSupported == true {
            previewLayer.connection?.videoOrientation = orientation.toAVCaptureVideoOrientation()
        }
        
        CATransaction.commit()
    }
}