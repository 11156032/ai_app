import 'package:flutter/material.dart';

/// 應用程式多語系支援服務（繁體中文、日本語、한국어）
class AppLocaleService {
  AppLocaleService._();
  static final AppLocaleService instance = AppLocaleService._();

  static const String zhTW = 'zh_TW';
  static const String ja = 'ja';
  static const String ko = 'ko';

  static final ValueNotifier<String> currentLanguageNotifier =
      ValueNotifier<String>(zhTW);

  static String get currentLanguage => currentLanguageNotifier.value;

  static void setLanguage(String lang) {
    if (lang == zhTW || lang == ja || lang == ko) {
      currentLanguageNotifier.value = lang;
    }
  }

  static String getLanguageDisplayName(String code) {
    switch (code) {
      case ja:
        return '日本語';
      case ko:
        return '한국어';
      case zhTW:
      default:
        return '繁體中文';
    }
  }

  static String getLanguageFlag(String code) {
    switch (code) {
      case ja:
        return '🇯🇵';
      case ko:
        return '🇰🇷';
      case zhTW:
      default:
        return '🇹🇼';
    }
  }

  /// 產生給 AI 大模型的語言指示 Prompt
  static String getAiLanguageInstruction([String? langCode]) {
    final code = langCode ?? currentLanguage;
    switch (code) {
      case ja:
        return '【言語指定】全ての出力・解説・アドバイスは自然で丁寧な日本語（Japanese）で作成してください。';
      case ko:
        return '【언어 지정】모든 답변, 해설 및 학습 조언은 자연스럽고 친절한 한국어(Korean)로 작성해 주세요.';
      case zhTW:
      default:
        return '【語言指定】請一律以繁體中文（Traditional Chinese）回答，禁止使用簡體字。';
    }
  }

