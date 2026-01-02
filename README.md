# Claude Code Skills

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Skills](https://img.shields.io/badge/skills-1-blue.svg)](https://github.com/Tapiocapioca/claude-code-skills)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-purple.svg)](https://claude.com/code)

**Production-ready skills for Claude Code**

[Installation](#installation) | [Available Skills](#available-skills) | [Contributing](#contributing)

</div>

---

## Installation

### Option 1: Plugin Marketplace (Recommended)

```bash
/plugin marketplace add Tapiocapioca/claude-code-skills
```

### Option 2: Manual Clone

```bash
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/Tapiocapioca/claude-code-skills.git
```

### Option 3: Single Skill

```bash
git clone https://github.com/Tapiocapioca/claude-code-skills.git
cp -r claude-code-skills/skills/web-to-rag ~/.claude/skills/
```

---

## Available Skills

| Skill | Description | Documentation |
|-------|-------------|---------------|
| **[web-to-rag](skills/web-to-rag/)** | Scrape websites, YouTube, PDFs into local RAG | [README](skills/web-to-rag/README.md) • [Prerequisites](skills/web-to-rag/PREREQUISITES.md) |

> **Free to test!** Try `web-to-rag` without cost using [iFlow Platform](https://platform.iflow.cn/en/models) (free tier). Sign up [here](https://iflow.cn/oauth?redirect=https%3A%2F%2Fvibex.iflow.cn%2Fsession%2Fsso_login).

Each skill is **self-contained** with its own prerequisites, infrastructure, and documentation.

---

## Repository Structure

```
claude-code-skills/
├── .claude-plugin/
│   └── marketplace.json         # Plugin registry
├── skills/
│   └── web-to-rag/              # Self-contained skill
│       ├── SKILL.md             # Skill definition
│       ├── README.md            # Documentation
│       ├── install-prerequisites.ps1
│       ├── install-prerequisites.sh
│       ├── infrastructure/      # Docker containers
│       ├── references/          # Supporting docs
│       └── scripts/             # Utilities
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## Adding New Skills

1. Create folder under `skills/`
2. Add `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: my-skill-name
   description: |
     What the skill does and when to use it.
     Include trigger keywords.
   allowed-tools: Tool1 Tool2 Tool3
   ---
   ```
3. Add `README.md`
4. Include installer if needed
5. Update `marketplace.json`
6. Submit pull request

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

### Ideas for New Skills

- Database query assistant
- API documentation generator
- Code review automation
- Log analysis
- Test generation

---

## License

[MIT License](LICENSE)

---

## Author

Created by [Tapiocapioca](https://github.com/Tapiocapioca) with Claude Code.

*Last updated: January 2026*
