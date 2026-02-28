vim.api.nvim_create_user_command("ToggleRelNum", function()
  vim.wo.relativenumber = not vim.wo.relativenumber
end, {})
