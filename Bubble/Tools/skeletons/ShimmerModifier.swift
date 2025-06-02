//
//  ShimmerModifier.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 30/5/25.
//

import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.6   // arranca fuera de la vista
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.6), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .rotationEffect(.degrees(70))
                .offset(x: phase * 300)        // «ancho» de la banda
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 0.6                // recorre toda la vista
                }
            }
    }
}

extension View {
    /// Añade efecto shimmer a cualquier vista.
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
