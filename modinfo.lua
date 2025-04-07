-- 250324 VanCa: Integrate KeyBind UI by 李皓奇
-- https://github.com/liolok/DST-KeyBind-UI
-- 250402 VanCa: Add Chinese support. Sadly, can't make Japanese works in the Mod page rightnow.

local STRINGS_AQ = {
    DESCRIPTION = {
        [[
Modified by: VanCa / Cutlass / null / eXiGe

Press F5 to enable Endless Deploy or enable it by default in mod settings.

While Endless Deploy is On:
	• Shift + Double click: Start a recursive queue. Before performing an action on an Entity, automatically trigger [Shift + Double click] on that Entity to add nearby Entities to the Selected list.
	• Shift + Click and drag: Endlessly perform an action on those selected Entities. While in this mode, [Shift + Double click] won’t start a recursive queue; it only adds nearby Entities to the Selected list.

Original mod: steamcommunity.com/sharedfiles/filedetails/?id=2873533916]],
        zh = [[
修改者：VanCa / Cutlass / null / eXiGe

按F5启用无尽部署或在模组设置中默认启用。

当无尽部署开启时：
	• Shift + 双击：开始递归队列。在对实体执行操作之前，自动触发[Shift + 双击]该实体，将附近实体添加到选定列表中。
	• Shift + 点击并拖动：对选定的实体无限执行操作。在此模式下，[Shift + 双击]不会启动递归队列；它只会将附近的实体添加到选定列表中。

原版模组:steamcommunity.com/sharedfiles/filedetails/?id=2873533916]],
        zht = [[
修改者：VanCa / Cutlass / null / eXiGe

按F5啟用無盡部署或在模組設定中預設啟用。

當無盡部署開啟時：
	• Shift + 雙擊：開始遞歸佇列。在對實體執行操作之前，自動觸發[Shift + 雙擊]該實體，將附近實體添加到選定清單中。
	• Shift + 點擊並拖動：對選定的實體無限執行操作。在此模式下，[Shift + 雙擊]不會啟動遞歸佇列；它只會將附近的實體添加到選定清單中。

原版模組:steamcommunity.com/sharedfiles/filedetails/?id=2873533916]],
        ja = [[
改修者: VanCa / Cutlass / null / eXiGe

F5を押して無限配置を有効化、またはMOD設定でデフォルトを有効にします。

無限配置が有効な場合:
	• Shift + ダブルクリック: 再帰キューを開始。エンティティにアクションを実行する前に、自動的に[Shift + ダブルクリック]をトリガーし、近くのエンティティを選択リストに追加します。
	• Shift + クリック＆ドラッグ: 選択したエンティティに対して無限にアクションを実行。このモードでは[Shift + ダブルクリック]は再帰キューを開始せず、近くのエンティティを選択リストに追加するのみです。

オリジナルMOD: steamcommunity.com/sharedfiles/filedetails/?id=2873533916]]
    },
    CONFIG = {
        -- General settings
        INGAME_LANGUAGE = {
            "Ingame language",
            zh = "游戏语言",
            zht = "遊戲語言",
            ja = "ゲーム内言語",
            DEST = {
                "Select ingame language",
                zh = "在游戏中选择语言",
                zht = "在遊戲中選擇語言",
                ja = "ゲーム内で言語を選択"
            }
        },
        ACTION_QUEUE_KEY = {"ActionQueue key", zh = "行动队列键", zht = "行動佇列鍵", ja = "アクションキューキー"},
        ALWAYS_CLEAR_QUEUE = {"Always clear queue", zh = "总是清除队列", zht = "總是清除佇列", ja = "常にキューをクリア"},
        SELECTION_COLOR = {"Selection color", zh = "选择颜色", zht = "選擇顏色", ja = "選択色"},
        HIGHLIGHT_OPACITY = {
            "Selection highlight opacity",
            zh = "选择高亮不透明度",
            zht = "選擇高亮不透明度",
            ja = "選択ハイライトの不透明度",
            DESC = {
                "Opacity level of the highlight for selected entities",
                zh = "选中实体的高亮不透明度级别",
                zht = "選中實體的高亮不透明度級別",
                ja = "選択されたエンティティのハイライト不透明度レベル"
            }
        },
        SELECTION_OPACITY = {
            "Selection rectangle opacity",
            zh = "选择矩形不透明度",
            zht = "選擇矩形不透明度",
            ja = "選択矩形不透明度",
            DESC = {
                "Opacity level of the selection rectangle when Shift + Click&Drag",
                zh = "当Shift+点击拖动时选择矩形的不透明度级别",
                zht = "當Shift+點擊拖動時選擇矩形的不透明度級別",
                ja = "Shift+クリック＆ドラッグ時の選択矩形不透明度"
            }
        },
        DOUBLE_CLICK_SPEED = {"Double click speed", zh = "双击速度", zht = "雙擊速度", ja = "ダブルクリック速度"},
        DOUBLE_CLICK_RANGE = {"Double click range", zh = "双击范围", zht = "雙擊範圍", ja = "ダブルクリック範囲"},
        -- Turf grid settings
        TURF_GRID_KEY = {"Turf grid toggle key", zh = "草皮网格切换键", zht = "草皮網格切換鍵", ja = "ターフグリッド切替キー"},
        TURF_GRID_RADIUS = {"Turf grid radius", zh = "草皮网格半径", zht = "草皮網格半徑", ja = "ターフグリッド半径"},
        TURF_GRID_COLOR = {"Turf grid color", zh = "草皮网格颜色", zht = "草皮網格顏色", ja = "ターフグリッド色"},
        DEPLOY_ON_GRID = {"Always deploy on grid", zh = "总是在网格上部署", zht = "總是在網格上部署", ja = "常にグリッド上に配置"},
        -- Hotkey settings
        AUTO_COLLECT_KEY = {"Auto-collect toggle key", zh = "自动收集切换键", zht = "自動收集切換鍵", ja = "自動収集切替キー"},
        ENABLE_AUTO_COLLECT = {
            "Enable auto-collect by default",
            zh = "默认启用自动收集",
            zht = "預設啟用自動收集",
            ja = "デフォルト自動収集有効"
        },
        ENDLESS_DEPLOY_KEY = {"Endless deploy toggle key", zh = "无尽部署切换键", zht = "無盡部署切換鍵", ja = "エンドレス配置切替キー"},
        ENABLE_ENDLESS_DEPLOY = {
            "Enable endless deploy by default",
            zh = "默认启用无尽部署",
            zht = "預設啟用無盡部署",
            ja = "デフォルトエンドレス配置有効"
        },
        CRAFT_LAST_RECIPE_KEY = {"Craft last recipe key", zh = "制作上一个配方键", zht = "製作上一個配方鍵", ja = "最終レシピ作成キー"},
        -- Placement settings
        TOOTH_TRAP_SPACING = {"Tooth-trap spacing", zh = "牙齿陷阱间距", zht = "牙齒陷阱間距", ja = "トゥーストラップ間隔"},
        FARM_GRID = {
            "Farm tilling grid",
            zh = "农场耕种网格",
            zht = "農場耕種網格",
            ja = "農耕グリッド",
            DESC = {
                "TILL farm plots in 2x2, 3x3, or 4x4 grids",
                zh = "以2x2、3x3或4x4网格耕种农场地块",
                zht = "以2x2、3x3或4x4網格耕種農場地塊",
                ja = "2x2/3x3/4x4グリッドで農耕地を耕作"
            }
        },
        -- Farm settings
        STOP_WATERING_AT = {
            "Stop watering at",
            zh = "停止浇水于",
            zht = "停止澆水於",
            ja = "灌漑停止ポイント",
            DESC = {
                "Stop watering when the farm tile's moisture reach __%",
                zh = "当农场地块的水分达到__％时停止浇水",
                zht = "當農場地塊的水分達到__％時停止澆水",
                ja = "農耕地水分が__%到達時灌漑停止"
            }
        },
        STOP_FERTILIZING_AT = {
            "Stop fertilizing at",
            zh = "停止施肥于",
            zht = "停止施肥於",
            ja = "施肥停止ポイント",
            DESC = {
                "Stop fertilizing when all the nutrient(s) value of the farm tile reach __%\n(match with the Fertilizer being used)",
                zh = "当农场地块的所有营养值达到__％时停止施肥\n（与所用肥料匹配）",
                zht = "當農場地塊的所有營養值達到__％時停止施肥\n（與所用肥料匹配）",
                ja = "農耕地栄養価が__%到達時施肥停止\n（肥料タイプに合わせ設定）"
            }
        },
        -- Experimental settings
        ENABLE_DOUBLE_SNAKE = {
            "Enable double snaking",
            zh = "启用双蛇形模式",
            zht = "啟用雙蛇形模式",
            ja = "ダブルスネーク有効化",
            DESC = {
                "[EXPERIMENTAL] Deploy / plant in a zigzag pattern",
                zh = "[实验性] 以曲折模式部署/种植",
                zht = "[實驗性] 以曲折模式部署/種植",
                ja = "[実験的] ジグザグ配置/植栽を有効化"
            }
        },
        ENABLE_QAAQ_MOD = {
            "Enable QAAQ mod compatibility",
            zh = "启用QAAQ模组兼容性",
            zht = "啟用QAAQ模組兼容性",
            ja = "QAAQ MOD互換性有効化",
            DESC = {
                "Enable this if using littledro's QAAQ mod",
                zh = "如果使用littledro的QAAQ模组，请启用此选项",
                zht = "如果使用littledro的QAAQ模組，請啟用此選項",
                ja = "littledroのQAAQ MOD使用時有効化"
            }
        },
        -- Debug settings
        ENABLE_DEBUG_MODE = {"Enable Debug Mode", zh = "启用调试模式", zht = "啟用偵錯模式", ja = "デバッグモード有効化"},
        -- Common options
        YES = {"Yes", zh = "是", zht = "是", ja = "有効"},
        NO = {"No", zh = "否", zht = "否", ja = "無効"},
        DISABLED = {"Disabled", zh = "禁用", zht = "禁用", ja = "無効化"},
        -- Grid options
        GRID_2X2 = {"2x2", zh = "2x2", zht = "2x2", ja = "2x2"},
        GRID_3X3 = {"3x3", zh = "3x3", zht = "3x3", ja = "3x3"},
        GRID_4X4 = {"4x4", zh = "4x4", zht = "4x4", ja = "4x4"}
    },
    COLORS = {
        WHITE = {"White", zh = "白色", zht = "白色", ja = "白"},
        RED = {"Red", zh = "红色", zht = "紅色", ja = "赤"},
        ORANGE = {"Orange", zh = "橙色", zht = "橙色", ja = "橙"},
        YELLOW = {"Yellow", zh = "黄色", zht = "黃色", ja = "黄"},
        GREEN = {"Green", zh = "绿色", zht = "綠色", ja = "緑"},
        TEAL = {"Teal", zh = "青色", zht = "青色", ja = "青緑"},
        BLUE = {"Blue", zh = "蓝色", zht = "藍色", ja = "青"},
        PURPLE = {"Purple", zh = "紫色", zht = "紫色", ja = "紫"},
        PINK = {"Pink", zh = "粉色", zht = "粉色", ja = "桃"},
        GOLD = {"Gold", zh = "金色", zht = "金色", ja = "金"}
    }
}

