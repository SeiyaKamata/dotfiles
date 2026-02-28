return {
  "Pocco81/auto-save.nvim",
  config = function()
    require("auto-save").setup {
      enabled = true,                   -- 起動時に自動保存有効
      execution_message = {
          message = function()
              return ("AutoSave: saved at " .. vim.fn.strftime("%H:%M:%S"))
          end,
          dim = 0.18,
          cleaning_interval = 1250,
      },
      trigger_events = {"InsertLeave", "BufLeave", "FocusLost"},
	  condition = function(buf)
	  	local fn = vim.fn
	  	local utils = require("auto-save.utils.data")
  
	  	if
	  		fn.getbufvar(buf, "&modifiable") == 1 and
	  		utils.not_in(fn.getbufvar(buf, "&filetype"), {}) then
	  		return true
	  	end
	  	return false
	  end,
      -- 追加で一定時間ごとに自動保存したい場合
      write_all_buffers = false,
      debounce_delay = 1000
    }
  end
}
