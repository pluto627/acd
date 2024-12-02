from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from openai import OpenAI
import jwt
import math
import pandas as pd
from datetime import datetime, timedelta
import re
import os
from flask_cors import CORS
import openai
from pathlib import Path
import whisper

app = Flask(__name__)
CORS(app)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///medical_app.db'
app.config['SECRET_KEY'] = 'your-secret-key-here'
app.config['UPLOAD_FOLDER'] = 'audio_uploads'
db = SQLAlchemy(app)

# 确保上传文件夹存在
Path(app.config['UPLOAD_FOLDER']).mkdir(parents=True, exist_ok=True)

app.config['JSON_AS_ASCII'] = False

client = OpenAI(
    api_key = "sk-UWxnGIMxYh98QeNva9mmh9aQbA82OychmCPbD3kw4cMjR46z",
    base_url = "https://api.fe8.cn/v1"
)

# 初始化Whisper模型
whisper_model = whisper.load_model("base")

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    health_data = db.Column(db.JSON)
    medication_reminders = db.Column(db.JSON)
    hearing_test_results = db.Column(db.JSON)
    sleep_reports = db.Column(db.JSON)
    chat_history = db.Column(db.JSON, default=list)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

def chat_with_openai(prompt, model="gpt-4o"):
    try:
        chat_completion = client.chat.completions.create(
            messages=[{"role": "user", "content": prompt}],
            model=model,
            temperature=0.7,
            max_tokens=2000
        )
        return process_response_text(chat_completion.choices[0].message.content)
    except Exception as e:
        print(f"OpenAI API Error: {e}")
        return "抱歉，服务暂时出现问题，请稍后再试。"

def process_response_text(text):
    if not text:
        return ""
    # 清理Markdown标记和特殊字符，但保留基本格式
    text = text.replace('#', '').replace('*', '')
    return text.strip()

def require_auth(f):
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'No token provided'}), 401
        try:
            payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            request.user_id = payload['user_id']
            return f(*args, **kwargs)
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
    return decorated

@app.route('/audio_transcribe', methods=['POST'])
def audio_transcribe():
    try:
        if 'audio' not in request.files:
            return jsonify({'error': 'No audio file provided'}), 400
        
        audio_file = request.files['audio']
        if audio_file.filename == '':
            return jsonify({'error': 'No selected file'}), 400
        
        # 保存音频文件
        filename = os.path.join(app.config['UPLOAD_FOLDER'], 
                              datetime.now().strftime('%Y%m%d_%H%M%S.m4a'))
        audio_file.save(filename)
        
        # 使用Whisper进行语音识别
        result = whisper_model.transcribe(filename)
        transcribed_text = result["text"]
        
        # 使用GPT生成医嘱总结
        summary_prompt = f"""作为一名专业的医生，请对以下医嘱内容进行分析和总结：

1. 核心诊断：提取关键的诊断信息
2. 用药建议：总结主要的用药指导
3. 生活建议：提炼重要的生活注意事项
4. 后续跟进：归纳后续就医或观察建议

患者描述/医嘱内容：{transcribed_text}

请用简洁、清晰的语言总结，确保信息准确且易于理解。"""
        
        summary = chat_with_openai(summary_prompt)
        
        # 清理临时文件
        os.remove(filename)
        
        return jsonify({
            'transcription': transcribed_text,
            'summary': summary
        })
        
    except Exception as e:
        print(f"Error in audio_transcribe: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/condition_chat', methods=['POST'])
def condition_chat():
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data received'}), 400
        
        message = data.get('message')
        if not message:
            return jsonify({'error': 'No message provided'}), 400
        
        # 医疗建议分析提示词
        analysis_prompt = f"""你现在是一名专业的医生，请对以下内容进行分析和建议：

1. 症状分析：请分析描述的症状
2. 可能的原因：列出可能导致这些症状的常见原因
3. 初步建议：提供可以在家尝试的缓解方法
4. 生活建议：给出日常生活中的注意事项和预防措施
5. 就医建议：说明在什么情况下需要及时就医

患者描述：{message}

请用专业、易懂的语言回答，注意平衡专业性和可理解性。"""

        response = chat_with_openai(analysis_prompt)
        return jsonify({'response': response})
    
    except Exception as e:
        print(f"Error in condition_chat: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/medicine_chat', methods=['POST'])
def medicine_chat():
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data received'}), 400
        
        message = data.get('message')
        if not message:
            return jsonify({'error': 'No message provided'}), 400
        
        # 药物咨询提示词
        medicine_prompt = f"""作为一名专业的药剂师，请对以下用药问题进行解答：

1. 用药分析：分析患者的用药问题
2. 用药建议：提供正确的服药方法和注意事项
3. 药物相互作用：说明是否存在药物相互作用风险
4. 副作用提示：告知可能的副作用和应对方法
5. 特殊提醒：针对特殊人群（如孕妇、儿童、老年人）的用药建议

患者问题：{message}

请用专业且通俗的语言回答，确保患者能够理解。"""

        response = chat_with_openai(medicine_prompt)
        return jsonify({'response': response})
    
    except Exception as e:
        print(f"Error in medicine_chat: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/psychology_chat', methods=['POST'])
def psychology_chat():
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data received'}), 400
        
        message = data.get('message')
        if not message:
            return jsonify({'error': 'No message provided'}), 400
        
        # 心理咨询提示词
        psychology_prompt = f"""作为一名专业的心理咨询师，请提供以下帮助：

1. 情感理解：体现对来访者感受的理解和共情
2. 问题分析：对心理困扰进行专业分析
3. 建议指导：提供具体可行的调适建议
4. 资源推荐：推荐合适的心理健康资源
5. 预防建议：预防类似问题再次发生的建议

来访者描述：{message}

请用温和、专业的语言回应，注重建立信任感。"""

        response = chat_with_openai(psychology_prompt)
        return jsonify({'response': response})
    
    except Exception as e:
        print(f"Error in psychology_chat: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5001, debug=True)