vim.api.nvim_create_user_command("Scratch", function()
  vim.cmd("enew")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "hide"
  vim.bo.swapfile = false
  vim.bo.buflisted = false
end, {})
