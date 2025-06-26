import Foundation
import AVFoundation
import Combine
import SwiftUI
import Accelerate

// MARK: - Audio Visualizer
class AudioVisualizer: NSObject, ObservableObject {
    // MARK: - Properties
    private let audioManager: AudioManager
    private let fft = FFTProcessor()
    
    @Published private(set) var waveformData: [Float] = []
    @Published private(set) var spectrumData: [Float] = []
    @Published private(set) var peakLevel: Float = 0.0
    @Published private(set) var averageLevel: Float = 0.0
    
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let waveformLength = 100
    private let spectrumLength = 64
    private let updateInterval: TimeInterval = 0.05 // 20 FPS
    
    // MARK: - Initialization
    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        super.init()
        
        setupAudioMonitoring()
        initializeData()
    }
    
    deinit {
        stopVisualization()
    }
    
    // MARK: - Public Methods
    func startVisualization() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateVisualization()
        }
    }
    
    func stopVisualization() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func reset() {
        waveformData.removeAll()
        spectrumData.removeAll()
        peakLevel = 0.0
        averageLevel = 0.0
        initializeData()
    }
    
    // MARK: - Private Methods
    private func setupAudioMonitoring() {
        audioManager.$audioLevel
            .sink { [weak self] level in
                self?.processAudioLevel(level)
            }
            .store(in: &cancellables)
    }
    
    private func initializeData() {
        waveformData = Array(repeating: 0.0, count: waveformLength)
        spectrumData = Array(repeating: 0.0, count: spectrumLength)
    }
    
    private func processAudioLevel(_ level: Float) {
        // Update peak and average levels
        peakLevel = max(peakLevel, level)
        averageLevel = (averageLevel * 0.9) + (level * 0.1)
        
        // Add to waveform data
        waveformData.append(level)
        if waveformData.count > waveformLength {
            waveformData.removeFirst()
        }
        
        // Generate spectrum data (simplified)
        generateSpectrumData(from: level)
    }
    
    private func generateSpectrumData(from level: Float) {
        // Generate mock spectrum data based on audio level
        // In practice, this would use FFT analysis
        for i in 0..<spectrumLength {
            let frequency = Float(i) / Float(spectrumLength)
            let amplitude = level * (1.0 - frequency) * Float.random(in: 0.5...1.5)
            spectrumData[i] = amplitude
        }
    }
    
    private func updateVisualization() {
        // Update visualization data
        // This is called periodically to provide smooth updates
        objectWillChange.send()
    }
}

// MARK: - FFT Processor
class FFTProcessor {
    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length
    private let n: vDSP_Length
    
    init() {
        log2n = 10 // 1024 samples
        n = 1 << log2n
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func process(_ samples: [Float]) -> [Float] {
        var realParts = [Float](repeating: 0, count: Int(n/2))
        var imagParts = [Float](repeating: 0, count: Int(n/2))
        
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        // Convert to split complex format
        samples.withUnsafeBufferPointer { samplesPtr in
            vDSP_ctoz(samplesPtr.baseAddress!, 2, &splitComplex, 1, n/2)
        }
        
        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: Int(n/2))
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, n/2)
        
        // Convert to dB
        var scaledMagnitudes = [Float](repeating: 0, count: Int(n/2))
        vDSP_vdbcon(magnitudes, 1, [1.0], &scaledMagnitudes, 1, n/2, 1)
        
        return scaledMagnitudes
    }
}

// MARK: - Audio Visualization Views
struct WaveformView: View {
    let data: [Float]
    let color: Color
    let lineWidth: CGFloat
    
    init(data: [Float], color: Color = .accentColor, lineWidth: CGFloat = 2.0) {
        self.data = data
        self.color = color
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let centerY = height / 2
                let stepX = width / CGFloat(data.count - 1)
                
                path.move(to: CGPoint(x: 0, y: centerY))
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = centerY + CGFloat(value) * centerY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color, lineWidth: lineWidth)
        }
    }
}

struct SpectrumView: View {
    let data: [Float]
    let color: Color
    let barWidth: CGFloat
    let spacing: CGFloat
    