-- Mod metadata
author = "simplex (Original Author)"
version = "2.9.16"
name = "ActionQueue RB3 - with endless action v" .. version
folder_name = folder_name or "action queue"
if not folder_name:find("workshop-") then
    name = name .. " -dev"
end
description = ChooseTranslationTable(STRINGS_AQ.DESCRIPTION)

api_version_dst = 10
icon_atlas = "modicon.xml"
icon = "modicon.tex"
dst_compatible = true
all_clients_require_mod = false
client_only_mod = true

-- 250304 VanCa: Load after Japanese Language Pack (625582678) to support "Auto ingame language" mode
priority = -101

-- Key configuration

local keyboard = {
    -- from STRINGS.UI.CONTROLSSCREEN.INPUTS[1] of strings.lua, need to match constants.lua too.
    {"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "Print", "ScrolLock", "Pause"},
    {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"},
    {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"},
    {"Escape", "Tab", "CapsLock", "LShift", "LCtrl", "LSuper", "LAlt"},
    {"Space", "RAlt", "RSuper", "RCtrl", "RShift", "Enter", "Backspace"},
    {"BackQuote", "Minus", "Equals", "LeftBracket", "RightBracket"},
    {"Backslash", "Semicolon", "Quote", "Period", "Slash"}, -- punctuation
    {"Up", "Down", "Left", "Right", "Insert", "Delete", "Home", "End", "PageUp", "PageDown"} -- navigation
}
local numpad = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "Period", "Divide", "Multiply", "Minus", "Plus"}
local mouse = {"\238\132\130", "\238\132\131", "\238\132\132"} -- Middle Mouse Button, Mouse Button 4 and 5
local key_disabled = {description = ChooseTranslationTable(STRINGS_AQ.CONFIG.DISABLED), data = "KEY_DISABLED"}
keys = {key_disabled}
for i = 1, #mouse do
    keys[#keys + 1] = {description = mouse[i], data = mouse[i]}
end
for i = 1, #keyboard do
    for j = 1, #keyboard[i] do
        local key = keyboard[i][j]
        keys[#keys + 1] = {description = key, data = "KEY_" .. key:upper()}
    end
    keys[#keys + 1] = key_disabled
end
for i = 1, #numpad do
    local key = numpad[i]
    keys[#keys + 1] = {description = "Numpad " .. key, data = "KEY_KP_" .. key:upper()}
end

-- 250403 VanCa: Add language list
local language_list = {
    {description = "Auto", data = "auto"},
    {description = "English", data = "en"},
    {description = "日本語", data = "ja"},
    {description = "简体中文", data = "zh"},
    {description = "繁體中文", data = "zht"}
}

local colorlist = {
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.WHITE), data = "WHITE"},
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.RED), data = "FIREBRICK"},
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.ORANGE), data = "TAN"},
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.YELLOW), data = "LIGHTGOLD"},
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.GREEN), data = "GREEN"},
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.TEAL), data = "TEAL"},
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.BLUE), data = "OTHERBLUE"},
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.PURPLE), data = "DARKPLUM"},
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.PINK), data = "ROSYBROWN"},
    {description = ChooseTranslationTable(STRINGS_AQ.COLORS.GOLD), data = "GOLDENROD"}
}

