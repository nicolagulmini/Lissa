import Foundation
import AVFoundation

struct LinearRamp {
    private var current: Float
    private var target: Float
    private var step: Float
    private let rampTime: Float
    private let sampleRate: Float
    
    init(initialValue: Float, rampTimeSeconds: Float = 0.005, sampleRate: Float = 44100) {
        self.current = initialValue
        self.target = initialValue
        self.rampTime = rampTimeSeconds
        self.sampleRate = sampleRate
        self.step = 0
    }
    
    mutating func setTarget(_ newTarget: Float) {
        if newTarget != target {
            self.target = newTarget
            let totalSamples = rampTime * sampleRate
            self.step = (newTarget - current) / totalSamples
        }
    }
    
    mutating func update() -> Float {
        if abs(current - target) > abs(step) {
            current += step
        } else {
            current = target
            step = 0
        }
        return current
    }
    
    var value: Float {
        return current
    }
    
    var isRamping: Bool {
        return step != 0
    }
}

class AudioEngineManager: ObservableObject {
    
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    
    private var pointBuffer = RingBuffer<CGPoint>(capacity: 1024)
    private let pointBufferQueue = DispatchQueue(label: "audio.pointBuffer.queue")
    
    private var sampleCounter: UInt64 = 0
    private var sampleRate: Float = 44100
    
    @Published var A: Float { didSet { updateParams() } }
    @Published var B: Float { didSet { updateParams() } }
    @Published var a: Float { didSet { updateParams() } }
    @Published var b: Float { didSet { updateParams() } }
    @Published var delta: Float { didSet { updateParams() } }
    @Published var mute: Float = 1.0
    
    private var rampA: LinearRamp
    private var rampB: LinearRamp
    private var rampFreqA: LinearRamp
    private var rampFreqB: LinearRamp
    private var rampDelta: LinearRamp
    
    private let paramQueue = DispatchQueue(label: "audio.params.queue")
    
    private var isPlaying: Bool = true
    
    init(a: Float, b: Float, A: Float, B: Float, delta: Float) {
        
        self.A = A
        self.B = B
        self.a = a
        self.b = b
        self.delta = delta
        
        rampA = LinearRamp(initialValue: A)
        rampB = LinearRamp(initialValue: B)
        rampFreqA = LinearRamp(initialValue: a)
        rampFreqB = LinearRamp(initialValue: b)
        rampDelta = LinearRamp(initialValue: delta)
        
        updateParams()
        setupAudio()
    }
    
    private func updateParams() {
        paramQueue.async {
            self.rampA.setTarget(self.A)
            self.rampB.setTarget(self.B)
            self.rampFreqA.setTarget(self.a)
            self.rampFreqB.setTarget(self.b)
            self.rampDelta.setTarget(self.delta)
        }
    }
    
    private func setupAudio() {
        setRampTimes(amplitude: 0.001, frequency: 0.003, phase: 0.002)
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!
        
        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for frame in 0..<Int(frameCount) {
                let t = Double(self.sampleCounter) / Double(self.sampleRate)
                
                var currentA: Float = 0
                var currentB: Float = 0
                var currentFreqA: Float = 0
                var currentFreqB: Float = 0
                var currentDelta: Float = 0
                
                self.paramQueue.sync {
                    currentA = self.rampA.update()
                    currentB = self.rampB.update()
                    currentFreqA = self.rampFreqA.update()
                    currentFreqB = self.rampFreqB.update()
                    currentDelta = self.rampDelta.update()
                }
                
                let leftPhase = 2 * Double.pi * Double(currentFreqA) * t + Double(currentDelta)
                let rightPhase = 2 * Double.pi * Double(currentFreqB) * t
                
                let leftSample = Double(currentA) * sin(leftPhase)
                let rightSample = Double(currentB) * sin(rightPhase)
                
                let point = CGPoint(x: CGFloat(leftSample), y: CGFloat(rightSample))
                pointBufferQueue.async {
                    self.pointBuffer.write(point)
                }
                
                if ablPointer.count > 0 {
                    ablPointer[0].mData?.assumingMemoryBound(to: Float.self)[frame] = Float(leftSample)*Float(mute)
                }
                if ablPointer.count > 1 {
                    ablPointer[1].mData?.assumingMemoryBound(to: Float.self)[frame] = Float(rightSample)*Float(mute)
                }
                
                self.sampleCounter += 1
            }
            
            return noErr
        }
        
        if let node = sourceNode {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }
    
    func setRampTimes(amplitude: Float = 0.003, frequency: Float = 0.008, phase: Float = 0.005) {
        paramQueue.async {
            self.rampA = LinearRamp(initialValue: self.rampA.value, rampTimeSeconds: amplitude, sampleRate: self.sampleRate)
            self.rampB = LinearRamp(initialValue: self.rampB.value, rampTimeSeconds: amplitude, sampleRate: self.sampleRate)
            self.rampFreqA = LinearRamp(initialValue: self.rampFreqA.value, rampTimeSeconds: frequency, sampleRate: self.sampleRate)
            self.rampFreqB = LinearRamp(initialValue: self.rampFreqB.value, rampTimeSeconds: frequency, sampleRate: self.sampleRate)
            self.rampDelta = LinearRamp(initialValue: self.rampDelta.value, rampTimeSeconds: phase, sampleRate: self.sampleRate)
        }
    }
    
    func start() {
        do {
            try engine.start()
            self.isPlaying = true
        } catch {
            print("Error in engine start: \(error)")
        }
    }
    
    func stop() {
        engine.stop()
        self.isPlaying = false
    }
    
    func getRecentPoints() -> [CGPoint] {
        var points: [CGPoint] = []
        pointBufferQueue.sync {
            points = self.pointBuffer.getBuffer()
        }
        return points
    }
    
    func getIsPlaying() -> Bool {
        return self.isPlaying
    }
}

