import SwiftUI
import Combine
import CoreMotion
import AVFoundation

/// Centralized manager for device orientation tracking using Core Motion for robustness.
public class OrientationManager: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var currentOrientation: UIDeviceOrientation = .portrait
    @Published public private(set) var lastValidOrientation: UIDeviceOrientation = .portrait

    @Published public private(set) var continuousAngleRadians: Double = 0.0

    // MARK: - Private Properties
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    // MARK: - Initialization
    public init() {
        print("✅ OrientationManager: Initialized.")
        startTracking()
    }

    deinit {
        stopTracking()
    }

    // MARK: - Public Methods
    public var captureOrientation: UIDeviceOrientation { lastValidOrientation }
    public var videoOrientation: AVCaptureVideoOrientation { AVCaptureVideoOrientation(deviceOrientation: captureOrientation) ?? .portrait }

    public func startTracking() {
        guard motionManager.isAccelerometerAvailable else {
            print("🛑 OrientationManager ERROR: Accelerometer is not available.")
            return
        }

        motionManager.accelerometerUpdateInterval = 0.1 // Increase update frequency for smoother rotation
        print("✅ OrientationManager: Starting Core Motion updates.")

        motionManager.startAccelerometerUpdates(to: queue) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }

            // --- LOGGING THE RAW DATA ---
            // print(String(format: "➡️ OrientationManager RAW DATA: x: %.2f, y: %.2f, z: %.2f", data.acceleration.x, data.acceleration.y, data.acceleration.z))

            // --- DISCRETE ORIENTATION LOGIC ---
            let newOrientation = self.orientation(from: data.acceleration)

            // --- CONTINUOUS ANGLE LOGIC ---
            // Calculate the angle using atan2. We use x and -y to map correctly to SwiftUI's coordinate space.
            let angleInRadians = -atan2(data.acceleration.x, -data.acceleration.y)

            DispatchQueue.main.async {
                // --- Update discrete orientation ---
                self.currentOrientation = newOrientation
                if newOrientation.isValidForCapture && self.lastValidOrientation != newOrientation {
                    print("✅ OrientationManager: >>> Publishing new valid discrete orientation: \(newOrientation.name)")
                    self.lastValidOrientation = newOrientation
                }

                // --- Update continuous angle ---
                self.continuousAngleRadians = angleInRadians
            }
        }
    }

    public func stopTracking() {
        print("✅ OrientationManager: Stopping Core Motion updates.")
        motionManager.stopAccelerometerUpdates()
    }

    // MARK: - Private Methods
    private func orientation(from acceleration: CMAcceleration) -> UIDeviceOrientation {
        if abs(acceleration.z) > 0.8 { return acceleration.z < 0 ? .faceUp : .faceDown }
        if acceleration.y < -0.6 { return .portrait }
        if acceleration.y > 0.6 { return .portraitUpsideDown }
        if acceleration.x < -0.6 { return .landscapeLeft }
        if acceleration.x > 0.6 { return .landscapeRight }
        return .unknown
    }
}

// MARK: - UIDeviceOrientation & AVCaptureVideoOrientation Extensions

public extension UIDeviceOrientation {
    var isValidForCapture: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }

    /// Returns the rotation angle as a SwiftUI `Angle`.
    var rotationAngle: Angle {
        return Angle(radians: Double(self.rotationAngleRadians))
    }

    var rotationAngleRadians: CGFloat {
        switch self {
        case .portrait: return 0
        case .portraitUpsideDown: return .pi
        case .landscapeLeft: return .pi / 2
        case .landscapeRight: return -.pi / 2
        default: return 0
        }
    }

    var counterRotationAngle: Angle {
        switch self {
        case .portrait: return .degrees(0)
        case .portraitUpsideDown: return .degrees(-180)
        case .landscapeLeft: return .degrees(-90)
        case .landscapeRight: return .degrees(90)
        default: return .degrees(0)
        }
    }

    var name: String {
        switch self {
        case .unknown: return "unknown"
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portraitUpsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        case .faceUp: return "faceUp"
        case .faceDown: return "faceDown"
        @unknown default: return "default"
        }
    }
}

public extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeRight: self = .landscapeLeft
        case .landscapeLeft: self = .landscapeRight
        default: return nil
        }
    }
}
