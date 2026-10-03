-- blueprint: .codex/esir/blueprints/camera-windows.md#contract
-- Reusable detached camera windows. Access policy belongs to the caller.
-- Entity tracking is native; only open remote/god view cameras schedule reads.
local scheduler = require("lib/runtime-scheduler")
local model = {}
local GUI = "ei-camera-window"
local INTERVAL = 12

---@class EiCameraOptions
---@field owner string Caller namespace, used for scoped shutdown.
---@field id string|nil Stable window key within that namespace.
---@field title LocalisedString|nil
---@field player_index uint|nil Target player, not viewer.
---@field entity LuaEntity|nil Target entity.
---@field follow_view boolean|nil Follow a player's remote view instead of their body.
---@field position MapPosition|nil
---@field surface_index uint|nil
---@field zoom number|nil

local function peek() return storage.ei_camera_windows end
local function state()
    storage.ei_camera_windows = storage.ei_camera_windows or {windows={}, by_target={}, objects={}, due={}, next_due=nil}
    return storage.ei_camera_windows
end
local function valid(entity) return entity and entity.valid and entity.object_name == "LuaEntity" end
local function key(viewer, owner, id) return viewer .. ":" .. owner .. ":" .. (id or "main") end
local function set(element, property, value)
    if element[property] ~= value then element[property] = value end
end
local function schedule(entry, tick)
    if entry.due then return end
    local root=state()
    entry.due=tick+INTERVAL
    scheduler.delayed_schedule(root.due,entry.due,entry.key)
    root.next_due=math.min(root.next_due or entry.due,entry.due)
end

-- Native display events resize the same camera and preserve its zoom/attachment.
-- Lua GUI dimensions use scale-independent units; screen locations use pixels.
local function resize(entry,player)
    if not (entry.root and entry.root.valid and entry.camera and entry.camera.valid) then return end
    local scale=player.display_scale;local resolution=player.display_resolution
    local width=math.max(1,math.floor(math.min(480,resolution.width/scale-40,(resolution.height/scale-120)/0.625)))
    local camera_height=math.max(1,math.floor(width*0.625))
    local frame_width,frame_height=width+16,camera_height+96
    entry.root.style.width=frame_width;entry.root.style.height=frame_height
    entry.camera.style.width=width;entry.camera.style.height=camera_height
    entry.status.style.minimal_width=0;entry.status.style.maximal_width=width;entry.status.style.maximal_height=44
    if entry.title and entry.title.valid then
        entry.title.style.maximal_width=width
        entry.title_caption.style.minimal_width=0;entry.title_caption.style.maximal_width=math.max(1,width-112)
    end
    local margin=math.floor(8*scale)
    local x_max=math.max(0,math.floor(resolution.width-frame_width*scale-margin))
    local y_max=math.max(0,math.floor(resolution.height-frame_height*scale-margin))
    local location=entry.root.auto_center and {x=(resolution.width-frame_width*scale)/2,y=(resolution.height-frame_height*scale)/2}
        or entry.root.location or {x=margin,y=margin}
    entry.root.location={x=math.floor(math.max(0,math.min(x_max,math.max(margin,location.x)))),
        y=math.floor(math.max(0,math.min(y_max,math.max(margin,location.y))))}
end

function model.on_display_changed(event)
    local root=peek();if not root then return end
    local player=game.get_player(event.player_index);if not (player and player.valid) then return end
    for _,entry in pairs(root.windows) do if entry.viewer==event.player_index then resize(entry,player) end end
end

