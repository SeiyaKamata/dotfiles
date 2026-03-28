local M = {}

--- 汎用キーマップ
--- @param mode string | table
--- @param lhs string
--- @param rhs string | function
--- @param opts? table
function M.map(mode, lhs, rhs, opts)
	vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { noremap = true, silent = true }, opts or {}))
end

--- バッファローカルなキーマップを返す関数
--- @param bufnr integer
--- @return function
function M.buf_map(bufnr)
	return function(mode, lhs, rhs, opts)
		vim.keymap.set(
			mode,
			lhs,
			rhs,
			vim.tbl_extend("force", { noremap = true, silent = true, buffer = bufnr }, opts or {})
		)
	end
end

--- 保存時に実行するautocmdを作成
--- @param pattern string
--- @param callback function
function M.on_save(pattern, callback)
	vim.api.nvim_create_autocmd("BufWritePre", {
		pattern = pattern,
		callback = callback,
	})
end

return M
