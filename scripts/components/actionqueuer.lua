local GeoUtil = require("utils/geoutil")
local Image = require("widgets/image")
local headings = {
    [0] = true,
    [45] = false,
    [90] = false,
    [135] = true,
    [180] = true,
    [225] = false,
    [270] = false,
    [315] = true,
    [360] = true
}
local easy_stack = {minisign_item = "structure", minisign_drawn = "structure", spidereggsack = "spiderden"}
local entity_morph = {spiderhole = "spiderhole_rock"}
local moving_target = {tumbleweed = true}
local deploy_spacing = {wall = 1, fence = 1, trap = 2, mine = 2, turf = 4, moonbutterfly = 4}
local drop_spacing = {trap = 2}
local unselectable_tags = {"DECOR", "FX", "INLIMBO", "NOCLICK", "player"}
local selection_thread_id = "actionqueue_selection_thread"
local action_thread_id = "actionqueue_action_thread"
local allowed_actions = {}
for _, category in pairs(
    {"allclick", "leftclick", "rightclick", "single", "noworkdelay", "tools", "autocollect", "collect"}
) do
    allowed_actions[category] = {}
end
local offsets = {}
for i, offset in pairs({{0, 0}, {0, 1}, {1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}}) do
    offsets[i] = Point(offset[1] * 1.5, 0, offset[2] * 1.5)
end

-- 201221 null: added support for snapping Tills to different farm tile grids
local farm_grid = "3x3"
-- local farm_spacing = 1.333 -- 210116 null: 1.333 (4/3) = selection box spacing for Tilling, Wormwood planting, etc

-- 210202 null: selection box spacing / offset for Tilling, Wormwood planting, etc
local farm_spacing = 4 / 3 -- 210202 null: use 4/3 higher precision to prevent alignment issues at edge of maps
local farm3x3_offset = farm_spacing / 2 -- 210202 null: 3x3 grid offset, use 4/3/2 to prevent alignment issues at edge of maps

local double_snake = false -- 210127 null: support for snaking within snaking in DeployToSelection()

-- 210116 null: 4x4 grid offsets for each heading
local offsets_4x4 = {
    -- these are basically margin/offset multipliers, selection box often starts from adjacent tile
    [0] = {x = 3, z = 3}, -- heading of 0 and 360 are the same
    [45] = {x = 1, z = 3},
    [90] = {x = -1, z = 3},
    [135] = {x = -1, z = 1},
    [180] = {x = -1, z = -1},
    [225] = {x = 1, z = -1},
    [270] = {x = 3, z = -1},
    [315] = {x = 3, z = 1},
    [360] = {x = 3, z = 3}
}

-- -- 210116 null: debug Farm spacing function
-- function SetFarmSpacing(num)
--     farm_spacing = num
--     print("farm_spacing: ", farm_spacing)
-- end
-- nspace = SetFarmSpacing

-- 210705 null: added support for other mods to add their own CherryPick conditions
local mod_cherrypick_fns = {} -- This will be a list of funtions from other mods

local DebugPrint = _G.ActionQueue.DebugPrint

-- 250522 VanCa: Added GetAnimation
function GetAnimation(ent)
    if ent == nil then
        return
    end
    local a, b, c, d, e, f = ent.AnimState:GetHistoryData()
    return b
end

local function AddAction(category, action, testfn)
    DebugPrint("-------------------------------------")
    DebugPrint("AddAction: category:", category, "action:", action, "testfn:", testfn)
    if type(category) ~= "string" or not allowed_actions[category] then
        DebugPrint("Category doesn't exist:", category)
        return
    end
    local action_ = type(action) == "string" and ACTIONS[action] or action
    if type(action_) ~= "table" or not action_.id then
        DebugPrint("Action doesn't exist:", action)
        return
    end
    if testfn ~= nil and testfn ~= true and type(testfn) ~= "function" then
        DebugPrint("testfn should be true, a function that returns a boolean, or nil:", testfn, "type:", type(testfn))
        return
    end
    local modifier = allowed_actions[category][action_] and (testfn and "modified" or "removed") or (testfn and "added")
    if not modifier then
        return
    end
    allowed_actions[category][action_] = testfn
    -- DebugPrint("Successfully", modifier, action_.id, "action in", category, "category.")
end

local function AddActionList(category, ...)
    DebugPrint("-------------------------------------")
    DebugPrint("AddActionList: category:", category)
    for _, action in pairs({...}) do
        -- DebugPrint("AddActionList: action:", action)
        AddAction(category, action, true)
    end
end

local function RemoveActionList(category, ...)
    DebugPrint("-------------------------------------")
    DebugPrint("RemoveActionList: category:", category)
    for _, action in pairs({...}) do
        DebugPrint("RemoveActionList: action:", action)
        AddAction(category, action)
    end
end

--[[global console functions]]
AddActionQueuerAction = AddAction
RemoveActionQueuerAction = AddAction
AddActionQueuerActionList = AddActionList
RemoveActionQueuerActionList = RemoveActionList

--[[allclick]]
AddActionList("allclick", "NET", "EAT")
-- 201222 null: Moved "EAT" from "rightclick" to "allclick" list

AddAction(
    "allclick",
    "CHOP",
    function(target)
        -- 250512 VanCa: Prevent chopping short palmcone tree
        return not (target.prefab == "palmconetree" and
            (target.AnimState:IsCurrentAnimation("idle_short") or
                target.AnimState:IsCurrentAnimation("sway1_loop_short") or
                target.AnimState:IsCurrentAnimation("sway2_loop_short")))
    end
)

AddAction(
    "allclick",
    "ATTACK",
    function(target)
        return target:HasTag("wall")
    end
)

-- 241021 VanCa: Stop mining when Werepig pillar is sharking
AddAction(
    "allclick",
    "MINE",
    function(target)
        if target.prefab == "daywalker_pillar" and target.AnimState:IsCurrentAnimation("pillar_shake") then
            return false
        else
            return true
        end
    end
)

--[[leftclick]]
AddActionList(
    "leftclick",
    "ADDFUEL",
    "ADDWETFUEL",
    "CHECKTRAP",
    "COMBINESTACK",
    "COOK",
    "DECORATEVASE",
    "DIG",
    "DRAW",
    "DRY",
    "EAT",
    "FERTILIZE",
    "FILL",
    "HAUNT",
    "LOWER_SAIL_BOOST",
    "PLANT",
    "RAISE_SAIL",
    "REPAIR_LEAK",
    "SEW",
    "TAKEITEM",
    "UPGRADE",
    "PLANTSOIL",
    "INTERACT_WITH",
    "ERASE_PAPER",
    "PICK",
    "BOTTLE",
    "WAX",
    "GRAVEDIG", -- 250304 VanCa: Added support for Wendy's skill
    "FT_CUTFUNGI", -- 250410 VanCa: Added support for shaving Candle Tree in Fairy Tales mod
    "MYTH_YJP_GIVE", -- 250412 VanCa: Added support for reviving giant plant with Myth mod's bottle
    "ADD_CARD_TO_DECK", -- 250415 VanCa: Added support for stack JIMBO cards
    "POUNCECAPTURE" -- 250613 VanCa: Added support for capturing Gestalt
)

-- 250320 VanCa: Prevent endless loop between 2 Catapults
AddAction(
    "leftclick",
    "ACTIVATE",
    function(target)
        return target.prefab == "dirtpile" or
            (target.prefab == "winona_catapult" and
                (target.AnimState:IsCurrentAnimation("idle_off_nodir") or
                    target.AnimState:IsCurrentAnimation("idle_off")))
    end
)
AddAction(
    "leftclick",
    "HARVEST",
    function(target)
        if target.prefab == "birdcage" then
            -- Only allow harvest sleeping bird
            if target.AnimState:IsCurrentAnimation("sleep_loop") and target.AnimState:IsCurrentAnimation("sleep_pre") then
                return true
            else
                return false
            end
        end

        -- others
        return true
    end
)
AddAction(
    "leftclick",
    "HEAL",
    function(target)
        --ThePlayer can only heal themselves, not other players
        return target == ThePlayer or not target:HasTag("player")
    end
)
AddAction(
    "leftclick",
    "PICKUP",
    function(target)
        return target.prefab ~= "trap" and target.prefab ~= "birdtrap" and not target:HasTag("mineactive") and
            not target:HasTag("minesprung")
    end
)
AddAction(
    "leftclick",
    "SHAVE",
    function(target)
        return target:HasTag("brushable")
    end
)

-- 201223 null: left click for PLANTREGISTRY_RESEARCH while equipping plantregistryhat
AddAction(
    "leftclick",
    "PLANTREGISTRY_RESEARCH",
    function(target)
        local equip_item = ThePlayer.components.playeravatardata.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        return equip_item and (equip_item.prefab == "plantregistryhat" or equip_item.prefab == "nutrientsgoggleshat") and
            target.prefab ~= "farm_plant_randomseed" -- 201223 null: disable research on random seeds to prevent infinite queue issue
    end
)

-- 210203 null: added support for leftclick FEED, when Walter feeds small Woby
-- 250310 VanCa: changed to allow all to support FEED beefalo when riding
AddAction(
    "leftclick",
    "FEED",
    function(target)
        -- return target.prefab == "wobysmall"
        return true
    end
)

-- 210226 null: added support for left click Wickerbottom book on self for READ (for Wickerbottom / Maxwell)
AddAction(
    "leftclick",
    "READ",
    function(target)
        local active_item = self:GetActiveItem()
        return active_item and active_item.AnimState and active_item.AnimState:GetBuild() == "books" and
            target == ThePlayer -- 210226 null: only queue READ if ThePlayer is using a book on themselves
    end
)
-- 240930 VanCa: added support for putting water into Kettle/Desalinator/Brewery in Dehydrated mod
AddAction(
    "leftclick",
    "GIVEWATER",
    function(target)
        if
            target:HasTag("kettle") or target:HasTag("desalinator") or target:HasTag("brewery") or
                target:HasTag("barrel")
         then
            return target.replica.waterlevel._accepting:value()
        end

        -- others
        return true
    end
)
-- 240930 VanCa: added support for taking water from water sources in Dehydrated mod
AddAction(
    "leftclick",
    "TAKEWATER",
    function(target)
        -- 241010 VanCa: return true, until something needs to be excluded
        -- return target.prefab == "pond" or target.prefab == "pond_mos" or target.prefab == "pond_cave" or
        -- target.prefab == "hotspring" or
        -- target.prefab == "grotto_pool_big" or
        -- target.prefab == "grotto_pool_small" or
        -- target.prefab == "oasislake" or
        -- target.prefab == "cherry_pond" or
        -- target.prefab == "quagmire_pond_salt" or
        -- target.prefab == "kyno_pond_salt" or
        -- target.prefab == "icefishing_hole" or
        -- target.prefab == "desalinator" or
        -- target.prefab == "barrel"
        return true
    end
)
AddAction(
    "leftclick",
    "TAKEWATER_OCEAN",
    function(target)
        return true
    end
)
-- 241010 VanCa: added support for putting ingredients into Crock Pots, Kettles, Breweries, Distilleries,...
AddAction(
    "leftclick",
    "STORE",
    function(target, self)
        -- Skip detailed processing for compatibility with QuickAction for ActionQueue (2753482847)
        if not self then
            return true
        end
        local active_item = self:GetActiveItem()
        if target:HasTags({"chest", "structure"}) and active_item.prefab == "featherpencil" then
            -- 250319 VanCa: Exclude STORE chests to draw minisign with click & drag easily
            return false
        end

        -- Make sure selected_ents_client_memory[target] is not nil
        self.selected_ents_client_memory[target] = self.selected_ents_client_memory[target] or {}

        local container = self:GetContainer(target)

        if container then
            if container.usespecificslotsforitems then
                -- (distilleries)
                local slot = container:GetSpecificSlotForItem(active_item)
                if slot then
                    -- Appropriate ingredient

                    -- If the target container is opening, remember what's in the specific slot
                    if container._isopen then
                        self.selected_ents_client_memory[target].item_in_specific_slot = container:GetItemInSlot(slot)
                    end
                    -- If specific slot is empty then return true
                    return not self.selected_ents_client_memory[target].item_in_specific_slot
                else
                    -- Inappropriate ingredient
                    return false
                end
            else
                -- (kettles / breweries / crock pots)
                -- If the target container is opening, remember whether it's full or not
                if container._isopen then
                    self.selected_ents_client_memory[target].is_full = container:IsFull()
                end
                -- Prevent STORE action when giving inappropriate thing or when it is full
                return container:CanTakeItemInSlot(active_item) and not self.selected_ents_client_memory[target].is_full
            end
        end
    end
)

AddAction(
    "leftclick",
    "GIVE",
    function(target, self)
        -- Skip detailed processing for compatibility with QuickAction for ActionQueue (2753482847)
        if not self then
            return true
        end
        local act
        if target.prefab == "well" then
            -- 241003 VanCa: (Dehydrated) Well
            -- Refuse GIVE action if the well is not ready or the active item isn't a bucket
            if not (target:HasTag("ready") and self:GetActiveItem():HasTag("bucket_empty")) then
                return false
            end
        elseif target.prefab == "gelblob_storage" then
            -- 241003 VanCa: prevent repeatedly giving item to gelblob_storage that already has another item.
            return not target.takeitem:value() or target.takeitem:value().prefab == self:GetActiveItem().prefab
        elseif target.prefab == "rabbithole" then
            -- 250613 VanCa: prevent giving nonsense things into rabbit hole
            return self:GetActiveItem().prefab == "carrot"
        end

        return true
    end
)
-- 240930 VanCa: added support for eating shield stone in 神魔修仙录（渡劫篇） mod
AddAction(
    "leftclick",
    "BOGD_COM_WORKABLE_ACTION",
    function(target)
        return true
    end
)

-- 241013 VanCa: added support for pickup daogui_corpse_flower tree in 道诡异仙 mod (workshop-3155177428)
AddAction(
    "leftclick",
    "DAOGUI_PICKUP",
    function(target)
        -- return target.prefab == "daogui_corpse_flower"
        return true
    end
)

-- 241013 VanCa: added temporary support for giving materials to compostingbin
AddAction(
    "leftclick",
    "ADDCOMPOSTABLE",
    function(target, self)
        -- Skip detailed processing for compatibility with QuickAction for ActionQueue (2753482847)
        if not self then
            return true
        end

        -- Always return true at first
        if target.prefab == "compostingbin" and self.selected_ents_client_memory[target] then
            local client_memory = self.selected_ents_client_memory[target]
            if not client_memory.CheckNotFull then
                client_memory.CheckNotFull =
                    target:DoPeriodicTask(
                    0.5,
                    function()
                        if self:IsSelectedEntity(target) then
                            if not target.AnimState:IsCurrentAnimation("working") then
                                client_memory.is_full = false
                            end
                        else
                            client_memory.CheckNotFull:Cancel()
                            client_memory.CheckNotFull = nil
                        end
                    end
                )
            end
            return not client_memory.is_full
        end
        return true
    end
)

-- 250219 VanCa: added support for RUMMAGE Ornate Chest
AddAction(
    "leftclick",
    "RUMMAGE",
    function(target, self)
        -- Skip detailed processing for compatibility with QuickAction for ActionQueue (2753482847)
        if not self then
            return true
        end

        if target.prefab == "pandoraschest" or target.prefab == "chest_mimic" then
            -- Make sure selected_ents_client_memory[target] is not nil (check allowed action before select)
            self.selected_ents_client_memory[target] = self.selected_ents_client_memory[target] or {}

            return not self.selected_ents_client_memory[target].skip_this_target
        end
        return false
    end
)

-- 250919 VanCa: Added support for mining Luna Hail == Cutlass 3.2 + Fix a stuck on burn trees
AddAction(
    "leftclick",
    "REMOVELUNARBUILDUP",
    function(target)
        -- Fix a stuck on burn trees
        return not (target:HasTag("burnt") or target:HasTag("fire") or target:HasTag("stump"))
    end
)

--[[rightclick]]
AddActionList(
    "rightclick",
    "CASTSPELL",
    "COOK",
    "DIG",
    "FEEDPLAYER",
    "HAMMER",
    "REPAIR",
    "RESETMINE",
    "TURNON",
    "TURNOFF",
    "UNWRAP",
    "TAKEITEM",
    "POUR_WATER",
    "DEPLOY_TILEARRIVE",
    "OCEAN_TRAWLER_LOWER",
    "OCEAN_TRAWLER_RAISE",
    "SCYTHE",
    "START_PUSHING",
    "DRAW_FROM_DECK" -- 250415 VanCa: Added support for draw JIMBO cards from deck
)

-- 201218 null: added support for right click PICK while equipping plantregistryhat
-- 210103 null: added support for right click PICK while Wormwood (plantkin)
-- 250401 VanCa: Fix a bug where Wormwood can't PICK farm plants with rightclick
AddAction(
    "rightclick",
    "PICK",
    function(target)
        local equip_item = ThePlayer.components.playeravatardata.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        return (equip_item and (equip_item.prefab == "plantregistryhat" or equip_item.prefab == "nutrientsgoggleshat")) or
            (ThePlayer:HasTag("plantkin") and target:HasTag("farm_plant")) or
            target.prefab == "otterden"
    end
)

-- 201218 null: added support for right click INTERACT_WITH while equipping plantregistryhat
AddAction(
    "rightclick",
    "INTERACT_WITH",
    function(target)
        local equip_item = ThePlayer.components.playeravatardata.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        return equip_item and (equip_item.prefab == "plantregistryhat" or equip_item.prefab == "nutrientsgoggleshat")
    end
)

