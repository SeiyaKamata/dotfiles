return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("nvim-tree").setup {
      view = {
        width = 30,
        side = "left", -- 左側に表示
      },
      renderer = {
        icons = {
          show = {
            git = true,    -- Git 状態アイコンを表示
            folder = true, -- フォルダアイコンを表示
            file = true,   -- ファイルアイコンを表示
          },
        },
        group_empty = true, -- 空フォルダをまとめて表示
      },
      filters = {
        dotfiles = false, -- ドットファイルを表示する（true にすると非表示）
        custom ={
          "config.code%-workspace", -- ← このファイルを非表示に
          ".git",                   -- .git フォルダを非表示に
          "node_modules",
          "*.code-workspace",
        }
      },
      git = {
        enable = true, -- Git 連携を有効化
      },
    }

    -- キーマップ設定
    vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true, desc = "Toggle file explorer" })
    vim.keymap.set("n", "<leader>o", ":NvimTreeFocus<CR>", { silent = true, desc = "Focus file explorer" })
  end,
}
