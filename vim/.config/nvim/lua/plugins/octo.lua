return {
	"pwntester/octo.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	cmd = "Octo",
	keys = {
		{ "<leader>op", "<cmd>Octo pr list<cr>", desc = "GitHub: PR 一覧" },
		{ "<leader>oo", "<cmd>Octo pr search is:pr is:open author:@me<cr>", desc = "GitHub: 自分の open PR" },
		{ "<leader>or", "<cmd>Octo review start<cr>", desc = "GitHub: PR レビュー開始" },
		{ "<leader>oR", "<cmd>Octo review resume<cr>", desc = "GitHub: PR レビュー再開" },
		{ "<leader>oi", "<cmd>Octo issue list<cr>", desc = "GitHub: Issue 一覧" },
		{ "<leader>oc", "<cmd>Octo pr changes<cr>", desc = "GitHub: PR の変更ファイル" },
	},
	config = function()
		require("octo").setup({
			picker = "telescope",
			-- カーソル下のコメントスレッドを表示（コメント確認用）
			default_to_projects_v2 = false,
		})
	end,
}