-- 210103 null: added support for right click INTERACT_WITH while Wormwood (plantkin)
AddAction(
    "rightclick",
    "INTERACT_WITH",
    function(target)
        return ThePlayer:HasTag("plantkin")
    end
)

-- 210203 null: added support for rightclick FEED, when Walter feeds big Woby
AddAction(
    "rightclick",
    "FEED",
    function(target)
        return target.prefab == "wobybig"
    end
)

-- 241001 VanCa: added support for rightclick turn on Sprinkler (Dehydrated mod)
AddAction(
    "rightclick",
    "TURNON_TILEARRIVE",
    function(target)
        return target.prefab == "well_sprinkler"
    end
)

-- 241010 VanCa: exclude campkettles & campdesalinators that are not empty from DISMANTLE selection (Dehydrated mod)
AddAction(
    "rightclick",
    "DISMANTLE",
    function(target)
        if target.prefab == "campkettle" or target.prefab == "campdesalinator" then
            return target.replica.waterlevel._isdepleted:value()
        end
        return true
    end
)

-- 241001 VanCa: added support for taking food from the table that give seasoned food every day in 登仙 mod (workshop-3235319974)
AddAction(
    "rightclick",
    "XD_USE_INVENTORY",
    function(target)
        return target.prefab == "xd_qwsk"
    end
)

-- 241001 VanCa: added support for lighting up trees
AddAction(
    "rightclick",
    "LIGHT",
    function(target)
        return target:HasTag("tree") or target:HasTag("plant")
    end
)

-- 250307 VanCa: added "FILL" to rightclick and support switching wateringCan
-- (when holding the wateringcan, refill is rightclick)
AddAction(
    "rightclick",
    "FILL",
    function(target, self)
        -- Skip detailed processing for compatibility with QuickAction for ActionQueue (2753482847)
        if not self then
            return true
        end

        local item_in_hand = self:GetEquippedItemInHand()
        if item_in_hand and (item_in_hand.prefab == "wateringcan" or item_in_hand.prefab == "premiumwateringcan") then
            if self:GetActiveItem() then
                return false
            elseif self:GetItemPercent(item_in_hand) == 100 then
                DebugPrint("This watering can is full")
                return nil ~=
                    self:GetNewEquippedItemInHand(
                        {"wateringcan", "premiumwateringcan"},
                        nil,
                        function(item)
                            return self:GetItemPercent(item) < 100
                        end
                    )
            end
        end
        return true
    end
)

-- 250427 cutglass: Support pickup spider
AddAction(
    "rightclick",
    "PICKUP",
    function(target)
        return target:HasTag("spider")
    end
)

-- 250427 cutglass: Picking items on the ground with Knabsack for Wortox
AddAction(
    "rightclick",
    "NABBAG",
    function(target)
        return target.prefab ~= "trap" and target.prefab ~= "birdtrap" and not target:HasTag("mineactive") and
            not target:HasTag("minesprung")
    end
)

--[[single]]
AddActionList("single", "CASTSPELL", "DECORATEVASE", "REPAIR_LEAK")

--[[noworkdelay]]
AddActionList(
    "noworkdelay",
    "ADDFUEL",
    "ADDWETFUEL",
    "CHOP",
    "COOK",
    "DIG",
    "DRY",
    "EAT",
    "FERTILIZE",
    "HAMMER",
    "HARVEST",
    "HEAL",
    "MINE",
    "PLANT",
    "REPAIR",
    "TERRAFORM",
    "ADDCOMPOSTABLE",
    "DEPLOY_TILEARRIVE",
    "PICKUP",
    "LIGHT",
    "ERASE_PAPER", -- 250114 VanCa: Added ERASE_PAPER to noworkdelay list
    "DRAW_FROM_DECK" -- 250114 VanCa
)

AddAction(
    "noworkdelay",
    "GIVE",
    function(target)
        return target:HasTag("trader")
    end
)

AddAction(
    "noworkdelay",
    "NET",
    function(target)
        return not ThePlayer.components.locomotor or not target:HasTag("butterfly")
    end
)

AddAction(
    "noworkdelay",
    "FILL",
    function(target, self)
        -- Skip detailed processing for compatibility with QuickAction for ActionQueue (2753482847)
        if not self then
            return true
        end

        local item_in_hand = self:GetEquippedItemInHand()
        if item_in_hand and (item_in_hand.prefab == "wateringcan" or item_in_hand.prefab == "premiumwateringcan") then
            return false
        else
            local active_item = self:GetActiveItem()
            if active_item and (active_item.prefab == "wateringcan" or active_item.prefab == "premiumwateringcan") then
                return false
            end
        end
        return true
    end
)

--[[tools]]
AddActionList("tools", "ATTACK", "CHOP", "DIG", "HAMMER", "MINE", "NET", "SCYTHE")

--[[autocollect]]
AddActionList("autocollect", "CHOP", "DIG", "HAMMER", "HARVEST", "MINE", "PICK", "PICKUP", "RESETMINE", "SCYTHE")
AddAction(
    "autocollect",
    "GIVE",
    function(target)
        return target.prefab ~= "mushroom_farm" and target.prefab ~= "moonbase" and not target:HasTag("gemsocket")
    end
)

--[[collect]]
AddAction(
    "collect",
    "PICKUP",
    function(target)
        return not (target:HasTag("INLIMBO") or target:HasTag("NOCLICK") or target:HasTag("irreplaceable") or
            target:HasTag("knockbackdelayinteraction") or
            target:HasTag("event_trigger") or
            target:HasTag("catchable") or
            target:HasTag("fire") or
            target:HasTag("light") or
            target:HasTag("spider") or
            target:HasTag("cursed") or
            target:HasTag("paired") or
            target:HasTag("bundle") or
            target:HasTag("heatrock") or
            target:HasTag("deploykititem") or
            target:HasTag("boatbuilder") or
            target:HasTag("singingshell") or
            target:HasTag("archive_lockbox") or
            target:HasTag("simplebook") or
            target:HasTag("donotautopick") or
            target:HasTag("backpack")) and
            target:HasTag("_inventoryitem") and
            target.prefab ~= "amulet"
    end
)

-- 250327 VanCa: Add highlight opacity
local ActionQueuer =
    Class(
    function(self, inst)
        self.inst = inst
        self.selection_widget = Image("images/selection_square.xml", "selection_square.tex")
        self.selection_widget:Hide()
        self.clicked = false
        self.TL, self.TR, self.BL, self.BR = nil, nil, nil, nil
        TheInput:AddMoveHandler(
            function(x, y)
                self.screen_x, self.screen_y = x, y
                self.queued_movement = true
            end
        )
        --Maps ent to key and rightclick(true or false) to value
        self.selected_ents = {}
        self.selected_ents_sortable = {}
        self.selected_ents_client_memory = {}
        self.selected_farm_tiles = {}
        self.selection_thread = nil
        self.action_thread = nil
        self.action_delay = FRAMES * 3
        self.work_delay = FRAMES * 6
        self.color = {x = 1, y = 1, z = 1}
        self.highlight_opacity = 0.5
        self.deploy_on_grid = false
        self.auto_collect = false
        self.endless_deploy = false
        self.last_click = {time = 0}
        self.double_click_speed = 0.4
        self.double_click_range = 15
        self.last_target_ent = nil
        self.double_click_flag = false
        self.drag_click_selected_flag = false
        self.AddAction = AddAction
        self.RemoveAction = AddAction
        self.AddActionList = AddActionList
        self.RemoveActionList = RemoveActionList
        DebugPrint("ActionQueuer initialize")
    end
)

local function IsValidEntity(ent)
    -- DebugPrint("IsValidEntity: ent:", ent)
    return ent and ent.Transform and ent:IsValid() and not ent:HasTag("INLIMBO")
end

local function IsHUDEntity()
    -- DebugPrint("IsHUDEntity")
    local ent = TheInput:GetWorldEntityUnderMouse()
    return ent and ent:HasTag("INLIMBO") or TheInput:GetHUDEntityUnderMouse()
end

local function CheckAllowedActions(category, action, target, self)
    -- DebugPrint("CheckAllowedActions: category:", category, "action:", action, "target:", target)
    local allowed_action = allowed_actions[category][action]
    return allowed_action and (allowed_action == true or allowed_action(target, self))
end

local function GetWorldPosition(screen_x, screen_y)
    -- DebugPrint("GetWorldPosition: screen_x:", screen_x, "screen_y:", screen_y)
    return Point(TheSim:ProjectScreenPos(screen_x, screen_y))
end

-- -- 210127 null: can use TheInput:GetWorldPosition() instead
-- -- 201223 null: function to get the in-game world position under the mouse
-- local function GetWorldPositionUnderMouse()
--     local screen_x, screen_y = TheSim:GetPosition() -- Get player's cursor coordinates (pixels) on display screen
--     return Point(TheSim:ProjectScreenPos(screen_x, screen_y)) -- Convert the screen coordinates into in-game world position
-- end

local function GetDeploySpacing(item)
    -- DebugPrint("GetDeploySpacing: item:", item)
    for key, spacing in pairs(deploy_spacing) do
        if item.prefab:find(key) or item:HasTag(key) then
            return spacing
        end
    end
    local spacing = item.replica.inventoryitem:DeploySpacingRadius()
    return spacing ~= 0 and spacing or 1
end

local function GetDropSpacing(item)
    -- DebugPrint("GetDropSpacing: item:", item)
    for key, spacing in pairs(drop_spacing) do
        if item.prefab:find(key) or item:HasTag(key) then
            return spacing
        end
    end
    return 1
end

local function CompareDeploySpacing(item, spacing)
    DebugPrint("-------------------------------------")
    DebugPrint("CompareDeploySpacing: item:", item, "spacing:", spacing)
    return item and item.replica.inventoryitem and item.replica.inventoryitem.classified and
        item.replica.inventoryitem.classified.deployspacing:value() == spacing
end

local function GetHeadingDir()
    DebugPrint("-------------------------------------")
    DebugPrint("GetHeadingDir")
    local dir = headings[TheCamera.heading]
    if dir ~= nil then
        return TheCamera.heading, dir
    end
    for heading, dir in pairs(headings) do --diagonal priority
        local check_angle = heading % 2 ~= 0 and 23 or 22.5
        if math.abs(TheCamera.heading - heading) < check_angle then
            return heading, dir
        end
    end
end

local function GetAccessibleTilePosition(pos)
    DebugPrint("-------------------------------------")
    DebugPrint("GetAccessibleTilePosition: pos:", pos)
    local ent_blockers = TheSim:FindEntities(pos.x, 0, pos.z, 4, {"blocker"})
    for _, offset in pairs(offsets) do
        local offset_pos = offset + pos
        for _, ent in pairs(ent_blockers) do
            local ent_radius = ent:GetPhysicsRadius(0) + 0.6 --character size + 0.1
            if offset_pos:DistSq(ent:GetPosition()) < ent_radius * ent_radius then
                offset_pos = nil
                break
            end
        end
        if offset_pos then
            return offset_pos
        end
    end
    return nil
end

-- -- 201217 null: added support for snapping Tills to farm tile grid
-- -- Idea from surg's Snapping tills mod: https://steamcommunity.com/sharedfiles/filedetails/?id=2302837868
-- local function GetSnapTillPosition(pos)
--     local tilecenter = _G.Point(_G.TheWorld.Map:GetTileCenterPoint(pos.x, 0, pos.z))
--     local tilepos = _G.Point(tilecenter.x - 2, 0, tilecenter.z - 2)
--     local cx, cz

--     -- 201221 null: added support for snapping Tills to different farm tile grids
--     if farm_grid == "3x3" then
--         cx = math.floor((pos.x - tilepos.x) / 1.333) -- 4/3, 3 sections per tile row
--         cz = math.floor((pos.z - tilepos.z) / 1.333)
--         pos.x, pos.z = tilepos.x + ((cx * 1.333) + 0.665), tilepos.z + ((cz * 1.333) + 0.665) -- spacing = 1.333, offset = 0.665
--     elseif farm_grid == "4x4" then
--         cx = math.floor(pos.x - tilepos.x) -- 4/4, 4 sections per tile row
--         cz = math.floor(pos.z - tilepos.z)
--         pos.x, pos.z = tilepos.x + (cx * 1.333), tilepos.z + (cz * 1.333) -- spacing = 1.333, offset = 0
--         -- pos.x, pos.z = tilepos.x + ((cx * 1.26) + 0.11), tilepos.z + ((cz * 1.26) + 0.11) -- spacing = 1.333, offset = 0.665
--     end

--     -- 201220 null: Check if snapped pos already Tilled
--     for _,ent in pairs(TheSim:FindEntities(pos.x, 0, pos.z, 0.005, {"soil"})) do
--         if not ent:HasTag("NOCLICK") then return nil end -- Skip Tilling this position
--     end

--     return pos
-- end
-- -- 210116 null: not needed anymore, due to setting up correct starting values for farm grids

-- 210127 null: added support for changing between regular snaking or double snaking deployment
function ActionQueuer:SetDoubleSnake(bool)
    DebugPrint("-------------------------------------")
    DebugPrint("SetDoubleSnake: bool:", bool)
    double_snake = bool
end

-- 201221 null: added support for changing Snapped farm Till grid
function ActionQueuer:SetFarmGrid(type)
    DebugPrint("-------------------------------------")
    DebugPrint("SetFarmGrid: type:", type)
    farm_grid = type
end

function ActionQueuer:SetToothTrapSpacing(num)
    DebugPrint("-------------------------------------")
    DebugPrint("SetToothTrapSpacing: num:", num)
    deploy_spacing.trap = num
end

-- Get the items on the mouse
function ActionQueuer:GetActiveItem(allowed_prefabs)
    local item = self.inst.replica.inventory:GetActiveItem()
    DebugPrint("-------------------------------------")
    DebugPrint("GetActiveItem:", tostring(item))

    -- If no prefab is specified, return GetActiveItem() result
    if not allowed_prefabs then
        return item
    end

    -- If prefab is table, then allowed_prefabs = prefab, if prefab is string allowed_prefabs = {allowed_prefabs}, if else, crash..
    allowed_prefabs =
        (type(allowed_prefabs) == "string" and {allowed_prefabs}) or
        (type(allowed_prefabs) == "table" and allowed_prefabs)
    -- Return nil if the current active item isn't what we expect
    return table.contains(allowed_prefabs, item.prefab) and item
end

function ActionQueuer:GetEquippedItemInHand()
    DebugPrint("-------------------------------------")
    local item_in_hand = self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    DebugPrint("GetEquippedItemInHand: ", tostring(item_in_hand))
    return item_in_hand
end

-- Get item durable, reference: 呼吸
-- i: [0 ~ 100]%
function ActionQueuer:GetItemPercent(inst)
    local i = 100
    local classified =
        type(inst) == "table" and inst.replica and inst.replica.inventoryitem and inst.replica.inventoryitem.classified
    if classified then
        if inst:HasOneOfTags({"fresh", "show_spoilage"}) and classified.perish then
            i = math.floor(classified.perish:value() / 0.62)
        elseif classified.percentused then
            i = classified.percentused:value()
        end
    end
    return i
end

-- Get entity's container
function ActionQueuer:GetContainer(ent)
    -- DebugPrint("ent:", ent)
    if ent and ent.replica then
        return ent.replica.container or ent.replica.inventory
    end
end

local order_all = {"container", "equip", "body", "backpack", "mouse"}
-- Get the location of the item and its container. Actually, tags are legacy code [Items under the mouse will only be included if order == ‘mouse’]
-- reference: 呼吸
function ActionQueuer:GetSlotsFromAll(allowed_prefabs, tags_required, validate_func, order)
    DebugPrint("-------------------------------------")
    DebugPrint("GetSlotsFromAll: allowed_prefabs:", allowed_prefabs, "tags_required:", tags_required)
    local result = {}
    local invent = self.inst.replica.inventory

    if order == "mouse" then
        order = order_all
    elseif type(order) == "string" and table.contains(order_all, order) then
        order = {order}
    elseif type(order) == "table" then
        local temp_order = {}
        for _, storage_name in pairs(order) do
            if type(storage_name) == "string" and table.contains(order_all, storage_name) then
                table.insert(temp_order, storage_name)
            end
        end
        order = temp_order
    else
        order = {"container", "equip", "body", "backpack"}
    end

    -- Make sure tags_required and allowed_prefabs are table, or nil
    tags_required =
        (type(tags_required) == "string" and {tags_required}) or (type(tags_required) == "table" and tags_required) or
        nil
    allowed_prefabs =
        (type(allowed_prefabs) == "string" and {allowed_prefabs}) or
        (type(allowed_prefabs) == "table" and allowed_prefabs) or
        nil

    local backpack_list, container_list = {}, {}
    DebugPrint("invent:GetOpenContainers():", invent:GetOpenContainers())
    for container_inst, _ in pairs(invent:GetOpenContainers() or {}) do
        if container_inst:HasTag("INLIMBO") then
            table.insert(backpack_list, container_inst)
        else
            table.insert(container_list, container_inst)
        end
    end

    local function check_and_add_result(cont, slot, item)
        if
            item and (not allowed_prefabs or table.contains(allowed_prefabs, item.prefab)) and
                (not tags_required or item:HasTags(tags_required)) and
                (not validate_func or validate_func(item, cont, slot))
         then
            table.insert(
                result,
                {
                    cont = cont,
                    slot = slot,
                    item = item
                }
            )
        end
    end

    local function check_containers(conts)
        for _, cont in pairs(conts) do
            local container = self:GetContainer(cont)
            -- 241010 VanCa: Stop taking item from "cooker" type container
            -- 250428 VanCa: Allow taking item from frostpack (Casino host)
            if container and (container.type ~= "cooker" or container.inst.prefab == "frostpack") then
                DebugPrint("[ " .. tostring(cont) .. " ]", container.type)
                for slot, item in pairs(container:GetItems()) do
                    DebugPrint("slot:", slot, "item:", tostring(item))
                    check_and_add_result(cont, slot, item)
                end
            end
        end
    end

    for _, storage_name in pairs(order) do
        if storage_name == "body" then
            DebugPrint("--- inventory ---")
            for slot, item in pairs(invent:GetItems()) do
                DebugPrint("slot:", slot, "item:", tostring(item))
                check_and_add_result(self.inst, slot, item)
            end
        elseif storage_name == "equip" then
            DebugPrint("--- equip ---")
            for slot, item in pairs(invent:GetEquips()) do
                DebugPrint("slot:", slot, "item:", tostring(item))
                check_and_add_result(self.inst, slot, item)
            end
        elseif storage_name == "mouse" then
            DebugPrint("--- mouse ---")
            check_and_add_result(self.inst, "mouse", self:GetActiveItem())
        elseif storage_name == "backpack" then
            DebugPrint("--- backpack ---")
            check_containers(backpack_list)
        elseif storage_name == "container" then
            DebugPrint("--- containers ---")
            check_containers(container_list)
        end
    end

    DebugPrint("Result:", result)
    return result
