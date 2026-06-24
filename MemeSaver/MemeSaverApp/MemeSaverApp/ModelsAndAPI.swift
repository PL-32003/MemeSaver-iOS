//
//  ModelsAndAPI.swift
//  MemeSaverApp
//
//  Created by Mac09 on 2026/5/29.
//

import SwiftUI
import SwiftData
import Foundation

// ==========================================
// MARK: - 1. 資料模型 (Models)
// ==========================================

@Model
class LocalDatabaseMeme {
    @Attribute(.unique) var id: String
    var imageUrl: String
    var name: String
    var memeKeywords: [String]
    var emotionKeywords: [String]
    var baseWeight: Double
    var isLiked: Bool
    
    init(id: String = UUID().uuidString, imageUrl: String, name: String, memeKeywords: [String], emotionKeywords: [String], baseWeight: Double = 1.0, isLiked: Bool = false) {
        self.id = id
        self.imageUrl = imageUrl
        self.name = name
        self.memeKeywords = memeKeywords
        self.emotionKeywords = emotionKeywords
        self.baseWeight = baseWeight
        self.isLiked = isLiked
    }
}

struct APIMemeAnalysis: Codable {
    let name: String
    let memeKeywords: [String]
    let emotionKeywords: [String]
    enum CodingKeys: String, CodingKey { case name, memeKeywords = "meme_keywords", emotionKeywords = "emotion_keywords" }
}

struct MemeRecommendationResponse: Codable {
    let contextAnalysis: ContextAnalysis
    let recommendations: [RecommendationItem]
    enum CodingKeys: String, CodingKey { case contextAnalysis = "context_analysis", recommendations }
}

struct ContextAnalysis: Codable {
    let detectedContext: String
    let emotionalTone: String
    let generalReason: String
    enum CodingKeys: String, CodingKey { case detectedContext = "detected_context", emotionalTone = "emotional_tone", generalReason = "general_reason" }
}

struct RecommendationItem: Codable, Identifiable {
    let id: String
    let name: String
    let imageUrl: String
    let matchWeight: Double
    enum CodingKeys: String, CodingKey { case id, name, imageUrl = "image_url", matchWeight = "match_weight" }
}

// ==========================================
// MARK: - 2. API 服務 (MemeAPIService)
// ==========================================

class MemeAPIService {
    // ⚠️ 執行前請務必填寫你申請的 Gemini API Key
    private let apiKey = ""
    private let apiUrl = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent")!
    
    func analyzeNewMeme(image: UIImage) async throws -> APIMemeAnalysis {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { throw URLError(.badServerResponse) }
        let prompt = """
        這是一張網路梗圖。請分析這張圖並以 JSON 格式回傳：
        1. "name": 取個簡短好笑的名稱（⚠️ 嚴格限制：絕對不能超過 6 個字）。
        2. "meme_keywords": 3-5個描述圖片物理特徵的英文或中文單字。
        3. "emotion_keywords": 3-5個描述適合表達情緒的詞彙。
        
        ⚠️ 嚴格全局限制：
        - 所有的字串值（包含 name 與 emotion_keywords）都必須強制使用【繁體中文 (Traditional Chinese, zh-TW)】輸出。
        - "name" 欄位的值長度【絕對不可以超過 6 個繁體中文字】。如果想到的名字太長，請縮減精煉。
        - 嚴格只回傳 JSON。
        """
        let payload = buildGeminiPayload(prompt: prompt, base64Image: imageData.base64EncodedString())
        let responseData = try await sendGeminiRequest(payload: payload)
        return try JSONDecoder().decode(APIMemeAnalysis.self, from: responseData)
    }
    
