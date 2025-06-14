-- 250324 VanCa: Integrate KeyBind UI by 李皓奇
-- https://github.com/liolok/DST-KeyBind-UI
modimport("keybind")
-- 250402 VanCa: Add Chinese and Japanese support

local _G = GLOBAL
if _G.TheNet:IsDedicated() or _G.TheNet:GetServerGameMode() == "lavaarena" then
    return
end

TUNING.ACTION_QUEUE_DEBUG_MODE = GetModConfigData("enable_debug_mode")

function table_print(tt, indent, done)
    done = done or {}
    indent = indent or 0
    local spacer = string.rep("  ", indent)

    if type(tt) == "table" then
        if done[tt] then
            return "table (circular reference)"
        end
        done[tt] = true

        local sb = {"{\n"}
        for key, value in pairs(tt) do
            table.insert(sb, spacer .. "  ")
            if type(key) == "number" then
                table.insert(sb, string.format("[%d] = ", key))
            else
                table.insert(sb, string.format("%s = ", tostring(key)))
            end

            -- Expand 1 level deep, show type for deeper tables
            if type(value) == "table" then
                if indent < 1 then -- Only expand up to 1 level deep
                    table.insert(sb, table_print(value, indent + 1, done))
                else
                    table.insert(sb, tostring(value) .. " (table)")
                end
            else
                table.insert(sb, tostring(value) .. " (" .. type(value) .. ")")
            end
            table.insert(sb, ",\n")
        end
        table.insert(sb, spacer .. "}")
        done[tt] = nil -- Allow reuse of this table in other branches
        return table.concat(sb)
    else
        return tostring(tt) .. " (" .. type(tt) .. ")"
    end
end

function to_string(tbl)
    if tbl == nil then
        return "nil"
    end
    if type(tbl) == "table" then
        return table_print(tbl, 0, {})
    elseif "string" == type(tbl) then
        return tbl
    end
    return tostring(tbl) .. " (" .. type(tbl) .. ")"
end

local DebugPrint = TUNING.ACTION_QUEUE_DEBUG_MODE and function(...)
        local msg = "[ActionQueue]"
        for i = 1, arg.n do
            msg = msg .. " " .. to_string(arg[i])
        end
        if arg.n > 1 then
            msg = msg .. "\n"
        end

        if #msg > 3900 then
            local chunks = {}
            local remaining = msg
            while #remaining > 3900 do
                local chunk = remaining:sub(1, 3900)
                local last_newline = chunk:find("\n[^\n]*$")
                if last_newline then
                    table.insert(chunks, chunk:sub(1, last_newline - 1))
                    remaining = remaining:sub(last_newline)
                else
                    table.insert(chunks, chunk)
                    remaining = remaining:sub(3901)
                end
            end
            table.insert(chunks, remaining)
            for _, chunk in ipairs(chunks) do
                print(chunk)
            end
        else
            print(msg)
        end
    end or function()
    end
_G.ActionQueue = {}
_G.ActionQueue.DebugPrint = DebugPrint

TUNING.ACTION_QUEUE_LANGUAGE = GetModConfigData("language")
local lang =
    TUNING.ACTION_QUEUE_LANGUAGE == "auto" and _G.LOC.GetLocale() and _G.LOC.GetLocale().code or
    TUNING.ACTION_QUEUE_LANGUAGE

local LANG_MESSAGES = {
    zh = {
        AUTO_COLLECT = "自动收集: ",
        ENDLESS_DEPLOY = "无尽部署: ",
        NO_PREVIOUS_RECIPE = "未找到之前的配方",
        UNABLE_TO_CRAFT = "无法制作: ",
        CRAFTING_LAST_RECIPE = "正在制作上一个配方: "
    },
    zht = {
        AUTO_COLLECT = "自動收集: ",
        ENDLESS_DEPLOY = "無盡部署: ",
        NO_PREVIOUS_RECIPE = "未找到之前的配方",
        UNABLE_TO_CRAFT = "無法製作: ",
        CRAFTING_LAST_RECIPE = "正在製作上一個配方: "
    },
    en = {
        AUTO_COLLECT = "Auto Collect: ",
        ENDLESS_DEPLOY = "Endless deploy: ",
        NO_PREVIOUS_RECIPE = "No previous recipe found",
        UNABLE_TO_CRAFT = "Unable to craft: ",
        CRAFTING_LAST_RECIPE = "Crafting last recipe: "
    },
    ja = {
        AUTO_COLLECT = "自動収集: ",
        ENDLESS_DEPLOY = "無限展開: ",
        NO_PREVIOUS_RECIPE = "以前のレシピが見つかりません",
        UNABLE_TO_CRAFT = "作成できません: ",
        CRAFTING_LAST_RECIPE = "最後のレシピを作成中: "
    }
}
local MESSAGES = LANG_MESSAGES[lang] or LANG_MESSAGES.en

