vim.api.nvim_create_user_command("CopyProjectRoot", function()
  local output = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 or not output[1] or output[1] == "" then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local root = output[1]
  vim.fn.setreg('"', root)
  vim.fn.setreg("+", root)
  vim.notify(root)
end, {})
