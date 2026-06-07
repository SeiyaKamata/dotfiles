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

-- tmux の conf ファイルを tmux filetype として認識
vim.filetype.add({
	pattern = {
		[".*/tmux/.*%.conf"] = "tmux",
	},
})

-- 大きいファイル（1MB以上）はundo無効化
vim.api.nvim_create_autocmd("BufReadPre", {
	callback = function()
		local ok, stat = pcall(vim.uv.fs_stat, vim.fn.expand("<afile>"))
		if ok and stat and stat.size > 1024 * 1024 then
			vim.opt_local.undofile = false
			vim.opt_local.foldmethod = "manual"
		end
	end,
})
