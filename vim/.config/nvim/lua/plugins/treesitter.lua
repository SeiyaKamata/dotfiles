-- nvim-treesitter は main ブランチ（Neovim 0.12+ 必須）を使う。
-- main は完全な書き直しで、旧 master の API（nvim-treesitter.configs / ensure_installed /
-- highlight={enable=true}）は廃止。パーサは install() で導入し、ハイライト・インデントは
-- Neovim 本体側（vim.treesitter.start / indentexpr）で有効化する。
return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false, -- ハイライトを初回ファイルから確実に効かせるため遅延ロードしない
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").setup()

		-- 使用言語のパーサを導入（旧 ensure_installed 相当）。非同期。
		require("nvim-treesitter").install({
			"lua",
			"python",
			"javascript",
			"markdown", -- render-markdown.nvim 用
			"markdown_inline", -- render-markdown.nvim 用
		})

		-- filetype ごとにハイライト／インデントを有効化（旧 highlight/indent = {enable=true} 相当）
		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				local buf = args.buf
				local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
				if not lang then
					return
				end
				-- パーサが利用可能なときだけ開始（未導入なら何もしない＝エラーにしない）
				if not pcall(vim.treesitter.language.add, lang) then
					return
				end
				pcall(vim.treesitter.start, buf)
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
