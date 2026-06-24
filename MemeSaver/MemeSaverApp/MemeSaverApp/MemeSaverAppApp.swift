//
//  MemeSaverAppApp.swift
//  MemeSaverApp
//
//  Created by Mac09 on 2026/5/29.
//

import SwiftUI
import SwiftData

@main
struct MemeSaverApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        // 🌟 啟動 SwiftData 資料庫，綁定我們設計的梗圖資料模型
        .modelContainer(for: LocalDatabaseMeme.self)
    }
}
