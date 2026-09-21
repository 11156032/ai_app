import json
import os

with open('db_export.json', 'r', encoding='utf-8') as f:
    db_data = json.load(f)

json_data_str = json.dumps(db_data, ensure_ascii=False)

html_content = '''<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI App - SQLite 資料庫視覺化檢視器</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600&family=Inter:wght@300;400;500;600;700;800&family=Noto+Sans+TC:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-primary: #0b0f19;
      --bg-secondary: #111827;
      --bg-tertiary: #1f2937;
      --bg-card: rgba(17, 24, 39, 0.85);
      --bg-card-hover: rgba(31, 41, 55, 0.85);
      --border-color: rgba(255, 255, 255, 0.08);
      --border-color-focus: rgba(99, 102, 241, 0.5);
      --text-primary: #f9fafb;
      --text-secondary: #9ca3af;
      --text-muted: #6b7280;
      --accent-primary: #6366f1;
      --accent-glow: rgba(99, 102, 241, 0.25);
      --accent-success: #10b981;
      --accent-warning: #f59e0b;
      --accent-danger: #ef4444;
      --accent-info: #3b82f6;
      --sidebar-width: 320px;
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
      display: flex;
      height: 100vh;
      overflow: hidden;
      -webkit-font-smoothing: antialiased;
    }

    /* Scrollbars */
    ::-webkit-scrollbar {
      width: 6px;
      height: 6px;
    }
    ::-webkit-scrollbar-track {
      background: transparent;
    }
    ::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.15);
      border-radius: 4px;
    }
    ::-webkit-scrollbar-thumb:hover {
      background: rgba(255, 255, 255, 0.25);
    }

    /* Sidebar */
    aside {
      width: var(--sidebar-width);
      min-width: var(--sidebar-width);
      background: var(--bg-secondary);
      border-right: 1px solid var(--border-color);
      display: flex;
      flex-direction: column;
      height: 100%;
      z-index: 10;
    }

    .brand-header {
      padding: 20px;
      display: flex;
      align-items: center;
      gap: 12px;
      border-bottom: 1px solid var(--border-color);
      background: linear-gradient(180deg, rgba(99, 102, 241, 0.08) 0%, transparent 100%);
    }

    .brand-icon {
      width: 40px;
      height: 40px;
      background: linear-gradient(135deg, #6366f1, #8b5cf6);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      box-shadow: 0 4px 12px var(--accent-glow);
    }

    .brand-title h1 {
      font-size: 16px;
      font-weight: 700;
      color: #fff;
      letter-spacing: -0.01em;
    }

    .brand-title p {
      font-size: 11px;
      color: var(--text-muted);
    }

    .search-box {
      padding: 14px 16px;
      border-bottom: 1px solid var(--border-color);
    }

    .search-input-wrapper {
      position: relative;
      display: flex;
      align-items: center;
    }

    .search-input-wrapper svg {
      position: absolute;
      left: 12px;
      width: 16px;
      height: 16px;
      fill: var(--text-muted);
    }

    .search-input {
      width: 100%;
      padding: 8px 12px 8px 36px;
      background: var(--bg-primary);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      color: #fff;
      font-size: 13px;
      outline: none;
      transition: all 0.2s;
    }

    .search-input:focus {
      border-color: var(--accent-primary);
      box-shadow: 0 0 0 3px var(--accent-glow);
    }

    .table-nav {
      flex: 1;
      overflow-y: auto;
      padding: 12px 8px;
    }

    .nav-category {
      margin-bottom: 16px;
    }

    .nav-category-title {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      color: var(--text-muted);
      letter-spacing: 0.05em;
      padding: 6px 12px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    .table-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 9px 12px;
      margin-bottom: 2px;
      border-radius: 8px;
      color: var(--text-secondary);
      cursor: pointer;
      font-size: 13px;
      font-weight: 500;
      transition: all 0.15s ease;
      user-select: none;
    }

    .table-item:hover {
      background: var(--bg-tertiary);
      color: #fff;
    }

    .table-item.active {
      background: linear-gradient(90deg, rgba(99, 102, 241, 0.2) 0%, rgba(99, 102, 241, 0.05) 100%);
      color: #a5b4fc;
      border-left: 3px solid var(--accent-primary);
      font-weight: 600;
    }

    .table-item-name {
      display: flex;
      align-items: center;
      gap: 8px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .table-badge {
      font-size: 11px;
      padding: 2px 7px;
      border-radius: 12px;
      background: rgba(255, 255, 255, 0.06);
      color: var(--text-muted);
      font-family: 'Fira Code', monospace;
    }

    .table-item.active .table-badge {
      background: rgba(99, 102, 241, 0.25);
      color: #c7d2fe;
    }

    .sidebar-footer {
      padding: 14px 16px;
      border-top: 1px solid var(--border-color);
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12px;
      color: var(--text-muted);
      background: var(--bg-secondary);
    }

    /* Main Content */
    main {
      flex: 1;
      display: flex;
      flex-direction: column;
      height: 100%;
      overflow: hidden;
      background: var(--bg-primary);
    }

    /* Top Navigation Bar */
    header {
      padding: 16px 28px;
      border-bottom: 1px solid var(--border-color);
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: var(--bg-secondary);
    }

    .header-left {
      display: flex;
      align-items: center;
      gap: 16px;
    }

    .current-table-title {
      font-size: 20px;
      font-weight: 700;
      color: #fff;
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .current-table-badge {
      font-size: 12px;
      padding: 3px 10px;
      border-radius: 6px;
      background: rgba(99, 102, 241, 0.15);
      color: #818cf8;
      font-family: 'Fira Code', monospace;
      font-weight: 500;
    }

    .tab-buttons {
      display: flex;
      gap: 4px;
      background: var(--bg-primary);
      padding: 4px;
      border-radius: 8px;
      border: 1px solid var(--border-color);
    }

    .tab-btn {
      padding: 6px 14px;
      border-radius: 6px;
      border: none;
      background: transparent;
      color: var(--text-muted);
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.15s;
    }

    .tab-btn:hover {
      color: #fff;
    }

    .tab-btn.active {
      background: var(--bg-tertiary);
      color: #fff;
      font-weight: 600;
    }

    .header-actions {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 7px 14px;
      border-radius: 7px;
      border: 1px solid var(--border-color);
      background: var(--bg-tertiary);
      color: #e5e7eb;
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.15s;
    }

    .btn:hover {
      background: #374151;
      color: #fff;
      border-color: rgba(255, 255, 255, 0.2);
    }

    .btn-primary {
      background: var(--accent-primary);
      border-color: var(--accent-primary);
      color: #fff;
    }

    .btn-primary:hover {
      background: #4f46e5;
    }

    /* Content Area */
    .content-area {
      flex: 1;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      position: relative;
    }

    .tab-panel {
      display: none;
      flex: 1;
      height: 100%;
      flex-direction: column;
      overflow: hidden;
    }

    .tab-panel.active {
      display: flex;
    }

    /* Data Table Toolbar */
    .table-toolbar {
      padding: 12px 28px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid var(--border-color);
      background: rgba(17, 24, 39, 0.4);
    }

    .filter-box {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .table-search-input {
      width: 280px;
      padding: 7px 12px 7px 32px;
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      border-radius: 6px;
      color: #fff;
      font-size: 13px;
      outline: none;
    }

    .table-search-input:focus {
      border-color: var(--accent-primary);
    }

    .table-pagination-info {
      font-size: 13px;
      color: var(--text-muted);
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .pagination-select {
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      color: #e5e7eb;
      padding: 4px 8px;
      border-radius: 6px;
      font-size: 12px;
      outline: none;
    }

    /* Data Table Container */
    .table-container {
      flex: 1;
      overflow: auto;
      padding: 0 28px 20px 28px;
    }

    table.data-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
      text-align: left;
      margin-top: 16px;
    }

    table.data-table th {
      position: sticky;
      top: 0;
      background: #182234;
      color: #e2e8f0;
      font-weight: 600;
      padding: 10px 14px;
      border-bottom: 2px solid rgba(255, 255, 255, 0.1);
      cursor: pointer;
      user-select: none;
      white-space: nowrap;
      z-index: 5;
    }

    table.data-table th:hover {
      background: #1e2d45;
      color: #fff;
    }

    table.data-table th .th-content {
      display: flex;
      align-items: center;
      gap: 6px;
    }

    table.data-table th .col-type {
      font-size: 10px;
      font-weight: 400;
      color: #94a3b8;
      font-family: 'Fira Code', monospace;
    }

    table.data-table td {
      padding: 10px 14px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
      color: #cbd5e1;
      max-width: 340px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      font-family: 'Inter', sans-serif;
    }

    table.data-table tr:hover td {
      background: rgba(255, 255, 255, 0.03);
      color: #fff;
    }

    .cell-clickable {
      cursor: pointer;
      transition: color 0.1s;
    }
    .cell-clickable:hover {
      color: #a5b4fc !important;
      text-decoration: underline;
    }

    .val-null {
      color: #64748b;
      font-style: italic;
      font-size: 12px;
    }

    .val-pk {
      font-weight: 700;
      color: #38bdf8;
      font-family: 'Fira Code', monospace;
    }

    .val-blob {
      display: inline-block;
      padding: 2px 6px;
      border-radius: 4px;
      background: rgba(245, 158, 11, 0.15);
      color: #fbbf24;
      font-size: 11px;
      font-family: 'Fira Code', monospace;
    }

    .val-json {
      display: inline-block;
      padding: 2px 6px;
      border-radius: 4px;
      background: rgba(168, 85, 247, 0.15);
      color: #c084fc;
      font-size: 11px;
      font-family: 'Fira Code', monospace;
    }

    .val-bool {
      display: inline-block;
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 11px;
      font-family: 'Fira Code', monospace;
    }
    .val-bool-1 {
      background: rgba(16, 185, 129, 0.15);
      color: #34d399;
    }
    .val-bool-0 {
      background: rgba(239, 68, 68, 0.15);
      color: #f87171;
    }

    /* Pagination Footer */
    .pagination-footer {
      padding: 12px 28px;
      border-top: 1px solid var(--border-color);
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: var(--bg-secondary);
    }

    .pagination-btns {
      display: flex;
      gap: 6px;
    }

    .page-btn {
      padding: 5px 10px;
      border-radius: 6px;
      border: 1px solid var(--border-color);
      background: var(--bg-tertiary);
      color: var(--text-secondary);
      font-size: 12px;
      cursor: pointer;
    }

    .page-btn:hover:not(:disabled) {
      background: #374151;
      color: #fff;
    }

    .page-btn:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }

    /* Schema Tab */
    .schema-container {
      padding: 24px 28px;
      overflow-y: auto;
      flex: 1;
    }

    .schema-card {
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 20px;
      margin-bottom: 20px;
    }

    .schema-card-title {
      font-size: 15px;
      font-weight: 700;
      color: #fff;
      margin-bottom: 14px;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .sql-code-block {
      background: #060911;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 8px;
      padding: 16px;
      font-family: 'Fira Code', monospace;
      font-size: 13px;
      color: #a5b4fc;
      white-space: pre-wrap;
      line-height: 1.6;
      overflow-x: auto;
    }

    /* Dashboard Tab */
    .dashboard-container {
      padding: 24px 28px;
      overflow-y: auto;
      flex: 1;
    }

    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 16px;
      margin-bottom: 28px;
    }

    .stat-card {
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 8px;
      position: relative;
      overflow: hidden;
    }

    .stat-card::after {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 3px;
      background: linear-gradient(90deg, #6366f1, #a855f7);
    }

    .stat-label {
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      color: var(--text-muted);
      letter-spacing: 0.05em;
    }

    .stat-value {
      font-size: 28px;
      font-weight: 800;
      color: #fff;
      font-family: 'Fira Code', monospace;
    }

    .stat-sub {
      font-size: 12px;
      color: var(--text-secondary);
    }

    .tables-summary-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 14px;
    }

    .summary-card {
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 16px;
      cursor: pointer;
      transition: all 0.2s;
    }

    .summary-card:hover {
      border-color: var(--accent-primary);
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(0, 0, 0, 0.4);
    }

    .summary-card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;
    }

    .summary-card-title {
      font-size: 14px;
      font-weight: 700;
      color: #fff;
    }

    .summary-card-desc {
      font-size: 12px;
      color: var(--text-muted);
      margin-bottom: 12px;
      line-height: 1.4;
    }

    .summary-card-meta {
      display: flex;
      gap: 12px;
      font-size: 11px;
      color: var(--text-secondary);
      font-family: 'Fira Code', monospace;
    }

    /* Modal */
    .modal-backdrop {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.7);
      backdrop-filter: blur(4px);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 1000;
    }

    .modal-backdrop.open {
      display: flex;
    }

    .modal-box {
      background: var(--bg-secondary);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 12px;
      width: 90%;
      max-width: 650px;
      max-height: 80vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6);
      overflow: hidden;
    }

    .modal-header {
      padding: 16px 20px;
      border-bottom: 1px solid var(--border-color);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .modal-header h3 {
      font-size: 16px;
      color: #fff;
    }

    .modal-close-btn {
      background: transparent;
      border: none;
      color: var(--text-muted);
      font-size: 20px;
      cursor: pointer;
      line-height: 1;
    }
    .modal-close-btn:hover {
      color: #fff;
    }

    .modal-body {
      padding: 20px;
      overflow-y: auto;
      flex: 1;
    }

    .modal-code {
      background: #060911;
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 14px;
      font-family: 'Fira Code', monospace;
      font-size: 13px;
      color: #e2e8f0;
      white-space: pre-wrap;
      word-break: break-all;
    }

    .modal-footer {
      padding: 12px 20px;
      border-top: 1px solid var(--border-color);
      display: flex;
      justify-content: flex-end;
      gap: 10px;
      background: rgba(0, 0, 0, 0.2);
    }

    /* Empty state */
    .empty-state {
      padding: 60px 20px;
      text-align: center;
      color: var(--text-muted);
    }
    .empty-state svg {
      width: 48px;
      height: 48px;
      margin-bottom: 12px;
      opacity: 0.4;
    }
  </style>
</head>
<body>

  <!-- Sidebar -->
  <aside>
    <div class="brand-header">
      <div class="brand-icon">⚡</div>
      <div class="brand-title">
        <h1>AI App Database</h1>
        <p>SQLite 21 張資料表檢視器</p>
      </div>
    </div>

    <div class="search-box">
      <div class="search-input-wrapper">
        <svg viewBox="0 0 24 24"><path d="M10 18a7.952 7.952 0 0 0 4.897-1.688l4.396 4.396 1.414-1.414-4.396-4.396A7.952 7.952 0 0 0 18 10c0-4.411-3.589-8-8-8s-8 3.589-8 8 3.589 8 8 8zm0-14c3.309 0 6 2.691 6 6s-2.691 6-6 6-6-2.691-6-6 2.691-6 6-6z"/></svg>
        <input type="text" id="tableFilterInput" class="search-input" placeholder="搜尋資料表名稱...">
      </div>
    </div>

    <div class="table-nav" id="tableNavContainer">
      <!-- Generated via JS -->
    </div>

    <div class="sidebar-footer">
      <span>總計 21 張資料表</span>
      <span id="totalRecordsBadge">0 筆記錄</span>
    </div>
  </aside>

  <!-- Main Content -->
  <main>
    <header>
      <div class="header-left">
        <div class="current-table-title">
          <span id="currentTableIcon">📊</span>
          <span id="currentTableName">總覽儀表板</span>
          <span id="currentTableBadge" class="current-table-badge">Overview</span>
        </div>
      </div>

      <div class="tab-buttons">
        <button class="tab-btn active" onclick="switchTab('dataTab')">📋 資料內容</button>
        <button class="tab-btn" onclick="switchTab('schemaTab')">📐 結構 Schema</button>
        <button class="tab-btn" onclick="switchTab('dashboardTab')">📊 總覽儀表板</button>
      </div>

      <div class="header-actions">
        <button class="btn" onclick="exportCurrentTable('csv')">匯出 CSV</button>
        <button class="btn btn-primary" onclick="exportCurrentTable('json')">匯出 JSON</button>
      </div>
    </header>

    <div class="content-area">
      
      <!-- 1. DATA TAB -->
      <div id="dataTab" class="tab-panel active">
        <div class="table-toolbar">
          <div class="filter-box">
            <div class="search-input-wrapper">
              <svg viewBox="0 0 24 24"><path d="M10 18a7.952 7.952 0 0 0 4.897-1.688l4.396 4.396 1.414-1.414-4.396-4.396A7.952 7.952 0 0 0 18 10c0-4.411-3.589-8-8-8s-8 3.589-8 8 3.589 8 8 8zm0-14c3.309 0 6 2.691 6 6s-2.691 6-6 6-6-2.691-6-6 2.691-6 6-6z"/></svg>
              <input type="text" id="rowSearchInput" class="table-search-input" placeholder="在當前資料表中搜尋關鍵字...">
            </div>
          </div>
          <div class="table-pagination-info">
            <span id="paginationInfoText">顯示第 1 - 10 筆，共 0 筆</span>
            <label>每頁：</label>
            <select id="pageSizeSelect" class="pagination-select" onchange="changePageSize(this.value)">
              <option value="10">10 筆</option>
              <option value="25" selected>25 筆</option>
              <option value="50">50 筆</option>
              <option value="100">100 筆</option>
              <option value="all">全部</option>
            </select>
          </div>
        </div>

        <div class="table-container" id="tableContainer">
          <table class="data-table" id="dataTable">
            <thead id="dataThead"></thead>
            <tbody id="dataTbody"></tbody>
          </table>
        </div>

        <div class="pagination-footer">
          <div id="paginationSummary" style="font-size: 13px; color: var(--text-muted);"></div>
          <div class="pagination-btns">
            <button class="page-btn" id="btnFirstPage" onclick="goToPage(1)">« 首頁</button>
            <button class="page-btn" id="btnPrevPage" onclick="prevPage()">‹ 上一頁</button>
            <button class="page-btn" id="btnNextPage" onclick="nextPage()">下一頁 ›</button>
            <button class="page-btn" id="btnLastPage" onclick="goToLastPage()">末頁 »</button>
          </div>
        </div>
      </div>

      <!-- 2. SCHEMA TAB -->
      <div id="schemaTab" class="tab-panel">
        <div class="schema-container">
          <div class="schema-card">
            <div class="schema-card-title">
              <span>📌 欄位規格 (Columns Definition)</span>
            </div>
            <table class="data-table" style="margin-top: 0;">
              <thead>
                <tr>
                  <th>CID</th>
                  <th>欄位名稱 (Name)</th>
                  <th>資料型別 (Type)</th>
                  <th>非空限制 (Not Null)</th>
                  <th>預設值 (Default)</th>
                  <th>主鍵 (Primary Key)</th>
                </tr>
              </thead>
              <tbody id="schemaColsTbody"></tbody>
            </table>
          </div>

          <div class="schema-card">
            <div class="schema-card-title">
              <span>🔗 外鍵關聯 (Foreign Keys)</span>
            </div>
            <div id="schemaFksContainer"></div>
          </div>

          <div class="schema-card">
            <div class="schema-card-title">
              <span>📝 CREATE TABLE SQL 語句</span>
            </div>
            <pre class="sql-code-block" id="schemaSqlCode"></pre>
          </div>
        </div>
      </div>

      <!-- 3. DASHBOARD TAB -->
      <div id="dashboardTab" class="tab-panel">
        <div class="dashboard-container">
          <div class="stats-grid">
            <div class="stat-card">
              <div class="stat-label">總資料表數</div>
              <div class="stat-value" id="statTotalTables">21</div>
              <div class="stat-sub">涵蓋 6 大功能模組</div>
            </div>
            <div class="stat-card">
              <div class="stat-label">總資料筆數</div>
              <div class="stat-value" id="statTotalRows">0</div>
              <div class="stat-sub">本機預覽資料庫記錄數</div>
            </div>
            <div class="stat-card">
              <div class="stat-label">資料庫架構版本</div>
              <div class="stat-value">v17</div>
              <div class="stat-sub">SQLite 3 / Flutter Engine</div>
            </div>
            <div class="stat-card">
              <div class="stat-label">安全保護機制</div>
              <div class="stat-value" style="color: #34d399; font-size: 22px;">ON CASCADE</div>
              <div class="stat-sub">外鍵關聯自動連鎖防禦</div>
            </div>
          </div>

          <h2 style="font-size: 16px; font-weight: 700; margin-bottom: 14px; color: #fff;">📚 完整資料表清單與卡片總覽</h2>
          <div class="tables-summary-grid" id="tablesSummaryGrid"></div>
        </div>
      </div>

    </div>
  </main>

  <!-- Cell Detail Modal -->
  <div class="modal-backdrop" id="cellModal" onclick="closeModal(event)">
    <div class="modal-box" onclick="event.stopPropagation()">
      <div class="modal-header">
        <h3 id="modalTitle">欄位詳細內容</h3>
        <button class="modal-close-btn" onclick="closeModalDirect()">×</button>
      </div>
      <div class="modal-body">
        <pre class="modal-code" id="modalContent"></pre>
      </div>
      <div class="modal-footer">
        <button class="btn" onclick="copyModalContent()">複製內容</button>
        <button class="btn btn-primary" onclick="closeModalDirect()">關閉</button>
      </div>
    </div>
  </div>

  <script>
    // Embedded Database Data
    const DATABASE_DATA = ''' + json_data_str + ''';

    // Categories definition
    const CATEGORIES = [
      {
        id: 'user_auth',
        name: '👤 使用者與會員系統',
        tables: ['users', 'point_transactions']
      },
      {
        id: 'quiz_study',
        name: '📝 題庫與測驗系統',
        tables: ['questions', 'tags', 'question_tag_map', 'user_papers', 'wrong_questions', 'quiz_results', 'remedial_materials']
      },
      {
        id: 'calendar_productivity',
        name: '📅 行事曆與個人記錄',
        tables: ['calendar_events', 'todos', 'notes', 'diaries']
      },
      {
        id: 'social_community',
        name: '💬 社群動態牆',
        tables: ['posts', 'post_likes', 'comments', 'post_bookmarks']
      },
      {
        id: 'groups_system',
        name: '👥 讀書會群組系統',
        tables: ['community_groups', 'group_members', 'group_announcements']
      },
      {
        id: 'marketing_ads',
        name: '📢 廣告與行銷推廣',
        tables: ['advertisements']
      }
    ];

    const TABLE_DESCRIPTIONS = {
      'users': '使用者帳號、個人檔案、主題顏色、會員等級與點數餘額',
      'point_transactions': '點數與積分交易歷程記錄（簽到、兌換消耗等）',
      'questions': '完整題庫資料（單選/複選、詳解、難度、學科分類）',
      'tags': '題目與分類標籤（如：中國史、力學等）',
      'question_tag_map': '題目與標籤多對多對應關係關聯表',
      'user_papers': '使用者自訂組卷與自建試卷清單',
      'wrong_questions': '錯題本與個人弱點檢討筆記',
      'quiz_results': '歷次測驗作答結果、作答時間、答題正確率統計',
      'remedial_materials': 'AI 自動弱點分析與各學科補救教材',
      'calendar_events': '行事曆事件、週期重複排程、時間與地點記錄',
      'todos': '個人待辦清單與完成時間',
      'notes': '個人筆記與語音智慧聽寫轉文字筆記',
      'diaries': '每日生活與學習日記',
      'posts': '社群動態牆貼文（含圖片/檔案二進位儲存）',
      'post_likes': '社群貼文按讚與防重複機制',
      'comments': '貼文留言與多層巢狀回覆討論',
      'post_bookmarks': '貼文收藏清單',
      'community_groups': '讀書會社群群組基本資料與邀請碼',
      'group_members': '群組成員、權限角色（管理員/成員）與狀態',
      'group_announcements': '群組置頂公告與最新通知',
      'advertisements': '橫幅推廣廣告與全國大賽活動資訊'
    };

    let currentTable = 'users';
    let currentPage = 1;
    let pageSize = 25;
    let sortColumn = null;
    let sortAsc = true;
    let filterQuery = '';

    // Initialize UI
    function init() {
      let totalRows = 0;
      Object.keys(DATABASE_DATA).forEach(k => {
        totalRows += DATABASE_DATA[k].rowCount;
      });

      document.getElementById('statTotalRows').innerText = totalRows.toLocaleString();
      document.getElementById('totalRecordsBadge').innerText = `${totalRows.toLocaleString()} 筆記錄`;

      renderSidebar();
      renderDashboard();
      selectTable(Object.keys(DATABASE_DATA)[0] || 'users');

      // Setup Search listeners
      document.getElementById('tableFilterInput').addEventListener('input', (e) => {
        filterSidebar(e.target.value);
      });

      document.getElementById('rowSearchInput').addEventListener('input', (e) => {
        filterQuery = e.target.value.toLowerCase();
        currentPage = 1;
        renderTableData();
      });
    }

    function renderSidebar() {
      const container = document.getElementById('tableNavContainer');
      container.innerHTML = '';

      CATEGORIES.forEach(cat => {
        const catDiv = document.createElement('div');
        catDiv.className = 'nav-category';

        const titleDiv = document.createElement('div');
        titleDiv.className = 'nav-category-title';
        titleDiv.innerHTML = `<span>${cat.name}</span>`;
        catDiv.appendChild(titleDiv);

        cat.tables.forEach(tableName => {
          if (!DATABASE_DATA[tableName]) return;
          const tData = DATABASE_DATA[tableName];
          const item = document.createElement('div');
          item.className = `table-item ${tableName === currentTable ? 'active' : ''}`;
          item.id = `nav-item-${tableName}`;
          item.onclick = () => selectTable(tableName);

          item.innerHTML = `
            <div class="table-item-name">
              <span>📄</span>
              <span>${tableName}</span>
            </div>
            <span class="table-badge">${tData.rowCount}</span>
          `;
          catDiv.appendChild(item);
        });

        container.appendChild(catDiv);
      });
    }

    function filterSidebar(query) {
      const q = query.toLowerCase();
      document.querySelectorAll('.table-item').forEach(item => {
        const name = item.id.replace('nav-item-', '');
        if (name.toLowerCase().includes(q)) {
          item.style.display = 'flex';
        } else {
          item.style.display = 'none';
        }
      });
    }

    function selectTable(tableName) {
      if (!DATABASE_DATA[tableName]) return;
      currentTable = tableName;
      currentPage = 1;
      sortColumn = null;
      sortAsc = true;
      filterQuery = '';
      document.getElementById('rowSearchInput').value = '';

      // Update sidebar active class
      document.querySelectorAll('.table-item').forEach(el => el.classList.remove('active'));
      const activeEl = document.getElementById(`nav-item-${tableName}`);
      if (activeEl) activeEl.classList.add('active');

      // Update Header
      document.getElementById('currentTableName').innerText = tableName;
      document.getElementById('currentTableBadge').innerText = `${DATABASE_DATA[tableName].rowCount} 筆資料 • ${DATABASE_DATA[tableName].columns.length} 欄位`;

      renderTableData();
      renderSchemaTab();
    }

    function renderTableData() {
      const tData = DATABASE_DATA[currentTable];
      if (!tData) return;

      const thead = document.getElementById('dataThead');
      const tbody = document.getElementById('dataTbody');

      // Build Headers
      thead.innerHTML = '';
      const trHead = document.createElement('tr');
      
      const thIndex = document.createElement('th');
      thIndex.style.width = '50px';
      thIndex.innerText = '#';
      trHead.appendChild(thIndex);

      tData.columns.forEach(col => {
        const th = document.createElement('th');
        th.onclick = () => sortBy(col.name);
        
        let sortIcon = '';
        if (sortColumn === col.name) {
          sortIcon = sortAsc ? ' ▲' : ' ▼';
        }

        th.innerHTML = `
          <div class="th-content">
            <span>${col.name}${col.pk ? ' 🔑' : ''}${sortIcon}</span>
            <span class="col-type">${col.type || 'TEXT'}</span>
          </div>
        `;
        trHead.appendChild(th);
      });
      thead.appendChild(trHead);

      // Filter rows
      let filteredRows = tData.rows.filter(row => {
        if (!filterQuery) return true;
        return Object.values(row).some(val => {
          if (val === null || val === undefined) return false;
          return String(val).toLowerCase().includes(filterQuery);
        });
      });

      // Sort rows
      if (sortColumn) {
        filteredRows.sort((a, b) => {
          let vA = a[sortColumn];
          let vB = b[sortColumn];
          if (vA === null) return 1;
          if (vB === null) return -1;
          if (typeof vA === 'number' && typeof vB === 'number') {
            return sortAsc ? vA - vB : vB - vA;
          }
          return sortAsc 
            ? String(vA).localeCompare(String(vB), 'zh-Hant')
            : String(vB).localeCompare(String(vA), 'zh-Hant');
        });
      }

      // Pagination
      const totalFiltered = filteredRows.length;
      let pSize = pageSize === 'all' ? totalFiltered : parseInt(pageSize, 10);
      if (pSize <= 0) pSize = 1;
      const totalPages = Math.ceil(totalFiltered / pSize) || 1;
      if (currentPage > totalPages) currentPage = totalPages;

      const startIdx = (currentPage - 1) * pSize;
      const endIdx = pageSize === 'all' ? totalFiltered : Math.min(startIdx + pSize, totalFiltered);
      const displayRows = filteredRows.slice(startIdx, endIdx);

      // Render Rows
      tbody.innerHTML = '';
      if (displayRows.length === 0) {
        const emptyTr = document.createElement('tr');
        emptyTr.innerHTML = `<td colspan="${tData.columns.length + 1}" class="empty-state">查無相關資料記錄</td>`;
        tbody.appendChild(emptyTr);
      } else {
        displayRows.forEach((row, rIdx) => {
          const tr = document.createElement('tr');
          
          const tdIdx = document.createElement('td');
          tdIdx.style.color = 'var(--text-muted)';
          tdIdx.style.fontSize = '11px';
          tdIdx.innerText = startIdx + rIdx + 1;
          tr.appendChild(tdIdx);

          tData.columns.forEach(col => {
            const td = document.createElement('td');
            const val = row[col.name];
            
            if (val === null || val === undefined) {
              td.innerHTML = '<span class="val-null">NULL</span>';
            } else if (typeof val === 'string' && val.startsWith('<BLOB')) {
              td.innerHTML = `<span class="val-blob">${val}</span>`;
            } else if (typeof val === 'string' && (val.startsWith('{') || val.startsWith('[')) && (val.endsWith('}') || val.endsWith(']'))) {
              td.innerHTML = `<span class="val-json cell-clickable" onclick="openCellDetail('${col.name}', '${escapeJson(val)}')">JSON (${val.length} 字符)</span>`;
            } else if (col.pk) {
              td.innerHTML = `<span class="val-pk">${escapeHtml(String(val))}</span>`;
            } else if (typeof val === 'number' && (val === 0 || val === 1) && (col.name.startsWith('is_') || col.name.startsWith('has_') || col.name.endsWith('_active') || col.name === 'done')) {
              td.innerHTML = `<span class="val-bool ${val === 1 ? 'val-bool-1' : 'val-bool-0'}">${val === 1 ? 'TRUE (1)' : 'FALSE (0)'}</span>`;
            } else {
              const strVal = String(val);
              td.innerText = strVal;
              td.title = strVal;
              if (strVal.length > 30) {
                td.classList.add('cell-clickable');
                td.onclick = () => openCellDetail(col.name, strVal);
              }
            }
            tr.appendChild(td);
          });

          tbody.appendChild(tr);
        });
      }

      // Update Pagination Bar
      document.getElementById('paginationInfoText').innerText = 
        `顯示第 ${totalFiltered === 0 ? 0 : startIdx + 1} - ${endIdx} 筆，共 ${totalFiltered} 筆`;
      document.getElementById('paginationSummary').innerText = 
        `第 ${currentPage} 頁 / 共 ${totalPages} 頁`;

      document.getElementById('btnFirstPage').disabled = currentPage <= 1;
      document.getElementById('btnPrevPage').disabled = currentPage <= 1;
      document.getElementById('btnNextPage').disabled = currentPage >= totalPages;
      document.getElementById('btnLastPage').disabled = currentPage >= totalPages;
    }

    function sortBy(colName) {
      if (sortColumn === colName) {
        sortAsc = !sortAsc;
      } else {
        sortColumn = colName;
        sortAsc = true;
      }
      renderTableData();
    }

    function changePageSize(val) {
      pageSize = val;
      currentPage = 1;
      renderTableData();
    }

    function goToPage(page) {
      currentPage = page;
      renderTableData();
    }

    function prevPage() {
      if (currentPage > 1) {
        currentPage--;
        renderTableData();
      }
    }

    function nextPage() {
      currentPage++;
      renderTableData();
    }

    function goToLastPage() {
      const tData = DATABASE_DATA[currentTable];
      if (!tData) return;
      const pSize = pageSize === 'all' ? tData.rows.length : parseInt(pageSize, 10);
      const totalPages = Math.ceil(tData.rows.length / pSize) || 1;
      currentPage = totalPages;
      renderTableData();
    }

    function renderSchemaTab() {
      const tData = DATABASE_DATA[currentTable];
      if (!tData) return;

      const tbody = document.getElementById('schemaColsTbody');
      tbody.innerHTML = '';

      tData.columns.forEach(col => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td style="font-family: 'Fira Code', monospace; color: var(--text-muted);">${col.cid}</td>
          <td style="font-weight: 600; color: #fff;">${col.name}${col.pk ? ' 🔑 (PK)' : ''}</td>
          <td style="font-family: 'Fira Code', monospace; color: #818cf8;">${col.type || 'TEXT'}</td>
          <td>${col.notnull ? '<span style="color:#f87171;">YES</span>' : '<span style="color:var(--text-muted);">NO</span>'}</td>
          <td style="font-family: 'Fira Code', monospace; color: #fbbf24;">${col.dflt_value !== null ? col.dflt_value : '<span class="val-null">NULL</span>'}</td>
          <td>${col.pk ? '<span style="color:#38bdf8; font-weight:700;">PRIMARY KEY</span>' : '-'}</td>
        `;
        tbody.appendChild(tr);
      });

      // Foreign keys
      const fkContainer = document.getElementById('schemaFksContainer');
      fkContainer.innerHTML = '';
      if (tData.foreign_keys && tData.foreign_keys.length > 0) {
        const ul = document.createElement('ul');
        ul.style.listStyle = 'none';
        tData.foreign_keys.forEach(fk => {
          const li = document.createElement('li');
          li.style.padding = '8px 0';
          li.style.borderBottom = '1px solid rgba(255,255,255,0.05)';
          li.style.fontFamily = 'Fira Code, monospace';
          li.style.fontSize = '13px';
          li.innerHTML = `➡️ 欄位 <strong style="color:#818cf8">${fk.from}</strong> 參考至 <strong style="color:#34d399">${fk.table} (${fk.to})</strong> [ON UPDATE: ${fk.on_update}, ON DELETE: ${fk.on_delete}]`;
          ul.appendChild(li);
        });
        fkContainer.appendChild(ul);
      } else {
        fkContainer.innerHTML = '<span style="color: var(--text-muted); font-size: 13px;">無外鍵約束設定</span>';
      }

      // SQL statement
      document.getElementById('schemaSqlCode').innerText = tData.sql || '-- No SQL available';
    }

    function renderDashboard() {
      const container = document.getElementById('tablesSummaryGrid');
      container.innerHTML = '';

      Object.keys(DATABASE_DATA).forEach(tableName => {
        const tData = DATABASE_DATA[tableName];
        const card = document.createElement('div');
        card.className = 'summary-card';
        card.onclick = () => {
          selectTable(tableName);
          switchTab('dataTab');
        };

        const desc = TABLE_DESCRIPTIONS[tableName] || '資料表';

        card.innerHTML = `
          <div class="summary-card-header">
            <span class="summary-card-title">📄 ${tableName}</span>
            <span class="table-badge">${tData.rowCount} 筆</span>
          </div>
          <div class="summary-card-desc">${desc}</div>
          <div class="summary-card-meta">
            <span>📐 ${tData.columns.length} 欄位</span>
            <span>🔗 ${(tData.foreign_keys || []).length} 外鍵</span>
          </div>
        `;
        container.appendChild(card);
      });
    }

    function switchTab(tabId) {
      document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      
      const targetPanel = document.getElementById(tabId);
      if (targetPanel) targetPanel.classList.add('active');

      const btns = document.querySelectorAll('.tab-btn');
      if (tabId === 'dataTab') btns[0].classList.add('active');
      if (tabId === 'schemaTab') btns[1].classList.add('active');
      if (tabId === 'dashboardTab') btns[2].classList.add('active');
    }

    function openCellDetail(colName, content) {
      document.getElementById('modalTitle').innerText = `欄位 [${colName}] 詳細內容`;
      
      let formatted = content;
      try {
        const parsed = JSON.parse(content);
        formatted = JSON.stringify(parsed, null, 2);
      } catch (e) {}

      document.getElementById('modalContent').innerText = formatted;
      document.getElementById('cellModal').classList.add('open');
    }

    function closeModalDirect() {
      document.getElementById('cellModal').classList.remove('open');
    }

    function closeModal(e) {
      if (e.target.id === 'cellModal') {
        closeModalDirect();
      }
    }

    function copyModalContent() {
      const text = document.getElementById('modalContent').innerText;
      navigator.clipboard.writeText(text).then(() => {
        alert('已成功複製到剪貼簿！');
      });
    }

    function exportCurrentTable(type) {
      const tData = DATABASE_DATA[currentTable];
      if (!tData) return;

      if (type === 'json') {
        const blob = new Blob([JSON.stringify(tData.rows, null, 2)], { type: 'application/json' });
        downloadBlob(blob, `${currentTable}_export.json`);
      } else if (type === 'csv') {
        if (tData.rows.length === 0) {
          alert('當前資料表無資料可匯出！');
          return;
        }
        const headers = tData.columns.map(c => c.name);
        let csvContent = headers.join(',') + '\\n';
        tData.rows.forEach(r => {
          const rowVals = headers.map(h => {
            let v = r[h];
            if (v === null || v === undefined) return '""';
            let str = String(v).replace(/"/g, '""');
            return `"${str}"`;
          });
          csvContent += rowVals.join(',') + '\\n';
        });
        const blob = new Blob(['\\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
        downloadBlob(blob, `${currentTable}_export.csv`);
      }
    }

    function downloadBlob(blob, filename) {
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }

    function escapeHtml(str) {
      return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }

    function escapeJson(str) {
      return str.replace(/'/g, "\\\\'").replace(/"/g, '&quot;');
    }

    // Run
    window.onload = init;
  </script>
</body>
</html>
'''

with open('database_viewer.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print("Generated database_viewer.html successfully!")
