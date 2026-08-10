import firebase_admin
from firebase_admin import credentials, messaging

# 1. 替換為您的 Firebase 服務帳戶私鑰檔案路徑
# 您可以從 Firebase Console -> 專案設定 -> 服務帳戶 -> 產生新的私密金鑰 來下載
cred = credentials.Certificate("firebase-adminsdk.json")
firebase_admin.initialize_app(cred)

# 2. 定義要發送的通知內容
message = messaging.Message(
    notification=messaging.Notification(
        title='📢 系統公告',
        body='親愛的用戶您好，AI 助手已全面升級，快來體驗新功能！'
    ),
    # 發送給訂閱了 'all_users' 主題的所有使用者
    topic='all_users'
)

# 3. 發送推播
try:
    response = messaging.send(message)
    print('推播發送成功:', response)
except Exception as e:
    print('推播發送失敗:', e)
