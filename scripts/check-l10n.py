#!/usr/bin/env python3
"""Checks the English table: no duplicate keys, every user-facing Chinese
string in Sources has a translation, and no unused entries."""
import json, os, re, sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "Sources", "SideTouchBar")
TABLE = os.path.join(ROOT, "App", "L10n+English.swift")
CJK = re.compile(r"[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef]")
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')

# Chinese strings that are never shown: menu titles matched in other apps,
# browser title markers, measuring samples, and language-specific defaults.
NOT_SHOWN = {
    "进入全屏", "退出全屏", "画中画", "显示字幕", "隐藏字幕", "字幕", " - 内存用量", " - 内存使用量",
    "新聊天", "边栏", "阅读器", "Run|运行", "Stop Debugging|停止调试", "Debugging Actions|调试操作",
    "Step Over|步过", "示例标题，可能有两行", "/Users/me/示例项目", "继续", "解释改动", "解释一下刚才的改动",
    "写测试", "为刚才的改动补充测试", "检查改动", "检查一下这次的改动有没有问题", "中文回答", "请用中文回答",
    "词", "中文", "跟随系统",
}

def literals(path, skip_raw=True):
    in_raw = False
    for line in open(path, encoding="utf-8"):
        if skip_raw:
            if line.count('#"""') == 1 and not in_raw:
                in_raw = True
                continue
            if '"""#' in line and in_raw:
                in_raw = False
                continue
            if in_raw or line.strip().startswith("//"):
                continue
        for match in LITERAL.finditer(line):
            yield match.group(1)

table_keys = []
for line in open(TABLE, encoding="utf-8"):
    match = re.match(r'\s*"((?:[^"\\]|\\.)*)":', line)
    if match:
        table_keys.append(match.group(1))

used = set()
for directory, _, files in os.walk(ROOT):
    for name in files:
        path = os.path.join(directory, name)
        if name.endswith(".swift") and path != TABLE:
            used.update(s for s in literals(path) if CJK.search(s))

duplicates = sorted({k for k in table_keys if table_keys.count(k) > 1})
missing = sorted(used - set(table_keys) - NOT_SHOWN)
unused = sorted(set(table_keys) - used)

for title, items in [("Duplicate keys", duplicates), ("Missing translations", missing), ("Unused entries", unused)]:
    if items:
        print(f"{title} ({len(items)}):")
        for item in items:
            print("  " + item)
print(f"{len(table_keys)} entries, {len(used)} Chinese strings in use.")
sys.exit(1 if duplicates or missing else 0)
