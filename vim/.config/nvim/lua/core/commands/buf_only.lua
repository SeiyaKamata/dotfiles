vim.api.nvim_create_user_command("BufOnly", function()
  local current = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.api.nvim_buf_is_loaded(buf) then
      if vim.api.nvim_buf_get_option(buf, "buflisted") then
        vim.api.nvim_buf_delete(buf, { force = false })
      end
    end
  end
end, {})
