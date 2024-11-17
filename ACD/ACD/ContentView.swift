import SwiftUI
import VisionKit
import Vision
import Foundation
import AVFoundation
import UserNotifications
import CoreMotion
import Combine

struct ContentView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @State private var showLaunchScreen = true
    private let motionManager = CMMotionManager()

    var body: some View {
        if showLaunchScreen {
            LaunchView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        showLaunchScreen = false
                        hasLaunchedBefore = true
                    }
                }
        } else if !hasLaunchedBefore {
            OnboardingView(showLaunchScreen: $showLaunchScreen)
        } else {
            MainView()
                .onAppear {
                    requestNotificationPermission()
                    scheduleDailyNotification()
                    startEveningMonitoring()
                    NotificationManager.shared.rescheduleIfNotConfirmed()
                }
        }
    }

    // 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知权限已授权")
            } else if let error = error {
                print("通知权限被拒绝: \(error.localizedDescription)")
            }
        }
    }

    // 设置每日通知
    private func scheduleDailyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "每日睡眠报告"
        content.body = UserDefaults.standard.string(forKey: "dailySleepReport") ?? "昨晚的睡眠数据未检测，请检查设置。"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 10 // 每天上午10点

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailySleepReportNotification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知设置失败: \(error.localizedDescription)")
            } else {
                print("每日睡眠通知已设置")
            }
        }
    }

    // 开始夜晚传感器监测
    private func startEveningMonitoring() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0

            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { data, error in
                guard let acceleration = data?.acceleration else { return }

                // 模拟灯光强度的变化
                let simulatedLightLevel = max(0, 1000 - abs(acceleration.x) * 500)

                // 存储到本地记录
                let phoneUsageTime = Int.random(in: 0...240) // 模拟手机使用时间
                let report = "手机使用时间: \(phoneUsageTime) 分钟，平均光照强度: \(Int(simulatedLightLevel)) Lux"

                UserDefaults.standard.set(report, forKey: "dailySleepReport")
            }

            print("夜晚传感器监测已开始")
        } else {
            print("加速度计不可用")
        }
    }
}

class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        setupNotificationActions()
    }

    // 配置通知交互
    private func setupNotificationActions() {
        let confirmAction = UNNotificationAction(identifier: "CONFIRM_ACTION", title: "服用确认", options: .foreground)
        let category = UNNotificationCategory(identifier: "MEDICATION_REMINDER", actions: [confirmAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // 处理用户点击通知的响应
    func handleNotificationResponse(response: UNNotificationResponse) {
        if response.actionIdentifier == "CONFIRM_ACTION" {
            let currentDate = Date()
            UserDefaults.standard.set(currentDate, forKey: "lastMedicationTime")
            print("用户已确认服药: \(currentDate)")
            // 取消当日剩余提醒
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rescheduleReminder"])
        }
    }

    // 如果未确认服药，则重新安排提醒
    func rescheduleIfNotConfirmed() {
        if UserDefaults.standard.object(forKey: "lastMedicationTime") == nil {
            let content = UNMutableNotificationContent()
            content.title = "药物提醒"
            content.body = "您尚未确认服用药物，请尽快确认。"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1800, repeats: false)
            let request = UNNotificationRequest(identifier: "rescheduleReminder", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("重复提醒设置失败: \(error.localizedDescription)")
                } else {
                    print("重复提醒已安排")
                }
            }
        }
    }
}

// 让 AppDelegate 响应通知交互
struct OnboardingView: View {
    @Binding var showLaunchScreen: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("欢迎使用本应用！")
                .font(.largeTitle)
                .padding()

            Text("在这里，您可以查询药物信息、病情以及拍照识别文字。")
                .multilineTextAlignment(.center)
                .padding()

