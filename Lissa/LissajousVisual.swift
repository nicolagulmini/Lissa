import SwiftUI

struct LissajousGraphicParameters {
    var width: CGFloat = 0.6
    var color: Color = .pink
    //var backgroundColor: Color = .white
    var handNoiseX: Float = 0.0
    var handNoiseY: Float = 0.0
    var handAmplitudeX: Float = 0.0
    var handAmplitudeY: Float = 0.0
    var handFreqX: Float = 1.0
    var handFreqY: Float = 1.0
    var handPhaseShift: Float = Float.pi/2
    var fps: Double = 30.0
}

class HandMovement {
    private var nextArgument: Float = 0
    private var sampleRate: Float = 44100
    
    func getNextPoint(amplitudeX: Float, amplitudeY: Float, freqX: Float, freqY: Float, phaseShift: Float) -> (x: Float, y: Float) {
        defer {
            nextArgument = (nextArgument + 1/self.sampleRate).truncatingRemainder(dividingBy: 2*Float.pi)
        }
        let x = 1 + 0.5 * amplitudeX * sin(freqX * nextArgument)
        let y = 1 + 0.5 * amplitudeY * sin(freqY * nextArgument + phaseShift)
        return (x: x, y: y)
    }
    
    /*
    func isPlayingNow() -> Bool {
        return self.isPlaying
    }
    
    func stop() {
        self.isPlaying = false
    }
    
    func start() {
        self.isPlaying = true
    }
     */
}

struct LissajousView: View {
    @ObservedObject var engine: AudioEngineManager
    
    @State private var displayPoints: [CGPoint] = []
    @State private var timerSource: DispatchSourceTimer? // to get real time modifications
    @State private var handMovement: HandMovement = HandMovement()
    @State private var isPlaying: Bool = true
    
    var params: LissajousGraphicParameters
    
    var body: some View {
        
        Canvas() { context, size in
            
            var handedNoiseX: CGFloat = CGFloat(0.0)
            var handedNoiseY: CGFloat = CGFloat(0.0)
            
            if (self.isPlaying) {
                handedNoiseX = CGFloat(Float.random(in: -1..<1) * params.handNoiseX)
                handedNoiseY = CGFloat(Float.random(in: -1..<1) * params.handNoiseY)
            }
            
            let scale: CGFloat = min(size.width, size.height) / 2.2
            
            let center = CGPoint(x: (size.width) / 2, y: (size.height) / 2)
            
            // laser wake
            for (index, point) in displayPoints.enumerated() {
                var handedNoisePointX = CGFloat(1.0)
                var handedNoisePointY = CGFloat(1.0)
                if (self.isPlaying) {
                    let handMovementPoint = handMovement.getNextPoint(amplitudeX: params.handAmplitudeX,
                                                                      amplitudeY: params.handAmplitudeY,
                                                                      freqX: params.handFreqX,
                                                                      freqY: params.handFreqY,
                                                                      phaseShift: params.handPhaseShift)
                    handedNoisePointX = CGFloat(handMovementPoint.x)
                    handedNoisePointY = CGFloat(handMovementPoint.y)
                }
                
                let x = (center.x * handedNoisePointX) + (point.x + handedNoiseX) * scale
                let y = (center.y * handedNoisePointY) + (point.y + handedNoiseY) * scale
                let cgPoint = CGPoint(x: x, y: y)
                
                // oldest point is the most transparent...
                let normalizedIndex = Double(index) / Double(max(displayPoints.count - 1, 1))
                let opacity = pow(normalizedIndex, 2) // ...with a quadratic decay
                let pointSize = 0.0 + (3.0 * normalizedIndex * params.width)
                
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: cgPoint.x - pointSize/2,
                        y: cgPoint.y - pointSize/2,
                        width: pointSize,
                        height: pointSize
                    )),
                    with: .color(params.color.opacity(opacity))
                )
            }
        }
        //.drawingGroup()
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timerSource?.cancel()
            timerSource = nil
        }
        .onChange(of: engine.getIsPlaying()) {
            self.isPlaying = engine.getIsPlaying()
        }
    }
    
    private func startTimer() {
        timerSource?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: 1.0 / params.fps)
        timer.setEventHandler {
            let audioPoints = engine.getRecentPoints()
            DispatchQueue.main.async {
                self.displayPoints = audioPoints
            }
        }
        timer.resume()
        timerSource = timer
    }
}

struct StaticLissajousView: View {
    var A: Float
    var B: Float
    var a: Float
    var b: Float
    var delta: Float
    var params: LissajousGraphicParameters

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let scale: CGFloat = min(size.width, size.height) / 2.2

            let steps = 1000
            for t in stride(from: 0.0, through: 2 * .pi, by: 2 * .pi / Float(steps)) {
                let x = A * sin(a * t + delta)
                let y = B * sin(b * t)

                let point = CGPoint(
                    x: center.x + CGFloat(x) * scale,
                    y: center.y + CGFloat(y) * scale
                )

                if t == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            context.stroke(path, with: .color(params.color), lineWidth: params.width)
        }
    }
}