-- 250307 VanCa: Added options in the mod settings to allow users to choose what the limits should be.
TUNING.STOP_WATERING_AT = GetModConfigData("stop_watering_at")
TUNING.STOP_FERTILIZING_AT = GetModConfigData("stop_fertilizing_at")

-- 250427 VanCa: Add optimal target selection.
TUNING.TARGET_SELECTION = GetModConfigData("target_seletion")

local SpawnPrefab = _G.SpawnPrefab
local TheInput = _G.TheInput
local unpack = _G.unpack
local CONTROL_ACTION = _G.CONTROL_ACTION
local CONTROL_FORCE_INSPECT = _G.CONTROL_FORCE_INSPECT
local CONTROL_FORCE_TRADE = _G.CONTROL_FORCE_TRADE
local PLAYERCOLOURS = _G.PLAYERCOLOURS
local STRINGS = _G.STRINGS
local ActionQueuer
local ThePlayer
local TheWorld

PLAYERCOLOURS.WHITE = {1, 1, 1, 1}

Assets = {
    Asset("ATLAS", "images/selection_square.xml"),
    Asset("IMAGE", "images/selection_square.tex")
}

local interrupt_controls = {}
for control = _G.CONTROL_ATTACK, _G.CONTROL_MOVE_RIGHT do
    interrupt_controls[control] = true
end

-- 220225 null: support for littledro's QAAQ mod
local qaaq = GetModConfigData("qaaq")
if qaaq then
    interrupt_controls[_G.CONTROL_ACTION] = false
end

local mouse_controls = {[_G.CONTROL_PRIMARY] = false, [_G.CONTROL_SECONDARY] = true}

local function GetKeyFromConfig(config)
    local key = GetModConfigData(config, true)
    if type(key) == "string" and _G:rawget(key) then
        key = _G[key]
    end
    return type(key) == "number" and key or -1
end

local callback = {} -- config name to function called when the key event triggered

local function InGame()
    return ThePlayer and ThePlayer.HUD and not ThePlayer.HUD:HasInputFocus()
end

local turf_grid = {}
local turf_size = 4
local turf_grid_visible = false
local turf_grid_radius = GetModConfigData("turf_grid_radius")
local turf_grid_color = PLAYERCOLOURS[GetModConfigData("turf_grid_color")]
callback.turf_grid_key = function()
    if not InGame() then
        return
    end
    if turf_grid_visible then
        for _, grid in pairs(turf_grid) do
            grid:Hide()
        end
        turf_grid_visible = false
        return
    end
    local center_x, _, center_z = TheWorld.Map:GetTileCenterPoint(ThePlayer.Transform:GetWorldPosition())
    local radius = turf_grid_radius * turf_size
    local count = 1
    for x = center_x - radius, center_x + radius, turf_size do
        for z = center_z - radius, center_z + radius, turf_size do
            if not turf_grid[count] then
                turf_grid[count] = SpawnPrefab("gridplacer")
                turf_grid[count].AnimState:SetAddColour(unpack(turf_grid_color))
            end
            turf_grid[count].Transform:SetPosition(x, 0, z)
            turf_grid[count]:Show()
            count = count + 1
        end
    end
    turf_grid_visible = true
end

-- 220225 null: support for littledro's QAAQ mod
local collect_mod = {turn_on = "normal", turn_off = false, chop_mod = "chop_mod"}

callback.auto_collect_key = function()
    if not InGame() then
        return
    end

    if qaaq then -- 220225 null: support for littledro's QAAQ mod
        ActionQueuer.auto_collect = collect_mod.turn_on
        collect_mod.turn_on = collect_mod.chop_mod
        collect_mod.chop_mod = collect_mod.turn_off
        collect_mod.turn_off = ActionQueuer.auto_collect
    else
        ActionQueuer.auto_collect = not ActionQueuer.auto_collect -- 220225 null: original autocollect toggle
    end
    ThePlayer.components.talker:Say(MESSAGES.AUTO_COLLECT .. tostring(ActionQueuer.auto_collect))
end