end

-- return.item: item object
-- return.slot: item position
-- return.container: cont_instst
function ActionQueuer:GetSlotFromAll(allowed_prefabs, tags_required, validate_func, order)
    return self:GetSlotsFromAll(allowed_prefabs, tags_required, validate_func, order)[1]
end

-- Pick up a certain item
function ActionQueuer:TakeActiveItemFromAllOfSlot(cont, slot, item_data)
    local count = 0
    while self:GetActiveItem() do
        if count % 5 == 0 then
            self.inst.replica.inventory:ReturnActiveItem()
        else
            -- Short wait
            Sleep(self.action_delay)
            DebugPrint("ReturnActiveItem short wait: ", count - math.floor(count / 5))
        end
        count = count + 1
    end
    local container = self:GetContainer(cont)
    if container then
        count = 0
        repeat
            if count % 5 == 0 then
                if type(slot) == "number" then
                    container:TakeActiveItemFromAllOfSlot(slot)
                else
                    container:TakeActiveItemFromEquipSlot(slot)
                end
            else
                -- Short wait
                Sleep(self.action_delay)
                DebugPrint("TakeActiveItem short wait: ", count - math.floor(count / 5))
            end
            count = count + 1
        until not item_data or self:GetActiveItem() == item_data.item
    end
end

function ActionQueuer:GetNewActiveItem(allowed_prefabs, tags_required, validate_func, order)
    DebugPrint("-------------------------------------")
    DebugPrint(
        "GetNewActiveItem: prefabs: ",
        allowed_prefabs,
        "tags_required: ",
        tags_required,
        "validate_func: ",
        validate_func
    )
    local current_time = GetTime()
    -- Make sure allowed_prefabs is a table (or nil)
    allowed_prefabs =
        (type(allowed_prefabs) == "string" and allowed_prefabs ~= "" and {allowed_prefabs}) or
        (type(allowed_prefabs) == "table" and allowed_prefabs) or
        nil

    local item_data = self:GetSlotFromAll(allowed_prefabs, tags_required, validate_func, order)
    if item_data then
        DebugPrint("item_data:", item_data)
        self:TakeActiveItemFromAllOfSlot(item_data.cont, item_data.slot, item_data)
        DebugPrint("GetNewActiveItem - Done")
        DebugPrint("Time took: ", GetTime() - current_time)
        return item_data.item
    end

    -- If we didn't find the required item
    if allowed_prefabs and table.contains(allowed_prefabs, "goldcoin") then
        -- in case the required item was "goldcoin", try to find a goldenpiggy and withdraw from it
        local goldenpiggy_data = self:GetSlotFromAll("goldenpiggy")
        if goldenpiggy_data then
            self.inst.replica.inventory:UseItemFromInvTile(goldenpiggy_data.item)

            -- long wait
            self:Wait()
        end
    end
end

function ActionQueuer:GetNewEquippedItemInHand(allowed_prefabs, tags_required, validate_func, order)
    DebugPrint("-------------------------------------")
    DebugPrint("GetNewEquippedItemInHand: prefabs:", allowed_prefabs, "tags_required:", tags_required)
    local current_time = GetTime()

    local item_data = self:GetSlotFromAll(allowed_prefabs, tags_required, validate_func, order)
    if item_data then
        DebugPrint("item_data:", item_data)
        local count = 0
        repeat
            if count % 5 == 0 then
                SendRPCToServer(RPC.ControllerUseItemOnSelfFromInvTile, ACTIONS.EQUIP.code, item_data.item)
            else
                -- Short wait
                Sleep(self.action_delay)
                DebugPrint("GetNewEquippedItemInHand short wait: ", count - math.floor(count / 5))
            end
            count = count + 1
        until self:GetEquippedItemInHand() == item_data.item
        DebugPrint("GetNewEquippedItemInHand - Done")
        DebugPrint("Time took: ", GetTime() - current_time)
        return item_data.item
    end
end

-- 250320 VanCa: Unequip Item
-- not_mouse: if true: can't unequip the equipment on the mouse
-- roughly determine whether there is an empty slot within the inventory and backpack, if they're already full then return.
-- reference: 呼吸
function ActionQueuer:UnEquip(item, not_mouse)
    DebugPrint("-------------------------------------")
    DebugPrint("UnEquip item:", tostring(item), "not_mouse: ", not_mouse)
    local invent = self.inst.replica.inventory
    if not_mouse then
        local equips = invent:GetEquips() or {}
        local backpack
        for eslot, equip in pairs(equips) do
            backpack = equip:HasTag("backpack") and equip
        end
        local backpack_cont = ActionQueuer:GetContainer(backpack)

        if invent:IsFull() and (not backpack_cont or backpack_cont:IsFull()) then
            -- Inventory & backpack are full, can't unequip
            return false
        end
    end

    if item and item:HasTag("heavy") then
        invent:DropItemFromInvTile(item)
    else
        if TheWorld and TheWorld.ismastersim then
            invent:ControllerUseItemOnSelfFromInvTile(item)
        else
            SendRPCToServer(RPC.ControllerUseItemOnSelfFromInvTile, ACTIONS.UNEQUIP.code, item)
        end
    end
end

function ActionQueuer:Wait(action, target, rightclick)
    DebugPrint("-------------------------------------")
    DebugPrint("Wait: action: ", tostring(action), "target: ", tostring(target), "rightclick: ", rightclick)
    local current_time = GetTime()

    if action and CheckAllowedActions("noworkdelay", action, target, self) then
        DebugPrint("Short wait")
        while true do
            Sleep(self.action_delay)
            if action == ACTIONS.PICKUP then
                if
                    not IsValidEntity(target) and not (self.inst.sg and self.inst.sg:HasStateTag("moving")) and
                        not self.inst:HasTag("moving") or
                        self.inst:HasTag("idle")
                        -- or not self.inst.components.playercontroller:IsDoingOrWorking()
                 then
                    break
                end
            elseif not (self.inst.sg and self.inst.sg:HasStateTag("moving")) and not self.inst:HasTag("moving") then
                break
            end
        end
    else
        DebugPrint("Long wait")
        Sleep(self.work_delay)
        repeat
            Sleep(self.action_delay)
        until not (self.inst.sg and self.inst.sg:HasStateTag("moving")) and not self.inst:HasTag("moving") and
            self.inst:HasTag("idle") and
            not self.inst.components.playercontroller:IsDoingOrWorking()
    end
    DebugPrint("Time waited:", GetTime() - current_time)

    if action == ACTIONS.ADDCOMPOSTABLE and target.prefab == "compostingbin" then
        local client_memory = self.selected_ents_client_memory[target]
        if not client_memory.CheckFull then
            local check_full_start_timer = GetTime()
            local is_full = true
            client_memory.CheckFull =
                target:DoPeriodicTask(
                0.1,
                function()
                    local player_anim = GetAnimation(ThePlayer)
                    if
                        is_full ~= nil and table.contains({"give", "give_pst"}, player_anim) and
                            not client_memory.CheckUse
                     then
                        local check_use_start_timer = GetTime()
                        client_memory.CheckUse =
                            target:DoPeriodicTask(
                            0.1,
                            function()
                                if not target.AnimState:IsCurrentAnimation("working") then
                                    is_full = false
                                end
                                if (not is_full or GetTime() - check_use_start_timer > 0.4) and client_memory.CheckUse then
                                    client_memory.is_full = is_full
                                    is_full = nil
                                    client_memory.CheckUse:Cancel()
                                    client_memory.CheckUse = nil
                                end
                            end
                        )
                    end
                    if (not is_full or GetTime() - check_full_start_timer > 0.4) and client_memory.CheckFull then
                        client_memory.CheckFull:Cancel()
                        client_memory.CheckFull = nil
                        DebugPrint(check_full_start_timer, "end CheckFull")
                    end
                end
            )
        end
    end
end

function ActionQueuer:GetAction(target, rightclick, pos, active_item, item_in_hand)
    DebugPrint("-------------------------------------")
    DebugPrint("GetAction: target:", tostring(target), "rightclick:", rightclick)
    local pos = pos or target:GetPosition()

    if target then
        if target.prefab == "ocean_water_source" then
            target = nil
        end
    end

    local playeractionpicker = self.inst.components.playeractionpicker
    -- Rightclick
    if rightclick then
        if target and target.prefab == "nutrients_overlay" then
            active_item = active_item or self:GetActiveItem()
            item_in_hand = item_in_hand or self:GetEquippedItemInHand()

            -- Watering farm tile
            if
                (item_in_hand and (item_in_hand.prefab == "wateringcan" or item_in_hand.prefab == "premiumwateringcan")) or
                    (active_item and (active_item.prefab == "wateringcan" or active_item.prefab == "premiumwateringcan"))
             then
                -- Fertilizing farm tile
                -- Dummy action to get through validates
                return BufferedAction(self.inst, nil, ACTIONS.POUR_WATER_GROUNDTILE, nil, pos), true
            elseif active_item and (active_item:HasTag("fertilizer")) then
                -- Dummy action to get through validates
                return BufferedAction(self.inst, nil, ACTIONS.DEPLOY_TILEARRIVE, active_item, pos), true
            end
        end
        for _, act in ipairs(playeractionpicker:GetRightClickActions(pos, target)) do
            DebugPrint("check right click act:", act.action.id)
            if CheckAllowedActions("rightclick", act.action, target, self) then
                DebugPrint("Allowed rightclick action:", act.action.id)
                return act, true
            end
        end
    end
    -- Leftclick
    for _, act in ipairs(playeractionpicker:GetLeftClickActions(pos, target)) do
        DebugPrint("check left click act:", act.action.id)
        if
            not rightclick and CheckAllowedActions("leftclick", act.action, target, self) or
                CheckAllowedActions("allclick", act.action, target, self)
         then
            -- 250613 VanCa: Prevent Take-Give loop with gelblob_storage in some case
            local saved_act =
                self.selected_ents_client_memory[target] and self.selected_ents_client_memory[target].saved_act
            if saved_act and saved_act.action == act.action or not saved_act then
                DebugPrint("Allowed leftclick action:", act.action.id)
                return act, false
            end
        end
    end
    DebugPrint("No allowed action for target:", tostring(target))
    return nil
end

function ActionQueuer:SendAction(act, rightclick, target)
    DebugPrint("-------------------------------------")
    DebugPrint("SendAction: act:", act.action.id, "rightclick:", rightclick, "target:", tostring(target))
    local playercontroller = self.inst.components.playercontroller
    if playercontroller.ismastersim then
        self.inst.components.combat:SetTarget(nil)
        playercontroller:DoAction(act)
        return
    end
    local pos = act:GetActionPoint() or self.inst:GetPosition()

    -- CONTROL_FORCE_STACK (8)  - 1
    -- CONTROL_FORCE_TRADE (4)  - 0
    -- CONTROL_FORCE_ATTACK (2) - 1
    -- CONTROL_FORCE_INSPECT (1) - 0
    -- controlmods == 10 == 1010 == FORCE_STACK + FORCE_ATTACK
    local controlmods

    -- 250320 VanCa: Those item won't work with controlmods
    if target and target.prefab ~= "gelblob_storage" and target.prefab ~= "winona_catapult" then
        controlmods = 10 --force stack and force attack
    end

    if playercontroller.locomotor then
        act.preview_cb = function()
            if rightclick then
                SendRPCToServer(
                    RPC.RightClick,
                    act.action.code,
                    pos.x,
                    pos.z,
                    target,
                    act.rotation,
                    true,
                    nil,
                    nil,
                    act.action.mod_name
                )
            else
                SendRPCToServer(
                    RPC.LeftClick,
                    act.action.code,
                    pos.x,
                    pos.z,
                    target,
                    true,
                    controlmods,
                    nil,
                    act.action.mod_name
                )
            end
        end
        playercontroller:DoAction(act)
    else
        if rightclick then
            SendRPCToServer(
                RPC.RightClick,
                act.action.code,
                pos.x,
                pos.z,
                target,
                act.rotation,
                true,
                nil,
                act.action.canforce,
                act.action.mod_name
            )
        else
            SendRPCToServer(
                RPC.LeftClick,
                act.action.code,
                pos.x,
                pos.z,
                target,
                true,
                controlmods,
                act.action.canforce,
                act.action.mod_name
            )
        end
    end
end

function ActionQueuer:SendActionAndWait(act, rightclick, target)
    DebugPrint("-------------------------------------")
    DebugPrint("SendActionAndWait: target:", tostring(target))
    if target and target.prefab == "ocean_water_source" then
        target = nil
    end

    if target then
        if self.drag_click_selected_flag or self.double_click_flag then
            local highlight = target.components.highlight
            if highlight then
                highlight.highlight_add_colour_red = nil
                highlight.highlight_add_colour_green = nil
                highlight.highlight_add_colour_blue = nil
                -- green
                --highlight:SetAddColour({x = 0/255*0.5, y = 153/255*0.5, z = 85/255*0.5})
                -- blue
                --highlight:SetAddColour({x = 20/255 * 0.5, y = 174/255 * 0.5, z = 213/255 * 0.5})
                -- pink
                highlight:SetAddColour(
                    {
                        x = 255 / 255 * self.highlight_opacity,
                        y = 192 / 255 * self.highlight_opacity,
                        z = 203 / 255 * self.highlight_opacity
                    }
                )
            end
        end

        if act.action.id == "GIVE" then
            -- 241003 Auto wake caged bird
            -- If the bird is sleeping
            if
                target.prefab == "birdcage" and
                    (target.AnimState:IsCurrentAnimation("sleep_loop") or
                        target.AnimState:IsCurrentAnimation("sleep_pre"))
             then
                -- Save what we're giving to the bird, then put it back to inventory
                -- To trigger HARVEST action
                local active_item = self:GetActiveItem()
                self.inst.replica.inventory:ReturnActiveItem()

                DebugPrint("Trigger a HARVEST action to take out the bird")
                act = BufferedAction(self.inst, nil, ACTIONS.HARVEST, nil, nil)
                self:SendAction(act, false, target)
                self:Wait(act.action, target)

                while true do
                    DebugPrint("Take the bird from inventory")
                    self:GetNewActiveItem(nil, "bird")
                    DebugPrint("Put the bird back to the cage")
                    act = self:GetAction(target, false)
                    if act and act:IsValid() then
                        -- (STORE action)
                        break
                    else
                        Sleep(self.work_delay)
                    end
                end
                self:SendAction(act, false, target)
                self:Wait(act.action, target)

                DebugPrint("Take back what we were giving to the bird")
                self:GetNewActiveItem(active_item.prefab)

                -- (GIVE action)
                while true do
                    act = self:GetAction(target, false)
                    if not act or act.action.id ~= "GIVE" then
                        self:Wait()
                    else
                        break
                    end
                end
            end
        end
    else
        -- Non target action (ex: ??)
    end

    self:SendAction(act, rightclick, target)
    self:Wait(act.action, target, rightclick)

    -- 250219 VanCa: Prevent once opened Ornate Chest from being added to the selected_list again
    if act.action == ACTIONS.RUMMAGE then
        self.selected_ents_client_memory[target].skip_this_target = true
    end

    -- 250307 VanCa: support switching wateringCan when refill (leftclick)
    if act.action == ACTIONS.FILL and not rightclick then
        local item_in_hand = self:GetEquippedItemInHand()
        if item_in_hand and (item_in_hand.prefab == "wateringcan" or item_in_hand.prefab == "premiumwateringcan") then
            DebugPrint("The holding watering can is full")
            if
                not self:GetNewActiveItem(
                    {"wateringcan", "premiumwateringcan"},
                    nil,
                    function(item)
                        return self:GetItemPercent(item) < 100
                    end
                )
             then
                self:DeselectEntity(target)
            end
        end
    end

    -- 250415 VanCa: Auto drop the deck when stacking cards
    if act.action == ACTIONS.ADD_CARD_TO_DECK and target.prefab == "playing_card" then
        local active_item = self:GetActiveItem()
        if active_item and active_item.prefab == "deck_of_cards" then
            self:DropActiveItem(self.inst:GetPosition(), active_item)
            self:SelectEntity(active_item, rightclick)
        end
    end
    DebugPrint("SendActionAndWait end")
