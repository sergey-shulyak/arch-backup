require("nvchad.configs.lspconfig").defaults()

local servers = {
  "ts_ls",              -- TypeScript/JavaScript
  "ruby_lsp",           -- Ruby/Rails
  "pyright",            -- Python
  "bash_ls",            -- Bash
  "html",               -- HTML
  "cssls",              -- CSS
}

for _, server in ipairs(servers) do
  vim.lsp.config(server, {})
end

vim.lsp.enable(servers)

-- read :h lspconfig-nvim-0.11 for changing options of lsp servers 
