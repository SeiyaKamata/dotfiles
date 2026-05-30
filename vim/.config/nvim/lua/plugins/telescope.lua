return {
	"nvim-telescope/telescope.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		require("telescope").setup({
			defaults = {
				prompt_prefix = "❯ ",
				selection_caret = "❯ ",
				path_display = { "truncate" },
			},
			pickers = {
				find_files = { find_command = { "fd", "--type", "f" } },
			},
		})

		local builtin = require("telescope.builtin")
		local map = vim.keymap.set

		local function find_files_all()
			builtin.find_files({ hidden = true, no_ignore = true })
		end
		local function live_grep_all()
			builtin.live_grep({ additional_args = { "--hidden", "--no-ignore" } })
		end

		map("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
		map("n", "<leader>fb", function() builtin.buffers({ initial_mode = "normal" }) end, { desc = "Find buffers" })
		map("n", "<leader>fg", builtin.live_grep,   { desc = "Live grep" })
		map("n", "<leader>fF", find_files_all,      { desc = "Find files (all)" })
		map("n", "<leader>fG", live_grep_all,        { desc = "Live grep (all)" })
	end,
}
