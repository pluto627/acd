from flask import Flask, request, jsonify
from openai import OpenAI

app = Flask(__name__)

client = OpenAI(
    api_key="sk-atlcBwX24klYutsuVqWgkrZMbbFFDNkmJp6wYxbtBzfSDsMS",
    base_url="https://api.fe8.cn/v1"
)

def chat_with_openai(prompt, model="gpt-4o"):
    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": prompt,
            }
        ],
        model=model,
    )
    return chat_completion.choices[0].message.content


def generate_prompt(context_type, user_question):
    if context_type == "medication":
        system_message = "你现在是一个家庭医生，你可以做一些药物和食物的判断，提供药物建议，告诉药物的使用方法和说明，并且告诉我什么药物或者食物可能会有雨这个药物有冲突。"
    elif context_type == "condition":
        system_message = "你现在是一个家庭医生，你可以帮助用户对病情进行简单判断，提供应对措施的建议。"
    elif context_type == "camera":
        system_message = "你现在是一名家庭医生，可以对用户上传的文档内容进行分析，并提供针对药物和病理的建议。如果用户上传的是药物名称或说明书，帮助解释药物用途、推荐用法、剂量和注意事项；如果用户上传的是病理分析报告或化验单，则解释关键指标，识别异常数据，并提供后续治疗建议或健康管理的建议。"
    else:
        system_message = ""
    return system_message + user_question


@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json()
    context_type = data.get('context_type')
    user_question = data.get('user_question')
    prompt = generate_prompt(context_type, user_question)
    response = chat_with_openai(prompt)
    return jsonify({"response": response})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)