-- nvim-treesitter main ブランチ（Neovim 0.12+ 必須）
local parsers = {
	"lua", "python", "nix",
	"javascript", "jsx", "typescript", "tsx",
	"ruby", "go",
	"json", "yaml", "toml", "sql",
	"bash",
	"terraform", "hcl",
	"dockerfile",
	"git_config", "gitignore", "gitcommit", "git_rebase", "gitattributes",
	"tmux",
	-- "make",  -- tree-sitter-grammars/tree-sitter-make のアーカイブが現在504のため保留
	"markdown", "markdown_inline",
}

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	event = { "BufReadPost", "BufNewFile" },
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").setup()
		require("nvim-treesitter").install(parsers)

		local function try_start(buf)
			if vim.b[buf].large_file then return end
			local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
			if not lang then return end
			if not pcall(vim.treesitter.language.add, lang) then return end
			-- options.lua の BufReadPost より FileType が先に来た場合のフォールバック
			local has_long = vim.api.nvim_buf_call(buf, function()
				return vim.fn.search([[\%>10000v.]], "n", 0, 0) > 0
			end)
			if has_long then
				vim.b[buf].large_file = true
				return
			end
			pcall(vim.treesitter.start, buf)
			vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end

		vim.api.nvim_create_autocmd("FileType", {
			callback = function(ev) try_start(ev.buf) end,
		})

		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				try_start(buf)
			end
		end
	end,
}
