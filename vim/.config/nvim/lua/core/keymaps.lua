local function map(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { desc = desc, noremap = true, silent = true })
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

map("i", "jj",               "<Esc>",                                      "jj でノーマルモード")
map("n", "<leader>q",        "<cmd>x<CR>",                                 "保存して終了")
map("n", "<leader>h",        "<cmd>nohlsearch<CR>",                        "検索ハイライト解除")
map("n", "<C-f>",            "/",                                          "検索")
map("n", "H",                "^",                                          "行頭")
map("n", "L",                "$",                                          "行末")
map("n", "J",                "}",                                          "段落を下へ")
map("n", "K",                "{",                                          "段落を上へ")

map("n", "<leader>sr",       ":%s//g<Left><Left>",                         "バッファ全体を置換")
map("v", "<leader>sr",       ":s//g<Left><Left>",                          "選択範囲を置換")
map("n", "<leader>sw",       ":%s/\\<<C-r><C-w>\\>//gI<Left><Left><Left>", "カーソル単語をバッファ全体で置換")

map("n", "<Tab>",            "<cmd>bnext<CR>",                             "次のバッファへ")
map("n", "<S-Tab>",          "<cmd>bprevious<CR>",                         "前のバッファへ")
map("n", "<leader><leader>", "<cmd>b#<CR>",                                "直前のバッファへ")

-- v 連打で normal -> visual -> v-line -> v-block -> normal とサイクルさせる
-- ビジュアルの文字/行/矩形は Neovim のマッピング上は同一の x モードなので
-- キーマップ自体を4つに分けられず、現在の mode() を引く対応表にする。
local visual_cycle = {
	n     = "v",
	v     = "V",
	V     = "<C-v>",
	["\22"] = "<Esc>",
}
vim.keymap.set({ "n", "x" }, "v", function()
	return visual_cycle[vim.fn.mode()] or "v"
end, { expr = true, noremap = true, silent = true, desc = "ビジュアルモードをサイクル" })

-- ==========================================================================
-- Nop（無効化）設定はここに集約する
-- ==========================================================================

-- <leader>XY 系（3打鍵以上）のグループ先頭キー。タイポ・タイムアウト時に
-- 生キー（o→insert突入、s→置換してinsert突入 等）へフォールバックしない
-- ための安全弁。新しく <leader>X* のグループを増やしたらここにも追記する。
for _, prefix in ipairs({ "o", "f", "r", "s", "g", "c" }) do
	map("n", "<leader>" .. prefix, "<Nop>", "no-op")
end

-- Ex モード無効化（Q/gQ: 開始, q:/q// q?: コマンドライン/検索ウィンドウ, ZZ/ZQ: 終了ショートカット）
map("n", "q",                 "<Nop>",                                      "")
map("n", "Q",                 "<Nop>",                                      "")
map("n", "gQ",                "<Nop>",                                      "Exモード無効化")
map("n", "q:",                "<Nop>",                                      "")
map("n", "q/",                "<Nop>",                                      "")
map("n", "q?",                "<Nop>",                                      "")
map("n", "ZZ",                "<Nop>",                                      "")
map("n", "ZQ",                "<Nop>",                                      "")
map("n", "?",                 "<Nop>",                                      "")

-- Replace モード無効化（R: 通常, gR: Virtual Replace, <Insert>: Insert中の切り替え）
map("n", "R",                 "<Nop>",                                      "Replaceモード無効化")
map("n", "gR",                "<Nop>",                                      "Virtual Replaceモード無効化")
map("i", "<Insert>",          "<Nop>",                                      "Insert中のReplace切り替え無効化")

-- Select モード無効化（gh/gH/g<C-h>: 開始, Visual中の<C-g>: Visualからの切り替え）
map("n", "gh",                "<Nop>",                                      "Selectモード無効化")
map("n", "gH",                "<Nop>",                                      "Selectモード（行）無効化")
map("n", "g<C-h>",            "<Nop>",                                      "Selectモード（矩形）無効化")
map("x", "<C-g>",             "<Nop>",                                      "VisualからSelectへの切り替え無効化")
