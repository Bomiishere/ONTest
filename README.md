# ONTest – 即時賽事賠率系統


## SwiftUI · MVVM + TCA · Swift Concurrency · 可測試擴充


### 1. 專案概覽

#### 專案為即時賽事賠率展示 App。資料來源包含：
    * /api/matches：一次載入約 100 筆比賽（含 matchID、隊伍、開賽時間）。
    * /api/odds：載入每場比賽初始賠率（teamA / teamB）。
    * WebSocket 模擬：以 Timer/Combine.Timer 每秒推播多筆賠率更新。

#### UI 使用 **SwiftUI**，狀態管理採 **MVVM + The Composable Architecture (TCA)**，非同步採 **Swift Concurrency**：
    * 即時更新對應 Cell（避免整頁 reload），保持順暢。
    * Thread-safe 的資料合併與排序邏輯。
    * 清楚的 DI 與可測試設計（Mocks / TestStore）。

⸻

### 2. 架構說明

#### 2.1 專案層次

    App
     ├─ Features
     │   └─ MatchList
     │       ├─ MatchListFeature.swift   // TCA: State / Action / Reducer
     │       ├─ MatchListView.swift      // SwiftUI View
     │       └─ Components               // UI 子元件
     ├─ Services
     │   ├─ API         // api 抽象與實作
     │   └─ WebSocket   // WebSocket 抽象與實作
     ├─ Repository
     │   └─ Cache       // 快取機制
     ├─ Core
     │   ├─ Model       // Match / Odds 等資料模型
     │   ├─ DI          // Dependencies
     │   └─ Utilities   // 日期..等工具
     └─ Support
     │   └─ Mock        // Mock Data
     └─ Test

#### 2.2 MVVM 對照

    * Model：Match, Odds, MatchOddsUpdate 等不可變資料。
    * ViewModel：由 TCA Reducer/Store 承擔（State 驅動 UI、Action 驅動事件）。
    * View：SwiftUI MatchListView 視圖，透過 Store 綁定資料與事件。

⸻

### 3. Swift Concurrency / Combine 使用場景

#### 3.1 Swift Concurrency（async/await / Task / Actor）
    * 資料載入：fetchMatches()、fetchOddsList() 以 async 執行，結果合併進 State。
    * 資料合併：WebSocket 高頻更新會先進入 Reducer，透過 .throttle(id:for:scheduler:) 控制更新頻率，避免同一比賽在短時間內被過度刷新。
    * 取消控制：TCA 的 .run 會回傳可取消的 task，並以 cancellable(id:cancelInFlight:) 管理生命週期。
    * 線程安全：OddsRepository 是 actor，確保 apply update 時，odds 資料在多執行緒下寫入一致。
    * 測試：使用 TestStore 驗證相關邏輯。

#### 3.2 Combine（僅用於 WebSocket 模擬）
    * 依題目指定，推播以 Timer 或 Combine.Timer 模擬，每秒最多 10 筆更新。
    * 在邊界處包裝成 AsyncStream<MatchOddsUpdate> 輸出給 TCA 介面，讓上層統一以 Swift Concurrency 消費。
    * 設計原則：IO（HTTP/Timer）接入層可以是 Combine，但進入 Reducer 後一律轉為 async / AsyncSequence，簡化可測試性與一致性。

⸻

### 4. 如何確保資料存取 thread‑safe？

#### 4.1. 值型別狀態：
    * TCA State 為 struct，所有變更都在 Reducer 的單一序列化執行中完成。

#### 4.2 Actor 隔離：
    * 對「多來源更新」的共享可變資料（例如 odds 合併、快取），(應)使用 actor OddsMerger / actor CacheBox。

    ```
    actor OddsMerger {
      private var latest: [MatchID: Odds] = [:]
      func apply(_ update: OddsUpdate) -> Odds { /* 合併後回傳 */ }
    }
    ```
#### 4.3 MainActor：
    * UI 已與 Store.State 綁定，所有狀態更新（如更新 State.matches[id].odds) 都在 Reducer 中完成，Store 會保證 Reducer 在單一序列化環境中執行，因此無需額外 @MainActor 即可確保 thread-safe。
    
#### 4.4 不可變模型：
    * Match、Odds 為不可變 struct，更新以「新值覆蓋舊值」的方式，避免同一實例被多執行緒同時修改。
    
#### 4.5 取消與重入：
    * 啟動 stream 時使用 .cancellable(id: .stream, cancelInFlight: true)，避免重複訂閱導致競態。

⸻

### 5. UI 與 ViewModel 資料綁定方式

#### 5.1 SwiftUI + TCA
    * 以 StoreOf<MatchListFeature> 餵給 MatchListView。
    * 只更新受影響的 Row，每筆 odds 更新對應一個 State.Row，確保僅該 Row 重新計算/渲染，避免整表 reload。
    * 排序：Reducer 內在合併後維持 startTime 升序；如需穩定排序，採 stable sort 並以 matchID 當 tiebreaker。

#### 5.2 UIKit (若以 UITableView 呈現）
    * 用 UITableViewDiffableDataSource 或 performBatchUpdates 做局部 reload。

⸻

### 6. 效能與驗證（FPS / Instruments / Log）

#### 6.1 FPS 指標（App 畫面內）
    在 ZStack 疊一個輕量 FPSBadge（以 CADisplayLink 每秒計數）。

#### 6.2 Instruments – 更新流暢度
    Animation Hitches：看 Hitch 事件、平均幀時間。

#### 6.3 Instruments – 記憶體 Retain/Leaks
    * Leaks 確認無紅點。
    * Allocations 連續切換頁面後 Persistent 不持續攀升

#### 6.4 觀察 Log
    * 確認 APIService 與 WSStream 皆有 deinit

⸻

### 7. 測試策略

#### 7.1 單元測試（TCA TestStore）
    * 時間相依：測 throttle update。
    * 資料流：驗證 State 變更順序：task → _fetchCache → _fetchAPI → _startOddsStream...。

#### 7.2 行為測試（UI）
    * 合併後目標 Row 顯示變更。
    * 排序維持正確。
    * 測試 API 錯誤時，顯示訊息。

⸻

### 8. 建置與執行

    * Xcode 15+，iOS 17+
    * 直接 ⌘+R 執行
    * 如需調整 odds update 推播節奏，在 WSTopic.Odds 的常數中修改。

⸻

### 9. 後續工作

    * 當更新密度極高時，需評估更積極的批次合併策略與優先級排程。
    * 大量列表（>1k）可改用分段載入 + 虛擬化渲染策略 (只 load 看得到的)。
