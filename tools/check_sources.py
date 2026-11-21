"""离线静态检查：括号/引号平衡、文件清单完整性。没有 macOS 时用来提前发现低级语法错误。"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "LeafReader")


def strip_swift(src: str) -> str:
    out = []
    i = 0
    n = len(src)
    while i < n:
        if src.startswith('"""', i):
            i += 3
            while i < n and not src.startswith('"""', i):
                i += 1
            i += 3
            continue
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j == -1 else j
            continue
        if src.startswith("/*", i):
            depth = 1
            i += 2
            while i < n and depth > 0:
                if src.startswith("/*", i):
                    depth += 1
                    i += 2
                elif src.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            continue
        ch = src[i]
        if ch == '"':
            i += 1
            while i < n:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def check_balance(path: str) -> list:
    with open(path, encoding="utf-8") as fh:
        raw = fh.read()
    if raw.count('"""') % 2 != 0 and raw.count('#"""') + raw.count('"""#') == 0:
        return ["未闭合的多行字符串 \"\"\""]
    code = strip_swift(raw)
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    problems = []
    line = 1
    for ch in code:
        if ch == "\n":
            line += 1
        if ch in "([{":
            stack.append((ch, line))
        elif ch in ")]}":
            if not stack:
                problems.append(f"第 {line} 行多余的 {ch}")
                continue
            top, top_line = stack.pop()
            if pairs[ch] != top:
                problems.append(f"第 {line} 行 {ch} 与第 {top_line} 行 {top} 不匹配")
    for ch, line in stack:
        problems.append(f"第 {line} 行 {ch} 未闭合")
    return problems


def main() -> int:
    files = []
    for dirpath, _, filenames in os.walk(SRC):
        for name in filenames:
            if name.endswith(".swift"):
                files.append(os.path.join(dirpath, name))
    files.sort()

    failures = 0
    for path in files:
        problems = check_balance(path)
        rel = os.path.relpath(path, ROOT)
        if problems:
            failures += 1
            print(f"[FAIL] {rel}")
            for p in problems[:12]:
                print("       " + p)
        else:
            print(f"[ OK ] {rel}")

    # 资源检查
    assets = os.path.join(SRC, "Assets.xcassets")
    for required in ["Contents.json", "AppIcon.appiconset/Contents.json", "AccentColor.colorset/Contents.json"]:
        target = os.path.join(assets, *required.split("/"))
        if not os.path.isfile(target):
            failures += 1
            print(f"[FAIL] 缺少资源 {required}")

    print(f"\n共 {len(files)} 个 Swift 文件，{failures} 个问题")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())