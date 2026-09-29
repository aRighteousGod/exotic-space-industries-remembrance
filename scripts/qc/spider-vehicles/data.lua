local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="esir-spider-qc-target"
target.max_health=1000000000
target.resistances={}
target.healing_per_tick=0
data:extend({target})
-- Repeated small impacts exercise flat resistance per hit, before aggregation.
local resistant=table.deepcopy(target)
resistant.name="esir-spider-qc-resistant"
resistant.resistances={{type="physical",decrease=20,percent=30}}
local repeated=table.deepcopy(data.raw.projectile.rocket)
repeated.name="esir-spider-qc-repeated-impact"
repeated.action={type="direct",action_delivery={type="instant",target_effects={type="damage",repeat_count=3,damage={amount=10,type="physical"}}}}
local repeated_ammo=table.deepcopy(data.raw.ammo.rocket)
repeated_ammo.name="esir-spider-qc-repeated-ammo"
repeated_ammo.ammo_type.action.action_delivery.projectile=repeated.name
data:extend({resistant,repeated,repeated_ammo})
-- Native script effects for dispatch stress; neither ID belongs to a shipped handler.
local dispatch=table.deepcopy(data.raw.explosion.explosion)
dispatch.name="esir-spider-qc-dispatch"
dispatch.created_effect={type="direct",action_delivery={type="instant",target_effects={
    {type="script",effect_id="esir-spider-qc-unrelated"},
    {type="script",effect_id="ei-spider-shot:esir-spider-qc-unregistered"},
}}}
data:extend({dispatch})
-- A tiny burner fixture exposes nested fuel/spent-fuel preservation in all grids.
local generator=table.deepcopy(data.raw["generator-equipment"]["fission-reactor-equipment"] or data.raw["generator-equipment"]["fusion-reactor-equipment"])
generator.name="esir-spider-qc-generator"
generator.shape={width=1,height=1,type="full"}
generator.power="1W"
generator.burner={type="burner",fuel_categories={"chemical"},fuel_inventory_size=1,burnt_inventory_size=1,effectivity=1}
local generator_item=table.deepcopy(data.raw.item["solar-panel-equipment"])
generator_item.name=generator.name
generator_item.place_as_equipment_result=generator.name
data:extend({generator,generator_item})
