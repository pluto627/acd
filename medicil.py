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
    if context_type == "usage":
        system_message = "你现在是一名家庭医生，这个药物的使用方式是什么（用最精简的话告诉我） "
    elif context_type == "frequency":
        system_message = "你现在是一名家庭医生，请你告诉我这个药物每天使用几次并且在什么时候使用"
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
    app.run(host='0.0.0.0', port=5003)
