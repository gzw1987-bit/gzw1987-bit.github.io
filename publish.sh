#!/bin/bash
# Usage: ./publish.sh <源文件路径> <分类> <标题> <描述> [标签1,标签2,...]
#
# 示例:
#   ./publish.sh ~/yijing-derivation/derivation-journey.html yijing "易经衍化之旅" "太极→384爻完整推演链路，13个交互阶段" "核心,交互,3400行"
#   ./publish.sh ~/claude-journey.html meta "166天旅程全景" "Claude Code协作全旅程" "核心,交互"
#
# 取消发布:
#   ./publish.sh --unpublish <路径>
#   ./publish.sh --unpublish yijing/derivation-journey.html

set -e
SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SITE_DIR"

# === UNPUBLISH ===
if [ "$1" = "--unpublish" ]; then
  target="$2"
  if [ -z "$target" ]; then
    echo "Usage: $0 --unpublish <path>"
    exit 1
  fi
  # Remove from published.json
  python3 -c "
import json,sys
with open('published.json') as f: items=json.load(f)
items=[i for i in items if i['path']!='$target']
with open('published.json','w') as f: json.dump(items,f,ensure_ascii=False,indent=2)
print(f'Removed $target. {len(items)} items remain.')
"
  # Remove file
  rm -f "$target"
  git add -A && git commit -m "unpublish: $target" && git push origin main
  echo "Done. Unpublished: $target"
  exit 0
fi

# === PUBLISH ===
SRC="$1"
CATEGORY="$2"
TITLE="$3"
DESC="$4"
TAGS="$5"

if [ -z "$SRC" ] || [ -z "$CATEGORY" ] || [ -z "$TITLE" ]; then
  echo ""
  echo "  publish.sh — 发布一个页面到你的知识站"
  echo ""
  echo "  用法: ./publish.sh <源文件> <分类> <标题> <描述> [标签]"
  echo ""
  echo "  分类: yijing / frameworks / research / meta / course"
  echo ""
  echo "  示例:"
  echo "    ./publish.sh ~/yijing-derivation/derivation-journey.html yijing \\"
  echo "      \"易经衍化之旅\" \"太极→384爻完整推演\" \"核心,交互\""
  echo ""
  echo "  取消发布:"
  echo "    ./publish.sh --unpublish yijing/derivation-journey.html"
  echo ""
  echo "  当前已发布:"
  python3 -c "
import json
with open('published.json') as f: items=json.load(f)
if not items: print('    (无)')
for i in items: print(f'    {i[\"path\"]}  —  {i[\"title\"]}')
"
  exit 0
fi

# Validate source file
if [ ! -f "$SRC" ]; then
  echo "Error: $SRC not found"
  exit 1
fi

# Create category dir
mkdir -p "$CATEGORY"

# Copy file
FILENAME=$(basename "$SRC")
DEST="$CATEGORY/$FILENAME"
cp "$SRC" "$DEST"
echo "Copied: $SRC → $DEST"

# Update published.json
DATE=$(date '+%Y-%m-%d')
python3 -c "
import json
with open('published.json') as f: items=json.load(f)

# Remove existing entry for same path (update)
items=[i for i in items if i['path']!='$DEST']

tags='$TAGS'.split(',') if '$TAGS' else []
tags=[t.strip() for t in tags if t.strip()]

items.insert(0, {
    'path': '$DEST',
    'title': '$TITLE',
    'desc': '$DESC',
    'tags': tags,
    'date': '$DATE',
    'category': '$CATEGORY'
})

with open('published.json','w') as f:
    json.dump(items, f, ensure_ascii=False, indent=2)
print(f'published.json updated. Total: {len(items)} items.')
"

# Git commit and push
git add -A
git commit -m "publish: $TITLE"
git push origin main

echo ""
echo "Published! Will be live in ~1 min at:"
echo "  https://gzw1987-bit.github.io/$DEST"
echo ""
echo "Homepage: https://gzw1987-bit.github.io/"
