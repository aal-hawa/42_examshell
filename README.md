# 42 Exam Practice Shell

⚡ An interactive practice environment for 42 School exams (Ranks 02-06) ⚡

## 📋 Overview

This project provides a comprehensive practice shell for 42 School examinations, offering interactive menus and practice exercises for different exam ranks. The shell simulates the actual exam environment and helps students prepare effectively.

> **Note**: This is a maintained fork of the original [terminal-42s/42_examshell](https://github.com/terminal-42s/42_examshell) project with additional improvements and updates. The original repository remains the canonical source, while this fork includes enhanced functionality and maintenance.

## 🔄 Repository Information

- **Original Repository**: [https://github.com/terminal-42s/42_examshell](https://github.com/terminal-42s/42_examshell)
- **This Fork**: [https://github.com/aal-hawa/42_examshell](https://github.com/aal-hawa/42_examshell)
- **Maintained by**: aal-hawa
- **Updates**: Enhanced `list`, `choose`, `cases`, `clean`, `fclean` commands + AI `analysis` with multi-model support

## 🚀 Features

- **Interactive Menu System**: Clean, colorful terminal interface
- **Multiple Exam Ranks**: Support for Ranks 02, 03, 04, 05 and 06
- **Practice Environment**: Dedicated workspace (`rendu` folder) for submissions
- **Interactive Exercise Picker**: Numbered menu to choose exercises by number or name
- **Direct Selection**: `choose <name|num>` for quick jumps, or just `choose` for the menu
- **AI Error Analysis**: `analysis` command sends test failures + your code to AI for detailed explanations
- **Multi-Model AI**: Each provider can have multiple models with a default model selected
- **Command Reference**: Built-in `help` command shows all available commands
- **Easy Navigation**: Simple numbered menu system

## 📁 Project Structure

```
.
├── exam.sh           # Main entry point
├── Makefile          # Build configuration
├── README.md         # This file
└── .resources/       # Practice materials
    ├── main/         # Main menu and interface
    ├── rank02/       # Rank 02 exam exercises
    ├── rank03/       # Rank 03 exam exercises
    ├── rank04/       # Rank 04 exam exercises
    ├── rank05/       # Rank 05 exam exercises
    └── rank06/       # Rank 06 exam exercises
```

## 🔧 Installation & Usage

### Quick Start

1. **Clone the repository** (choose either version):

   **Option 1: Original repository**
   ```bash
   git clone https://github.com/terminal-42s/42_examshell
   cd 42_examshell
   ```

   **Option 2: Maintained fork (recommended)**
   ```bash
   git clone https://github.com/aal-hawa/42_examshell
   cd 42_examshell
   ```

2. **Run the exam shell**:
   ```bash
   make
   ```

   Or directly:
   ```bash
   bash exam.sh
   ```

### Menu Options

The main menu provides the following options:

- **🔄 1. Commands**: Access command reference and practice
- **🚀 2. Exam Rank 02**: Practice exercises for Rank 02 exam
- **📋 3. Exam Rank 03**: Practice exercises for Rank 03 exam
- **📄 4. Exam Rank 04**: Practice exercises for Rank 04 exam
- **📄 5. Exam Rank 05**: Practice exercises for Rank 05 exam
- **📄 6. Exam Rank 06**: Practice exercises for Rank 06 exam
- **📁 7. Open Rendu Folder**: Access your submission workspace
- **🔄 8. Update Shell**: Keep your exam shell up-to-date with latest features

## ⌨️ Commands

Once inside a practice session, you can use these commands:

| Command | Description |
|---------|-------------|
| `list` | Show all exercises in the current level |
| `choose` | Pick an exercise from a numbered menu |
| `choose <name\|num>` | Pick a specific exercise by name or number directly (e.g. `choose ft_strlen` or `choose 5`) |
| `next` | Get a random next exercise |
| `test` | Test your code (stops at first failure, like real exam) |
| `cases` | Run ALL test cases & show detailed results (doesn't stop at first failure) |
| `analysis` | AI analysis of test failures — explains what, why, and how to fix |
| `setai add <name> <endpoint> [key] [model]` | Add a new AI provider |
| `setai remove <name>` | Remove an AI provider |
| `setai use <name>` | Switch active AI provider |
| `setai key <name> <key>` | Set API key for a provider |
| `setai addmodel <name> <model>` | Add a model to a provider's model list |
| `setai rmodel <name> <model>` | Remove a model from a provider's model list |
| `setai defaultmodel <name> <model>` | Set the default model for a provider |
| `setai model <name> <model>` | Set default model (adds to list if new — shortcut) |
| `setai endpoint <name> <url>` | Set endpoint for a provider |
| `showai` | Show all AI provider configurations (with model lists) |
| `status` | Show current session info (rank, level, current exercise) |
| `clean` | Remove compiled artifacts & temp files (.o, binaries, logs, test outputs) |
| `fclean` | Full clean: clean + remove `rendu/` & `trace/` workspaces |
| `help` | Show all available commands |
| `menu` | Return to the main menu |
| `exit` | Exit the exam shell |

### Example Usage

```
/> list
Exercises in rank02 > level0:
==================================================
  ○ 1. first_word
  ○ 2. fizzbuzz
  → 3. ft_putstr  ◄ current
  ○ 4. ft_strcpy
  ○ 5. ft_strlen
  ...
==================================================

/> choose
  Exercises in rank02 > level0
==================================================
    1. first_word
    2. fizzbuzz
  → 3. ft_putstr  ◄ current
    4. ft_strcpy
    5. ft_strlen
  ...
==================================================
  Enter number (1-12), name, or 'q' to cancel:
  /> 2
✔ Switched to: fizzbuzz

/> choose ft_strlen
✔ Switched to: ft_strlen

/> choose 5
✔ Switched to: ft_strlen

/> next
🔄 Next exercise: epur_str

/> test
Running tester.sh...
FAIL
Expected Output: "17"
Your Output:     "0"

/> cases
📊 Running ALL test cases for: ft_strlen
==================================================

── Test Case 1 ──
→ CASE PASSED

── Test Case 2 ──
FAIL
Expected Output: "17"
Your Output:     "0"
 CASE FAILED (checking next…)

── Test Case 3 ──
→ CASE PASSED

==================================================
✘ 1 test case(s) FAILED
Fix the errors and run 'test' or 'cases' again.

/> status
Session Status:
==================================================
  Rank:    rank02
  Level:   level0
  Current: ft_strlen
  Total:   12 exercises in this level
==================================================
```

## 💡 How to Use

1. Launch the application using `make` or `bash exam.sh`
2. Select your desired exam rank or practice option
3. Follow the on-screen instructions
4. Complete exercises in the automatically created `rendu` folder
5. Use `choose` (no args) for the numbered menu picker, or `choose <name>` / `choose <num>` to jump directly
6. Use `test` for a quick check (stops at first failure) or `cases` to see ALL failures at once
7. Use `clean` to remove compiled artifacts (.o, binaries, logs, test outputs) or `fclean` to wipe everything and start fresh
8. Use `analysis` to get AI-powered explanations of test failures
9. Use the practice environment to simulate real exam conditions

## 🤖 AI Analysis

The `analysis` command uses AI to analyze your test failures and code to explain:
- **WHAT** is wrong (specific error)
- **WHY** it fails (root cause)
- **HOW** to fix it (concrete code suggestions)

### Multi-Provider & Multi-Model Setup

Each AI provider has its own endpoint, API key, and **multiple models** with a **default model** selected. You can add multiple providers, each with multiple models, and switch between them.

A **default config** with pre-configured providers is created automatically on first run (`make`). Just set your API key to get started:

```
/> setai key gemini <your-api-key>
✔ API key saved for 'gemini'.

/> analysis
🤖 AI Analysis for: ft_strlen
...
```

Or add custom providers:

```
/> setai add openai https://api.openai.com/v1 sk-xxx gpt-4o-mini
✔ Provider 'openai' added and set as active.
  Model 'gpt-4o-mini' set as default for 'openai'.

/> setai addmodel openai gpt-4o
✔ Model 'gpt-4o' added to 'openai'.

/> setai addmodel openai gpt-4-turbo
✔ Model 'gpt-4-turbo' added to 'openai'.

/> setai add deepseek https://api.deepseek.com/v1 sk-yyy deepseek-chat
✔ Provider 'deepseek' added.

/> setai addmodel deepseek deepseek-reasoner
✔ Model 'deepseek-reasoner' added to 'deepseek'.

/> setai defaultmodel openai gpt-4o
✔ Default model for 'openai' set to 'gpt-4o'.

/> setai use deepseek
✔ Active provider set to: deepseek
  Default model: deepseek-chat

/> showai
🤖 AI Configuration
==================================================
  Config file: ~/.42examshell_ai.conf

  → [openai] ◄ active
    endpoint: https://api.openai.com/v1
    key:      sk-xxx12...5678
    models:
      ★ gpt-4o  ◄ default
        gpt-4o-mini
        gpt-4-turbo

    [deepseek]
    endpoint: https://api.deepseek.com/v1
    key:      sk-yyy34...9012
    models:
      ★ deepseek-chat  ◄ default
        deepseek-reasoner

    [gemini]
    endpoint: https://generativelanguage.googleapis.com/v1beta/openai
    key:      not set
    models:
      ★ gemini-2.0-flash  ◄ default
        gemini-2.5-flash
        gemini-2.5-pro

    [openrouter]
    endpoint: https://openrouter.ai/api/v1
    key:      not set
    models:
      ★ google/gemini-2.0-flash-001  ◄ default
        deepseek/deepseek-chat-v3-0324
        openai/gpt-4o-mini
        meta-llama/llama-4-maverick

==================================================
  Active: openai | Default model: gpt-4o
  Switch with: setai use <name>
```

### Commands

| Command | Description |
|---------|-------------|
| `setai add <name> <endpoint> [key] [model]` | Add a new provider (model becomes default) |
| `setai remove <name>` | Remove a provider |
| `setai use <name>` | Switch active provider |
| `setai key <name> <key>` | Set/change API key for a provider |
| `setai addmodel <name> <model>` | Add a model to a provider's model list |
| `setai rmodel <name> <model>` | Remove a model from a provider's model list |
| `setai defaultmodel <name> <model>` | Set the default model for a provider (adds if not in list) |
| `setai model <name> <model>` | Shortcut: adds model if new & sets as default |
| `setai endpoint <name> <url>` | Set/change endpoint for a provider |
| `showai` | Show all providers with model lists (★ = default) |

### Supported Providers (OpenAI-compatible)

| Provider | Endpoint | Popular Models |
|----------|----------|----------------|
| **Gemini** ⭐ | `https://generativelanguage.googleapis.com/v1beta/openai` | `gemini-2.0-flash`, `gemini-2.5-flash`, `gemini-2.5-pro` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini`, `gpt-4o`, `gpt-4-turbo` |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat`, `deepseek-reasoner` |
| OpenRouter | `https://openrouter.ai/api/v1` | Multi-model gateway (100+ models) |
| xAI/Grok | `https://api.x.ai/v1` | `grok-beta` |
| Mistral | `https://api.mistral.ai/v1` | `mistral-small`, `mistral-medium` |
| Together | `https://api.together.xyz/v1` | Open-source models (Llama, Mixtral, etc.) |
| Anthropic | `https://api.anthropic.com/v1` | `claude-3-haiku-20240307`, `claude-3-sonnet` |

> **⭐ Gemini is the default provider** — set your key with `setai key gemini <your-api-key>` and you're ready to go.

You can use any OpenAI-compatible provider — just give it a name and endpoint.

### Example Session

```
# Default config is created automatically on 'make' — just set your key:
/> setai key gemini AIzaSy...
✔ API key saved for 'gemini'.

/> showai
🤖 AI Configuration
==================================================
  Config file: ~/.42examshell_ai.conf

  → [gemini] ◄ active
    endpoint: https://generativelanguage.googleapis.com/v1beta/openai
    key:      AIzaSy...4321
    models:
      ★ gemini-2.0-flash  ◄ default
        gemini-2.5-flash
        gemini-2.5-pro

  [openai]
  endpoint: https://api.openai.com/v1
  key:      not set
  models:
    ★ gpt-4o-mini  ◄ default
      gpt-4o
      gpt-4-turbo

  [deepseek]
  ...

==================================================
  Active: gemini | Default model: gemini-2.0-flash

/> cases
📊 Running ALL test cases for: ft_strlen
...
✘ 3 failure(s) found

/> analysis
🤖 Sending to AI for analysis...
  Provider: gemini
  Endpoint: https://generativelanguage.googleapis.com/v1beta/openai
  Model:    gemini-2.0-flash (default)
==================================================
🤖 AI Analysis for: ft_strlen
==================================================
1. **WHAT**: Your ft_strlen returns 0 for all inputs
2. **WHY**: The while loop condition uses `*str` but never increments `str`
3. **HOW**: Add `str++` inside the loop:
   ```c
   int ft_strlen(char *str) {
       int len = 0;
       while (*str++)
           len++;
       return len;
   }
   ```
==================================================
```

### Config File

AI settings are stored in `~/.42examshell_ai.conf` with restricted permissions (600). A default config with providers is created automatically on `make`. You can edit it manually:

```ini
[openai]
endpoint=https://api.openai.com/v1
key=sk-abc123...
models=gpt-4o-mini gpt-4o gpt-4-turbo
default_model=gpt-4o-mini

[deepseek]
endpoint=https://api.deepseek.com/v1
key=sk-def456...
models=deepseek-chat deepseek-reasoner
default_model=deepseek-chat

[gemini]
endpoint=https://generativelanguage.googleapis.com/v1beta/openai
key=AIzaSy...
models=gemini-3.1-flash-lite gemini-2.5-flash
default_model=gemini-3.1-flash-lite

[openrouter]
endpoint=https://openrouter.ai/api/v1
key=sk-or-...
models=google/gemini-2.0-flash-001 deepseek/deepseek-chat-v3-0324 openai/gpt-4o-mini
default_model=google/gemini-2.0-flash-001

[active]
provider=gemini
```

- Each `[section]` is a provider with its own endpoint, key, and model list
- `models` is a space-separated list of available models
- `default_model` is the model used by the `analysis` command
- `[active]` determines which provider `analysis` uses
- Your API keys are never shared or committed
- You can add, remove, or edit providers and models directly in the file
- **Backward compatible**: old configs with `model=X` (singular) still work

## 📝 Workspace

The shell automatically creates a `rendu` folder where you can:
- Write your solutions
- Test your code
- Practice exam submissions

## 🔄 Staying Up-to-Date

The exam shell includes an automatic update mechanism:

```bash
# From the main menu, select option 8: Update Shell
# Or manually run:
bash update.sh
```

The update script will:
- ✅ Check for latest changes from the repository
- ✅ Display available updates before pulling
- ✅ Download and apply all updates automatically
- ✅ Update file permissions for test scripts
- ✅ Return you to the main menu when complete

Stay tuned for new exam ranks, improved testers, and additional features!

## 🔧 Maintenance & Updates

This fork is maintained by **aal-hawa** with enhanced functionality and regular updates. Key improvements include:

### Enhanced Commands
- **`list`**: Improved exercise listing with better formatting and current exercise indicator
- **`choose`**: Enhanced selection interface with number and name support, better error handling
- **`cases`**: Comprehensive test case runner with detailed output and failure analysis
- **`analysis`**: AI-powered error analysis — explains what's wrong, why, and how to fix it
- **`clean`**: More thorough cleanup of temporary files, binaries, and test outputs
- **`fclean`**: Complete workspace reset including `rendu/` and `trace/` directories

### Additional Features
- Multi-provider AI configuration with per-provider keys and models
- **Multi-model support**: Each provider can have multiple models with a default model selected
- Model management commands: `addmodel`, `rmodel`, `defaultmodel`
- Regular synchronization with the original repository
- Bug fixes and performance improvements
- Enhanced error handling and user feedback
- Updated practice materials and test cases
- AI analysis integration for smarter debugging

### Update Sources
You can update from either source:
- **Original repository**: `https://github.com/terminal-42s/42_examshell`
- **This fork**: `https://github.com/aal-hawa/42_examshell` (recommended for latest improvements)

For the most current features and improvements, always use the maintained fork.

## 🎯 Target Audience

This tool is designed for:
- 42 School students preparing for exams
- Anyone practicing C programming and system administration
- Students wanting to simulate exam conditions

## ⚙️ Requirements

- Bash shell
- Unix-like operating system (Linux/macOS)
- Terminal with color support (recommended)

## 📚 Exam Ranks Covered

- **Rank 02**: Fundamental C programming concepts
- **Rank 03**: Advanced C programming and system calls
- **Rank 04**: Complex algorithms and data structures
- **Rank 05**: Advanced C++ programming and object-oriented design
- **Rank 06**: Advanced system programming (mini_db, mini_serv)

## 🤝 Contributing

This is a practice tool for 42 School students. Contributions and improvements are welcome to enhance the learning experience.

## 📧 Support

For issues or questions regarding the practice environment, please refer to your 42 School resources or community.

---

**Good luck with your exams! 🍀**

*Made for 42 School students by 42 School students*
