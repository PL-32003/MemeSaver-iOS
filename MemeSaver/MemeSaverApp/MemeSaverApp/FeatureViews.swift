//
//  FeatureViews.swift
//  MemeSaverApp
//
//  Created by Mac09 on 2026/5/29.
//

import SwiftUI
import SwiftData
import Photos

// ==========================================
// MARK: - 共用元件：自訂頂部拖曳控制條
// ==========================================
struct CustomDragHandle: View {
    var body: some View {
        Capsule()
            .fill(Color.gray.opacity(0.4))
            .frame(width: 40, height: 5)
            // 🌟 這裡完美控制橫條的上下間距，讓它視覺置中
            .padding(.top, 16)
            .padding(.bottom, 16)
    }
}

// ==========================================
// MARK: - 功能一：截圖配對頁面 (MatchTestView)
// ==========================================
struct MatchTestView: View {
    @Query private var allMemes: [LocalDatabaseMeme]
    @State private var apiResponse: MemeRecommendationResponse? = nil
    @State private var isProcessing: Bool = false
    @State private var statusText: String = "正在讀取最新截圖..."
    @State private var currentScreenshot: UIImage? = nil
    @State private var showSecondBatch: Bool = false
    let apiService = MemeAPIService()
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "E5DFEA").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 🌟 置入自訂的控制橫條
                CustomDragHandle()
                
                if isProcessing {
                    VStack(spacing: 15) { ProgressView().scaleEffect(1.5); Text(statusText).foregroundColor(.gray) }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 108)
                } else if let response = apiResponse {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("分析結果 / 分析摘要").font(.title2).bold().foregroundColor(.black)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("💬 語境分析：\(response.contextAnalysis.detectedContext)")
                                    Text("🎭 情緒氛圍：\(response.contextAnalysis.emotionalTone)")
                                    Text("💡 推薦理由：\(response.contextAnalysis.generalReason)")
                                }.font(.body).foregroundColor(Color(hex: "555555")).lineSpacing(4)
                            }.padding(.horizontal, 20)
                            
                            if response.recommendations.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundColor(.gray.opacity(0.5))
                                    Text("目前資料庫中沒有適合這段語境的梗圖\n趕快去上傳一些吧！").font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
                                }.frame(maxWidth: .infinity).padding(.top, 40)
                            } else {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    let displayItems = showSecondBatch 
                                        ? Array(response.recommendations.dropFirst(5).prefix(5)) 
                                        : Array(response.recommendations.prefix(5))

                                    ForEach(displayItems) { item in 
                                        MemeGridCell(item: item) 
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            Spacer().frame(height: 130)
                        }
                    }
                } else { VStack { Text(statusText).foregroundColor(.red) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            
            VStack {
                let hasMoreThanFive = (apiResponse?.recommendations.count ?? 0) > 5
                
                Button(action: { 
                    withAnimation { showSecondBatch.toggle() } 
                }) {
                    Text(showSecondBatch ? "Show Previous" : "Suggest More")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "6B1B8A"))
                        .frame(width: 350, height: 70)
                        .background(Color(hex: "C6B7E2"))
                        .cornerRadius(25)
                }
                .disabled(isProcessing || !hasMoreThanFive)
                .opacity((isProcessing || !hasMoreThanFive) ? 0.5 : 1.0)                
            }
            .frame(maxWidth: .infinity)
            .frame(height: 108)
            .background(Color(hex: "F3F3F3"))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: -2)
        }.onAppear { Task { await fetchLatestPhotoAndAnalyze() } }
    }
    
    private func fetchLatestPhotoAndAnalyze() async {
        isProcessing = true; statusText = "正在讀取最新照片..."
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { statusText = "無相簿權限"; isProcessing = false; return }
        
        let fetchOptions = PHFetchOptions(); fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        guard let latestAsset = PHAsset.fetchAssets(with: .image, options: fetchOptions).firstObject else { statusText = "相簿中沒有照片"; isProcessing = false; return }
        
        let requestOptions = PHImageRequestOptions(); requestOptions.isSynchronous = false; requestOptions.deliveryMode = .highQualityFormat
        PHImageManager.default().requestImage(for: latestAsset, targetSize: CGSize(width: 1024, height: 1024), contentMode: .aspectFit, options: requestOptions) { image, _ in
            guard let validImage = image else { statusText = "無法讀取圖片"; isProcessing = false; return }
            self.currentScreenshot = validImage
            Task { await analyzeScreenshot(image: validImage, isSuggestMore: false) }
        }
    }
    
    private func analyzeScreenshot(image: UIImage, isSuggestMore: Bool) async {
        await MainActor.run { 
            self.isProcessing = true
            self.statusText = "Gemini 正在分析對話語境..." 
            self.showSecondBatch = false
        }
        do {
            let result = try await apiService.matchChatScreenshot(screenshot: image, localDatabase: allMemes)
            await MainActor.run { self.apiResponse = result; self.isProcessing = false }
        } catch { await MainActor.run { self.statusText = "API 分析失敗"; self.isProcessing = false } }
    }
}

