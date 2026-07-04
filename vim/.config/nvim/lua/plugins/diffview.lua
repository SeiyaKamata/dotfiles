return {
	"sindrets/diffview.nvim",
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen HEAD~1<cr>", desc = "直前のコミットとの差分を表示" },
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "現在のファイルの変更履歴を表示" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "リポジトリ全体の変更履歴を表示" },
		{ "<leader>gv", "<cmd>DiffviewFileHistory --range=origin/HEAD...HEAD --right-only --no-merges<cr>", desc = "ローカルでPRをコミットごとにレビュー" },
	},

  config = function()
    require("diffview").setup({
      hooks = {
        diff_buf_read = function(bufnr)
          vim.opt_local.foldenable = false
        end,
      },
    })
  end,
}
