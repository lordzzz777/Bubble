//
//  VoiceRecordingButton.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 13/4/25.
//

import SwiftUI

struct VoiceRecordingButton: View {
    var onStart: () -> Void
    var onCancel: () -> Void
    var onFinish: () -> Void
    
    @GestureState private var dragOffset: CGSize = .zero
    @State private var isRecording = false
    
    var body: some View {
        ZStack{
            Circle()
                .fill(isRecording ? Color.red : Color.blue)
                .frame(width: 30, height: 30)
                .overlay(content: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                })
        }.gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragOffset){ value, state, _ in
                    state = value.translation
                }
                .onChanged{ _ in
                    if isRecording{
                        onStart()
                        isRecording = true
                    }
                }
                .onEnded{ value in
                    if value.translation.width < -50 {
                        onCancel()
                    }else{
                        onFinish()
                    }
                    isRecording = false
                }
        )
    }
}

//#Preview {
//    VoiceRecordingButton()
//}
