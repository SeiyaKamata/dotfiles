local opt = vim.opt

-- 表示系
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.wrap = false
-- opt.winbar = "%=%f"
opt.title = true
opt.synmaxcol = 320 -- 長行のシンタックスハイライトを打ち切りパフォーマンス改善
opt.showmode = false
opt.cmdheight = 0

-- インデント系
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- 検索系
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.inccommand = "split"

-- 操作性
opt.scrolloff = 8
opt.splitbelow = true
opt.splitright = true
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 500
opt.jumpoptions = "view"
opt.swapfile = false

-- 補完
opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumheight = 10

-- clipboard
opt.clipboard = "unnamedplus"

-- SSH 経由 (herdr --remote 含む) は xclip/wl-copy 等が無いため OSC52 でホスト側クリップボードへ転送する
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
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
end

-- diff 系
opt.diffopt:append({ "linematch:60", "algorithm:histogram", "indent-heuristic" })

-- diff ハイライトの彩度を落とす
local function dim_diff()
  vim.api.nvim_set_hl(0, "DiffAdd",    { bg = "#1e3a2a" })  -- 追加: 暗めの緑
  vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#3a1e24", fg = "#3a1e24" })  -- 埋め行: 暗めの赤＋斜線を埋没
  vim.api.nvim_set_hl(0, "DiffChange", { bg = "#2a2a3a" })  -- 変更行: 控えめ
  vim.api.nvim_set_hl(0, "DiffText",   { bg = "#3a3a5a", bold = true })  -- 変更語: ここだけ目立たせる
end

dim_diff()

-- colorscheme 読み込みで上書きされないよう再適用
vim.api.nvim_create_autocmd("ColorScheme", { callback = dim_diff })

-- tmux の conf ファイルを tmux filetype として認識
vim.filetype.add({
	pattern = {
		[".*/tmux/.*%.conf"] = "tmux",
	},
})

-- 大きいファイル（1MB以上）はundo無効化・大ファイルフラグを立てる
vim.api.nvim_create_autocmd("BufReadPre", {
	callback = function(ev)
		local ok, stat = pcall(vim.uv.fs_stat, vim.fn.expand("<afile>"))
		if ok and stat and stat.size > 1024 * 1024 then
			vim.opt_local.undofile = false
			vim.opt_local.foldmethod = "manual"
			vim.b[ev.buf].large_file = true
		end
	end,
})

-- 長い行（10000文字以上）を含むバッファも大ファイルとして扱う
vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function(ev)
		if vim.b[ev.buf].large_file then return end
		local has_long = vim.api.nvim_buf_call(ev.buf, function()
			return vim.fn.search([[\%>10000v.]], "n", 0, 0) > 0
		end)
		if has_long then
			vim.b[ev.buf].large_file = true
			pcall(function() require("ibl").setup_buffer(ev.buf, { enabled = false }) end)
		end
	end,
})
