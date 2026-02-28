-- Interactive replace command: :R
vim.api.nvim_create_user_command("R", function()
  vim.ui.input({ prompt = "Replace from: " }, function(from)
    if not from or from == "" then return end

    vim.ui.input({ prompt = "Replace to: " }, function(to)
      if to == nil then return end

      -- escape for :substitute (very important)
      local esc = vim.fn.escape
      from = esc(from, [[\/.*$^~[]])
      to   = esc(to,   [[\/&]])

      vim.cmd(string.format("%%s/%s/%s/g", from, to))
    end)
  end)
end, {})
