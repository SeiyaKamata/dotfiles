return {
	"pwntester/octo.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	cmd = "Octo",
	keys = (function()
		-- 選択中PRのコミット一覧キャッシュと現在位置。review開始のたびにリセットする。
		local commit_state = { commits = nil, idx = 0, fetching = false }

		local function focus_commit_at(review, idx)
			local commit = commit_state.commits[idx]
			commit_state.idx = idx
			review:focus_commit(commit.sha, commit.parents[1].sha)
		end

		local function step_commit(direction)
			local review = require("octo.reviews").get_current_review()
			if not review then
				vim.notify("レビューが開始されていません", vim.log.levels.WARN)
				return
			end

			if commit_state.commits then
				local idx = commit_state.idx + direction
				if idx < 1 or idx > #commit_state.commits then
					vim.notify(direction > 0 and "これが最後のコミットです" or "これが最初のコミットです", vim.log.levels.WARN)
					return
				end
				focus_commit_at(review, idx)
				return
			end

			if commit_state.fetching then
				return
			end
			commit_state.fetching = true

			local gh = require("octo.gh")
			gh.api.get({
				"/repos/{repo}/pulls/{number}/commits",
				format = { repo = review.pull_request.repo, number = review.pull_request.number },
				paginate = true,
				opts = {
					cb = gh.create_callback({
						success = function(output)
							commit_state.fetching = false
							commit_state.commits = vim.json.decode(output)
							focus_commit_at(review, direction > 0 and 1 or #commit_state.commits)
						end,
					}),
				},
			})
		end

		return {
			{
				"<leader>on",
				function()
					vim.ui.input({ prompt = "PR番号: " }, function(n)
						if n and n ~= "" then
							vim.cmd("Octo pr edit " .. n)
						end
					end)
				end,
				desc = "GitHub: PR番号を指定して開く",
			},
			{
				"<leader>or",
				function()
					commit_state.commits, commit_state.idx, commit_state.fetching = nil, 0, false
					vim.cmd("Octo review start")
				end,
				desc = "GitHub: PR レビュー開始",
			},
			{ "]C", function() step_commit(1) end, desc = "GitHub: 次のコミットへ" },
			{ "[C", function() step_commit(-1) end, desc = "GitHub: 前のコミットへ" },
		}
	end)(),
	config = function()
		require("octo").setup({
			picker = "telescope",
			-- カーソル下のコメントスレッドを表示（コメント確認用）
			default_to_projects_v2 = false,
		})
	end,
}
