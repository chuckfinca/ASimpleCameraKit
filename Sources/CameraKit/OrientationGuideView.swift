import SwiftUI

/// A visual guide that always points in a consistent direction regardless of device orientation
public struct OrientationGuideView: View {
    // MARK: - Public Properties
    
    /// The size of the guide view
    public var size: CGFloat
    
    /// The color of the icon
    public var color: Color
    
    /// The background color
    public var backgroundColor: Color
    
    /// The icon to display
    public var icon: Image
    
    /// Whether to show a circular background
    public var showBackground: Bool
    
    /// The orientation manager to use (if nil, a new one will be created)
    @ObservedObject private var orientationManager: OrientationManager
    
    // MARK: - Initialization
    
    /// Creates a new orientation guide view
    /// - Parameters:
    ///   - orientationManager: An optional orientation manager to use
    ///   - size: The size of the guide (default: 50)
    ///   - color: The color of the icon (default: white)
    ///   - backgroundColor: The background color (default: black with 60% opacity)
    ///   - showBackground: Whether to show a circular background (default: true)
    ///   - icon: The icon to display (default: house.fill)
    public init(
        orientationManager: OrientationManager? = nil,
        size: CGFloat = 50,
        color: Color = .white,
        backgroundColor: Color = Color.black.opacity(0.6),
        showBackground: Bool = true,
        icon: Image = Image(systemName: "house.fill")
    ) {
        self.size = size
        self.color = color
        self.backgroundColor = backgroundColor
        self.showBackground = showBackground
        self.icon = icon
        self._orientationManager = ObservedObject(
            wrappedValue: orientationManager ?? OrientationManager()
        )
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Optional circular background
            if showBackground {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size + 10, height: size + 10)
            }
            
            // Icon that rotates to maintain orientation
            icon
                .font(.system(size: size * 0.6))
                .foregroundColor(color)
                .rotationEffect(orientationAdjustment)
        }
    }
    
    // MARK: - Private Properties
    
    /// Calculates the rotation needed to keep the icon oriented correctly
    private var orientationAdjustment: Angle {
        // Get the counter-rotation angle to offset the UI rotation
        let counterRotation = orientationManager.currentOrientation.counterRotationAngle
        
        // Add 180 degrees to make the icon point "up" instead of "down" (house icon points down by default)
        return counterRotation + .degrees(180)
    }
}

// MARK: - Presets

public extension OrientationGuideView {
    /// Creates a ceiling indicator that always points to the ceiling
    /// - Parameters:
    ///   - orientationManager: An optional orientation manager to use
    ///   - size: The size of the guide (default: 50)
    ///   - color: The color of the icon (default: white)
    /// - Returns: An orientation guide configured as a ceiling indicator
    static func ceilingIndicator(
        orientationManager: OrientationManager? = nil,
        size: CGFloat = 50,
        color: Color = .white
    ) -> OrientationGuideView {
        return OrientationGuideView(
            orientationManager: orientationManager,
            size: size,
            color: color,
            backgroundColor: Color.black.opacity(0.6),
            showBackground: true,
            icon: Image(systemName: "house.fill")
        )
    }
    
    /// Creates a compass that always points north
    /// - Parameters:
    ///   - orientationManager: An optional orientation manager to use
    ///   - size: The size of the guide (default: 50)
    ///   - color: The color of the icon (default: white)
    /// - Returns: An orientation guide configured as a compass
    static func compass(
        orientationManager: OrientationManager? = nil,
        size: CGFloat = 50,
        color: Color = .white
    ) -> OrientationGuideView {
        return OrientationGuideView(
            orientationManager: orientationManager,
            size: size,
            color: color,
            backgroundColor: Color.black.opacity(0.6),
            showBackground: true,
            icon: Image(systemName: "location.north.fill")
        )
    }
}

// MARK: - Preview

#if DEBUG
struct OrientationGuideView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            VStack(spacing: 20) {
                OrientationGuideView.ceilingIndicator()
                OrientationGuideView.compass()
                OrientationGuideView(
                    size: 60,
                    color: .yellow,
                    backgroundColor: .red.opacity(0.5),
                    icon: Image(systemName: "arrow.up.circle.fill")
                )
            }
        }
    }
}
#endif
