import SwiftUI
import CoreMotion

struct LightAndPhoneUsageView: View {
    @State private var phoneUsageTime: Int = 0
    @State private var lightLevel: Double = 0.0
    @State private var sleepReport: String = "无记录"
    @State private var motionManager = CMMotionManager()
    @AppStorage("dailySleepReport") private var dailySleepReport: String = "暂无记录"

    var body: some View {
        VStack {
            Text("夜晚使用手机和灯光检测")
                .font(.largeTitle)
                .padding()

            Text("每天晚上使用手机的时间：\(phoneUsageTime) 分钟")
            Slider(value: Binding(get: {
                Double(phoneUsageTime)
            }, set: { newValue in
                phoneUsageTime = Int(newValue)
            }), in: 0...240, step: 5)
            .padding()

            Text("当前灯光强度：\(Int(lightLevel)) Lux")
                .padding()

            Button(action: {
                startSensorMonitoring()
            }) {
                Text("开始检测")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Button(action: {
                stopSensorMonitoring()
                generateSleepReport()
            }) {
                Text("结束检测并生成报告")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Text("今日报告：\(sleepReport)")
                .padding()

            Spacer()
        }
        .padding()
    }

    private func startSensorMonitoring() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { data, error in
                if let acceleration = data?.acceleration {
                    lightLevel = max(0, 1000 - abs(acceleration.x) * 500) // 模拟光照强度变化
                }
            }
        }
    }

    private func stopSensorMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }

    private func generateSleepReport() {
        let report = "您昨晚的手机使用时间：\(phoneUsageTime) 分钟，平均光照强度：\(Int(lightLevel)) Lux"
        dailySleepReport = report
        sleepReport = report
    }
}