local function refresh(entry, tick)
    local viewer=game.get_player(entry.viewer)
    if not (viewer and viewer.valid and viewer.connected and entry.root and entry.root.valid) then return false end
    local camera, status=entry.camera,entry.status
    if not (camera and camera.valid) then return false end
    local opts=entry.options
    local target=opts.player_index and game.get_player(opts.player_index)
    local entity=opts.entity
    local position,surface
    local caption=opts.title or {"ei-admin.camera"}
    local fallback=false
    if opts.player_index then
        if not (target and target.valid and target.connected) then
            set(camera,"visible",false)
            if entry.caption_signature~="offline" then status.caption={"ei-admin.camera-offline"};entry.caption_signature="offline" end
            return true
        end
        caption=target.name
        if opts.follow_view then
            surface,position=target.surface,target.position
            if target.controller_type~=defines.controllers.remote then entity=target.character end
        else
            surface,position=target.physical_surface,target.physical_position
            entity=target.character
        end
        fallback=not valid(entity)
    elseif valid(entity) then
        surface,position=entity.surface,entity.position
        caption=opts.title or entity.localised_name
    elseif opts.entity then
        set(camera,"visible",false)
        if entry.caption_signature~="unavailable" then status.caption={"ei-admin.camera-unavailable"};entry.caption_signature="unavailable" end
        return true
    else
        surface=opts.surface_index and game.get_surface(opts.surface_index)
        position=opts.position
    end
    if not (surface and surface.valid and position) then
        set(camera,"visible",false)
        if entry.caption_signature~="unavailable" then status.caption={"ei-admin.camera-unavailable"};entry.caption_signature="unavailable" end
        return true
    end
    set(camera,"visible",true)
    if camera.surface_index~=surface.index then camera.surface_index=surface.index end
    if valid(entity) then
        if entry.bound_entity~=entity then camera.entity=entity;entry.bound_entity=entity;entry.position=nil end
    else
        if entry.bound_entity then camera.entity=nil;entry.bound_entity=nil end
        local prior=entry.position
        if not prior or prior.x~=position.x or prior.y~=position.y then
            camera.position=position;entry.position={x=position.x,y=position.y}
        end
    end
    local signature=opts.player_index and tostring(caption) or (valid(entity) and entity.name or "location")
    if entry.caption_signature~=signature then status.caption=caption;entry.caption_signature=signature end
    if fallback and entry.root.visible then schedule(entry,tick) end
    return true
end

---@param player LuaPlayer
---@param options EiCameraOptions
---@param tick MapTick
---@return LuaGuiElement|nil,string|nil
function model.open(player,options,tick)
    if not (player and player.valid and player.connected) then return nil,"A connected viewer is required." end
    if not (options and type(options.owner)=="string" and options.owner:match("^[%w_-]+$")) then return nil,"Invalid camera owner." end
    local root=state()
    local id=key(player.index,options.owner,options.id)
    local old=root.windows[id]
    local location=old and old.root and old.root.valid and old.root.location
    model.close(player.index,options.owner,options.id)
    local count=0
    for _,window in pairs(root.windows) do if window.viewer==player.index then count=count+1 end end
    if count>=4 then return nil,"Close a camera first (four windows per viewer)." end
    local name=GUI.."-"..options.owner.."-"..(options.id or "main")
    if player.gui.screen[name] then player.gui.screen[name].destroy() end
    local frame=player.gui.screen.add{type="frame",name=name,direction="vertical",tags={parent_gui=GUI,key=id}}
    frame.style.padding=8
    local title=frame.add{type="flow",direction="horizontal"}
    local title_caption=title.add{type="label",caption=options.title or {"ei-admin.camera"},tooltip=options.title or {"ei-admin.camera"},style="frame_title"}
    local spacer=title.add{type="empty-widget",style="ei_titlebar_draggable_spacer"};spacer.drag_target=frame
    for _,button in ipairs({{"minus","−"},{"plus","+"},{"close","×"}}) do
        title.add{type="button",caption=button[2],style="frame_action_button",tags={parent_gui=GUI,key=id,action=button[1]}}
    end
    local camera=frame.add{type="camera",position=player.physical_position,surface_index=player.physical_surface.index,
        zoom=math.max(0.1,math.min(4,tonumber(options.zoom) or 0.5))}
    local status=frame.add{type="label",caption="",style="ei_admin_caption"}
    if location then frame.location=location else frame.auto_center=true end
    local entry={key=id,viewer=player.index,owner=options.owner,id=options.id,options=options,root=frame,camera=camera,status=status,
        title=title,title_caption=title_caption}
    resize(entry,player)
    root.windows[id]=entry
    if options.player_index then
        root.by_target[options.player_index]=root.by_target[options.player_index] or {}
        root.by_target[options.player_index][id]=true
    elseif valid(options.entity) then
        local registration=script.register_on_object_destroyed(options.entity)
        entry.registration=registration
        root.objects[registration]=root.objects[registration] or {}
        root.objects[registration][id]=true
    end
    refresh(entry,tick)
    return frame