end

function ActionQueuer:SetHighlightOpacity(opacity)
    DebugPrint("-------------------------------------")
    DebugPrint("SetHighlightOpacity: opacity:", opacity)
    self.highlight_opacity = opacity
end

function ActionQueuer:SetSelectionColor(r, g, b, a)
    DebugPrint("-------------------------------------")
    DebugPrint("SetSelectionColor: r:", r, "g:", g, "b:", b, "a:", a)
    self.selection_widget:SetTint(r, g, b, a)
    self.color.x = r * self.highlight_opacity
    self.color.y = g * self.highlight_opacity
    self.color.z = b * self.highlight_opacity
end

function ActionQueuer:SelectionBox(rightclick)
    DebugPrint("-------------------------------------")
    DebugPrint("SelectionBox: rightclick:", rightclick)
    local previous_ents = {}
    local started_selection = false
    local start_x, start_y = self.screen_x, self.screen_y
    self.update_selection = function()
        if not started_selection then
            if math.abs(start_x - self.screen_x) + math.abs(start_y - self.screen_y) < 32 then
                return
            end
            started_selection = true
        end
        local xmin, xmax = start_x, self.screen_x
        if xmax < xmin then
            xmin, xmax = xmax, xmin
        end
        local ymin, ymax = start_y, self.screen_y
        if ymax < ymin then
            ymin, ymax = ymax, ymin
        end
        self.selection_widget:SetPosition((xmin + xmax) / 2, (ymin + ymax) / 2)
        self.selection_widget:SetSize(xmax - xmin + 2, ymax - ymin + 2)
        self.selection_widget:Show()
        self.TL, self.BL, self.TR, self.BR =
            GetWorldPosition(xmin, ymax),
            GetWorldPosition(xmin, ymin),
            GetWorldPosition(xmax, ymax),
            GetWorldPosition(xmax, ymin)
        --self.TL, self.BL, self.TR, self.BR = GetWorldPosition(xmin, ymin), GetWorldPosition(xmin, ymax), GetWorldPosition(xmax, ymin), GetWorldPosition(xmax, ymax)
        local center = GetWorldPosition((xmin + xmax) / 2, (ymin + ymax) / 2)
        local range =
            math.sqrt(
            math.max(center:DistSq(self.TL), center:DistSq(self.BL), center:DistSq(self.TR), center:DistSq(self.BR))
        )
        local IsBounded = GeoUtil.NewQuadrilateralTester(self.TL, self.TR, self.BR, self.BL)
        local current_ents = {}
        for _, ent in pairs(TheSim:FindEntities(center.x, 0, center.z, range, nil, unselectable_tags)) do
            if IsValidEntity(ent) then
                local pos = ent:GetPosition()
                if IsBounded(pos) then
                    if not self:IsSelectedEntity(ent) and not previous_ents[ent] then
                        local act, rightclick_ = self:GetAction(ent, rightclick, pos)
                        if act then
                            self:SelectEntity(ent, rightclick_, act)
                            if not self.double_click_flag then
                                DebugPrint("SelectionBox > drag_click_selected_flag = true")
                                self.drag_click_selected_flag = true
                            end
                        end
                    end
                    current_ents[ent] = true
                end
            end
        end
        for ent in pairs(previous_ents) do
            if not current_ents[ent] then
                self:DeselectEntity(ent)
            end
        end
        previous_ents = current_ents
    end
    self.selection_thread =
        StartThread(
        function()
            while self.inst:IsValid() do
                if self.queued_movement then
                    self.update_selection()
                    self.queued_movement = false
                end
                Sleep(FRAMES)
            end
            self:ClearSelectionThread()
        end,
        selection_thread_id
    )
end

-- 210705 null: added support for other mods to add their own CherryPick conditions
-- Requested by Tony for compatibility with Lazy Controls mod (https://steamcommunity.com/sharedfiles/filedetails/?id=2111412487)
function ActionQueuer:AddModCherryPickFn(fn) -- Allows other mods to add their own CherryPick functions to check custom conditions
    DebugPrint("-------------------------------------")
    DebugPrint("AddModCherryPickFn: fn:", fn)
    table.insert(mod_cherrypick_fns, fn)
end

function ActionQueuer:CanModCherryPick(ent) -- Check other mods' CherryPick conditions, if mod can CherryPick the ent, return true
    -- DebugPrint("CanModCherryPick: ent:", ent)
    if next(mod_cherrypick_fns) == nil then
        return false
    end
    for _, v in ipairs(mod_cherrypick_fns) do
        if type(v) == "function" and v(ent) then
            return true
        end
    end
    return false
end

-- reference: 呼吸
function ActionQueuer:AddAdjacentFarmTiles(init_tile, rightclick, target_pos)
    DebugPrint("-------------------------------------")
    DebugPrint(
        "AddAdjacentFarmTiles: init_tile:",
        tostring(init_tile),
        "rightclick:",
        rightclick,
        "target_pos:",
        target_pos
    )
    if target_pos then
        local player_pos = self.inst:GetPosition()
        local distance = math.sqrt(player_pos:DistSq(target_pos))
        DebugPrint("distance:", distance)
        if not TheWorld.Map:IsFarmableSoilAtPoint(target_pos.x, 0, target_pos.z) or distance > self.double_click_range then
            DebugPrint("Not a farm tile or out of range")
            return
        end

        -- Select farm tile
        for _, ent in pairs(TheWorld.Map:GetEntitiesOnTileAtPoint(target_pos.x, target_pos.y, target_pos.z)) do
            if ent.prefab == "nutrients_overlay" then
                if self:IsSelectedFarmTile(ent) then
                    -- Farm tile is already selected
                    -- "return" to prevent overlap recursion
                    return
                end
                self:SelectFarmTile(ent, rightclick)
                break
            end
        end
    else
        target_pos = init_tile:GetPosition()
    end

    -- Trigger a recursion to select adjacent (4 directions) farm tiles
    DebugPrint("North-West")
    self:AddAdjacentFarmTiles(
        init_tile,
        rightclick,
        {
            x = target_pos.x + 4,
            y = target_pos.y,
            z = target_pos.z
        }
    )
    DebugPrint("East-South")
    self:AddAdjacentFarmTiles(
        init_tile,
        rightclick,
        {
            x = target_pos.x - 4,
            y = target_pos.y,
            z = target_pos.z
        }
    )
    DebugPrint("South-West")
    self:AddAdjacentFarmTiles(
        init_tile,
        rightclick,
        {
            x = target_pos.x,
            y = target_pos.y,
            z = target_pos.z - 4
        }
    )
    DebugPrint("North-East")
    self:AddAdjacentFarmTiles(
        init_tile,
        rightclick,
        {
            x = target_pos.x,
            y = target_pos.y,
            z = target_pos.z + 4
        }
    )
end

function ActionQueuer:DoubleClick(rightclick, target)
    DebugPrint("-------------------------------------")
    DebugPrint("DoubleClick: rightclick:", rightclick, "target:", tostring(target))
    local pos = target.pos or target:GetPosition()
    local x, y, z = pos:Get()

    if target.prefab == "rock_avocado_bush" and (target.action == ACTIONS.PICK or target.action == ACTIONS.SCYTHE) then
        -- 210213 null: support for differentiating Stone Fruit Bushes in Pick (idle3) vs Crumble (idle4) state (blizstorm)
        -- 210315 null: support for isolating chopping of lvl 3 trees (blizstorm / Tranoze)
        local AnimstatePick = target.AnimState:IsCurrentAnimation("idle3") and "idle3" or "idle4"
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent.prefab == "rock_avocado_bush" and ent.AnimState:IsCurrentAnimation(AnimstatePick) then
                self:SelectEntity(ent, rightclick)
            end
        end
    elseif
        (target.action == ACTIONS.CHOP or target.action == ACTIONS.LIGHT) and
            -- 250414 VanCa: When Chopping or Lighting
            (target.prefab == "evergreen" or -- 210315 null: lvl 3 evergreen (blizstorm / Tranoze)
                target.prefab == "deciduoustree" or -- 210315 null: lvl 3 deciduous (blizstorm)
                target.prefab == "moon_tree" or -- 210322 null: lvl 3 lune trees
                target.prefab == "twiggytree" or -- 210322 null: lvl 3 twiggy trees
                target.prefab == "palmconetree" or -- 221010 cutlass: lvl 3 palmcone treesv
                target.prefab == "evergreen_sparse") and -- 240930 VanCa: lvl 3 Lumpy Evergreen | Cutlass updated this in ver 2.8
            (target.AnimState:IsCurrentAnimation("sway1_loop_tall") or
                target.AnimState:IsCurrentAnimation("sway2_loop_tall"))
     then -- Only check for lvl3/tall trees
        DebugPrint("Target is a lv3 tree:", target.prefab)
        -- 210322 null: support for isolating mining of lvl 3 marble trees
        -- Only check for lvl3/tall trees. Otherwise default to original CherryPick code.
        -- Double Click on Tall trees only CHOPs the Tall trees.
        -- Double Click on any other size tree CHOPs trees of all sizes (including Tall trees).
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if
                ent.prefab == target.prefab and
                    (ent.AnimState:IsCurrentAnimation("sway1_loop_tall") or
                        ent.AnimState:IsCurrentAnimation("sway2_loop_tall"))
             then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif target.prefab == "deciduoustree" and target:HasTag("monster") then
        -- 241030 VanCa: Chopping/lighting Poison Birchnut Tree won't select all nearby trees
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent.prefab == "deciduoustree" and ent:HasTag("monster") then
                self:SelectEntity(ent, rightclick)
            end
        end
    elseif (target.action == ACTIONS.DIG or target.action == ACTIONS.LIGHT) and target:HasTags({"tree", "DIG_workable"}) then
        -- 241028 VanCa: Do not distinguish between tree stumps when lighting/digging up roots
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent:HasTags({"tree", "DIG_workable"}) then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif
        target:HasTag("tree") and
            (target.AnimState:IsCurrentAnimation("idle_old") or target.AnimState:IsCurrentAnimation("sway1_loop_short") or
                target.AnimState:IsCurrentAnimation("sway2_loop_short"))
     then
        -- 241028 VanCa: Chopping old tree won't select all nearby trees anymore
        -- for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
        -- if
        -- ent.prefab == target.prefab and
        -- (ent.AnimState:IsCurrentAnimation("idle_old") then
        -- self:SelectEntity(ent, false)
        -- end
        -- end
    elseif target:HasTags({"tree", "burnt"}) or target.prefab == "cave_banana_burnt" then
        DebugPrint("Target is a burned tree:", target.prefab)
        -- 241013 VanCa: Added support for chopping burned trees.
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent:HasTags({"tree", "burnt"}) or ent.prefab == "cave_banana_burnt" then
                if
                    not (ent.AnimState:IsCurrentAnimation("chop_burnt") or
                        ent.AnimState:IsCurrentAnimation("chop_burnt_tall") or
                        ent.AnimState:IsCurrentAnimation("chop_burnt_normal") or
                        ent.AnimState:IsCurrentAnimation("chop_burnt_short"))
                 then
                    self:SelectEntity(ent, false)
                end
            end
        end
    elseif
        target.prefab == "marbleshrub" and target.action == ACTIONS.MINE and
            (target.AnimState:IsCurrentAnimation("idle_tall") or target.AnimState:IsCurrentAnimation("hit_tall"))
     then -- Only check for lvl3/tall marble trees
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if
                ent.prefab == target.prefab and
                    (ent.AnimState:IsCurrentAnimation("idle_tall") or ent.AnimState:IsCurrentAnimation("hit_tall"))
             then
                self:SelectEntity(ent, false)
            end
        end
    elseif string.find(target.prefab, "gargoyle_") and target.action == ACTIONS.MINE then
        -- 241030 VanCa: Mine all Suspicious Moonrock without distinction
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent.prefab and string.find(ent.prefab, "gargoyle_") then
                self:SelectEntity(ent, false)
            end
        end
    elseif target.prefab == "nutrients_overlay" then
        -- 241012 Vanca: Select nearby farm tiles (wartering, fertilizing,..)
        self:AddAdjacentFarmTiles(target, rightclick)
    elseif (target.prefab == "pandoraschest" or target.prefab == "chest_mimic") and target.action == ACTIONS.RUMMAGE then
        -- 250219 VanCa: Added support for RUMMAGE Ornate Chests
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if target.prefab == "pandoraschest" or target.prefab == "chest_mimic" then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif target.prefab == "gelblob_storage" and target.action == ACTIONS.TAKEITEM then
        -- 250222 VanCa: only take identical items from nearby gelblob_storage(s)
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent.prefab == target.prefab then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    if ent.takeitem:value().prefab == target.takeitem:value().prefab then
                        self:SelectEntity(ent, rightclick_, act)
                    end
                end
            end
        end
    elseif
        target.action == ACTIONS.DIG and target.prefab == "weed_forgetmelots" and
            target.AnimState:IsCurrentAnimation("crop_bloomed")
     then
        -- 250321 VanCa: Only select old forget-me-not when digging old forget-me-not
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent.prefab == "weed_forgetmelots" and ent.AnimState:IsCurrentAnimation("crop_bloomed") then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif (target.action == ACTIONS.DIG or target.action == ACTIONS.PICK) and target:HasTag("farm_plant_killjoy") then
        -- 250321 VanCa: Won't select normal plants when digging up rotten farm plants
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent.prefab == target.prefab and ent:HasTag("farm_plant_killjoy") then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif
        (target.action == ACTIONS.DIG or target.action == ACTIONS.PICK) and target:HasTags("farm_plant") and
            (target.AnimState:IsCurrentAnimation("crop_full") or target.AnimState:IsCurrentAnimation("crop_oversized"))
     then
        -- 250404 VanCa: Won't select unripe or rotten plants when digging/haverting farm plants
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if
                ent.prefab == target.prefab and
                    (ent.AnimState:IsCurrentAnimation("crop_full") or ent.AnimState:IsCurrentAnimation("crop_oversized"))
             then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif
        target.action == ACTIONS.DIG and target:HasTags("farm_plant") and
            (target.AnimState:IsCurrentAnimation("crop_seed") or target.AnimState:IsCurrentAnimation("crop_sprout") or
                target.AnimState:IsCurrentAnimation("crop_small") or
                target.AnimState:IsCurrentAnimation("crop_med"))
     then
        -- 250404 VanCa: Won't select grown plants when digging up growing farm plants
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if
                ent.prefab == target.prefab and
                    (ent.AnimState:IsCurrentAnimation("crop_seed") or ent.AnimState:IsCurrentAnimation("crop_sprout") or
                        ent.AnimState:IsCurrentAnimation("crop_small") or
                        ent.AnimState:IsCurrentAnimation("crop_med"))
             then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif
        target.action == ACTIONS.INTERACT_WITH and not target:HasTag("farm_plant_killjoy") and
            target:HasTags("farm_plant")
     then
        -- 250408 VanCa: Won't distinguish between types when talking to plants - except farm_plant_killjoy
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if not ent:HasTag("farm_plant_killjoy") and ent:HasTags("farm_plant") then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif table.contains({"chessjunk1", "chessjunk2", "chessjunk3"}, target.prefab) then
        -- 250414 VanCa: Won't distinguish between Broken Clockworks types
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if table.contains({"chessjunk1", "chessjunk2", "chessjunk3"}, ent.prefab) then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif target.action == ACTIONS.PICK and table.contains({"flower_cave", "flower_cave_double"}, target.prefab) then
        -- 250414 VanCa: Select all Light Flowers that have equal or better quality.
        local allow_list = {"flower_cave_double", "flower_cave_triple"}
        if target.prefab == "flower_cave" then
            table.insert(allow_list, "flower_cave")
        end
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if table.contains(allow_list, ent.prefab) then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif target.prefab:match("^singingshell_octave") then
        -- 250502 VanCa: Select all singingshell_octave shells
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent.prefab:match("^singingshell_octave") then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif target.prefab:match("^deer_antler") then
        -- 250613 VanCa: Select all kinds of deer_antler
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent.prefab:match("^deer_antler") then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif target.prefab == "blueprint" then
        -- 250613 VanCa: Only pick up blueprints with the same name
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if ent.prefab == target.prefab and ent.name == target.name then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_)
                end
            end
        end
    elseif target.action == ACTIONS.REMOVELUNARBUILDUP then
        -- 250919 VanCa: Select all nearby prefab that has lunar hail builded-up
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            local act, rightclick_ = self:GetAction(ent, rightclick)
            if act and act.action == target.action then
                self:SelectEntity(ent, rightclick_)
            end
        end
    else
        DebugPrint("Not a special target:", target.prefab)
        -- 210705 null: added support for other mods to add their own CherryPick conditions
        for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.double_click_range, nil, unselectable_tags)) do
            if
                (ent.prefab == target.prefab or -- Original CherryPick condition
                    self:CanModCherryPick(ent)) and -- 210705 null: Other mods' CherryPick conditions (if true, select the ent)
                    IsValidEntity(ent) and
                    not self:IsSelectedEntity(ent)
             then
                local act, rightclick_ = self:GetAction(ent, rightclick)
                if act and act.action == target.action then
                    self:SelectEntity(ent, rightclick_, act)
                end
            end
        end
    end
    return
