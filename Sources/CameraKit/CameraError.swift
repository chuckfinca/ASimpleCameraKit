import Foundation
import SwiftUI

/// Errors that can occur during camera operations
public enum CameraError: LocalizedError {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case photoCaptureFailed
    case unknownError
    case accessDenied
    
    public var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is unavailable"
        case .cannotAddInput:
            return "Cannot add camera input"
        case .cannotAddOutput:
            return "Cannot add photo output"
        case .photoCaptureFailed:
            return "Failed to capture photo"
        case .unknownError:
            return "An unknown camera error occurred"
        case .accessDenied:
            return "Camera access is denied"
        }
    }
}

/// A view modifier that presents an error alert
public struct ErrorAlert: ViewModifier {
    @Binding var isPresented: Bool
    var error: Error?
    var retryAction: (() -> Void)?
    
    public init(isPresented: Binding<Bool>, error: Error?, retryAction: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.error = error
        self.retryAction = retryAction
    }
    
    public func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: $isPresented,
                actions: {
                    Button("OK", role: .cancel) {}
                    
                    if let retryAction = retryAction {
                        Button("Retry", action: retryAction)
                    }
                },
                message: {
                    Text(error?.localizedDescription ?? "An unknown error occurred")
                }
            )
    }
}

public extension View {
    /// Presents an error alert when a given condition is true
    /// - Parameters:
    ///   - isPresented: Whether the alert should be shown
    ///   - error: The error to display
    ///   - retryAction: Optional action to perform when retry is tapped
    /// - Returns: A view with the error alert attached
    func errorAlert(isPresented: Binding<Bool>, error: Error?, retryAction: (() -> Void)? = nil) -> some View {
        self.modifier(ErrorAlert(isPresented: isPresented, error: error, retryAction: retryAction))
    }
}
