//
//  VoiceRecordingButton.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 13/4/25.
//

import SwiftUI

struct VoiceRecordingButton: View {
   @Environment(\.colorScheme) private var colorScheme
    var onStart: () -> Void
    var onFinish: () -> Void
    var onCancel: () -> Void
    
    // Estado de gesto
    @State private var isDraggingLeft = false
    @State private var dragOffset: CGSize = .zero
    
    // Umbral de cancelación
    private let cancelThreshold: CGFloat = -80
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isDraggingLeft ? .red : .gray)
                .frame( width:  30 , height: 70 )
                .shadow(radius: 4)
            
            Image(systemName: "mic.fill")
                .foregroundColor(.white)
                .font(.system(size: 24))
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragOffset = value.translation
                    isDraggingLeft = dragOffset.width < cancelThreshold
                }
                .onEnded { _ in
                    if isDraggingLeft {
                        onCancel()
                    } else {
                        onFinish()
                    }
                    // Reset visual
                    dragOffset = .zero
                    isDraggingLeft = false
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.2)
                .onEnded { _ in
                    onStart()
                }
        )
        .animation(.easeInOut(duration: 0.2), value: isDraggingLeft)
    }
}
