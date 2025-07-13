# ASimpleCameraKit

A modern, lightweight Swift Package for iOS camera functionality with robust orientation handling and optional SwiftUI UI components.

## Features

### Core Camera Functionality
- 🎥 **Simple Camera Service** - Easy-to-use async/await camera operations
- 📸 **Photo Capture** - High-quality photo capture with metadata preservation
- 🔄 **Session Management** - Automatic session lifecycle management
- 🛡️ **Permission Handling** - Built-in camera permission checking
- ⚠️ **Error Handling** - Comprehensive error types with localized descriptions

### Advanced Orientation Management
- 🧭 **Core Motion Integration** - Accurate device orientation tracking using accelerometer
- 📱 **Discrete & Continuous Rotation** - Support for both step-based and smooth rotation
- 🎯 **Capture Orientation** - Proper EXIF metadata for photo orientation
- 🔄 **Real-time Updates** - Combine publishers for reactive orientation updates

### Optional UI Components
- 🎨 **SwiftUI Components** - Ready-to-use UI elements
- 🔄 **Device Rotation Modifier** - Rotate UI elements while keeping app locked to portrait
- ⏳ **Loading Overlay** - Customizable loading spinner component
- 📱 **Native iOS Behavior** - Mimics the native Camera app's interface rotation

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add ASimpleCameraKit to your project using Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/yourusername/ASimpleCameraKit`
3. Select the version you want to use

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ASimpleCameraKit", from: "1.0.0")
]
```

Then add the products to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ASimpleCameraKit", package: "ASimpleCameraKit"),
        .product(name: "ASimpleCameraKitUI", package: "ASimpleCameraKit"), // Optional UI components
    ]
)
```

## Quick Start

### Basic Camera Implementation

```swift
import SwiftUI
import ASimpleCameraKit

struct CameraView: View {
    @StateObject private var cameraService = CameraService()
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraService.captureSession)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Capture button
                Button {
                    Task {
                        do {
                            try await cameraService.capturePhoto()
                        } catch {
                            showingError = true
                        }
                    }
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(.black, lineWidth: 2)
                                .frame(width: 60, height: 60)
                        )
                }
                .padding(.bottom, 50)
            }
        }
        .task {
            await cameraService.startSession()
        }
        .cameraErrorAlert(
            isPresented: $showingError,
            error: cameraService.error.value
        )
    }
}

// Camera preview view using AVCaptureVideoPreviewLayer
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
```

### Accessing Captured Images

The camera service provides a Combine publisher for captured images:

```swift
struct CapturedImageView: View {
    @StateObject private var cameraService = CameraService()
    @State private var capturedImage: UIImage?
    
    var body: some View {
        VStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                Button("Clear") {
                    cameraService.clearCapturedImage()
                }
            } else {
                Text("No image captured")
            }
        }
        .onReceive(cameraService.capturedImage) { image in
            capturedImage = image
        }
    }
}
```

## UI Components

ASimpleCameraKit also provides an optional set of SwiftUI components to build a robust camera interface quickly. To use them, add the `ASimpleCameraKitUI` product to your target dependencies.

```swift
import ASimpleCameraKitUI
```

### Available Components

#### Device Rotation Modifier

In apps that are locked to a specific orientation (e.g., portrait), you may still want certain UI elements to rotate to match the physical orientation of the device, just like the native iOS Camera app. You can achieve this with the `.rotatesWithDevice()` modifier.

**Usage**

This modifier requires an instance of the `OrientationManager` from the core ASimpleCameraKit library and supports two rotation styles:
- `.discrete` (default) - Rotates in 90-degree steps
- `.continuous` - Rotates smoothly with device movement

```swift
import SwiftUI
import ASimpleCameraKit
import ASimpleCameraKitUI

struct MyCameraView: View {
    // Get the orientation manager from your camera service
    @StateObject private var cameraService = CameraService()

    var body: some View {
        ZStack {
            // Your main, non-rotating content here...
            CameraPreviewView(session: cameraService.captureSession)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // These buttons will rotate with the device
                HStack {
                    Button("Flash") { /* toggle flash */ }
                    Button("Grid") { /* toggle grid */ }
                    Button("Timer") { /* set timer */ }
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(8)
                .rotatesWithDevice(
                    orientationManager: cameraService.orientationManager,
                    style: .discrete // or .continuous for smooth rotation
                )
                
                Spacer()
            }
        }
        .task {
            await cameraService.startSession()
        }
    }
}
```

#### LoadingOverlay

A customizable loading spinner component for displaying processing states.

```swift
struct ProcessingView: View {
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            // Your main content
            
