from flask import Flask, request, jsonify
from openai import OpenAI

app = Flask(__name__)

client = OpenAI(
    api_key='sk-UWxnGIMxYh98QeNva9mmh9aQbA82OychmCPbD3kw4cMjR46z',
    base_url='https://api.fe8.cn/v1'
)

def evaluate_health_data(age, gender, systolic_bp, diastolic_bp, weight):
    # 1. Evaluate Blood Pressure
    if age <= 12:
        bp_status = 'Normal' if 90 <= systolic_bp <= 110 and 55 <= diastolic_bp <= 75 else 'Abnormal'
    elif 13 <= age <= 18:
        bp_status = 'Normal' if 110 <= systolic_bp <= 135 and 65 <= diastolic_bp <= 85 else 'Abnormal'
    elif age > 60:
        bp_status = 'Normal' if systolic_bp < 150 and diastolic_bp < 90 else 'Abnormal'
    else:
        if systolic_bp < 120 and diastolic_bp < 80:
            bp_status = 'Normal'
        elif 120 <= systolic_bp <= 139 or 80 <= diastolic_bp <= 89:
            bp_status = 'Pre-hypertension'
        elif 140 <= systolic_bp <= 159 or 90 <= diastolic_bp <= 99:
            bp_status = 'Stage 1 Hypertension'
        else:
            bp_status = 'Stage 2 Hypertension'

    # Summary Report
    report = {
        'Age': age,
        'Gender': gender,
        'Blood Pressure Status': bp_status,
        'Weight': weight
    }

    return report

def generate_health_report(report):
    summary = "Here is your health evaluation report:\n"
    for key, value in report.items():
        summary += f"- {key}: {value}\n"
    summary += "\n如果上述任何指标不正常，请咨询医疗保健专业人员以获得进一步指导。56"
    return summary

def send_report_to_gpt(report):
    prompt = f"请提供对以下健康评估报告的分析:\n{generate_health_report(report)}"

    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": prompt,
            }
        ],
        model="gpt-4o"
    )
    return chat_completion.choices[0].message.content

@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json()
    print(f"Received data: {data}")

    # 验证输入是否有效
    try:
        age = int(data.get('年龄', 0))  # 如果没有提供 'age'，则使用默认值 0
        gender = data.get('gender', '不知道')
        systolic_bp = int(data.get('舒张压', 0))
        diastolic_bp = int(data.get('收缩压', 0))
        weight = int(data.get('体重', 0))
    except ValueError:
        return jsonify({"error": "Invalid input data. Please provide numeric values for age, systolic_bp, diastolic_bp, and weight."}), 400

    # 继续处理请求
    report = evaluate_health_data(age, gender, systolic_bp, diastolic_bp, weight)
    gpt_analysis = send_report_to_gpt(report)
    return jsonify({"response": gpt_analysis})



if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002)