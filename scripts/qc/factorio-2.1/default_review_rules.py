"""Bounded semantic dispositions for the fixed 143 added default controls.

These are source/schema dispositions, not blanket engine acceptance. Each row
retains its exact official default, affected final-data identities and source
hits in default-controls.json. Focused native evidence is attached separately.
"""

# Owner rules apply only to the fixed added-default cohort, never arbitrary
# future properties. Field-specific exceptions precede these groups.
OWNERS = {
    'AgriculturalTowerPrototype': ('retained-opt-in-module-default', 'No effects and no quality slot bonus are enabled. The core agricultural tower has no authored ESIR module policy; allowing categories alone grants no effect.'),
    'AmbientSound': ('ported-soundtrack-scope-default', 'play_on_all_surfaces remains false; authored tracks use the migrated planets binding. This is binding/source acceptance, not audible playback.'),
    'AsteroidPrototype': ('approved-asteroid-damage-policy', 'All 40 core asteroids have explicit damage_per_hp; canonical size values follow the approved 0/3/5/12/50 policy and operational variants retain their authored multiplier.'),
    'CarPrototype': ('retained-native-car-extension', 'Unspecified impact immunity remains false and driving volume remains one. Explicit inherited immunity belongs to native/required-dependency bodies; ESIR car/tank/hover handling is checked separately.'),
    'CargoBayPrototype': ('retained-native-cargo-bay-extension', 'ESIR does not author these new unloading/direction controls. The native unloading bay opts in; ordinary cargo bays retain false defaults. No ESIR dispatch or cargo-pod ownership API changes here.'),
    'CombatRobotPrototype': ('retained-native-robot-separation', 'ESIR supplies no separation overrides. The three native combat robots carry explicit native separation values; the remaining bodies keep zero defaults. No ESIR pursuit scheduler or ammunition value is changed.'),
    'ContainerPrototype': ('retained-single-direction-container', 'All 72 final core container records omit direction_count and retain one direction. Directional robot doors were ported separately; no new directional inventory identity is created.'),
    'CraftingMachinePrototype': ('retained-native-machine-presentation', 'Mirroring defaults to the presence of vector_to_place_result; random animation starts remain opt-in. Eight inherited native machines explicitly opt in. ESIR category/effect/recipe economics are separate audited fields.'),
    'DisplayPanelPrototype': ('retained-native-display-limits', 'Only the native display-panel prototype is present. ESIR does not author panel records or raise the native 100-record/500-character limits.'),
    'FluidPrototype': ('retained-native-fluid-glow', 'Glow is opt-in. Three inherited final fluids explicitly enable it; no ESIR fluid temperature, fuel value or amount is changed by this rendering field.'),
    'FluidWagonPrototype': ('retained-native-wagon-valves', 'Retain the native valve positions and tank spacing for inherited wagons and documented defaults for standalone bodies. Capacity is independently accepted at all qualities; native pump animation/contact geometry is a separate presentation boundary.'),
    'GeneratorPrototype': ('ported-generator-direction-policy', 'All four final generators explicitly retain two_direction_only=true; the new default cannot add rotations. Generator graphics and loaded output have separate native receipts.'),
    'InserterPrototype': ('retained-native-inserter-mirroring', 'Use native mirroring; no ESIR override exists. Native railgun insertion checks exercise 288 inserters in eight orientations; this is not a claim about every blueprint GUI path.'),
    'ItemWithInventoryPrototype': ('retained-fixed-item-inventory', 'The one core item-with-inventory does not opt into quality inventory scaling. Its existing fixed size remains the governing authored value.'),
    'MiningDrillPrototype': ('retained-native-drill-placement', 'Retain native resource-required placement and mirrored geometry. Native/derived drills explicitly carry their migration/mirroring flags; custom advanced/superior bodies pass all four directions on dry and wet resources.'),
    'NightVisionEquipmentPrototype': ('retained-night-vision-behavior', 'No sunglasses override is authored; false retains the ordinary night-vision role. No equipment identity, power or visual strength is edited.'),
    'ProxyContainerPrototype': ('retained-single-direction-proxy', 'Both final proxy containers retain one direction. Inventory forwarding and native owned helper state are separate runtime responsibilities.'),
    'PumpPrototype': ('retained-native-pump-valve-range', 'Both final pumps explicitly inherit 2.22 for the fluid-wagon valve range, so the newly documented 2.2 fallback is unused. Fluid admission/capacity remains separate.'),
    'ReactorPrototype': ('retained-native-reactor-icons', 'ESIR does not override the new energy-icon suppression threshold. Native fusion records explicitly use 800; other reactors retain the unbounded default. Heat output/topology and fusion controls have their own evidence.'),
    'RobotWithLogisticInterfacePrototype': ('retained-robot-mining-policy', 'No robot opts into require_charge_to_mine. Empty batteries therefore introduce no new mining prerequisite; robot quality and energy costs are ported independently.'),
    'RocketSiloPrototype': ('approved-native-rocket-quality-effects', 'The user approved native 2.1 silo quality speedups: arm/engine-start/rising modifiers 0.2/0.45/0.15 and lift weight 1000000. Physical delivery, 45 pollution/plume cases (374714 checks), 24 inspected rendered phases, in-flight reload and actual 2.0 migration pass. Emissions retain the configured total; plume starts 239 ticks after native clamp release.'),
    'SelectionToolPrototype': ('retained-selection-event-policy', 'All 14 core selection tools omit send_pre_selection_events. Existing dispatcher hooks remain event-driven and do not subscribe to an extra pre-selection stream.'),
    'SimpleEntityPrototype': ('retained-native-decorative-variation', 'Random shuffling remains opt-in; 11 inherited native scenery definitions enable it. ESIR does not add this flag. Terrain/resource/nest migration evidence is separate from decorative visual sequence parity.'),
    'SpaceConnectionPrototype': ('retained-starmap-origin-and-shape', 'All ten core connections retain origin zero and native arc shape. Endpoint identities, lengths, spawn curves and physical travel are separate preserved values.'),
    'SpaceLocationPrototype': ('retained-starmap-origin', 'All ten locations retain origin zero. Planetary surface properties, legacy map generation and soundtrack bindings are separate owner ports.'),
    'TurretPrototype': ('retained-native-turret-failure-policy', 'No ESIR override of leave_attacking_if_shoot_fails is authored. Preserve the native failure transition and inherited explicit false where supplied; ESIR acquisition, cooldown and scripted combat still use their existing owners.'),
    'AmmoType': ('retained-unclamped-ammo-default', 'No force_clamp_to_max_range override is authored; false preserves the existing projectile/range rules. Ballistic payload and acquisition fields remain owned by combat doctrines.'),
    'AnimationParameters': ('retained-animation-frame-fidelity', 'allow_reducing_frames remains false, so the renderer may not discard authored frames through this new opt-in. Native scene/working-light captures are separate evidence.'),
    'AreaTriggerItem': ('retained-area-trigger-origin-policy', 'require_origin_is_valid remains false; existing delayed payloads are not newly cancelled when their origin expires. No ESIR trigger gains an extra source-validity gate.'),
    'BaseAttackParameters': ('retained-asteroid-target-priority', 'No threatening_asteroid_penalty override is authored; zero adds no new penalty to ESIR targeting. The approved asteroid impact damage policy is unrelated.'),
    'CircuitConnectorSprites': ('ported-connector-render-default', 'The unified authored drill connectors explicitly supply object layer and draw orders 14/48. Native connectors retain their declared values or object/10 fallback; 16 working drill captures verify the changed custom owners.'),
    'CreateEntityTriggerEffectItem': ('retained-native-creation-trigger-default', 'preserve_ghosts_and_corpses remains false and details remain visible in tooltips. No new ghost/corpse custody promise or hidden effect is introduced by ESIR.'),
    'EffectReceiver': ('retained-native-effect-limits', 'No ESIR replacement of the new limit records or uses_local_effects default exists. The 110 native module/machine cases preserve every penalty, with the 18 explicitly approved productivity precision changes. Extreme externally modified limits require their own compatibility acceptance.'),
    'GameViewSettings': ('retained-native-view-default', 'ESIR does not set hide_tall_entities or show_pins_gui. Native visibility/pin preferences remain engine-owned; no migration writes replace player view settings.'),
    'PipeConnectionDefinition': ('retained-native-alternate-port-default', 'No ESIR alt_direction, alt_position or hide_connection_info override exists. Alternate geometry inherits the authored primary direction/position; the fluid transaction and capacity ports do not rewrite connections.'),
    'ProductionHealthEffect': ('unused-production-health-schema', 'Qualified source search finds no ESIR production_health_effect authoring. Unrelated damage_type matches are combat records; this new nested default does not create production damage.'),
    'ProjectileTriggerDelivery': ('retained-projectile-speed-default', 'inherit_speed remains false; ESIR payload definitions do not opt into adding source velocity. Scripted ballistic scatter and projectile speed values remain unchanged.'),
    'RadiusVisualisationSpecification': ('retained-owner-radius-default', 'No explicit distance_quality_multiplier is authored. Native radius visualization derives its multiplier from the owning prototype; beacon/radar/robot gameplay ranges retain their respective owner policies.'),
    'SelectionModeData': ('retained-selection-exclusion-default', 'Both ignore_cannot_select flags remain false. Existing selection tools continue to honor native cannot-select entity/tile exclusions.'),
    'SignalIDConnector': ('retained-normal-signal-default', 'An omitted signal quality resolves to normal; explicit authored qualities remain attached. Native induction, fusion, gate and orbital section tests exercise the ported circuit owners.'),
    'SpriteNWaySheet': ('retained-single-frame-repeat', 'frame_repeat defaults to one and no ESIR override exists. Authored sprite dimensions/directions remain intact; generated and native scenes were inspected separately.'),
    'SpriteSource': ('retained-rgba-sprite-default', 'color_channels remains four with no ESIR override. The port retains authored color/alpha channels; no sprite is converted to a different channel format.'),
    'ThrusterGraphicsSet': ('retained-native-thruster-animation', 'Native random start frames remain enabled for thruster graphics; ESIR does not override this presentation-only phase. Fuel, oxidizer and thrust values are independent fields.'),
}

