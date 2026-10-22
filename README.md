# Claude Code SEO Skills Toolkit

A curated bundle of specialized SEO, content strategy, and audit skills for [Claude Code](https://claude.ai/code). Includes automated installation for Windows and optional WordPress integration via [Royal MCP](https://wordpress.org/plugins/royal-mcp/).

---

## ⚡ 1-Minute Quick Start (Windows)

Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/rachid-log/claude-seo-skills/main/install.ps1 | iex
```

The script will automatically:
1. Verify Node.js (18+) is available.
2. Ensure Claude Code CLI (`claude`) is installed globally via npm.
3. Install all 7 SEO skills into `$HOME\.claude\skills\`.
4. Optionally prompt you to link your WordPress site via Royal MCP.

---

## 📦 Included Skills

| Skill | Description | Trigger Keywords |
|---|---|---|
| **ai-seo** | Optimize content to get cited in AI answers (ChatGPT, Perplexity, Gemini, Google AI Overviews) | `AI SEO`, `AEO`, `GEO`, `llms.txt`, `cite sources` |
| **seo-audit** | Comprehensive technical and on-page SEO health check | `SEO audit`, `technical SEO`, `crawl errors`, `rankings` |
| **content-strategy** | Plan content calendars, topic clusters, and demand-driven roadmaps | `content strategy`, `topic clusters`, `what to write` |
| **programmatic-seo** | Design data-driven landing pages and templates at scale | `programmatic SEO`, `pSEO`, `pages at scale`, `templates` |
| **schema** | Implement and test JSON-LD structured data and rich snippets | `schema markup`, `structured data`, `rich snippets` |
| **audit-website** | Iterative site auditor and fix loop (integrates with SquirrelScan CLI) | `audit website`, `website quality`, `accessibility audit` |
| **find-skills** | Discover and install community skills from `skills.sh` | `find skill`, `install skill`, `extend capabilities` |

---

## 🔌 WordPress Royal MCP Integration (Optional)

If you manage a WordPress site, you can link it directly to Claude Code so the SEO skills can inspect published pages, draft articles, and insert schema markup automatically:

1. Install and activate **[Royal MCP](https://wordpress.org/plugins/royal-mcp/)** on your WordPress site.
2. In WordPress Admin, navigate to **Royal MCP** settings and toggle **Enable Royal MCP Integration**.
3. During the PowerShell installer, enter your WordPress URL and API key when prompted, or manually register anytime:

```powershell
claude mcp add --transport http royal-wordpress "https://your-site.com/wp-json/royal-mcp/v1/mcp" --header "Authorization: Bearer <your-wordpress-api-key>"
```

---

## 🛠️ Manual Installation (Cross-Platform)

Clone this repository and copy the `skills/` folder into your global Claude directory:

```bash
git clone https://github.com/rachid-log/claude-seo-skills.git
cp -r claude-seo-skills/skills/* ~/.claude/skills/
```

Verify your installed skills inside any Claude Code session by typing:

```text
/skills
```
