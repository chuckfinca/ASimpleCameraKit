import SwiftUI
import ASimpleCameraKit

/// A view that displays a loading spinner with a message
public struct LoadingOverlay: View {
    /// Message to display below the spinner
    var message: String
    
    /// Background opacity
    var backgroundOpacity: Double
    
    /// Creates a loading overlay
    /// - Parameters:
    ///   - message: Message to display
    ///   - backgroundOpacity: Opacity of the background (0-1)
    public init(message: String = "Processing...", backgroundOpacity: Double = 0.7) {
        self.message = message
        self.backgroundOpacity = backgroundOpacity
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(25)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

#if DEBUG
struct LoadingOverlay_Previews: PreviewProvider {
    static var previews: some View {
        LoadingOverlay(message: "Extracting Contact Information...")
    }
}
#endif
