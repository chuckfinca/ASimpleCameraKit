import SwiftUI
import AVFoundation
import Combine

// A robust camera preview that properly handles orientation and layout changes
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewView {
        print("CameraPreview - makeUIView called")
        
        // Create our custom UIView subclass that manages its own AVCaptureVideoPreviewLayer
        let view = CameraPreviewView(session: session)
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        print("CameraPreview - updateUIView called. View bounds: \(uiView.bounds)")
        
        // This will be called when the SwiftUI view updates, including during orientation changes
        // Just ensure our view has the latest session
        uiView.session = session
        
        // Force layout update - this is critical
        DispatchQueue.main.async {
            uiView.updateVideoOrientation()
            uiView.layoutIfNeeded()
        }
    }
}

// Custom UIView subclass that properly manages the AVCaptureVideoPreviewLayer
class CameraPreviewView: UIView {
    var session: AVCaptureSession
    private var orientationManager = OrientationManager()
    
    // We can directly access the AVCaptureVideoPreviewLayer through the layer property
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    init(session: AVCaptureSession) {
        self.session = session
        super.init(frame: .zero)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = .black
        videoPreviewLayer.session = session
        videoPreviewLayer.videoGravity = .resizeAspectFill
        
        // Ensure the layer is configured to receive layout updates
        videoPreviewLayer.frame = bounds
        
        // Set initial video orientation
        updateVideoOrientation()
    }
    
    // This updates the video orientation based on the current device orientation
    func updateVideoOrientation() {
        guard let connection = videoPreviewLayer.connection, connection.isVideoOrientationSupported else {
            return
        }
        
        // Get the video orientation from the orientation manager
        let videoOrientation = orientationManager.videoOrientation
        
        // Apply the orientation
        connection.videoOrientation = videoOrientation
        
        // Force layout update
        setNeedsLayout()
    }
    
    // Make sure our layer is always properly sized
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Safety check to ensure we don't set zero bounds
        if bounds.width > 0 && bounds.height > 0 {
            CATransaction.begin()
            CATransaction.setDisableActions(true) // Prevent animation
            videoPreviewLayer.frame = bounds
            CATransaction.commit()
            
            print("CameraPreviewView - layoutSubviews. Layer frame: \(videoPreviewLayer.frame)")
        }
    }
}