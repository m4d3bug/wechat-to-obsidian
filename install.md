# 安装指南：wechat-to-obsidian

你是一个 OpenClaw AI Agent，正在帮用户安装"微信文章 → Obsidian"技能。请按以下步骤依次执行，遇到需要用户提供信息的地方请主动询问。

---

## 第一步：收集配置信息

在开始安装前，请询问用户以下变量（如果用户已在消息中提供，直接使用）：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `VAULT_DIR` | Obsidian Inbox 目录的绝对路径 | `/mnt/e/KnowledgeBase/Inbox` |
| `TOPIC_NAME` | 触发爬虫的 Telegram 话题名称 | `博览群书` |
| `OLLAMA_URL` | Ollama 服务地址（AI 打标签用，可选） | `http://localhost:11435` |
| `MODEL` | Ollama 模型名称（可选） | `minimax-m2.5:cloud` |

询问示例："请告诉我你的 Obsidian Inbox 路径，以及你希望用哪个 Telegram 话题名来触发收藏（默认"博览群书"）？"

---

## 第二步：安装 Python 依赖

```bash
pip install beautifulsoup4 markdownify
```

验证安装成功：

```bash
python3 -c "import bs4; import markdownify; print('依赖安装成功')"
```

---

## 第三步：部署技能文件

```bash
mkdir -p ~/.openclaw/workspace/skills/wechat-to-obsidian/scripts
```

下载脚本文件：

```bash
curl -sL https://raw.githubusercontent.com/m4d3bug/wechat-to-obsidian/main/scripts/fetch_and_save.sh \
  -o ~/.openclaw/workspace/skills/wechat-to-obsidian/scripts/fetch_and_save.sh

curl -sL https://raw.githubusercontent.com/m4d3bug/wechat-to-obsidian/main/SKILL.md \
  -o ~/.openclaw/workspace/skills/wechat-to-obsidian/SKILL.md

chmod +x ~/.openclaw/workspace/skills/wechat-to-obsidian/scripts/fetch_and_save.sh
```

---

## 第四步：写入用户配置

用用户提供的变量替换脚本中的默认值：

```bash
SCRIPT=~/.openclaw/workspace/skills/wechat-to-obsidian/scripts/fetch_and_save.sh

sed -i "s|VAULT_DIR=.*|VAULT_DIR=\"${VAULT_DIR}\"|" "$SCRIPT"
sed -i "s|OLLAMA_URL=.*|OLLAMA_URL=\"${OLLAMA_URL}\"|" "$SCRIPT"
sed -i "s|MODEL=.*|MODEL=\"${MODEL}\"|" "$SCRIPT"
```

更新 SKILL.md 中的话题名称：

```bash
sed -i "s|博览群书|${TOPIC_NAME}|g" \
  ~/.openclaw/workspace/skills/wechat-to-obsidian/SKILL.md
```

---

## 第五步：配置执行白名单

读取当前 `~/.openclaw/exec-approvals.json`，在 `agents.main.allowlist` 中添加以下条目（如果文件不存在则创建）：

```json
{
  "pattern": "~/.openclaw/workspace/skills/wechat-to-obsidian/scripts/fetch_and_save.sh"
}
```

如需创建完整文件，使用以下内容：

```json
{
  "version": 1,
  "defaults": {
    "security": "allowlist",
    "ask": "on-miss",
    "askFallback": "allowlist"
  },
  "agents": {
    "main": {
      "security": "allowlist",
      "ask": "on-miss",
      "askFallback": "allowlist",
      "autoAllowSkills": true,
      "allowlist": [
        {
          "pattern": "~/.openclaw/workspace/skills/wechat-to-obsidian/scripts/fetch_and_save.sh"
        }
      ]
    }
  }
}
```

---

## 第六步：验证安装

创建 Obsidian Inbox 目录（如不存在）：

```bash
mkdir -p "${VAULT_DIR}"
```

运行一次测试（可选，需用户提供一条微信文章链接）：

```bash
~/.openclaw/workspace/skills/wechat-to-obsidian/scripts/fetch_and_save.sh "https://mp.weixin.qq.com/s/EXAMPLE"
```

---

## 第七步：重载技能

告诉用户："技能已安装完成。请在 OpenClaw 中说'刷新技能'或重启 Gateway 使技能生效。"

然后回复用户安装总结：

```
✅ wechat-to-obsidian 安装完成

配置：
- Obsidian Inbox: ${VAULT_DIR}
- 触发话题: ${TOPIC_NAME}
- AI 打标签: ${OLLAMA_URL} / ${MODEL}

使用方式：在 Telegram「${TOPIC_NAME}」话题中发送任意微信文章链接即可自动收录。
```
