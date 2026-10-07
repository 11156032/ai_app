"""掃描 lib/ 中仍寫死在介面上的中文字串，協助檢查多語系（繁中/日/韓）覆蓋率。

用法：
    python scripts/check_i18n.py            # 各檔案剩餘數量摘要
    python scripts/check_i18n.py -v         # 列出每一筆（行號 + 內容）
    python scripts/check_i18n.py -v lib/screens/notes_screen.dart

會自動略過：註解、debugPrint/print/throw/RegExp 行、三引號字串（AI 提示詞）、
已包在 tr()/trv() 內的字串、開發者中心與資料庫種子資料。
剩下的結果中仍可能包含「程式邏輯用的資料值」（例如篩選狀態 '全部'、題型 '單選題'），
這類值應保持原文，於顯示處以 trv() 轉換；若某行確定不需翻譯，可在行尾加上 // i18n-ignore。
"""
import io
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib')
EXCLUDE_DIRS = {'developer', 'l10n'}
EXCLUDE_FILES = {'database_helper.dart', 'app_locale_service.dart', 'architecture_qa_service.dart'}
CJK = re.compile(r'[㐀-鿿]')
SKIP_LINE = re.compile(r'debugPrint|\bprint\(|\blog\(|throw |Exception\(|RegExp\(|i18n-ignore|^\s*(//|///|\*)')


def string_literals(src):
    """Yield (line_no, content) for non-triple-quoted string literals (handles ${} nesting)."""
    i, n = 0, len(src)
    out = []

    def parse_string(i):
        raw = i > 0 and src[i - 1] in 'rR' and (i < 2 or not (src[i - 2].isalnum() or src[i - 2] == '_'))
        q = src[i]
        triple = src[i:i + 3] == q * 3
        ql = 3 if triple else 1
        j = i + ql
        start = j
        while j < n:
            c = src[j]
            if not raw and c == '\\':
                j += 2
                continue
            if (triple and src[j:j + 3] == q * 3) or (not triple and (c == q or c == '\n')):
                break
            if not raw and c == '$' and j + 1 < n and src[j + 1] == '{':
                j = parse_code(j + 2, True)
                continue
            j += 1
        if not triple:
            out.append((src.count('\n', 0, i) + 1, src[start:j]))
        return j + ql

    def parse_code(i, interp):
        depth = 0
        while i < n:
            c = src[i]
            if src.startswith('//', i):
                k = src.find('\n', i)
                i = n if k < 0 else k
                continue
            if src.startswith('/*', i):
                k = src.find('*/', i + 2)
                i = n if k < 0 else k + 2
                continue
            if c in '\'"':
                i = parse_string(i)
                continue
            if c == '{':
                depth += 1
            elif c == '}':
                if interp and depth == 0:
                    return i + 1
                depth -= 1
            i += 1
        return i

    parse_code(0, False)
    return out


def scan_file(path):
    src = io.open(path, encoding='utf-8').read()
    lines = src.split('\n')
    hits = []
    for line_no, content in string_literals(src):
        if not CJK.search(content):
            continue
        line = lines[line_no - 1]
        if SKIP_LINE.search(line):
            continue
        hits.append((line_no, content))
    return hits


def main():
    verbose = '-v' in sys.argv
    targets = [a for a in sys.argv[1:] if not a.startswith('-')]
    files = []
    if targets:
        files = targets
    else:
        for dirpath, dirnames, filenames in os.walk(ROOT):
            dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
            for f in filenames:
                if f.endswith('.dart') and f not in EXCLUDE_FILES:
                    files.append(os.path.join(dirpath, f))
    total = 0
    results = []
    for f in sorted(files):
        hits = scan_file(f)
        if hits:
            results.append((len(hits), f, hits))
            total += len(hits)
    for count, f, hits in sorted(results, reverse=True):
        print(f'{count:5d}  {os.path.relpath(f, os.path.join(ROOT, ".."))}')
        if verbose:
            for line_no, content in hits:
                print(f'         L{line_no}: {content[:100]}')
    print(f'\n共 {total} 筆可能未翻譯的中文字串（含程式邏輯用資料值）')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
