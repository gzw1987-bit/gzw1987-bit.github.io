#!/bin/bash
# Usage: ./publish.sh <源文件路径> <分类> <标题> <描述> [标签1,标签2,...]
# 分类: yijing / frameworks / research / meta / course
# 取消发布: ./publish.sh --unpublish <分类/文件.html>
set -euo pipefail
SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SITE_DIR"

if [ "${1-}" != "--unpublish" ] && [ "$#" -lt 3 ]; then
  echo "用法: $0 <源文件> <分类> <标题> [描述] [标签]"
  echo "分类: yijing / frameworks / research / meta / course"
  echo "取消发布: $0 --unpublish <分类/文件.html>"
  python3 - <<'PY'
import json
from pathlib import Path
items = json.loads(Path('published.json').read_text(encoding='utf-8'))
for item in items:
    print(f"    {item['path']} — {item['title']}")
PY
  exit 0
fi

# Pass text as arguments instead of interpolating it into Python source.
DEST=$(python3 - "$@" <<'PY'
import datetime
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import sys
import tempfile

categories = {'yijing', 'frameworks', 'research', 'meta', 'course'}
root = Path.cwd().resolve()
metadata = root / 'published.json'
args = sys.argv[1:]

def fail(message):
    raise SystemExit('Error: ' + message)

def safe_destination(value):
    relative = PurePosixPath(value)
    if (relative.is_absolute() or len(relative.parts) != 2 or
            relative.parts[0] not in categories or
            relative.suffix.lower() not in {'.html', '.htm'} or
            any(ord(char) < 32 for char in value) or '\\' in value):
        fail('路径必须为受支持的分类/HTML文件名')
    destination = root / relative
    if destination.is_symlink() or destination.parent.is_symlink():
        fail('不允许发布或删除符号链接')
    if not destination.resolve().is_relative_to(root):
        fail('路径超出站点目录')
    return destination, relative.as_posix()

items = json.loads(metadata.read_text(encoding='utf-8'))
if not isinstance(items, list):
    fail('published.json 必须为列表')

if args[0] == '--unpublish':
    if len(args) != 2:
        fail('用法: --unpublish <分类/文件.html>')
    destination, relative = safe_destination(args[1])
    if not any(item.get('path') == relative for item in items):
        fail('该路径未登记为已发布页面')
    items = [item for item in items if item.get('path') != relative]
    destination.unlink(missing_ok=True)
else:
    if not 3 <= len(args) <= 5:
        fail('用法: <源文件> <分类> <标题> [描述] [标签]')
    source, category, title = args[:3]
    description = args[3] if len(args) > 3 else ''
    tags = args[4] if len(args) > 4 else ''
    if not title.strip():
        fail('标题不能为空')
    source = Path(source).expanduser()
    if not source.is_file():
        fail('源文件不存在')
    destination, relative = safe_destination(category + '/' + source.name)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.resolve() != destination.resolve():
        shutil.copyfile(source, destination)
    items = [item for item in items if item.get('path') != relative]
    items.insert(0, {'path': relative, 'title': title, 'desc': description,
        'tags': [tag.strip() for tag in tags.split(',') if tag.strip()],
        'date': datetime.date.today().isoformat(), 'category': category})

# Replace metadata atomically after validating all arguments.
with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=root, delete=False) as file:
    json.dump(items, file, ensure_ascii=False, indent=2)
    file.write('\n')
    temporary = file.name
try:
    os.replace(temporary, metadata)
finally:
    if Path(temporary).exists():
        Path(temporary).unlink()
print(relative)
PY
)

git add -- published.json "$DEST"
if git diff --cached --quiet -- published.json "$DEST"; then
  echo "页面与索引没有变更。"
  exit 0
fi
if [ "${1-}" = "--unpublish" ]; then
  git commit --only -m "unpublish: $DEST" -- published.json "$DEST"
else
  git commit --only -m "publish: $3" -- published.json "$DEST"
fi
git push origin main
echo "完成: https://gzw1987-bit.github.io/$DEST"
