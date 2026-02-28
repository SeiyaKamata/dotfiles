vim.api.nvim_create_user_command("RelPath", function(opts)
  local path = vim.fn.expand("%:p")
  if path == "" then
    vim.notify("No file for current buffer", vim.log.levels.WARN)
    return
  end

  local relpath = vim.fn.fnamemodify(path, ":.")
  vim.fn.setreg('"', relpath)
  vim.fn.setreg("+", relpath)

  vim.notify(relpath)
end, { bang = true })
