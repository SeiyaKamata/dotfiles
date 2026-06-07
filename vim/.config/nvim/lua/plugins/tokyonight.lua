return {
	"folke/tokyonight.nvim",
	lazy = false, -- 起動時にロード
	priority = 1000,
	config = function()
		require("tokyonight").setup({
			on_highlights = function(hl, c)
				hl.FugitiveBg = { bg = "#24283b" }
			end,
		})
		vim.cmd("colorscheme tokyonight-night")
	end,
}
