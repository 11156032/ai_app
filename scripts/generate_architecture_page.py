import json

html_content = '''<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI App - 雲端 vs 地端 資料庫架構規劃指南</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600&family=Inter:wght@300;400;500;600;700;800&family=Noto+Sans+TC:wght@300;400;500;600;700;900&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-primary: #f8fafc;
      --bg-secondary: #ffffff;
      --bg-card: #ffffff;
      --border-color: #e2e8f0;
      --border-hover: #cbd5e1;
      --text-primary: #0f172a;
      --text-secondary: #475569;
      --text-muted: #64748b;
      
      --cloud-color: #0284c7;
      --cloud-bg: #f0f9ff;
      --cloud-border: #bae6fd;

      --local-color: #059669;
      --local-bg: #ecfdf5;
      --local-border: #a7f3d0;

      --hybrid-color: #7c3aed;
      --hybrid-bg: #f5f3ff;
      --hybrid-border: #ddd6fe;

      --shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.05);
      --shadow-md: 0 4px 15px rgba(0, 0, 0, 0.05);
      --shadow-lg: 0 10px 25px rgba(0, 0, 0, 0.07);
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: 'Inter', 'Noto Sans TC', sans-serif;
      background-color: var(--bg-primary);
      color: var(--text-primary);
      padding: 40px 20px;
      line-height: 1.6;
      -webkit-font-smoothing: antialiased;
    }

    .container {
      max-width: 1200px;
      margin: 0 auto;
    }

    /* Header */
    .header-section {
      text-align: center;
      margin-bottom: 40px;
    }

    .badge-top {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: #e0e7ff;
      border: 1px solid #c7d2fe;
      color: #4338ca;
      font-size: 13px;
      font-weight: 600;
      padding: 5px 14px;
      border-radius: 20px;
      margin-bottom: 16px;
    }

    .header-section h1 {
      font-size: 32px;
      font-weight: 800;
      letter-spacing: -0.02em;
      margin-bottom: 12px;
      color: #0f172a;
    }

    .header-section p {
      font-size: 15px;
      color: var(--text-secondary);
      max-width: 760px;
      margin: 0 auto;
    }

    /* KPI Summary Cards */
    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 20px;
      margin-bottom: 36px;
    }

    .kpi-card {
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      border-radius: 14px;
      padding: 24px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      box-shadow: var(--shadow-md);
      position: relative;
    }

    .kpi-card.cloud {
      border-top: 4px solid var(--cloud-color);
    }
    .kpi-card.local {
      border-top: 4px solid var(--local-color);
    }
    .kpi-card.hybrid {
      border-top: 4px solid var(--hybrid-color);
    }

    .kpi-title {
      font-size: 14px;
      font-weight: 700;
      display: flex;
      align-items: center;
      justify-content: space-between;
      color: #1e293b;
    }

    .kpi-count {
      font-size: 32px;
      font-weight: 900;
      font-family: 'Fira Code', monospace;
    }

    .kpi-card.cloud .kpi-count { color: var(--cloud-color); }
    .kpi-card.local .kpi-count { color: var(--local-color); }
    .kpi-card.hybrid .kpi-count { color: var(--hybrid-color); }

    .kpi-desc {
      font-size: 13.5px;
      color: var(--text-secondary);
      line-height: 1.5;
    }

    /* Architecture Visual Diagram */
    .diagram-section {
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      border-radius: 14px;
      padding: 28px;
      margin-bottom: 40px;
      box-shadow: var(--shadow-md);
    }

    .section-title {
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 20px;
      display: flex;
      align-items: center;
      gap: 10px;
      color: #0f172a;
    }

    .diagram-grid {
      display: grid;
      grid-template-columns: 1fr 60px 1fr 60px 1fr;
      align-items: center;
      gap: 12px;
    }

    @media (max-width: 900px) {
      .diagram-grid {
        grid-template-columns: 1fr;
        gap: 20px;
      }
      .diagram-arrow {
        transform: rotate(90deg);
        text-align: center;
      }
    }

    .diagram-node {
      border-radius: 12px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .diagram-node.cloud-box {
      border: 1px solid var(--cloud-border);
      background: var(--cloud-bg);
    }

    .diagram-node.local-box {
      border: 1px solid var(--local-border);
      background: var(--local-bg);
    }

    .diagram-node.sync-box {
      border: 1px solid var(--hybrid-border);
      background: var(--hybrid-bg);
    }

    .diagram-node h3 {
      font-size: 15px;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 8px;
      color: #0f172a;
    }

    .diagram-node ul {
      list-style: none;
      font-size: 12.5px;
      color: var(--text-secondary);
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .diagram-node li {
      padding: 5px 10px;
      background: #ffffff;
      border: 1px solid rgba(0, 0, 0, 0.06);
      border-radius: 6px;
      font-family: 'Fira Code', monospace;
      color: #1e293b;
    }

    .diagram-arrow {
      text-align: center;
      font-size: 22px;
      color: #94a3b8;
    }

    /* Filter Toolbar */
    .filter-toolbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 14px;
      margin-bottom: 24px;
    }

    .filter-tabs {
      display: flex;
      gap: 8px;
      background: #f1f5f9;
      padding: 5px;
      border-radius: 10px;
      border: 1px solid #e2e8f0;
    }

    .filter-btn {
      padding: 8px 16px;
      border-radius: 8px;
      border: none;
      background: transparent;
      color: var(--text-secondary);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }

    .filter-btn:hover {
      color: #0f172a;
    }

    .filter-btn.active {
      background: #ffffff;
      color: #0f172a;
      box-shadow: var(--shadow-sm);
    }

    .search-input {
      padding: 9px 16px;
      background: #ffffff;
      border: 1px solid var(--border-color);
      border-radius: 8px;
      color: #0f172a;
      font-size: 13px;
      width: 280px;
      outline: none;
      box-shadow: var(--shadow-sm);
    }
    .search-input:focus {
      border-color: #6366f1;
      box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15);
    }

    /* Table Cards Grid */
    .cards-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
      gap: 20px;
    }

    .arch-card {
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 14px;
      padding: 22px;
      display: flex;
      flex-direction: column;
      gap: 14px;
      transition: all 0.2s ease;
      box-shadow: var(--shadow-sm);
    }

    .arch-card:hover {
      transform: translateY(-2px);
      box-shadow: var(--shadow-md);
      border-color: var(--border-hover);
    }

    .arch-card-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 10px;
    }

    .arch-table-name {
      font-size: 17px;
      font-weight: 700;
      color: #0f172a;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .arch-table-zh {
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 2px;
    }

    .type-pill {
      font-size: 11px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 20px;
      white-space: nowrap;
      letter-spacing: 0.02em;
    }

    .type-pill.cloud {
      background: var(--cloud-bg);
      color: var(--cloud-color);
      border: 1px solid var(--cloud-border);
    }
    .type-pill.local {
      background: var(--local-bg);
      color: var(--local-color);
      border: 1px solid var(--local-border);
    }
    .type-pill.hybrid {
      background: var(--hybrid-bg);
      color: var(--hybrid-color);
      border: 1px solid var(--hybrid-border);
    }

    .reason-box {
      background: #f8fafc;
      border: 1px solid #f1f5f9;
      border-radius: 8px;
      padding: 12px 14px;
      font-size: 13.5px;
      color: #334155;
      line-height: 1.55;
    }

    .reason-box strong {
      color: #0f172a;
    }

    .arch-meta-list {
      display: flex;
      flex-direction: column;
      gap: 7px;
      font-size: 12.5px;
      color: var(--text-secondary);
      background: #f8fafc;
      padding: 10px 12px;
      border-radius: 8px;
    }

    .arch-meta-item {
      display: flex;
      justify-content: space-between;
      border-bottom: 1px dashed #e2e8f0;
      padding-bottom: 4px;
    }
    .arch-meta-item:last-child {
      border-bottom: none;
      padding-bottom: 0;
    }

    .arch-meta-item span:first-child {
      color: var(--text-muted);
      font-weight: 500;
    }

    .arch-meta-item span:last-child {
      font-family: 'Fira Code', monospace;
      color: #0f172a;
      font-weight: 600;
    }

    /* Links Footer */
    .links-footer {
      margin-top: 50px;
      padding: 24px;
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 14px;
      box-shadow: var(--shadow-sm);
    }

    .links-title {
      font-size: 14px;
      color: var(--text-secondary);
      font-weight: 500;
    }

    .links-btns {
      display: flex;
      gap: 10px;
    }

    .btn {
      padding: 8px 16px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      text-decoration: none;
      border: 1px solid #cbd5e1;
      background: #ffffff;
      color: #1e293b;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s;
    }

    .btn:hover {
      background: #f1f5f9;
      border-color: #94a3b8;
    }
  </style>
</head>
<body>

  <div class="container">

    <!-- Header -->
    <div class="header-section">
      <div class="badge-top">🚀 系統架構決策與資料分工指南</div>
      <h1>雲端 (Cloud) vs 地端 (Local) 資料庫架構規劃</h1>
      <p>針對 AI 學習 App 之 21 張資料表，從「隱私性、資安、多人互動、離線可用性 (Offline-First) 與伺服器頻寬成本」進行深度劃分與架構建議。</p>
    </div>

    <!-- KPI Summary Cards -->
    <div class="kpi-grid">
      <div class="kpi-card cloud">
        <div class="kpi-title">
          <span>☁️ 雲端主導 (Cloud-First)</span>
          <span style="font-size: 18px;">🌐</span>
        </div>
        <div class="kpi-count">8 張表</div>
        <div class="kpi-desc">社群動態、讀書會群組、官方題庫、點數安全與推播廣告。以雲端為唯一可信來源 (Single Source of Truth)。</div>
      </div>

      <div class="kpi-card local">
        <div class="kpi-title">
          <span>📱 地端主導 (Local-First)</span>
          <span style="font-size: 18px;">🔒</span>
        </div>
        <div class="kpi-count">5 張表 / 設定</div>
        <div class="kpi-desc">個人心情日記、待辦清單、UI 主題偏好、字體縮放與自備 API 金鑰。講求極致隱私與零延遲秒開體驗。</div>
      </div>

      <div class="kpi-card hybrid">
        <div class="kpi-title">
          <span>🔄 混合同步 (Hybrid Sync)</span>
          <span style="font-size: 18px;">⚡</span>
        </div>
        <div class="kpi-count">8 張表</div>
        <div class="kpi-desc">個人筆記、行事曆排程、刷題成績與錯題本。本機優先秒開與離線作答，連網時背景自動雙向備份。</div>
      </div>
    </div>

    <!-- Architecture Diagram -->
    <div class="diagram-section">
      <div class="section-title">
        <span>🏗️ 三層資料流架構模型 (Three-Tier Data Model)</span>
      </div>

      <div class="diagram-grid">
        <!-- Node 1 -->
        <div class="diagram-node local-box">
          <h3>📱 終端本機 (SQLite / Storage)</h3>
          <p style="font-size: 12px; color: var(--text-muted);">離線可用 • 零延遲 • 隱私防護</p>
          <ul>
            <li>diaries (心情日記)</li>
            <li>todos (待辦事項)</li>
            <li>App 主題 / 字體 / 偏好</li>
            <li>離線題庫與作答快取</li>
          </ul>
        </div>

        <div class="diagram-arrow">⇄</div>

        <!-- Node 2 -->
        <div class="diagram-node sync-box">
          <h3>🔄 雙向同步引擎 (Sync Engine)</h3>
          <p style="font-size: 12px; color: var(--text-muted);">衝突排解 • 背景排程 • 差異上傳</p>
          <ul>
            <li>notes (學習筆記)</li>
            <li>calendar_events (行事曆)</li>
            <li>wrong_questions (錯題本)</li>
            <li>quiz_results (測驗成績)</li>
          </ul>
        </div>

        <div class="diagram-arrow">⇄</div>

        <!-- Node 3 -->
        <div class="diagram-node cloud-box">
          <h3>☁️ 雲端核心 (Postgres / Firebase)</h3>
          <p style="font-size: 12px; color: var(--text-muted);">多人協作 • 帳號認證 • 防作弊</p>
          <ul>
            <li>posts / comments (社群動態)</li>
            <li>community_groups (讀書會)</li>
            <li>questions (官方題庫中心)</li>
            <li>point_transactions (積分點數)</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Filter Toolbar -->
    <div class="filter-toolbar">
      <div class="filter-tabs">
        <button class="filter-btn active" onclick="filterCategory('all', this)">全部 (21)</button>
        <button class="filter-btn" onclick="filterCategory('cloud', this)">☁️ 雲端 (8)</button>
        <button class="filter-btn" onclick="filterCategory('local', this)">📱 地端 (5)</button>
        <button class="filter-btn" onclick="filterCategory('hybrid', this)">🔄 混合同步 (8)</button>
      </div>

      <input type="text" id="searchInput" class="search-input" placeholder="搜尋資料表名稱或關鍵字..." oninput="searchCards(this.value)">
    </div>

    <!-- Cards Grid -->
    <div class="cards-grid" id="cardsGrid">
      <!-- Generated via JS -->
    </div>

    <!-- Navigation Footer -->
    <div class="links-footer">
      <div class="links-title">
        <span>💡 需要查看詳細欄位字典或資料內容？</span>
      </div>
      <div class="links-btns">
        <a href="database_dictionary.html" class="btn">📑 規格書資料字典 (Data Dictionary)</a>
        <a href="database_viewer.html" class="btn">💻 互動式資料庫檢視器 (Viewer)</a>
      </div>
    </div>

  </div>

  <script>
    const ARCH_DATA = [
      {
        code: "T01",
        name: "users",
        zh: "使用者資料表",
        type: "hybrid",
        typeText: "混合同步",
        reason: "帳號、密碼雜湊、會員等級與權限由<strong>雲端主控驗證</strong>；但個人的介面主題 (theme_color)、深色模式、字體大小與導覽列設定應<strong>本地快取</strong>以保證 App 秒開。",
        storage: "Cloud Postgres + Local SharedPreferences",
        syncPolicy: "登入時下載設定，變更時雙向同步"
      },
      {
        code: "T02",
        name: "calendar_events",
        zh: "行事曆事件資料表",
        type: "hybrid",
        typeText: "混合同步",
        reason: "學生隨時需要查看課表與考試日程（無網路也能檢視），故本地需保留完整資料；同時與雲端雙向同步，支援多裝置（手機/平板/電腦）與 Google Calendar 連動。",
        storage: "Local SQLite + Cloud DB",
        syncPolicy: "本機優先寫入，連網時背景自動同步"
      },
      {
        code: "T03",
        name: "tags",
        zh: "標籤資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "標籤為題庫與社群群組的全域分類體系，由官方或社群統一維護，手機端僅需在需要時進行唯讀快取。",
        storage: "Cloud Database (唯讀快取至本地)",
        syncPolicy: "App 啟動時差異檢查更新"
      },
      {
        code: "T04",
        name: "questions",
        zh: "題庫題目資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "題庫會持續擴充、勘誤更正與新增詳解。放雲端可即時更新題庫，無須頻繁發布 App Store 更新包；App 可依選定科目離線打包下載題庫快取。",
        storage: "Cloud Database + Local Cache",
        syncPolicy: "按章節/科目隨選離線下載"
      },
      {
        code: "T05",
        name: "question_tag_map",
        zh: "題目標籤關聯表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "與題庫題目綁定之多對多關聯，隨官方題庫由雲端統一控管與分發。",
        storage: "Cloud Database",
        syncPolicy: "隨題目資料一併下載快取"
      },
      {
        code: "T06",
        name: "notes",
        zh: "筆記資料表",
        type: "hybrid",
        typeText: "混合同步",
        reason: "課堂聽寫、語音轉文字需即時秒存至手機（即使在無訊號教室）；上傳至雲端後可進行 AI 雲端整理、跨裝置備份與分享。",
        storage: "Local SQLite + Cloud Backup",
        syncPolicy: "本地即時存檔，連網後非同步上傳備份"
      },
      {
        code: "T07",
        name: "diaries",
        zh: "日記資料表",
        type: "local",
        typeText: "地端主導",
        reason: "高度個人隱私與心情日記。<strong>絕不主動上傳未加密雲端</strong>，保障使用者隱私安全感；可提供使用者手動加密備份選項。",
        storage: "Local SQLite (建議搭配本機加密)",
        syncPolicy: "僅保存在本機 / 使用者手動 E2EE 備份"
      },
      {
        code: "T08",
        name: "todos",
        zh: "待辦事項資料表",
        type: "local",
        typeText: "地端主導",
        reason: "隨手紀錄待辦事項講求<strong>極致零延遲</strong>，點擊勾選必須 0.01 秒即時反應，完全不受網路連線延遲或斷線影響。",
        storage: "Local SQLite",
        syncPolicy: "本地優先 / 可選帳號層級雲端同步"
      },
      {
        code: "T09",
        name: "posts",
        zh: "社群貼文資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "社群動態必須供所有使用者即時瀏覽與發布。<strong>圖片/檔案 BLOB 應轉存於 S3 / Firebase Storage</strong>，資料庫僅記錄 URL，降低手機流量。",
        storage: "Cloud Database + Cloud Object Storage (S3)",
        syncPolicy: "分頁滑動即時載入 (Infinite Scroll)"
      },
      {
        code: "T10",
        name: "post_likes",
        zh: "貼文按讚資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "跨使用者即時按讚與防重複點擊機制，必須由雲端伺服器進行原子操作（Atomic Transaction）驗證。",
        storage: "Cloud Database / Redis 快取",
        syncPolicy: "即時 API 呼叫"
      },
      {
        code: "T11",
        name: "comments",
        zh: "貼文留言資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "多人群聊與巢狀回覆討論，依賴雲端伺服器進行即時推播與留言審查過濾。",
        storage: "Cloud Database",
        syncPolicy: "即時拉取 / WebSocket 訂閱"
      },
      {
        code: "T12",
        name: "quiz_results",
        zh: "測驗紀錄資料表",
        type: "hybrid",
        typeText: "混合同步",
        reason: "作答完成後本地立刻生成成績圖表與診斷；同時上傳雲端生成全台排名、PR值分析與學習成長軌跡曲線。",
        storage: "Local SQLite + Cloud Analytics DB",
        syncPolicy: "交卷時立即上傳並同步"
      },
      {
        code: "T13",
        name: "post_bookmarks",
        zh: "貼文收藏資料表",
        type: "hybrid",
        typeText: "混合同步",
        reason: "使用者收藏的精華貼文，本地快取方便離線回顧，雲端同步確保換手機時收藏清單不遺失。",
        storage: "Local SQLite + Cloud DB",
        syncPolicy: "收藏/取消時同步雲端"
      },
      {
        code: "T14",
        name: "community_groups",
        zh: "讀書會群組資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "多人讀書會由群主管理，包含公開/私密權限、邀請碼 Token 驗證等，必須由雲端統一授權。",
        storage: "Cloud Database",
        syncPolicy: "即時查詢與更新"
      },
      {
        code: "T15",
        name: "group_members",
        zh: "群組成員資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "群組成員名單、管理員身分、禁言狀態與已讀時間標記，涉及跨用戶協作，必須雲端集中處理。",
        storage: "Cloud Database",
        syncPolicy: "即時推播與狀態同步"
      },
      {
        code: "T16",
        name: "group_announcements",
        zh: "群組公告資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "讀書會置頂公告發布時需配合 FCM (Firebase Cloud Messaging) 推播給所有成員。",
        storage: "Cloud Database + FCM 推播",
        syncPolicy: "即時推播通知"
      },
      {
        code: "T17",
        name: "user_papers",
        zh: "自訂試卷資料表",
        type: "hybrid",
        typeText: "混合同步",
        reason: "學生自己挑題組裝的模擬考卷，存於本地可隨時離線考，同步到雲端可一鍵分享給讀書會同學或老師。",
        storage: "Local SQLite + Cloud Sharing",
        syncPolicy: "本地保存，分享時上傳產生分享碼"
      },
      {
        code: "T18",
        name: "wrong_questions",
        zh: "錯題本資料表",
        type: "hybrid",
        typeText: "混合同步",
        reason: "錯題本是個人複習核心，離線隨時可檢討筆記；雲端同步讓 AI 診斷模型能跨裝置持續分析學生的弱點分佈。",
        storage: "Local SQLite + Cloud AI Knowledge Base",
        syncPolicy: "本機作答即時記錄，背景自動同步"
      },
      {
        code: "T19",
        name: "remedial_materials",
        zh: "弱點補救教材資料表",
        type: "hybrid",
        typeText: "混合同步",
        reason: "雲端 AI (Gemini) 生成客製化補救講義後，回傳並<strong>快取於手機本地</strong>，讓學生搭車通勤無網路時也能精準複習。",
        storage: "Cloud AI Generation + Local Offline Cache",
        syncPolicy: "雲端生成後快取到本地"
      },
      {
        code: "T20",
        name: "point_transactions",
        zh: "點數交易紀錄資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "<strong>防作弊核心</strong>！點數可用於兌換會員或解鎖功能，餘額與每一筆加扣點明細必須由伺服器驗證，嚴禁單純依賴本地修改。",
        storage: "Cloud Secure Ledger / Database",
        syncPolicy: "每次交易由後端 API 伺服器原子執行"
      },
      {
        code: "T21",
        name: "advertisements",
        zh: "廣告活動資料表",
        type: "cloud",
        typeText: "雲端主導",
        reason: "行銷橫幅、全國大專 AI 比賽等活動文案時效性強，由行銷後台雲端即時控管上架與下架。",
        storage: "Cloud Database / CDN 快取",
        syncPolicy: "App 每次啟動時抓取最新有效活動"
      }
    ];

    let currentFilter = 'all';
    let searchQuery = '';

    function renderCards() {
      const container = document.getElementById('cardsGrid');
      container.innerHTML = '';

      const filtered = ARCH_DATA.filter(item => {
        const matchesType = (currentFilter === 'all') || (item.type === currentFilter);
        const q = searchQuery.toLowerCase();
        const matchesQuery = !searchQuery || 
          item.name.toLowerCase().includes(q) || 
          item.zh.toLowerCase().includes(q) || 
          item.reason.toLowerCase().includes(q);
        return matchesType && matchesQuery;
      });

      if (filtered.length === 0) {
        container.innerHTML = '<div style="grid-column: 1/-1; text-align:center; padding: 50px; color: var(--text-muted);">查無符合條件的資料表</div>';
        return;
      }

      filtered.forEach(item => {
        const card = document.createElement('div');
        card.className = 'arch-card';

        card.innerHTML = `
          <div class="arch-card-header">
            <div>
              <div class="arch-table-name">
                <span>${item.code}</span>
                <span>${item.name}</span>
              </div>
              <div class="arch-table-zh">${item.zh}</div>
            </div>
            <span class="type-pill ${item.type}">${item.typeText}</span>
          </div>

          <div class="reason-box">
            ${item.reason}
          </div>

          <div class="arch-meta-list">
            <div class="arch-meta-item">
              <span>儲存媒介</span>
              <span>${item.storage}</span>
            </div>
            <div class="arch-meta-item">
              <span>同步策略</span>
              <span>${item.syncPolicy}</span>
            </div>
          </div>
        `;
        container.appendChild(card);
      });
    }

    function filterCategory(type, btn) {
      currentFilter = type;
      document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      renderCards();
    }

    function searchCards(val) {
      searchQuery = val;
      renderCards();
    }

    window.onload = () => {
      renderCards();
    };
  </script>
</body>
</html>
'''

with open('database_architecture.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print("Generated white theme database_architecture.html successfully!")
