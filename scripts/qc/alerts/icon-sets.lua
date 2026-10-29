-- Production stage API and personal selection; Factorio objects are mocked here.
package.path='exotic-space-industries-remembrance/?.lua;'..package.path
local catalog=require('lib/alert-catalog')
package.loaded['__exotic-space-industries-remembrance__/lib/alert-catalog']=catalog
package.loaded['__exotic-space-industries-remembrance__/lib/lib']=require('lib/lib')
local sets=require('lib/alert-icon-sets')
local checks=0
local function check(ok,label)checks=checks+1;assert(ok,label)end
local function reject(fn,label)check(not pcall(fn),label)end
local function stage()
    mods={['example-provider']='1.0.0',['another_provider']='1.0.0',['example-provider__variant']='1.0.0'}
    data={raw={}}
    function data:extend(rows)
        for _,row in ipairs(rows)do
            self.raw[row.type]=self.raw[row.type] or {}
            assert(not self.raw[row.type][row.name],'duplicate mocked prototype')
            self.raw[row.type][row.name]=row
        end
    end
    data:extend(sets.setting_definitions());data:extend(sets.builtin_prototypes())
    return data.raw
end
local function provider(id)
    return {api_version=1,provider='example-provider',id=id,icons={
        ['gate-low-power']={icon='__example-provider__/gate.png',icon_size=128},
        ['ecology-wildfire']={icons={
            {icon='__example-provider__/fire.png',icon_size=64,tint={1,0.5,0},scale=0.5},
            {icon='__example-provider__/outline.png',icon_size=64,shift={x=1,y=-1},draw_background=false},
        }},
    }}
end
local function runtime(raw)
    prototypes={mod_setting=raw['string-setting'],virtual_signal=raw['virtual-signal']}
    settings={startup={[sets.default_setting_name]={value='rendered'}},player_default={unrelated={value=true}}}
    sets.refresh_runtime()
end

