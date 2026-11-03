--==============================================================================
-- ESIR FILE MAP
-- owns: factory passage settings, category policy and geometry bounds
-- loaded_by: settings.lua, factory-passage stages, map settings schema, admin registry
-- cadence: settings/data stage and pure runtime setting reads
-- forwarded_events: startup_setting_definitions, runtime_setting_definition, runtime_setting_definitions, update_budget, circuit_scan_budget, circuit_scanner_enabled, resolve
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup settings
--==============================================================================
-- blueprint: .codex/esir/blueprints/factory-passage.md#contract
local config = {}
config.prefix = "ei-factory-passage-"
config.layer = "ei_pipe_joint"
config.helper_prefix = "ei-factory-passage-joint-"
config.catalog = "ei-factory-passage"
config.budget = 256
config.budget_setting = config.prefix.."update-budget"
config.budget_min = 1
config.budget_max = 1024
config.circuit_enabled_setting = config.prefix.."circuit-scanner-enabled"
config.circuit_budget_setting = config.prefix.."circuit-scan-budget"
config.circuit_budget = 1
config.circuit_cooldown = 60
config.helper_steps = 64
config.helper_quantum = 1/16
config.overlap = 1/32
config.native_pipe_types={pipe=true,["pipe-to-ground"]=true,["infinity-pipe"]=true}
config.excluded_flags={["placeable-off-grid"]="off-grid"}
config.author_opt_out="squeak_behaviour"
config.support_flags={["not-selectable-in-game"]=true}
config.excluded_receivers={car=true,["spider-vehicle"]=true,locomotive=true,["cargo-wagon"]=true,["fluid-wagon"]=true,["artillery-wagon"]=true,unit=true,character=true}
-- These are operational collision owners, not generic invisible support entities.
function config.operational_category(name)
    if name=="ei-gate" or name=="ei-gate-container" then return "logistics" end
    if name:match("^ei%-induction%-matrix%-core%-%d+$") then return "power" end
