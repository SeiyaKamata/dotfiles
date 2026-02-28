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
        git_clean = false,
        custom ={
        }
      },
      git = {
        enable = true, -- Git 連携を有効化
      },
    }


    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    -- key map
    map("n", "<leader>et", ":NvimTreeToggle<CR>", opts)
    map("n", "<leader>eo", ":NvimTreeFocus<CR>", opts)
    map("n", "<leader>ef", ":NvimTreeFindFile<CR>", opts)

  end,
}
