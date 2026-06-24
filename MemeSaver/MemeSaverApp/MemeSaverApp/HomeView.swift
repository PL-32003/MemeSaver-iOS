//
//  HomeView.swift
//  MemeSaverApp
//
//  Created by Mac09 on 2026/5/29.
//

import SwiftUI
import SwiftData // 🌟 記得要 import SwiftData

struct HomeView: View {
    @State private var showMatchSheet = false
    @State private var showUploadSheet = false
    @State private var showDeleteSheet = false
    
    // 🌟 1. 取得 SwiftData 環境與資料庫裡的梗圖
    @Environment(\.modelContext) private var modelContext
    @Query private var allMemes: [LocalDatabaseMeme]
    
    let backgroundColor = Color(hex: "D3CFD6")
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("MemeSaver")
                    .font(.system(size: 56, weight: .bold))
                    .italic()
                    .foregroundColor(.black)
                    .padding(.top, 40)
                
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        HomeMenuButton(
                            title: "Read Message\nScreenshot", imageName: "ReadIcon",
                            isSelected: showMatchSheet, action: { showMatchSheet = true }
                        )
                        HomeMenuButton(
                            title: "Upload Meme\nto Database", imageName: "UploadIcon",
                            isSelected: showUploadSheet, action: { showUploadSheet = true }
                        )
                    }
                    HomeMenuButton(
                        title: "Delete Meme", imageName: "DeleteIcon",
                        isSelected: showDeleteSheet, action: { showDeleteSheet = true }
                    )
                }
                .padding(.horizontal)
                Spacer()
            }
        }
        .sheet(isPresented: $showMatchSheet, onDismiss: {
            preloadDefaultMemesIfNeeded()
        }) {
            MatchTestView().presentationDetents([.medium, .large]).presentationDragIndicator(.hidden).presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showUploadSheet, onDismiss: {
            preloadDefaultMemesIfNeeded()
        }) {
            UploadTestView().presentationDetents([.medium, .large]).presentationDragIndicator(.hidden).presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showDeleteSheet, onDismiss: {
            preloadDefaultMemesIfNeeded() // 🌟 關鍵在這裡：當刪除視窗關閉時，立刻檢查是否需要補血！
        }) {
            DeleteMemeView().presentationDetents([.medium, .large]).presentationDragIndicator(.hidden).presentationContentInteraction(.scrolls)
        }
        .onAppear {
            preloadDefaultMemesIfNeeded()
        }
    }
    
    // ==========================================
    // 🌟 3. 自動預載預設梗圖的邏輯
    // ==========================================
    private func preloadDefaultMemesIfNeeded() {
        guard allMemes.isEmpty else { return }
        
        print("📥 偵測到資料庫為空，開始載入預設梗圖...")
        
        let defaultMemesData: [(name: String, memeKeywords: [String], emotionKeywords: [String], imageName: String)] = [
            (name: "愛心眼狂粉", 
             memeKeywords: ["粉髮女孩", "愛心眼", "雙手緊握", "MyGO"], 
             emotionKeywords: ["狂熱", "喜悅", "崇拜", "心動", "太棒了"], 
             imageName: "1"),
            
            (name: "真的太好了", 
             memeKeywords: ["棕髮女孩", "微笑", "陽光", "MyGO"], 
             emotionKeywords: ["欣慰", "開心", "安心", "太好了"], 
             imageName: "2"),
            
            (name: "我不參加", 
             memeKeywords: ["紫髮女孩", "眼神迴避", "粉髮女孩", "MyGO"], 
             emotionKeywords: ["拒絕", "冷漠", "逃避", "不想理", "抗拒"], 
             imageName: "3"),
            
            (name: "真心抱歉", 
             memeKeywords: ["白髮女孩", "低頭", "悲傷表情", "MyGO"], 
             emotionKeywords: ["道歉", "愧疚", "難過", "委屈"], 
             imageName: "4"),
            
            (name: "我考慮一下", 
             memeKeywords: ["粉髮女孩", "閉眼笑", "MyGO"], 
             emotionKeywords: ["敷衍", "婉拒", "尷尬", "拖延", "打哈哈"], 
             imageName: "5"),
            
            (name: "給我振作點", 
             memeKeywords: ["藍髮女孩", "生氣", "低頭的人", "MyGO"], 
             emotionKeywords: ["鼓勵", "生氣", "激動", "叫醒", "恨鐵不成鋼"], 
             imageName: "6"),
            
            (name: "真是受不了", 
             memeKeywords: ["粉髮女孩", "人群", "無奈表情", "MyGO"], 
             emotionKeywords: ["無奈", "煩躁", "受不了", "嘆氣", "心累"], 
             imageName: "7"),
            
            (name: "我想也是", 
             memeKeywords: ["紫髮女孩", "側臉", "桌子", "MyGO"], 
             emotionKeywords: ["妥協", "失望", "預料之中", "無奈", "果然如此"], 
             imageName: "8"),
            
            (name: "柚餅子", 
             memeKeywords: ["白髮女孩", "異色瞳", "吉他音箱", "呆滯", "MyGO"], 
             emotionKeywords: ["發呆", "問號", "肚子餓", "不知所措", "裝傻"], 
             imageName: "9"),
            
            (name: "我不配當人", 
             memeKeywords: ["藍髮女孩", "彎腰", "沮喪", "背影", "MyGO"], 
             emotionKeywords: ["極度自責", "崩潰", "絕望", "後悔", "想死"], 
             imageName: "10")
        ]
        
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        for item in defaultMemesData {
            if let image = UIImage(named: item.imageName),
               let imageData = image.jpegData(compressionQuality: 0.8) {
                
                let fileName = UUID().uuidString + ".jpg"
                let fileURL = documentDirectory.appendingPathComponent(fileName)
                
                do {
                    try imageData.write(to: fileURL)
                    
                    let newMeme = LocalDatabaseMeme(
                        imageUrl: fileName,
                        name: item.name,
                        memeKeywords: item.memeKeywords,
                        emotionKeywords: item.emotionKeywords,
                        baseWeight: 1.0,
                        isLiked: false
                    )
                    
                    modelContext.insert(newMeme)
                } catch {
                    print("❌ 圖片 \(item.imageName) 寫入失敗：\(error)")
                }
            }
        }
        
        do {
            try modelContext.save()
            print("✅ 預設梗圖載入完成！")
        } catch {
            print("❌ 預設梗圖儲存失敗：\(error)")
        }
    }
}

// ---------------- 以下保持原本的按鈕與顏色擴充 ---------------- //

struct HomeMenuButton: View {
    let title: String
    let imageName: String
    var isSelected: Bool = false
    
    let selectedBgColor = Color(hex: "C6B7E2")
    let selectedTextColor = Color(hex: "6B1B8A")
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                Image(imageName).resizable().scaledToFit().frame(width: 120, height: 120)
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? selectedTextColor : .black)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 170, height: 220)
            .background(isSelected ? selectedBgColor : Color(hex: "F3F3F3"))
            .cornerRadius(25)
            .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(isSelected ? selectedTextColor : Color.clear, lineWidth: 3))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}