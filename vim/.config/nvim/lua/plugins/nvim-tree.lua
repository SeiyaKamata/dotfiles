return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	keys = {
		{ "<leader>e", desc = "Toggle file tree" },
	},
	cmd = { "NvimTreeOpen", "NvimTreeToggle", "NvimTreeFocus", "NvimTreeClose" },
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
				dotfiles = true,
				git_clean = false,
			},
			git = { enable = true },
			update_focused_file = { enable = true },
			on_attach = function(bufnr)
				local api = require("nvim-tree.api")
				api.config.mappings.default_on_attach(bufnr)
				local opts = { buffer = bufnr, noremap = true, silent = true, nowait = true }
				vim.keymap.set("n", "l", api.node.open.edit, opts)
				vim.keymap.set("n", "h", api.node.navigate.parent_close, opts)
				vim.keymap.set("n", "<CR>", function()
					local node = api.tree.get_node_under_cursor()
					if not node then
						return
					end
					if node.type == "directory" then
						vim.fn.setreg('"', node.name)
						vim.fn.setreg("+", node.name)
						local relpath = vim.fn.fnamemodify(node.absolute_path, ":.")
						local feature = relpath:match("^%.specs/([^/]+)$")
						if feature then
							local path = vim.fn.getcwd() .. "/.target_feature"
							local f = io.open(path, "w")
							if f then
								f:write(feature .. "\n")
								f:close()
							end
						end
					else
						local relpath = vim.fn.fnamemodify(node.absolute_path, ":.")
						vim.fn.setreg('"', relpath)
						vim.fn.setreg("+", relpath)
					end
					vim.cmd("quit")
				end, opts)
			end,
		})

		vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>",
			{ noremap = true, silent = true, desc = "Toggle file tree" })
	end,
}
