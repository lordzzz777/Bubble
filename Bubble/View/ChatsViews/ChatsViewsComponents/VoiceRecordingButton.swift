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
    
    // Estados internos
    @State private var isDraggingLeft = false
    @State private var dragOffset: CGSize = .zero
    @State private var isRecording = false
    @State private var animatePulse = false
    
    // Umbral de cancelación
    private let cancelThreshold: CGFloat = -80
    
    var body: some View {
        ZStack {
            if isRecording {
                Circle()
                    .fill(isDraggingLeft ? .red : .blue)
                    .frame(width: 70, height: 70)
                    .shadow(radius: 6)
                    .scaleEffect(animatePulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animatePulse)
                
                Image(systemName: "mic.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 24))
            } else {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.gray)
                    .font(.system(size: 24))
            }
        }
        .offset(x: dragOffset.width, y: dragOffset.height * 0.3)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: isRecording)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dragOffset = value.translation
                        isDraggingLeft = dragOffset.width < cancelThreshold
                    }
                }
                .onEnded { _ in
                    if isDraggingLeft {
                        onCancel()
                    } else {
                        onFinish()
                    }
                    
                    withAnimation(.easeInOut) {
                        dragOffset = .zero
                        isDraggingLeft = false
                        isRecording = false
                        animatePulse = false
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.2)
                .onEnded { _ in
                    withAnimation(.easeInOut) {
                        onStart()
                        isRecording = true
                        animatePulse = true
                    }
                }
        )
    }
}