callback.endless_deploy_key = function()
    if not InGame() then
        return
    end
    ActionQueuer.endless_deploy = not ActionQueuer.endless_deploy
    ThePlayer.components.talker:Say(MESSAGES.ENDLESS_DEPLOY .. tostring(ActionQueuer.endless_deploy))
end

local last_recipe, last_skin
callback.craft_last_recipe_key = function()
    if not InGame() then
        return
    end
    if not last_recipe then
        ThePlayer.components.talker:Say(MESSAGES.NO_PREVIOUS_RECIPE)
        return
    end
    local last_recipe_name = STRINGS.NAMES[last_recipe.name:upper()] or "UNKNOWN"
    local builder = ThePlayer.replica.builder
    if not builder:CanBuild(last_recipe.name) and not builder:IsBuildBuffered(last_recipe.name) then
        ThePlayer.components.talker:Say(MESSAGES.UNABLE_TO_CRAFT .. last_recipe_name)
        return
    end
    if last_recipe.placer then
        if not builder:IsBuildBuffered(last_recipe.name) then
            builder:BufferBuild(last_recipe.name)
        end
        ThePlayer.components.playercontroller:StartBuildPlacementMode(last_recipe, last_skin)
    else
        builder:MakeRecipeFromMenu(last_recipe, last_skin)
    end
    ThePlayer.components.talker:Say(MESSAGES.CRAFTING_LAST_RECIPE .. last_recipe_name)
end

local function ActionQueuerInit()
    DebugPrint("Adding ActionQueuer component")
    ThePlayer:AddComponent("actionqueuer")
    ActionQueuer = ThePlayer.components.actionqueuer
    ActionQueuer.double_click_speed = GetModConfigData("double_click_speed")
    ActionQueuer.double_click_range = GetModConfigData("double_click_range")
    ActionQueuer.deploy_on_grid = GetModConfigData("deploy_on_grid")
    ActionQueuer.auto_collect = GetModConfigData("enable_auto_collect")
    ActionQueuer.endless_deploy = GetModConfigData("enable_endless_deploy")
    ActionQueuer:SetToothTrapSpacing(GetModConfigData("tooth_trap_spacing"))
    ActionQueuer:SetFarmGrid(GetModConfigData("farm_grid")) -- 201221 null: added support for changing farm grids (3x3, 4x4)
    ActionQueuer:SetDoubleSnake(GetModConfigData("double_snake")) -- 210127 null: added support for snaking within snaking
    local r, g, b = unpack(PLAYERCOLOURS[GetModConfigData("selection_color")])
    -- 250327 VanCa: Add highlight opacity
    ActionQueuer:SetHighlightOpacity(GetModConfigData("highlight_opacity"))
    ActionQueuer:SetSelectionColor(r, g, b, GetModConfigData("selection_opacity"))
end

-- 250327 VanCa: TheInput.IsKeyDown(...) crash when action_queue_key is nil, so I set it to 999 instead, for safety
local action_queue_key

--maybe i won't need this one day...
local use_control

local always_clear_queue = GetModConfigData("always_clear_queue")
AddComponentPostInit(
    "playercontroller",
    function(self, inst)
        if inst ~= _G.ThePlayer then
            return
        end
        ThePlayer = _G.ThePlayer
        TheWorld = _G.TheWorld
        ActionQueuerInit()

        local PlayerControllerOnControl = self.OnControl
        DebugPrint("PlayerControllerOnControl = self.OnControl")
        self.OnControl = function(self, control, down)
            local mouse_control = mouse_controls[control]
            if mouse_control ~= nil then
                if down then
                    if TheInput:IsAqModifierDown(action_queue_key) then
                        local target = TheInput:GetWorldEntityUnderMouse()
                        if
                            target and target:HasTag("fishable") and not inst.replica.rider:IsRiding() and
                                inst.replica.inventory:EquipHasTag("fishingrod")
                         then
                            ActionQueuer:StartAutoFisher(target)
                        elseif not ActionQueuer.auto_fishing then
                            ActionQueuer:OnDown(mouse_control)
                        end
                        return
                    end
                else
                    if ActionQueuer:OnUp(mouse_control) == "build_with_vanilla_grid" then
                        -- 250613 VanCa: Allow buiding with vanilla geometric (shift + single click)
                        DebugPrint("build_with_vanilla_grid control:", control, "down: true")
                        PlayerControllerOnControl(self, control, true)
                    end
                end
            end
            PlayerControllerOnControl(self, control, down)
            if
                down and ActionQueuer.action_thread and not ActionQueuer.selection_thread and InGame() and
                    (interrupt_controls[control] or mouse_control ~= nil and not TheInput:GetHUDEntityUnderMouse())
             then
                ActionQueuer:ClearActionThread()
                if always_clear_queue or control == CONTROL_ACTION then
                    ActionQueuer:ClearSelectedEntities()
                end
            end
        end
        local PlayerControllerIsControlPressed = self.IsControlPressed
        self.IsControlPressed = function(self, control)
            if control == CONTROL_FORCE_INSPECT and ActionQueuer.action_thread then
                return false
            end

            -- 201220 null: fix for EAT on self
            if
                use_control and control == CONTROL_FORCE_TRADE and
                    ThePlayer.components.playeravatardata.inst.replica.inventory:GetActiveItem() ~= nil
             then
                return false
            end

            return PlayerControllerIsControlPressed(self, control)
        end
    end
)

