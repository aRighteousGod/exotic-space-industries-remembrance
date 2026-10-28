-- Appended only to a private staged main control.lua, after its lexical owners.
remote.add_interface("esir-qc-migration-private", {
    seed = function(surface)
        storage.gaia_surfaces = storage.gaia_surfaces or {}
        storage.gaia_surfaces[surface.name] = true
        local root = storage.ei.terrain_evolution
        assert(root and root.surfaces[1], "Donor ecology root missing")
        root.compatibility = {external_mod=true, name="TerrainEvolution"}
        root.surfaces[1].overrides = {enabled=true, wildfire="off", flood=false, drought=false, cliffs=false}
    end,
    snapshot = function()
        local root = storage.ei.terrain_evolution
        return {gaia_owned=storage.gaia_surfaces and storage.gaia_surfaces["esir-migration-gaia"],
            compatibility=root and root.compatibility,
            overrides=root and root.surfaces[1] and root.surfaces[1].overrides,
            ecology_enabled=root and root.surfaces[1] and root.surfaces[1].config.enabled}
    end
})
