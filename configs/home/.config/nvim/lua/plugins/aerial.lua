return {
  {
    "stevearc/aerial.nvim",
    opts = {
      -- You can customize these options:
      backends = { "treesitter", "lsp", "markdown", "man" },
      -- Disable line limit so it works on large files
      disable_max_lines = false,
      layout = {
        -- Enum: persist, retain, toggle
        max_width = { 40, 0.1 },
        width = 40,
        min_width = 10,
        -- window-local options. See :help window_options
        win_opts = {
          winblend = 10,
        },
      },
      show_guides = true,
      filter_kind = false,
      -- Keymaps in aerial window
      keymaps = {
        ["?"] = "actions.show_help",
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.jump",
        ["<2-LeftMouse>"] = "actions.jump",
        ["-"] = "actions.close",
        ["gg"] = "actions.scroll",
        ["<C-j>"] = "actions.scroll",
        ["<C-k>"] = "actions.scroll",
        ["{"] = "actions.prev",
        ["}"] = "actions.next",
        ["[["] = "actions.prev_up",
        ["]]"] = "actions.next_up",
      },
    },
  },
}
