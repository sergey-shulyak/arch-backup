# Neovim Configuration Guide

A modern, well-structured Neovim configuration for experienced Vim users featuring LSP integration, intelligent completion, Treesitter, Git integration, and more.

## Quick Start

### Prerequisites

Before using this configuration, ensure you have:

- **Neovim 0.10+** (tested with 0.11+)
- **Git** (for plugin installation)
- **Node.js** (required for TypeScript, JavaScript, and other node-based language servers)
- **C compiler** (gcc/clang for Treesitter parser compilation)
- **ripgrep** (optional but recommended for fast searching, used by Telescope)

### First-Time Setup

1. Backup your current configuration (if you have one):
   ```bash
   mv ~/.config/nvim ~/.config/nvim.backup
   ```

2. Clone or copy this configuration to `~/.config/nvim/`

3. Start Neovim:
   ```bash
   nvim
   ```

4. Lazy.nvim will automatically download and install all plugins on first launch.

5. Install language servers via Mason. Run:
   ```vim
   :Mason
   ```
   This opens an interactive UI where you can install language servers. The configuration pre-configures these servers:
   - `lua_ls` - Lua
   - `pyright` - Python
   - `ts_ls` - TypeScript/JavaScript
   - `rust_analyzer` - Rust

   You can install additional servers as needed for your projects.

6. After installing language servers, restart Neovim or run `:LspStart` to activate them.

## Plugin Overview

### Colorscheme & UI
- **catppuccin** - Beautiful, popular color scheme with excellent LSP support
- **lualine** - Lightweight, customizable status line

### Editing & Navigation
- **Comment.nvim** - Easy code commenting (gc, v:gc)
- **nvim-autopairs** - Auto-close brackets, quotes, etc.
- **Telescope** - Fuzzy finder for files, buffers, grep, and more
- **nvim-tree** - File explorer sidebar with icons

### Code Understanding & Intelligence
- **nvim-lspconfig** - Language Server Protocol integration (the core of code intelligence)
- **mason.nvim** - Interactive UI for installing language servers
- **mason-lspconfig** - Automatically configures LSP servers installed via Mason
- **fidget.nvim** - Nice UI for LSP progress notifications

### Completion & Snippets
- **nvim-cmp** - Best-in-class completion engine
- **cmp-nvim-lsp** - LSP completions
- **cmp-buffer** - Completions from buffer words
- **cmp-path** - File path completions
- **LuaSnip** - Snippet engine for code templates
- **friendly-snippets** - Pre-built snippets for many languages

### Code Highlighting & Syntax
- Built-in Neovim regex-based syntax highlighting (reliable and lightweight)
- LSP-based diagnostics and code intelligence

### Git Integration
- **gitsigns.nvim** - Git decorations (diff signs, blame), hunk operations
- **vim-fugitive** - Comprehensive Git wrapper for full workflow integration

---

## Keybindings Reference

### General Navigation & Editing (Existing)
| Key | Action |
|-----|--------|
| `<Space>` | Leader key |
| `<C-h/j/k/l>` | Navigate between splits |
| `<C-Left/Right/Up/Down>` | Resize splits |
| `<Tab>` / `<S-Tab>` | Indent/de-indent (visual mode) |
| `n` / `N` | Center search results when jumping |
| `jk` | Escape insert mode |
| `<Esc>` | Clear search highlights |
| `<C-s>` | Save file |
| `<Space>q` | Quit |

### File Explorer (nvim-tree)
| Key | Action |
|-----|--------|
| `<Space>e` | Toggle file explorer |
| `a` | Create new file/directory |
| `d` | Delete file/directory |
| `r` | Rename file |
| `c` | Copy file |
| `x` | Cut file |
| `p` | Paste file |
| `Enter` | Open file |
| `<C-v>` | Open file in vertical split |
| `<C-x>` | Open file in horizontal split |

### Telescope (Fuzzy Finder)
| Key | Action |
|-----|--------|
| `<Space>ff` | Find files |
| `<Space>fg` | Live grep (search text in files) |
| `<Space>fb` | Find open buffers |
| `<Space>fh` | Help tags |
| `<C-j/k>` | Navigate results |
| `<C-x/v>` | Open in split (when previewing) |
| `<Esc>` | Close picker |

### LSP (Language Server Protocol)
| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Go to references |
| `gi` | Go to implementation |
| `K` | Hover documentation |
| `<Space>ca` | Code actions |
| `<Space>rn` | Rename symbol |
| `[d` | Previous diagnostic |
| `]d` | Next diagnostic |
| `<Space>d` | Show diagnostic float (error details) |

