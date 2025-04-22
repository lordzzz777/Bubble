//
//  AudioWaveformView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 20/4/25.
//

import SwiftUI

struct AudioWaveformView: View {
    var samples: [CGFloat]
    var progress: CGFloat // 0.0 a 1.0
    
    var maxHeight: CGFloat = 30
    var barWidth: CGFloat = 3
    var barSpacing: CGFloat = 2
    var playedColor: Color = .primary
    var unplayedColor: Color = .gray.opacity(0.4)
    
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(samples.indices, id: \.self) { i in
                    let indexProgress = CGFloat(i) / CGFloat(samples.count)
                    let isPlayed = indexProgress <= progress
                    let height = min(maxHeight, samples[i] * maxHeight)
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(isPlayed ? playedColor : unplayedColor)
                        .frame(width: barWidth, height: max(4, height))
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: maxHeight)
            .animation(.easeInOut(duration: 0.2), value: progress)
            
        }
    }
}