            if isProcessing {
                LoadingOverlay(
                    message: "Processing photo...",
                    backgroundOpacity: 0.7
                )
            }
        }
    }
}
```

## Advanced Usage

### Custom Error Handling

```swift
struct CameraViewWithCustomErrors: View {
    @StateObject private var cameraService = CameraService()
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        // ... camera UI
        .onReceive(cameraService.error) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        .alert("Camera Error", isPresented: $showingError) {
            Button("OK") { }
            Button("Retry") {
                Task {
                    try? await cameraService.setupCaptureSession()
                    await cameraService.startSession()
                }
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
}
```

### Orientation Monitoring

```swift
struct OrientationAwareView: View {
    @StateObject private var cameraService = CameraService()
    @State private var currentOrientation: UIDeviceOrientation = .portrait
    
    var body: some View {
        VStack {
            Text("Current orientation: \(currentOrientation.name)")
            
            // Your camera interface
        }
        .onReceive(cameraService.orientationManager.$currentOrientation) { orientation in
            currentOrientation = orientation
        }
    }
}
```

### Session Lifecycle Management

```swift
struct CameraLifecycleView: View {
    @StateObject private var cameraService = CameraService()
    @State private var isSessionRunning = false
    
    var body: some View {
        VStack {
            if isSessionRunning {
                Text("Camera is running")
                    .foregroundColor(.green)
            } else {
                Text("Camera is stopped")
                    .foregroundColor(.red)
            }
            
            Button(isSessionRunning ? "Stop Camera" : "Start Camera") {
                Task {
                    if isSessionRunning {
                        await cameraService.stopSession()
                    } else {
                        await cameraService.startSession()
                    }
                }
            }
        }
        .onReceive(cameraService.isSessionRunning) { running in
            isSessionRunning = running
        }
    }
}
```

## API Reference

### CameraService

The main service class that manages camera operations.

#### Properties

- `captureSession: AVCaptureSession` - The active capture session
- `capturedImage: CurrentValueSubject<UIImage?, Never>` - Publisher for captured images
- `deviceOrientation: CurrentValueSubject<UIDeviceOrientation, Never>` - Publisher for device orientation
- `isSessionRunning: CurrentValueSubject<Bool, Never>` - Publisher for session state
- `error: CurrentValueSubject<Error?, Never>` - Publisher for errors
- `orientationManager: OrientationManager` - Orientation tracking manager

#### Methods

- `checkPermissions() async -> Bool` - Check camera permissions
- `startSession() async` - Start the camera session
- `stopSession() async` - Stop the camera session
- `capturePhoto() async throws` - Capture a photo
- `clearCapturedImage()` - Clear the captured image
- `getCurrentOrientation() -> UIDeviceOrientation` - Get current orientation

### OrientationManager

Manages device orientation using Core Motion for accuracy.

#### Properties

- `currentOrientation: UIDeviceOrientation` - Current device orientation
- `lastValidOrientation: UIDeviceOrientation` - Last valid capture orientation
- `continuousAngle: Angle` - Continuous rotation angle for smooth animations
- `captureOrientation: UIDeviceOrientation` - Orientation to use for photo capture
- `videoOrientation: AVCaptureVideoOrientation` - Video orientation for AVFoundation

#### Methods

- `startTracking()` - Start orientation tracking
- `stopTracking()` - Stop orientation tracking

### CameraError

Enumeration of possible camera errors.

- `.cameraUnavailable` - Camera hardware is not available
- `.cannotAddInput` - Cannot add camera input to session
- `.cannotAddOutput` - Cannot add photo output to session
- `.photoCaptureFailed` - Photo capture operation failed
- `.unknownError` - An unknown error occurred
- `.accessDenied` - Camera access permission denied

## Best Practices

1. **Always check permissions** before starting the camera session
2. **Handle errors gracefully** using the provided error types and alert modifier
3. **Use orientation manager** from camera service for consistent orientation handling
4. **Stop sessions** when the camera view disappears to save battery
5. **Clear captured images** when no longer needed to free memory

## License

[Add your license information here]

## Contributing

[Add contribution guidelines here]

## Support

[Add support information here]