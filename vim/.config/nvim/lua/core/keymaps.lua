local function map(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { desc = desc, noremap = true, silent = true })
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- <leader>XY 系（3打鍵以上）のグループ先頭キー。タイポ・タイムアウト時に
-- 生キー（o→insert突入、s→置換してinsert突入 等）へフォールバックしない
-- ための安全弁。新しく <leader>X* のグループを増やしたらここにも追記する。
for _, prefix in ipairs({ "o", "f", "r", "s", "g", "c" }) do
	map("n", "<leader>" .. prefix, "<Nop>", "no-op")
end

map("i", "jj",         "<Esc>",                                            "jj でノーマルモード")
map("n", "<leader>q",  "<cmd>x<CR>",                                       "保存して終了")
map("n", "<leader>h",  "<cmd>nohlsearch<CR>",                              "検索ハイライト解除")
map("n", "<C-f>",      "/",                                                "検索")
map("n", "H",          "^",                                                "行頭")
map("n", "L",          "$",                                                "行末")
map("n", "J",          "}",                                                "段落を下へ")
map("n", "K",          "{",                                                "段落を上へ")

map("n", "<leader>sr", ":%s//g<Left><Left>",                               "バッファ全体を置換")
map("v", "<leader>sr", ":s//g<Left><Left>",                                "選択範囲を置換")
map("n", "<leader>sw", ":%s/\\<<C-r><C-w>\\>//gI<Left><Left><Left>",      "カーソル単語をバッファ全体で置換")

map("n", "<Tab>",            "<cmd>bnext<CR>",           "次のバッファへ")
map("n", "<S-Tab>",          "<cmd>bprevious<CR>",       "前のバッファへ")
map("n", "<leader><leader>", "<cmd>b#<CR>",              "直前のバッファへ")

map("n", "q",  "<Nop>", "")
map("n", "Q",  "<Nop>", "")
map("n", "q:", "<Nop>", "")
map("n", "q/", "<Nop>", "")
map("n", "q?", "<Nop>", "")
map("n", "ZZ", "<Nop>", "")
map("n", "ZQ", "<Nop>", "")
map("n", "?",  "<Nop>", "")