-- 201221 null: farm tile Tilling grid list
local gridlist = {
    {description = ChooseTranslationTable(STRINGS_AQ.CONFIG.GRID_2X2), data = "2x2"},
    {description = ChooseTranslationTable(STRINGS_AQ.CONFIG.GRID_3X3), data = "3x3"},
    {description = ChooseTranslationTable(STRINGS_AQ.CONFIG.GRID_4X4), data = "4x4"}
}

-- 250307 VanCa: Stop watering when tile's moisture reach __%
local stop_watering_options = {
    {description = "20%", data = 0.2},
    {description = "30%", data = 0.3},
    {description = "40%", data = 0.4},
    {description = "50%", data = 0.5},
    {description = "60%", data = 0.6},
    {description = "70%", data = 0.7},
    {description = "80%", data = 0.8},
    {description = "90%", data = 0.9},
    {description = "100%", data = 0.99}
}

-- 250307 VanCa: Stop fertilizing when tile's nutrient(s) reach __%
local stop_fertilizing_options = {
    {description = "25%", data = 2},
    {description = "50%", data = 3},
    {description = "100%", data = 4}
}

local boolean = {
    {description = ChooseTranslationTable(STRINGS_AQ.CONFIG.YES), data = true},
    {description = ChooseTranslationTable(STRINGS_AQ.CONFIG.NO), data = false}
}

