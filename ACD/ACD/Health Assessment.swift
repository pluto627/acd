 import SwiftUI
import Foundation

struct HealthSurveyView: View {
    @State private var currentPage = 0
    @State private var userInput = UserInput()
    @State private var response: String = ""
    @State private var showResponse = false

    let questions = [
        "你多大了？",
        "你是什么性别？(男/女)",
        "你的收缩压是多少?",
        "你的舒张压是多少",
        "你的体重是多少？"
    ]

    var body: some View {
        VStack {
            if showResponse {
                    Text(response)
                        .padding()
            } else {
                Text(questions[currentPage])
                    .font(.title2)
                    .padding()
                Picker(selection: Binding(
                    get: { userInput[currentPage] },
                    set: { userInput[currentPage] = $0 }
                ), label: Text("Select your answer")) {
                    ForEach(generateOptions(for: currentPage), id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .padding()
                Button(action: {
                    if currentPage < questions.count - 1 {
                        currentPage += 1
                    } else {
                        sendDataToServer()
                    }
                }) {
                    Text(currentPage < questions.count - 1 ? "下一步" : "提交")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }

    func sendDataToServer() {
        guard let url = URL(string: "http://192.168.1.25:5002/chat") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 将数据转换为合适的类型
        let json: [String: Any] = [
            "age": Int(userInput.age) ?? 0,
            "gender": userInput.gender,
            "systolic_bp": Int(userInput.systolicBP) ?? 0,
            "diastolic_bp": Int(userInput.diastolicBP) ?? 0,
            "weight": Int(userInput.weight.replacingOccurrences(of: " kg", with: "")) ?? 0
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
            request.httpBody = jsonData
        } catch {
            print("Error serializing JSON: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let gptResponse = json["response"] as? String {
                    DispatchQueue.main.async {
                        self.response = gptResponse
                        self.showResponse = true
                    }
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }.resume()
    }

    func generateOptions(for questionIndex: Int) -> [String] {
        switch questionIndex {
        case 0:
            return (1...100).map { "\($0)" }
        case 1:
            return ["男", "女"]
        case 2, 3:
            return (50...200).map { "\($0)" }
        case 4:
            return (30...150).map { "\($0) kg" }
        default:
            return []
        }
    }
}

struct UserInput {
    var age = ""
    var gender = ""
    var systolicBP = ""
    var diastolicBP = ""
    var weight = ""

    subscript(index: Int) -> String {
        get {
            switch index {
            case 0: return age
            case 1: return gender
            case 2: return systolicBP
            case 3: return diastolicBP
            case 4: return weight
            default: return ""
            }
        }
        set {
            switch index {
            case 0: age = newValue
            case 1: gender = newValue
            case 2: systolicBP = newValue
            case 3: diastolicBP = newValue
            case 4: weight = newValue
            default: break
            }
        }
    }
}

struct HealthSurveyView_Previews: PreviewProvider {
    static var previews: some View {
        HealthSurveyView()
    }
}
