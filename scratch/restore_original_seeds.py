import re

file_path = r"C:\Users\user\ai_app\lib\database\database_helper.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add self-healing check in _initDB to restore seed users if they are missing
init_pattern = r"if \(!userCols\.any\(\(c\) => c\['name'\] == 'is_google'\)\) \{[\s\S]+?\}\s+\}"
replacement_init = """if (!userCols.any((c) => c['name'] == 'is_google')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN is_google INTEGER DEFAULT 0');
        debugPrint('Dynamic migration: Added is_google column to users table.');
      }

      // 自我修復：如果原廠測試帳號被清空，自動重新導入 (以 Sharon 帳號 id = u1 為指標)
      final u1Check = await db.query('users', where: "id = 'u1'");
      if (u1Check.isEmpty) {
        debugPrint('Dynamic migration: Restoring original seed users and data (Sharon, etc.)...');
        await _seedDatabase(db);
      }
    }"""

content = re.sub(init_pattern, replacement_init, content)

# 2. Add conflictAlgorithm: ConflictAlgorithm.ignore to all inserts in _seedDatabase
# First, let's locate the _seedDatabase method.
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
    
    old_body = "".join(body_chars)
    
    # Replace db.insert(..., { ... }) with db.insert(..., { ... }, conflictAlgorithm: ConflictAlgorithm.ignore)
    new_body = re.sub(
        r"await db\.insert\('([^']+)', (\{[\s\S]*?\})\);",
        r"await db.insert('\1', \2, conflictAlgorithm: ConflictAlgorithm.ignore);",
        old_body
    )
    
    content = content.replace(old_body, new_body)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Success: database_helper.dart updated to restore original seed data dynamically!")
