-- Minimal Neovim Config (Neovim 0.11+)

-- Leader key
vim.g.mapleader = " "

-- Settings
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true
opt.wrap = false
opt.cursorline = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.scrolloff = 8
opt.cmdheight = 1
opt.updatetime = 300

-- Keybindings
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Navigation
map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-j>", "<C-w>j", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-l>", "<C-w>l", opts)

-- Window resize
map("n", "<C-Left>", ":vertical resize -5<CR>", opts)
map("n", "<C-Right>", ":vertical resize +5<CR>", opts)
map("n", "<C-Up>", ":resize +5<CR>", opts)
map("n", "<C-Down>", ":resize -5<CR>", opts)

-- Indenting
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)

-- Better search
map("n", "n", "nzzzv", opts)
map("n", "N", "Nzzzv", opts)

-- Esc
map("i", "jk", "<Esc>", opts)

-- Clear highlights
map("n", "<Esc>", ":nohlsearch<CR>", opts)

-- Save
map("n", "<C-s>", ":w<CR>", opts)
map("i", "<C-s>", "<Esc>:w<CR>", opts)

-- Quick quit
map("n", "<Leader>q", ":q<CR>", opts)

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugins
require("lazy").setup({
  -- Colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    config = function()
      vim.cmd.colorscheme "catppuccin-mocha"
      -- Disable background
      vim.cmd([[highlight Normal ctermbg=NONE guibg=NONE]])
      vim.cmd([[highlight NormalNC ctermbg=NONE guibg=NONE]])
      vim.cmd([[highlight EndOfBuffer ctermbg=NONE guibg=NONE]])
    end,
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    config = function()
      require("lualine").setup({
        options = { theme = "catppuccin" },
      })
    end,
  },

  -- Comment
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup()
    end,
  },

  -- Telescope (fuzzy finder)
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local telescope = require("telescope.builtin")
      map("n", "<Leader>ff", telescope.find_files, opts)
      map("n", "<Leader>fg", telescope.live_grep, opts)
      map("n", "<Leader>fb", telescope.buffers, opts)
      map("n", "<Leader>fh", telescope.help_tags, opts)
    end,
  },
}, {
  defaults = { lazy = true },
})