    func matchChatScreenshot(screenshot: UIImage, localDatabase: [LocalDatabaseMeme]) async throws -> MemeRecommendationResponse {
        guard let imageData = screenshot.jpegData(compressionQuality: 0.8) else { throw URLError(.badServerResponse) }
        struct AIPayload: Encodable { let id, name: String; let memeKeywords: [String]; let isLiked: Bool }
        let payload = localDatabase.map { AIPayload(id: $0.id, name: $0.name, memeKeywords: $0.memeKeywords, isLiked: $0.isLiked) }
        let dbJsonString = String(data: try JSONEncoder().encode(payload), encoding: .utf8) ?? "[]"
        
        // 🌟 包含了 LINE/Discord 判斷與要求最多 10 張的 Prompt
        let prompt = """
        這是一張通訊軟體的聊天室截圖（可能是 LINE 或 Discord）。
        請先仔細辨識截圖中的「對話結構」與「發言者身份」，再進行語意分析：
        
        【視覺解析規則】
        1. 如果是 LINE 格式：位於右側（通常是綠色）的對話框代表「使用者本人（我）」，位於左側（通常是白色）的對話框代表「對方」。
        2. 如果是 Discord 格式：所有訊息皆為靠左對齊。請先觀察「截圖最上方（標題列）的名稱或頭像」，該名稱即代表「聊天對象（對方）」。而在下方對話紀錄中出現的另一個名字，即代表「使用者本人（我）」。
        3. 請依序由上至下讀取對話，並正確理解其中的「文字訊息」、「檔案傳輸（如 PDF, PPTX 檔名）」、以及「語音通話紀錄」。忽略最上方的系統時間與電量等無關資訊。

        接著，我會提供你一份目前的【梗圖資料庫】：\(dbJsonString)。
        請根據上述規則還原出真實的對話脈絡後，執行任務並回傳指定的 JSON 格式：
        1. "context_analysis": 包含 "detected_context" (精準總結目前的對話情境與發生了什麼事), "emotional_tone" (判斷當下的情緒氛圍), "general_reason" (說明為何推薦這些梗圖)。
        2. "recommendations": 根據語境與資料庫 keywords 比對。
            - 計算 match_weight (0.0~1.0)。如果 "isLiked" 為 true，請額外加上 0.25 權重 (最高 1.0)。
            - 回傳包含 "id", "name", "image_url", "match_weight" 的陣列，依分數從大到小排序，【最多回傳 10 張】。絕對不要包含 isLiked 欄位。
                
        ⚠️ 嚴格全局限制：
        - 只回傳 match_weight 大於等於 0.1 的梗圖。如果資料庫中沒有任何符合此標準的梗圖，請直接回傳空陣列 []。
        - 所有的字串值（特別是 context_analysis 裡的所有內容）都必須強制使用【繁體中文 (Traditional Chinese, zh-TW)】輸出。
        - 嚴格只回傳 JSON 格式，不要加上任何 Markdown 標記 (如 ```json) 或其他說明文字。
        """
        
        let apiPayload = buildGeminiPayload(prompt: prompt, base64Image: imageData.base64EncodedString())
        
        let responseData = try await sendGeminiRequest(payload: apiPayload)
                
        // 🌟 雙層防護機制：字串清洗與解析
        guard let rawResponseString = String(data: responseData, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        let sanitizedString = cleanJSONString(rawResponseString)
                
        guard let sanitizedData = sanitizedString.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        do {
            return try JSONDecoder().decode(MemeRecommendationResponse.self, from: sanitizedData)
        } catch {
            print("❌ JSON 解析失敗，錯誤資訊：\\(error)")
            print("❌ 清洗後的字串長這樣：\n\\(sanitizedString)")
            throw error
        }
    }

    private func cleanJSONString(_ rawString: String) -> String {
        var cleaned = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        if let startIndex = cleaned.firstIndex(of: "{"),
            let endIndex = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIndex...endIndex])
        } else if let startIndex = cleaned.firstIndex(of: "["),
                let endIndex = cleaned.lastIndex(of: "]") {
            cleaned = String(cleaned[startIndex...endIndex])
        }
            
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func buildGeminiPayload(prompt: String, base64Image: String) -> [String: Any] {
        return ["contents": [["parts": [["text": prompt], ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]]]], "generationConfig": ["responseMimeType": "application/json"]]
    }
    
    private func sendGeminiRequest(payload: [String: Any]) async throws -> Data {
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { throw URLError(.badServerResponse) }
        if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let textData = (((jsonObject["candidates"] as? [[String: Any]])?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]])?.first?["text"] as? String {
            return textData.data(using: .utf8) ?? Data()
        }
        throw URLError(.cannotParseResponse)
    }
}