do
    local raw=stage();local definitions=sets.setting_definitions()
    check(#definitions==2,'one startup selector and one personal selector')
    check(definitions[1].setting_type=='startup' and definitions[1].default_value=='rendered','startup defaults rendered')
    check(definitions[2].setting_type=='runtime-per-user' and definitions[2].default_value==sets.sentinel,'personal defaults one-shot sentinel')
    check(definitions[1].hidden==false and definitions[2].hidden==false,'both selectors visible')
    check(#definitions[1].allowed_values==4 and #definitions[2].allowed_values==5,'sentinel only offered personally')
    local signals=raw['virtual-signal'];local count=0
    for _ in pairs(signals)do count=count+1 end
    check(count==#catalog.entries*#sets.builtin_ids,'all complete builtin families generated')
    for _,entry in ipairs(catalog.entries)do
        check(sets.signal_name('original',entry.id)==entry.icon_signal,'Original preserves existing native signal')
        for _,id in ipairs(sets.builtin_ids)do
            local signal=signals[sets.signal_name(id,entry.id)]
            local folder=id=='original' and '' or id..'/'
            check(signal.icon=='__exotic-space-industries-remembrance-graphics-6__/graphics/gui/alerts/'..folder..entry.id..'.png'
                and signal.icon_size==128 and signal.hidden and signal.hidden_in_factoriopedia,'builtin path/size/visibility')
        end
    end
    local def=provider('test');local id=sets.register_settings(def)
    check(id=='example-provider__test' and sets.register_data(def)==id,'settings and data share stable provider ID')
    for _,name in ipairs{sets.setting_name,sets.default_setting_name}do
        check(raw['string-setting'][name].allowed_values[#raw['string-setting'][name].allowed_values]==id,'provider selectable in both menus')
    end
    local gate=signals[sets.signal_name(id,'gate-low-power')]
    check(gate.icon=='__example-provider__/gate.png','single artwork override used')
    local fire=signals[sets.signal_name(id,'ecology-wildfire')]
    check(#fire.icons==2 and fire.icons[2].shift.y==-1 and fire.icon==nil,'layered artwork preserved')
    def.icons['ecology-wildfire'].icons[2].shift.y=99
    check(fire.icons[2].shift.y==-1,'registered layers detached from manifest mutation')
    local flood=signals[sets.signal_name(id,'ecology-flood')]
    check(flood.icon==signals[sets.signal_name('rendered','ecology-flood')].icon,'partial provider defaults to Rendered artwork')
    local other=provider('selected');other.provider='another_provider';other.fallback='svg'
    sets.register_settings(other);sets.register_data(other)
    check(signals[sets.signal_name('another_provider__selected','ecology-flood')].icon:find('/svg/',1,true)~=nil,'explicit SVG fallback used')
    runtime(raw)
    local available=sets.available_sets()
    check(table.concat(available,',')=='original,svg,rendered,vanilla,another_provider__selected,example-provider__test','builtin order and sorted providers')
    available[1]='corrupted';check(sets.available_sets()[1]=='original','callers cannot mutate cached available sets')
    check(sets.choice_caption(id)[2][1]=='string-mod-setting.ei-alert-icon-set-'..id,'GUI caption shares native personal locale key')
end

do
    local raw=stage();local def=provider('test');sets.register_settings(def);sets.register_data(def)
    local before=#raw['string-setting'][sets.setting_name].allowed_values
    reject(function()sets.register_settings(def)end,'duplicate settings registration rejected')
    reject(function()sets.register_data(def)end,'duplicate data registration rejected')
    check(#raw['string-setting'][sets.setting_name].allowed_values==before,'failed registration leaves allowed values intact')
    for _,bad in ipairs{
        {api_version=2,provider='example-provider',id='bad'},
        {api_version=1,provider='missing-provider',id='bad'},
        {api_version=1,provider='example-provider',id='bad__id'},
        {api_version=1,provider='example-provider',id='Bad'},
        {api_version=1,provider='example-provider',id='bad',fallback='another_provider__selected'},
        {api_version=1,provider='example-provider',id='bad',icons={unknown={icon='a',icon_size=128}}},
        {api_version=1,provider='example-provider',id='bad',icons={['gate-low-power']={icon='a'}}},
        {api_version=1,provider='example-provider',id='bad',icons={['gate-low-power']={icon='a',icon_size=128,icons={{icon='b',icon_size=64}}}}},
        {api_version=1,provider='example-provider',id='bad',icons={['gate-low-power']={icons={}}}},
        {api_version=1,provider='example-provider',id='bad',icons={['gate-low-power']={icons={{icon='b'}}}}},
        {api_version=1,provider='example-provider',id='bad',icons={['gate-low-power']={icons={{icon='b',icon_size=64,scale=0}}}}},
        {api_version=1,provider='example-provider',id='bad',icons={['gate-low-power']={icons={{icon='b',icon_size=64,tint={r='red'}}}}}},
        {api_version=1,provider='example-provider',id='bad',callback=function()end},
    }do
        reject(function()sets.register_settings(bad)end,'invalid manifest rejected before settings mutation')
        reject(function()sets.register_data(bad)end,'invalid manifest rejected before prototype mutation')
    end
    local cycle=provider('cycle');cycle.icons=cycle
    reject(function()sets.register_data(cycle)end,'cyclic manifest rejected')
    local sparse=provider('sparse');sparse.icons['gate-low-power']={icons={[1]={icon='a',icon_size=64},[3]={icon='b',icon_size=64}}}
    reject(function()sets.register_data(sparse)end,'sparse layers rejected')
    local long=provider(string.rep('a',190));reject(function()sets.register_settings(long)end,'prototype name limit enforced in settings stage')
    reject(function()sets.signal_name('rendered','undeclared')end,'unknown alert ID has no signal')
    local collision_a=provider('variant-test');local collision_b=provider('test');collision_b.provider='example-provider__variant'
    check(sets.register_settings(collision_a)~=sets.register_settings(collision_b),'qualified provider IDs do not flatten different namespaces')
end

do
    local raw=stage();local def=provider('test');local id=sets.register_settings(def);sets.register_data(def);runtime(raw)
    local p={valid=true,mod_settings={unrelated={value=false}}}
    check(sets.player_set(p)=='rendered' and p.mod_settings[sets.setting_name]==nil,'read-only resolution does not write missing preference')
    local resolved,changed=sets.normalize_player(p)
    check(resolved=='rendered' and changed and p.mod_settings[sets.setting_name].value=='rendered','missing personal setting freezes startup default')
    settings.startup[sets.default_setting_name].value='svg'
    resolved,changed=sets.normalize_player(p);check(resolved=='rendered' and not changed,'startup changes preserve concrete personal choice')
    p.mod_settings[sets.setting_name]={value=sets.sentinel}
    resolved,changed=sets.normalize_player(p);check(resolved=='svg' and changed,'sentinel explicitly copies current startup selection')
    check(p.mod_settings.unrelated.value==false,'normalization leaves other personal settings unchanged')
    settings.player_default[sets.setting_name]={value='original'}
    check(sets.normalize_map_default() and settings.player_default[sets.setting_name].value==sets.sentinel,'future players receive one-shot startup default')
    check(not sets.normalize_map_default() and settings.player_default.unrelated.value,'map default normalization is idempotent and scoped')
    settings.startup[sets.default_setting_name].value=id
    local newcomer={valid=true,mod_settings={[sets.setting_name]={value=sets.sentinel}}}
    check(sets.normalize_player(newcomer)==id,'new player can inherit provider startup default')
    check(sets.normalize_player(p)=='svg','existing other player remains isolated')
    p.mod_settings[sets.setting_name]={value=id};settings.startup[sets.default_setting_name].value='original'
    raw['virtual-signal'][sets.signal_name(id,'ecology-flood')]=nil;sets.refresh_runtime()
    check(#sets.available_sets()==#sets.builtin_ids,'incomplete provider family excluded in full')
    resolved,changed=sets.normalize_player(p)
    check(resolved=='original' and changed,'removed or broken provider freezes current valid startup fallback')
    settings.startup[sets.default_setting_name].value=id
    check(sets.player_set(p)=='original','invalid startup does not override valid personal choice')
    p.mod_settings[sets.setting_name]={value=id}
    check(sets.normalize_player(p)=='rendered','invalid personal and startup provider terminate at Rendered')
    raw['string-setting'][sets.setting_name].allowed_values[#raw['string-setting'][sets.setting_name].allowed_values+1]='unknown__'..string.rep('a',210)
    sets.refresh_runtime();check(#sets.available_sets()==#sets.builtin_ids,'malformed external allowed value cannot crash runtime discovery')
    local absent={valid=false}
    resolved,changed=sets.normalize_player(absent);check(resolved=='rendered' and not changed,'invalid player is not mutated')
    settings.player_default=nil;check(not sets.normalize_map_default(),'missing map-default mock surface is harmless')
end

do
    local raw=stage();runtime(raw)
    local messages={};local old_log=log
    log=function(message)messages[#messages+1]=message end
    local z=provider('z-missing');local a=provider('a-missing')
    local zid=sets.register_settings(z);local aid=sets.register_settings(a)
    local choices=raw['string-setting'][sets.setting_name].allowed_values
    choices[#choices+1]='bad/id'
    sets.refresh_runtime()
    check(#messages==3,'each malformed or unregistered family produces one diagnostic')
    check(messages[1]:find("set '"..aid.."'",1,true)~=nil and messages[2]:find("set '"..zid.."'",1,true)~=nil,
        'provider diagnostic order is deterministic and independent of registration order')
    check(messages[1]:find(sets.signal_name(aid,catalog.entries[1].id),1,true)~=nil,
        'missing-family diagnostic names first missing catalogue signal')
    check(messages[3]:find('bad/id',1,true)~=nil,'malformed selector value is identified')
    sets.refresh_runtime();sets.available_sets()
    check(#messages==3,'unchanged refreshes and cached reads do not repeat diagnostics')
    sets.register_data(a);sets.refresh_runtime()
    check(#messages==3,'repairing one family does not repeat other diagnostics')
    raw['virtual-signal'][sets.signal_name(aid,'ecology-flood')]=nil
    sets.refresh_runtime()
    check(#messages==4 and messages[4]:find(sets.signal_name(aid,'ecology-flood'),1,true)~=nil,
        'new failure after repair identifies its first missing signal')
    sets.refresh_runtime();check(#messages==4,'new diagnostic also deduplicates on unchanged refresh')
    raw['virtual-signal'][sets.signal_name(aid,catalog.entries[1].id)]=nil
    sets.refresh_runtime()
    check(#messages==5 and messages[5]:find(sets.signal_name(aid,catalog.entries[1].id),1,true)~=nil,
        'changed missing-signal diagnosis is reported once')
    log=old_log
end

do
    for _,fallback in ipairs(sets.builtin_ids) do
        local raw=stage();local def=provider('fallback');def.fallback=fallback;def.icons={}
        local id=sets.register_settings(def);sets.register_data(def)
        check(raw['virtual-signal'][sets.signal_name(id,'ecology-flood')].icon==raw['virtual-signal'][sets.signal_name(fallback,'ecology-flood')].icon,
            'partial provider supports built-in fallback '..fallback)
        runtime(raw);settings.startup[sets.default_setting_name].value=fallback
        local p={valid=true,mod_settings={}}
        check(sets.normalize_player(p)==fallback and p.mod_settings[sets.setting_name].value==fallback,
            'each built-in can initialize new players: '..fallback)
    end
end

do
    -- Catalogue additions automatically gain every builtin/provider signal, without a second manifest list.
    local raw=stage();local original_count=#catalog.entries
    catalog.add{id='fixture-future',channel='operational',setting_name='ei-alert-fixture-future',default_enabled=false,
        icon_signal='ei-alert-fixture-future',localised_name={'fixture.name'},localised_description={'fixture.description'},order='z'}
    data.raw['virtual-signal']={};data:extend(sets.builtin_prototypes())
    local def=provider('future');local id=sets.register_settings(def);sets.register_data(def)
    local count=0;for _ in pairs(raw['virtual-signal'])do count=count+1 end
    check(count==(original_count+1)*(#sets.builtin_ids+1),'future entry generates all builtins and complete provider family')
    check(raw['virtual-signal'][sets.signal_name(id,'fixture-future')].icon==raw['virtual-signal'][sets.signal_name('rendered','fixture-future')].icon,
        'provider omission of future entry copies configured builtin fallback')
    runtime(raw);check(#sets.available_sets()==#sets.builtin_ids+1,'future catalogue validates complete registered sets')
end
print('PASS '..checks..' alert icon-set assertions; stage/native settings boundaries mocked.')
