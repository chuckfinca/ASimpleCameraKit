//
//  RotatableContainerView.swift
//  ContactCapture
//
//  Created by Charles Feinn on 7/12/25.
//

import SwiftUI

// A UIViewRepresentable that hosts a SwiftUI view and applies a CGAffineTransform for rotation.
struct RotatableContainerView<Content: View>: UIViewRepresentable {
    @ViewBuilder let content: () -> Content
    let angle: Angle

    func makeUIView(context: Context) -> UIView {
        return UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let hostingController = context.coordinator.hostingController
        hostingController.rootView = AnyView(content())

        if hostingController.view.superview == nil {
            hostingController.view.backgroundColor = .clear
            uiView.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: uiView.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
            ])
        }

        let transform = CGAffineTransform(rotationAngle: angle.radians)
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            uiView.transform = transform
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        lazy var hostingController = UIHostingController<AnyView>(rootView: AnyView(EmptyView()))
    }
}
