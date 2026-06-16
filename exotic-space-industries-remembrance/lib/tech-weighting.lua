local tech_weighting = {}

local BUCKET_WEIGHT = {
    heavy = 0.75,
    medium = 0.5,
    light = 0.25,
}

-- This table is intentionally discounts-only. Visible, non-repeatable technologies that do not
-- match any rule stay at full weight by default.
local WEIGHTING_RULES = {
    exclude = {
        hidden = true,
        repeatable = true,
    },
    heavy = {
        exact = {
            "ei-liquid-nitrogen-oil-processing",
            "ei-liquid-oxygen-heavy-oil-cracking",
            "ei-nitric-acid-medium-destilate-cracking",
        },
        chain_roots = {
            "research-speed",
            "worker-robots-speed",
            "worker-robots-storage",
            "inserter-capacity-bonus",
            "braking-force",
            "transport-belt-capacity",
        },
        prefixes = {
            "ei-waveform-harmonics-",
        },
    },
    medium = {
        exact = {},
        chain_roots = {
            "physical-projectile-damage",
            "weapon-shooting-speed",
            "laser-shooting-speed",
            "laser-weapons-damage",
            "stronger-explosives",
            "refined-flammables",
            "electric-weapons-damage",
            "tl-tesla-coil-shooting-speed",
            "tl-tesla-coil-damage-technology",
            "tl-tesla-ammo-upgrade-technology",
        },
        prefixes = {},
    },
    light = {
        exact = {
            "toolbelt",
            "toolbelt-equipment",
            "ei-steampunk-lamp",
            "ei-emerald-target-verdict",
            "ei-emerald-apocalypse-recursion",
        },
        chain_roots = {
            "follower-robot-count",
            "upgrade-shells",
            "ei-emerald-shard-manifold",
            "ei-emerald-reload-litany",
            "ei-emerald-verdict-aperture",
            "ei-emerald-charge-catechism",
            "ei-emerald-inertial-oath",
            "ei-emerald-aegis-covenant",
            "ei-emerald-vector-keel",
            "ei-emerald-collapse-mandate",
        },
        prefixes = {
            "cb-coldjet-ammo-damage-",
            "tl-multi-zap-",
            "tl-slowdown-",
            "tl-single-zap-",
            "tl-flames-",
            "tl-volatility-",
            "ei-storm-lattice-",
            "ei-dielectric-rupture-",
            "ei-bridge-coupling-",
            "ei-reactance-overdrive-",
        },
    },
}

local MATCH_ORDER = { "heavy", "medium", "light" }
local NUMBERED_CHAIN_PATTERN = "^(.*)%-(%d+)$"

local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end

    return false
end

local function starts_with(value, prefix)
    return string.find(value or "", prefix, 1, true) == 1
end

local function matches_any_prefix(name, prefixes)
    for _, prefix in ipairs(prefixes or {}) do
        if starts_with(name, prefix) then
            return true
        end
    end

    return false
end

local function bucket_matches(name, rules, chain_root)
    if contains(rules.exact, name) then
        return true
    end

    if chain_root and contains(rules.chain_roots, chain_root) then
        return true
    end

    if matches_any_prefix(name, rules.prefixes) then
        return true
    end

    return false
end

local function has_repeatable_formula(technology)
    local formula = technology and technology.research_unit_count_formula
    if formula == nil then
        return false
    end

    if type(formula) == "string" then
        return formula ~= ""
    end

    return formula ~= false
end

function tech_weighting.get_chain_root(name)
    -- Pack-wide ladders mostly use the familiar `family-1`, `family-2`, ... naming scheme.
    -- Matching on the shared root lets a single rule catch the whole chain without listing
    -- every level explicitly.
    local root = string.match(name or "", NUMBERED_CHAIN_PATTERN)
    return root
end

function tech_weighting.should_count_technology(technology)
    if not technology then
        return false
    end

    if WEIGHTING_RULES.exclude.hidden and technology.hidden then
        return false
    end

    if WEIGHTING_RULES.exclude.repeatable then
        -- Runtime `max_level` is not stable enough to distinguish true repeatables from
        -- ordinary finite technologies. The authored count formula is the repeatable signal
        -- we intentionally use across this pack.
        if has_repeatable_formula(technology) then
            return false
        end
    end

    return true
end

local function get_matching_buckets(name)
    local matches = {}
    local chain_root = tech_weighting.get_chain_root(name)

    -- Resolve from exact overrides outward to broader family rules. This preserves the
    -- ability to carve out utility or doctrine exceptions without breaking the generic
    -- progression-first chain classifications.
    for _, bucket_name in ipairs(MATCH_ORDER) do
        local rules = WEIGHTING_RULES[bucket_name]

        if bucket_matches(name, rules, chain_root) then
            matches[#matches + 1] = bucket_name
        end
    end

    return matches
end

function tech_weighting.get_technology_bucket(name, technology)
    if technology and not tech_weighting.should_count_technology(technology) then
        return nil
    end

    local matches = get_matching_buckets(name)
    return matches[1]
end

function tech_weighting.get_technology_weight(name, technology)
    local bucket = tech_weighting.get_technology_bucket(name, technology)

    if not bucket then
        return 1.0
    end

    return BUCKET_WEIGHT[bucket] or 1.0
end

function tech_weighting.get_weight_marker_level(name, technology)
    if technology and not tech_weighting.should_count_technology(technology) then
        return nil
    end

    local bucket = tech_weighting.get_technology_bucket(name, technology)
    if bucket == "heavy" then
        return 3
    end

    if bucket == "medium" then
        return 2
    end

    if bucket == "light" then
        return 1
    end

    return nil
end

function tech_weighting.audit_technology_weights(technology_prototypes)
    local summary = {
        excluded_hidden = 0,
        excluded_repeatable = 0,
        heavy = 0,
        medium = 0,
        light = 0,
        full_default = 0,
    }

    -- Run one overlap audit against the loaded prototype set so bucket edits fail fast during
    -- init instead of silently shifting the save's scaling curve.
    for technology_name, technology in pairs(technology_prototypes or {}) do
        if technology.hidden then
            summary.excluded_hidden = summary.excluded_hidden + 1
        elseif has_repeatable_formula(technology) then
            summary.excluded_repeatable = summary.excluded_repeatable + 1
        else
            local matches = get_matching_buckets(technology_name)

            if #matches > 1 then
                error(
                    "Technology weighting overlap for "
                    .. technology_name
                    .. ": "
                    .. table.concat(matches, ", ")
                )
            end

            if #matches == 0 then
                summary.full_default = summary.full_default + 1
            else
                summary[matches[1]] = summary[matches[1]] + 1
            end
        end
    end

    return summary
end

return tech_weighting
