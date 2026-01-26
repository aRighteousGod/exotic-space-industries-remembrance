--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["DiscoScience"] then
    return
end

if DiscoScience and DiscoScience.prepareLab then
    DiscoScience.prepareLab(data.raw["lab"]["ei-dark-age-lab"])
end