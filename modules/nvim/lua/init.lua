-- Neovim configuration
-- You can write Lua code here just like normal Neovim

-- Options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.showmode = false -- Shown by lualine instead

-- Transparent background (apply after colorscheme loads)
local function set_transparent_bg()
  vim.api.nvim_set_hl(0, "Normal", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "NormalNC", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "LineNr", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "Folded", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "FoldColumn", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "VertSplit", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "StatusLine", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "NONE", ctermbg = "NONE" })
end

-- Apply transparency on colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = set_transparent_bg,
})

-- Apply transparency on VimEnter (after plugins load)
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(set_transparent_bg, 100)
  end,
})

-- Spell checking
vim.opt.spell = true
vim.opt.spelllang = "en_us"
vim.opt.spelloptions:append("camel")
vim.api.nvim_set_hl(0, "SpellBad", { undercurl = false, underline = true, sp = '#777777' }) -- undercurl to underline


-- OSC 52 clipboard support (for remote/container environments)
vim.g.clipboard = {
	name = "OSC 52",
	copy = {
		["+"] = require("vim.ui.clipboard.osc52").copy("+"),
		["*"] = require("vim.ui.clipboard.osc52").copy("*"),
	},
	paste = {
		["+"] = require("vim.ui.clipboard.osc52").paste("+"),
		["*"] = require("vim.ui.clipboard.osc52").paste("*"),
	},
}

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Telescope keymaps
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Buffers" })
vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help tags" })
vim.keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Recent files" })
vim.keymap.set("n", "<leader>fd", "<cmd>Telescope diagnostics<cr>", { desc = "Diagnostics" })

-- Buffer navigation
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
vim.keymap.set("n", "<leader>bp", "<cmd>BufferLinePick<cr>", { desc = "Pick buffer" })

-- Window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Resize windows
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Git keymaps (gitsigns)
vim.keymap.set("n", "<leader>gb", "<cmd>Gitsigns blame_line<cr>", { desc = "Git blame line" })
vim.keymap.set("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
vim.keymap.set("n", "<leader>gr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset hunk" })
vim.keymap.set("n", "]h", "<cmd>Gitsigns next_hunk<cr>", { desc = "Next hunk" })
vim.keymap.set("n", "[h", "<cmd>Gitsigns prev_hunk<cr>", { desc = "Previous hunk" })

-- Better escape
vim.keymap.set("i", "jk", "<Esc>", { desc = "Escape" })
vim.keymap.set("i", "jj", "<Esc>", { desc = "Escape" })

-- Move lines
vim.keymap.set("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move line up" })

-- Clear search highlight
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Messages and notifications
vim.keymap.set("n", "<leader>nm", "<cmd>messages<cr>", { desc = "Show messages" })
vim.keymap.set("n", "<leader>nh", "<cmd>Noice history<cr>", { desc = "Noice history" })
vim.keymap.set("n", "<leader>nl", "<cmd>Noice last<cr>", { desc = "Noice last message" })
vim.keymap.set("n", "<leader>nn", "<cmd>Notifications<cr>", { desc = "Show notifications" })
vim.keymap.set("n", "<leader>nc", function()
	local messages = vim.fn.execute("messages")
	vim.fn.setreg("+", messages)
	vim.notify("Messages copied to clipboard!", vim.log.levels.INFO)
end, { desc = "Copy messages to clipboard" })

-- show error detail when the cursor is hovering
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end,
})

-- Copy current file path to clipboard
vim.keymap.set("n", "<leader>cp", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path, vim.log.levels.INFO)
end, { desc = "Copy absolute path" })

vim.keymap.set("n", "<leader>cr", function()
  local path = vim.fn.expand("%")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path, vim.log.levels.INFO)
end, { desc = "Copy relative path" })

vim.keymap.set("n", "<leader>cf", function()
  local path = vim.fn.expand("%:t")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path, vim.log.levels.INFO)
end, { desc = "Copy filename" })