end

---@param viewer_index uint
---@param owner string
---@param id string|nil
function model.close(viewer_index,owner,id)
    local root=peek();if not root then return end
    local k=key(viewer_index,owner,id);local entry=root.windows[k]
    if not entry then return end
    if entry.root and entry.root.valid then entry.root.destroy() end
    local target=entry.options.player_index
    if target and root.by_target[target] then root.by_target[target][k]=nil;if not next(root.by_target[target]) then root.by_target[target]=nil end end
    if entry.registration and root.objects[entry.registration] then
        root.objects[entry.registration][k]=nil
        if not next(root.objects[entry.registration]) then root.objects[entry.registration]=nil end
    end
    if entry.due and root.due[entry.due] then
        local bucket=root.due[entry.due]
        for i=#bucket,1,-1 do if bucket[i]==k then table.remove(bucket,i) end end
        if #bucket==0 then root.due[entry.due]=nil end
        root.next_due=scheduler.delayed_next_due_tick(root.due)
    end
    root.windows[k]=nil
end

function model.close_owner(owner,viewer_index)
    local root=peek();if not root then return end
    for _,entry in pairs(root.windows) do
        if entry.owner==owner and (not viewer_index or entry.viewer==viewer_index) then model.close(entry.viewer,entry.owner,entry.id) end
    end
end

function model.on_gui_click(event)
    local element=event.element
    if not (element and element.valid and element.tags.parent_gui==GUI) then return false end
    local root=peek();local entry=root and root.windows[element.tags.key]
    if not entry or entry.viewer~=event.player_index then return true end
    if element.tags.action=="close" then model.close(entry.viewer,entry.owner,entry.id)
    elseif (element.tags.action=="plus" or element.tags.action=="minus") and entry.camera and entry.camera.valid then
        local factor=element.tags.action=="plus" and 1.25 or 0.8
        entry.camera.zoom=math.max(0.1,math.min(4,entry.camera.zoom*factor))
        entry.options.zoom=entry.camera.zoom
    end
    return true
end

function model.on_gui_closed(event)
    local element=event.element
    if not (element and element.valid and element.tags.parent_gui==GUI) then return end
    local root=peek();local entry=root and root.windows[element.tags.key]
    if entry then model.close(entry.viewer,entry.owner,entry.id) end
end

function model.on_player_changed(event)
    local root=peek();if not root then return end
    for id in pairs(root.by_target[event.player_index] or {}) do
        local entry=root.windows[id]
        if entry then refresh(entry,event.tick) end
    end
end

function model.on_player_left(event)
    local root=peek();if not root then return end
    for _,entry in pairs(root.windows) do if entry.viewer==event.player_index then model.close(entry.viewer,entry.owner,entry.id) end end
    model.on_player_changed(event)
end

function model.on_object_destroyed(event)
    local root=peek();local windows=root and root.objects[event.registration_number]
    if not windows then return end
    root.objects[event.registration_number]=nil
    for id in pairs(windows) do local entry=root.windows[id];if entry then refresh(entry,event.tick) end end
end

function model.has_tick_work(tick)
    local root=peek();return root and root.next_due and tick>=root.next_due or false
end

function model.updater(tick)
    local root=peek();if not root or not root.next_due or tick<root.next_due then return end
    local due=scheduler.delayed_take_due_through(root.due,tick)
    root.next_due=nil
    for _,id in ipairs(due or {}) do
        local entry=root.windows[id]
        if entry and entry.due and entry.due<=tick then
            entry.due=nil
            if not refresh(entry,tick) then model.close(entry.viewer,entry.owner,entry.id) end
        end
    end
    root.next_due=scheduler.delayed_next_due_tick(root.due)
end

model.gui_name=GUI
return model