            Button(action: {
                showLaunchScreen = false
            }) {
                Text("开始使用")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
struct MainView: View {
    @State private var selectedTab: String? = ""
    @State private var medicationInput: String = ""
    @State private var conditionInput: String = ""
    @State private var medicationResponse: [Message] = []
    @State private var conditionResponse: [Message] = []
    @State private var showCameraView = false
    @State private var recognizedText: String = ""
    @State private var isLoading = false
    @State private var showProfileOptions = false
    @State private var showHealthSurvey = false
 
    var body: some View {
        VStack {
            if showHealthSurvey {
                HealthSurveyView()
            } else if showProfileOptions {
                ProfileOptionsView(showHealthSurvey: $showHealthSurvey)
            } else if selectedTab == "medication" {
                QueryResponseView(
                    gptResponse: $medicationResponse,
                    userInput: $medicationInput,
                    selectedTab: "medication",
                    isLoading: $isLoading,
                    sendInputToBackend: sendInputToBackend
                )
            } else if selectedTab == "condition" {
                QueryResponseView(
                    gptResponse: $conditionResponse,
                    userInput: $conditionInput,
                    selectedTab: "condition",
                    isLoading: $isLoading,
                    sendInputToBackend: sendInputToBackend
                )
            } else if showCameraView {
                CameraView(recognizedText: $recognizedText, onSave: {
                    isLoading = true
                    sendInputToBackend(contextType: "camera", userInput: recognizedText) { response in
                        medicationResponse.append(Message(text: "识别文本: \(recognizedText)", isUser: false))
                        medicationResponse.append(Message(text: "系统: \(response)", isUser: false))
                        isLoading = false
                        showCameraView = false
                    }
                })
            } else {
                Text("请选择操作").padding()
            }
            Spacer()
            
            // Bottom tab buttons
            HStack {
                // Medication Tab Button
                Button(action: {
                    selectedTab = "medication"
                    clearAllViewsExcept("medication")
                }) {
                    VStack {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 25))
                        Text("药物")
                            .font(.caption)
                    }
                }
                Spacer()
                
                // Condition Tab Button
                Button(action: {
                    selectedTab = "condition"
                    clearAllViewsExcept("condition")
                }) {
                    VStack {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 25))
                        Text("病情")
                            .font(.caption)
                    }
                }
                Spacer()
                
                // Camera Button
                Button(action: {
                    showCameraView = true
                    clearAllViewsExcept("camera")
                }) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 25))
                        Text("拍照")
                            .font(.caption)
                    }
                }
                Spacer()
                
                // Profile/Person Button
                Button(action: {
                    showProfileOptions = true
                    clearAllViewsExcept("profile")
                }) {
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 25))
                        Text("个人")
                            .font(.caption)
                    }
                }
                .padding(.trailing)
            }
            .padding()
        }
        .navigationBarTitle("查询页面", displayMode: .inline)
        .overlay(
            Group {
                if isLoading {
                    LoadingOverlayView()
                }
            }
        )
    }

    // Function to reset all view states except the selected one
    private func clearAllViewsExcept(_ view: String) {
        showCameraView = (view == "camera")
        showProfileOptions = (view == "profile")
        showHealthSurvey = (view == "healthSurvey")
        selectedTab = (view == "medication" || view == "condition") ? view : nil
    }

    func sendInputToBackend(contextType: String, userInput: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "http://192.168.1.25:5001/chat") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "context_type": contextType,
            "user_question": userInput
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error: \(error?.localizedDescription ?? "No data")")
                return
            }
            
            if let responseDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
               let response = responseDict["response"] {
                DispatchQueue.main.async {
                    completion(response)
                }
            }
        }
        
        task.resume()
    }
}

struct QueryResponseView: View {
    @Binding var gptResponse: [Message]
    @Binding var userInput: String
    var selectedTab: String
    @Binding var isLoading: Bool
    let sendInputToBackend: (String, String, @escaping (String) -> Void) -> Void

    @State private var displayedText: String = ""
    @State private var isAnimatingText: Bool = false

