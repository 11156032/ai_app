const admin = require('firebase-admin');

// 1. 替換為您的 Firebase 服務帳戶私鑰檔案路徑
// 您可以從 Firebase Console -> 專案設定 -> 服務帳戶 -> 產生新的私密金鑰 來下載
const serviceAccount = require('./firebase-adminsdk.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// 2. 定義要發送的通知內容
const message = {
  notification: {
    title: '📢 系統公告',
    body: '親愛的用戶您好，AI 助手已全面升級，快來體驗新功能！'
  },
  // 發送給訂閱了 'all_users' 主題的所有使用者（對應我們在 App 內的訂閱名稱）
  topic: 'all_users' 
};

// 3. 發送推播
admin.messaging().send(message)
  .then((response) => {
    console.log('推播發送成功:', response);
  })
  .catch((error) => {
    console.log('推播發送失敗:', error);
  });
