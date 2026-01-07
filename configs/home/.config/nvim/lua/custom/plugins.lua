return {
  {
    "stevearc/aerial.nvim",
    opts = {
      placement = "window",
      layout = {
        width = 30,
        default_direction = "right",
      },
      show_guides = true,
      filter_kind = false,
    },
    keys = {
      { "<leader>o", "<cmd>AerialToggle<CR>", desc = "Toggle outline" },
      { "<leader>O", "<cmd>AerialOpen<CR>", desc = "Open outline" },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = require "configs.treesitter",
  },

  {
    "williamboman/mason.nvim",
    opts = require "configs.mason",
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      search = {
        multi_window = true,
        forward = true,
        wrap = true,
      },
    },
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash",
      },
      {
        "S",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter",
      },
    },
  },
}
