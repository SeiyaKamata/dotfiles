vim.api.nvim_create_user_command("TmuxSend", function(opts)
  local text

  if opts.range > 0 then
    text = table.concat(
      vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false),
      "\n"
    )
  else
    text = vim.api.nvim_get_current_line()
  end

  text = text:gsub("\n", "; ")

  vim.fn.system({
    "tmux", "send-keys",
    "-t", "!",
    text, "C-m"
  })
end, { range = true })