FIELDS = {
    'circuit_wire_max_distance': ('retained-native-circuit-extension', 'Retain explicit native wire distances where inherited; zero fallback adds no connector to a standalone body. ESIR runtime proxy/circuit ownership remains separate.'),
    'draw_circuit_wires': ('retained-native-wire-rendering', 'True permits normal wire drawing when a connector exists. It does not create a connector, circuit network or ESIR telemetry output.'),
    'draw_copper_wires': ('retained-native-wire-rendering', 'True permits normal copper-wire drawing where supported. It does not add electrical supply connections or alter power consumption.'),
    'tall': ('retained-native-height-visibility', 'Elevated rail/ramp subtypes keep their native tall default; ordinary entities keep false unless explicitly declared. Collision masks and train elevation topology are unchanged by this visibility field.'),
    'show_fluid_visualization_when_in_cursor': ('retained-native-fluid-cursor-ui', 'Keep native cursor-fluid visualization for pipes/pumps/tanks and false on ordinary entities. This only changes the native placement overlay, not fluid connectivity or storage.'),
    'hide_from_stats': ('retained-energy-statistics-default', 'Energy sources remain visible by default; explicit authored hiding remains intact. Native loaded-power/consumption checks do not imply a screenshot audit of every statistics panel.'),
    'auto_refuel': ('retained-native-burner-refuelling', 'True retains ordinary burner refuelling; ESIR does not disable it. Loaded generator, vehicle/train and preserved burner-state fixtures exercise admitted fuels and queued/in-flight custody.'),
}

