vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    vim.fn.system("im-select com.apple.keylayout.ABC")
  end,
})
