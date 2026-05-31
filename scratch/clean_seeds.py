import re

file_path = r"C:\Users\user\ai_app\lib\database\database_helper.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update _initDB to include dynamic cleanup of u1, u2, u5, u6
migration_pattern = r"if \(!userCols\.any\(\(c\) => c\['name'\] == 'is_google'\)\) \{[\s\S]+?\}\s+\}"
replacement_migration = """if (!userCols.any((c) => c['name'] == 'is_google')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN is_google INTEGER DEFAULT 0');
        debugPrint('Dynamic migration: Added is_google column to users table.');
      }

      // 自動清理歷史寫死之測試帳號與相關資料，確保排行榜與社群乾淨
      await db.delete('users', where: "id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('posts', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('quiz_results', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('todos', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.delete('calendar_events', where: "user_id IN ('u1', 'u2', 'u5', 'u6')");
      await db.update('questions', {'user_id': 'u3'}, where: "user_id IN ('u1', 'u2')");
      debugPrint('Dynamic migration: Cleaned up hardcoded seed users and data.');
    }"""

content = re.sub(migration_pattern, replacement_migration, content)

# 2. Re-write _seedDatabase to remove Sharon, prof, ta, lee, guest inserts, posts, calendar_events, todos, and quiz_results.
# First, let's locate the _seedDatabase method.
seed_start = content.find("Future<void> _seedDatabase(Database db) async {")
if seed_start != -1:
    # We find the closing brace of the _seedDatabase method.
    # Since there are many nested braces due to jsonEncode, let's parse braces carefully.
    braces = 0
    idx = seed_start + len("Future<void> _seedDatabase(Database db) async {") - 1
    in_triple_quotes = False
    
    # Simple brace matching
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
    
    # Now let's process the seed body.
    # Keep u3, u4 inserts, keep questions (modifying user_id to u3), keep tags.
    # Remove u1, u2, u5, u6, calendar_events, todos, posts, quiz_results.
    
    # We can rebuild the _seedDatabase method body:
    new_body = """{
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
"""
    
    # Extract questions and tags from old seed_body using regex
    # We look for all `db.insert('questions', ...)` and `db.insert('tags', ...)` and `db.insert('question_tag_map', ...)`
    # To keep it exact, we can find all matches of `await db.insert('questions', { ... });`
    # Let's extract them.
    matches = re.findall(r"await db\.insert\('(?:questions|tags|question_tag_map)', \{[\s\S]*?\}\);", seed_body)
    
    # Process each match: replace user_id 'u1' or 'u2' with 'u3'
    for match in matches:
        processed = match.replace("'user_id': 'u1'", "'user_id': 'u3'").replace("'user_id': 'u2'", "'user_id': 'u3'")
        new_body += "\n    " + processed
        
    new_body += "\n  }"
    
    # Replace the old seed body with the new one
    content = content[:seed_start] + "Future<void> _seedDatabase(Database db) async " + new_body + content[idx+1:]

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Success: database_helper.dart updated!")
