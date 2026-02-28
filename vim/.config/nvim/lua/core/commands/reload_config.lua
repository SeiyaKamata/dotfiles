vim.api.nvim_create_user_command("ReloadConfig", function()
  vim.cmd("source $MYVIMRC")
  vim.notify("Config reloaded")
end, {})
