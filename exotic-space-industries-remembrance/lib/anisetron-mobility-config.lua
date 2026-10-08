-- blueprint: .codex/esir/blueprints/anisetron.md#contract
-- Shared native anti-stall sticker definitions; never read visual fidelity.
local config = {
    vehicle = "ei-anisetron",
    prefix = "ei-anisetron-hover-compensation-",
    -- .20 still allowed multi-second native reversal stalls. .50 passed the
    -- long manual/autopilot, armed and stacked-slow regression in 2.0.77.
    minimum_modifier = .50,
    multiplier_step = 1.25,
    -- Covers the installed fifteen-type stack with spare compensation tiers.
    tiers = 64,
    service_interval = 4,
    safety_lifetime = 12,
}
config.factors, config.names = {}, {}
for tier = 1, config.tiers do
    config.factors[tier] = config.multiplier_step ^ tier
    config.names[tier] = config.prefix .. tier
end
return config
