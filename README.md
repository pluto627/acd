```markdown
# ACDoctor - 智能医疗咨询助手

## 项目介绍

ACDoctor是一款基于SwiftUI和Flask开发的医疗咨询应用。它提供用药提醒、病情咨询、处方扫描、听力测试和心理咨询等功能。

## 主要功能

- **用药提醒**: 智能药品管理、定时提醒、药品扫描
- **病情咨询**: AI辅助诊断、专业建议
- **处方扫描**: OCR识别、用药建议
- **听力测试**: 专业听力评估、建议报告
- **心理咨询**: 智能心理咨询师、情感支持

## 技术栈

### 前端
- SwiftUI
- Combine
- Vision框架
- UserNotifications

### 后端
- Flask
- OpenAI API
- SQLAlchemy
- JWT认证
- pandas

## 安装和使用

1. 克隆仓库
```bash
git clone [repository-url]
```

2. 安装依赖
```bash
pip install -r requirements.txt
```

3. 配置环境变量
```bash
export OPENAI_API_KEY="your-api-key"
```

4. 运行后端服务
```bash
python acd.py
```

5. 运行iOS应用

在Xcode中打开项目并运行。

## API接口

- `/auth`: 用户认证
- `/chat`: 通用对话
- `/medicine_chat`: 药品咨询
- `/condition_chat`: 病情咨询
- `/psychology_chat`: 心理咨询
- `/hearing_test`: 听力测试

## 声明

本项目仅供学习参考，不可用于实际医疗诊断。请遵医嘱进行治疗。
```
