"""
初始化 MySQL 資料表的腳本
執行此腳本會在雲端 MySQL 中建立 App 所需的所有資料表
（安全做法：只建立不存在的表，不會覆蓋現有資料）
"""

import asyncio
import os
import aiomysql
from dotenv import load_dotenv

load_dotenv()

# ─── 建表 SQL（對齊現有 SQLite schema）───

TABLES = [
    # 1. 用戶表
    """
    CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(36) PRIMARY KEY,
        username VARCHAR(100) NOT NULL UNIQUE,
        email VARCHAR(255) NOT NULL UNIQUE,
        hashed_password TEXT NOT NULL,
        display_name VARCHAR(100) DEFAULT '',
        bio TEXT,
        tags JSON,
        avatar_url TEXT,
        avatar_color INT DEFAULT 0,
        avatar_selected TINYINT DEFAULT 0,
        nickname_updated_at DATETIME NULL,
        is_email_verified TINYINT DEFAULT 0,
        font_size_factor DOUBLE DEFAULT 1.2,
        theme_color_idx INT DEFAULT 0,
        is_dark_mode TINYINT DEFAULT 0,
        gemini_api_key TEXT,
        is_google TINYINT DEFAULT 0,
        calendar_view_mode VARCHAR(20) DEFAULT 'dot',
        social_feed_layout VARCHAR(20) DEFAULT 'card',
        show_floating_nav_bar TINYINT DEFAULT 0,
        has_seen_tour TINYINT DEFAULT 0,
        nav_bar_items TEXT DEFAULT 'calendar,quiz,social,notes,social_feed',
        push_notifications_enabled TINYINT DEFAULT 1,
        `language` VARCHAR(10) DEFAULT 'zh_TW',
        membership_tier VARCHAR(20) DEFAULT 'free',
        membership_expires_at DATETIME NULL,
        points_balance INT DEFAULT 100,
        last_daily_reward_at DATETIME NULL,
        deleted_at DATETIME NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 2. 行事曆事件
    """
    CREATE TABLE IF NOT EXISTS calendar_events (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        title VARCHAR(200) NOT NULL,
        description TEXT DEFAULT '',
        is_all_day TINYINT DEFAULT 0,
        start_time DATETIME NOT NULL,
        end_time DATETIME NOT NULL,
        location VARCHAR(200) DEFAULT '',
        color VARCHAR(50) DEFAULT 'bg-blue-400',
        recurrence_type VARCHAR(20) DEFAULT 'none',
        recurrence_days TEXT DEFAULT '',
        recurrence_end TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_events_user_id (user_id),
        INDEX idx_events_start_time (start_time),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 3. 標籤
    """
    CREATE TABLE IF NOT EXISTS tags (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL UNIQUE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 4. 題目
    """
    CREATE TABLE IF NOT EXISTS questions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        text TEXT NOT NULL,
        options JSON NOT NULL,
        answer VARCHAR(50) NOT NULL,
        explanation TEXT DEFAULT '',
        subject VARCHAR(100) DEFAULT '',
        type VARCHAR(20) DEFAULT '單選題',
        difficulty VARCHAR(10) DEFAULT '中',
        is_public TINYINT DEFAULT 0,
        bookmarked TINYINT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_questions_user_id (user_id),
        INDEX idx_questions_subject (subject),
        INDEX idx_questions_difficulty (difficulty),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 5. 題目-標籤對應
    """
    CREATE TABLE IF NOT EXISTS question_tag_map (
        question_id INT NOT NULL,
        tag_id INT NOT NULL,
        PRIMARY KEY (question_id, tag_id),
        FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 6. 筆記
    """
    CREATE TABLE IF NOT EXISTS notes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        title VARCHAR(200) NOT NULL,
        content TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_notes_user_id (user_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 7. 日記
    """
    CREATE TABLE IF NOT EXISTS diaries (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        date VARCHAR(20) NOT NULL,
        content TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_diaries_user_id (user_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 8. 待辦事項
    """
    CREATE TABLE IF NOT EXISTS todos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        text TEXT NOT NULL,
        done TINYINT DEFAULT 0,
        done_at DATETIME NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_todos_user_id (user_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 9. 社群貼文
    """
    CREATE TABLE IF NOT EXISTS posts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        group_id INT NULL,
        content TEXT NOT NULL,
        type VARCHAR(20) DEFAULT 'text',
        attached_data JSON,
        likes INT DEFAULT 0,
        is_edited TINYINT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_posts_user_id (user_id),
        INDEX idx_posts_type (type),
        INDEX idx_posts_group_id (group_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 10. 貼文按讚
    """
    CREATE TABLE IF NOT EXISTS post_likes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        post_id INT NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        UNIQUE KEY uk_post_user (post_id, user_id),
        FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 11. 留言
    """
    CREATE TABLE IF NOT EXISTS comments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        post_id INT NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        text TEXT NOT NULL,
        parent_id INT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_comments_post_id (post_id),
        FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 12. 測驗結果
    """
    CREATE TABLE IF NOT EXISTS quiz_results (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        total INT NOT NULL,
        correct INT NOT NULL,
        wrong_question_ids JSON DEFAULT NULL,
        duration_seconds INT DEFAULT 0,
        subject VARCHAR(100) DEFAULT '',
        paper_id INT DEFAULT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 13. 貼文收藏
    """
    CREATE TABLE IF NOT EXISTS post_bookmarks (
        id INT AUTO_INCREMENT PRIMARY KEY,
        post_id INT NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        UNIQUE KEY uk_bookmark_post_user (post_id, user_id),
        FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 14. 社群群組
    """
    CREATE TABLE IF NOT EXISTS community_groups (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(200) NOT NULL,
        description TEXT DEFAULT '',
        icon_emoji VARCHAR(10) DEFAULT '📚',
        type VARCHAR(20) NOT NULL DEFAULT 'public',
        owner_id VARCHAR(36) NOT NULL,
        tags JSON,
        member_count INT DEFAULT 1,
        invite_token VARCHAR(100),
        token_expires_at DATETIME NULL,
        invite_link_active TINYINT DEFAULT 1,
        join_requires_approval TINYINT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 15. 群組成員
    """
    CREATE TABLE IF NOT EXISTS group_members (
        id INT AUTO_INCREMENT PRIMARY KEY,
        group_id INT NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        role VARCHAR(20) DEFAULT 'member',
        status VARCHAR(20) DEFAULT 'active',
        joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_read_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        is_muted TINYINT DEFAULT 0,
        UNIQUE KEY uk_group_user (group_id, user_id),
        INDEX idx_group_members_group (group_id),
        INDEX idx_group_members_user (user_id),
        FOREIGN KEY (group_id) REFERENCES community_groups(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 16. 群組公告
    """
    CREATE TABLE IF NOT EXISTS group_announcements (
        id INT AUTO_INCREMENT PRIMARY KEY,
        group_id INT NOT NULL,
        author_id VARCHAR(36) NOT NULL,
        content TEXT NOT NULL,
        is_pinned TINYINT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (group_id) REFERENCES community_groups(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 17. 自訂試卷
    """
    CREATE TABLE IF NOT EXISTS user_papers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        name VARCHAR(200) NOT NULL,
        question_ids JSON DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 18. 錯題記錄
    """
    CREATE TABLE IF NOT EXISTS wrong_questions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        question_id INT NOT NULL,
        note TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 19. 補救教材
    """
    CREATE TABLE IF NOT EXISTS remedial_materials (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        subject VARCHAR(100) NOT NULL,
        content TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uk_user_subject (user_id, subject)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 20. 題目討論
    """
    CREATE TABLE IF NOT EXISTS question_discussions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        question_id INT NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        user_name VARCHAR(100) NOT NULL,
        avatar_url VARCHAR(500),
        content TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        likes_count INT DEFAULT 0,
        is_ai_response TINYINT DEFAULT 0,
        parent_id INT DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 21. 題目討論按讚
    """
    CREATE TABLE IF NOT EXISTS question_discussion_likes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        discussion_id INT NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uk_discussion_user (discussion_id, user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 22. 點數交易紀錄
    """
    CREATE TABLE IF NOT EXISTS point_transactions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        amount INT NOT NULL,
        type VARCHAR(50) NOT NULL,
        description TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,

    # 23. 廣告
    """
    CREATE TABLE IF NOT EXISTS advertisements (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        sponsor VARCHAR(200) NOT NULL,
        link_url TEXT,
        bg_gradient VARCHAR(50),
        is_active TINYINT DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
]


async def init_tables():
    """建立所有資料表（IF NOT EXISTS，安全冪等）"""
    conn = await aiomysql.connect(
        host=os.getenv("DB_HOST", "140.131.114.242"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        db=os.getenv("DB_NAME", "ai_app"),
        charset="utf8mb4",
    )
    try:
        async with conn.cursor() as cur:
            for i, sql in enumerate(TABLES, 1):
                table_name = sql.strip().split("IF NOT EXISTS")[1].strip().split()[0].strip("`")
                try:
                    await cur.execute(sql)
                    print(f"  ✅ [{i:02d}/{len(TABLES)}] {table_name}")
                except Exception as e:
                    print(f"  ❌ [{i:02d}/{len(TABLES)}] {table_name} — {e}")
            await conn.commit()
        print(f"\n🎉 完成！共處理 {len(TABLES)} 張資料表。")
    finally:
        conn.close()


if __name__ == "__main__":
    print("🚀 開始初始化 MySQL 資料表...\n")
    asyncio.run(init_tables())