// ==========================================
// MARK: - 網格內單個梗圖元件 (優化上下間距版)
// ==========================================
struct MemeGridCell: View {
    let item: RecommendationItem
    @Environment(\.modelContext) private var modelContext
    @Query private var allMemes: [LocalDatabaseMeme]
    @State private var copyFeedback: Bool = false
    
    private func getFullImagePath(from fileName: String) -> String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName).path
    }
    
    var body: some View {
        let localMeme = allMemes.first(where: { $0.id == item.id })
        let isLiked = localMeme?.isLiked ?? false
        let realFileName = localMeme?.imageUrl ?? ""
        
        // 🌟 將原本預設的 spacing 設為 0，改用 Spacer 精確控制留白
        VStack(spacing: 0) {
            
            // 1. 頂部留白：把標題往下推
            Spacer().frame(height: 14)
            
            Text("Meme: \(item.name)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
            
            // 2. 標題與圖片的間距
            Spacer().frame(height: 8)
            
            if !realFileName.isEmpty, let uiImage = UIImage(contentsOfFile: getFullImagePath(from: realFileName)) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 149, height: 110) // 保持你設計的完美圖片比例
                    .cornerRadius(25)
                    .clipped()
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.black.opacity(0.8), lineWidth: 1.5))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 149, height: 110)
                    .cornerRadius(25)
                    .overlay(Text("遺失").font(.caption))
            }
            
            // 3. 圖片與按鈕的間距
            Spacer().frame(height: 8)
            
            HStack(spacing: 20) {
                // 稍微縮小按鈕內部的間距 (從 4 變 2)
                VStack(spacing: 2) {
                    Button(action: { localMeme?.isLiked.toggle() }) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isLiked ? Color(hex: "6B1B8A") : .white)
                            // 🌟 圓形按鈕稍微縮小至 40，騰出空間給底部留白
                            .frame(width: 40, height: 40)
                            .background(isLiked ? Color(hex: "C6B7E2") : Color(hex: "B4B2B2"))
                            .clipShape(Circle())
                    }
                    Text("Favorite").font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                }
                VStack(spacing: 2) {
                    Button(action: { copyMemeToClipboard(fileName: realFileName) }) {
                        Image(systemName: copyFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(copyFeedback ? Color.green : Color(hex: "B4B2B2"))
                            .clipShape(Circle())
                    }
                    Text("Copy").font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                }
            }
            
            // 4. 底部留白：把按鈕往上推
            Spacer().frame(height: 14)
        }
        .frame(width: 170, height: 210) // 🌟 維持整張卡片的總大小不變
        .background(Color.white)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func copyMemeToClipboard(fileName: String) {
        Task {
            if !fileName.isEmpty, let uiImage = UIImage(contentsOfFile: getFullImagePath(from: fileName)) {
                UIPasteboard.general.image = uiImage
                await MainActor.run {
                    withAnimation { copyFeedback = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copyFeedback = false }
                    }
                }
            }
        }
    }
}

// ==========================================
// MARK: - 功能二：上傳新梗圖 (UploadTestView)
// ==========================================
struct UploadTestView: View {
    @State private var fetchResult: PHFetchResult<PHAsset>? = nil
    @State private var permissionError: Bool = false
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "E5DFEA").ignoresSafeArea()
            VStack(spacing: 0) {
                // 🌟 置入自訂的控制橫條
                CustomDragHandle()
                
                if permissionError { Text("需要相簿權限才能選擇圖片").foregroundColor(.red).padding() }
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        if let fetchResult = fetchResult { ForEach(0..<fetchResult.count, id: \.self) { index in PhotoGridCell(asset: fetchResult.object(at: index)) } }
                    }.padding(.horizontal, 16).padding(.top, 8)
                }
            }
        }.onAppear { loadPhotos() }
    }
    
    private func loadPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            let fetchOptions = PHFetchOptions(); fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            self.fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        } else { PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in DispatchQueue.main.async { if newStatus == .authorized || newStatus == .limited { self.loadPhotos() } else { self.permissionError = true } } } }
    }
}

struct PhotoGridCell: View {
    let asset: PHAsset
    @Environment(\.modelContext) private var modelContext
    @State private var image: UIImage? = nil
    enum UploadState { case none, uploading, success, failure }
    @State private var uploadState: UploadState = .none
    let apiService = MemeAPIService()
    
    var body: some View {
        ZStack {
            Color.white
            if let image = image { Image(uiImage: image).resizable().scaledToFit().frame(width: 170, height: 170).clipped() } else { ProgressView().frame(width: 170, height: 170) }
            
            switch uploadState {
            case .none: EmptyView()
            case .uploading: Color.black.opacity(0.5); VStack(spacing: 8) { ProgressView().tint(.white); Text("分析中...").font(.caption).bold().foregroundColor(.white) }
            case .success: Color.green.opacity(0.6); VStack(spacing: 8) { Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundColor(.white); Text("上傳成功").font(.caption).bold().foregroundColor(.white) }
            case .failure: Color.red.opacity(0.6); VStack(spacing: 8) { Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundColor(.white); Text("上傳失敗").font(.caption).bold().foregroundColor(.white) }
            }
        }.frame(width: 170, height: 170).background(Color.white).cornerRadius(10).onAppear { loadImage() }
        .onTapGesture { if uploadState == .none { Task { await processAndUploadImage() } } }
    }
    
