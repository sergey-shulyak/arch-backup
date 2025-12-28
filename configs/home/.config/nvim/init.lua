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
  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    config = function()
      require("lualine").setup()
    end,
  },

  -- Comment
  {
    "numToStr/Comment.nvim",
    lazy = false,
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
    lazy = false,
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local telescope = require("telescope.builtin")
      map("n", "<leader>ff", telescope.find_files, opts)
      map("n", "<Leader>fg", telescope.live_grep, opts)
      map("n", "<Leader>fb", telescope.buffers, opts)
      map("n", "<Leader>fh", telescope.help_tags, opts)
    end,
  },

  -- File icons
  {
    "nvim-tree/nvim-web-devicons",
    lazy = false,
  },

  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 30,
        },
        renderer = {
          icons = {
            show = {
              file = true,
              folder = true,
            },
          },
        },
      })
      map("n", "<leader>e", ":NvimTreeToggle<CR>", opts)
    end,
  },


  -- LSP: Mason (LSP installer)
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup()
    end,
  },

  -- LSP: nvim-lspconfig (configuration data + utilities)
  {
    "neovim/nvim-lspconfig",
    lazy = false,
  },

  -- LSP: Mason LSP config bridge (auto-enables installed servers)
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "pyright", "ts_ls", "rust_analyzer" },
        automatic_enable = true,
      })

      -- Setup keybindings for all LSP servers
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufnr = args.buf
          local bufopts = { noremap = true, silent = true, buffer = bufnr }
          map("n", "gd", vim.lsp.buf.definition, bufopts)
          map("n", "gD", vim.lsp.buf.declaration, bufopts)
          map("n", "gr", vim.lsp.buf.references, bufopts)
          map("n", "gi", vim.lsp.buf.implementation, bufopts)
          map("n", "K", vim.lsp.buf.hover, bufopts)
          map("n", "<leader>ca", vim.lsp.buf.code_action, bufopts)
          map("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
          map("n", "[d", vim.diagnostic.goto_prev, bufopts)
          map("n", "]d", vim.diagnostic.goto_next, bufopts)
          map("n", "<leader>d", vim.diagnostic.open_float, bufopts)
        end,
      })
    end,
  },

  -- LSP: Fidget (progress UI)
  {
    "j-hui/fidget.nvim",
    lazy = false,
    config = function()
      require("fidget").setup({})
    end,
  },

  -- Completion: nvim-cmp
  {
    "hrsh7th/nvim-cmp",
    lazy = false,
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },

  -- Git: Gitsigns
  {
    "lewis6991/gitsigns.nvim",
    lazy = false,
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "▎" },
          change = { text = "▎" },
          delete = { text = "" },
          topdelete = { text = "" },
          changedelete = { text = "▎" },
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function map_gitsigns(mode, lhs, rhs)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true })
          end

          -- Navigation
          map_gitsigns("n", "]c", function()
            if vim.wo.diff then return "]c" end
            vim.schedule(function() gs.next_hunk() end)
            return "<Ignore>"
          end, { expr = true })
          map_gitsigns("n", "[c", function()
            if vim.wo.diff then return "[c" end
            vim.schedule(function() gs.prev_hunk() end)
            return "<Ignore>"
          end, { expr = true })

          -- Actions
          map_gitsigns("n", "<leader>gs", gs.stage_hunk)
          map_gitsigns("n", "<leader>gr", gs.reset_hunk)
          map_gitsigns("n", "<leader>gS", gs.stage_buffer)
          map_gitsigns("n", "<leader>gu", gs.undo_stage_hunk)
          map_gitsigns("n", "<leader>gR", gs.reset_buffer)
          map_gitsigns("n", "<leader>gp", gs.preview_hunk)
          map_gitsigns("n", "<leader>gb", gs.toggle_current_line_blame)
          map_gitsigns("n", "<leader>gd", gs.diffthis)
          map_gitsigns("n", "<leader>gD", function() gs.diffthis("~") end)

          -- Text objects
          map_gitsigns({ "o", "x" }, "ig", ":<C-U>Gitsigns select_hunk<CR>")
        end,
      })
    end,
  },

  -- Git: Fugitive
  {
    "tpope/vim-fugitive",
    lazy = false,
  },
}, {
  defaults = { lazy = true },
})

-- Apply hyprstyle colors after plugins and colorscheme load
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if pcall(require, "nvim-colors") then
      require("nvim-colors").setup()
    end
  end,
})
