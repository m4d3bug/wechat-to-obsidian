# 微信文章 → Obsidian 知识库

在 Telegram 话题里丢一条微信链接，AI 自动爬取、排版、打标签，存进 Obsidian。

## 安装

在 OpenClaw 中发送：

```
帮我安装 wechat-to-obsidian：https://raw.githubusercontent.com/m4d3bug/wechat-to-obsidian/main/install.md
```

Agent 会询问你的 Obsidian 路径和 Telegram 话题名，自动完成配置。

## 效果

```
你：  https://mp.weixin.qq.com/s/xxxxx
Bot： 已收录《大模型时代的知识管理》
      标签：[AI, 效率工具, 知识管理]
```

Obsidian 收到：

```
Inbox/
├── 2026-03-16_大模型时代的知识管理.md
└── 2026-03-16_大模型时代的知识管理_assets/
    ├── img_1.jpg
    └── img_2.png
```

## 前置要求

- [OpenClaw](https://openclaw.ai)
- Python 3.8+（`beautifulsoup4`、`markdownify`，安装脚本自动处理）
- [Ollama](https://ollama.ai)（可选，用于 AI 打标签）
- Telegram Bot + 开启话题的超级群组

## 手动安装

详见 [install.md](./install.md)。

## License

MIT
