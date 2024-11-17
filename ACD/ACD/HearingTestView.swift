import AVFoundation
import SwiftUI

struct HearingTestView: View {
    @State private var isTestStarted = false
    @State private var currentMessage = "请您佩戴耳机 测试"
    @State private var isWaitingForTouch = true
    @State private var currentFrequency: Float = 500 // 初始频率 1000Hz
    @State private var currentVolume: Float = 0.9 // 初始音量 50%
    @State private var touchCount = 0
    @State private var isLeftEarTest = true
    @State private var isTestFinished = false

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    var body: some View {
        VStack {
            Text(currentMessage)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding()

            Button(action: {
                startTest()
            }) {
                Text(isTestStarted ? "正在测试..." : "开始测试")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isTestStarted)

            Spacer()

            if isTestStarted {
                Text("当前音频：频率: \(Int(currentFrequency)) Hz 音量: \(Int(currentVolume * 100))%")
                    .padding()

                // 可触控区域
                Color.white
                    .overlay(
                        Text("触摸屏幕继续测试")
                            .foregroundColor(.black)
                            .font(.headline)
                    )
                    .gesture(
                        TapGesture()
                            .onEnded {
                                onTouch()
                            }
                    )
                    .frame(height: 300)
                    .border(Color.gray)

                Spacer()

            } else if isTestFinished {
                Text("测试完成！")
                    .font(.title)
                    .foregroundColor(.green)
                    .padding()
            }
        }
        .padding()
        .onAppear {
            setupAudioEngine()
        }
        .onDisappear {
            stopAudioEngine()
        }
    }

    func startTest() {
        isTestStarted = true
        currentMessage = "请您确保您在一个相对安静的环境"
        playNextAudio()
    }

    func setupAudioEngine() {
        audioEngine.attach(playerNode)

        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(playerNode, to: mainMixer, format: nil)

        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }

    

    func playTone(frequency: Float, volume: Float) {
        let sampleRate: Float = 44100
        let duration: Float = 2 // 音频持续时间（秒）

        let totalSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0.0, count: totalSamples)

        // 生成正弦波音频样本
        for sampleIndex in 0..<totalSamples {
            let time = Float(sampleIndex) / sampleRate
            samples[sampleIndex] = sin(2 * .pi * frequency * time) * volume
        }

        // 创建 AVAudioFormat 对象，设置音频格式为单声道
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)
        
        // 创建一个 AVAudioPCMBuffer 来存储音频数据
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: AVAudioFrameCount(totalSamples)) else {
            print("无法创建音频缓冲区")
            return
        }

        audioBuffer.frameLength = AVAudioFrameCount(totalSamples)

        // 将生成的正弦波样本填充到音频缓冲区
        for i in 0..<totalSamples {
            audioBuffer.floatChannelData?.pointee[i] = samples[i]
        }

        // 创建 AVAudioEngine 和 AVAudioPlayerNode
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()

        // 将播放器节点连接到音频引擎的主输出
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioBuffer.format)

        do {
            // 启动音频引擎
            try audioEngine.start()

            // 播放音频缓冲区
            playerNode.scheduleBuffer(audioBuffer, at: nil, options: .loops, completionHandler: nil)
            
            // 开始播放
            playerNode.play()
        } catch {
            print("音频引擎启动失败: \(error)")
        }
    }


    func playNextAudio() {
        if isLeftEarTest {
            // Play audio for left ear  
            currentFrequency = 500 // Reset to initial frequency
            currentVolume = 0.9 // Reset to initial volume
            isLeftEarTest = false
        } else {
            // Switch to right ear
            currentFrequency = 600 // Right ear has a higher frequency
            currentVolume = 0.9// Slightly higher volume
            isLeftEarTest = true
        }

        playTone(frequency: currentFrequency, volume: currentVolume)
    }

    func onTouch() {
        touchCount += 1

        // If user touches 3 times, increase volume and frequency
        if touchCount >= 3 {
            currentVolume = min(currentVolume + 0.1, 1.0) // Increase volume
            currentFrequency = min(currentFrequency + 500, 5000) // Increase frequency
            touchCount = 0 // Reset touch count
        }

        playNextAudio()
    }

    func stopAudioEngine() {
        audioEngine.stop()
        playerNode.stop()
    }
}
