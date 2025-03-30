import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Get the screen size to ensure we have a non-zero frame
        let screenSize = UIScreen.main.bounds.size
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        // Start with screen size to ensure visibility
        previewLayer.frame = CGRect(origin: .zero, size: screenSize)
        view.layer.addSublayer(previewLayer)
        
        // Store previewLayer for updates
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = context.coordinator.previewLayer else { return }
        
        // If view bounds are zero, use screen size
        if uiView.bounds.width == 0 || uiView.bounds.height == 0 {
            let screenSize = UIScreen.main.bounds.size
            previewLayer.frame = CGRect(origin: .zero, size: screenSize)
        } else {
            // Otherwise use the view bounds
            previewLayer.frame = uiView.bounds
        }
        
        // Force layout
        uiView.setNeedsLayout()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}