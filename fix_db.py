import os, re
for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            modified = re.sub(r'db\.insert\(\s*\'([^\']+)\',\s*\{', r'db.insert(' + chr(39) + r'\1' + chr(39) + r', <String, Object?>{', content)
            modified = re.sub(r'db\.update\(\s*\'([^\']+)\',\s*\{', r'db.update(' + chr(39) + r'\1' + chr(39) + r', <String, Object?>{', modified)
            if content != modified:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(modified)

