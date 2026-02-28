-- 基本オプション
local opt = vim.opt

-- 表示系
opt.number = true           -- 行番号を表示
opt.relativenumber = true   -- 相対行番号
opt.cursorline = true       -- カーソル行をハイライト
opt.termguicolors = true    -- 24bitカラー有効化
opt.signcolumn = "yes"      -- 常にサインカラムを表示
opt.wrap = false            -- 折り返し無効化
opt.winbar = "%=%f"
opt.title = true

-- buffer保存
opt.hidden = true

-- インデント系
opt.expandtab = true        -- タブをスペースに変換
opt.shiftwidth = 2          -- 自動インデントの幅
opt.tabstop = 2             -- タブ幅
opt.smartindent = true      -- スマートインデント

-- 検索系
opt.ignorecase = true       -- 大文字小文字を無視
opt.smartcase = true        -- 大文字が含まれていたら区別
opt.incsearch = true        -- インクリメンタルサーチ
opt.hlsearch = true         -- 検索結果をハイライト

-- 操作性
opt.scrolloff = 8             -- 上下に余白を持たせる
opt.splitbelow = true         -- 横分割は下に開く
opt.splitright = true         -- 縦分割は右に開く

-- 補完
opt.completeopt = { "menu", "menuone", "noselect" }

-- clipboard
opt.clipboard = "unnamedplus"