ITEM_FIELDS = {
    'lab_ignores_spoil_percent': 'False retains spoil-sensitive item science. ESIR science remains tools; native item/tool/mixed lab consumption is verified separately.',
    'quality_affects_spoil_ticks': 'True retains native spoil lifetime scaling. Paired lifetime queries cover all 18 shared spoiling items at every quality with zero differences.',
    'science_capacity': 'One is the normal-capacity fallback for native science items. Tool durability remains its own field; ESIR discovery/lab code accepts both item and tool science.',
    'space_platform_request_priority': 'Default false retains ordinary request priority; two native bootstrap items explicitly opt in. ESIR does not add priorities to its own items.',
    'spoil_quality_change': 'Zero requests no quality transformation on spoilage. ESIR does not author a new spoil-quality conversion; existing result identities and lifetimes are preserved.',
}

RECIPE_FIELDS = {
    'can_set_quality': 'Native selection is enabled for recipes with eligible item ingredients; no ESIR quality_min/max/change constraints are added. Fluid-only recipes keep native normal-quality selection. Authored allow_quality remains independent.',
    'categories': 'Array routing preserves all shared recipe/machine memberships; omitted category remains crafting. Final-data eligibility and native crafting are separately checked.',
    'raise_on_crafted': 'False adds no per-craft event stream. ESIR retains existing crafting/research event receivers and event-first scheduling.',
    'requires_ingredients_to_unlock_results': 'The default follows hidden; no ESIR override is added. This controls prototype discovery, not technology prerequisites or native recipe.enabled state.',
    'sort_item_ingredients': 'True retains native ingredient presentation sorting; it does not reorder or change consumed amounts, quality eligibility or product metadata.',
}

