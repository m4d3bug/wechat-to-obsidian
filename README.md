# 微信文章 → Obsidian 知识库

> 在 Telegram 话题里丢一条微信链接，AI 自动爬取、排版、打标签，存进 Obsidian。

---

## 效果

```
你：  https://mp.weixin.qq.com/s/xxxxx
Bot： 已收录《大模型时代的知识管理》
      保存至 Obsidian Inbox，标签：[AI, 效率工具, 知识管理]
```

Obsidian 收到：

```
Inbox/
├── 2026-03-16_大模型时代的知识管理.md
└── 2026-03-16_大模型时代的知识管理_assets/
    ├── img_1.jpg
    └── img_2.png
```

---

## 架构

```
Telegram Topic ──► OpenClaw Agent ──► fetch_and_save.sh
                                             │
                        ┌────────────────────┤
                        ▼                    ▼
                   WeChat HTML          Ollama (本地)
                        │                    │
                        ▼                    ▼
                  BeautifulSoup         AI 打标签
                  + markdownify              │
                        │                    │
                        └──────────┬─────────┘
                                   ▼
                            Obsidian Vault (.md)
```

---

## 前置要求

| 组件 | 说明 |
|------|------|
| [OpenClaw](https://openclaw.ai) | AI Agent 平台，负责 Telegram 接入和技能调度 |
| Python 3.8+ | 运行爬虫解析脚本 |
| [Ollama](https://ollama.ai) | 本地推理，用于 AI 打标签（可选，不影响爬取） |
| Obsidian Vault | 目标笔记库（本地文件夹即可） |
| Telegram Bot | 消息入口 |

---

## 安装

### 1. 克隆仓库

```bash
git clone https://github.com/m4d3bug/wechat-to-obsidian.git
cd wechat-to-obsidian
```

### 2. 安装 Python 依赖

```bash
pip install beautifulsoup4 markdownify
```

### 3. 配置变量

编辑 `scripts/fetch_and_save.sh`，修改顶部的配置项：

```bash
# ── 必填 ──────────────────────────────────────
VAULT_DIR="/mnt/e/KnowledgeBase/Inbox"   # Obsidian Inbox 目录的绝对路径

# ── 可选（AI 打标签，不填则跳过） ──────────────
OLLAMA_URL="http://localhost:11435"       # Ollama 服务地址
MODEL="minimax-m2.5:cloud"               # 使用的模型名称
```

### 4. 赋予执行权限

```bash
chmod +x scripts/fetch_and_save.sh
```

### 5. 手动验证

```bash
./scripts/fetch_and_save.sh "https://mp.weixin.qq.com/s/YOUR_ARTICLE_ID"
```

看到 `SAVED:/path/to/file.md` 说明爬取成功。

---

## 接入 OpenClaw + Telegram

### 第一步：创建 Telegram Bot

1. 打开 Telegram，搜索 **@BotFather**
2. 发送 `/newbot`，按提示设置名称和用户名
3. 复制返回的 **Bot Token**（格式：`123456789:AAFxxx...`）

### 第二步：创建带话题的 Telegram 群组

1. 新建一个 Telegram **超级群组**（Supergroup）
2. 进入群组设置 → **Topics**（话题）→ 开启
3. 创建一个新话题，名称设为你的知识库话题名，例如：

   ```
   TOPIC_NAME="博览群书"   # ← 改成你喜欢的名字
   ```

4. 将上面创建的 Bot 拉入群组，并设为**管理员**（需要发送消息权限）

### 第三步：获取群组 ID 和话题 ID

**获取群组 ID：**

```bash
# 让 Bot 发一条消息到群组，然后请求：
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
```

在返回的 JSON 里找 `"chat":{"id": -1001234567890}`，这就是群组 ID（负数）。

**获取话题 ID：**

在上面的 `getUpdates` 响应里找 `"message_thread_id": 12`，这是话题 ID。
或者在群组里右键话题名 → 复制链接，链接末尾的数字即为话题 ID。

### 第四步：安装并配置 OpenClaw

```bash
npm install -g openclaw
openclaw wizard
```

向导结束后，编辑 `~/.openclaw/openclaw.json`：

```json
{
  "tools": {
    "exec": {
      "host": "gateway",
      "security": "allowlist"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "<YOUR_BOT_TOKEN>",
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "groupAllowFrom": ["telegram:<YOUR_TELEGRAM_USER_ID>"],
      "streaming": "off",
      "groups": {
        "<GROUP_ID>": {
          "topics": {
            "<TOPIC_ID>": {
              "agentId": "main",
              "requireMention": false
            }
          }
        }
      }
    }
  }
}
```

> **变量说明：**
> | 变量 | 说明 |
> |------|------|
> | `<YOUR_BOT_TOKEN>` | BotFather 给的 Token |
> | `<YOUR_TELEGRAM_USER_ID>` | 你的 Telegram 数字 ID（可通过 @userinfobot 查询） |
> | `<GROUP_ID>` | 群组 ID（负数，如 `-1001234567890`） |
> | `<TOPIC_ID>` | 话题 ID（如 `12`） |
> | `TOPIC_NAME` | 话题显示名称（随意，仅在 Telegram 界面可见） |

### 第五步：部署技能

将整个仓库放到 OpenClaw skills 目录：

```bash
# 默认 skills 目录
SKILLS_DIR="$HOME/.openclaw/workspace/skills"

cp -r . "$SKILLS_DIR/knowledge-base"
```

### 第六步：配置执行白名单

编辑 `~/.openclaw/exec-approvals.json`：

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
          "pattern": "/root/.openclaw/workspace/skills/knowledge-base/scripts/fetch_and_save.sh"
        }
      ]
    }
  }
}
```

> 将 `pattern` 路径改为你实际的脚本绝对路径。

### 第七步：启动

```bash
openclaw start
```

---

## 使用方法

在你配置的 Telegram 话题（`TOPIC_NAME`）里直接发送微信文章链接：

```
https://mp.weixin.qq.com/s/xxxxxxxxxxxxxxxxxxxxxx
```

Bot 会自动处理并回复收录结果。无需 @Bot，无需任何命令前缀。

---

## 输出格式

每篇文章生成一个 Markdown 文件，格式如下：

```markdown
---
title: 文章标题
author: 公众号名称
url: https://mp.weixin.qq.com/s/xxx
created: 2026-03-16
tags: [标签1, 标签2, 标签3]
---

正文内容（1:1 还原原文排版）...

![图片](2026-03-16_文章标题_assets/img_1.jpg)
```

图片存放在同级的 `_assets` 文件夹，路径与 Obsidian 兼容。

---

## 常见问题

**Q：提示"环境异常"**
微信对非客户端访问有风控。目前脚本模拟 MicroMessenger UA，正常公众号文章均可抓取；付费内容、已删除文章无法获取。

**Q：图片显示"加载失败"**
微信图片有防盗链，需在 24 小时内下载。请在收到链接后及时触发爬取。

**Q：标签是"[未分类]"**
Ollama 服务未启动或模型不存在。标签功能可选，不影响文章保存。检查：
```bash
curl http://localhost:11435/api/tags
```

**Q：Bot 没有响应**
检查 OpenClaw 日志：
```bash
openclaw doctor
```

---

## 依赖说明

| 包 | 用途 |
|----|------|
| `beautifulsoup4` | HTML 解析 |
| `markdownify` | HTML → Markdown 1:1 转换 |
| `curl` | 文章抓取 & 图片下载（系统自带） |

---

## License

MIT
