--==============================================================================
-- ESIR FILE MAP
-- owns: historical working-sound fade defaults on ESIR identities and generated bodies
-- loaded_by: data-final-fixes.lua after generated entity families
-- cadence: final data pass only
-- storage_roots: none
--==============================================================================
-- blueprint: .codex/esir/blueprints/entity-presentation.md#contract
-- blueprint-ref: .codex/esir/blueprints/entity-presentation.md#working-sound-defaults
-- Factorio 2.1 defaults omitted MainSound fades to 8/20 ticks instead of 0/0.
-- Keep authored overrides and progress-matched sounds; copy before mutation so
-- shared vanilla/dependency sound tables retain their own engine semantics.
local patched = {}
local function preserve_main(sound)
    if sound.match_progress_to_activity then return end
    if sound.fade_in_ticks == nil then sound.fade_in_ticks = 0 end
    if sound.fade_out_ticks == nil then sound.fade_out_ticks = 0 end
end

for _, prototypes in pairs(data.raw) do
    for name, prototype in pairs(prototypes) do
        local sound = prototype.working_sound
        if name:sub(1, 3) == "ei-" and type(sound) == "table" then
            local copy = patched[sound]
            if not copy then
                -- WorkingSound also accepts a bare Sound definition or array.
                copy = (sound.filename or sound.variations or sound[1]) and {sound=table.deepcopy(sound)} or table.deepcopy(sound)
                if copy.main_sounds then
                    if copy.main_sounds[1] then
                        for _, main in ipairs(copy.main_sounds) do preserve_main(main) end
                    else
                        preserve_main(copy.main_sounds)
                    end
                else
                    preserve_main(copy)
                end
                patched[sound] = copy
            end
            prototype.working_sound = copy
        end
    end
end
