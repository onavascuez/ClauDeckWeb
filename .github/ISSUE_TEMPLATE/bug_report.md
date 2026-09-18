---
name: Bug report
about: Something in ClauDeck or ClauDeck Lite does not behave as described
title: "[Bug] "
labels: bug
---

**Edition and version**
ClauDeck / ClauDeck Lite, version shown in the Stream Deck app (e.g. 2.0.0.0).

**Windows: run this first**
In PowerShell — read-only, prints no token — and paste the output at the end of this report:

```powershell
irm https://claudeck.dev/support/windows-check.ps1 -OutFile $env:TEMP\claudeck-check.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\claudeck-check.ps1
```

**Environment**
- OS and version (macOS 15.x / Windows 11):
- Stream Deck app version:
- Claude Code version (`claude --version`):
- Terminal app (Ghostty, iTerm, Windows Terminal…):

**What happened**
What you did, what you expected, what you saw on the deck.

**Plugin log**
Attach the newest file from the plugin's `logs/` folder:
- macOS: `~/Library/Application Support/com.elgato.StreamDeck/Plugins/dev.claudeck.streamdeck.sdPlugin/logs/`
- Windows: `%APPDATA%\Elgato\StreamDeck\Plugins\dev.claudeck.streamdeck.sdPlugin\logs\`
For hook problems, run `touch ~/.claude/claude-deck/debug` first and attach `~/.claude/claude-deck/hooks.log` too.
