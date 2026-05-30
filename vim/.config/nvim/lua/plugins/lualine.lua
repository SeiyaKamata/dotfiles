return {
	"nvim-lualine/lualine.nvim",
	config = function()
		-- ===== leader（prefix）待ち検知 =====
		-- Vim/Neovim には「leader待ち」を知らせる autocmd が無いため、
		-- on_key で生のキー入力を監視して疑似的に検知する。
		--   - ノーマル/ビジュアルモードで leader が押されたら pending=true
		--   - 次のキーが来たら（＝確定/キャンセル）解除
		--   - timeoutlen 経過でも保険として自動解除
		vim.g.leader_pending = false

		local leader = vim.g.mapleader
		if leader == nil or leader == "" then
			leader = "\\"
		end

		local timer = nil
		local function clear_pending()
			if vim.g.leader_pending then
				vim.g.leader_pending = false
				require("lualine").refresh()
			end
			if timer then
				timer:close()
				timer = nil
			end
		end

		local ns = vim.api.nvim_create_namespace("leader_indicator")
		vim.on_key(function(_, typed)
			if vim.g.leader_pending then
				-- 待ち中に何かキーが来た → prefix 確定 or キャンセルとみなして解除
				clear_pending()
				return
			end
			if typed ~= leader then
				return
			end
			local m = vim.fn.mode()
			-- n=ノーマル, v/V/<C-v>=ビジュアル系 のみ反応（挿入時のスペース等は無視）
			if m ~= "n" and m ~= "v" and m ~= "V" and m ~= "\22" then
				return
			end
			vim.g.leader_pending = true
			require("lualine").refresh()
			if timer then
				timer:close()
			end
			timer = vim.uv.new_timer()
			timer:start(vim.o.timeoutlen, 0, vim.schedule_wrap(clear_pending))
		end, ns)

		require("lualine").setup({
			options = {
				theme = "gruvbox",
				globalstatus = true,
			},
			sections = {
				lualine_a = {
					{
						-- tmux prefix(白 PREFIX) と区別するため gruvbox の赤で LEADER
						function()
							return " LEADER "
						end,
						cond = function()
							return vim.g.leader_pending
						end,
						color = { fg = "#1d2021", bg = "#fb4934", gui = "bold" },
					},
					"mode",
				},
			},
		})
	end,
}
