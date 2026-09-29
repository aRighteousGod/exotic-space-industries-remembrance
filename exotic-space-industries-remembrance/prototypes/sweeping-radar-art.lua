--==============================================================================
-- ESIR FILE MAP
-- owns: retained 256-facing radar body/shadow/glow animation prototypes
-- loaded_by: prototypes/sweeping-radar
-- cadence: data stage; exact packed pixels, fixed bases in every master frame
--==============================================================================
local config=require("lib/sweeping-radar-config")
local art={}
local graphics=ei_path.."graphics/entities/"

local function visual_entity(name,pictures)
    return {type="simple-entity-with-owner",name=name,hidden=true,hidden_in_factoriopedia=true,
        flags={"not-on-map","placeable-off-grid","not-blueprintable","not-deconstructable","not-flammable"},
        selectable_in_game=false,collision_mask={layers={}},collision_box={{0,0},{0,0}},
        selection_box={{0,0},{0,0}},render_layer="object",random_variation_on_create=false,
        pictures=pictures}
end

---@param name string
---@param role string
---@param page integer
---@return table
local function layer(name,role,page)
    local definition=config.art[name]
    local shadow=role=="shadow"
    return {filename=graphics..definition.asset.."/"..definition.asset.."-"..role..(page==2 and "_1" or "")..".png",
        width=shadow and definition.shadow_width or 208,height=shadow and 160 or definition.body_height,
        line_length=8,frame_count=config.art_page_frames,animation_speed=1,scale=0.5,
        shift=shadow and {definition.shadow_shift,0} or {0,definition.body_shift},
        draw_as_shadow=shadow or nil,draw_as_glow=role=="glow" or nil,
        blend_mode=role=="glow" and "additive" or "normal"}
end

for _,name in ipairs(config.names) do
    for page=1,2 do
        for _,lit in ipairs(config.art[name].glow and {false,true} or {false}) do
            local pictures={}
            for frame=0,config.art_page_frames-1 do
                local layers={}
                for _,role in ipairs(lit and {"body","shadow","glow"} or {"body","shadow"}) do
                    local part=layer(name,role,page)
                    part.x=(frame%8)*part.width;part.y=math.floor(frame/8)*part.height
                    part.frame_count=nil;part.animation_speed=nil;part.line_length=nil
                    layers[#layers+1]=part
                end
                pictures[#pictures+1]={layers=layers}
            end
            data:extend({visual_entity(name.."-visual-"..page..(lit and "-lit" or ""),pictures)})
        end
        data:extend({{type="animation",name=name.."-body-"..page,
            layers={layer(name,"body",page),layer(name,"shadow",page)}}})
        if config.art[name].glow then
            local glow=layer(name,"glow",page)
            glow.type="animation";glow.name=name.."-glow-"..page
            data:extend({glow})
        end
    end
    local index=config.art[name].north
    local page=math.floor(index/config.art_page_frames)+1
    local frame=index%config.art_page_frames
    local body,shadow=layer(name,"body",page),layer(name,"shadow",page)
    for _,part in ipairs{body,shadow} do
        part.x=(frame%8)*part.width;part.y=math.floor(frame/8)*part.height
        part.frame_count=1;part.line_length=1
    end
    data:extend({{type="animation",name=name.."-preview",layers={body,shadow}}})
    -- Placement preview is native; built chassis use scripted frozen frames.
    local preview=table.deepcopy(body)
    preview.frame_count=nil;preview.animation_speed=nil;preview.line_length=nil
    art[name]=preview
    local ghost=table.deepcopy(preview)
    ghost.tint={r=0.35,g=0.65,b=1,a=0.45}
    data:extend({visual_entity(name.."-visual-ghost",{ghost})})
end
return art
