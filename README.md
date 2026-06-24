# MemeSaver 🖼️

An intelligent iOS application that analyzes text in chat screenshots and recommends relevant memes based on the conversation context. 

## 📖 Overview
MemeSaver bridges the gap between everyday conversations and meme culture. By leveraging on-device OCR and a Large Language Model (LLM), the app intelligently understands the context of a user's chat screenshot and suggests the most fitting memes to reply with. 

This project demonstrates a complete implementation of a modern iOS application, integrating local data management, native computer vision, and cloud-based AI.

## 🚀 Key Features
* **Intelligent Text Extraction**: Utilizes Apple's native Vision framework to perform fast and accurate Optical Character Recognition (OCR) on chat screenshots.
* **Contextual Meme Recommendation**: Integrates the Google Gemini API to analyze the extracted conversation context and perform semantic matching for meme suggestions.
* **Efficient Local Storage**: Manages the user's personal meme library using SwiftData, ensuring smooth performance and persistent data storage.
* **Modern & Responsive UI**: Built entirely with SwiftUI, featuring an intuitive interface for managing meme tags, categories, and viewing recommendations.

## 🛠️ Tech Stack
* **Language:** Swift
* **UI Framework:** SwiftUI
* **Local Database:** SwiftData
* **Machine Learning / OCR:** Apple Vision Framework
* **AI Integration:** Google Gemini API

## ⚙️ System Architecture Workflow
1. **Input:** The user imports a chat screenshot from their Photo Library.
2. **Processing (Local):** Vision Framework extracts the text contents from the image.
3. **Analysis (Cloud):** The extracted text is sent to the Gemini API as a prompt to analyze the conversational context and emotional tone.
4. **Retrieval (Local):** Based on the LLM's output keywords, the app queries the SwiftData database to find matching user-saved memes.
5. **Output:** The best-matched memes are displayed on the SwiftUI interface.

## 📱 Screenshots
<!-- 請在下方替換成你實際的 App 畫面截圖連結，你可以直接把截圖拖曳到 GitHub 的編輯框裡，它會自動生成網址 -->
<p align="center">
  <img src="<截圖1_網址>" width="250" alt="Home Screen">
  <img src="<截圖2_網址>" width="250" alt="Recommendation Screen">
  <img src="<截圖3_網址>" width="250" alt="Meme Library Screen">
</p>

## 💻 Requirements
* iOS 17.0+
* Xcode 15.0+

## 🔧 Installation & Setup
1. Clone the repository:
```bash
   git clone [https://github.com/yourusername/MemeSaver.git](https://github.com/yourusername/MemeSaver.git)
```

1. Open MemeSaver.xcodeproj in Xcode.
2. Add your Gemini API Key:
   Locate the configuration file or environment variables setup in the project.
   Insert your valid Google Gemini API Key.
5. Build and run the project on a simulator or a physical iOS device.
