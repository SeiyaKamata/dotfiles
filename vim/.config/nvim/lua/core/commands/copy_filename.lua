vim.api.nvim_create_user_command("CopyFileName", function()
  local name = vim.fn.expand("%:t")
  if name == "" then
    vim.notify("No file for current buffer", vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('"', name)
  vim.fn.setreg("+", name)
  vim.notify(name)
end, {})
