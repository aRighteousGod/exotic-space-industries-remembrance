--====================================================================================================
--REMOVE GAIA TILES/ENTITIES FORM NAUVIS
--====================================================================================================

--ENTITIES NOT ON NAUVIS
------------------------------------------------------------------------------------------------------

local remove_entities = {
    "ei-core-patch",
    "ei-cryoflux-patch",
    "ei-phytogas-patch",
    "ei-morphium-patch",
    "ei-ammonia-patch",
    "ei-coal-gas-patch",
    "ei-gaia-tree-01",
    "ei-gaia-tree-02",
    "ei-gaia-tree-05",
    --"ei-gaia-tree-09"
}

local remove_entity_settings = {}
for i,v in ipairs(remove_entities) do
    remove_entity_settings[v] = {frequency = 0, size = 0, richness = 0}
end

--TILES NOT ON NAUVIS
------------------------------------------------------------------------------------------------------

local remove_tiles = {}

for i,v in pairs(data.raw["tile"]) do
    -- if tile starts with "ei-" add to remove_tiles
    if string.sub(i, 1, 3) == "ei-" then
        table.insert(remove_tiles, i)
    end
end

local remove_tiles_settings = {}
for i,v in ipairs(remove_tiles) do
    remove_tiles_settings[v] = {frequency = 0, size = 0, richness = 0}
end

local new_autoplace_settings = {
    ["tile"] = {
        ["treat_missing_as_default"] = true,
        ["settings"] = remove_tiles_settings
    },
    ["entity"] = {
        ["treat_missing_as_default"] = true,
        ["settings"] = remove_entity_settings
    },
    ["decorative"] = {
        ["treat_missing_as_default"] = true,
        ["settings"] = {}
    }
}

--APPLY CHANGES
------------------------------------------------------------------------------------------------------

for i,v in pairs(data.raw["map-gen-presets"].default) do

    if not (type(data.raw["map-gen-presets"].default[i]) == "table") then
        goto continue
    end

    -- skip default settings
    if i == "default" then
        goto continue
    end

    if not v.basic_settings then
        data.raw["map-gen-presets"].default[i].basic_settings = {}
    end

    data.raw["map-gen-presets"].default[i].basic_settings.autoplace_settings = new_autoplace_settings

    log("Removed gaia tiles from map-gen-presets: ".. i)
    
    ::continue::

end

-- add a new EI-default setting
data.raw["map-gen-presets"].default["ei-default"] = {
    order = "a",
    basic_settings = {
        autoplace_settings = new_autoplace_settings
    }
}

