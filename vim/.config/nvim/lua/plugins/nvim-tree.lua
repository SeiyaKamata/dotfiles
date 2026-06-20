return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("nvim-tree").setup({
			view = {
				width = 40,
				float = {
					enable = true,
					open_win_config = function()
						local screen_w = vim.opt.columns:get()
						local screen_h = vim.opt.lines:get() - vim.opt.cmdheight:get()
						local window_w = math.floor(screen_w * 0.4)
						local window_h = math.floor(screen_h * 0.8)
						return {
							border = "rounded",
							relative = "editor",
							row = math.floor((screen_h - window_h) / 2),
							col = math.floor((screen_w - window_w) / 2),
							width = window_w,
							height = window_h,
						}
					end,
				},
			},
			renderer = {
				group_empty = true,
				icons = { show = { git = true, folder = true, file = true } },
			},
			filters = {
				dotfiles = false,
				git_clean = false,
				exclude = {
					"specs",
				},
			},
			git = { enable = true },
			on_attach = function(bufnr)
				local api = require("nvim-tree.api")
				api.config.mappings.default_on_attach(bufnr)
				local opts = { buffer = bufnr, noremap = true, silent = true, nowait = true }
				vim.keymap.set("n", "l", api.node.open.edit, opts)
				vim.keymap.set("n", "h", api.node.navigate.parent_close, opts)
			end,
		})

		vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>",
			{ noremap = true, silent = true, desc = "Toggle file tree" })
	end,
}
