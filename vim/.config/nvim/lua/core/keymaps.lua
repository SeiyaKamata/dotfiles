local function map(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { desc = desc, noremap = true, silent = true })
end

vim.g.mapleader = " "

map("i", "jj",         "<Esc>",                                            "jj でノーマルモード")
map("n", "<leader>q",  "<cmd>x<CR>",                                       "保存して終了")
map("n", "<leader>h",  "<cmd>nohlsearch<CR>",                              "検索ハイライト解除")
map("n", "<leader>rp", "<cmd>RelPath<CR>",                                 "相対パスをコピー")
map("n", "H",          "^",                                                "行頭")
map("n", "L",          "$",                                                "行末")
map("n", "J",          "}",                                                "段落を下へ")
map("n", "K",          "{",                                                "段落を上へ")

map("n", "<C-j>",      "<cmd>m .+1<CR>==",                                 "現在行を下へ移動")
map("n", "<C-k>",      "<cmd>m .-2<CR>==",                                 "現在行を上へ移動")
map("v", "<C-j>",      "<cmd>m '>+1<CR>gv=gv",                            "選択行を下へ移動")
map("v", "<C-k>",      "<cmd>m '<-2<CR>gv=gv",                            "選択行を上へ移動")
map("i", "<C-j>",      "<Esc><cmd>m .+1<CR>==gi",                         "挿入モードで現在行を下へ移動")
map("i", "<C-k>",      "<Esc><cmd>m .-2<CR>==gi",                         "挿入モードで現在行を上へ移動")

map("n", "<leader>sr", ":%s//g<Left><Left>",                               "バッファ全体を置換")
map("v", "<leader>sr", ":s//g<Left><Left>",                                "選択範囲を置換")
map("n", "<leader>sw", ":%s/\\<<C-r><C-w>\\>//gI<Left><Left><Left>",      "カーソル単語をバッファ全体で置換")

map("n", "<Tab>",            "<cmd>bnext<CR>",           "次のバッファへ")
map("n", "<S-Tab>",          "<cmd>bprevious<CR>",       "前のバッファへ")
map("n", "<leader><leader>", "<cmd>b#<CR>",              "直前のバッファへ")
map("n", "<leader>bb",       "<cmd>buffers<CR>:buffer ", "バッファ一覧から選択")
map("n", "<leader>bd",       "<cmd>bdelete<CR>",         "現在のバッファを削除")

map("n", "q",  "<Nop>", "")
map("n", "Q",  "<Nop>", "")
map("n", "q:", "<Nop>", "")
map("n", "q/", "<Nop>", "")
map("n", "q?", "<Nop>", "")
map("n", "ZZ", "<Nop>", "")
map("n", "ZQ", "<Nop>", "")
map("n", "?",  "<Nop>", "")
map("n", "s",  "<Nop>", "")