AddClassPostConstruct(
    "components/builder_replica",
    function(self)
        local BuilderReplicaMakeRecipeFromMenu = self.MakeRecipeFromMenu
        self.MakeRecipeFromMenu = function(self, recipe, skin)
            last_recipe, last_skin = recipe, skin
            if
                not ActionQueuer.action_thread and TheInput:IsAqModifierDown(action_queue_key) and not recipe.placer and
                    self:CanBuild(recipe.name)
             then
                ActionQueuer:RepeatRecipe(self, recipe, skin)
            else
                BuilderReplicaMakeRecipeFromMenu(self, recipe, skin)
            end
        end
        local BuilderReplicaMakeRecipeAtPoint = self.MakeRecipeAtPoint
        self.MakeRecipeAtPoint = function(self, recipe, pt, rot, skin)
            last_recipe, last_skin = recipe, skin
            BuilderReplicaMakeRecipeAtPoint(self, recipe, pt, rot, skin)
        end
    end
)

AddComponentPostInit(
    "highlight",
    function(self, inst)
        local HighlightHighlight = self.Highlight
        self.Highlight = function(self, ...)
            if ActionQueuer.selection_thread or ActionQueuer:IsSelectedEntity(inst) then
                return
            end
            HighlightHighlight(self, ...)
        end
        local HighlightUnHighlight = self.UnHighlight
        self.UnHighlight = function(self)
            if ActionQueuer:IsSelectedEntity(inst) then
                return
            end
            HighlightUnHighlight(self)
        end
    end
)

--for minimizing the memory leak in geo
--hides the geo grid during an action queue
AddComponentPostInit(
    "placer",
    function(self, inst)
        local PlacerOnUpdate = self.OnUpdate
        self.OnUpdate = function(self, ...)
            self.disabled = ActionQueuer.action_thread ~= nil
            PlacerOnUpdate(self, ...)
        end
    end
)

local is_holding_action_queue_mouse_key = false
function IsMouseKeyDown(key)
    return is_holding_action_queue_mouse_key
end

local handler = {} -- config name to key event handlers
function KeyBind(name, key)
    if handler[name] then
        handler[name]:Remove()
    end -- disable old binding

    -- Special Unbind handling for action_queue_key
    if name == "action_queue_key" then
        TheInput.IsAqModifierDown = function()
            return false
        end
    end

    if key ~= nil then -- new binding
        if key >= 1000 then -- it's a mouse button
            if name == "action_queue_key" then
                handler[name] =
                    GLOBAL.TheInput:AddMouseButtonHandler(
                    function(button, down, x, y)
                        if button == key then
                            is_holding_action_queue_mouse_key = down
                        end
                    end
                )
                use_control = false
                action_queue_key = key
                TheInput.IsAqModifierDown = IsMouseKeyDown
            else
                handler[name] =
                    GLOBAL.TheInput:AddMouseButtonHandler(
                    function(button, down, x, y)
                        if button == key and down then
                            callback[name]()
                        end
                    end
                )
            end
        else -- it's a keyboard key
            if name == "action_queue_key" then
                use_control =
                    TheInput:GetLocalizedControl(0, CONTROL_FORCE_TRADE) == STRINGS.UI.CONTROLSSCREEN.INPUTS[1][key]
                action_queue_key = use_control and CONTROL_FORCE_TRADE or key
                TheInput.IsAqModifierDown = use_control and TheInput.IsControlPressed or TheInput.IsKeyDown
            else
                handler[name] = GLOBAL.TheInput:AddKeyDownHandler(key, callback[name])
            end
        end
    else -- no binding
        handler[name] = nil
    end
end