end

function ActionQueuer:CherryPick(rightclick)
    DebugPrint("-------------------------------------")
    DebugPrint("CherryPick: rightclick:", rightclick)
    DebugPrint("self.last_target_ent", tostring(self.last_target_ent))
    local current_time = GetTime()
    local activeItem
    local item_in_hand

    if current_time - self.last_click.time < self.double_click_speed and self.last_click.prefab then
        DebugPrint("Double click: true")
        DebugPrint("self.last_click.prefab:", self.last_click.prefab)
        -- While in drag_click_selected mode, [shift + double click] won't start a recursion queue, only add nearby Entities to the Selected list,
        if not self.drag_click_selected_flag then
            -- Start a recursion [shift + double click] queue: Before performing an action on an entity, automatically trigger [shift + double click] on that entity to add nearby Entities to the Selected list
            self.double_click_flag = true
        end

        self:DoubleClick(rightclick, self.last_click)

        -- Prevent triple click?
        -- old code: self.last_click.prefab = nil
        -- 241013 VanCa: prevent triple click without affects entity prefab: current_time - last_click.time > double_click_speed
        self.last_click.time = 0
        return
    end

    local allEntitiesUnderMouse = TheInput:GetAllEntitiesUnderMouse()
    local pos = TheInput:GetWorldPosition()

    activeItem = self:GetActiveItem()
    if activeItem then
        if activeItem:HasTag("bucket_empty") then
            -- (Dehydrated) Can't get any target entity when taking water from ocean, so create a dummy temporary one
            DebugPrint("pos:", pos)
            local null_target = CreateEntity()
            null_target.prefab = "ocean_water_source"
            null_target.entity:AddTransform()
            null_target.Transform:SetPosition(pos:Get())

            table.insert(allEntitiesUnderMouse, null_target)
        end
    end

    -- Add farm tiles to the Entities under mouse list (needed when Watering, fertilizing)
    for _, ent in pairs(TheWorld.Map:GetEntitiesOnTileAtPoint(pos.x, pos.y, pos.z)) do
        if ent.prefab == "nutrients_overlay" then -- Look for tile's nutrients_overlay entity, that's a farm tile
            table.insert(allEntitiesUnderMouse, ent)
            break
        end
    end

    -- 250613 VanCa: Make storing food into gelblob_storage easier
    if activeItem and not rightclick then
        for _, entity in ipairs(allEntitiesUnderMouse) do
            if entity.prefab == "gelblob_storage" then
                local pos = entity:GetPosition()
                for _, ent in pairs(
                    TheSim:FindEntities(pos.x, 0, pos.z, self.double_click_range, nil, unselectable_tags)
                ) do
                    if entity ~= ent and ent.prefab == "gelblob_storage" then
                        table.insert(allEntitiesUnderMouse, ent)
                    end
                end
                break
            end
        end
    end

    DebugPrint("allEntitiesUnderMouse:", allEntitiesUnderMouse)

    for _, ent in ipairs(allEntitiesUnderMouse) do
        DebugPrint("ent:", ent)
        if ent.takeitem then
            DebugPrint("ent.takeitem:", ent.takeitem:value())
        end
        DebugPrint("DebugString:", ent:GetDebugString())
        if self.selected_ents[ent] ~= nil then
            -- Make manual deselect easier
            self:DeselectEntity(ent)
        else
            if IsValidEntity(ent) then
                DebugPrint("CherryPick > Entity is valid:", tostring(ent))

                -- 250411 VanCa: Support refill watering can with leftclick
                if not rightclick and not activeItem and ent:HasTag("watersource") then
                    item_in_hand = self:GetEquippedItemInHand()
                    if
                        item_in_hand and
                            (item_in_hand.prefab == "wateringcan" or item_in_hand.prefab == "premiumwateringcan")
                     then
                        rightclick = true
                    end
                end

                local act, rightclick_ = self:GetAction(ent, rightclick, nil, activeItem, item_in_hand)
                DebugPrint("act:", tostring(act), "rightclick_:", rightclick_)
                if act then
                    if ent.prefab == "nutrients_overlay" then
                        self:SelectFarmTile(ent, rightclick_)
                    else
                        self:ToggleEntitySelection(ent, rightclick_, act)
                    end

                    -- -- Original CherryPick code
                    -- self.last_click = {prefab = ent.prefab, pos = ent:GetPosition(), action = act.action, time = current_time}

                    -- 210213 null: save AnimState to support Stone Fruit Bush Pick (idle3) vs Crumble (idle4) state (blizstorm)
                    -- 241013 VanCa: save the whole ent to support finding nearby burned trees (need HasTags function)
                    self.last_click = ent
                    self.last_click.action = act.action
                    self.last_click.time = current_time

                    self.inst:DoTaskInTime(
                        self.double_click_speed,
                        function(inst)
                            local actions_allowed_to_repeat_with_one_click = {
                                "GIVE",
                                "GIVEWATER",
                                "TAKEWATER",
                                "FILL",
                                "ADDCOMPOSTABLE"
                            }
                            local targets_allowed_to_repeat_with_one_click = {
                                "well",
                                "campkettle",
                                "campdesalinator",
                                "desalinator"
                            }
                            if self.action_thread then
                                if
                                    (table.contains(actions_allowed_to_repeat_with_one_click, act.action.id) or
                                        table.contains(targets_allowed_to_repeat_with_one_click, ent.prefab)) and
                                        not self.double_click_flag and
                                        not self.drag_click_selected_flag
                                 then
                                    -- when executing those actions, "shift + single click" is treated the same as drag_click_selected an item, repeat 4ever
                                    DebugPrint(
                                        self.double_click_speed ..
                                            "sec has passed, 'shift + single click' now being treated the same as drag_click_selected an item"
                                    )
                                    self.drag_click_selected_flag = true
                                    DebugPrint("drag_click_selected_flag:", self.drag_click_selected_flag)
                                end
                            end
                        end
                    )
                    break
                end
            else
                DebugPrint("CherryPick > Not a valid entity:", tostring(ent))
            end
        end
    end
end

function ActionQueuer:OnDown(rightclick)
    DebugPrint("OnDown: rightclick:", rightclick)
    self:ClearSelectionThread()
    if self.inst:IsValid() and not IsHUDEntity() then
        DebugPrint("Start new queue")
        self.clicked = true
        self:SelectionBox(rightclick)
        self:CherryPick(rightclick)
    end
end

function ActionQueuer:OnUp(rightclick)
    DebugPrint("-------------------------------------")
    DebugPrint("OnUp: rightclick:", rightclick)

    -- 210702 null: fix for Klei's mouse queue bug, clear Klei's own action queue
    ThePlayer.components.playercontroller:ClearActionHold()

    self:ClearSelectionThread()
    if self.clicked then
        self.clicked = false
        if self.action_thread then
            return
        end
        if self:IsWalkButtonDown() then
            DebugPrint("Walk button pressed")
            self:ClearSelectedEntities()
        elseif next(self.selected_ents) then
            self:ApplyToSelection()
        elseif rightclick then
            local active_item = self:GetActiveItem()
            if active_item then
                if easy_stack[active_item.prefab] then
                    local ent = TheInput:GetWorldEntityUnderMouse()
                    if ent and ent:HasTag(easy_stack[active_item.prefab]) then
                        local act = BufferedAction(self.inst, nil, ACTIONS.DEPLOY, active_item, ent:GetPosition())
                        self:SendAction(act, true)
                        return
                    end
                end

                -- 201224 null: added basic support for Fertilizing of farming tiles
                if active_item:HasTag("fertilizer") then
                    -- local pos = GetWorldPositionUnderMouse() -- Tiles aren't entities, so try getting pos under mouse cursor
                    local pos = TheInput:GetWorldPosition() -- 210127 null: Tiles aren't entities, so get pos under mouse cursor
                    if pos and TheWorld.Map:IsFarmableSoilAtPoint(pos.x, 0, pos.z) then -- This might not be best way to do this
                        self:FertilizeTile(pos, active_item) -- Fertilize a single tile multiple times
                    else
                        self:DeployToSelection(self.FertilizeAtPoint, 4, active_item) -- Fertilize multiple tiles
                    end
                    return
                end

                -- 210103 null: added basic support for Wormwood planting
                if ThePlayer:HasTag("plantkin") and active_item:HasTag("deployedfarmplant") then
                    if not self.TL then
                        return
                    end
                    local cx, cz = (self.TL.x + self.BR.x) / 2, (self.TR.z + self.BL.z) / 2 -- Get SelectionBox() center coords
                    if (cx and cz) and TheWorld.Map:IsFarmableSoilAtPoint(cx, 0, cz) then -- if center = soil tile
                        self:DeployToSelection(self.WormwoodPlantAtPoint, farm_spacing, active_item) -- Snap to farm grid
                    else
                        self:DeployToSelection(self.DeployActiveItem, farm_spacing, active_item) -- Plant normally
                    end
                    return
                end

                -- 250306 VanCa: Equip the ActiveItem (wateringcan) if the watering queue has been started while holding a wateringcan in ActiveItem slot
                local equip_item = self:GetEquippedItemInHand()
                if active_item.prefab == "wateringcan" or active_item.prefab == "premiumwateringcan" then
                    self.inst.replica.inventory:EquipActiveItem()
                else
                    if active_item.replica.inventoryitem:IsDeployable(self.inst) then
                        return self:DeployToSelection(self.DeployActiveItem, GetDeploySpacing(active_item), active_item)
                    else
                        return self:DeployToSelection(self.DropActiveItem, GetDropSpacing(active_item), active_item)
                    end
                end
            end
            local equip_item = self:GetEquippedItemInHand()
            if equip_item and (equip_item.prefab == "pitchfork" or equip_item.prefab == "goldenpitchfork") then
                -- 210107 null: added support for Watering of farming tiles (single tile until full or multiple tiles once each)
                self:DeployToSelection(self.TerraformAtPoint, 4, equip_item)
            elseif equip_item and (equip_item.prefab == "wateringcan" or equip_item.prefab == "premiumwateringcan") then
                DebugPrint("WaterTile drag_click_selected_flag:", self.drag_click_selected_flag)
                DebugPrint("WaterTile double_click_flag:", self.double_click_flag)
                -- 201217 null: added support for Tilling of farming tiles
                -- 210202 null: first check if selection box is being used
                if not self.TL or (math.abs(self.TL.x - self.BR.x) + math.abs(self.TR.z - self.BL.z) < 1) then -- if single click
                    local pos = TheInput:GetWorldPosition() -- 210127 null: Tiles aren't entities, so get pos under mouse cursor
                    if pos and TheWorld.Map:IsFarmableSoilAtPoint(pos.x, 0, pos.z) then
                        self:WaterTile(equip_item) -- 210107 null: Water a single tile until full moisture
                    end
                else -- if selection box
                    self:DeployToSelection(self.WaterAtPoint, 4, equip_item) -- 201217 null: Water multiple tiles
                end
            elseif
                equip_item and
                    (equip_item.prefab == "farm_hoe" or equip_item.prefab == "golden_farm_hoe" or
                        equip_item.prefab == "shovel_lunarplant")
             then
                self:DeployToSelection(self.TillAtPoint, farm_spacing, equip_item)
            end
        elseif self.inst.components.playercontroller.placer then
            local playercontroller = self.inst.components.playercontroller
            local recipe = playercontroller.placer_recipe
            local rotation = playercontroller.placer:GetRotation()
            local skin = playercontroller.placer_recipe_skin
            local builder = self.inst.replica.builder
            local spacing = recipe.min_spacing > 2 and 4 or 2
            return self:DeployToSelection(
                function(self, pos, item)
                    if not builder:IsBuildBuffered(recipe.name) then
                        if not builder:CanBuild(recipe.name) then
                            return false
                        end
                        builder:BufferBuild(recipe.name)
                    end
                    if builder:CanBuildAtPoint(pos, recipe, rotation) then
                        builder:MakeRecipeAtPoint(recipe, pos, rotation, skin)
                        self:Wait()
                    end
                    return true
                end,
                spacing
            )
        end
    end
end

function ActionQueuer:DeployToSelection(deploy_fn, spacing, item)
    DebugPrint("-------------------------------------")
    DebugPrint("DeployToSelection: deploy_fn:", deploy_fn, "spacing:", spacing, "item:", item)
    if not self.TL then
        DebugPrint("(build_with_vanilla_grid)")
        return "build_with_vanilla_grid"
    end

    -- 210116 null: cases for snapping positions to farm grid (Tilling, Wormwood planting on soil tiles, etc)
    local snap_farm = false
    if deploy_fn == self.TillAtPoint or deploy_fn == self.WormwoodPlantAtPoint then
        snap_farm = true
    end
    if snap_farm then
        if farm_grid == "4x4" then
            spacing = 1.26 -- 210116 null: different spacing for 4x4 grid
        elseif farm_grid == "2x2" then
            spacing = 2 -- 210609 null: different spacing for 2x2 grid
        end
    end

    local heading, dir = GetHeadingDir()
    local diagonal = heading % 2 ~= 0
    DebugPrint("Heading:", heading, "Diagonal:", diagonal, "Spacing:", spacing)
    DebugPrint("TL:", self.TL, "TR:", self.TR, "BL:", self.BL, "BR:", self.BR)
    local X, Z = "x", "z"
    if dir then
        X, Z = Z, X
    end
    local spacing_x = self.TL[X] > self.TR[X] and -spacing or spacing
    local spacing_z = self.TL[Z] > self.BL[Z] and -spacing or spacing
    local adjusted_spacing_x = diagonal and spacing * 1.4 or spacing
    local adjusted_spacing_z = diagonal and spacing * 0.7 or spacing
    local width = math.floor(self.TL:Dist(self.TR) / adjusted_spacing_x)
    local height =
        self.endless_deploy and 100 or
        math.floor(self.TL:Dist(self.BL) / (width < 1 and adjusted_spacing_x or adjusted_spacing_z))
    DebugPrint("Width:", width + 1, "Height:", height + 1) --since counting from 0
    local start_x, _, start_z = self.TL:Get()
    local terraforming = false

    if
        deploy_fn == self.WaterAtPoint or -- 201217 null: added support for Watering of farming tiles
            deploy_fn == self.FertilizeAtPoint or -- 201223 null: added support for Fertilizing of farming tiles
            deploy_fn == self.TerraformAtPoint or
            item and item:HasTag("groundtile")
     then
        start_x, _, start_z = TheWorld.Map:GetTileCenterPoint(start_x, 0, start_z)
        terraforming = true
    elseif deploy_fn == self.DropActiveItem or item and (item:HasTag("wallbuilder") or item:HasTag("fencebuilder")) then
        -- 210116 null: adjust farm grid start position + offsets (thanks to blizstorm for help)
        start_x, start_z = math.floor(start_x) + 0.5, math.floor(start_z) + 0.5
    elseif snap_farm then
        -- 210709 null: fix for 3x3 alignment on medium/huge servers (different tile offsets)
        local tilecenter = _G.Point(_G.TheWorld.Map:GetTileCenterPoint(start_x, 0, start_z)) -- center of tile
        local tilepos = _G.Point(tilecenter.x - 2, 0, tilecenter.z - 2) -- corner of tile
        if tilecenter.x % 4 == 0 then -- if center of tile is divisible by 4, then it's a medium/huge server
            farm3x3_offset = farm_spacing -- adjust offset for medium/huge servers for 3x3 grid
        end

        if farm_grid == "4x4" then -- 4x4 grid
            -- 4x4 grid: spacing = 1.26, offset/margins = 0.11
            start_x, start_z =
                tilepos.x + math.floor((start_x - tilepos.x) / 1.26 + 0.5) * 1.26 + 0.11 * offsets_4x4[heading].x,
                tilepos.z + math.floor((start_z - tilepos.z) / 1.26 + 0.5) * 1.26 + 0.11 * offsets_4x4[heading].z
        elseif farm_grid == "2x2" then -- 210609 null: 2x2 grid: spacing = 2 (4/2), offset = 1 (4/2/2)
            start_x, start_z = math.floor(start_x / 2) * 2 + 1, math.floor(start_z / 2) * 2 + 1
        else -- 3x3 grid: spacing = 1.333 (4/3), offset = 0.665 (4/3/2)
            -- 210202 null: remove +0.5 floored rounding for more consistent wormwood placements (blizstorm)
            -- 210202 null: use more precise 3x3 grid offset for better alignment at edge of maps
            -- start_x, start_z = math.floor(start_x * 0.75 + 0.5) * 1.333 + 0.665,
            --                    math.floor(start_z * 0.75 + 0.5) * 1.333 + 0.665

            -- 210201 null: /0.75 (3/4) instead of *1.333 (4/3) to better support edge of large -1600 to 1600 maps (blizstorm)
            -- start_x, start_z = math.floor(start_x * 0.75 + 0.5) / 0.75 + 0.665,
            --                    math.floor(start_z * 0.75 + 0.5) / 0.75 + 0.665
            start_x, start_z =
                math.floor(start_x / farm_spacing) * farm_spacing + farm3x3_offset,
                math.floor(start_z / farm_spacing) * farm_spacing + farm3x3_offset
        end
    elseif self.deploy_on_grid then -- 210201 null: deploy_on_grid = last to avoid conflict with farm grids (blizstorm)
        start_x, start_z = math.floor(start_x * 2 + 0.5) * 0.5, math.floor(start_z * 2 + 0.5) * 0.5
    end

    local cur_pos = Point()
    local count = {x = 0, y = 0, z = 0}
    local row_swap = 1

    -- 210127 null: added support for snaking within snaking for faster deployment (thanks to blizstorm)
    local step = 1
    local countz2 = 0
    local countStep = {{0, 1}, {1, 0}, {0, -1}, {1, 0}}
    if height < 1 then
        countStep = {{1, 0}, {1, 0}, {1, 0}, {1, 0}}
    end -- 210130 null: bliz fix (210127)

    self.action_thread =
        StartThread(
        function()
            self.inst:ClearBufferedAction()
            while self.inst:IsValid() do
                cur_pos.x = start_x + spacing_x * count.x
                cur_pos.z = start_z + spacing_z * count.z
                if diagonal then
                    if width < 1 then
                        if count[Z] > height then
                            break
                        end
                        count[X] = count[X] - 1
                        count[Z] = count[Z] + 1
                    else
                        local row = math.floor(count.y / 2)
                        if count[X] + row > width or count[X] + row < 0 then
                            count.y = count.y + 1
                            if count.y > height then
                                break
                            end
                            row_swap = -row_swap
                            count[X] = count[X] + row_swap - 1
                            count[Z] = count[Z] + row_swap
                            cur_pos.x = start_x + spacing_x * count.x
                            cur_pos.z = start_z + spacing_z * count.z
                        end
                        count.x = count.x + row_swap
                        count.z = count.z + row_swap
                    end
                else
                    if double_snake then -- 210127 null: snake within snake deployment (thanks to blizstorm)
                        if count[X] > width or count[X] < 0 then
                            countz2 = countz2 + 2 -- assume first that next major row can be progressed since this is the case most of the time (blizstorm)

                            -- if countz2 > height then -- old bliz code (210115)
                            if countz2 + 1 > height then -- 210130 null: bliz fix (210127)
                                -- if countz2 - 1 > height then -- old bliz code (210115)
                                -- if countz2 - 1 <= height then -- old bliz code (210122)
                                if countz2 <= height then -- 210130 null: bliz fix (210127)
                                    -- countz2 = countz2 - 1 -- old bliz code (210115)
                                    countStep = {{1, 0}, {1, 0}, {1, 0}, {1, 0}}
                                else
                                    break
                                end
                            end

                            step = 1
                            row_swap = -row_swap
                            count[X] = count[X] + row_swap
                            count[Z] = countz2
                            cur_pos.x = start_x + spacing_x * count.x
                            cur_pos.z = start_z + spacing_z * count.z
                        end
                        count[X] = count[X] + countStep[step][1] * row_swap
                        count[Z] = count[Z] + countStep[step][2]
                        step = step % 4 + 1
                    else -- Regular snaking deployment
                        if count[X] > width or count[X] < 0 then
                            count[Z] = count[Z] + 1
                            if count[Z] > height then
                                break
                            end
                            row_swap = -row_swap
                            count[X] = count[X] + row_swap
                            cur_pos.x = start_x + spacing_x * count.x
                            cur_pos.z = start_z + spacing_z * count.z
                        end
                        count[X] = count[X] + row_swap
                    end
                end

                local accessible_pos = cur_pos
                if terraforming then
                    -- 210116 null: not needed anymore
                    -- elseif snap_farm then -- 210116 null: (Tilling, Wormwood planting on soil tile)
                    --     accessible_pos = GetSnapTillPosition(cur_pos) -- Snap pos to farm grid
                    accessible_pos = GetAccessibleTilePosition(cur_pos)
                elseif deploy_fn == self.TillAtPoint then -- 210117 null: check if pos already Tilled
                    for _, ent in pairs(TheSim:FindEntities(cur_pos.x, 0, cur_pos.z, 0.005, {"soil"})) do
                        if not ent:HasTag("NOCLICK") then
                            accessible_pos = false
                            break
                        end -- Skip Tilling this position
                    end
                end

                DebugPrint("Current Position:", accessible_pos or "skipped")
                if accessible_pos then
                    if not deploy_fn(self, accessible_pos, item) then
                        break
                    end
                end
            end
            self:ClearActionThread()
            self:ClearSelectedEntities()
            self.inst:DoTaskInTime(
                0,
                function()
                    if next(self.selected_ents) then
                        self:ApplyToSelection()
                    end
                end
            )
        end,
        action_thread_id
    )
