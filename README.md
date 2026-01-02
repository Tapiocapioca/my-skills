# Claude Code Skills

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Skills](https://img.shields.io/badge/skills-1-blue.svg)](https://github.com/Tapiocapioca/claude-code-skills)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-purple.svg)](https://claude.com/code)

**A collection of production-ready skills for Claude Code**

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
# Clone to skills directory
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/Tapiocapioca/claude-code-skills.git
```

### Option 3: Single Skill

```bash
# Clone repository
git clone https://github.com/Tapiocapioca/claude-code-skills.git

# Copy only the skill you need
cp -r claude-code-skills/skills/web-to-rag ~/.claude/skills/
```

---

## Available Skills

| Skill | Description | Documentation |
|-------|-------------|---------------|
| **[web-to-rag](skills/web-to-rag/)** | Scrape websites, YouTube videos, PDFs and embed into local RAG | [README](skills/web-to-rag/README.md) • [Prerequisites](skills/web-to-rag/PREREQUISITES.md) |

> 💡 **Free to test!** You can try `web-to-rag` without spending money using [iFlow Platform](https://platform.iflow.cn/en/models) as the LLM provider (free tier available).

Each skill is **self-contained** with its own:
- Prerequisites and installers
- Infrastructure (Docker containers, if needed)
- Documentation

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
│       ├── install-prerequisites.ps1  # Windows installer
│       ├── install-prerequisites.sh   # Linux/macOS installer
│       ├── infrastructure/      # Docker containers
│       │   └── docker/
│       │       ├── yt-dlp/
│       │       └── whisper/
│       ├── references/          # Supporting docs
│       └── scripts/             # Utility scripts
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## Adding New Skills

1. Create a folder under `skills/` with your skill name
2. Add a `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: my-skill-name
   description: |
     What the skill does and when to use it.
     Include trigger keywords.
   allowed-tools: Tool1 Tool2 Tool3
   ---
   ```
3. Add documentation in `README.md`
4. Include prerequisites installer if the skill needs external services
5. Update `marketplace.json` to register the skill
6. Submit a pull request

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Ideas for New Skills

- Database query assistant
- API documentation generator
- Code review automation
- Log analysis
- Test generation

---

## License

[MIT License](LICENSE) - Feel free to use and modify.

---

## Author

Created by [Tapiocapioca](https://github.com/Tapiocapioca) with Claude Code.

*Last updated: January 2026*
