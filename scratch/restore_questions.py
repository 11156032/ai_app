import re

file_path = r"C:\Users\user\ai_app\lib\database\database_helper.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Let's locate the _seedDatabase method.
seed_start = content.find("Future<void> _seedDatabase(Database db) async {")
if seed_start != -1:
    idx = seed_start + len("Future<void> _seedDatabase(Database db) async {") - 1
    braces = 0
    body_chars = []
    while idx < len(content):
        char = content[idx]
        body_chars.append(char)
        if char == '{':
            braces += 1
        elif char == '}':
            braces -= 1
            if braces == 0:
                break
        idx += 1
    
    seed_body = "".join(body_chars)
    
    # Extract all questions, tags, and question_tag_map inserts from seed_body
    inserts = re.findall(r"await db\.insert\('(?:questions|tags|question_tag_map)', \{[\s\S]*?\}\);", seed_body)
    
    # We will create a new _seedQuestions method content
    seed_questions_body = "Future<void> _seedQuestions(Database db) async {\n"
    for ins in inserts:
        seed_questions_body += "    " + ins + "\n"
    seed_questions_body += "  }\n"
    
    # We will clean the _seedDatabase method body to only contain users and calling _seedQuestions
    new_seed_database = """Future<void> _seedDatabase(Database db) async {
    // 1. Users - 只保留系統與訪客
    await db.insert('users', {
      'id': 'u3',
      'username': '系統',
      'email': 'sys@gmail.com',
      'hashed_password': 'mock_password',
      'display_name': '系統',
    });
    await db.insert('users', {
      'id': 'u4',
      'username': '訪客',
      'email': 'guest@gmail.com',
      'hashed_password': 'mock_password',
      'display_name': '訪客',
    });

    // 2. Questions & Tags
    await _seedQuestions(db);
  }"""

    # Replace the old _seedDatabase with the new one and append _seedQuestions after it
    old_full_seed = "Future<void> _seedDatabase(Database db) async " + seed_body
    replacement = new_seed_database + "\n\n  " + seed_questions_body
    content = content.replace(old_full_seed, replacement)

# Now, let's fix the dynamic migration inside _initDB
# We search for the dynamic migration we inserted earlier:
migration_search = """      // 自動清理歷史寫死之測試帳號與相關資料，確保排行榜與社群乾淨
      await db.delete('users', where: "id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('posts', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('quiz_results', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('todos', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('calendar_events', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.update('questions', {'user_id': 'u3'}, where: "user_id IN ('u1', 'u2')");
      debugPrint('Dynamic migration: Cleaned up hardcoded seed users and data.');"""

migration_replace = """      // 先將現有題目的作者更新為系統帳號 'u3' (防止後續刪除使用者時被級聯刪除)
      await db.update('questions', {'user_id': 'u3'}, where: "user_id IN ('u1', 'u2')");

      // 自動清理歷史寫死之測試帳號與相關資料，確保排行榜與社群乾淨
      await db.delete('users', where: "id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('posts', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('quiz_results', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('todos', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('calendar_events', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      
      // 檢查題目是否因為先前的級聯刪除而被排空，若是則重新 Re-seed 題目的部分
      final qCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM questions')) ?? 0;
      if (qCount == 0) {
        debugPrint('Dynamic migration: Restoring questions bank...');
        await _seedQuestions(db);
      }
      debugPrint('Dynamic migration: Cleaned up hardcoded seed users and data.');"""

content = content.replace(migration_search, migration_replace)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Success: Refactored database_helper.dart with self-healing questions restore!")
