import SwiftUI

struct ContentView: View {
    @State private var isPlaying: Bool = false
    @State private var A: Float = 0.3
    @State private var B: Float = 0.3
    @State private var a: Float = 22.5
    @State private var b: Float = 19.5
    @State private var delta: Float = 0.0
    @State private var lineWidth: CGFloat = 1
    @StateObject private var audioManager = AudioEngineManager(a: 225, b: 195, A: 0.3, B: 0.3, delta: 0)
    @State var graphicParams = LissajousGraphicParameters()
    @State private var staticFigure: Bool = false
    @State private var audioMuted: Bool = false
    
    var body: some View {
        VStack{
            //AudioPlayerView(fileName: "bass-test", url: Bundle.main.url(forResource: "bass-test", withExtension: "wav"))
            //            .padding()
        
            HStack {
                VStack {
                    Group {
                        if (staticFigure) {
                            StaticLissajousView(A: A, B: B, a: a, b: b, delta: delta, params: graphicParams)
                        }
                        else {
                            LissajousView(engine: audioManager, params: graphicParams)
                        }
                    }
                    .onDisappear {
                        audioManager.stop() // audio stops when visual (so window) is closed
                    }
                    .frame(width: 300, height: 300)
                    Spacer()
                    HStack
                    {
                        Button(action: {
                            isPlaying.toggle()
                            if isPlaying {
                                audioManager.start()
                            } else {
                                audioManager.stop()
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.largeTitle)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Text("Generate Sinwaves")
                        //Toggle("Mute Audio", isOn: $audioMuted)
                        //    .onChange(of: audioMuted) { _, newValue in
                        //        audioManager.mute = newValue ? 1.0 : 0.0
                        //    }
                        Spacer()
                        Toggle("Static Figure", isOn: $staticFigure)
                    }
                    Spacer()
                    VStack {
                        HStack
                        {
                            SliderView(label: "A", value: $A, range: 0...1, step: nil)
                            SliderView(label: "B", value: $B, range: 0...1, step: nil)
                            SliderView(label: "δ", value: $delta, range: 0...Float.pi * 2, step: nil)
                        }
                        SliderView(label: "a", value: $a, range: 5...50, step: 0.25)
                        SliderView(label: "b", value: $b, range: 5...50, step: 0.25)
                        
                    }
                    .onChange(of: A) { audioManager.A = A }
                    .onChange(of: a) { audioManager.a = a * 10 }
                    .onChange(of: b) { audioManager.b = b * 10 }
                    .onChange(of: B) { audioManager.B = B }
                    .onChange(of: delta) { audioManager.delta = delta }
                    // let's keep audioManager values separated from graphics ones
                }
                .frame(minWidth: 300, maxWidth: 300, minHeight: 500, maxHeight: 500)
                Spacer()
                VStack() {
                    Text("Lissajous Curve Generator")
                        .multilineTextAlignment(.center)
                        .font(.title)
                        .foregroundColor(.white)
                        
                    Spacer()
                    ColorPicker("Laser color: ", selection: $graphicParams.color)
                    SliderView(label: "Line", value: $graphicParams.width, range: 0.1...5.0, step: nil)
                    SliderView(label: "X Instability", value: $graphicParams.handNoiseX, range: 0.0...0.3, step: nil)
                    SliderView(label: "Y Instability", value: $graphicParams.handNoiseY, range: 0.0...0.3, step: nil)
                    SliderView(label: "X Hand Movement", value: $graphicParams.handAmplitudeX, range: 0.0...1.0, step: nil)
                    SliderView(label: "Y Hand Movement", value: $graphicParams.handAmplitudeY, range: 0.0...1.0, step: nil)
                    SliderView(label: "X Hand Speed", value: $graphicParams.handFreqX, range: 0.0...100.0, step: nil)
                    SliderView(label: "Y Hand Speed", value: $graphicParams.handFreqY, range: 0.0...100.0, step: nil)
                    SliderView(label: "Hand Phase Shift", value: $graphicParams.handPhaseShift, range: 0.0...Float.pi, step: nil)
                }
                .frame(minWidth: 300, maxWidth: 300, minHeight: 500, maxHeight: 500)
            }
            .padding(50)
            .frame(minWidth: 750, maxWidth: 750, minHeight: 600, maxHeight: 600)
        }
    }
    
}


struct SliderView<T: BinaryFloatingPoint>: View where T.Stride: BinaryFloatingPoint {
    let label: String
    @Binding var value: T
    let range: ClosedRange<T>
    let step: T?

    var body: some View {
        VStack {
            Text("\(label): \(String(format: "%.2f", Double(value)))")

            if let step = step {
                Slider(
                    value: Binding<Double>(
                        get: { Double(value) },
                        set: { value = T($0) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: Double(step)
                )
            } else {
                Slider(
                    value: Binding<Double>(
                        get: { Double(value) },
                        set: { value = T($0) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound)
                )
            }
        }
    }
}
