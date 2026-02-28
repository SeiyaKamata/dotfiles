return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("telescope").setup {
      defaults = {
        prompt_prefix = "❯ ",
        selection_caret = "❯ ",
        path_display = { "truncate" },
        find_command = { "fd", "--type", "f" },
      },
    }

    local builtin = require("telescope.builtin")
    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    -- custom functions
    local function find_files_all()
      builtin.find_files({
        hidden = true,
        no_ignore = true,
      })
    end
    local function live_grep_all()
      builtin.live_grep({
        additional_args = function()
          return { "--hidden", "--no-ignore" }
        end,
      })
    end

    -- key maps
    map("n", "<leader>ff", builtin.find_files, opts)
    map("n", "<C-p>", builtin.find_files, opts)
    map("n", "<leader>fb", builtin.buffers, opts)
    map("n", "<leader>fg", builtin.live_grep, opts)

    map("n", "<leader>fF", find_files_all, opts)
    map("n", "<leader>fG", live_grep_all, opts)

  end,
}