end

function ActionQueuer:IsWalkButtonDown()
    DebugPrint("-------------------------------------")
    DebugPrint("IsWalkButtonDown")
    return self.inst.components.playercontroller:IsAnyOfControlsPressed(
        CONTROL_MOVE_UP,
        CONTROL_MOVE_DOWN,
        CONTROL_MOVE_LEFT,
        CONTROL_MOVE_RIGHT
    )
end

function ActionQueuer:DeployActiveItem(pos, item)
    DebugPrint("-------------------------------------")
    DebugPrint("DeployActiveItem: pos:", pos, "item:", item)
    local active_item = self:GetActiveItem() or self:GetNewActiveItem(item.prefab)
    if not active_item then
        return false
    end
    local inventoryitem = active_item.replica.inventoryitem
    if inventoryitem and inventoryitem:CanDeploy(pos, nil, self.inst) then
        local act = BufferedAction(self.inst, nil, ACTIONS.DEPLOY, active_item, pos)
        local playercontroller = self.inst.components.playercontroller
        if playercontroller.deployplacer then
            act.rotation = playercontroller.deployplacer.Transform:GetRotation()
        end
        self:SendActionAndWait(act, true)
        if not playercontroller.ismastersim and not CompareDeploySpacing(active_item, DEPLOYSPACING.NONE) then
            while inventoryitem and inventoryitem:CanDeploy(pos, nil, self.inst) do
                Sleep(self.action_delay)
                if self.inst:HasTag("idle") then
                    self:SendActionAndWait(act, true)
                end
            end
        end
    end
    return true
end

function ActionQueuer:DropActiveItem(pos, item)
    DebugPrint("-------------------------------------")
    DebugPrint("DropActiveItem: pos:", pos, "item:", item)
    local active_item = self:GetActiveItem() or self:GetNewActiveItem(item.prefab)
    if not active_item then
        return false
    end
    if #TheSim:FindEntities(pos.x, 0, pos.z, 0.1, nil, unselectable_tags) == 0 then
        local act = BufferedAction(self.inst, nil, ACTIONS.DROP, active_item, pos)
        act.options.wholestack = false
        self:SendActionAndWait(act, false)
    end
    return true
end

-- 201217 null: added support for Watering of farming tiles
-- 241012 VanCa: Modify WaterTile & WaterAtPoint to watering multi tiles until full moisture in Endless Deploy mode
function ActionQueuer:WaterAtPoint(pos, item, endless_deploy)
    DebugPrint("-------------------------------------")
    DebugPrint("WaterAtPoint: pos:", pos, "item:", tostring(item), "endless_deploy:", endless_deploy)
    local x, y, z = pos:Get()
    local item_in_hand = self:GetEquippedItemInHand()
    if not item_in_hand then
        return false
    end
    if self:GetItemPercent(item_in_hand) == 0 then
        DebugPrint("This watering can is emptied")
        if
            not self:GetNewEquippedItemInHand(
                {"wateringcan", "premiumwateringcan"},
                nil,
                function(item)
                    return self:GetItemPercent(item) > 0
                end
            )
         then
            return false
        end
    end

    if TheWorld.Map:IsFarmableSoilAtPoint(x, y, z) then
        local act = BufferedAction(self.inst, nil, ACTIONS.POUR_WATER_GROUNDTILE, item, pos)
        -- If input endless_deploy is nil then use self.endless_deploy
        endless_deploy = endless_deploy or self.endless_deploy
        if endless_deploy then
            local moisture
            for _, ent in pairs(TheWorld.Map:GetEntitiesOnTileAtPoint(x, y, z)) do
                if ent.prefab == "nutrients_overlay" then -- Look for tile's nutrients_overlay entity, that contains moisture data
                    moisture = ent
                    break
                end
            end
            if not moisture or type(moisture) ~= "table" or not moisture.AnimState then
                return false
            end
            DebugPrint("Tile's water:", moisture.AnimState:GetCurrentAnimationTime())

            -- while self.inst:IsValid() and moisture.AnimState:GetCurrentAnimationTime() < 0.99 do -- Water tile until full

            -- 210202 null: water tile until 90% full instead of 99% (blizstorm)
            -- Moisture constantly drains, so it doesn't stay at 100% for long, hence 99% limit was previously used.
            -- However, there are some cases where you end up watering 5 times. Each = 25%, so 5th time = only watering 1%
            -- So blizstorm suggested using a 90% limit instead.

            -- 250307 VanCa: Added options in the mod settings to allow users to choose what the limits should be.
            while self.inst:IsValid() and moisture.AnimState:GetCurrentAnimationTime() < TUNING.STOP_WATERING_AT do -- Water tile until 90% full
                -- 241012 Vanca: added support for automatically replacing emptied watering can
                if self:GetItemPercent(self:GetEquippedItemInHand()) == 0 then
                    DebugPrint("This watering can is emptied")
                    self:GetNewEquippedItemInHand(
                        {"wateringcan", "premiumwateringcan"},
                        nil,
                        function(item)
                            return self:GetItemPercent(item) > 0
                        end
                    )
                end
                self:SendActionAndWait(act, true)
                DebugPrint("Tile's water:", moisture.AnimState:GetCurrentAnimationTime())
            end
        else
            -- endless_deploy Off
            -- Default behavor, water the tile once.
            self:SendActionAndWait(act, true)
        end
    end
    return true
end

-- 210107 null: added support for Watering of farming tile until moisture is full
-- 241012 VanCa: Modify WaterTile & WaterAtPoint to watering multi tiles until full moisture in Endless Deploy mode
function ActionQueuer:WaterTile(item)
    DebugPrint("-------------------------------------")
    DebugPrint("WaterTile: item:", tostring(item))
    if not item or not self:GetEquippedItemInHand() then
        return
    end

    self.action_thread =
        StartThread(
        function()
            self.inst:ClearBufferedAction()
            while self.inst:IsValid() do
                local closest_tile = self:GetClosestTile()
                if not closest_tile then
                    break
                end
                self:WaterAtPoint(closest_tile:GetPosition(), item, true)
                self:DeselectFarmTile(closest_tile)
            end

            self:ClearActionThread()
            self:ClearSelectedEntities()
        end,
        action_thread_id
    )
end

-- 201217 null: added support for Tilling of farming tiles
function ActionQueuer:TillAtPoint(pos, item)
    DebugPrint("-------------------------------------")
    DebugPrint("TillAtPoint: pos:", pos, "item:", item)
    local x, y, z = pos:Get()
    if not self:GetEquippedItemInHand() then
        return false
    end
    if TheWorld.Map:CanTillSoilAtPoint(x, y, z) then -- 201221 null: Fix for when objects block Tilling
        local act = BufferedAction(self.inst, nil, ACTIONS.TILL, item, pos)
        self:SendActionAndWait(act, false) -- false = RPC.LeftClick, avoids Geometric Placement mod's RPC.RightClick snap overrides
    end
    return true
end

-- 250306 VanCa: Gets fertilizer prefab's nutrient values
-- reference: Insight mod
function GetNutrientValue(prefab)
    local FERTILIZER_DEFS =
        (TheSim:GetGameID() == "DST" and CurrentRelease.GreaterOrEqualTo("R14_FARMING_REAPWHATYOUSOW") and
        require("prefabs/fertilizer_nutrient_defs").FERTILIZER_DEFS) or
        {}
    for _prefab, data in pairs(FERTILIZER_DEFS) do
        if _prefab == prefab then
            -- {Growth formula, Compost, Manure}
            return data.nutrients
        end
    end
end

-- 250306 VanCa: Get nutrient levels.
-- reference: 呼吸
function GetFertilities(tile)
    DebugPrint("GetFertilities: tile:", tile)
    local nutrientlevels = tile and tile.nutrientlevels and tile.nutrientlevels:value()
    -- 4：100% 3：50% 2:25% 1:%1 0:0%
    return nutrientlevels and
        {
            bit.band(nutrientlevels, 7), -- Growth formula
            bit.band(bit.rshift(nutrientlevels, 3), 7), -- Compost
            bit.band(bit.rshift(nutrientlevels, 6), 7) -- Manure
        }
end

-- 201223 null: added support for Fertilizing of farming tiles
-- 250307 VanCa: Stop Fertilizing when the tile has had enough of that fertilizer's nutrient(s)
function ActionQueuer:FertilizeAtPoint(pos, item, fast, endless_deploy)
    DebugPrint("-------------------------------------")
    DebugPrint("FertilizeAtPoint: pos:", pos, "item:", item, "fast:", fast)
    local activeItem = self:GetActiveItem()
    if not activeItem then
        return false
    end
    for _, ent in pairs(TheWorld.Map:GetEntitiesOnTileAtPoint(pos.x, pos.y, pos.z)) do
        if ent.prefab == "nutrients_overlay" then
            local act = BufferedAction(self.inst, nil, ACTIONS.DEPLOY_TILEARRIVE, item, pos)
            local tileNutrients = GetFertilities(ent)
            local fertilizerNutrients = GetNutrientValue(activeItem.prefab)
            -- If input endless_deploy is nil then use self.endless_deploy
            endless_deploy = endless_deploy or self.endless_deploy
            if endless_deploy and fertilizerNutrients then
                -- 250307 VanCa: Added options in the mod settings to allow users to choose what the limits should be.
                while (fertilizerNutrients[1] > 0 and tileNutrients[1] < TUNING.STOP_FERTILIZING_AT) or
                    (fertilizerNutrients[2] > 0 and tileNutrients[2] < TUNING.STOP_FERTILIZING_AT) or
                    (fertilizerNutrients[3] > 0 and tileNutrients[3] < TUNING.STOP_FERTILIZING_AT) do
                    -- while a tile's nutrient < Limit
                    self:SendActionAndWait(act, true)

                    -- Pickup a new stack of fertilizer
                    if not self:GetActiveItem() then
                        DebugPrint("Pickup a new stack of fertilizer")
                        if not self:GetNewActiveItem(activeItem.prefab) then
                            return false
                        end
                    end

                    -- 201225 null: extra delay needed when Fertilizing through SelectionBox()
                    if not fast then
                        while not self.inst:HasTag("idle") do
                            Sleep(self.action_delay)
                        end
                    end

                    -- Update the tile's nutrients info
                    tileNutrients = GetFertilities(ent)
                end
            else
                -- endless_deploy Off
                -- Default behavor, fertilize the tile once.
                if
                    fertilizerNutrients and
                        ((fertilizerNutrients[1] > 0 and tileNutrients[1] < 4) or
                            (fertilizerNutrients[2] > 0 and tileNutrients[2] < 4) or
                            (fertilizerNutrients[3] > 0 and tileNutrients[3] < 4)) or
                        not fertilizerNutrients
                 then
                    -- 250404 VanCa: If we can get fertilizer information, skip tiles that doesn't need it
                    -- If we can't, fertilize each tile once
                    self:SendActionAndWait(act, true)

                    -- 201225 null: extra delay needed when Fertilizing through SelectionBox()
                    if not fast then
                        while not self.inst:HasTag("idle") do
                            Sleep(self.action_delay)
                        end
                    end
                end
            end
            break
        end
    end
    return true
end

-- 201224 null: added support for Fertilizing of farming tiles
function ActionQueuer:FertilizeTile(pos, item)
    DebugPrint("-------------------------------------")
    DebugPrint("FertilizeTile: pos:", pos, "item:", item)
    -- 201225 null: make sure pos and item exist, and tile = farmable before continuing
    if not pos or not item or not TheWorld.Map:IsFarmableSoilAtPoint(pos.x, 0, pos.z) then
        return
    end

    self.action_thread =
        StartThread(
        function()
            self.inst:ClearBufferedAction()
            local activeItem = self:GetActiveItem()
            while self.inst:IsValid() do
                local closest_tile = self:GetClosestTile()
                if not closest_tile then
                    break
                end
                -- 250307 Vanca: pickup a new stack of fertilizer
                if not self:GetActiveItem() then
                    DebugPrint("Pickup a new stack of fertilizer")
                    if not self:GetNewActiveItem(activeItem.prefab) then
                        break
                    end
                end
                if not self:FertilizeAtPoint(closest_tile:GetPosition(), item, false, true) then
                    break
                end
                self:DeselectFarmTile(closest_tile)
            end
            self:ClearActionThread()
            self:ClearSelectedEntities()
        end,
        action_thread_id
    )
end

-- 210103 null: added support for Wormwood planting inside farm soil grids
function ActionQueuer:WormwoodPlantAtPoint(pos, item)
    DebugPrint("-------------------------------------")
    DebugPrint("WormwoodPlantAtPoint: pos:", pos, "item:", item)
    local x, y, z = pos:Get()
    local active_item = self:GetActiveItem() or self:GetNewActiveItem(item.prefab)
    if not active_item then
        return false
    end
    local inventoryitem = active_item.replica.inventoryitem
    if inventoryitem and inventoryitem:CanDeploy(pos, nil, self.inst) and TheWorld.Map:CanTillSoilAtPoint(x, y, z) then -- Do not plant outside the farm soil tile in this scenario
        local act = BufferedAction(self.inst, nil, ACTIONS.DEPLOY, active_item, pos)
        self:SendActionAndWait(act, false) -- 210127 null: false avoids Geometric Placement mod's RPC.RightClick snap overrides
    end
    return true