### Completion
| Key | Action |
|-----|--------|
| `<C-Space>` | Trigger completion menu |
| `<Tab>` | Select next completion (or jump to next snippet placeholder) |
| `<S-Tab>` | Select previous completion |
| `<CR>` | Confirm selection |
| `<C-e>` | Close completion menu |
| `<C-b/f>` | Scroll completion documentation |

### Git (Gitsigns)
| Key | Action |
|-----|--------|
| `]c` | Next hunk (change) |
| `[c` | Previous hunk |
| `<Space>gp` | Preview hunk |
| `<Space>gs` | Stage hunk |
| `<Space>gr` | Reset hunk (discard changes) |
| `<Space>gS` | Stage entire buffer |
| `<Space>gu` | Undo stage hunk |
| `<Space>gR` | Reset entire buffer |
| `<Space>gb` | Toggle inline blame |
| `<Space>gd` | Show diff for current file |
| `<Space>gD` | Show diff against previous version |
| `ig` | Text object for hunk (visual/operator mode) |

### Comments
| Key | Action |
|-----|--------|
| `gc` | Toggle comment (normal or visual mode) |
| `gcc` | Toggle comment on current line |
| `gbc` | Toggle block comment |


---

## Common Workflows

### Navigating Code (LSP)

1. **Jump to definition:** Place cursor on a symbol and press `gd`
2. **See all references:** Press `gr` to find everywhere a symbol is used
3. **View function signature:** Press `K` to see documentation/signature
4. **View errors:** Press `[d` / `]d` to cycle through diagnostics, or `<Space>d` to see details
5. **Fix errors:** Press `<Space>ca` to see available code actions

### Finding Files & Text

1. **Quick file search:** `<Space>ff` opens fuzzy file finder
2. **Search project text:** `<Space>fg` to grep for text across files
3. **Switch buffers:** `<Space>fb` to find open files
4. **Full-text navigation:** Use Telescope's live grep to explore codebases

### Working with Git

1. **See changed lines:** Git signs automatically show in the left margin
   - `▎` = Added or changed line
   - `-` = Deleted line
2. **Stage changes:** Navigate to hunk with `]c`/`[c`, then `<Space>gs` to stage
3. **Commit changes:** `:Git commit` (via vim-fugitive)
4. **View blame:** `<Space>gb` to toggle inline blame
5. **Preview hunk:** `<Space>gp` to see what changed

### Code Completion

1. **In insert mode**, start typing and completion menu appears automatically
2. **Use `<Tab>`/`<S-Tab>`** to navigate suggestions
3. **Press `<CR>`** to accept a suggestion
4. **Use `<C-Space>`** to manually trigger completion if it doesn't appear
5. **Snippet placeholders:** After accepting a snippet, `<Tab>` jumps to next placeholder

### Editing with Text Objects

New syntax-aware text objects from Treesitter:
- `daf` - Delete entire function
- `vif` - Select function body
- `cac` - Change entire class
- `yab` - Yank entire block

### File Management

1. **Toggle explorer:** `<Space>e` opens/closes file sidebar
2. **Create file:** Press `a` in explorer, type filename with `.` for folders
3. **Delete file:** Navigate to file, press `d`
4. **Rename file:** Press `r` and edit name
5. **Open in split:** `<C-v>` for vertical, `<C-x>` for horizontal

---

## Adding Language Support

### Installing New LSP Servers

1. Open Mason UI:
   ```vim
   :Mason
   ```

2. Use `j/k` to navigate, press `i` to install a server

3. Popular servers to consider:
   - `gopls` - Go
   - `clangd` - C/C++
   - `vimls` - VimScript
   - `bashls` - Bash
   - `dockerls` - Dockerfile
   - `jsonls` - JSON
   - `yamlls` - YAML

4. After installation, the LSP will auto-attach to files of that language

### Checking LSP Status

View which language servers are active:
```vim
:LspInfo
```

This shows all attached servers for the current file.

### Uninstalling Servers

In Mason UI:
- Navigate to a server with `j/k`
- Press `d` to uninstall

---

## Customization

### Changing the Colorscheme

In `init.lua`, find the catppuccin config and change:
```lua
vim.cmd.colorscheme "catppuccin-mocha"
```

Other available variants:
- `catppuccin-latte` (light)
- `catppuccin-frappe` (dark blue)
- `catppuccin-macchiato` (medium dark)

### Adding More Keybindings

