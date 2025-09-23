-- キーマッピング
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- スペースをリーダーキーに
vim.g.mapleader = " "

-- 基本操作
map("i", "jj", "<Esc>", opts)       -- jk でノーマルモード
map("n", "<leader>w", ":w<CR>", opts) -- 保存
map("n", "<leader>q", ":q<CR>", opts) -- 終了
map("n", "<leader>h", ":nohlsearch<CR>", opts) -- 検索ハイライト解除

-- ウィンドウ操作
map("n", "<leader>sv", "<C-w>v", opts) -- 垂直分割
map("n", "<leader>sh", "<C-w>s", opts) -- 水平分割
map("n", "<leader>se", "<C-w>=", opts) -- サイズを等分
map("n", "<leader>sx", ":close<CR>", opts) -- ウィンドウを閉じる

-- NvimTree
map("n", "<leader>e", ":NvimTreeToggle<CR>", opts)

-- Telescope
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", opts)
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", opts)
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", opts)
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", opts)

-- LSP
map("n", "gd", vim.lsp.buf.definition, opts)
map("n", "K", vim.lsp.buf.hover, opts)
map("n", "gr", vim.lsp.buf.references, opts)
map("n", "<leader>rn", vim.lsp.buf.rename, opts)
