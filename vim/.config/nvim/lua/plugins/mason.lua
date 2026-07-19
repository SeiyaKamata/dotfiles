return {
	"williamboman/mason.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("mason").setup({
			ensure_installed = {
				"stylua",
				"prettier",
				"black",
				"rubocop",
			},
		})
	end,
}
