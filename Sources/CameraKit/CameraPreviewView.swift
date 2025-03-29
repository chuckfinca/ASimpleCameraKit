import SwiftUI
import AVFoundation

/// A SwiftUI wrapper around AVCaptureVideoPreviewLayer for displaying camera input
public struct CameraPreviewView: UIViewRepresentable {
    /// The capture session to display
    public let session: AVCaptureSession
    
    /// The current device orientation
    @Binding public var orientation: UIDeviceOrientation
    
    /// Creates a new camera preview view
    /// - Parameters:
    ///   - session: The AVCaptureSession to display
    ///   - orientation: Binding to the current device orientation
    public init(session: AVCaptureSession, orientation: Binding<UIDeviceOrientation>) {
        self.session = session
        self._orientation = orientation
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
        previewLayer.connection?.videoOrientation = orientation.toAVCaptureVideoOrientation()
        
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
        
        // Update orientation
        if previewLayer.connection?.isVideoOrientationSupported == true {
            previewLayer.connection?.videoOrientation = orientation.toAVCaptureVideoOrientation()
        }
        
        CATransaction.commit()
    }
}