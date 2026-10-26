-- Native serialization of pending, delivered and expiring legacy ecology records.
local model={}
local fields={'items','by_id','coalesced','next_id','next_tick','cursor','cleanup_cursor','anchors','dropped','delivered','roster_epoch'}
function model.prepare(ctx,player,tick)
    local s=storage.alert_fixture
    local channel=ctx.alerts.channel_state('ecology')
    assert(#channel.items==0,'clean ecology baseline before migration fixture')
    local owner=storage.ei.terrain_evolution.surfaces[s.surface.index]
    for i,category in ipairs{'wildfire','flood','drought'} do
        assert(ctx.ecology.record_effect{category=category,surface=s.surface,owner=owner,position={x=32*i,y=0},count=1,tick=tick})
    end
    channel.next_tick=tick
    ctx.alerts.service_channel('ecology',tick)
    local delivered
    for _,r in ipairs(channel.items) do if #r.recipients>0 then delivered=r end end
    assert(delivered,'migration fixture has a native delivered record')
    -- Reconstruct the legacy marker/icon only inside the isolated fixture.
    local old=delivered.anchor
    player.remove_alert{entity=old,type=defines.alert_type.custom,icon={type='virtual',name=ctx.catalog.by_id[delivered.alert_id].icon_signal}}
    old.destroy()
    delivered.anchor=s.surface.create_entity{name='ei-ecology-alert-anchor',position=delivered.position,force='neutral'}
    delivered.anchor.destructible=false
    player.add_custom_alert(delivered.anchor,{type='virtual',name=delivered.category=='wildfire' and 'signal-fire' or 'signal-info'},{'ei-ecology.category-'..delivered.category},true)
    delivered.delivered[player.index]=true;delivered.delivery_complete=true
    channel.items[3].expires=tick+10
    storage.ei.gate.gate[s.unit].alerts_enabled=false
    ctx.ecology.set_preference(player,'restoration',false)
    s.migration={records={},delivered=channel.delivered,next_id=channel.next_id,anchors=channel.anchors,player_index=player.index,marker=delivered.anchor}
    for _,r in ipairs(channel.items) do s.migration.records[#s.migration.records+1]={record=r,id=r.id,expires=r.expires,token=r.chunk_token,references=r.chunk_token.references,owner=r.owner} end
    local legacy=storage.ei.ecology_alerts
    for _,key in ipairs(fields) do legacy[key]=channel[key] end
    legacy.alert_delivery_version=nil
    storage.ei.alerts.channels.ecology=nil
    s.phase='saved-legacy';s.save_tick=tick
    game.auto_save('unified-alerts-migration')
end
function model.resume(ctx,player,tick)
    local s=storage.alert_fixture;local saved=s.migration
    -- Same initialization path used by configuration migration, after native reload.
    ctx.ecology.initialize(tick);ctx.alerts.initialize(tick)
    local channel=ctx.alerts.channel_state('ecology')
    assert(#channel.items==3 and channel.next_id==saved.next_id and channel.delivered==saved.delivered and channel.anchors==saved.anchors,'native migration preserves indexes and counters')
    for _,item in ipairs(saved.records) do
        local r=channel.by_id[item.id]
        assert(r==item.record and r.expires==item.expires and r.owner==item.owner and r.chunk_token==item.token and r.chunk_token.references==item.references,'native migration preserves receipt identities, deadline and reference count')
    end
    assert(saved.marker.valid and saved.marker.name=='ei-ecology-alert-anchor','legacy marker adopted')
    assert(storage.ei.gate.gate[s.unit].alerts_enabled==false,'gate Off survives native serialization')
    assert(player.mod_settings['ei-ecology-alert-restoration'].value==false and not ctx.ecology.preferences(player).restoration,'native preference false survives migration')
    ctx.ecology.initialize(tick)
    assert(ctx.alerts.channel_state('ecology')==channel,'native migration initializer idempotent')
    s.phase='verify-retirement';s.resume_tick=tick;s.legacy_delivered=channel.delivered
    for _,r in ipairs(channel.items) do r.cancelled=true end
end
function model.finish(ctx,tick)
    local s=storage.alert_fixture
    if tick-s.resume_tick<512 then return end
    local channel=ctx.alerts.channel_state('ecology')
    assert(channel.delivered==s.legacy_delivered,'no duplicate legacy native delivery')
    assert(#channel.items==0 and channel.anchors==0 and not s.migration.marker.valid,'legacy retirement has no orphan records or markers')
    for _,item in ipairs(s.migration.records) do assert(item.record.chunk_token==nil and item.token.references==item.references-1,'each adopted receipt released exactly once') end
    return {complete=true,all_pass=true,engine=script.active_mods.base,scope='Native save/reload of pending, delivered and expiring ecology incidents; exact receipt release, legacy marker adoption, saved false and idempotent migration.'}
end
return model