-- 210215 null: original BuildNumConfig() breaks on saving Double click speed for 0.15, 0.4, 0.45, and 0.5 values (they reset to 0)
-- Created an alternative function to handle decimal step values
-- Continue to use original BuildNumConfig() to maintain old functionality
-- Use nullBuildNumConfig() when needing to use float step values
local function nullBuildNumConfig(start_num, end_num, step, percent)
    local num_table = {}
    local iterator = 1
    local suffix = percent and "%" or ""

    local ostart_num, oend_num, ostep -- For storing original parameters if needed
    if step > 0 and step < 1 then -- If step = float between 0 and 1 (IE, Double click speed)
        ostart_num, oend_num, ostep = start_num, end_num, step -- Store the original parameters

        -- Convert floats to integers (only 2 decimal places though)
        start_num = start_num * 100
        end_num = end_num * 100
        step = step * 100
    end

    for i = start_num, end_num, step do -- if step was a non-integer, iterate as integers instead
        local i = ostep and i / 100 or i -- if step was a non-integer, convert i back to a float first

        num_table[iterator] = {description = i .. suffix, data = percent and i / 100 or i} -- original code
        iterator = iterator + 1
    end
    return num_table
end

local function BuildNumConfig(start_num, end_num, step, percent)
    local num_table = {}
    local iterator = 1
    local suffix = percent and "%" or ""
    for i = start_num, end_num, step do
        num_table[iterator] = {description = i .. suffix, data = percent and i / 100 or i}
        iterator = iterator + 1
    end
    return num_table
end

local function AddConfig(label, name, options, default, hover)
    return {label = label, name = name, options = options, default = default, hover = hover or ""}
end

