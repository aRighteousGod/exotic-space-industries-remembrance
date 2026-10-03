-- Native GUI/action regressions in the isolated full-ESIR fixture only.
local model={}
local function find(parent,predicate)
    for _,child in ipairs(parent.children) do
        if predicate(child.tags) then return child end
        local nested=find(child,predicate);if nested then return nested end
    end
end
local function collector()
    local checks={}
    return checks,function(name,ok,detail)checks[#checks+1]={name=name,ok=not not ok,detail=detail}end
end
function model.start(admin,common,world,player,surface,tick)
    local checks,check=collector()
    admin.open(player,"chunks",tick)
    local session=common.state().sessions[player.index]
    session.surface_index=surface.index;session.position={x=32,y=32};session.area=nil
    local ok,message=admin.execute(player,"chunks",{surface_index=surface.index,force_index=player.force.index,
        position={x=2048,y=2048},radius=31,mode="generate"},tick)
    check("older terrain job admitted before newer placement",ok,message)
    local older=session.last_job
    ok,message=admin.execute(player,"place_entities",{surface_index=surface.index,force_index=player.force.index,
        position={x=32,y=32},place_item={name="wooden-chest",quality="normal"},quantity=1,direction=0},tick)
    check("newer short placement admitted beside terrain job",ok,message)
    storage.ei.admin_world_gui_qc={player=player.index,surface=surface.index,start=tick,older=older,newer=session.last_job}
    check("world regression contains two different job IDs",older and older~=session.last_job)
    return checks
end
function model.finish(admin,gui,common,world,player,tick)
    local checks,check=collector()
    local state=assert(storage.ei.admin_world_gui_qc)
    if tick-state.start<8 then return false,checks end
    admin.open(player,"chunks",tick)
    local session=common.state().sessions[player.index]
    local active={};for _,job in ipairs(world.peek_summary().jobs) do active[job.id]=true end
    check("older terrain job survives newer job completion",active[state.older] and not active[state.newer])
    local chosen=session.drafts.active_job
    check("active-job chooser selects older surviving job",chosen==state.older,chosen)
    local button=assert(session.cancel_job_button)
    check("cancel selection stays enabled after newer job completes",button.enabled)
    gui.on_gui_click{player_index=player.index,element=button,tick=tick}
    active={};for _,job in ipairs(world.peek_summary().jobs) do active[job.id]=true end
    check("GUI cancels older selected job independently of last job",not active[state.older])
    check("empty active-job chooser disables cancellation",not button.enabled and session.drafts.active_job==nil)

    admin.open(player,"enemies",tick)
    session.enemy_mix={};session.drafts.enemy="small-biter"
    session.fields.enemy_count.text="1.5"
    gui.on_gui_change{player_index=player.index,element=session.fields.enemy_count,tick=tick}
    local add=assert(find(session.pages.enemies,function(t)return t.action=="mixture" end))
    gui.on_gui_click{player_index=player.index,element=add,tick=tick}
    check("fractional enemy mixture count is rejected",#session.enemy_mix==0)
    session.fields.enemy_count.text="3"
    gui.on_gui_change{player_index=player.index,element=session.fields.enemy_count,tick=tick}
    gui.on_gui_click{player_index=player.index,element=add,tick=tick}
    check("whole-number enemy mixture count is preserved",#session.enemy_mix==1 and session.enemy_mix[1].count==3)

    admin.open(player,"effects",tick)
    session.fields.pollution_amount.text="999"
    gui.on_gui_change{player_index=player.index,element=session.fields.pollution_amount,tick=tick}
    local presets={}
    for _,amount in ipairs({100,1000,10000}) do
        local preset=assert(find(session.pages.effects,function(t)return t.action=="execute" and t.args and t.args.operation=="add_pollution" and t.args.amount==amount end))
        presets[#presets+1]=preset
        gui.on_gui_click{player_index=player.index,element=preset,tick=tick}
        check("pollutant preset confirms exact amount "..amount,session.confirm and session.confirm.args.amount==amount)
        local cancel=assert(find(session.confirm_frame,function(t)return t.action=="cancel-confirm" end))
        gui.on_gui_click{player_index=player.index,element=cancel,tick=tick}
    end
    local planet=assert(game.planets["ei-admin-qc-no-pollutant"])
    local clean=planet.surface or planet.create_surface()
    assert(clean.pollutant_type==nil,"Fixture planet unexpectedly has a pollutant")
    session.surface_index=clean.index;gui.refresh(player.index,tick)
    check("all pollutant presets disable without native pollutant",not presets[1].enabled and not presets[2].enabled and not presets[3].enabled)
    session.surface_index=state.surface

    admin.open(player,"fluids",tick)
    local original_root=session.root
    local infinite
    for _,prototype in pairs(prototypes.get_entity_filtered{{filter="type",type="resource"}}) do
        if prototype.infinite_resource and (prototype.normal_resource_amount or 0)>0 then infinite=prototype;break end
    end
    assert(infinite,"No infinite resource with a native normal amount")
    session.fields.resource.elem_value=infinite.name
    gui.on_gui_change{player_index=player.index,element=session.fields.resource,tick=tick}
    session.fields.resource_amount.text=tostring(infinite.normal_resource_amount)
    gui.on_gui_change{player_index=player.index,element=session.fields.resource_amount,tick=tick}
    local readout=session.readout.caption
    check("infinite resource shows native amount and 100 percent nominal yield",type(readout)=="table" and readout[1]=="ei-admin.resource-infinite-readout"
        and tonumber(readout[3])==infinite.normal_resource_amount and tonumber(readout[4])==infinite.normal_resource_amount
        and tonumber(readout[5])==100,readout)
    session.fields.resource.elem_value="stone"
    gui.on_gui_change{player_index=player.index,element=session.fields.resource,tick=tick}
    session.fields.resource_amount.text="25"
    gui.on_gui_change{player_index=player.index,element=session.fields.resource_amount,tick=tick}
    readout=session.readout.caption
    check("finite resource readout reflects edited amount",type(readout)=="table" and readout[1]=="ei-admin.resource-finite-readout" and tonumber(readout[3])==25,readout)
    session.fields.resource_amount.text="2.5"
    gui.on_gui_change{player_index=player.index,element=session.fields.resource_amount,tick=tick}
    readout=session.readout.caption
    check("invalid resource amount has explicit readout",type(readout)=="table" and readout[1]=="ei-admin.resource-invalid-readout")
    check("resource selector and field edits retain GUI root",session.root==original_root and original_root.valid)
    storage.ei.admin_world_gui_qc=nil
    return true,checks
end
return model
