-- キーマッピング
local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc, noremap = true, silent = true })
end

-- スペースをリーダーキーに
vim.g.mapleader = " "

-- 基本操作
map("i", "jj", "<Esc>", "jj でノーマルモード")
map("n", "<leader>w", ":w<CR>", "保存")
map("n", "<leader>q", ":q<CR>", "終了")
map("n", "<leader>h", ":nohlsearch<CR>", "検索ハイライト解除")
map("n", "<leader>rp", ":RelPath<CR>", "相対パスをコピー")

-- VS Code風操作
map("n", "<M-Down>", ":m .+1<CR>==", "現在行を下へ移動")
map("n", "<M-Up>", ":m .-2<CR>==", "現在行を上へ移動")
map("v", "<M-Down>", ":m '>+1<CR>gv=gv", "選択行を下へ移動")
map("v", "<M-Up>", ":m '<-2<CR>gv=gv", "選択行を上へ移動")
map("i", "<M-Down>", "<Esc>:m .+1<CR>==gi", "挿入モードで現在行を下へ移動")
map("i", "<M-Up>", "<Esc>:m .-2<CR>==gi", "挿入モードで現在行を上へ移動")

-- 置換
map("n", "<leader>sr", ":%s//g<Left><Left>", "バッファ全体を置換")
map("v", "<leader>sr", ":s//g<Left><Left>", "選択範囲を置換")
map("n", "<leader>sw", ":%s/\\<<C-r><C-w>\\>//gI<Left><Left><Left>", "カーソル単語をバッファ全体で置換")

-- buffer操作系
map("n", "<Tab>", "<cmd>bnext<CR>", "次のバッファへ")
map("n", "<S-Tab>", "<cmd>bprevious<CR>", "前のバッファへ")
map("n", "<leader><leader>", "<cmd>b#<CR>", "直前のバッファへ")
map("n", "<leader>bn", "<cmd>bnext<CR>", "次のバッファへ")
map("n", "<leader>bp", "<cmd>bprevious<CR>", "前のバッファへ")
map("n", "<leader>bb", "<cmd>buffers<CR>:buffer ", "バッファ一覧から選択")
map("n", "<leader>bd", "<cmd>bdelete<CR>", "現在のバッファを削除")

-- ウィンドウ操作
--map("n", "<leader>sv", "<C-w>v", "垂直分割")
--map("n", "<leader>sh", "<C-w>s", "水平分割")
--map("n", "<leader>se", "<C-w>=", "サイズを等分")
--map("n", "<leader>sx", ":close<CR>", "ウィンドウを閉じる")

-- いらないキーバインド
map("n", "q", "<Nop>", "q を無効化")
map("n", "Q", "<Nop>", "Ex モードを無効化")
map("n", "q:", "<Nop>", "コマンドライン履歴を無効化")
map("n", "q/", "<Nop>", "検索履歴を無効化")
map("n", "q?", "<Nop>", "逆方向検索履歴を無効化")
map("n", "ZZ", "<Nop>", "保存して終了を無効化")
map("n", "ZQ", "<Nop>", "保存せず終了を無効化")
map("n", "?", "<Nop>", "逆方向検索を無効化")
