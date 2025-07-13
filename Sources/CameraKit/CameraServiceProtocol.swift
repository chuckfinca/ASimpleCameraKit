import AVFoundation
import UIKit
import Combine
import SwiftUI

/// Protocol defining the interface for a camera service
public protocol CameraServiceProtocol {
    /// The active capture session
    var captureSession: AVCaptureSession { get }
    
    /// Publisher for the most recently captured image
    var capturedImage: CurrentValueSubject<UIImage?, Never> { get }
    
    /// Publisher for the current device orientation
    var deviceOrientation: CurrentValueSubject<UIDeviceOrientation, Never> { get }
    
    /// Publisher for the session running state
    var isSessionRunning: CurrentValueSubject<Bool, Never> { get }
    
    /// Publisher for any errors that occur
    var error: CurrentValueSubject<Error?, Never> { get }
    
    /// Orientation manager for orientation tracking
    var orientationManager: OrientationManager { get }
    
    /// Checks camera permissions
    /// - Returns: Whether camera access is authorized
    func checkPermissions() async -> Bool
    
    /// Clears the captured image
    func clearCapturedImage()
    
    /// Starts the capture session
    func startSession() async
    
    /// Stops the capture session
    func stopSession() async
    
    /// Captures a photo
    /// - Throws: CameraError if capture fails
    func capturePhoto() async throws
    
    /// Returns the current device orientation
    /// - Returns: The current device orientation
    func getCurrentOrientation() -> UIDeviceOrientation
}
