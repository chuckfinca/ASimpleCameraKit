import SwiftUI
import Combine
import AVFoundation

/// Centralized manager for device orientation tracking and management
public class OrientationManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Current device orientation
    @Published public private(set) var currentOrientation: UIDeviceOrientation
    
    /// Whether the current orientation is valid (not unknown, faceUp, or faceDown)
    @Published public private(set) var isValidOrientation: Bool = true
    
    /// Most recent valid orientation (excludes unknown, faceUp, faceDown)
    @Published public private(set) var lastValidOrientation: UIDeviceOrientation
    
    // MARK: - Private Properties
    
    private var orientationObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a new orientation manager
    public init() {
        // Initialize with current orientation
        let deviceOrientation = UIDevice.current.orientation
        
        // Handle initial orientation
        if deviceOrientation.isValidForCapture {
            self.currentOrientation = deviceOrientation
            self.lastValidOrientation = deviceOrientation
        } else {
            // Default to portrait if the initial orientation is invalid
            self.currentOrientation = deviceOrientation
            self.lastValidOrientation = .portrait
            self.isValidOrientation = false
        }
        
        setupOrientationTracking()
    }
    
    deinit {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Returns the current capture orientation, using lastValidOrientation if current is invalid
    public var captureOrientation: UIDeviceOrientation {
        return currentOrientation.isValidForCapture ? currentOrientation : lastValidOrientation
    }
    
    /// Returns the AVCaptureVideoOrientation for the current device orientation
    public var videoOrientation: AVCaptureVideoOrientation {
        return ImageOrientationService.shared.videoOrientationFrom(deviceOrientation: captureOrientation)
    }
    
    /// Start orientation tracking (automatically called during initialization)
    public func startTracking() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    
    /// Stop orientation tracking
    public func stopTracking() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    // MARK: - Private Methods
    
    private func setupOrientationTracking() {
        // Start generating notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // Set up notification observer
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleOrientationChange()
        }
    }
    
    private func handleOrientationChange() {
        let newOrientation = UIDevice.current.orientation
        
        // Update current orientation regardless of validity
        currentOrientation = newOrientation
        
        // Check if the orientation is valid for capture
        isValidOrientation = newOrientation.isValidForCapture
        
        // Update the last valid orientation if appropriate
        if newOrientation.isValidForCapture {
            lastValidOrientation = newOrientation
        }
    }
}

// MARK: - UIDeviceOrientation Extensions

public extension UIDeviceOrientation {
    /// Returns whether this orientation is valid for capture (not unknown, faceUp, or faceDown)
    var isValidForCapture: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        case .unknown, .faceUp, .faceDown:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Returns the rotation angle needed to display content properly in this orientation
    var rotationAngle: Angle {
        switch self {
        case .portrait:
            return .degrees(0)
        case .portraitUpsideDown:
            return .degrees(180)
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .faceUp, .faceDown, .unknown:
            return .degrees(0)
        @unknown default:
            return .degrees(0)
        }
    }
    
    /// Returns the inverse rotation needed to counteract the UI rotation
    var counterRotationAngle: Angle {
        switch self {
        case .portrait:
            return .degrees(0)
        case .portraitUpsideDown:
            return .degrees(-180)
        case .landscapeLeft:
            return .degrees(-90)
        case .landscapeRight:
            return .degrees(90)
        case .faceUp, .faceDown, .unknown:
            return .degrees(0)
        @unknown default:
            return .degrees(0)
        }
    }
}
