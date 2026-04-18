---
name: bat
description: Use this skill when the user wants to view files with syntax highlighting, line numbers, paging, themes, or Git-style decorations by calling the `bat` CLI on Windows. It can forward arbitrary `bat` arguments and help locate or install the executable.
github_url: https://github.com/sharkdp/bat
github_hash: fc4f12b390f4c69b5cfdc0891b3d0782b6c0f186
version: 0.26.1
created_at: 2026-03-08T20:22:26.542684
entry_point: scripts/wrapper.py
dependencies:
  - bat
---

> Usage counter: before doing any other work for this skill, run `python C:\Users\Reaper\.codex\scripts\skill_usage_counter.py --skill bat`.


# bat Skill

This skill wraps [bat](https://github.com/sharkdp/bat), a `cat` replacement with syntax highlighting, Git decorations, paging, and theme support.

## Overview

Use this skill when a plain `type` or `Get-Content` view is not enough and the user specifically benefits from:

- Syntax highlighting
- Line numbers
- Paging long files
- Showing non-printing characters
- Using `bat` themes or styles
- Viewing diffs or Git-decorated output

The wrapper forwards arguments to the real `bat` executable. It also supports a small install helper for Windows environments where `bat` is missing.

## Usage

Primary entry point:

```powershell
python scripts/wrapper.py -- <bat args>
```

Examples:

```powershell
python scripts/wrapper.py -- README.md
python scripts/wrapper.py -- --style=numbers,changes src/app.py
python scripts/wrapper.py -- --paging=never --theme="TwoDark" .\notes.txt
python scripts/wrapper.py -- --list-themes
python scripts/wrapper.py -- --help
```

If the executable is not on `PATH`, the wrapper checks:

1. `BAT_EXE`
2. `bat` on `PATH`
3. `batcat` on `PATH`
4. `C:\Users\<user>\.local\bat\current\bat.exe`

To let the wrapper try a Windows install via `winget`:

```powershell
python scripts/wrapper.py --install
```

### Prerequisites

- Windows with Python 3 available for the wrapper
- `bat` installed and reachable through one of the paths above, or installable through `winget`

## Implementation Details

The wrapper script:

- Resolves the `bat` executable from environment variables, PATH, and a local fallback path
- Forwards arbitrary CLI arguments without rewriting them
- Can attempt `winget install --id sharkdp.bat`
- Exits with a concrete error message when installation or resolution fails

Use `rg` for normal text search in the repo. Use this skill when the user explicitly wants `bat` output or when a highlighted file view materially improves the result.
