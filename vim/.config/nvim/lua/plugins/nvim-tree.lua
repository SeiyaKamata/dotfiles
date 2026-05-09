return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("nvim-tree").setup({
			view = { width = 30 },
			renderer = {
				group_empty = true,
				icons = { show = { git = true, folder = true, file = true } },
			},
			filters = { dotfiles = false, git_clean = false },
			git = { enable = true },
		})

		vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>",
			{ noremap = true, silent = true, desc = "Toggle file tree" })
	end,
}
