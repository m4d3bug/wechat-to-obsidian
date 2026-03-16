---
name: knowledge-base
description: >
  知识库管理：当用户在"博览群书"话题发送微信文章链接（mp.weixin.qq.com）时，
  自动爬取文章内容，用本地大模型整理成卡片型笔记，保存到 Obsidian Inbox。
  触发条件：消息包含 mp.weixin.qq.com 链接。
  不适用于：普通对话、非微信链接。
---

# 知识库技能

## 触发场景

用户在"博览群书" Topic 发送包含 `mp.weixin.qq.com` 的链接时自动触发。

## 执行步骤

1. 从消息中提取微信文章 URL
2. 调用爬虫脚本抓取内容并用 AI 整理
3. 保存到 Obsidian Inbox，回复保存结果

## 调用方式

```bash
/root/.openclaw/workspace/skills/knowledge-base/scripts/fetch_and_save.sh <url>
```

脚本输出最后一行格式为 `SAVED:/path/to/file.md`，提取路径告知用户。

## 回复模板

成功时回复：
```
已收录《文章标题》
保存至 Obsidian Inbox，标签：[tag1, tag2]
```

失败时回复：
```
抓取失败：<原因>，请检查链接是否有效。
```

## 配置

- Vault Inbox: `/mnt/e/KnowledgeBase/Inbox`
- 模型: `minimax-m2.5:cloud`（本地 Ollama）
- 爬虫脚本: `scripts/fetch_and_save.sh`