    var body: some View {
        VStack {
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(gptResponse) { message in
                            HStack {
                                if message.isUser {
                                    Spacer()
                                    Text(message.text)
                                        .padding()
                                        .background(Color.blue.opacity(0.8))
                                        .cornerRadius(15)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
                                } else {
                                    Text(message.isPlaceholder ? displayedText : message.text)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(15)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                                    Spacer()
                                }
                            }
                            .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.leading)
                        }
                    }
                    .padding()
                }
                .onChange(of: gptResponse.count) { _ in
                    scrollView.scrollTo(gptResponse.last?.id, anchor: .bottom)
                }
            }

            Divider()

            HStack {
                TextField("请输入内容", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 36)
                    .padding(.leading, 8)

                Button(action: {
                    guard !userInput.isEmpty else { return }
                    let userMessage = Message(text: userInput, isUser: true)
                    gptResponse.append(userMessage)

                    let placeholderMessage = Message(text: "", isUser: false, isPlaceholder: true)
                    gptResponse.append(placeholderMessage)

                    triggerHapticFeedback()
                    isLoading = true
                    sendInputToBackend(selectedTab, userInput) { response in
                        handleAnimatedText(response: response)
                        userInput = ""
                        isLoading = false
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                        .padding()
                }
            }
            .padding()
        }
    }

    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func handleAnimatedText(response: String) {
        displayedText = ""
        isAnimatingText = true

        let characters = Array(response)
        var index = 0

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if index < characters.count {
                displayedText.append(characters[index])
                index += 1
            } else {
                timer.invalidate()
                isAnimatingText = false
                triggerHapticFeedback() // 结束后再振动
                if let placeholderIndex = gptResponse.firstIndex(where: { $0.isPlaceholder }) {
                    gptResponse[placeholderIndex] = Message(text: response, isUser: false)
                }
            }
        }
    }
}
struct TypingIndicator: View {
    @State private var dotCount = 0

    var body: some View {
        HStack {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .opacity(dotCount == index ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: dotCount)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                dotCount = (dotCount + 1) % 3
            }
        }
    }
}

struct ProfileOptionsView: View {
    @Binding var showHealthSurvey: Bool
    @State private var showHearingTest = false
    @State private var showLightAndPhoneUsageView = false
    @State private var showMedicationReminderView = false

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    NavigationLink(destination: HealthSurveyView()) {
                        VStack {
                            Text("自我档案")
                        }
                        .frame(width: UIScreen.main.bounds.width / 2 - 20, height: UIScreen.main.bounds.height / 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }

                    NavigationLink(destination: HearingTestView()) {
                        VStack {
                            Text("听力测试")
                        }
                        .frame(width: UIScreen.main.bounds.width / 2 - 20, height: UIScreen.main.bounds.height / 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
                .padding()

                HStack(spacing: 10) {
                    NavigationLink(destination: LightAndPhoneUsageView()) {
                        VStack {
                            Text("夜晚使用检测")
                        }
                        .frame(width: UIScreen.main.bounds.width / 2 - 20, height: UIScreen.main.bounds.height / 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }

                    NavigationLink(destination: MedicationReminderView()) {
                        VStack {
                            Text("药物提醒")
                        }
                        .frame(width: UIScreen.main.bounds.width / 2 - 20, height: UIScreen.main.bounds.height / 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("选择功能")
        }
    }
}

struct LoadingOverlayView: View {
    var body: some View {
        VStack {
            // 此处已删除加载符号和文本
        }
        .background(Color.white.opacity(0.8))
        .cornerRadius(10)
        .shadow(radius: 10)
    }
}
struct Message: Identifiable {
    let id = UUID()
    var text: String
    var isUser: Bool
    var isPlaceholder: Bool = false
    var timestamp: Date = Date() // 添加时间戳
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    var onSave: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let cameraViewController = VNDocumentCameraViewController()
        cameraViewController.delegate = context.coordinator
        return cameraViewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(recognizedText: $recognizedText, onSave: onSave)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        @Binding var recognizedText: String
        var onSave: () -> Void

        init(recognizedText: Binding<String>, onSave: @escaping () -> Void) {
            _recognizedText = recognizedText
            self.onSave = onSave
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
                if let observations = request.results as? [VNRecognizedTextObservation] {
                    self.recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                }
                self.onSave()
            }

            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            let handler = VNImageRequestHandler(cgImage: images.first!.cgImage!, options: [:])
            try? handler.perform([textRecognitionRequest])
            controller.dismiss(animated: true)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
