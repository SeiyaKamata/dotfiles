return {
  "lewis6991/gitsigns.nvim",
  config = function()
    require("gitsigns").setup({
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
        end


        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>hd", gs.diffthis, "Diff this (buffer vs HEAD)")
        map("n", "<leader>hD", function() gs.diffthis("~") end, "Diff this (buffer vs HEAD~)")

      end,
    })
  end,
}
