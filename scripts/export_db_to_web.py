import sqlite3
import json
import os

db_path = 'app_database_preview.db'
if not os.path.exists(db_path):
    print(f"Error: {db_path} not found")
    exit(1)

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

# Get all tables
cursor.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
tables_meta = cursor.fetchall()

db_data = {}
for t in tables_meta:
    t_name = t['name']
    t_sql = t['sql']
    
    # Get columns info
    cursor.execute(f"PRAGMA table_info('{t_name}');")
    cols_info = [dict(row) for row in cursor.fetchall()]
    
    # Get foreign keys info
    cursor.execute(f"PRAGMA foreign_key_list('{t_name}');")
    fks_info = [dict(row) for row in cursor.fetchall()]

    # Get rows
    try:
        cursor.execute(f"SELECT * FROM '{t_name}';")
        rows = []
        for r in cursor.fetchall():
            row_dict = {}
            for k in r.keys():
                val = r[k]
                if isinstance(val, bytes):
                    row_dict[k] = f"<BLOB {len(val)} bytes>"
                else:
                    row_dict[k] = val
            rows.append(row_dict)
    except Exception as e:
        rows = []
        print(f"Error reading {t_name}: {e}")
        
    db_data[t_name] = {
        'name': t_name,
        'sql': t_sql,
        'columns': cols_info,
        'foreign_keys': fks_info,
        'rowCount': len(rows),
        'rows': rows
    }

conn.close()

with open('db_export.json', 'w', encoding='utf-8') as f:
    json.dump(db_data, f, ensure_ascii=False, indent=2)

print(f"Exported {len(db_data)} tables successfully to db_export.json!")
