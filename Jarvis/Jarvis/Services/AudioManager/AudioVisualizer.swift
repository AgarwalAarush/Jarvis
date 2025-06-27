import SwiftUI

// MARK: - Audio Visualizer
class AudioVisualizer: ObservableObject {
    @Published var audioLevels: [Float]
    @Published var waveform: [Float]
    @Published var peakLevel: Float = 0.0
    
    let barCount: Int
    
    init(barCount: Int = 30) {
        self.barCount = barCount
        self.audioLevels = Array(repeating: 0.0, count: barCount)
        self.waveform = []
    }
    
    func updateLevels(with buffer: UnsafeBufferPointer<Float>) {
        let step = buffer.count / barCount
        var levels: [Float] = []
        
        for i in 0..<barCount {
            let start = i * step
            let end = min((i + 1) * step, buffer.count)
            let slice = Array(buffer[start..<end])
            let rms = sqrt(slice.map { $0 * $0 }.reduce(0, +) / Float(slice.count))
            levels.append(rms)
        }
        
        DispatchQueue.main.async {
            self.audioLevels = levels
            self.peakLevel = levels.max() ?? 0.0
        }
    }
    
    func updateWaveform(with buffer: UnsafeBufferPointer<Float>) {
        DispatchQueue.main.async {
            self.waveform = Array(buffer)
        }
    }
    
    func reset() {
        audioLevels = Array(repeating: 0.0, count: barCount)
        waveform = []
        peakLevel = 0.0
    }
    
    func startVisualization() {
        // No-op, handled by AudioManager
    }
    
    func stopVisualization() {
        // No-op, handled by AudioManager
    }
}

// MARK: - Audio Visualization View
struct AudioVisualizationView: View {
    @ObservedObject var visualizer: AudioVisualizer
    let style: VisualizationStyle
    
    var body: some View {
        switch style {
        case .linear:
            LinearAudioVisualizer(visualizer: visualizer)
        case .circular:
            CircularAudioVisualizer(visualizer: visualizer)
        case .waveform:
            WaveformAudioVisualizer(visualizer: visualizer)
        }
    }
    
    enum VisualizationStyle {
        case linear
        case circular
        case waveform
    }
}

// MARK: - Linear Audio Visualizer
struct LinearAudioVisualizer: View {
    @ObservedObject var visualizer: AudioVisualizer
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<visualizer.barCount, id: \.self) { index in
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: CGFloat(visualizer.audioLevels[index] * 50))
                    .animation(.easeInOut(duration: 0.1), value: visualizer.audioLevels[index])
            }
        }
    }
}

// MARK: - Circular Audio Visualizer
struct CircularAudioVisualizer: View {
    @ObservedObject var visualizer: AudioVisualizer
    
    var body: some View {
        ZStack {
            ForEach(0..<visualizer.barCount, id: \.self) { index in
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 10 + CGFloat(visualizer.audioLevels[index] * 40))
                    .rotationEffect(.degrees(Double(index) / Double(visualizer.barCount) * 360))
                    .offset(y: -60)
                    .animation(.easeInOut(duration: 0.1), value: visualizer.audioLevels[index])
            }
        }
    }
}

// MARK: - Waveform Audio Visualizer
struct WaveformAudioVisualizer: View {
    @ObservedObject var visualizer: AudioVisualizer
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step = size.width / CGFloat(visualizer.waveform.count)
            
            for (index, level) in visualizer.waveform.enumerated() {
                let x = CGFloat(index) * step
                let y = size.height / 2 + CGFloat(level) * size.height / 2
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.stroke(path, with: .color(Color.accentColor), lineWidth: 2)
        }
    }
}

// MARK: - Audio Level Meter
struct AudioLevelMeter: View {
    let level: Float
    let peakLevel: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * CGFloat(level))
                
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: geometry.size.height)
                    .offset(x: geometry.size.width * CGFloat(peakLevel))
            }
            .cornerRadius(4)
        }
    }
}