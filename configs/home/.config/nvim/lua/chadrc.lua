-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "chocolate",
	transparency = false,

	hl_override = {
		Normal = { bg = "NONE" },
		NormalNC = { bg = "NONE" },
		NormalFloat = { bg = "NONE" },
		FloatBorder = {},
		TelescopeNormal = { bg = "NONE" },
		TelescopePromptNormal = { bg = "NONE" },
		TelescopePreviewNormal = { bg = "NONE" },
		TelescopeResultsNormal = { bg = "NONE" },
	},
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }

return M
