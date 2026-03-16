#!/bin/bash
# 知识库爬虫：抓取微信文章原文 + 下载图片 + AI打标签 → 存Obsidian
set -e

URL="$1"
VAULT_DIR="/mnt/e/KnowledgeBase/Inbox"
OLLAMA_URL="http://localhost:11435"
MODEL="minimax-m2.5:cloud"
TMPDIR_WORK=$(mktemp -d)
trap "rm -rf $TMPDIR_WORK" EXIT

[ -z "$URL" ] && { echo "用法: $0 <微信文章URL>"; exit 1; }
mkdir -p "$VAULT_DIR"

# 1. 爬取
echo "[1/4] 爬取文章..."
curl -sL "$URL" \
  -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 MicroMessenger/8.0.43" \
  -H "Accept: text/html,application/xhtml+xml" \
  -H "Accept-Language: zh-CN,zh;q=0.9" \
  -H "X-Requested-With: com.tencent.mm" \
  --max-time 30 -o "$TMPDIR_WORK/raw.html"

grep -q "环境异常" "$TMPDIR_WORK/raw.html" && { echo "错误：微信验证拦截"; exit 1; }

# 2. Python解析：使用 BeautifulSoup + markdownify 1:1 转换
echo "[2/4] 解析正文..."
cat > "$TMPDIR_WORK/parse.py" << 'PYEOF'
import sys, re, json, html as html_mod
from bs4 import BeautifulSoup
from markdownify import markdownify as md

with open(sys.argv[1], encoding='utf-8', errors='ignore') as f:
    raw = f.read()

soup = BeautifulSoup(raw, 'html.parser')

# ── 标题 ──────────────────────────────────────────────────────────────
title = '未知标题'
candidates = [
    soup.find(class_='js_title_inner'),
    soup.find(id='activity-name'),
    soup.find(class_=re.compile(r'rich_media_title')),
    soup.find('title'),
]
for el in candidates:
    if el:
        t = el.get_text(strip=True)
        if len(t) > 2:
            title = t
            break

# ── 作者 ──────────────────────────────────────────────────────────────
author = ''
el = soup.find(id='js_name')
if el:
    author = el.get_text(' ', strip=True)
    for sep in ['在小说', '阅读器', '关注']:
        if sep in author:
            author = author[:author.index(sep)].strip()
            break

# ── 正文区域 ──────────────────────────────────────────────────────────
content_tag = soup.find(id='js_content')
if content_tag is None:
    content_tag = soup.find('body') or soup

# 删除 script / style
for tag in content_tag.find_all(['script', 'style']):
    tag.decompose()

# ── 处理微信图片：data-src → src，并记录顺序 ──────────────────────────
img_urls = []
seen = {}
for img in content_tag.find_all('img'):
    url = img.get('data-src') or img.get('src') or ''
    url = url.replace('&amp;', '&').strip()
    if not url.startswith('http'):
        # 移除无用占位图
        img.decompose()
        continue
    if url not in seen:
        seen[url] = len(img_urls)
        img_urls.append(url)
    idx = seen[url]
    # 用特殊占位符替换整个 img 标签（markdownify 会保留文本节点）
    placeholder_tag = BeautifulSoup(f'IMGPLACEHOLDER_{idx}_END', 'html.parser')
    img.replace_with(f'IMGPLACEHOLDER_{idx}_END')

# ── 微信 <section> 当做 div 处理（markdownify 默认忽略未知块级元素）──────
for sec in content_tag.find_all('section'):
    sec.name = 'div'

# ── markdownify 转换 ──────────────────────────────────────────────────
content_html = str(content_tag)
content_md = md(
    content_html,
    heading_style='ATX',
    bullets='-',
    newline_style='backslash',
    strip=['a'],          # 微信链接无意义，去掉 <a> 包装但保留文字
)

# ── 后处理 ────────────────────────────────────────────────────────────
content_md = html_mod.unescape(content_md)
content_md = content_md.replace('\xa0', ' ')
# 去掉 markdownify 在 backslash 模式下产生的行末反斜杠（段落间换行）
content_md = re.sub(r'\\\n', '\n', content_md)
# 折叠多余空行（最多保留两个连续空行）
content_md = re.sub(r'\n{4,}', '\n\n\n', content_md)
content_md = content_md.strip()

