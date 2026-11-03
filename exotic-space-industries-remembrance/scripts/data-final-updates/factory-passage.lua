--==============================================================================
-- ESIR FILE MAP
-- owns: final collision clearance and runtime pipe endpoint catalogue
-- loaded_by: data-final-fixes.lua after operating variants
-- cadence: once during final data
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup
--==============================================================================
-- blueprint: .codex/esir/blueprints/factory-passage.md#contract
local config = require("lib/factory-passage-config")
local masks = require("__core__/lualib/collision-mask-util")
local entity_masks = require("__core__/lualib/collision-mask-defaults")
local selected = config.resolve()
local catalog = {pipes={},pipe_names={},characters={},walkable={},changed={},excluded={},character_width=0.4,character_height=0.4}
local characters = {}
local pipe_mask=masks.get_mask(data.raw.pipe.pipe)
local max_character_extent=0
for _, character in pairs(data.raw.character) do
    characters[#characters+1]=masks.get_mask(character)
    if masks.masks_collide(pipe_mask,masks.get_mask(character)) then catalog.characters[character.name]=true end
    if catalog.characters[character.name] and character.collision_box then
        local x1,y1,x2,y2=config.coordinates(character.collision_box)
        if x2>x1 and y2>y1 then
            catalog.character_width=math.min(catalog.character_width,math.floor((x2-x1)*256)/256)
            catalog.character_height=math.min(catalog.character_height,math.floor((y2-y1)*256)/256)
            max_character_extent=math.max(max_character_extent,x2-x1,y2-y1)
        end
    end
end
-- A native pipe adds 0.2 tile at connections. Keep one fixed-point unit of
-- solid core, leaving nearly 0.6 tile even at ESIR's faster diagonal gait.
config.pipe_border=math.max(0.5-1/256,0.2+max_character_extent/2+2/256)
local elevated=data.raw["mod-data"] and data.raw["mod-data"]["elevated-pipes"]
local elevated_names=elevated and elevated.data or {}

local function has_flag(prototype, value)
    for _, flag in pairs(prototype.flags or {}) do if flag==value then return true end end
    return false
end

local function collides(prototype)
    local mask=masks.get_mask(prototype)
    if mask.colliding_with_tiles_only then return false end
    for _, character in ipairs(characters) do if masks.masks_collide(mask,character) then return true end end
    return false
end

local function eligible(prototype)
    if prototype[config.author_opt_out]==false then return false,"author-opt-out" end
    for flag,reason in pairs(config.excluded_flags) do if has_flag(prototype,flag) then return false,reason end end
    if not config.operational_category(prototype.name) then
        if prototype.selectable_in_game==false then return false,"support-helper" end
        for flag in pairs(config.support_flags) do if has_flag(prototype,flag) then return false,"support-helper" end end
    end
    if not (prototype.minable or prototype.placeable_by or has_flag(prototype,"player-creation")) then return false,"not-player-infrastructure" end
    if not collides(prototype) then return false,"already-walkable" end
    return true
end

local function connection_geometry_supported(prototype)
    -- A physical normal joint must be cardinal; underground/linked spans are ignored.
    local noncardinal=has_flag(prototype,"building-direction-8-way") or has_flag(prototype,"building-direction-16-way")
    if config.native_pipe_types[prototype.type] and noncardinal then return false end
    local boxes={}
    for _,box in pairs(prototype.fluid_boxes or {}) do boxes[#boxes+1]=box end
    for _,field in ipairs{"fluid_box","input_fluid_box","output_fluid_box","fuel_fluid_box","oxidizer_fluid_box"} do
        if prototype[field] then boxes[#boxes+1]=prototype[field] end
    end
    if prototype.energy_source and prototype.energy_source.fluid_box then boxes[#boxes+1]=prototype.energy_source.fluid_box end
    local trimmed=config.trim_box(prototype,"pipes","esir")
    if not trimmed then return false end
    local x1,y1,x2,y2=config.coordinates(trimmed)
    local function supported(port,heat_port)
        local direction=port.direction
        local position=port.position
        if not direction or direction%4~=0 or not position then return false end
        local x,y=position.x or position[1],position.y or position[2]
        if type(x)~="number" or type(y)~="number" or x~=x or y~=y then return false end
        if heat_port then
            if direction==0 or direction==8 then return x>x1-0.16 and x<x2+0.16 and y>=y1-1 and y<=y2+1 end
            return y>y1-0.16 and y<y2+0.16 and x>=x1-1 and x<=x2+1
        end
        -- Native normal fluid ports must remain inside the collision box.
        return x>=x1 and x<=x2 and y>=y1 and y<=y2
    end
    local physical=false
    for _, box in pairs(boxes) do
        for _, port in pairs(box.pipe_connections or {}) do
            if (port.connection_type or "normal")=="normal" then
                physical=true
                if not supported(port) then return false end
            end
        end
    end
    local heat=prototype.heat_buffer or (prototype.energy_source and prototype.energy_source.type=="heat" and prototype.energy_source)
    for _,port in pairs(heat and heat.connections or {}) do physical=true;if not supported(port,true) then return false end end
    return not physical or not noncardinal
end

if selected.enabled then
    for kind, default_category in pairs(config.type_category) do
        for name, prototype in pairs(data.raw[kind] or {}) do
            if not collides(prototype) then catalog.walkable[name]=true end
            local category=config.operational_category(name) or (elevated_names[name] and "pipes" or default_category)
            local active=category=="pipes" and selected.pipe_mode~="vanilla" or selected[category]
            if active then
                local admitted,reason=eligible(prototype)
                if admitted and category=="pipes" and selected.pipe_mode=="esir" then
                    for character_name,character in pairs(data.raw.character) do
                        if masks.masks_collide(masks.get_mask(prototype),masks.get_mask(character))~=(catalog.characters[character_name]==true) then
                            admitted,reason=false,"unsupported-character-collision-mask";break
                        end
                    end
                end
                if admitted and not connection_geometry_supported(prototype) then admitted,reason=false,"unsupported-connection-geometry" end
                if admitted then
                    local box,width,height=config.trim_box(prototype,category,selected.pipe_mode)
                    if box then
                        local before=table.deepcopy(prototype.collision_box)
                        local original_width,original_height=prototype.tile_width,prototype.tile_height
                        prototype.collision_box=box
                        prototype.tile_width=width
                        prototype.tile_height=height
                        catalog.changed[name]={category=category,before=before,after=table.deepcopy(box),width=width,height=height,original_width=original_width,original_height=original_height}
                        if category=="pipes" then catalog.pipes[name]=true;catalog.pipe_names[#catalog.pipe_names+1]=name end
                    else catalog.excluded[name]="unsupported-body-geometry" end
                else catalog.excluded[name]=reason end
            end
        end
    end
end
-- Native upgrade targets require identical boxes. An opt-out or category boundary
-- protects the entire connected upgrade family instead of breaking placement.
local entities={}
for kind,group in pairs(data.raw) do if entity_masks[kind] then
    for name,prototype in pairs(group) do
        if prototype.collision_box or prototype.fluid_box or prototype.fluid_boxes or prototype.input_fluid_box
            or prototype.output_fluid_box or prototype.fuel_fluid_box or prototype.oxidizer_fluid_box or prototype.heat_buffer
            or (prototype.energy_source and (prototype.energy_source.fluid_box or prototype.energy_source.type=="heat")) then
            entities[name]=prototype
            if not prototype.collision_box or not collides(prototype) then catalog.walkable[name]=true end
        end
    end
end end
-- A narrowed pipe can meet any receiver sharing its native connection category.
-- Quarantine a category if a receiver cannot be covered, before the engine loads
-- these boxes. Runtime cannot restore one placed entity's prototype collision.
local function fluid_ports(prototype)
    local ports={}
    local boxes={}
    for _,box in pairs(prototype.fluid_boxes or {}) do boxes[#boxes+1]=box end
    for _,field in ipairs{"fluid_box","input_fluid_box","output_fluid_box","fuel_fluid_box","oxidizer_fluid_box"} do if prototype[field] then boxes[#boxes+1]=prototype[field] end end
    if prototype.energy_source and prototype.energy_source.fluid_box then boxes[#boxes+1]=prototype.energy_source.fluid_box end
    for _,box in pairs(boxes) do for _,port in pairs(box.pipe_connections or {}) do
        if (port.connection_type or "normal")=="normal" then ports[#ports+1]=port end
    end end
    return ports
end
local function categories(port)
    local value=port.connection_category or "default"
    return type(value)=="table" and value or {value}
end
local function receiver_supported(prototype,port)
    if config.excluded_receivers[prototype.type] then return true end
    if has_flag(prototype,"building-direction-16-way")
        or (config.native_pipe_types[prototype.type] and has_flag(prototype,"building-direction-8-way")) then return false end
    if catalog.walkable[prototype.name] then return true end
    local box=prototype.collision_box
    if not box or (box.orientation or box[3] or 0)~=0 then return false end
    local x1,y1,x2,y2=config.coordinates(box)
    local function pose(position,direction,turn)
        if not position or not direction or direction%4~=0 then return false end
        local px,py=position.x or position[1],position.y or position[2]
        if type(px)~="number" or type(py)~="number" or px~=px or py~=py then return false end
        local angle=turn*math.pi/8
        local c,s=math.cos(angle),math.sin(angle)
        local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
        for _,point in ipairs{{x1,y1},{x1,y2},{x2,y1},{x2,y2}} do
            local x,y=point[1]*c-point[2]*s,point[1]*s+point[2]*c
            left,top,right,bottom=math.min(left,x),math.min(top,y),math.max(right,x),math.max(bottom,y)
        end
        if turn%4~=0 then
            local cx,cy=(x1+x2)/2,(y1+y2)/2
            local rx,ry=cx*c-cy*s,cx*s+cy*c
            local radius=math.min(x2-x1,y2-y1)/2/(math.abs(c)+math.abs(s))
            left,top,right,bottom=rx-radius,ry-radius,rx+radius,ry+radius
        end
        if direction==0 or direction==8 then return px>left-0.16 and px<right+0.16 and py>=top-1 and py<=bottom+1 end
        return py>top-0.16 and py<bottom+0.16 and px>=left-1 and px<=right+1
    end
    if port.position then
        if not pose(port.position,port.direction,0) then return false end
    elseif port.positions then
        for index,position in ipairs(port.positions) do if not pose(position,(port.direction+(index-1)*4)%16,(index-1)*4) then return false end end
    else return false end
    if has_flag(prototype,"building-direction-8-way") then
        if not pose(port.alt_position or port.position or port.positions[1],port.alt_direction or port.direction,2) then return false end
    end
    return true
end
local blocked_categories={}
local blocked_heat
if selected.pipe_mode=="esir" then
    for name,prototype in pairs(entities) do
        for _,port in pairs(fluid_ports(prototype)) do
            if not receiver_supported(prototype,port) then
                for _,category in pairs(categories(port)) do blocked_categories[category]=name end
            end
        end
        local heat=prototype.heat_buffer or (prototype.energy_source and prototype.energy_source.type=="heat" and prototype.energy_source)
        for _,port in pairs(heat and heat.connections or {}) do if not receiver_supported(prototype,port) then blocked_heat=name end end
    end
    for name in pairs(catalog.pipes) do
        local prototype=entities[name]
        if blocked_heat and (prototype.heat_buffer or (prototype.energy_source and prototype.energy_source.type=="heat")) then
            local change=catalog.changed[name]
            prototype.collision_box=change.before;prototype.tile_width=change.original_width;prototype.tile_height=change.original_height
            catalog.changed[name]=nil;catalog.pipes[name]=nil;catalog.excluded[name]="unsupported-heat-receiver:"..blocked_heat
        end
        for _,port in pairs(fluid_ports(prototype)) do for _,category in pairs(categories(port)) do
            if catalog.pipes[name] and blocked_categories[category] then
                local change=catalog.changed[name]
                prototype.collision_box=change.before;prototype.tile_width=change.original_width;prototype.tile_height=change.original_height
                catalog.changed[name]=nil;catalog.pipes[name]=nil
                catalog.excluded[name]="unsupported-receiver:"..blocked_categories[category]
                break
            end
        end;if not catalog.pipes[name] then break end end
    end
end
local function same_box(a,b)
    a=a or {{0,0},{0,0}};b=b or {{0,0},{0,0}}
    local ax,ay,bx,by=config.coordinates(a)
    local cx,cy,dx,dy=config.coordinates(b)
    local function quantize(value) return math.floor(math.abs(value)*256)*(value<0 and -1 or 1) end
    return quantize(ax)==quantize(cx) and quantize(ay)==quantize(cy) and quantize(bx)==quantize(dx) and quantize(by)==quantize(dy)
end
local repeat_pass=true
while repeat_pass do
    repeat_pass=false
    for name,prototype in pairs(entities) do
        local target=entities[prototype.next_upgrade]
        if target and not same_box(prototype.collision_box,target.collision_box) then
            for _,member in ipairs{prototype,target} do
                local change=catalog.changed[member.name]
                if change then
                    member.collision_box=change.before
                    member.tile_width=change.original_width
                    member.tile_height=change.original_height
                    catalog.changed[member.name]=nil;catalog.pipes[member.name]=nil
                    catalog.excluded[member.name]="upgrade-family-preserved"
                    repeat_pass=true
                end
            end
        end
    end
end
catalog.pipe_names={}
for name in pairs(catalog.pipes) do catalog.pipe_names[#catalog.pipe_names+1]=name end
table.sort(catalog.pipe_names)
if selected.pipe_mode=="esir" then
    for _, character in pairs(data.raw.character) do
        local mask=table.deepcopy(masks.get_mask(character))
        local admits=#catalog.pipe_names>0
        for name in pairs(catalog.pipes) do
            for kind in pairs(config.type_category) do
                local pipe=data.raw[kind] and data.raw[kind][name]
                if pipe and not masks.masks_collide(mask,masks.get_mask(pipe)) then admits=false;break end
            end
            if not admits then break end
        end
        if admits then mask.layers[config.layer]=true;character.collision_mask=mask;catalog.characters[character.name]=true end
    end
end
data:extend{{type="mod-data",name=config.catalog,data=catalog}}
log("EI factory passage: "..selected.pipe_mode)