end

function ActionQueuer:TerraformAtPoint(pos, item)
    DebugPrint("-------------------------------------")
    DebugPrint("TerraformAtPoint: pos:", pos, "item:", item)
    local x, y, z = pos:Get()
    if not self:GetEquippedItemInHand() then
        return false
    end
    if TheWorld.Map:CanTerraformAtPoint(x, y, z) then
        local act = BufferedAction(self.inst, nil, ACTIONS.TERRAFORM, item, pos)
        self:SendActionAndWait(act, true)
        while TheWorld.Map:CanTerraformAtPoint(x, y, z) do
            Sleep(self.action_delay)
            if self.inst:HasTag("idle") then
                self:SendActionAndWait(act, true)
            end
        end
        if self.auto_collect then
            self:AutoCollect(pos, true)
        end
    end
    return true
end

function ActionQueuer:TakeBucket(state)
    local bucket_list = {
        "bucket_empty",
        "bucket_woodie_empty",
        "bucket_steel_empty"
    }
    local active_item = self:GetActiveItem()
    if active_item and table.contains(bucket_list, active_item.prefab) then
        -- if we're holding a bucket already then return
        return active_item
    end
    if not TUNING.TARGET_SELECTION == "optimal" or #state.targets == 0 then
        -- Try to take a bucket
        local new_active_item = self:GetNewActiveItem(bucket_list)
        if new_active_item then
            state.is_active_item_changed = true
        end
        return new_active_item
    end
end

function ActionQueuer:TakeDirtyWater(state)
    local active_item = self:GetActiveItem()
    if active_item and table.contains({"water_dirty", "water_dirty_ice"}, active_item.prefab) then
        -- if we're holding dirty water already then return
        return active_item
    end
    -- try to take a stack of water_dirty
    return self:GetNewActiveItem({"water_dirty", "water_dirty_ice"})
end

function ActionQueuer:TakeSaltyWater(state)
    local active_item = self:GetActiveItem()
    if active_item and active_item.prefab == "water_salty" then
        -- if we're holding salty water already then return
        return active_item
    end
    -- try to take a stack of water_salty
    return self:GetNewActiveItem("water_salty")
end

