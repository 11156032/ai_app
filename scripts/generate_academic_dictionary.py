import json
import os

# Load actual database data
with open('db_export.json', 'r', encoding='utf-8') as f:
    db_data = json.load(f)

# Comprehensive Dictionary Schema Definition matching user's exact academic style
TABLE_SCHEMAS = [
    {
        "code": "T01",
        "name": "users",
        "chinese": "使用者資料表",
        "fields": [
            {"en": "id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": True, "fk": ""},
            {"en": "username", "zh": "使用者名稱", "type": "VARCHAR", "len": "150", "pk": False, "fk": ""},
            {"en": "email", "zh": "電子郵件", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "hashed_password", "zh": "密碼雜湊", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "display_name", "zh": "顯示暱稱", "type": "VARCHAR", "len": "100", "pk": False, "fk": ""},
            {"en": "bio", "zh": "個人簡介", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "tags", "zh": "關注標籤", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "avatar_blob", "zh": "頭像圖檔", "type": "BLOB", "len": "-", "pk": False, "fk": ""},
            {"en": "avatar_color", "zh": "頭像顏色編號", "type": "INTEGER", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "avatar_selected", "zh": "自訂頭像", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "nickname_updated_at", "zh": "最後暱稱更新時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "is_email_verified", "zh": "信箱是否驗證", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "font_size_factor", "zh": "字體倍率", "type": "Decimal(3,1)", "len": "", "pk": False, "fk": ""},
            {"en": "theme_color_idx", "zh": "主題色編號", "type": "TINYINT", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "is_dark_mode", "zh": "是否深色模式", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "gemini_api_key", "zh": "Gemini API 金鑰", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "is_google", "zh": "是否 Google 登入", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "calendar_view_mode", "zh": "行事曆檢視模式", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "social_feed_layout", "zh": "社群排版樣式", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "is_currently_logged_in", "zh": "當前是否登入", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "show_floating_nav_bar", "zh": "是否顯示懸浮導覽列", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "nav_bar_items", "zh": "自訂導覽列項目", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "push_notifications_enabled", "zh": "是否啟用推播通知", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "language", "zh": "介面語言設定", "type": "VARCHAR", "len": "20", "pk": False, "fk": ""},
            {"en": "deleted_at", "zh": "軟刪除時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "has_seen_tour", "zh": "是否完成導覽教學", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "membership_tier", "zh": "會員等級", "type": "VARCHAR", "len": "20", "pk": False, "fk": ""},
            {"en": "membership_expires_at", "zh": "會員到期時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "points_balance", "zh": "積分點數餘額", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": ""},
            {"en": "last_daily_reward_at", "zh": "最後簽到獎勵時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T02",
        "name": "calendar_events",
        "chinese": "行事曆事件資料表",
        "fields": [
            {"en": "id", "zh": "事件編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "title", "zh": "事件標題", "type": "VARCHAR", "len": "200", "pk": False, "fk": ""},
            {"en": "description", "zh": "事件說明", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "is_all_day", "zh": "是否全天事件", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "start_time", "zh": "開始時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "end_time", "zh": "結束時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "location", "zh": "地點", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "color", "zh": "標籤色彩", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "recurrence_type", "zh": "週期重複類型", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "recurrence_days", "zh": "重複星期設定", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "recurrence_end", "zh": "重複結束日期", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "updated_at", "zh": "更新時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T03",
        "name": "tags",
        "chinese": "標籤資料表",
        "fields": [
            {"en": "id", "zh": "標籤編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "name", "zh": "標籤名稱", "type": "VARCHAR", "len": "100", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T04",
        "name": "questions",
        "chinese": "題庫題目資料表",
        "fields": [
            {"en": "id", "zh": "題目編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "建立者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "text", "zh": "題目文字", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "options", "zh": "題目選項 (JSON)", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "answer", "zh": "標準解答", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "explanation", "zh": "解析說明", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "subject", "zh": "所屬學科", "type": "VARCHAR", "len": "100", "pk": False, "fk": ""},
            {"en": "type", "zh": "題型分類", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "difficulty", "zh": "難易度", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "is_public", "zh": "是否公開", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "bookmarked", "zh": "是否收藏", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T05",
        "name": "question_tag_map",
        "chinese": "題目標籤關聯表",
        "fields": [
            {"en": "question_id", "zh": "題目編號", "type": "INTEGER", "len": "4 bytes", "pk": True, "fk": "questions.id"},
            {"en": "tag_id", "zh": "標籤編號", "type": "INTEGER", "len": "4 bytes", "pk": True, "fk": "tags.id"}
        ]
    },
    {
        "code": "T06",
        "name": "notes",
        "chinese": "筆記資料表",
        "fields": [
            {"en": "id", "zh": "筆記編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "title", "zh": "筆記標題", "type": "VARCHAR", "len": "200", "pk": False, "fk": ""},
            {"en": "content", "zh": "筆記內容", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "updated_at", "zh": "更新時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T07",
        "name": "diaries",
        "chinese": "日記資料表",
        "fields": [
            {"en": "id", "zh": "日記編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "date", "zh": "日記日期", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "content", "zh": "日記內容", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "updated_at", "zh": "更新時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T08",
        "name": "todos",
        "chinese": "待辦事項資料表",
        "fields": [
            {"en": "id", "zh": "待辦編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "text", "zh": "待辦內容", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "done", "zh": "是否完成", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "done_at", "zh": "完成時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T09",
        "name": "posts",
        "chinese": "社群貼文資料表",
        "fields": [
            {"en": "id", "zh": "貼文編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "發布者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "group_id", "zh": "所屬群組編號", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": "community_groups.id"},
            {"en": "content", "zh": "貼文內容", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "type", "zh": "貼文類型", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "attached_data", "zh": "附加資料 (JSON)", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "media_blob", "zh": "圖片多媒體檔案", "type": "BLOB", "len": "-", "pk": False, "fk": ""},
            {"en": "file_blob", "zh": "附加檔案", "type": "BLOB", "len": "-", "pk": False, "fk": ""},
            {"en": "likes", "zh": "按讚數量", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": ""},
            {"en": "is_edited", "zh": "是否已編輯", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "發布時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T10",
        "name": "post_likes",
        "chinese": "貼文按讚資料表",
        "fields": [
            {"en": "id", "zh": "按讚編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "post_id", "zh": "貼文編號", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": "posts.id"},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"}
        ]
    },
    {
        "code": "T11",
        "name": "comments",
        "chinese": "貼文留言資料表",
        "fields": [
            {"en": "id", "zh": "留言編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "post_id", "zh": "貼文編號", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": "posts.id"},
            {"en": "user_id", "zh": "留言者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "text", "zh": "留言內容", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "parent_id", "zh": "父留言編號 (巢狀回覆)", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": "comments.id"},
            {"en": "created_at", "zh": "留言時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T12",
        "name": "quiz_results",
        "chinese": "測驗結果記錄表",
        "fields": [
            {"en": "id", "zh": "紀錄編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "測驗者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "total", "zh": "總題數", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": ""},
            {"en": "correct", "zh": "答對題數", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": ""},
            {"en": "wrong_question_ids", "zh": "錯題編號 (JSON)", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "duration_seconds", "zh": "答題耗時(秒)", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": ""},
            {"en": "subject", "zh": "測驗科目", "type": "VARCHAR", "len": "100", "pk": False, "fk": ""},
            {"en": "paper_id", "zh": "自訂試卷編號", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": "user_papers.id"},
            {"en": "timestamp", "zh": "測驗完成時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T13",
        "name": "post_bookmarks",
        "chinese": "貼文收藏資料表",
        "fields": [
            {"en": "id", "zh": "收藏編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "post_id", "zh": "貼文編號", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": "posts.id"},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"}
        ]
    },
    {
        "code": "T14",
        "name": "community_groups",
        "chinese": "讀書會群組資料表",
        "fields": [
            {"en": "id", "zh": "群組編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "name", "zh": "群組名稱", "type": "VARCHAR", "len": "150", "pk": False, "fk": ""},
            {"en": "description", "zh": "群組簡介", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "icon_emoji", "zh": "圖示表情", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "type", "zh": "群組類型 (公開/私密)", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "owner_id", "zh": "建立者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "tags", "zh": "標籤清單 (JSON)", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "member_count", "zh": "成員總數", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": ""},
            {"en": "invite_token", "zh": "邀請碼 Token", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "token_expires_at", "zh": "邀請碼到期時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "invite_link_active", "zh": "邀請連結是否啟用", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "join_requires_approval", "zh": "加入是否需審核", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T15",
        "name": "group_members",
        "chinese": "群組成員資料表",
        "fields": [
            {"en": "id", "zh": "成員紀錄編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "group_id", "zh": "群組編號", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": "community_groups.id"},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "role", "zh": "成員角色 (owner/admin/member)", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "status", "zh": "狀態 (active/pending)", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "joined_at", "zh": "加入時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "last_read_at", "zh": "最後已讀時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "is_muted", "zh": "是否靜音通知", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T16",
        "name": "group_announcements",
        "chinese": "群組公告資料表",
        "fields": [
            {"en": "id", "zh": "公告編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "group_id", "zh": "群組編號", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": "community_groups.id"},
            {"en": "author_id", "zh": "發布者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "content", "zh": "公告內容", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "is_pinned", "zh": "是否置頂", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T17",
        "name": "user_papers",
        "chinese": "使用者自訂試卷資料表",
        "fields": [
            {"en": "id", "zh": "試卷編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "name", "zh": "試卷名稱", "type": "VARCHAR", "len": "150", "pk": False, "fk": ""},
            {"en": "question_ids", "zh": "題目編號清單 (JSON)", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T18",
        "name": "wrong_questions",
        "chinese": "錯題本資料表",
        "fields": [
            {"en": "id", "zh": "錯題編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "question_id", "zh": "題目編號", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": "questions.id"},
            {"en": "note", "zh": "檢討筆記", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "加入時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T19",
        "name": "remedial_materials",
        "chinese": "弱點補救教材資料表",
        "fields": [
            {"en": "id", "zh": "教材編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "subject", "zh": "弱點學科", "type": "VARCHAR", "len": "100", "pk": False, "fk": ""},
            {"en": "content", "zh": "AI 生成補救教材", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "生成時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""},
            {"en": "updated_at", "zh": "更新時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T20",
        "name": "point_transactions",
        "chinese": "點數積分交易紀錄資料表",
        "fields": [
            {"en": "id", "zh": "交易編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "user_id", "zh": "使用者編號", "type": "VARCHAR", "len": "255", "pk": False, "fk": "users.id"},
            {"en": "amount", "zh": "變動點數", "type": "INTEGER", "len": "4 bytes", "pk": False, "fk": ""},
            {"en": "type", "zh": "交易類型 (reward/redeem)", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "description", "zh": "交易說明", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "交易時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    },
    {
        "code": "T21",
        "name": "advertisements",
        "chinese": "廣告推廣資料表",
        "fields": [
            {"en": "id", "zh": "廣告編號", "type": "INTEGER", "len": "AUTO", "pk": True, "fk": ""},
            {"en": "title", "zh": "廣告標題", "type": "VARCHAR", "len": "200", "pk": False, "fk": ""},
            {"en": "content", "zh": "廣告內容文案", "type": "TEXT", "len": "-", "pk": False, "fk": ""},
            {"en": "sponsor", "zh": "主辦/贊助單位", "type": "VARCHAR", "len": "150", "pk": False, "fk": ""},
            {"en": "link_url", "zh": "外部連結網址", "type": "VARCHAR", "len": "255", "pk": False, "fk": ""},
            {"en": "bg_gradient", "zh": "漸層背景配色", "type": "VARCHAR", "len": "50", "pk": False, "fk": ""},
            {"en": "is_active", "zh": "是否啟用上架", "type": "BOOLEAN", "len": "1 byte", "pk": False, "fk": ""},
            {"en": "created_at", "zh": "建立時間", "type": "DATETIME", "len": "", "pk": False, "fk": ""}
        ]
    }
]

db_json_str = json.dumps(db_data, ensure_ascii=False)
schema_json_str = json.dumps(TABLE_SCHEMAS, ensure_ascii=False)

html_code = f'''<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI App 資料庫規格說明書與資料字典 (Data Dictionary)</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600&family=Noto+Serif+TC:wght@400;600;700;900&family=Noto+Sans+TC:wght@300;400;500;700&display=swap" rel="stylesheet">
  <style>
    :root {{
      --primary-color: #1e293b;
      --border-dark: #000000;
      --bg-page: #f8fafc;
      --bg-paper: #ffffff;
      --text-main: #0f172a;
    }}

    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }}

    body {{
      font-family: 'Times New Roman', 'Noto Serif TC', 'PMingLiU', serif;
      background-color: var(--bg-page);
      color: var(--text-main);
      padding: 30px 20px;
      line-height: 1.5;
      -webkit-font-smoothing: antialiased;
    }}

    /* Top Control Bar */
    .top-controls {{
      max-width: 900px;
      margin: 0 auto 24px auto;
      background: #ffffff;
      padding: 14px 20px;
      border-radius: 10px;
      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.06);
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 12px;
      font-family: 'Noto Sans TC', sans-serif;
    }}

    .controls-title {{
      font-size: 16px;
      font-weight: 700;
      color: #1e293b;
      display: flex;
      align-items: center;
      gap: 8px;
    }}

    .controls-actions {{
      display: flex;
      gap: 10px;
      align-items: center;
    }}

    .btn {{
      padding: 8px 16px;
      border-radius: 6px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      border: 1px solid #cbd5e1;
      background: #ffffff;
      color: #334155;
      transition: all 0.2s;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      text-decoration: none;
    }}

    .btn:hover {{
      background: #f1f5f9;
      border-color: #94a3b8;
    }}

    .btn-primary {{
      background: #2563eb;
      color: #ffffff;
      border-color: #2563eb;
    }}
    .btn-primary:hover {{
      background: #1d4ed8;
    }}

    .select-table-jump {{
      padding: 8px 12px;
      border-radius: 6px;
      border: 1px solid #cbd5e1;
      font-size: 13px;
      color: #1e293b;
      background: #ffffff;
      outline: none;
    }}

    /* Document Paper Container */
    .document-container {{
      max-width: 900px;
      margin: 0 auto;
      background: var(--bg-paper);
      padding: 50px 45px;
      border-radius: 8px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
    }}

    .doc-header {{
      text-align: center;
      margin-bottom: 36px;
      padding-bottom: 20px;
      border-bottom: 2px solid #000;
    }}

    .doc-header h1 {{
      font-size: 26px;
      font-weight: 900;
      letter-spacing: 2px;
      margin-bottom: 8px;
    }}

    .doc-header p {{
      font-size: 14px;
      color: #475569;
    }}

    /* Academic Data Dictionary Table Style */
    .table-section {{
      margin-bottom: 45px;
      page-break-inside: avoid;
    }}

    .academic-table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 15px;
      text-align: center;
      border: 2px solid #000000;
      background: #ffffff;
    }}

    /* Table Title Span */
    .academic-table thead tr.table-title-row th {{
      font-size: 16px;
      font-weight: 700;
      padding: 10px 8px;
      border-bottom: 1.5px solid #000000;
      letter-spacing: 1px;
      background: #ffffff;
      color: #000000;
    }}

    /* Column Headers */
    .academic-table thead tr.col-header-row th {{
      font-size: 15px;
      font-weight: 600;
      padding: 8px 6px;
      border: 1px solid #000000;
      background: #ffffff;
      color: #000000;
    }}

    /* Data Rows */
    .academic-table tbody td {{
      padding: 7px 8px;
      border: 1px solid #000000;
      font-size: 14px;
      color: #000000;
    }}

    .academic-table td.col-en {{
      font-family: 'Times New Roman', 'Fira Code', serif;
      font-size: 14.5px;
    }}

    .academic-table td.col-zh {{
      font-family: 'Noto Serif TC', 'PMingLiU', serif;
    }}

    .academic-table td.col-type {{
      font-family: 'Times New Roman', serif;
    }}

    .academic-table td.col-len {{
      font-family: 'Times New Roman', serif;
    }}

    .academic-table td.col-pk, .academic-table td.col-fk {{
      font-size: 16px;
      font-weight: bold;
    }}

    /* Table Actions / Live Data Preview */
    .table-footer-bar {{
      margin-top: 10px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-family: 'Noto Sans TC', sans-serif;
      font-size: 12px;
      color: #64748b;
    }}

    .btn-toggle-data {{
      background: transparent;
      border: 1px solid #94a3b8;
      border-radius: 4px;
      padding: 4px 10px;
      font-size: 12px;
      cursor: pointer;
      color: #334155;
    }}
    .btn-toggle-data:hover {{
      background: #e2e8f0;
    }}

    .live-data-container {{
      display: none;
      margin-top: 12px;
      border: 1px solid #cbd5e1;
      border-radius: 6px;
      overflow-x: auto;
      background: #f8fafc;
      padding: 12px;
      font-family: 'Noto Sans TC', sans-serif;
    }}

    .live-data-container.show {{
      display: block;
    }}

    .live-table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
      text-align: left;
    }}
    .live-table th {{
      background: #e2e8f0;
      padding: 6px 10px;
      border: 1px solid #cbd5e1;
      font-weight: 600;
    }}
    .live-table td {{
      padding: 6px 10px;
      border: 1px solid #cbd5e1;
      max-width: 250px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }}

    /* Print Styles */
    @media print {{
      body {{
        background: #ffffff;
        padding: 0;
      }}
      .top-controls, .table-footer-bar, .live-data-container {{
        display: none !important;
      }}
      .document-container {{
        box-shadow: none;
        padding: 0;
        max-width: 100%;
      }}
      .table-section {{
        page-break-inside: avoid;
        margin-bottom: 30px;
      }}
    }}
  </style>
</head>
<body>

  <!-- Top Controls -->
  <div class="top-controls">
    <div class="controls-title">
      <span>📑</span>
      <span>AI App 資料表設計規格書 (全 21 張資料表)</span>
    </div>

    <div class="controls-actions">
      <select class="select-table-jump" onchange="jumpToTable(this.value)">
        <option value="">-- 快速跳轉至資料表 --</option>
'''

for s in TABLE_SCHEMAS:
    html_code += f'        <option value="{s["code"]}">{s["code"]} {s["name"]} {s["chinese"]}</option>\n'

html_code += '''      </select>
      <button class="btn btn-primary" onclick="window.print()">🖨️ 列印 / 存為 PDF</button>
      <button class="btn" onclick="toggleAllData()">👁️ 切換展開所有實際資料</button>
    </div>
  </div>

  <!-- Main Document Container -->
  <div class="document-container">
    <div class="doc-header">
      <h1>AI 智慧學習系統資料庫架構規格書</h1>
      <p>系統版本：v1.7.8 | 資料庫引擎：SQLite 3 (Dart/Flutter 跨平台規格)</p>
    </div>

    <div id="tablesList">
'''

for s in TABLE_SCHEMAS:
    t_code = s['code']
    t_name = s['name']
    t_zh = s['chinese']
    
    html_code += f'''
      <!-- {t_code} {t_name} -->
      <div class="table-section" id="{t_code}">
        <table class="academic-table">
          <thead>
            <tr class="table-title-row">
              <th colspan="6">{t_code} {t_name} {t_zh}</th>
            </tr>
            <tr class="col-header-row">
              <th style="width: 24%;">英文名稱</th>
              <th style="width: 26%;">中文名稱</th>
              <th style="width: 20%;">資料型態</th>
              <th style="width: 14%;">資料長度</th>
              <th style="width: 8%;">主鍵</th>
              <th style="width: 8%;">外鍵</th>
            </tr>
          </thead>
          <tbody>
'''
    for f in s['fields']:
        pk_dot = '●' if f['pk'] else ''
        fk_dot = '●' if f['fk'] else ''
        
        html_code += f'''            <tr>
              <td class="col-en">{f['en']}</td>
              <td class="col-zh">{f['zh']}</td>
              <td class="col-type">{f['type']}</td>
              <td class="col-len">{f['len']}</td>
              <td class="col-pk">{pk_dot}</td>
              <td class="col-fk">{fk_dot}</td>
            </tr>
'''
    html_code += f'''          </tbody>
        </table>

        <div class="table-footer-bar">
          <span>實體記錄筆數：<strong id="count-{t_name}">0</strong> 筆</span>
          <button class="btn-toggle-data" onclick="toggleLiveData('{t_name}')">檢視當前資料庫內容</button>
        </div>

        <div class="live-data-container" id="live-data-{t_name}">
          <table class="live-table">
            <thead id="live-thead-{t_name}"></thead>
            <tbody id="live-tbody-{t_name}"></tbody>
          </table>
        </div>
      </div>
'''

html_code += f'''
    </div>
  </div>

  <script>
    const DB_DATA = {db_json_str};

    function init() {{
      // Populate live data previews and row counts
      Object.keys(DB_DATA).forEach(tableName => {{
        const tData = DB_DATA[tableName];
        const countEl = document.getElementById(`count-${{tableName}}`);
        if (countEl) {{
          countEl.innerText = tData.rowCount;
        }}

        const thead = document.getElementById(`live-thead-${{tableName}}`);
        const tbody = document.getElementById(`live-tbody-${{tableName}}`);
        if (thead && tbody) {{
          // Headers
          const trHead = document.createElement('tr');
          tData.columns.forEach(col => {{
            const th = document.createElement('th');
            th.innerText = col.name;
            trHead.appendChild(th);
          }});
          thead.appendChild(trHead);

          // Rows (up to 10 preview)
          if (tData.rows.length === 0) {{
            const tr = document.createElement('tr');
            tr.innerHTML = `<td colspan="${{tData.columns.length}}" style="text-align:center; color:#94a3b8;">當前資料表尚無資料記錄</td>`;
            tbody.appendChild(tr);
          }} else {{
            tData.rows.slice(0, 10).forEach(r => {{
              const tr = document.createElement('tr');
              tData.columns.forEach(col => {{
                const td = document.createElement('td');
                const val = r[col.name];
                td.innerText = val === null ? 'NULL' : String(val);
                tr.appendChild(td);
              }});
              tbody.appendChild(tr);
            }});
          }}
        }}
      }});
    }}

    function jumpToTable(tableId) {{
      if (!tableId) return;
      const el = document.getElementById(tableId);
      if (el) {{
        el.scrollIntoView({{ behavior: 'smooth', block: 'start' }});
      }}
    }}

    function toggleLiveData(tableName) {{
      const el = document.getElementById(`live-data-${{tableName}}`);
      if (el) {{
        el.classList.toggle('show');
      }}
    }}

    let allExpanded = false;
    function toggleAllData() {{
      allExpanded = !allExpanded;
      document.querySelectorAll('.live-data-container').forEach(el => {{
        if (allExpanded) {{
          el.classList.add('show');
        }} else {{
          el.classList.remove('show');
        }}
      }});
    }}

    window.onload = init;
  </script>
</body>
</html>
'''

with open('database_dictionary.html', 'w', encoding='utf-8') as f:
    f.write(html_code)

print("Generated database_dictionary.html successfully!")
