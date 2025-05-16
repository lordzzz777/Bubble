//
//  AudioMessageView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 18/4/25.
//

import SwiftUI

struct AudioMessageView: View {
    var audioURLString: String
    var duration: Double
    
    @Bindable var chatAudioViewModel: ChatAudioViewModel
    @State private var localURL: URL? = nil
    @State private var progressTimerTask: Task<Void, Never>? = nil
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack {
            HStack {
                // Botón de reproducción
                Button(action: {
                    chatAudioViewModel.togglePlayback(from: audioURLString, progressBinding: $progress)

                }) {
                    Image(systemName: chatAudioViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.primary)
                }

                // Vista de onda de audio con color por progreso
                AudioWaveformView(
                    samples: chatAudioViewModel.waveformSamples,
                    progress: progress
                )
                .frame(height: 30)
                .padding(.horizontal, 4)
                
                // Tiempo actual
                Text(chatAudioViewModel.formattedTime(from: chatAudioViewModel.currentPlaybackTime))
                    .font(.caption)
                    .frame(width: 50)
            }
        }
        .padding(10)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onDisappear {
            progressTimerTask?.cancel()
        }
        .onAppear {
            Task {
                if chatAudioViewModel.waveformSamples.isEmpty {
                    if localURL == nil {
                        localURL = try? await chatAudioViewModel.downloadAndCacheAudio(from: audioURLString)
                    }
                    if let url = localURL {
                        await chatAudioViewModel.extractWaveformSamples(from: url)
                    }
                }
            }
        }
    }
}