result = {
    'title': title,
    'author': author,
    'content': content_md,
    'img_urls': img_urls,
}
print(json.dumps(result, ensure_ascii=False))
PYEOF

python3 "$TMPDIR_WORK/parse.py" "$TMPDIR_WORK/raw.html" > "$TMPDIR_WORK/parsed.json"

TITLE=$(python3 -c "import json; d=json.load(open('$TMPDIR_WORK/parsed.json')); print(d['title'])")
AUTHOR=$(python3 -c "import json; d=json.load(open('$TMPDIR_WORK/parsed.json')); print(d['author'])")
IMG_COUNT=$(python3 -c "import json; d=json.load(open('$TMPDIR_WORK/parsed.json')); print(len(d['img_urls']))")

echo "  标题: $TITLE"
echo "  图片数: $IMG_COUNT"

TODAY=$(date +%Y-%m-%d)
FILENAME=$(echo "$TITLE" | python3 -c "
import sys, re
t = sys.stdin.read().strip()
t = re.sub(r'[\\\\/:*?\"<>|%]', '', t)
print(t[:60])
")
ASSETS_DIR="${VAULT_DIR}/${TODAY}_${FILENAME}_assets"
mkdir -p "$ASSETS_DIR"

# 3. 下载图片并替换占位符
echo "[3/4] 下载图片 ($IMG_COUNT 张)..."
cat > "$TMPDIR_WORK/download_imgs.py" << PYEOF
import json, subprocess, os, sys

parsed = json.load(open('$TMPDIR_WORK/parsed.json'))
content = parsed['content']
assets_dir = '$ASSETS_DIR'
assets_name = '${TODAY}_${FILENAME}_assets'
ok = fail = 0

for i, url in enumerate(parsed['img_urls']):
    placeholder = f'IMGPLACEHOLDER_{i}_END'
    ext = 'jpg'
    for e in ['png', 'gif', 'webp', 'jpeg']:
        if e in url.lower():
            ext = e
            break
    local_name = f'img_{i+1}.{ext}'
    local_path = os.path.join(assets_dir, local_name)
    rel_path = f'{assets_name}/{local_name}'

    r = subprocess.run([
        'curl', '-sL', url,
        '-H', 'Referer: https://mp.weixin.qq.com/',
        '-H', 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)',
        '-o', local_path, '--max-time', '20'
    ], capture_output=True)

    if r.returncode == 0 and os.path.exists(local_path) and os.path.getsize(local_path) > 200:
        content = content.replace(placeholder, f'![图片]({rel_path})')
        ok += 1
    else:
        content = content.replace(placeholder, f'> [图片加载失败]({url})')
        fail += 1
    sys.stderr.write(f'\r  {i+1}/{len(parsed["img_urls"])} ({ok}成功 {fail}失败)')

sys.stderr.write('\n')
print(content)
PYEOF

FINAL_CONTENT=$(python3 "$TMPDIR_WORK/download_imgs.py")

# 4. AI 打标签
echo "[4/4] AI 打标签..."
PREVIEW=$(echo "$FINAL_CONTENT" | head -80 | tr '\n' ' ' | cut -c1-1500)
TAGS=$(curl -s "${OLLAMA_URL}/api/chat" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "请为以下文章生成3-6个中文标签，只输出标签列表格式如[标签1, 标签2]，不要其他内容。\n标题：${TITLE}\n内容摘要：${PREVIEW}" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')}],\"stream\":false}" \
  --max-time 60 | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('message',{}).get('content','[未分类]').strip())" 2>/dev/null)
TAGS=${TAGS:-"[未分类]"}

# 5. 写入文件
FILEPATH="${VAULT_DIR}/${TODAY}_${FILENAME}.md"
{
echo "---"
echo "title: ${TITLE}"
echo "author: ${AUTHOR}"
echo "url: ${URL}"
echo "created: ${TODAY}"
echo "tags: ${TAGS}"
echo "---"
echo ""
echo "$FINAL_CONTENT"
} > "$FILEPATH"

echo "完成: $FILEPATH"
echo "SAVED:$FILEPATH"
