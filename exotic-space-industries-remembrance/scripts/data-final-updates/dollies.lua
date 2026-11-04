-- blueprint: .codex/esir/blueprints/startup-and-integration.md#contract
-- Dolly reads the same blacklist for entities and their ghosts before moving either.
local blacklist = data.raw["mod-data"]["even-pickier-dollies"].data.blacklist_names
local protected = {
    ["ei-gate"] = true, ["ei-gate-container"] = true, ["ei-gate-circuit-interface"] = true,
    ["ei-auric-inoculation-vat"] = true, ["ei-auric-inoculation-vat-circuit-interface"] = true,
    ["ei-combustion-turbine-fluid-open-proxy"] = true, ["ei-fusion-reactor-circuit-interface"] = true,
    ["ei-combustion-turbine-oxygen-generator"] = true,
    ["ei-combustion-turbine-oxygen-generator-ash"] = true,
    ["ei-neutron-collector-circuit-interface"] = true, ["ei-sweeping-radar-output"] = true,
    ["ei-water-turret-power"] = true, ["ei-sweeping-radar-power"] = true, ["ei-phased-array-radar-power"] = true,
    ["ei-orbital-combinator-power-sensor"] = true, ["ei-orbital-selector-power-sensor"] = true,
    ["ei-orbital-coordinator-power-sensor"] = true, ["ei-orbital-dispatch-uplink-power-sensor"] = true,
    ["ei-platform-transponder-power-sensor"] = true,
    ["ei-steam-loader"] = true, ["ei-loader"] = true, ["ei-fast-loader"] = true, ["ei-express-loader"] = true,
    ["ei-turbo-loader"] = true, ["ei-neo-loader"] = true, ["ei-military-loader"] = true,
}
for kind in pairs(defines.prototypes.entity) do
    for name in pairs(data.raw[kind] or {}) do
        if protected[name] or name:match("^ei%-induction%-matrix%-")
            or name:match("^ei%-railgun%-cooling%-proxy") or name:match("^ei%-factory%-passage%-joint%-")
            or name:match("^ei%-sweeping%-radar%-visual%-") or name:match("^ei%-phased%-array%-radar%-visual%-") then
            blacklist[name] = true
        end
    end
end
-- Dolly checks masks against helpers inside the destination footprint, even point-sized ones.
for _, name in ipairs({"ei-fusion-reactor-circuit-interface", "ei-neutron-collector-circuit-interface"}) do
    data.raw["constant-combinator"][name].collision_mask = {layers = {}}
end
