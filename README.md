# AI Desktop

A VS Code-style desktop IDE with a built-in AI coding agent, built in Flutter and
powered by the HidePulsa AI API.

## Features

### Editor & Workspace
- **File explorer** with VS Code-style toolbar (new file, new folder, refresh,
  collapse all) and colored language icons (Material Icon Theme SVGs).
- **Tabbed code editor** with syntax highlighting (VS Code "Dark+" colors),
  line-number gutter, current-line highlight, and breadcrumbs.
- **Minimap** with a viewport indicator (click/drag to navigate).
- **Find / Replace** in-file (`Ctrl+F` / `Ctrl+H`) with match count and navigation.
- **Quick Open** (`Ctrl+P`) — fuzzy file search across the workspace.
- **Save** with `Ctrl+S`; open files & active tab are restored on next launch.

### Diagnostics (error detection)
- **Dart**: runs `dart analyze` for authoritative errors/warnings.
- **Python**: uses `pyflakes` if installed, otherwise `py_compile` for syntax errors.
- Structural checks (unbalanced brackets / unterminated strings) for other languages.
- Markers in the gutter, a **Problems** panel, and counts in the status bar.

### Integrated terminal
- Real PTY (ConPTY on Windows) via `xterm` + `flutter_pty`.
- **Multiple terminals** with a session list; pick the shell (Command Prompt,
  Windows PowerShell, PowerShell 7) from the `+` dropdown.
- Toggle with `Ctrl+\`` ; resizable bottom panel shared with Problems.

### AI assistant
- **Chat mode**: context-aware Q&A. The active file and any attached
  files/folders (`+` button) are sent as context.
- **Agent mode**: an autonomous loop that can `read_file`, `write_file`,
  `str_replace`, `delete_file`, `list_dir`, and `run_command` within the
  workspace. Commands require approval unless auto-approve is on.
- **Changes summary + Revert**: undo all file changes from an agent run.
- **#File / #Folder mention**: attach specific files/folders as context.
- Streaming responses, model selector, conversation history (persisted in Hive).

### UI / Theme
- VS Code Dark+ palette, **codicon** icon font, **JetBrains Mono** editor font.
- Custom frameless title bar (`window_manager`) with menu bar, center command
  box, and window controls. Opens maximized.

## Tech Stack
- **Flutter Desktop** (Windows primary)
- **Riverpod** — state management
- **Hive** — local persistence (settings, conversations, session)
- **xterm** + **flutter_pty** — integrated terminal
- **highlight** — syntax highlighting
- **flutter_svg** — file-type icons
- **window_manager** — custom title bar
- **http** — SSE streaming to the AI API

## Getting Started

### Prerequisites
- Flutter SDK (Dart 3.2+)
- Windows: Visual Studio with the "Desktop development with C++" workload
- (Optional) `pip install pyflakes` for richer Python diagnostics

### Run
```bash
flutter pub get
flutter run -d windows
```

### Build a release
```bash
flutter build windows --release
# output: build/windows/x64/runner/Release/
```

### Configuration
- A default HidePulsa API key ships in the app; change it via the **Settings**
  dialog (stored in Hive).
- Base URL: `https://ai.hidepulsa.com/v1`

## Keyboard Shortcuts
| Shortcut | Action |
| --- | --- |
| `Ctrl+P` | Quick Open file |
| `Ctrl+F` | Find in file |
| `Ctrl+H` | Find & Replace |
| `Ctrl+S` | Save file |
| `` Ctrl+` `` | Toggle terminal |
| `Esc` | Close find bar / dialogs |

## Project Structure
```
lib/
├── main.dart                     # Entry point, window setup
├── app.dart                      # MaterialApp
├── core/
│   ├── constants/                # API config, system prompts
│   ├── services/                 # AI API client (SSE)
│   ├── storage/                  # Hive setup
│   └── theme/                    # Colors, codicons
└── features/
    ├── ide/                      # Shell, menu bar, panels, quick open
    ├── workspace/                # Explorer, editor, minimap, file icons
    ├── chat/                     # AI chat, agent loop, context
    ├── agent/                    # Tools, change tracking
    ├── terminal/                 # PTY sessions
    ├── search/                   # Workspace search
    ├── git/                      # Source control
    ├── diagnostics/              # Error detection, problems
    ├── rundebug/                 # Run & Debug
    └── extensions/               # Built-in capabilities panel
```

## License
Private project — All rights reserved.