    init(data: [Float], color: Color = .accentColor, barWidth: CGFloat = 4.0, spacing: CGFloat = 2.0) {
        self.data = data
        self.color = color
        self.barWidth = barWidth
        self.spacing = spacing
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: spacing) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: barWidth, height: geometry.size.height * CGFloat(value))
                        .animation(.easeInOut(duration: 0.1), value: value)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct CircularWaveformView: View {
    let data: [Float]
    let color: Color
    let lineWidth: CGFloat
    
    init(data: [Float], color: Color = .accentColor, lineWidth: CGFloat = 2.0) {
        self.data = data
        self.color = color
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - lineWidth
            
            Path { path in
                guard !data.isEmpty else { return }
                
                let angleStep = 2 * .pi / CGFloat(data.count)
                
                for (index, value) in data.enumerated() {
                    let angle = CGFloat(index) * angleStep
                    let adjustedRadius = radius * (0.5 + CGFloat(value) * 0.5)
                    let x = center.x + cos(angle) * adjustedRadius
                    let y = center.y + sin(angle) * adjustedRadius
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                path.closeSubpath()
            }
            .stroke(color, lineWidth: lineWidth)
        }
    }
}

struct AudioLevelMeter: View {
    let level: Float
    let peakLevel: Float
    let color: Color
    
    init(level: Float, peakLevel: Float = 0.0, color: Color = .accentColor) {
        self.level = level
        self.peakLevel = peakLevel
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                // Peak level indicator
                if peakLevel > 0 {
                    Rectangle()
                        .fill(color.opacity(0.8))
                        .frame(height: 2)
                        .scaleEffect(x: CGFloat(peakLevel), anchor: .leading)
                        .animation(.easeOut(duration: 0.5), value: peakLevel)
                }
                
                // Current level
                Rectangle()
                    .fill(color)
                    .frame(height: 4)
                    .scaleEffect(x: CGFloat(level), anchor: .leading)
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }
}

// MARK: - Audio Visualization Components
struct AudioVisualizationView: View {
    @ObservedObject var visualizer: AudioVisualizer
    let style: VisualizationStyle
    
    enum VisualizationStyle {
        case waveform
        case spectrum
        case circular
        case meter
    }
    
    init(visualizer: AudioVisualizer, style: VisualizationStyle = .waveform) {
        self.visualizer = visualizer
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .waveform:
            WaveformView(data: visualizer.waveformData)
        case .spectrum:
            SpectrumView(data: visualizer.spectrumData)
        case .circular:
            CircularWaveformView(data: visualizer.waveformData)
        case .meter:
            AudioLevelMeter(level: visualizer.averageLevel, peakLevel: visualizer.peakLevel)
        }
    }
}

// MARK: - Audio Visualization Configuration
struct AudioVisualizationConfig {
    let updateRate: TimeInterval
    let waveformLength: Int
    let spectrumLength: Int
    let enableFFT: Bool
    let smoothingFactor: Float
    
    static let standard = AudioVisualizationConfig(
        updateRate: 0.05,
        waveformLength: 100,
        spectrumLength: 64,
        enableFFT: false,
        smoothingFactor: 0.1
    )
    
    static let highQuality = AudioVisualizationConfig(
        updateRate: 0.016, // 60 FPS
        waveformLength: 200,
        spectrumLength: 128,
        enableFFT: true,
        smoothingFactor: 0.05
    )
}

// MARK: - Audio Visualization Manager
class AudioVisualizationManager: ObservableObject {
    // MARK: - Properties
    private let visualizer: AudioVisualizer
    private let config: AudioVisualizationConfig
    
    @Published private(set) var isActive = false
    @Published private(set) var currentStyle: AudioVisualizationView.VisualizationStyle = .waveform
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(visualizer: AudioVisualizer, config: AudioVisualizationConfig = .standard) {
        self.visualizer = visualizer
        self.config = config
    }
    
    // MARK: - Public Methods
    func startVisualization() {
        visualizer.startVisualization()
        isActive = true
    }
    
    func stopVisualization() {
        visualizer.stopVisualization()
        isActive = false
    }
    
    func setStyle(_ style: AudioVisualizationView.VisualizationStyle) {
        currentStyle = style
    }
    
    func reset() {
        visualizer.reset()
    }
} 