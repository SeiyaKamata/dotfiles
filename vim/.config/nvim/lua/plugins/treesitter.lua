return {
	"nvim-treesitter/nvim-treesitter",
  branch = "main",
	build = ":TSUpdate",
	event = "BufReadPre",
	config = function()
		require("nvim-treesitter.configs").setup({
			ensure_installed = { "lua", "python", "javascript" },
			highlight = { enable = true },
			auto_install = true,
			indent = { enable = true },
		})
	end,
}