  /// 常用介面文字翻譯對照表
  static final Map<String, Map<String, String>> _translations = {
    // 頂部 AppBar 與 導覽列
    'nav_home': {zhTW: '首頁', ja: 'ホーム', ko: '홈'},
    'nav_calendar': {zhTW: '日曆行程', ja: 'カレンダー', ko: '캘린더'},
    'nav_quiz': {zhTW: '題庫', ja: '問題集', ko: '문제은행'},
    'nav_quiz_full': {zhTW: '題庫測驗', ja: '問題演習', ko: '문제 테스트'},
    'nav_ai_assistant': {zhTW: 'AI助理', ja: 'AI助手', ko: 'AI비서'},
    'nav_community': {zhTW: '社群', ja: 'コミュニティ', ko: '커뮤니티'},
    'nav_social_feed': {zhTW: '社群動態', ja: 'タイムライン', ko: '피드'},
    'nav_profile': {zhTW: '個人檔案', ja: 'マイページ', ko: '마이페이지'},
    'nav_leaderboard': {zhTW: '排行榜', ja: 'ランキング', ko: '랭킹'},
    'nav_notes': {zhTW: '筆記本', ja: 'ノート', ko: '노트'},

    // 個人檔案 分頁標籤
    'profile_tab_overview': {zhTW: '概覽', ja: '概要', ko: '개요'},
    'profile_tab_settings': {zhTW: '設定與安全', ja: '設定とセキュリティ', ko: '설정 및 보안'},
    'profile_tab_support': {zhTW: '系統協助', ja: 'サポート', ko: '시스템 지원'},

    // 個人檔案 模組與標題
    'profile_basic_info': {zhTW: '基本資訊', ja: '基本情報', ko: '기본 정보'},
    'profile_nickname': {zhTW: '暱稱', ja: 'ニックネーム', ko: '닉네임'},
    'profile_bio': {zhTW: '個人簡介', ja: '自己紹介', ko: '프로필 소개'},
    'profile_bio_hint': {zhTW: '點擊設定簡介...', ja: '自己紹介を設定...', ko: '소개글 입력...'},
    'profile_security_title': {zhTW: '帳號與安全', ja: 'アカウントとセキュリティ', ko: '계정 및 보안'},
    'profile_email': {zhTW: '綁定 Email', ja: '登録メール', ko: '로그인 이메일'},
    'profile_not_set': {zhTW: '未設定', ja: '未設定', ko: '미설정'},
    'profile_email_unchangeable': {zhTW: '註冊信箱不可更改', ja: '登録メールアドレスは変更できません', ko: '가입 이메일은 변경할 수 없습니다'},
    'profile_password': {zhTW: '修改密碼', ja: 'パスワード変更', ko: '비밀번호 변경'},
    'profile_google_login': {zhTW: '已使用 Google 帳號登入', ja: 'Google アカウントでログイン中', ko: 'Google 계정으로 로그인됨'},
    'profile_change_password': {zhTW: '定期修改更安全', ja: '定期的な変更をおすすめします', ko: '주기적으로 변경하면 안전합니다'},
    'profile_no_password_needed': {zhTW: '您已透過 Google 登入，無須修改密碼', ja: 'Google ログインのためパスワード変更は不要です', ko: 'Google 로그인 계정은 비밀번호 변경이 필요하지 않습니다'},
    'profile_delete_account': {zhTW: '刪除帳號', ja: 'アカウント削除', ko: '계정 삭제'},
    'profile_delete_hint': {zhTW: '30 天內可復原', ja: '30日以内は復元可能', ko: '30일 이내 복구 가능'},
    'profile_interaction_title': {zhTW: '互動紀錄', ja: 'アクティビティ履歴', ko: '활동 내역'},
    'profile_my_posts': {zhTW: '我的貼文', ja: 'マイ投稿', ko: '내 게시글'},
    'profile_posts_count': {zhTW: '已發佈 {0} 篇貼文與筆記', ja: '{0} 件の投稿・ノートを公開中', ko: '{0}개의 게시글 및 노트 발행됨'},
    'profile_quiz_history': {zhTW: '測驗歷史', ja: 'テスト履歴', ko: '테스트 기록'},
    'profile_leaderboard': {zhTW: '排行榜', ja: 'ランキング', ko: '랭킹'},
    'profile_leaderboard_desc': {zhTW: '查看所有使用者的測驗成績排名', ja: '全ユーザーの成績ランキングを確認', ko: '전체 사용자의 성적 랭킹 확인'},
    'profile_support_title': {zhTW: '系統與協助', ja: 'サポートとお問い合わせ', ko: '고객지원 및 도움말'},
    'feedback_and_help': {zhTW: '客服與意見回饋', ja: 'お問い合わせとフィードバック', ko: '문의 및 피드백'},
    'feedback_and_help_sub': {zhTW: '回報問題或提供功能建議', ja: '不具合報告・ご意見・サポート', ko: '문제 신고, 피드백 및 고객센터'},
    'about_us': {zhTW: '關於我們', ja: 'アプリについて', ko: '앱 정보'},
    'about_us_sub': {zhTW: '了解 App 技術運用、核心功能與品牌故事', ja: 'チーム紹介・プライバシーポリシー', ko: '팀 소개 및 이용약관'},
    'app_version': {zhTW: '版本資訊', ja: 'バージョン情報', ko: '버전 정보'},

    // 今日摘要卡片
    'dashboard_today_summary': {zhTW: '今日學習摘要', ja: '今日の学習サマリー', ko: '오늘의 학습 요약'},
    'dashboard_tap_flip': {zhTW: '點擊翻轉', ja: 'タップして反転', ko: '탭하여 뒤집기'},
    'dashboard_study_hours': {zhTW: '學習時數', ja: '学習時間', ko: '학습 시간'},
    'dashboard_completed_questions': {zhTW: '完成題目', ja: '完了した問題', ko: '푼 문제 수'},
    'dashboard_total_answered': {zhTW: '累積答題', ja: '総回答数', ko: '누적 풀이'},
    'dashboard_no_quiz_data': {zhTW: '暫無測驗資料', ja: 'テストデータがありません', ko: '테스트 데이터가 없습니다'},
    'unit_questions': {zhTW: '題', ja: '問', ko: '문제'},

    // 個人化設定
    'settings_title': {zhTW: '個人化設定', ja: 'カスタム設定', ko: '개인 맞춤 설정'},
    'settings_language': {zhTW: '介面語言', ja: '言語設定', ko: '언어 설정'},
    'settings_language_sub': {zhTW: '切換 App 介面與 AI 支援語言', ja: '言語とAI言語の切り替え', ko: '앱 및 AI 언어 변경'},
    'settings_font_size': {zhTW: '字體大小', ja: '文字サイズ', ko: '글자 크기'},
    'settings_theme_color': {zhTW: '主題色彩', ja: 'テーマカラー', ko: '테마 색상'},
    'settings_calendar_style': {zhTW: '行事曆顯示樣式', ja: 'カレンダー表示形式', ko: '캘린더 표시 스타일'},
    'settings_social_style': {zhTW: '社群貼文版面樣式', ja: '投稿レイアウト形式', ko: '커뮤니티 레이아웃'},
    'settings_floating_nav': {zhTW: '顯示底部導覽列', ja: 'フローティングバー表示', ko: '하단 바 표시'},
    'settings_dark_mode': {zhTW: '深色模式', ja: 'ダークモード', ko: '다크 모드'},
    'settings_notifications': {zhTW: '接收系統通知', ja: 'システム通知受信', ko: '시스템 알림 수신'},

    // 設定選項名稱與值
    'font_size_std': {zhTW: '標準 (預設)', ja: '標準 (デフォルト)', ko: '표준 (기본)'},
    'font_size_large': {zhTW: '放大 (大)', ja: '拡大 (大)', ko: '확대 (크게)'},
    'font_size_xlarge': {zhTW: '特大 (清晰)', ja: '特大 (見やすい)', ko: '특대 (선명하게)'},
    'theme_color_0': {zhTW: '經典暖棕 (預設)', ja: 'クラシックブラウン (デフォルト)', ko: '클래식 브라운 (기본)'},
    'theme_color_1': {zhTW: '孔雀藍', ja: 'ピーコックブルー', ko: '피콕 블루'},
    'theme_color_2': {zhTW: '森林綠', ja: 'フォレストグリーン', ko: '포레스트 그린'},
    'theme_color_3': {zhTW: '暮櫻紫', ja: 'サクラパープル', ko: '체리 퍼플'},
    'theme_color_4': {zhTW: '琥珀橙', ja: 'アンバーオレンジ', ko: '앰버 오렌지'},
    'calendar_mode_bar': {zhTW: '橫條跨天模式', ja: 'バー表示モード', ko: '가로 바 모드'},
    'calendar_mode_bar_desc': {zhTW: '以彩色橫條橫跨日期顯示，方便看清名稱與區間', ja: '日付をまたぐバーで期間と予定名を分かりやすく表示', ko: '기간 및 일정명을 직관적으로 확인할 수 있는 가로 바'},
    'calendar_mode_dot': {zhTW: '經典短條模式', ja: 'クラシック短冊モード', ko: '클래식 모드'},
    'calendar_mode_dot_desc': {zhTW: '日期下方以彩色短條標示行程，簡潔清晰', ja: '日付の下にカラーバーで表示し、シンプルで視認性抜群', ko: '날짜 아래 작은 바로 표시되어 깔끔하고 한눈에 파악'},
    'feed_layout_list': {zhTW: '新聞式列表', ja: 'ニュースリスト', ko: '뉴스 피드'},
    'feed_layout_list_desc': {zhTW: 'Row 左右佈局，左邊文章標題與摘要，右邊 80x80 小縮圖', ja: 'ニュース形式でタイトルとサムネイルを並べて一覧表示', ko: '제목과 썸네일이 정리된 리스트형 뉴스 피드'},
    'feed_layout_card': {zhTW: '規格化卡片', ja: 'カードスタイル', ko: '카드형 피드'},
    'feed_layout_card_desc': {zhTW: '卡片式呈現，文字最多3行，附帶精美縮圖預覽', ja: 'カードスタイルで画像プレビュー付きの見やすい表示', ko: '이미지 미리보기가 포함된 카드형 레이아웃'},

    // 圖表與診斷
    'chart_legend_proficient': {zhTW: '熟練度高', ja: '高習熟度', ko: '숙련도 높음'},
    'chart_legend_hesitant': {zhTW: '猶豫期', ja: '考慮時間長', ko: '고민 시간 김'},
    'chart_legend_careless': {zhTW: '粗心', ja: 'ケアレスミス', ko: '부주의'},
    'chart_legend_blindspot': {zhTW: '嚴重盲點', ja: '要復習', ko: '취약 단원'},
    'chart_y_label': {zhTW: '正確率', ja: '正答率', ko: '정답률'},
    'chart_x_label': {zhTW: '平均作答時間 (秒)', ja: '平均解答時間 (秒)', ko: '평균 풀이 시간 (초)'},
    'chart_tooltip': {zhTW: '正確率約: {0}%\n平均耗時約: {1}s\n(點擊開啟診斷詳情)', ja: '正答率約: {0}%\n平均時間約: {1}s\n(タップして詳細診断を開く)', ko: '정답률 약: {0}%\n평균 시간 약: {1}s\n(탭하여 진단 상세 열기)'},
    'sheet_overlapped_title': {zhTW: '此區域包含 {0} 個科目內容', ja: 'このエリアに {0} 科目あります', ko: '이 영역에 {0}개의 과목이 있습니다'},
    'sheet_overlapped_desc': {zhTW: '請點擊欲查看的科目，以開啟詳細診斷與 AI 補強：', ja: '確認したい科目を選択してください：', ko: '확인할 과목을 선택해 주세요:'},
    'general_practice': {zhTW: '一般練習', ja: '一般演習', ko: '일반 연습'},
    'acc_rate': {zhTW: '正確率', ja: '正答率', ko: '정답률'},
    'avg_time': {zhTW: '平均耗時', ja: '平均時間', ko: '평균 시간'},
    'avg_time_sec': {zhTW: '平均時間 (秒)', ja: '平均時間 (秒)', ko: '평균 시간 (초)'},
    'quiz_desc_proficient': {zhTW: '答題又快又準！代表該科目解題邏輯已經融會貫通。', ja: '正確かつスピーディー！十分に理解できています。', ko: '빠르고 정확합니다! 개념을 완벽히 이해했습니다.'},
    'quiz_desc_hesitant': {zhTW: '正確率達標，但花費較多時間思考，建議多做類似題目提升速度。', ja: '正答率は良いですが、解答に少し時間がかかっています。', ko: '정답률은 양호하나 풀이 시간이 다소 깁니다.'} ,
    'quiz_desc_blindspot': {zhTW: '花費較長時間但答錯率高，代表觀念可能尚未理解，建議重新複習重點。', ja: '誤答率が高いため、基本概念の復習が推奨されます。', ko: '오답률이 높아 기초 개념 복습이 필요합니다.'},
    'quiz_desc_careless': {zhTW: '答題速度快但正確率偏低，可能審題過快或細節粗心造成。', ja: '解答速度は速いですが、ケアレスミスに注意してください。', ko: '풀이 속도는 빠르나 실수에 주의하세요.'},
    'quiz_time': {zhTW: '測驗時間', ja: 'テスト日時', ko: '테스트 일시'},
    'quiz_score': {zhTW: '答對/總數', ja: '正答数/総数', ko: '정답/총 문제'},
    'quiz_review_schedule': {zhTW: '排入複習行程 ({0})', ja: '復習スケジュールに追加 ({0})', ko: '복습 일정 추가 ({0})'},
    'schedule_time_pick': {zhTW: '選擇複習行程時間', ja: '復習予定時間を選択', ko: '복습 시간 선택'},
    'quiz_review_title': {zhTW: '複習：{0}', ja: '復習：{0}', ko: '복습: {0}'},
    'quiz_scheduled_msg': {zhTW: '已將「複習：{0}」排入今日 {1} 行程！', ja: '「復習：{0}」を本日 {1} の予定に追加しました！', ko: '오늘 {1}에 「복습: {0}」 일정이 등록되었습니다!'},
    'ai_suggestion_button': {zhTW: '一鍵 AI 生成學習建議', ja: 'AI学習アドバイスを生成', ko: 'AI 맞춤 학습 제안 생성'},

    // 模擬貼文與星期
    'time_2h_ago': {zhTW: '2 小時前', ja: '2時間前', ko: '2시간 전'},
    'test_title': {zhTW: '打包測試', ja: 'レイアウト確認', ko: '레이아웃 테스트'},
    'test_desc': {zhTW: '這是一段用來展示卡片排版的模擬文字內容。', ja: 'カード表示のレイアウトを確認するためのサンプルテキストです。', ko: '카드형 레이아웃을 확인하기 위한 샘플 텍스트입니다.'},
    'plan_title': {zhTW: '國小生複習計畫', ja: '学習復習プラン', ko: '학습 복습 계획'},
    'plan_desc': {zhTW: '今天幫小朋友整理的重點，大家可以參考看看！', ja: 'まとめた要点です。ぜひ参考にしてみてください！', ko: '오늘 정리한 핵심 요점입니다. 참고해 보세요!'},
    'mon': {zhTW: '一', ja: '月', ko: '월'},
    'tue': {zhTW: '二', ja: '火', ko: '화'},
    'wed': {zhTW: '三', ja: '水', ko: '수'},
    'thu': {zhTW: '四', ja: '木', ko: '목'},
    'fri': {zhTW: '五', ja: '金', ko: '금'},
    'sat': {zhTW: '六', ja: '土', ko: '토'},
    'sun': {zhTW: '日', ja: '日', ko: '일'},

    // 常見問題與客服
    'faq_and_support': {zhTW: '常見問題與線上客服', ja: 'FAQ・オンラインサポート', ko: '자주 묻는 질문 및 고객센터'},
    'faq_and_support_sub': {zhTW: '功能問答、教學與 24H 線上客服', ja: 'よくある質問と24Hオンラインサポート', ko: '자주 묻는 질문 및 24H 고객센터'},
    'faq_tab': {zhTW: '精選常見問題', ja: 'よくある質問', ko: '자주 묻는 질문'},
    'support_tab': {zhTW: '24H 智能線上客服', ja: '24H AIサポート', ko: '24H AI 고객센터'},
    'support_online_status': {zhTW: 'YeBang 智能客服專員在線中', ja: 'YeBang サポート担当者が対応中', ko: 'YeBang AI 상담원 연결 중'},
    'support_greeting': {
      zhTW: '您好！我是 **YeBang 線上客服專員** 😊\n\n請問今天在使用 APP 題庫測驗、AI 學習診斷、個人筆記或帳號設定上有什麼我可以為您說明的嗎？您可以直接在下方輸入問題，或點擊快捷標籤！',
      ja: 'こんにちは！**YeBang オンラインサポート担当**です 😊\n\n問題集、AI学習診断、ノート、設定など、アプリのご利用に関してご不明な点はございますか？下の入力欄またはタグからお気軽にご質問ください！',
      ko: '안녕하세요! **YeBang 온라인 상담원**입니다 😊\n\n문제은행, AI 학습 진단, 오답노트, 설정 등 앱 사용에 관해 궁금한 점이 있으신가요? 아래 입력창이나 바로가기 태그를 통해 편하게 질문해 주세요!',
    },
    'support_input_hint': {zhTW: '請輸入您的操作問題…', ja: '質問を入力してください…', ko: '문의사항을 입력하세요…'},
    'support_transfer_human': {zhTW: '轉接人工回饋', ja: '担当者へ問い合わせ', ko: '상담원 문의'},
    'support_clear_history': {zhTW: '清空對話紀錄', ja: '履歴をクリア', ko: '대화 기록 지우기'},

    // 一般通用操作
    'btn_confirm': {zhTW: '確認', ja: '確認', ko: '확인'},
    'btn_cancel': {zhTW: '取消', ja: 'キャンセル', ko: '취소'},
    'btn_close': {zhTW: '關閉', ja: '閉じる', ko: '닫기'},
    'btn_save': {zhTW: '儲存', ja: '保存', ko: '저장'},
    'btn_logout': {zhTW: '登出', ja: 'ログアウト', ko: '로그아웃'},
    'saved_success': {zhTW: '偏好設定已儲存', ja: '設定を保存しました', ko: '설정이 저장되었습니다'},
    'cancel': {zhTW: '取消', ja: 'キャンセル', ko: '취소'},
    'confirm': {zhTW: '確定', ja: '確定', ko: '확인'},

    // 抽屜側拉選單 (Drawer)
    'drawer_title': {zhTW: '系統選單', ja: 'メニュー', ko: '메뉴'},
    'drawer_interact': {zhTW: '互動與管理', ja: 'インタラクション', ko: '인터랙션'},

    // 日曆頁籤與 popup
    'cal_tab_schedule': {zhTW: '今日行程', ja: '本日の予定', ko: '오늘 일정'},
    'cal_tab_todo': {zhTW: '待辦清單', ja: 'ToDoリスト', ko: '할 일 목록'},
    'cal_tab_diary': {zhTW: '日記', ja: '日記', ko: '일기'},
    'cal_add_schedule': {zhTW: '新增行程', ja: '予定を追加', ko: '일정 추가'},
    'cal_add_todo': {zhTW: '新增待辦', ja: 'ToDoを追加', ko: '할 일 추가'},
    'cal_write_diary': {zhTW: '寫今日日記', ja: '今日の日記を書く', ko: '오늘 일기 쓰기'},
    'cal_free_time': {zhTW: '空閒時間', ja: '空き時間', ko: '여유 시간'},

    // 學習歷程圖表區塊
    'chart_section_title_matrix': {zhTW: '學習歷程 (知識掌握度矩陣)', ja: '学習履歴 (習熟度マトリクス)', ko: '학습 이력 (숙련도 매트릭스)'},
    'chart_section_title_radar': {zhTW: '學習歷程 (多維能力分析)', ja: '学習履歴 (多次元能力分析)', ko: '학습 이력 (다차원 능력 분석)'},
    'chart_hint_tap_dot': {zhTW: '💡 點擊圓點查看測驗詳情與 AI 學習建議', ja: '💡 ドットをタップしてテスト詳細とAIアドバイスを確認', ko: '💡 점을 탭하여 테스트 상세 및 AI 학습 제안 확인'},
    'chart_hint_no_data': {zhTW: '本週尚無作答紀錄，完成練習後將自動繪製掌握度圖表', ja: '今週の回答記録がありません。練習後に自動で習熟度グラフを作成します', ko: '이번 주 풀이 기록이 없습니다. 연습 후 숙련도 차트가 자동 생성됩니다'},
    'chart_hint_radar': {zhTW: '💡 透過雷達圖快速掌握各科目能力分佈', ja: '💡 レーダーチャートで各科目の能力分布を確認', ko: '💡 레이더 차트로 각 과목별 능력 분포 확인'},
    'chart_hint_radar_no_data': {zhTW: '完成練習後將自動繪製各科能力分佈', ja: '練習後に各科目の能力分布が自動で描画されます', ko: '연습 후 각 과목별 능력 분포가 자동 생성됩니다'},
    'chart_blindspot_warn': {zhTW: '本週偵測到 {0} 筆嚴重盲點！建議及早複習。', ja: '今週 {0} 件の重大な盲点が検出されました！早めの復習をおすすめします。', ko: '이번 주 {0}개의 심각한 취약점이 발견되었습니다! 빠른 복습을 권장합니다.'},
    'chart_blindspot_btn': {zhTW: 'AI 學習建議', ja: 'AIアドバイス', ko: 'AI 학습 제안'},

    // 系統協助 - 未翻譯項目
    'tour_label': {zhTW: '互動式功能引導', ja: 'インタラクティブガイド', ko: '인터랙티브 가이드'},
    'tour_value': {zhTW: '操作引導：AI 功能、題庫功能逐步體驗', ja: 'AI機能・問題集機能のステップガイド', ko: 'AI 기능・문제은행 기능 단계별 안내'},
    'terms_label': {zhTW: '服務條款', ja: '利用規約', ko: '이용약관'},
    'terms_value': {zhTW: '查看使用者協議與隱私政策', ja: 'ユーザー規約とプライバシーポリシーを確認', ko: '이용약관 및 개인정보 처리방침 확인'},
    'privacy_label': {zhTW: '隱私權政策', ja: 'プライバシーポリシー', ko: '개인정보 처리방침'},
    'privacy_value': {zhTW: '了解我們如何蒐集與保護您的個人資料', ja: '個人情報の収集・保護方針について', ko: '개인 정보 수집 및 보호 방법 안내'},

    // 常見問題彈窗
    'faq_sheet_subtitle': {zhTW: '快速解答操作疑問・24H 專員即時對話', ja: '操作の疑問を素早く解決・24H専任サポート', ko: '빠른 문제 해결・24H 전담 상담원 실시간 대화'},
    'faq_tab_faq': {zhTW: '精選常見問題', ja: 'よくある質問', ko: '자주 묻는 질문'},
    'faq_tab_chat': {zhTW: '24H 智能線上客服', ja: '24H AIサポート', ko: '24H AI 고객센터'},
    'faq_search_hint': {zhTW: '搜尋問題關鍵字（如：同步、AI、信箱、筆記）…', ja: 'キーワードで検索（例：同期、AI、メール）…', ko: '키워드 검색（예: 동기화, AI, 이메일, 노트）…'},
    'faq_no_result': {zhTW: '查無符合「{0}」的常見問題', ja: '「{0}」に関する質問が見つかりません', ko: '「{0}」에 대한 질문을 찾을 수 없습니다'},
    'faq_go_chat': {zhTW: '前往線上客服提問', ja: 'サポートに質問する', ko: '고객센터에 문의하기'},
    'faq_footer_title': {zhTW: '仍有疑問或遇到操作問題？', ja: 'まだ疑問点や問題がありますか？', ko: '아직 궁금한 점이나 문제가 있으신가요?'},
    'faq_footer_sub': {zhTW: '24H 智慧線上客服隨時為您解答', ja: '24H AIサポートがいつでもお答えします', ko: '24H AI 고객센터가 언제든지 답변해 드립니다'},
    'faq_footer_btn': {zhTW: '立即發問', ja: '今すぐ質問', ko: '지금 문의'},
    'faq_cat_all': {zhTW: '全部', ja: 'すべて', ko: '전체'},
    'faq_cat_account': {zhTW: '帳號與同步', ja: 'アカウントと同期', ko: '계정 및 동기화'},
    'faq_cat_ai': {zhTW: 'AI 診斷與詳解', ja: 'AI診断と解説', ko: 'AI 진단 및 해설'},
    'faq_cat_quiz': {zhTW: '題庫與測驗', ja: '問題集とテスト', ko: '문제은행 및 테스트'},
    'faq_cat_notes': {zhTW: '個人筆記', ja: '個人ノート', ko: '개인 노트'},
    'faq_cat_settings': {zhTW: '設定與系統', ja: '設定とシステム', ko: '설정 및 시스템'},

    // FAQ 問答資料
    'faq_q1': {zhTW: '如何將學習紀錄與進度同步？', ja: '学習記録と進捗を同期するには？', ko: '학습 기록과 진도를 동기화하는 방법은?'},
    'faq_a1': {zhTW: '您的學習紀錄會與您的帳號即時連動。只要確保在有網路的環境下登入，系統會自動在背景將測驗進度、錯題與雲端資料庫同步。若使用訪客登入，資料僅會保留在當前裝置中。', ja: '学習記録はアカウントとリアルタイムで連携されます。ネットワーク環境でログインしていれば、テストの進捗・間違えた問題がバックグラウンドで自動的にクラウドと同期されます。ゲストログインの場合、データは現在の端末にのみ保存されます。', ko: '학습 기록은 계정과 실시간으로 연동됩니다. 네트워크 환경에서 로그인되어 있으면, 테스트 진도와 오답이 백그라운드에서 자동으로 클라우드와 동기화됩니다. 게스트 로그인의 경우 데이터는 현재 기기에만 저장됩니다.'},
    'faq_q2': {zhTW: 'AI 診斷報告與專屬學習建議的依據是什麼？', ja: 'AI診断レポートと専用学習アドバイスの根拠は？', ko: 'AI 진단 보고서 및 맞춤 학습 제안의 기준은 무엇인가요?'},
    'faq_a2': {zhTW: '系統會分析您在「錯題本」與「模擬試卷」中的實際答題狀況與章節掌握度，透過知識掌握度矩陣找出核心盲點，並結合 AI 專屬教師針對性生成弱項補強教材與觀念整理。', ja: '「間違えた問題集」と「模擬試験」での実際の回答状況と章の習熟度を分析し、習熟度マトリクスで核心的な盲点を特定。AIが弱点補強教材と概念整理を生成します。', ko: '「오답노트」와 「모의시험」의 실제 풀이 현황과 단원 숙련도를 분석하여, 숙련도 매트릭스로 핵심 취약점을 찾고 AI가 맞춤 보완 학습자료를 생성합니다.'},
    'faq_q3': {zhTW: '發現題目或解答有錯誤怎麼辦？', ja: '問題や解答に誤りを見つけた場合は？', ko: '문제나 정답에 오류를 발견했을 때는?'},
    'faq_a3': {zhTW: '若您發現題目或解答有誤，可以點擊題目頁面右上角的「標記」或「AI 詳解」確認，並可透過底部的「轉接人工客服回饋」將該題截圖與說明回報給我們，我們將由專人迅速修正。', ja: '問題や解答に誤りを見つけた場合は、問題ページ右上の「マーク」や「AI解説」で確認後、「担当者へ問い合わせ」からスクリーンショットと説明を送ってください。専任スタッフが迅速に修正します。', ko: '문제나 정답에 오류를 발견하면 문제 페이지 우상단의 「표시」나 「AI 해설」을 통해 확인하고, 하단의 「상담원 문의」로 스크린샷과 설명을 보내주세요. 전담 직원이 빠르게 수정합니다.'},
    'faq_q4': {zhTW: '測驗錯題如何一鍵同步到筆記本？', ja: '間違えた問題をワンタップでノートに同期するには？', ko: '오답을 원터치로 노트에 동기화하려면?'},
    'faq_a4': {zhTW: '在每次測驗完成後的「成績複習頁面」，勾選您想保存的題目並輸入筆記心得後，點擊「儲存錯題與筆記」，系統便會自動將其建立為個人專屬複習筆記。在筆記本中還可使用「AI 一鍵摘要整理」快速萃取精華！', ja: 'テスト後の「成績確認ページ」で保存したい問題にチェックを入れ、メモを入力後「間違い問題とメモを保存」をタップ。自動的に個人の復習ノートが作成されます。ノートでは「AI一括まとめ」も使えます！', ko: '테스트 후 「성적 복습 페이지」에서 저장할 문제를 체크하고 메모를 입력한 후 「오답 및 노트 저장」을 탭하세요. 자동으로 개인 복습 노트가 생성됩니다. 노트에서는 「AI 일괄 요약」도 사용 가능합니다!'},
    'faq_q5': {zhTW: '如何開啟或關閉推播通知與讀書提醒？', ja: 'プッシュ通知と学習リマインダーをオン/オフするには？', ko: '푸시 알림 및 학습 알림을 켜고 끄는 방법은?'},
    'faq_a5': {zhTW: '您可以至「個人檔案」>「設定與安全」中，開啟或關閉「接收系統通知」。此外，在「行事曆待辦」中建立排程時，亦可單獨為每項任務設定專屬提醒時間。', ja: '「マイページ」>「設定とセキュリティ」から「システム通知受信」をオン/オフできます。また「カレンダーToDoリスト」でタスクを作成する際、各タスクに個別のリマインダー時間を設定できます。', ko: '「마이페이지」 > 「설정 및 보안」에서 「시스템 알림 수신」을 켜거나 끌 수 있습니다. 또한 「캘린더 할 일 목록」에서 일정을 만들 때 각 항목에 개별 알림 시간을 설정할 수 있습니다.'},
    'faq_q6': {zhTW: '可以修改登入的電子信箱嗎？', ja: 'ログインメールアドレスを変更できますか？', ko: '로그인 이메일을 변경할 수 있나요?'},
    'faq_a6': {zhTW: '目前為了保障使用者的學習歷程與帳號安全，註冊或綁定之 Email 為主要識別，無法直接線上更改。若有特殊更換需求，可透過客服表單由管理員協助處理。密碼則可隨時於「設定與安全」中修改。', ja: '学習履歴とアカウントセキュリティ保護のため、登録・連携されたメールアドレスは主要識別子として直接オンライン変更できません。特別な変更が必要な場合はサポートフォームで管理者に依頼してください。パスワードは「設定とセキュリティ」でいつでも変更できます。', ko: '학습 이력과 계정 보안을 위해 가입 또는 연결된 이메일은 주요 식별자로 직접 온라인 변경이 불가합니다. 변경이 필요한 경우 고객센터 양식을 통해 관리자에게 요청하세요. 비밀번호는 「설정 및 보안」에서 언제든지 변경할 수 있습니다.'},
    'faq_q7': {zhTW: '如何切換深色主題與個性化主題顏色？', ja: 'ダークテーマとテーマカラーを切り替えるには？', ko: '다크 테마와 개인화 테마 색상을 변경하는 방법은?'},
    'faq_a7': {zhTW: '前往「個人檔案」>「介面與顯示偏好」，即可一鍵開啟/關閉「深色模式」，並可在「主題色彩」中自由挑選您喜愛的代表色（如智慧藍、活力橘、翡翠綠等）。', ja: '「マイページ」>「カスタム設定」で「ダークモード」を切り替え、「テーマカラー」から好みの代表色を選べます。', ko: '「마이페이지」 > 「개인 맞춤 설정」에서 「다크 모드」를 켜거나 끄고, 「테마 색상」에서 원하는 색상을 선택할 수 있습니다.'},

    // 客服聊天 UI
    'support_agent_online': {zhTW: 'YeBang 智能客服專員在線中', ja: 'YeBang AIサポート担当者が対応中', ko: 'YeBang AI 상담원 연결 중'},
    'support_transfer_btn': {zhTW: '轉接人工回饋', ja: '担当者へ問い合わせ', ko: '상담원 문의'},
    'support_clear_tooltip': {zhTW: '清空對話紀錄', ko: '대화 기록 지우기', ja: '履歴をクリア'},
    'support_input_placeholder': {zhTW: '請輸入您的操作問題…', ja: '質問を入力してください…', ko: '문의사항을 입력하세요…'},
    'support_thinking': {zhTW: '智慧客服正在整理說明…', ja: 'AIサポートが回答を準備中…', ko: 'AI 상담원이 답변을 정리 중…'},
    'support_reset_msg': {zhTW: '對話已重置 😊 請問還有什麼功能疑問需要為您說明嗎？', ja: '会話をリセットしました 😊 他にご不明な点はございますか？', ko: '대화가 초기화되었습니다 😊 다른 궁금한 점이 있으신가요?'},
    'support_error_msg': {zhTW: '【客服連線提醒】\n目前網路連線稍有延遲，請稍後再試，或點擊下方「轉接人工客服回饋」由專人為您處理！', ja: '【接続エラー】\n現在ネットワークが不安定です。しばらくしてから再試行するか、「担当者へ問い合わせ」をご利用ください。', ko: '【연결 안내】\n현재 네트워크 연결이 불안정합니다. 잠시 후 다시 시도하거나 「상담원 문의」를 이용해 주세요.'},
  };

  /// 獲取當前語言對應的字串，並支援參數置換
  static String tr(String key, [String? langCode, List<String>? args]) {
    final code = langCode ?? currentLanguage;
    final map = _translations[key];
    String text = map != null ? (map[code] ?? map[zhTW] ?? key) : key;
    if (args != null) {
      for (int i = 0; i < args.length; i++) {
        text = text.replaceAll('{$i}', args[i]).replaceAll('%s', args[i]);
      }
    }
    return text;
  }
}