end
function config.helper_names()
    local names={}
    for _,axis in ipairs{"horizontal","vertical"} do
        for step=1,config.helper_steps do names[#names+1]=config.helper_prefix..axis.."-"..step end
    end
    return names
end
config.categories = {"production", "power", "logistics", "turrets"}
config.groups = {
    production = {"assembling-machine", "furnace", "mining-drill", "lab", "rocket-silo", "agricultural-tower", "asteroid-collector"},
    power = {"generator", "burner-generator", "boiler", "reactor", "fusion-reactor", "fusion-generator", "accumulator", "solar-panel", "electric-energy-interface", "electric-pole", "power-switch", "lightning-attractor"},
    logistics = {"container", "logistic-container", "linked-container", "infinity-container", "inserter", "arithmetic-combinator", "decider-combinator", "constant-combinator", "selector-combinator", "lamp", "programmable-speaker", "beacon", "radar", "roboport", "train-stop", "cargo-landing-pad", "cargo-bay"},
    turrets = {"ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"},
    pipes = {"pipe", "pipe-to-ground", "infinity-pipe", "pump", "offshore-pump", "storage-tank", "heat-pipe", "heat-interface", "valve"},
}
config.type_category = {}
for category, types in pairs(config.groups) do
    for _, kind in ipairs(types) do config.type_category[kind] = category end
end

---@return data.ModSettingPrototype[]
function config.startup_setting_definitions()
    local definitions = {{type="bool-setting", name=config.prefix.."enabled", setting_type="startup", default_value=true, order="passage-a"}}
    for index, category in ipairs(config.categories) do
        definitions[#definitions+1] = {type="bool-setting", name=config.prefix..category, setting_type="startup", default_value=true, order="passage-b"..index}
    end
    definitions[#definitions+1] = {type="string-setting", name=config.prefix.."pipe-mode", setting_type="startup", default_value="esir",
        allowed_values={"vanilla", "squeak-through", "esir"}, order="passage-c"}
    for _,definition in ipairs(definitions) do
        definition.localised_description={"",{"mod-setting-description."..definition.name},"\n\n",{"ei-factory-passage.common"}}
    end
    return definitions
end

---@return data.IntSettingPrototype
function config.runtime_setting_definition()
    return {type="int-setting",name=config.budget_setting,setting_type="runtime-global",
        default_value=config.budget,minimum_value=config.budget_min,maximum_value=config.budget_max,order="passage-d"}
end

---@return data.ModSettingPrototype[]
function config.runtime_setting_definitions()
    return {config.runtime_setting_definition(),
        {type="bool-setting",name=config.circuit_enabled_setting,setting_type="runtime-global",default_value=false,order="passage-e"},
        {type="int-setting",name=config.circuit_budget_setting,setting_type="runtime-global",default_value=config.circuit_budget,
            minimum_value=config.budget_min,maximum_value=config.budget_max,order="passage-f"}}
end

---@return integer
function config.update_budget()
    return settings.global[config.budget_setting].value
end

---@return integer
function config.circuit_scan_budget()
    return settings.global[config.circuit_budget_setting].value
end

---@return boolean
function config.circuit_scanner_enabled()
    return settings.global[config.circuit_enabled_setting].value
end

---@return table
function config.resolve()
    local startup = settings.startup
    local master = startup[config.prefix.."enabled"].value
    local companion = (mods or script.active_mods)["squeak-through-2"]~=nil
    local enabled = master and not companion
    local configured = startup[config.prefix.."pipe-mode"].value
    local reason = companion and "companion" or not master and "master-disabled" or configured~="esir" and "pipe-mode" or "active"
    local result = {enabled=enabled, pipe_mode=enabled and configured or "vanilla",configured_mode=configured,inactive_reason=reason}
    for _, category in ipairs(config.categories) do result[category] = enabled and startup[config.prefix..category].value end
    return result
end

---@param box table
---@return number, number, number, number
function config.coordinates(box)
    local a, b = box.left_top or box[1], box.right_bottom or box[2]
    return a.x or a[1], a.y or a[2], b.x or b[1], b.y or b[2]
end

---@param prototype data.EntityPrototype
---@param category string
---@return table|nil, integer|nil, integer|nil
function config.trim_box(prototype, category, pipe_mode)
    if not prototype.collision_box then return end
    if (prototype.collision_box.orientation or prototype.collision_box[3] or 0)~=0 then return end
    local x1,y1,x2,y2 = config.coordinates(prototype.collision_box)
    if not (x1<=0 and y1<=0 and x2>=0 and y2>=0 and x2>x1 and y2>y1) then return end
    -- Native map coordinates truncate to 1/256 before implicit grid sizing.
    local function fixed(value) return math.floor(math.abs(value)*256)/256*(value<0 and -1 or 1) end
    local width = prototype.tile_width or math.ceil(fixed(x2)-fixed(x1))
    local height = prototype.tile_height or math.ceil(fixed(y2)-fixed(y1))
    if width<1 or height<1 then return end
    local border = 0.3
    -- Native connection expansion can trap a character during scripted building.
    -- Leave the same escapable body in both passage modes; ESIR closes joints
    -- with deferred helpers after the character leaves (native proof receipt).
    if pipe_mode~="vanilla" and config.native_pipe_types[prototype.type] then border=config.pipe_border or (0.5-1/256) end
    local nx1,ny1 = math.max(x1,-width/2+border),math.max(y1,-height/2+border)
    local nx2,ny2 = math.min(x2,width/2-border),math.min(y2,height/2-border)
    for _,flag in pairs(prototype.flags or {}) do
        if flag=="building-direction-8-way" or flag=="building-direction-16-way" then
            -- A rotated square's enclosing extent grows by sqrt(2). Protect
            -- the smaller grid dimension even between different headings.
            local radius=math.min(width/2-border,height/2-border)/math.sqrt(2)
            nx1,ny1=math.max(nx1,-radius),math.max(ny1,-radius)
            nx2,ny2=math.min(nx2,radius),math.min(ny2,radius)
            break
        end
    end
    if nx1>=nx2 or ny1>=ny2 then return end
    return {{nx1,ny1},{nx2,ny2}},width,height
end

return config
