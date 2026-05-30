return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPre",
	config = function()
		require("gitsigns").setup({
			signs = {
				change = { text = "┃" },
				changedelete = { text = "┃" },
			},
			on_attach = function(bufnr)
				local gs = package.loaded.gitsigns

				vim.keymap.set("n", "<leader>h", function()
					gs.toggle_deleted()
					gs.toggle_word_diff()
					gs.toggle_linehl()
				end, { buffer = bufnr, desc = "Toggle GitHub-style diff view", silent = true })
			end,
		})

		local function apply_highlights()
			local add_bg = "#143020"
			local add_word_bg = "#1a4d2e"
			local del_bg = "#3d1b1b"
			local del_word_bg = "#6b2828"
			local green_fg = "#7ee787"
			local red_fg = "#f85149"

			vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = green_fg })
			vim.api.nvim_set_hl(0, "GitSignsChange", { fg = green_fg })
			vim.api.nvim_set_hl(0, "GitSignsChangedelete", { fg = green_fg })
			vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = red_fg })
			vim.api.nvim_set_hl(0, "GitSignsTopdelete", { fg = red_fg })

			vim.api.nvim_set_hl(0, "GitSignsAddLn", { bg = add_bg })
			vim.api.nvim_set_hl(0, "GitSignsChangeLn", { bg = add_bg })
			vim.api.nvim_set_hl(0, "GitSignsChangedeleteLn", { bg = add_bg })

			vim.api.nvim_set_hl(0, "GitSignsDeleteVirtLn", { bg = del_bg })
			vim.api.nvim_set_hl(0, "GitSignsDeleteVirtLnInLine", { bg = del_word_bg })
			vim.api.nvim_set_hl(0, "GitSignsDeleteVirtLnInline", { bg = del_word_bg })

			vim.api.nvim_set_hl(0, "GitSignsAddInline", { bg = add_word_bg })
			vim.api.nvim_set_hl(0, "GitSignsChangeInline", { bg = add_word_bg })
			vim.api.nvim_set_hl(0, "GitSignsDeleteInline", { bg = del_word_bg })

			vim.api.nvim_set_hl(0, "GitSignsAddLnInline", { bg = add_word_bg })
			vim.api.nvim_set_hl(0, "GitSignsChangeLnInline", { bg = add_word_bg })
			vim.api.nvim_set_hl(0, "GitSignsDeleteLnInline", { bg = del_word_bg })
		end
		apply_highlights()
		vim.api.nvim_create_autocmd("ColorScheme", {
			callback = apply_highlights,
		})
	end,
}