    private func loadImage() {
        let requestOptions = PHImageRequestOptions(); requestOptions.isSynchronous = false; requestOptions.deliveryMode = .opportunistic
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 340, height: 340), contentMode: .aspectFit, options: requestOptions) { result, _ in if let result = result { self.image = result } }
    }
    
    private func processAndUploadImage() async {
        await MainActor.run { withAnimation { self.uploadState = .uploading } }
        let requestOptions = PHImageRequestOptions(); requestOptions.isSynchronous = false; requestOptions.deliveryMode = .highQualityFormat; requestOptions.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 800, height: 800), contentMode: .aspectFit, options: requestOptions) { image, _ in
            guard let validImage = image else { self.triggerFeedback(state: .failure); return }
            Task {
                do {
                    let analysis = try await apiService.analyzeNewMeme(image: validImage)
                    let fileName = "\(UUID().uuidString).jpg"
                    if let imageData = validImage.jpegData(compressionQuality: 0.8) { try? imageData.write(to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)) }
                    let newMeme = LocalDatabaseMeme(imageUrl: fileName, name: analysis.name, memeKeywords: analysis.memeKeywords, emotionKeywords: analysis.emotionKeywords)
                    await MainActor.run { modelContext.insert(newMeme); self.triggerFeedback(state: .success) }
                } catch { self.triggerFeedback(state: .failure) }
            }
        }
    }
    
    private func triggerFeedback(state: UploadState) { Task { @MainActor in withAnimation { self.uploadState = state }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { self.uploadState = .none } } } }
}

// ==========================================
// MARK: - 功能三：刪除管理頁面 (DeleteMemeView)
// ==========================================
struct DeleteMemeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allMemes: [LocalDatabaseMeme]
    @State private var selectedMemeIDs: Set<String> = []
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    private func getFullImagePath(from fileName: String) -> String { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName).path }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "E5DFEA").ignoresSafeArea()
            VStack(spacing: 0) {
                // 🌟 置入自訂的控制橫條
                CustomDragHandle()
                
                if allMemes.isEmpty {
                    VStack { Image(systemName: "tray.badge.questionmark").font(.system(size: 50)).foregroundColor(.gray); Text("資料庫內目前沒有任何梗圖").font(.headline).foregroundColor(.gray) }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 108)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(allMemes) { meme in
                                let isSelected = selectedMemeIDs.contains(meme.id)
                                ZStack(alignment: .topTrailing) {
                                    ZStack { Color.white; if let uiImage = UIImage(contentsOfFile: getFullImagePath(from: meme.imageUrl)) { Image(uiImage: uiImage).resizable().scaledToFit().frame(width: 170, height: 170).clipped() } else { Color.gray.opacity(0.3).overlay(Text("圖遺失").font(.caption)) } }
                                        .frame(width: 170, height: 170).background(Color.white).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color(hex: "6B1B8A") : Color.clear, lineWidth: 3))
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").font(.title2).foregroundColor(isSelected ? Color(hex: "6B1B8A") : .gray).padding(8).background(Circle().fill(Color.white.opacity(0.6))).padding(4)
                                }.onTapGesture { if isSelected { selectedMemeIDs.remove(meme.id) } else { selectedMemeIDs.insert(meme.id) } }
                            }
                        }.padding(.horizontal, 16).padding(.top, 8); Spacer().frame(height: 130)
                    }
                }
            }
            HStack(spacing: 15) {
                if selectedMemeIDs.isEmpty {
                    Button(action: deleteAllMemes) { Text("Clear All Meme").font(.system(size: 20, weight: .bold)).foregroundColor(Color(hex: "FF0005")).frame(width: 350, height: 70).background(Color(hex: "E2B7C4")).cornerRadius(25) }.disabled(allMemes.isEmpty).opacity(allMemes.isEmpty ? 0.5 : 1.0)
                } else {
                    Button(action: deleteSelectedMemes) { Text("Delete Selected (\(selectedMemeIDs.count))").font(.system(size: 16, weight: .bold)).foregroundColor(.white).frame(width: 170, height: 70).background(Color(hex: "6B1B8A")).cornerRadius(25) }
                    Button(action: deleteAllMemes) { Text("Clear All").font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "FF0005")).frame(width: 170, height: 70).background(Color(hex: "E2B7C4")).cornerRadius(25) }
                }
            }.frame(maxWidth: .infinity).frame(height: 108).background(Color(hex: "F3F3F3")).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: -2)
        }
    }
    
    private func deleteSelectedMemes() { withAnimation { for id in selectedMemeIDs { if let memeToDelete = allMemes.first(where: { $0.id == id }) { modelContext.delete(memeToDelete) } }; selectedMemeIDs.removeAll() } }
    private func deleteAllMemes() { withAnimation { for meme in allMemes { modelContext.delete(meme) }; selectedMemeIDs.removeAll() } }
}
