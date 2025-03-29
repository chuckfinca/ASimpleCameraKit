import SwiftUI

/// A stylized button for camera capture
public struct CaptureButton: View {
    /// Action to perform when the button is tapped
    var action: () -> Void
    
    /// Whether the button is disabled
    var disabled: Bool
    
    /// Button size
    var size: CGFloat
    
    /// Color for the button
    var color: Color
    
    /// Creates a new capture button
    /// - Parameters:
    ///   - action: Action to perform when tapped
    ///   - disabled: Whether the button is disabled
    ///   - size: Size of the button (diameter)
    ///   - color: Color of the button border
    public init(
        action: @escaping () -> Void,
        disabled: Bool = false,
        size: CGFloat = 70,
        color: Color = .black
    ) {
        self.action = action
        self.disabled = disabled
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                
                Circle()
                    .stroke(color, lineWidth: size * 0.07)
                    .frame(width: size, height: size)
            }
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
    }
}

#if DEBUG
struct CaptureButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            VStack(spacing: 20) {
                CaptureButton(action: {})
                CaptureButton(action: {}, disabled: true)
                CaptureButton(action: {}, size: 100, color: .red)
            }
        }
    }
}
#endif