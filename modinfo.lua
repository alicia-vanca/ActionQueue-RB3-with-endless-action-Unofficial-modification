author = "Cutlass / null / eXiGe / simplex(Original Author)"
version = "2.9.12"
name = "ActionQueue RB3 - with endless action v" .. version
description = ""
api_version_dst = 10

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
all_clients_require_mod = false
client_only_mod = true

folder_name = folder_name or "action queue"
if not folder_name:find("workshop-") then
    name = name .. " -dev"
end

description = [[
	Press F5 to enable Endless Deploy or enable it by default in mod settings.
	
	While Endless Deploy is On:
	
	• Shift + Double click: Start a recursive queue. Before performing an action on an Entity, automatically trigger [Shift + Double click] on that Entity to add nearby Entities to the Selected list.
	
	• Shift + Click and drag: Endlessly perform an action on those selected Entities. While in this mode, [Shift + Double click] won’t start a recursive queue; it only adds nearby Entities to the Selected list.

	Original mod: steamcommunity.com/sharedfiles/filedetails/?id=2873533916
]]

local boolean = { { description = "Yes", data = true }, { description = "No", data = false } }
local string = ""
local keys = {
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "F1",
    "F2",
    "F3",
    "F4",
    "F5",
    "F6",
    "F7",
    "F8",
    "F9",
    "F10",
    "F11",
    "F12",
    "LAlt",
    "RAlt",
    "LCtrl",
    "RCtrl",
    "LShift",
    "RShift",
    "Tab",
    "Capslock",
    "Space",
    "Minus",
    "Equals",
    "Backspace",
    "Insert",
    "Home",
    "Delete",
    "End",
    "Pageup",
    "Pagedown",
    "Print",
    "Scrollock",
    "Pause",
    "Period",
    "Slash",
    "Semicolon",
    "Leftbracket",
    "Rightbracket",
    "Backslash",
    "Up",
    "Down",
    "Left",
    "Right",
}
local keylist = {}
for i = 1, #keys do
    keylist[i] = { description = keys[i], data = "KEY_" .. string.upper(keys[i]) }
end
keylist[#keylist + 1] = { description = "Disabled", data = false }

local colorlist = {
    { description = "White", data = "WHITE" },
    { description = "Red", data = "FIREBRICK" },
    { description = "Orange", data = "TAN" },
    { description = "Yellow", data = "LIGHTGOLD" },
    { description = "Green", data = "GREEN" },
    { description = "Teal", data = "TEAL" },
    { description = "Blue", data = "OTHERBLUE" },
    { description = "Purple", data = "DARKPLUM" },
    { description = "Pink", data = "ROSYBROWN" },
    { description = "Gold", data = "GOLDENROD" },
}

-- 201221 null: farm tile Tilling grid list
local gridlist = {
    { description = "2x2", data = "2x2" },
    { description = "3x3", data = "3x3" },
    { description = "4x4", data = "4x4" },
}

-- 250307 VanCa: Stop watering when tile's moisture reach __%
local stopWateringOptions = {
    { description = "20%", data = 0.2 },
    { description = "30%", data = 0.3 },
    { description = "40%", data = 0.4 },
    { description = "50%", data = 0.5 },
    { description = "60%", data = 0.6 },
    { description = "70%", data = 0.7 },
    { description = "80%", data = 0.8 },
    { description = "90%", data = 0.9 },
    { description = "100%", data = 0.99 },
}

-- 250307 VanCa: Stop fertilizing when tile's nutrient(s) reach __%
local stopFertilizingOptions = {
    { description = "25%", data = 2 },
    { description = "50%", data = 3 },
    { description = "100%", data = 4 },
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

        num_table[iterator] = { description = i .. suffix, data = percent and i / 100 or i } -- original code
        iterator = iterator + 1
    end
    return num_table
end

local function BuildNumConfig(start_num, end_num, step, percent)
    local num_table = {}
    local iterator = 1
    local suffix = percent and "%" or ""
    for i = start_num, end_num, step do
        num_table[iterator] = { description = i .. suffix, data = percent and i / 100 or i }
        iterator = iterator + 1
    end
    return num_table
end

local function AddConfig(label, name, options, default, hover)
    return { label = label, name = name, options = options, default = default, hover = hover or "" }
end

configuration_options = {
    AddConfig("ActionQueue key", "action_queue_key", keylist, "KEY_LSHIFT"),
    AddConfig("Always clear queue", "always_clear_queue", boolean, true),
    AddConfig("Selection color", "selection_color", colorlist, "WHITE"),
    AddConfig("Selection opacity", "selection_opacity", BuildNumConfig(5, 95, 5, true), 0.5),

    -- 210215 null: fix for some values resetting back to 0 (IE 0.15, 0.4, 0.45, 0.5)
    AddConfig("Double click speed", "double_click_speed", nullBuildNumConfig(0, 0.5, 0.05), 0.3),
    -- AddConfig("Double click speed", "double_click_speed", BuildNumConfig(0, 0.5, 0.05), 0.3), -- original code

    AddConfig("Double click range", "double_click_range", BuildNumConfig(10, 60, 5), 25),
    AddConfig("Turf grid toggle key", "turf_grid_key", keylist, "KEY_F3"),
    AddConfig("Turf grid radius", "turf_grid_radius", BuildNumConfig(1, 50, 1), 5),
    AddConfig("Turf grid color", "turf_grid_color", colorlist, "WHITE"),
    AddConfig("Always deploy on grid", "deploy_on_grid", boolean, false),
    AddConfig("Auto-collect toggle key", "auto_collect_key", keylist, "KEY_F4"),
    AddConfig("Enable auto-collect by default", "auto_collect", boolean, false),
    AddConfig("Endless deploy toggle key", "endless_deploy_key", keylist, "KEY_F5"),
    AddConfig("Enable endless deploy by default", "endless_deploy", boolean, true),
    AddConfig("Craft last recipe key", "last_recipe_key", keylist, "KEY_C"),
    AddConfig("Tooth-trap spacing", "tooth_trap_spacing", BuildNumConfig(1, 4, 0.5), 2),

    AddConfig("Farm tilling grid", "farm_grid", gridlist, "3x3", "TILL farm plots in 2x2, 3x3, or 4x4 grids"),
    -- 201221 null: change between farm Tilling grids (3x3, 4x4)
    
    -- 250307 VanCa: Add options to set the stopping point of Watering & Fertilizing
    AddConfig("Stop watering at", "stopWateringAt", stopWateringOptions, 0.9, "Stop watering when the farm tile's moisture reach __%"),
    AddConfig("Stop fertilizing at", "stopFertilizingAt", stopFertilizingOptions, 3, "Stop fertilizing when all the nutrient(s) value of the farm tile reach __%\n(match with the Fertilizer being used)"),
    
    AddConfig(
        "Enable double snaking",
        "double_snake",
        boolean,
        false,
        "[EXPERIMENTAL] Deploy / plant in a zigzag pattern"
    ),
    AddConfig("Enable QAAQ mod compatibility", "qaaq", boolean, false, "Enable this if using littledro's QAAQ mod"), -- 220225 null

    AddConfig("Enable Debug Mode", "debug_mode", boolean, false),
}