-- 250429 VanCa: Evaluate all paths with debug prints
local function getOptimalTarget(targets, initial_pos, candidate_num, max_depth, neighbor_range)
    if #targets == 0 then
        return nil
    elseif #targets == 1 then
        DebugPrint("Distance:", initial_pos:DistSq(targets[1]:GetPosition()))
        return targets[1]
    end

    -- Precompute distances to avoid redundant calculations
    local pairwise_distances = {} -- Distance between pairs of targets
    for _, t in ipairs(targets) do
        pairwise_distances[t.GUID] = {}
    end

    candidate_num = candidate_num or math.huge
    max_depth = max_depth or math.huge
    neighbor_range = neighbor_range or 0
    local path_count = 0
    local best_total = math.huge
    local best_target = nil
    local best_path_str = ""

    local function generatePaths(current_target, targets, visited, current_path, current_total, depth)
        if depth == math.min(max_depth, #targets) or current_total >= best_total then
            path_count = path_count + 1
            local path_str = ""
            for i, t in ipairs(current_path) do
                if i > 1 then
                    path_str = path_str .. " → "
                end
                path_str = path_str .. t.GUID
                if i == 1 then
                    path_str = path_str .. string.format(" (%.2f)", t.distance)
                end
            end
            if depth < math.min(max_depth, #targets) then
                path_str = path_str .. " Bad path! Stop."
            end
            path_str =
                string.format("Path %3d: %-30s Total (%d steps): %7.2f", path_count, path_str, depth, current_total)
            DebugPrint(path_str)
            if current_total < best_total then
                best_total = current_total
                best_target = current_path[1]
                best_path_str = path_str
            end

            return
        end

        local candidates = {}
        for _, t in ipairs(targets) do
            if not visited[t] then
                local distance
                if current_target == nil then
                    distance = t.distance
                else
                    distance = pairwise_distances[current_target.GUID][t.GUID]
                    if not distance then
                        distance = current_target:GetPosition():DistSq(t:GetPosition())
                        pairwise_distances[current_target.GUID][t.GUID] = distance
                        pairwise_distances[t.GUID][current_target.GUID] = distance
                    end
                end
                table.insert(candidates, {target = t, distance = distance})
                if distance < 1.1 then
                    -- This target is right under my feet, stop adding others
                    break
                end
            end
        end

        -- Sort by distance
        table.sort(
            candidates,
            function(a, b)
                return a.distance < b.distance
            end
        )

        local top_closest = {}
        for i = 1, math.min(candidate_num, #candidates) do
            -- Prune candidates significantly farther than the closest one (sqrt(3) times threshold)
            if i > 1 and candidates[i].distance > candidates[1].distance * 4 then
                -- Stop including candidates beyond this point
                break
            end

            table.insert(top_closest, candidates[i])

            -- Prioritize immediate neighbors: if a target is within a close range,
            -- treat it as the only viable candidate (avoids overcomplicating paths)
            if candidates[i].distance < neighbor_range then
                -- Early exit for nearby targets
                break
            end
        end

        if current_target == nil and #top_closest == 1 then
            -- Early termination for single candidate at initial position
            depth = math.min(max_depth, #targets)
        else
            depth = depth + 1
        end

        for _, c in ipairs(top_closest) do
            local candidate = c.target
            local dist = c.distance

            visited[candidate] = true
            table.insert(current_path, candidate)

            generatePaths(candidate, targets, visited, current_path, current_total + dist, depth)

            table.remove(current_path)
            visited[candidate] = nil

            if current_total + dist >= best_total or path_count == 500 then
                -- Farther targets are 100% bad path - Early termination
                break
            end
        end
    end

    DebugPrint("Generate and evaluate all paths:")

    generatePaths(nil, targets, {}, {}, 0, 0)

    DebugPrint(string.format("Total: %d paths.", path_count), "Optimal Path:", best_path_str)
    return best_target
end

function ActionQueuer:GetClosestTarget(active_item)
    DebugPrint("-------------------------------------")
    DebugPrint("GetClosestTarget active_item:", tostring(active_item))
    local targets = {}
    local player_pos = self.inst:GetPosition()
    local repeat_flag = false
    local act

    -- -- Auto use coffee?
    -- local locomotor = self.inst.components.locomotor
    -- DebugPrint("locomotor:", locomotor)
    -- if not locomotor then
    -- locomotor = self.inst:AddComponent("locomotor")
    -- end
    -- DebugPrint("_externalspeedmultipliers:", locomotor._externalspeedmultipliers)
    -- DebugPrint("RunSpeed:", locomotor:RunSpeed())
    -- DebugPrint("ExternalSpeedMultiplier:", locomotor:ExternalSpeedMultiplier())
    -- DebugPrint("GetSpeedMultiplier:", locomotor:GetSpeedMultiplier())
    -- if locomotor:GetSpeedMultiplier() < 2.35 then
    -- end

    -- Precompute distances for ALL entities
    for _, ent in ipairs(self.selected_ents_sortable) do
        ent.distance = player_pos:DistSq(ent:GetPosition())
    end

    -- Sort selected entities bases on distance (farthest first)
    table.sort(
        self.selected_ents_sortable,
        function(a, b)
            return a.distance > b.distance
        end
    )

    for _, ent in pairs(self.selected_ents_sortable) do
        DebugPrint("Ent:", tostring(ent), "distance:", ent.distance)
    end

    -- In endless mode, repeat until we got a target, or until all targets are deselected
    repeat
        -- From nearest to farthest
        -- Iterating from the last element to the first to avoid the issue of shifting indices
        local state = {targets, is_active_item_changed = false}
        for i = #self.selected_ents_sortable, 1, -1 do
            local ent = self.selected_ents_sortable[i]
            if IsValidEntity(ent) then
                DebugPrint("Check ent:", tostring(ent))
                local skip_ent = false
                local rightclick = self.selected_ents[ent]
                local active_item_right_now = self:GetActiveItem()
                DebugPrint("Active item right now:", tostring(active_item_right_now))

                if ent.prefab == "well" and not self.selected_ents[ent] then
                    -- (Dehydrated) Well - left click
                    if ent:HasTag("ready") then
                        -- if this well is ready to receive bucket
                        -- then make sure we're holding a bucket
                        if self:TakeBucket(state) then
                            DebugPrint("Now we're holding a bucket")
                        else
                            -- If we don't have any bucket left
                            -- then skip this well
                            skip_ent = true
                        end
                    elseif ent.AnimState:IsCurrentAnimation("idle_watering") then
                        -- if this well is waiting for harvest
                        -- then put the active item (a bucket) back to inventory to trigger PICK action.
                        self.inst.replica.inventory:ReturnActiveItem()
                    end
                elseif ent.prefab == "campkettle" and not self.selected_ents[ent] then
                    -- (Dehydrated) Camp Kettle - left click

                    --if this campkettle is ready to receive Dirty water
                    if ent.replica.waterlevel._accepting:value() then
                        -- then try to take a stack of water_dirty
                        if self:TakeDirtyWater() then
                            DebugPrint("Now we're holding dirty water")
                        else
                            -- if there is no water_dirty, skip this campkettle
                            skip_ent = true
                        end
                    elseif ent:HasTag("pickable") then
                        -- if this campkettle is waiting for harvest
                        -- then put the active item back to inventory (if we're holding something)
                        -- so that GetAction could give us the "PICK" action.
                        self.inst.replica.inventory:ReturnActiveItem()
                        DebugPrint("Empty handed to collect water")
                    end
                elseif ent.prefab == "campdesalinator" and not self.selected_ents[ent] then
                    -- (Dehydrated) Camp Desalinator - left click

                    -- if this campdesalinator is ready to receive Salty water
                    if ent.replica.waterlevel._accepting:value() then
                        -- then try to take a stack of water_salty
                        if self:TakeSaltyWater() then
                            DebugPrint("Now we're holding salty water")
                        else
                            -- if there is no water_salty, skip this campdesalinator
                            skip_ent = true
                        end
                    elseif ent:HasTag("pickable") then
                        -- if this campdesalinator is waiting for harvest
                        -- then put the active item back to inventory (if we're holding something)
                        -- so that GetAction could give us the "PICK" action.
                        self.inst.replica.inventory:ReturnActiveItem()
                        DebugPrint("Empty handed to collect water")
                    end
                elseif ent.prefab == "desalinator" and not self.selected_ents[ent] then
                    -- (Dehydrated) Desalinator - left click

                    if
                        (ent.replica.waterlevel._accepting:value() and active_item_right_now and
                            active_item_right_now.prefab == "water_salty") or
                            (ent.AnimState:IsCurrentAnimation("idle_open") and active_item_right_now and
                                active_item_right_now:HasTag("watertaker")) or
                            (ent:HasTag("pickable") and not active_item_right_now)
                     then
                        -- Desalinator if more complicated than others because it has 3 states to consider
                        -- (waiting for salty water, ready to collect clean water, ready to collect salt)
                        -- If everything is good, then do nothing
                    else
                        if ent:HasTag("pickable") then
                            -- if this desalinator is ready to collect Salt but we're holding something
                            -- then put the active item back to inventory
                            -- so that GetAction could give us the "PICK" action.
                            self.inst.replica.inventory:ReturnActiveItem()
                            DebugPrint("Empty handed to collect Salt")
                        elseif ent.replica.waterlevel._accepting:value() then
                            -- if this desalinator is ready to receive Salty water but we're not holding one
                            -- then try to take a stack of water_salty
                            if self:TakeSaltyWater() then
                                DebugPrint("Now we're holding salty water")
                            else
                                -- if there is no water_salty, skip this desalinator
                                skip_ent = true
                            end
                        elseif ent.AnimState:IsCurrentAnimation("idle_open") or ent.AnimState:IsCurrentAnimation("idle") then
                            -- if this desalinator is ready to collect clean water but we're not holding a bucket
                            -- then make sure we're holding a bucket
                            if self:TakeBucket() then
                                DebugPrint("Now we're holding a bucket")
                            else
                                -- If we don't have any bucket left
                                -- then skip this desalinator
                                skip_ent = true
                            end
                        end
                    end
                elseif
                    ent:HasTag("watersource") and active_item and
                        (active_item.prefab == "wateringcan" or active_item.prefab == "premiumwateringcan") and
                        not active_item_right_now
                 then
                    -- 250307 VanCa: support switching wateringCan when refilling (leftclick)
                    active_item =
                        self:GetNewActiveItem(
                        {"wateringcan", "premiumwateringcan"},
                        nil,
                        function(item)
                            return self:GetItemPercent(item) < 100
                        end
                    ) or active_item
                elseif ent.prefab == "gravestone" and active_item and active_item.prefab == "graveurn" then
                    -- 250304 VanCa: Auto switch to unused graveurn when 'GRAVEDIG'ing with Wendy skill
                    if
                        active_item_right_now and active_item_right_now.prefab == "graveurn" and
                            active_item_right_now:HasTag("deployable")
                     then
                        active_item =
                            self:GetNewActiveItem(
                            {"graveurn"},
                            nil,
                            function(item)
                                return not item:HasTag("deployable")
                            end
                        ) or active_item
                    end
                end

                if not skip_ent then
                    act = self:GetAction(ent, rightclick, ent:GetPosition())
                    if act and act:IsValid() then
                        ent.act = act
                        ent.active_item = self:GetActiveItem()
                    elseif self.endless_deploy then
                        -- In an endless queue, skip targets that can't accept any action at this time
                        skip_ent = true
                    end
                end

                if not skip_ent then
                    if
                        TUNING.TARGET_SELECTION == "optimal" and #targets > 0 and
                            ent.distance > targets[#targets].distance * 16
                     then
                        -- Does not consider targets too far away
                        break
                    end

                    table.insert(targets, ent)
                    DebugPrint("Added to targets list:", tostring(ent), string.format("(%s)", #targets))

                    if TUNING.TARGET_SELECTION == "optimal" and not state.is_active_item_changed and #targets < 15 then
                        -- Continue till the end of seletion list to get all valid targets
                        -- If active changed, return the closed target
                    else
                        -- Found the closest target with valid action
                        break
                    end
                else
                    DebugPrint("Skip:", tostring(ent))
                end
            else
                DebugPrint("Not valid entity")
                self:DeselectEntity(ent)
            end
        end

        -- In endless mode, repeat until got a target, or until all targets are deselected
        if #targets == 0 and #self.selected_ents_sortable > 0 and self.endless_deploy then
            -- Re-hold the active item if it's somehow not on the mouse
            -- 250501 VanCa: Prevent endless take>store>take>store loop
            if active_item and not self:GetActiveItem() then
                DebugPrint("Try to get new active item~")
                active_item =
                    self:GetNewActiveItem(
                    active_item.prefab,
                    nil,
                    function(item, cont, slot)
                        return not self.selected_ents_client_memory[cont]
                    end
                ) or active_item
            end
            -- Set repeat
            repeat_flag = true
            Sleep(self.work_delay)
            DebugPrint("GetClosestTarget > repeat")
        else
            repeat_flag = false
        end
    until not repeat_flag

    local optimal_target = getOptimalTarget(targets, player_pos, nil, nil, 15)
    if optimal_target then
        act = optimal_target.act
        -- Update in case manual changed active item
        active_item = optimal_target.active_item
    end

    -- In recursion mode, find nearby targets before declaring an action on an entity
    DebugPrint("drag_click_selected_flag:", self.drag_click_selected_flag)
    DebugPrint("double_click_flag:", self.double_click_flag)
    DebugPrint("self.last_target_ent:", tostring(self.last_target_ent))
    if self.double_click_flag and #self.selected_ents_sortable > 0 and self.endless_deploy then
        -- Won't find nearby targets when repeating an action on a target
        -- (ex: choping a tree)
        if not self.last_target_ent or self.last_target_ent ~= optimal_target then
            self.last_target_ent = optimal_target
            DebugPrint("Selecting nearby targets recursively")
            optimal_target.action = act.action

            local total_selected_ents = #self.selected_ents_sortable
            DebugPrint("total_selected_ents:", total_selected_ents)
            self:DoubleClick(self.selected_ents[optimal_target], optimal_target)
            DebugPrint("#self.selected_ents_sortable:", #self.selected_ents_sortable)
            -- If there is a change in selected ents, find clostest target again
            if #self.selected_ents_sortable ~= total_selected_ents then
                DebugPrint("Selected new Entities, find closest target again")
                optimal_target, active_item, act = self:GetClosestTarget(active_item)
            end
        end
    end

    DebugPrint("Closest/Optimal target:", tostring(optimal_target))
    return optimal_target, active_item, act
end

function ActionQueuer:WaitToolReEquip()
    DebugPrint("-------------------------------------")
    DebugPrint("WaitToolReEquip")
    if not self:GetEquippedItemInHand() and not self.inst:HasTag("wereplayer") then
        self:Wait()
        return true
    end
end

function ActionQueuer:CheckEntityMorph(prefab, pos, rightclick)
    DebugPrint("-------------------------------------")
    DebugPrint("CheckEntityMorph: prefab:", prefab, "pos:", pos, "rightclick:", rightclick)
    if not entity_morph[prefab] then
        return
    end
    for _, ent in pairs(TheSim:FindEntities(pos.x, 0, pos.z, 1, nil, unselectable_tags)) do
        if ent.prefab == entity_morph[prefab] then
            self:SelectEntity(ent, rightclick)
        end
    end
end

function ActionQueuer:AutoCollect(pos, collect_now)
    DebugPrint("-------------------------------------")
    DebugPrint("AutoCollect: pos:", pos, "collect_now:", collect_now)
    for _, ent in pairs(TheSim:FindEntities(pos.x, 0, pos.z, 4, nil, unselectable_tags)) do
        -- 250320 VanCa: Prevent pickup W.I.N.bot when auto collect trigger near it
        if IsValidEntity(ent) and ent.prefab ~= "winona_storage_robot" and not self:IsSelectedEntity(ent) then
            local act = self:GetAction(ent, false)
            if act and CheckAllowedActions("collect", act.action, ent, self) then
                self:SelectEntity(ent, false)
                if collect_now then
                    self:SendActionAndWait(act, false, ent)
                    self:DeselectEntity(ent)
                end
            end
        end
    end
end

function ActionQueuer:ApplyToSelection()
    DebugPrint("-------------------------------------")
    DebugPrint("ApplyToSelection")
    DebugPrint("drag_click_selected_flag", self.drag_click_selected_flag)
    DebugPrint("double_click_flag", self.double_click_flag)
    self.action_thread =
        StartThread(
        function()
            self.inst:ClearBufferedAction()
            local active_item = self:GetActiveItem()
            DebugPrint("active_item:", tostring(active_item))
            while self.inst:IsValid() do
                DebugPrint("self.inst is Valid")
                local target, act
                -- Update active_item in case we manually picked a new active item when stuck in finding the closest target
                target, active_item, act = self:GetClosestTarget(active_item)
                if not target then
                    break
                end
                local highlight = target.components.highlight
                local rightclick = self.selected_ents[target]
                local pos = target:GetPosition()
                if not act then
                    act = self:GetAction(target, rightclick, pos, active_item)
                end
                if act and act:IsValid() then
                    DebugPrint("act is valid")
                    local tool_action = allowed_actions.tools[act.action]
                    DebugPrint("tool_action:", tool_action)

                    -- 250320 VanCa: Server won't excute these two actions on farm plants while Wormwood's holding a shovel
                    -- He can only check ASSESSPLANTHAPPINESS while holding a shovel, so this part auto unequip it
                    if
                        target:HasTag("farm_plant") and (act.action.id == "INTERACT_WITH" or act.action.id == "PICK") and
                            act.doer.prefab == "wormwood"
                     then
                        local equiped_item_in_hand = self:GetEquippedItemInHand()
                        if equiped_item_in_hand and equiped_item_in_hand:HasTag("DIG_tool") then
                            self:UnEquip(equiped_item_in_hand, false)
                        end
                    end

                    self:SendActionAndWait(act, rightclick, target)
                    if not CheckAllowedActions("single", act.action, target, self) then
                        DebugPrint("not a one time action")
                        local noworkdelay = CheckAllowedActions("noworkdelay", act.action, target, self)
                        DebugPrint("noworkdelay:", noworkdelay)
                        local current_action = act.action
                        DebugPrint("current_action:", current_action.id)
                        while IsValidEntity(target) and self.selected_ents[target] ~= nil do
                            DebugPrint("target is valid")
                            local act = self:GetAction(target, rightclick, pos)
                            -- 250921 VanCa: Continue to auto dig up stump while chopping if it doesn't require changing tool (Werebeaver)
                            if
                                not act or
                                    (act.action ~= current_action and
                                        not (current_action == ACTIONS.CHOP and act.action == ACTIONS.DIG))
                             then
                                DebugPrint("no action to perform")
                                if active_item then
                                    DebugPrint("active_item:", tostring(active_item))
                                    if noworkdelay then
                                        DebugPrint("No delay work - sleep")
                                        Sleep(self.action_delay)
                                    end --queue can exit without this delay
                                    if not self:GetActiveItem() then
                                        DebugPrint("Try to get new active item")
                                        if
                                            (active_item.prefab == "wateringcan" or
                                                active_item.prefab == "premiumwateringcan") and
                                                target:HasTag("watersource")
                                         then
                                            -- 250307 VanCa: support switching wateringCan when refilling (leftclick)
                                            active_item =
                                                self:GetNewActiveItem(
                                                {"wateringcan", "premiumwateringcan"},
                                                nil,
                                                function(item)
                                                    return self:GetItemPercent(item) < 100
                                                end
                                            ) or active_item
                                        else
                                            -- 250501 VanCa: Prevent endless take>store>take>store loop
                                            active_item =
                                                self:GetNewActiveItem(
                                                active_item.prefab,
                                                nil,
                                                function(_, cont)
                                                    return cont ~= target
                                                end
                                            ) or active_item
                                        end
                                        -- Sleep(self.action_delay)
                                        act = self:GetAction(target, rightclick, pos)
                                    end
                                elseif tool_action and self:WaitToolReEquip() then
                                    DebugPrint("tool_action and self:WaitToolReEquip()")
                                    act = self:GetAction(target, rightclick, pos)
                                end
                                if not act then
                                    DebugPrint("not act. stop repeat")
                                    break
                                end
                            end

                            -- 250921 VanCa: Continue to auto dig up stump while chopping if it doesn't require changing tool (Werebeaver)
                            if
                                act.action ~= current_action and
                                    not (current_action == ACTIONS.CHOP and act.action == ACTIONS.DIG)
                             then
                                DebugPrint("act.action ~= current_action")
                                break
                            end
                            self:SendActionAndWait(act, rightclick, target)
                        end
                    end
                    DebugPrint("The action is done with the entity")
                    DebugPrint("drag_click_selected_flag", self.drag_click_selected_flag)
                    DebugPrint("double_click_flag", self.double_click_flag)
                    if
                        (self.drag_click_selected_flag or
                            (tool_action and not self:GetEquippedItemInHand() and not self.inst:HasTag("wereplayer"))) and
                            self.endless_deploy and
                            self.selected_ents[target] ~= nil
                     then
                        -- in endless mode, won't deselect target if target is drag_click_selected
                        -- or it's tool_action but currently ran out of tool, skip Deselect to go back to GetClosestTarget
                        -- (after manual craft tool, this target may be the closest target again)
                        if highlight then
                            highlight:SetAddColour(self.color)
                        end
                    else
                        self:DeselectEntity(target)
                    end
                    self:CheckEntityMorph(target.prefab, pos, rightclick)
                    if active_item and not self:GetActiveItem() then
                        -- Sleep(self.action_delay)
                        if
                            not ((active_item.prefab == "wateringcan" or active_item.prefab == "premiumwateringcan") and
                                target:HasTag("watersource"))
                         then
                            -- 250415 VanCa: This line run after all watering can have been filled and the pond has been deselected
                            -- so no need to pick up new watering can in this case
                            -- 250501 VanCa: Prevent endless take>store>take>store loop
                            active_item =
                                self:GetNewActiveItem(
                                active_item.prefab,
                                nil,
                                function(_, cont)
                                    return cont ~= target
                                end
                            ) or active_item
                        end
                    elseif tool_action then
                        DebugPrint("tool_action. WaitToolReEquip")
                        self:WaitToolReEquip()
                    end
                    if self.auto_collect then
                        local auto_collect = CheckAllowedActions("autocollect", act.action, target, self)
                        DebugPrint("auto_collect:", auto_collect)
                        if auto_collect then
                            DebugPrint("Auto collect loot")
                            Sleep(FRAMES)
                            pos = moving_target[target.prefab] and self.inst:GetPosition() or pos
                            self:AutoCollect(pos, false)
                        end
                    end
                else
                    DebugPrint("No act or invalid")
                    if self.drag_click_selected_flag and self.endless_deploy and self.selected_ents[target] ~= nil then
                        -- won't deselect target if target is drag_click_selected & in endless mode
                        if highlight then
                            highlight:SetAddColour(self.color)
                        end
                    else
                        self:DeselectEntity(target)
                    end
                end
            end
            if #self.selected_ents_sortable == 0 then
                self.drag_click_selected_flag = false
                self.double_click_flag = false
                self.last_target_ent = nil
                self.selected_ents_client_memory = {}
            end
            self:ClearActionThread()
        end,
        action_thread_id
    )
end

function ActionQueuer:RepeatRecipe(builder, recipe, skin)
    DebugPrint("-------------------------------------")
    DebugPrint("RepeatRecipe: builder:", builder, "recipe:", recipe, "skin:", skin)
    self.action_thread =
        StartThread(
        function()
            self.inst:ClearBufferedAction()
            while self.inst:IsValid() and builder:CanBuild(recipe.name) do
                builder:MakeRecipeFromMenu(recipe, skin)
                Sleep(self.action_delay)
            end
            self:ClearActionThread()
        end,
        action_thread_id
    )
end

function ActionQueuer:StartAutoFisher(target)
    DebugPrint("-------------------------------------")
    DebugPrint("StartAutoFisher: target:", target)
    self:ToggleEntitySelection(target, false)
    if self.action_thread then
        return
    end
    if self.inst.locomotor then
        self.inst.components.talker:Say("Auto fisher will not work with lag compensation enabled")
        self:DeselectEntity(target)
        return
    end
    self.action_thread =
        StartThread(
        function()
            self.inst:ClearBufferedAction()
            self.auto_fishing = true
            while self.auto_fishing and self.inst:IsValid() and next(self.selected_ents) do
                for pond in pairs(self.selected_ents) do
                    local fishingrod = self:GetEquippedItemInHand() or self:GetNewEquippedItemInHand("fishingrod")
                    if not fishingrod or self:GetActiveItem() then
                        self.auto_fishing = false
                        break
                    end
                    local pos = pond:GetPosition()
                    local fish_act = BufferedAction(self.inst, pond, ACTIONS.FISH, fishingrod, pos)
                    while not self.inst:HasTag("nibble") do
                        if not self.inst:HasTag("fishing") and self.inst:HasTag("idle") then
                            self:SendAction(fish_act, false, pond)
                        end
                        Sleep(self.action_delay)
                    end
                    local catch_act = BufferedAction(self.inst, pond, ACTIONS.REEL, fishingrod, pos)
                    self:SendAction(catch_act, false, pond)
                    Sleep(self.action_delay)
                    self:SendActionAndWait(catch_act, false, pond)

                    -- 210130 null: only pick up fish if auto_collect is enabled
                    if self.auto_collect then
                        local fish = FindEntity(self.inst, 2, nil, {"fish"})
                        if fish then
                            local pickup_act = BufferedAction(self.inst, fish, ACTIONS.PICKUP, nil, fish:GetPosition())
                            self:SendActionAndWait(pickup_act, false, fish)
                        end
                    end
                end
            end
            self:ClearActionThread()
            self:ClearSelectedEntities()
        end,
        action_thread_id
    )
end

function ActionQueuer:GetClosestTile()
    DebugPrint("-------------------------------------")
    DebugPrint("GetClosestTile")
    local mindistsq, closest_tile
    local player_pos = self.inst:GetPosition()
    local player_pos_x, player_pos_z = player_pos.x, player_pos.z
    for tile in pairs(self.selected_farm_tiles) do
        local curdistsq = player_pos:DistSq(tile:GetPosition())
        if not mindistsq or curdistsq < mindistsq then
            mindistsq = curdistsq
            closest_tile = tile
        end
    end
    DebugPrint("Closest tile:", tostring(closest_tile))
    return closest_tile
end

function ActionQueuer:IsSelectedFarmTile(tile)
    --DebugPrint("IsSelectedEntity: ent:", ent)
    --nil check because boolean value
    return self.selected_farm_tiles[tile] ~= nil
end

function ActionQueuer:SelectFarmTile(tile, rightclick)
    DebugPrint("-------------------------------------")
    DebugPrint("SelectFarmTile: tile:", tostring(tile), "rightclick:", rightclick)
    if self:IsSelectedFarmTile(tile) then
        DebugPrint("Farm tile has been selected before")
        return
    end
    self.selected_farm_tiles[tile] = rightclick
    DebugPrint("...done! Farm tile has been selected")
end

function ActionQueuer:DeselectFarmTile(tile)
    DebugPrint("-------------------------------------")
    DebugPrint("DeselectFarmTile: tile:", tostring(tile))

    if self:IsSelectedFarmTile(tile) then
        self.selected_farm_tiles[tile] = nil
    end
end

function ActionQueuer:IsSelectedEntity(ent)
    --DebugPrint("IsSelectedEntity: ent:", ent)
    --nil check because boolean value
    return self.selected_ents[ent] ~= nil
end

function ActionQueuer:SelectEntity(ent, rightclick, act)
    DebugPrint("-------------------------------------")
    DebugPrint("SelectEntity: ent:", tostring(ent), "rightclick:", rightclick)
    if self:IsSelectedEntity(ent) then
        DebugPrint("Entity has been selected before")
        return
    end
    self.selected_ents[ent] = rightclick
    table.insert(self.selected_ents_sortable, ent)
    self.selected_ents_client_memory[ent] = {}

    if ent.prefab == "gelblob_storage" then
        self.selected_ents_client_memory[ent].saved_act = act
    end

    if not ent.components.highlight then
        ent:AddComponent("highlight")
    end
    local highlight = ent.components.highlight
    highlight.highlight_add_colour_red = nil
    highlight.highlight_add_colour_green = nil
    highlight.highlight_add_colour_blue = nil
    highlight:SetAddColour(self.color)
    highlight.highlit = true
    DebugPrint("...done! Selected and highlighted")
end

-- Function to remove a key based on its value
local function RemoveKeyByValue(tbl, value)
    for key, val in pairs(tbl) do
        if val == value then
            table.remove(tbl, key)
            break
        end
    end
end

function ActionQueuer:DeselectEntity(ent)
    DebugPrint("-------------------------------------")
    DebugPrint("DeselectEntity: ent:", tostring(ent))
    -- DebugPrint("DeselectEntity: ent:", ent:GetDebugString())

    if self:IsSelectedEntity(ent) then
        self.selected_ents[ent] = nil
        RemoveKeyByValue(self.selected_ents_sortable, ent)
        if ent:IsValid() and ent.components.highlight then
            ent.components.highlight:UnHighlight()
        end
    end

    if ent.prefab == "ocean_water_source" then
        ent:Remove()
    end
end

function ActionQueuer:ToggleEntitySelection(ent, rightclick, act)
    DebugPrint("-------------------------------------")
    DebugPrint("ToggleEntitySelection: ent:", tostring(ent), "rightclick:", rightclick)
    if self:IsSelectedEntity(ent) then
        self:DeselectEntity(ent)
    else
        self:SelectEntity(ent, rightclick, act)
    end
end

function ActionQueuer:ClearSelectedEntities()
    DebugPrint("-------------------------------------")
    DebugPrint("ClearSelectedEntities")
    self.double_click_flag = false
    self.drag_click_selected_flag = false
    DebugPrint("drag_click_selected_flag", self.drag_click_selected_flag)
    DebugPrint("double_click_flag", self.double_click_flag)
    self.selected_ents_client_memory = {}
    self.last_target_ent = nil
    for ent in pairs(self.selected_ents) do
        self:DeselectEntity(ent)
    end
    for tile in pairs(self.selected_farm_tiles) do
        self:DeselectFarmTile(tile)
    end
end

function ActionQueuer:ClearSelectionThread()
    DebugPrint("-------------------------------------")
    DebugPrint("ClearSelectionThread")
    if self.selection_thread then
        DebugPrint("Thread cleared:", self.selection_thread.id)
        KillThreadsWithID(self.selection_thread.id)
        self.selection_thread:SetList(nil)
        self.selection_thread = nil
        self.selection_widget:Hide()
    end
end

function ActionQueuer:ClearActionThread()
    DebugPrint("-------------------------------------")
    DebugPrint("ClearActionThread")
    if self.action_thread then
        DebugPrint("Thread cleared:", self.action_thread.id)
        KillThreadsWithID(self.action_thread.id)
        self.action_thread:SetList(nil)
        self.action_thread = nil
        self.auto_fishing = false
        self.TL, self.TR, self.BL, self.BR = nil, nil, nil, nil
    end
end

function ActionQueuer:ClearAllThreads()
    DebugPrint("-------------------------------------")
    DebugPrint("ClearAllThreads")
    self:ClearActionThread()
    self:ClearSelectionThread()
    self:ClearSelectedEntities()
    self.selection_widget:Kill()
end

ActionQueuer.OnRemoveEntity = ActionQueuer.ClearAllThreads
ActionQueuer.OnRemoveFromEntity = ActionQueuer.ClearAllThreads

-- local function GetSpeed(locomotor)
    -- local pc = ThePlayer.components.playercontroller
    -- if pc.locomotor then
        -- DebugPrint("groundspeedmultiplier:", locomotor.groundspeedmultiplier)
        -- DebugPrint("externalspeedmultiplier:", locomotor.externalspeedmultiplier)
    -- end
    -- local speed = locomotor:GetRunSpeed()
    -- return speed or speed / (locomotor:TempGroundSpeedMultiplier() or locomotor.groundspeedmultiplier or 1)
-- end
-- -- Get the movement speed, but not calculate the plus bonus
-- function ActionQueuer:GetSpeed()
    -- local pc = ThePlayer.components.playercontroller
    -- if not pc then
        -- return
    -- end
    -- if pc.locomotor then
        -- return GetSpeed(pc.locomotor)
    -- else
        -- local speed = GetSpeed(ThePlayer:AddComponent("locomotor"))
        -- ThePlayer:RemoveComponent("locomotor")
        -- return speed
    -- end
-- end

return ActionQueuer
