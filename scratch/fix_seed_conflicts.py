import re

file_path = r"C:\Users\user\ai_app\lib\database\database_helper.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()
start_idx = content.find("Future<void> _seedQuestions(Database db) async {")
if start_idx != -1:
    # Match the body of _seedQuestions
    idx = start_idx + len("Future<void> _seedQuestions(Database db) async {") - 1
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
    
    # Replace `db.insert('table', { ... });` with `db.insert('table', { ... }, conflictAlgorithm: ConflictAlgorithm.ignore);`
    # We can match `db.insert(..., { ... })` and append the parameter.
    # Note that there might be closing parentheses inside like jsonEncode([...]).
    # So we should be careful.
    # An easier way is to find all `await db.insert(...)` blocks and modify them.
    
    # Pattern to match: `await db.insert('tableName', { data } );`
    # Let's replace the ending `});` of `await db.insert(..., { ... });` with `}, conflictAlgorithm: ConflictAlgorithm.ignore);`
    # We can use regex replacement with lookbehinds or a parser.
    # Since all inserts end with `});`, we can find all `await db.insert(` and search forward to the matching `});`
    
    new_body = old_body
    
    # We will find each insert block
    insert_starts = [m.start() for m in re.finditer(r"await db\.insert\(", old_body)]
    # Go backwards to replace so indices don't shift or rebuild
    # Let's extract and replace cleanly
    offset = 0
    for pos in insert_starts:
        # Find the first `});` after pos
        end_pos = old_body.find("});", pos)
        if end_pos != -1:
            # We insert conflictAlgorithm inside the parenthesis
            # It should be `}, conflictAlgorithm: ConflictAlgorithm.ignore);`
            # Let's make sure it is exactly replaced.
            pass
            
    # Simple regex search and replace for the specific pattern in the file
    # We know that the database inserts look like:
    # await db.insert('table', {
    #   ...
    # });
    # Let's do a regex replacement:
    new_body = re.sub(
        r"await db\.insert\('([^']+)', (\{[\s\S]*?\})\);",
        r"await db.insert('\1', \2, conflictAlgorithm: ConflictAlgorithm.ignore);",
        old_body
    )
    
    content = content.replace(old_body, new_body)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Success: Added ConflictAlgorithm.ignore to all inserts in database_helper.dart!")
