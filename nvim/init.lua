-- Git 管理の lua ディレクトリを Lua モジュールパスに追加
local config_path = os.getenv("HOME") .. "/config/nvim/lua"
package.path = package.path .. ";" .. config_path .. "/?.lua"
package.path = package.path .. ";" .. config_path .. "/?/init.lua"

-- Core 設定をロード
require("core.options")
require("core.keymaps")
require("core.lazy")

-- Plugins 設定をロード
require("plugins")