PRODUCT_FIELDS = {
    'quality_change': 'Zero preserves ingredient/result quality without an extra transformation; the port retains explicit product metadata and permits native quality rolls only where already eligible.',
    'spoil_weight': 'One keeps ordinary ingredient contribution to product spoilage. ESIR does not author custom weighting; dedicated freshness overrides remain explicit.',
    'affected_by_quality': 'True retains native product quality eligibility; explicit recipe-level allow_quality and productivity exclusions are preserved. Crystal products have separate native conservation acceptance.',
    'always_fresh': 'False retains inherited freshness unless explicitly enabled. Migrated authored freshness flags live on the matching products, not a removed recipe-wide field.',
    'reset_freshness_on_craft': 'False retains normal craft freshness; both authored pentapod-egg outputs explicitly preserve their old reset behavior on the product field.',
}

QUALITY_FIELDS = {
    'chain_probability': 'Native first-step probability and later-chain probability are now separate. The native playable ladder retains ten-percent continuation; ESIR converts quality module effects by 0.1 so initial odds retain their old scale.',
    'previous_probability': 'Zero disables quality downgrade rolls; ESIR does not introduce a downgrade path.',
    'previous_chain_probability': 'Derived from zero previous_probability, so no downgrade chain is introduced.',
    'science_capacity_multiplier': 'Inherits tool_durability_multiplier, retaining the shared quality relationship between old tool science and new item science. Lab type discovery is ported separately.',
    'spoil_ticks_multiplier': 'Inherits default_multiplier; paired native spoil-lifetime checks retain every shared item lifetime at every quality.',
}


def review(path):
    _,owner,_,field=path.split('.')
    if field in FIELDS:return FIELDS[field]
    if owner=='ItemPrototype':return 'retained-item-default-policy',ITEM_FIELDS[field]
    if owner=='RecipePrototype':return 'ported-recipe-default-policy',RECIPE_FIELDS[field]
    if owner in ('ItemProductPrototype','ItemIngredientPrototype'):return 'ported-product-default-policy',PRODUCT_FIELDS[field]
    if owner=='QualityPrototype':return 'ported-quality-default-policy',QUALITY_FIELDS[field]
    return OWNERS[owner]
