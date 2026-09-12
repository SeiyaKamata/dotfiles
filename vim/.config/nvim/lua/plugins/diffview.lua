return {
	"sindrets/diffview.nvim",
	keys = {
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "現在のファイルの変更履歴を表示" },
		{ "<leader>gv", "<cmd>DiffviewFileHistory --range=origin/HEAD...HEAD --right-only --no-merges<cr>", desc = "ローカルでPRをコミットごとにレビュー" },
	},

  config = function()
    local actions = require("diffview.actions")

    -- diffview本体のselect_entry実装（file_history/listeners.lua）と同じ判定を使う：
    -- カーソル位置の項目が LogEntry（item.files あり）かつ複数コミットのパネル
    -- （panel.single_file == false）なら、select_entryはfold開閉だけでファイルは
    -- 開かれない。それ以外（FileEntryの選択、または単一ファイル履歴のコミット選択）
    -- は実際にファイルが開かれるので、その時だけパネルを閉じる。
    local function select_and_close()
      local will_open = true
      local ok, view = pcall(function() return require("diffview.lib").get_current_view() end)
      if ok and view and view.panel and view.panel.get_item_at_cursor then
        local ok2, item = pcall(function() return view.panel:get_item_at_cursor() end)
        if ok2 and item and item.files and not view.panel.single_file then
          will_open = false
        end
      end
      actions.select_entry()
      if will_open then
        actions.toggle_files()
      end
    end

    require("diffview").setup({
      hooks = {
        diff_buf_read = function(bufnr)
          vim.opt_local.foldenable = false
          vim.opt_local.wrap = true
        end,
      },
      keymaps = {
        -- パネルの開閉キーを <leader>b から <leader>e に変更
        view = {
          { "n", "<leader>b", false },
          { "n", "<leader>e", actions.toggle_files, { desc = "Toggle the file panel." } },
        },
        -- コミットを選択したら、その場でパネルを閉じてdiffペインを広く使う
        file_history_panel = {
          { "n", "<cr>", select_and_close, { desc = "選択したコミットのdiffを開き、パネルを閉じる" } },
          { "n", "o",    select_and_close, { desc = "選択したコミットのdiffを開き、パネルを閉じる" } },
          { "n", "l",    select_and_close, { desc = "選択したコミットのdiffを開き、パネルを閉じる" } },
          { "n", "<leader>b", false },
          { "n", "<leader>e", actions.toggle_files, { desc = "Toggle the file panel" } },
        },
      },
    })
  end,
}
