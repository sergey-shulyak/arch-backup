-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Apply hyprstyle colors after plugins and colorscheme load
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if pcall(require, "nvim-colors") then
      require("nvim-colors").setup()
    end
  end,
})