Edit `init.lua` and add new mappings in the Keybindings section:
```lua
map("n", "<Space>xx", ":YourCommand<CR>", opts)
```

### Adjusting Completion Behavior

Edit the nvim-cmp configuration in `init.lua` under "Completion: nvim-cmp":
- Change `sources` to add/remove completion sources
- Adjust `mapping` to modify keybindings

### Customizing LSP Servers

For language-specific LSP options, edit the `on_attach` function under "LSP: Neovim LSP config":
```lua
local function on_attach(client, bufnr)
  -- Add language-specific setup here
  if client.name == "pyright" then
    -- Python-specific configuration
  end
end
```

Or configure individual servers before the `mason_lspconfig.setup_handlers`:
```lua
lspconfig.rust_analyzer.setup({
  on_attach = on_attach,
  settings = {
    ["rust-analyzer"] = {
      checkOnSave = {
        command = "clippy"
      }
    }
  }
})
```

---

## Troubleshooting

### LSP Not Starting

1. Check if a server is installed:
   ```vim
   :Mason
   ```

2. Verify installation:
   ```vim
   :LspInfo
   ```

3. Try manually starting LSP:
   ```vim
   :LspStart
   ```

4. Check error messages:
   ```vim
   :messages
   ```

### Completion Not Working

1. Verify LSP is running (`:LspInfo`)
2. In insert mode, press `<C-Space>` to manually trigger
3. Check that you're in a file with an associated language server

### Treesitter Parser Not Installing

If you see "no parser" errors:
```vim
:TSInstall <language>
```

For example: `:TSInstall python` or `:TSInstall javascript`

### Performance Issues

If Neovim feels slow:
1. Check installed LSP servers (some are heavy): `:Mason`
2. Consider lazy-loading plugins by removing `lazy = false` from plugin specs
3. Disable Treesitter highlighting if needed (set `enable = false` in treesitter config)

### Conflicting Keybindings

If a keybinding doesn't work:
1. Check if another plugin is using it: `:verbose map <key>`
2. Edit `init.lua` to change the binding to something else

### Custom Colors Not Applying

If `nvim-colors.lua` overrides aren't working:
1. Verify the file has a `setup()` function
2. Check that the autocmd at the bottom of `init.lua` is present
3. Adjust highlight group names to match your Treesitter groups

---

## Tips for Experienced Vim Users

### Switching to LSP from Tags/Ctags

- `gd` (LSP) works everywhere, not just in tags file
- `gr` (references) is more comprehensive than `:ts` followed by `:tselect`
- Use `K` for hover instead of looking up docs manually

### Extending Vim Motions with Treesitter

- Treesitter text objects extend Vim's power: `daf` now respects language syntax
- Combine with existing motions: `2daf` deletes 2 functions
- Mix with visual mode: `vifp` selects function and pipes it

### Git Workflow Integration

- Stage/reset hunks without leaving Neovim: `<Space>gs` / `<Space>gr`
- Avoid switching to git CLI for common operations
- `:Git` gives you full Fugitive power when needed

### Smart Project Navigation

- Use Telescope's `live_grep` (`<Space>fg`) like `grep -r` but faster
- `<Space>ff` for file search without remembering structure
- Combine with `gd` to understand code relationships

---

## Additional Resources

- **Neovim Documentation:** `:help nvim`
- **LSP Documentation:** `:help lsp`
- **Plugin Documentation:** Use `:help <plugin-name>` after a plugin is loaded
- **Neovim Repository:** https://github.com/neovim/neovim
- **Mason Repository:** https://github.com/williamboman/mason.nvim

---

## File Structure

```
~/.config/nvim/
├── init.lua                    # Main configuration
├── lazy-lock.json              # Plugin versions (auto-managed by lazy.nvim)
├── README.md                   # This file
└── lua/
    └── nvim-colors.lua         # Custom color overrides
```

---

## Updating Plugins

To update all plugins:
```vim
:Lazy update
```

Or update specific plugins in the Lazy UI:
```vim
:Lazy
```

Press `u` to update a plugin, `x` to rollback.

---

## Performance Notes

- **Startup time:** Should be < 200ms with all plugins
- **Syntax highlighting:** Treesitter is faster than Vim's default regex-based approach
- **Completion:** Instant with LSP + nvim-cmp
- **File explorer:** Efficient with nvim-tree
- **Git operations:** Fast with gitsigns (checks only modified files)

If you experience slowness, check `:Lazy` for any plugins taking too long to load.

---

Happy coding!
