//
//  RecordingWaveformView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 18/4/25.
//

import SwiftUI

struct RecordingWaveformView: View {
    @Bindable var audioViewModel: ChatAudioViewModel
    var barColor: Color = .primary
    var maxHeight: CGFloat = 30
    var barWidth: CGFloat = 3
    var barSpacing: CGFloat = 2
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(audioViewModel.liveRecordingSamples.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor)
                    .frame(
                        width: barWidth,
                        height: max(4, min(maxHeight, audioViewModel.liveRecordingSamples[index] * maxHeight))
                    )
            }
        }
        .frame(height: maxHeight)
        .animation(.easeInOut(duration: 0.15), value: audioViewModel.liveRecordingSamples)
    }
}




