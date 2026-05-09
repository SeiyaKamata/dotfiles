local M = {}

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

return M
