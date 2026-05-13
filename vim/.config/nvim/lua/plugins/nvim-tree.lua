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
    
    		-- 最後のウィンドウが nvim-tree なら自動で閉じる
		vim.api.nvim_create_autocmd("BufEnter", {
			nested = true,
			callback = function()
				if #vim.api.nvim_list_wins() == 1
					and vim.bo.filetype == "NvimTree" then
					vim.cmd("quit")
				end
			end,
		})
	end,
}
