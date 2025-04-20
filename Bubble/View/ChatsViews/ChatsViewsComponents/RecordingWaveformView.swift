//
//  RecordingWaveformView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 18/4/25.
//

import SwiftUI

import SwiftUI

struct RecordingWaveformView: View {
    var barCount: Int = 20
    var barWidth: CGFloat = 3
    var barSpacing: CGFloat = 4
    var barColor: Color = .green
    
    @State private var heights: [CGFloat] = []
    @State private var isAnimating = true
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: barWidth, height: heights.indices.contains(index) ? heights[index] : 5)
            }
        }
        .task {
            await startAsyncAnimation()
        }
        .onDisappear {
            isAnimating = false
        }
    }
    
    @MainActor
    private func generateHeights() {
        heights = (0..<barCount).map { _ in
            CGFloat.random(in: 5...25)
        }
    }
    
    private func startAsyncAnimation() async {
        while isAnimating {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    generateHeights()
                }
            }
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 segundos
        }
    }
}



#Preview {
    RecordingWaveformView()
}