-- Configuration options
configuration_options = {
    {
        name = "language",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.INGAME_LANGUAGE),
        hover = ChooseTranslationTable(STRINGS_AQ.CONFIG.INGAME_LANGUAGE.DEST),
        options = language_list,
        default = "en"
    },
    {
        name = "action_queue_key",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.ACTION_QUEUE_KEY),
        options = keys,
        default = "KEY_LSHIFT"
    },
    {
        name = "always_clear_queue",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.ALWAYS_CLEAR_QUEUE),
        options = boolean,
        default = true
    },
    {
        name = "selection_color",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.SELECTION_COLOR),
        options = colorlist,
        default = "WHITE"
    },
    {
        name = "highlight_opacity",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.HIGHLIGHT_OPACITY),
        hover = ChooseTranslationTable(STRINGS_AQ.CONFIG.HIGHLIGHT_OPACITY.DESC),
        options = BuildNumConfig(5, 95, 5, true),
        default = 0.5
    },
    {
        name = "selection_opacity",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.SELECTION_OPACITY),
        hover = ChooseTranslationTable(STRINGS_AQ.CONFIG.SELECTION_OPACITY.DESC),
        options = BuildNumConfig(5, 95, 5, true),
        default = 0.5
    },
    {
        -- 210215 null: fix for some values resetting back to 0 (IE 0.15, 0.4, 0.45, 0.5)
        name = "double_click_speed",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.DOUBLE_CLICK_SPEED),
        options = nullBuildNumConfig(0, 0.5, 0.05),
        default = 0.3
    },
    {
        name = "double_click_range",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.DOUBLE_CLICK_RANGE),
        options = BuildNumConfig(10, 60, 5),
        default = 25
    },
    {
        name = "turf_grid_key",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.TURF_GRID_KEY),
        options = keys,
        default = "KEY_F3"
    },
    {
        name = "turf_grid_radius",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.TURF_GRID_RADIUS),
        options = BuildNumConfig(1, 50, 1),
        default = 5
    },
    {
        name = "turf_grid_color",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.TURF_GRID_COLOR),
        options = colorlist,
        default = "WHITE"
    },
    {
        name = "deploy_on_grid",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.DEPLOY_ON_GRID),
        options = boolean,
        default = false
    },
    {
        name = "auto_collect_key",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.AUTO_COLLECT_KEY),
        options = keys,
        default = "KEY_F4"
    },
    {
        name = "enable_auto_collect",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.ENABLE_AUTO_COLLECT),
        options = boolean,
        default = false
    },
    {
        name = "endless_deploy_key",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.ENDLESS_DEPLOY_KEY),
        options = keys,
        default = "KEY_F5"
    },
    {
        name = "enable_endless_deploy",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.ENABLE_ENDLESS_DEPLOY),
        options = boolean,
        default = true
    },
    {
        name = "craft_last_recipe_key",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.CRAFT_LAST_RECIPE_KEY),
        options = keys,
        default = "KEY_C"
    },
    {
        name = "tooth_trap_spacing",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.TOOTH_TRAP_SPACING),
        options = BuildNumConfig(1, 4, 0.5),
        default = 2
    },
    {
        -- 201221 null: change between farm Tilling grids (3x3, 4x4)
        name = "farm_grid",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.FARM_GRID),
        hover = ChooseTranslationTable(STRINGS_AQ.CONFIG.FARM_GRID.DESC),
        options = gridlist,
        default = "3x3"
    },
    {
        -- 250307 VanCa: Add options to set the stopping point of Watering & Fertilizing
        name = "stop_watering_at",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.STOP_WATERING_AT),
        hover = ChooseTranslationTable(STRINGS_AQ.CONFIG.STOP_WATERING_AT.DESC),
        options = stop_watering_options,
        default = 0.9
    },
    {
        name = "stop_fertilizing_at",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.STOP_FERTILIZING_AT),
        hover = ChooseTranslationTable(STRINGS_AQ.CONFIG.STOP_FERTILIZING_AT.DESC),
        options = stop_fertilizing_options,
        default = 3
    },
    {
        name = "double_snake",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.ENABLE_DOUBLE_SNAKE),
        hover = ChooseTranslationTable(STRINGS_AQ.CONFIG.ENABLE_DOUBLE_SNAKE.DESC),
        options = boolean,
        default = false
    },
    {
        -- 220225 null
        name = "qaaq",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.ENABLE_QAAQ_MOD),
        hover = ChooseTranslationTable(STRINGS_AQ.CONFIG.ENABLE_QAAQ_MOD.DESC),
        options = boolean,
        default = false
    },
    {
        name = "enable_debug_mode",
        label = ChooseTranslationTable(STRINGS_AQ.CONFIG.ENABLE_DEBUG_MODE),
        options = boolean,
        default = false
    }
}
