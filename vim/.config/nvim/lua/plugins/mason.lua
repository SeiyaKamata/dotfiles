return {
	"williamboman/mason.nvim",
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
