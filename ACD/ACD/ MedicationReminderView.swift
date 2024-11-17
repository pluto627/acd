import SwiftUI
import Vision
import UserNotifications
import VisionKit

struct MedicationReminderView: View {
    @State private var reminders: [MedicationReminder] = []
    @State private var newMedicationName: String = ""
    @State private var dailyDoses: Int = 1
    @State private var doseTimes: [Date] = []
    @State private var currentStep: Step = .listView
    @State private var isShowingOptions = false
    @State private var isShowingCamera = false
    @State private var recognizedText: String = ""

    enum Step {
        case listView, nameEntry, doseEntry, timeEntry
    }

    var body: some View {
        NavigationView {
            VStack {
                switch currentStep {
                case .listView:
                    ListView(reminders: $reminders)
                case .nameEntry:
                    MedicationNameEntryView(newMedicationName: $newMedicationName, onNext: {
                        currentStep = .doseEntry
                    })
                case .doseEntry:
                    DailyDoseEntryView(dailyDoses: $dailyDoses, onNext: {
                        currentStep = .timeEntry
                    })
                case .timeEntry:
                    DoseTimeEntryView(dailyDoses: $dailyDoses, doseTimes: $doseTimes, onSave: saveNewMedication)
                }
            }
            .navigationTitle("药物提醒")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingOptions = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue) // 添加颜色以增强视觉感
                    }
                    .actionSheet(isPresented: $isShowingOptions) {
                        ActionSheet(
                            title: Text("添加药物"),
                            buttons: [
                                .default(Text("拍照添加")) { isShowingCamera = true },
                                .default(Text("手动输入")) { currentStep = .nameEntry },
                                .cancel()
                            ]
                        )
                    }
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraView1(recognizedText: $recognizedText, onRecognize: handleRecognizedText)
            }
            .alert(isPresented: Binding<Bool>(
                get: { !recognizedText.isEmpty },
                set: { if !$0 { recognizedText = "" } }
            )) {
                Alert(
                    title: Text("OCR 结果"),
                    message: Text(recognizedText),
                    primaryButton: .default(Text("确认"), action: {
                        newMedicationName = recognizedText
                        currentStep = .timeEntry
                    }),
                    secondaryButton: .cancel(Text("手动填写")) {
                        currentStep = .doseEntry
                    }
                )
            }
        }
        .onAppear {
            loadReminders()
        }
    }

    private func saveNewMedication() {
        guard !newMedicationName.isEmpty else { return }
        let newReminder = MedicationReminder(name: newMedicationName, doseTimes: doseTimes)
        reminders.append(newReminder)
        saveReminders()
        for time in doseTimes {
            scheduleMedicationNotification(reminder: newReminder, time: time)
        }
        resetInputs()
    }

    private func resetInputs() {
        newMedicationName = ""
        dailyDoses = 1
        doseTimes = []
        currentStep = .listView
    }

    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: "medicationReminders")
        }
    }

    private func loadReminders() {
        if let data = UserDefaults.standard.data(forKey: "medicationReminders"),
           let savedReminders = try? JSONDecoder().decode([MedicationReminder].self, from: data) {
            reminders = savedReminders
        }
    }

    private func scheduleMedicationNotification(reminder: MedicationReminder, time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "药物提醒"
        content.body = "请服用 '\(reminder.name)'"
        content.sound = .default

        let trigger = Calendar.current.dateComponents([.hour, .minute], from: time)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true))
        UNUserNotificationCenter.current().add(request)
    }

    private func handleRecognizedText(_ text: String) {
        recognizedText = text
    }
}

struct MedicationReminder: Identifiable, Codable {
    let id = UUID()
    let name: String
    let doseTimes: [Date]
}

// Step 1: 列表显示药物
struct ListView: View {
    @Binding var reminders: [MedicationReminder]

    var body: some View {
        List {
            ForEach(reminders) { reminder in
                HStack {
                    Text(reminder.name)
                        .font(.title2)
                        .foregroundColor(.primary) // 主文字颜色
                    Spacer()
                    Text("次数: \(reminder.doseTimes.count)")
                        .foregroundColor(.secondary) // 辅助文字颜色
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1))) // 背景和圆角
            }
            .onDelete(perform: deleteReminder)
        }
        .listStyle(PlainListStyle())
        .background(Color(UIColor.systemBackground)) // 适配浅色/深色模式
    }

    private func deleteReminder(at offsets: IndexSet) {
        reminders.remove(atOffsets: offsets)
        saveReminders()
    }

    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: "medicationReminders")
        }
    }
}

// Step 2: 输入药物名称
struct MedicationNameEntryView: View {
    @Binding var newMedicationName: String
    var onNext: () -> Void

    var body: some View {
        VStack {
            TextField("请输入药物名称", text: $newMedicationName)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)))
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarItems(trailing: Button("下一步") {
            if !newMedicationName.isEmpty {
                onNext()
            }
        })
    }
}

// Step 3: 输入每日服用次数
struct DailyDoseEntryView: View {
    @Binding var dailyDoses: Int
    var onNext: () -> Void

    var body: some View {
        VStack {
            Stepper("每日服用次数: \(dailyDoses)", value: $dailyDoses, in: 1...10)
                .padding()
                .foregroundColor(.primary)
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarItems(trailing: Button("下一步") {
            onNext()
        })
    }
}

// Step 4: 输入每次服用时间
struct DoseTimeEntryView: View {
    @Binding var dailyDoses: Int
    @Binding var doseTimes: [Date]
    var onSave: () -> Void

    var body: some View {
        VStack {
            ForEach(0..<dailyDoses, id: \.self) { index in
                DatePicker("时间 \(index + 1)", selection: Binding(
                    get: { doseTimes.count > index ? doseTimes[index] : Date() },
                    set: { if doseTimes.count > index { doseTimes[index] = $0 } else { doseTimes.append($0) } }
                ), displayedComponents: .hourAndMinute)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarItems(leading: Button("返回") {
            doseTimes.removeAll()
        }, trailing: Button("保存") {
            onSave()
        })
    }
}

// Camera View for OCR
struct CameraView1: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    var onRecognize: (String) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: CameraView1

        init(_ parent: CameraView1) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var recognizedStrings: [String] = []
            let textRecognitionWorkQueue = DispatchQueue(label: "TextRecognitionQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
            textRecognitionWorkQueue.async { [weak self] in
                guard let self = self else { return }
                for pageIndex in 0..<scan.pageCount {
                    let image = scan.imageOfPage(at: pageIndex)
                    if let recognizedString = self.recognizeTextInImage(image) {
                        recognizedStrings.append(recognizedString)
                    }
                }
                DispatchQueue.main.async {
                    self.parent.recognizedText = recognizedStrings.joined(separator: "\n")
                    self.parent.onRecognize(self.parent.recognizedText)
                }
            }
        }

        func recognizeTextInImage(_ image: UIImage) -> String? {
            // Add your OCR text recognition logic here
            return "示例药物名称"
        }
    }
}

struct MedicationReminderView_Previews: PreviewProvider {
    static var previews: some View {
        MedicationReminderView()
    }
}
