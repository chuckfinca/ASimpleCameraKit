import SwiftUI
import AVFoundation
import Combine

// A robust camera preview that properly handles orientation and layout changes
// (Reverted to old logic where the preview layer content attempts to rotate,
//  and ignores portraitUpsideDown for preview updates)
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    // Removed @State orientation tracking here as the UIView manages it internally now

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

        // Force layout update and ensure video orientation is checked
        DispatchQueue.main.async {
            // It's good practice to re-check orientation on update, though
            // the notification observer is the primary trigger.
            uiView.updateVideoOrientation()
            uiView.layoutIfNeeded()
        }
    }
}

// Custom UIView subclass that properly manages the AVCaptureVideoPreviewLayer
// (Reverted to old logic where the preview layer content attempts to rotate,
//  and ignores portraitUpsideDown for preview updates)
class CameraPreviewView: UIView {
    var session: AVCaptureSession
    private var orientationObserver: NSObjectProtocol?

    // Keep track of the last valid orientation to use when device is face up/down etc.
    // Initialize smartly based on current device state if valid.
    private var lastValidOrientation: UIDeviceOrientation = .portrait

    // We can directly access the AVCaptureVideoPreviewLayer through the layer property
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    init(session: AVCaptureSession) {
        self.session = session
        // Initialize lastValidOrientation based on current device state if valid for UI
        let currentOrientation = UIDevice.current.orientation
        if currentOrientation.isValidInterfaceOrientation {
            self.lastValidOrientation = currentOrientation
        } else {
            // Fallback if initial state is faceup/down/unknown
            self.lastValidOrientation = .portrait
        }
        print("CameraPreviewView - Initial lastValidOrientation: \(self.lastValidOrientation.rawValue)")

        super.init(frame: .zero)

        setupView()
        setupOrientationObserver() // Add observer setup
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // Clean up the observer
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            print("CameraPreviewView - Removed orientation observer")
        }
        // Depending on your app structure, you might want to call
        // UIDevice.current.endGeneratingDeviceOrientationNotifications() here
        // if this view is the *only* thing using them. However, OrientationManager
        // likely handles this globally.
    }

    private func setupView() {

        backgroundColor = .black
        videoPreviewLayer.session = session
        videoPreviewLayer.videoGravity = .resizeAspectFill

        // Ensure the layer is configured to receive layout updates
        videoPreviewLayer.frame = bounds

        // Set initial video orientation based on current device state & logic
        print("CameraPreviewView - setupView calling updateVideoOrientation")
        updateVideoOrientation()
    }

    // --- Start: Orientation Handling Logic (Old Version Behavior) ---

    private func setupOrientationObserver() {
        // Start generating notifications if not already started elsewhere (safe to call multiple times)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main // Ensure updates happen on the main thread
        ) { [weak self] _ in
            // print("CameraPreviewView - Received orientation change notification")
            self?.updateVideoOrientation()
        }
        print("CameraPreviewView - Added orientation observer")
    }

    // This updates the video orientation based on the current device orientation
    // matching the old behavior (ignores upside-down for preview rotation).
    func updateVideoOrientation() {
        guard let connection = videoPreviewLayer.connection, connection.isVideoOrientationSupported else {
            // This can happen briefly during setup/teardown
            // print("CameraPreviewView - Cannot update orientation: Connection not available or orientation not supported.")
            return
        }

        // Get current physical device orientation
        let deviceOrientation = UIDevice.current.orientation

        // Determine which orientation to *use* for the PREVIEW layer,
        // using the last valid one for ambiguous or ignored states.
        let orientationToUse: UIDeviceOrientation

        // Treat unknown, faceUp, faceDown, AND portraitUpsideDown as cases
        // where we should stick to the last known valid *preview* orientation.
        if deviceOrientation == .unknown ||
            deviceOrientation == .faceUp ||
            deviceOrientation == .faceDown ||
            deviceOrientation == .portraitUpsideDown { // <-- Includes portraitUpsideDown

            // Use the last valid orientation for these ambiguous/ignored cases
            orientationToUse = lastValidOrientation
            // Only print if the ignored orientation is different from the one we're using
            // if deviceOrientation != orientationToUse {
            //     print("CameraPreviewView - Orientation \(deviceOrientation.rawValue) ignored for preview. Using last valid: \(orientationToUse.rawValue)")
            // }
        } else {
            // This is a valid orientation for preview update (.portrait, .landscapeLeft, .landscapeRight)
            // Update our tracker if it actually changed, then use it.
            if lastValidOrientation != deviceOrientation {
                lastValidOrientation = deviceOrientation
                print("CameraPreviewView - Updated lastValidOrientation to: \(lastValidOrientation.rawValue)")
            }
            orientationToUse = deviceOrientation
            // print("CameraPreviewView - Using current orientation for preview: \(orientationToUse.rawValue)")
        }


        // Convert the *chosen* device orientation (orientationToUse) to the corresponding
        // AVCaptureVideoOrientation for the preview layer.
        // IMPORTANT: Landscape modes are reversed for the back camera preview.
        let targetVideoOrientation: AVCaptureVideoOrientation
        switch orientationToUse {
        case .portrait:
            targetVideoOrientation = .portrait
            // We should not hit .portraitUpsideDown here based on the logic above,
            // because orientationToUse would be lastValidOrientation instead.
            // So this case mapping is technically redundant for the *output* of this specific logic block.
        case .portraitUpsideDown:
            targetVideoOrientation = .portraitUpsideDown // Maps UIDeviceOrientation -> AVCaptureVideoOrientation
        case .landscapeLeft:
            targetVideoOrientation = .landscapeRight // Reversed for back camera sensor
        case .landscapeRight:
            targetVideoOrientation = .landscapeLeft // Reversed for back camera sensor
            // This case handles .unknown, .faceUp, .faceDown if they were the initial
            // value of lastValidOrientation, or potentially slipped through. Default to portrait.
        default:
            targetVideoOrientation = .portrait
        }

        // Apply the orientation ONLY if it has actually changed from the current state.
        if connection.videoOrientation != targetVideoOrientation {
            print("CameraPreviewView - Setting videoOrientation from \(connection.videoOrientation.rawValue) to: \(targetVideoOrientation.rawValue)")
            // Apply orientation change within a transaction
            CATransaction.begin()
            // Setting actions disabled prevents layer contents animation during rotation, which is usually desired here.
            CATransaction.setDisableActions(true)
            connection.videoOrientation = targetVideoOrientation
            CATransaction.commit()

            // We might need to trigger layout after orientation change
            setNeedsLayout() // Request layout update
        } else {
            // print("CameraPreviewView - videoOrientation unchanged (\(targetVideoOrientation.rawValue))")
            // Still might need layout if bounds changed even if orientation didn't
            setNeedsLayout()
        }
    }

    // --- End: Orientation Handling Logic ---


    // Make sure our layer is always properly sized when the UIView's bounds change
    override func layoutSubviews() {
        super.layoutSubviews()

        // Safety check to ensure we don't set zero bounds, which can cause issues
        if bounds.width > 0 && bounds.height > 0 {
            // Use a transaction to prevent implicit animations during resize/layout
            CATransaction.begin()
            CATransaction.setDisableActions(true) // Prevent animation of the frame change
            // Only update if the frame is actually different
            if videoPreviewLayer.frame != bounds {
                // print("CameraPreviewView - layoutSubviews updating layer frame from \(videoPreviewLayer.frame) to \(bounds)")
                videoPreviewLayer.frame = bounds
            } else {
                // print("CameraPreviewView - layoutSubviews frame unchanged: \(bounds)")
            }
            CATransaction.commit()
        } else {
            // print("CameraPreviewView - layoutSubviews skipped due to zero bounds: \(bounds)")
        }
    }
}

// Helper extension (can be placed elsewhere, e.g., OrientationManager or a dedicated extension file)
fileprivate extension UIDeviceOrientation {
    /// Checks if the orientation is one typically used for interface layout (portrait or landscape)
    var isValidInterfaceOrientation: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default: // .unknown, .faceUp, .faceDown
            return false
        }
    }
}

// Helper extension for mapping raw values (useful for debugging prints)
#if DEBUG // Only include debug helpers in debug builds
    extension AVCaptureVideoOrientation {
        var rawValue: String {
            switch self {
            case .portrait: return ".portrait"
            case .portraitUpsideDown: return ".portraitUpsideDown"
            case .landscapeRight: return ".landscapeRight"
            case .landscapeLeft: return ".landscapeLeft"
            @unknown default: return "unknown"
            }
        }
    }
#endif
