"""Apply bounded, human-reviewed API dispositions without closing unknown rows.

The fixed source ledger hash scopes the completed qualified runtime audit. The
input remains immutable; the reviewed copy and exact key manifest are evidence.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from default_review_rules import review as review_default

LEDGER_HASH = "6ba54343ebf963f37e80644adb269b04dbdf57d2ee9b62a0326688c361f63515"
PORTED = {
    "classes.LuaEntity.attributes.active": "entity script activation owners; spider-vehicles legacy state conversion",
    "classes.LuaEntity.attributes.fluidbox": "auric-inoculation-vat; fluid-safety; flamethrower-fuels; railgun-cooling; admin/world; simulations",
    "classes.LuaEntity.attributes.minable": "runtime entity ownership and spider-vehicles saved placement state",
    "classes.LuaEntity.methods.remove_fluid": "indexed extraction and rollback owners",
    "classes.LuaEntity.methods.set_fluid": "indexed direct fluid owners",
    "classes.LuaFluidBox": "removed container API replaced by direct indexed LuaEntity methods",
    "classes.LuaGameScript.methods.create_profiler": "beacon-overload and singularity-lance use helpers.create_profiler",
}
COMPATIBLE = {
    "classes.LuaConstantCombinatorControlBehavior.methods.get_section": "auric, fusion, gate, induction, neutron, orbital and radar section consumers",
    "classes.LuaConstantCombinatorControlBehavior.methods.remove_section": "same constant-combinator section owners",
    "classes.LuaControl.attributes.opened": "lib/lib.lua object_name validation and dispatcher GUI entity resolution",
    "classes.LuaEntity.methods.get_fluid": "direct fluid consumers retain valid indices",
    "classes.LuaEntity.methods.get_fluid_count": "valid named fluid count queries",
    "classes.LuaEntity.methods.insert_fluid": "valid fluid definition tables",
    "classes.LuaEntityPrototype.attributes.effect_receiver": "beacon eligibility reads uses_beacon_effects; no old ModuleEffects value reader",
    "classes.LuaEntityPrototype.methods.get_inventory_size": "air-scrubber-compat quality-aware numeric inventory sizes",
    "classes.LuaEntityPrototype.methods.get_supply_area_distance": "beacon-overload nil-safe beacon consumers",
    "classes.LuaPlayer.methods.get_alerts": "lib/alerts.lua supplies one AlertFilter table",
    "classes.LuaPlayer.methods.remove_alert": "lib/alerts.lua supplies one AlertFilter table",
    "classes.LuaPrototypeBase.attributes.subgroup": "admin/world.lua subgroup.name remains valid",
    "classes.LuaSpacePlatform.attributes.space_connection": "surface-anchor, crystal-accumulator and orbital consumers only read",
    "classes.LuaSpacePlatform.attributes.space_location": "surface-anchor, crystal-accumulator and orbital consumers only read",
    "classes.LuaSurface.methods.create_entity": "qualified creation option tables reviewed against changed union/optional fields",
    "classes.LuaTilePrototype.attributes.collision_mask": "terrain-evolution same_mask compares layers and treats absent flags as false",
}
CONTAINERS = {"classes.LuaFluidBoxPrototype.methods", "classes.LuaQualityPrototype.methods", "classes.LuaStyle.methods"}
DOC_ONLY = {"application_version", "concepts.SoundPath.lists", "concepts.UndoRedoAction.type.variant_parameter_description",
            "prototypes.CustomInputPrototype.properties.key_sequence.lists", "prototypes.GuiStyle.custom_properties.lists",
            "classes.LuaSimulation.methods.get_widget_position.variant_parameter_description"}

# Narrow native receipts supplement source classification; they do not close
# unrelated owners, rendering, multiplayer or release acceptance for a whole API.
NATIVE_EVIDENCE = {
    "classes.LuaControl.attributes.opened": (
        "Native turbine ownership/close/reopen and induction GUI/configuration pass; fusion final dispatcher/widget/save checks pass at 100/125 percent with rendered relative/fallback consoles; no physical-input claim",
        ["turbine-runtime-21/headless-reload-03.receipt.json", "turbine-runtime-21/client-reload-03.receipt.json", "fusion-gui-21/responsive-100-01.receipt.json", "fusion-gui-21/responsive-125-03.receipt.json", "induction-native-21/configuration-02.receipt.json"]),
    "classes.LuaForce.attributes.unlock_travel_to_space_platforms": (
        "Approved native 2.1 discovery gate: Rocket silo stays locked; three native discovery completions grant travel; exact migration body adopts researched discovery effects; actual 2.0 Rocket-silo-only donor and reload remain locked",
        ["platform-travel-native/native-03.receipt.json", "platform-travel-native/reload-01.receipt.json", "platform-travel-migration/migration-01.checkpoint.json", "platform-travel-migration/reload-01.receipt.json"]),
    "classes.LuaForce.attributes.unlock_logistic_network": (
        "Native engine migration retains the researched logistic-robotics unlock in the populated donor",
        ["migration-beacon-21/script-output/migration-second-reload.json"]),
    "classes.LuaEntity.attributes.active": (
        "Disabled machine and legacy beacon source states preserved through actual migration and repeated reload; five generator bodies retain disabled behavior in paired loaded-network tests",
        ["migration-beacon-21/script-output/migration-second-reload.json", "audit/power-output-parity.json", "power-output-21/native-06.receipt.json"]),
    "classes.LuaEntity.attributes.minable": (
        "Protected rare assembler retains writable mining flag through migration and repeated reload",
        ["migration-beacon-21/script-output/migration-second-reload.json"]),
    "classes.LuaEntity.attributes.fluidbox": (
        "52 fluid-safety assertions, paired heater conservation, 175 auric checks, 51/53 flamethrower checks, railgun migration of 296 helpers/2091 fields, and all 135 native fusion recipes plus populated fusion migration; other fluid owners remain separate",
        ["fluid-native/script-output/fluid-safety-native.json", "audit/heat-parity-final.json", "auric-runtime-21-buffer-parity/script-output/auric-native-reload.json", "audit/auric-cycle-parity.json", "flamethrower-native-21/script-output/flamethrower-qc.json", "flamethrower-native-off-21/script-output/flamethrower-qc.json", "railgun-migration-21/script-output/railgun-qc.json", "audit/fusion-recipes-parity.json", "fusion-migration-21/reload-01.checkpoint.json"]),
    "classes.LuaConstantCombinatorControlBehavior.methods.get_section": (
        "Fusion full/partial circuit commands and collector transitions, induction 98 GUI/configuration assertions and gate native circuit/transport checks pass; fusion owned helpers survive migration/reload",
        ["fusion-actors-21/native-02.receipt.json", "fusion-migration-21/reload-01.checkpoint.json", "induction-native-21/configuration-02.receipt.json", "gate-native-21/native-01.receipt.json"]),
    "classes.LuaPlayer.methods.get_alerts": (
        "Connected native alert fixture passes 170 catalog/preference/delivery assertions and actual save/reload/expiry checks, including personal Off retention",
        ["alerts-native-21/client-01.receipt.json", "alerts-native-21/client-reload-01.receipt.json"]),
    "classes.LuaPlayer.methods.remove_alert": (
        "Connected native alert fixture verifies delivery retirement, cleanup and repeated initialization without duplicate or orphan references",
        ["alerts-native-21/client-01.receipt.json", "alerts-native-21/client-reload-01.receipt.json"]),
    "classes.LuaFluidBox": (
        "Removed container API replaced in tested native fluid-safety, auric and flamethrower owners; no blanket acceptance of every fluid owner",
        ["fluid-native/script-output/fluid-safety-native.json", "auric-runtime-21/script-output/auric-native-reload.json", "flamethrower-native-21/script-output/flamethrower-qc.json"]),
    "types.SharedProbabilityDefinition": (
        "48,000 native crafts with blocked outputs, productivity, quality and repeated reload; all 24 authored return pairs",
        ["crystal-native/script-output/crystal-conservation.json"]),
    "types.FluidIngredientPrototype.properties.fluidbox_multiplier": (
        "Approved native Quality buffers: default input grows from two batches to four, authored multiplier 10 permits eleven batches. 24 native volume/quality cases and reload pass. No-Quality helper fallback retains legacy sizes; locked railgun stays 30/60",
        ["native-buffers-21/native-02.receipt.json", "native-buffers-21/reload-01.receipt.json", "package-core-24/compact/approved-native-buffer-changes.json", "railgun-runtime-21/native-04-fixture.json"]),
    "types.FluidProductPrototype.properties.fluidbox_multiplier": (
        "Approved native Quality output floor grows from two batches to three; larger entity volumes still dominate. 24 native cases and save/reload pass; fallback without Quality retains explicit two-batch floor",
        ["native-buffers-21/native-02.receipt.json", "native-buffers-21/reload-01.receipt.json", "package-core-24/compact/approved-native-buffer-changes.json"]),
    "prototypes.ReactorPrototype.properties.neighbour_connectable": (
        "Paired 16-layout native heat comparison preserves fuel use, bonuses and steady output; fixed startup offsets recorded",
        ["audit/heat-parity-final.json"]),
    "types.FluidEnergySource.properties.minimum_input_temperature": (
        "Twelve paired solar-tower boundary cases at 9/10/11 C over 6000 ticks: same heat and consumption at/above 10 C; below-floor 2.1 fluid can remain stored but is not consumed",
        ["audit/solar-boundary-parity.json", "solar-boundary-20/native-02.receipt.json", "solar-boundary-21/native-02.receipt.json"]),
}


QUALITY_ACCEPTED = {
    "prototypes.ModulePrototype.properties." + name + "_quality_multiplier"
    for name in ("consumption", "pollution", "productivity", "quality", "speed")
} | {
    "prototypes.QualityPrototype.properties.module_" + name + "_multiplier"
    for name in ("consumption", "pollution", "productivity", "quality", "speed")
} | {
    "prototypes.QualityPrototype.properties.cargo_wagon_inventory_size_multiplier",
    "prototypes.QualityPrototype.properties.locomotive_power_multiplier",
    "prototypes.QualityPrototype.properties.rolling_stock_max_speed_multiplier",
    "prototypes.RollingStockPrototype.properties.quality_affects_max_speed",
}
for quality_path in QUALITY_ACCEPTED:
    NATIVE_EVIDENCE[quality_path] = (
        "User-approved native precision and all-tier transport scaling: 22 modules, 110 native machine cases, 15 automatic trains, every locomotive ceiling and every cargo/fluid tier at all five qualities; all 21 precision changes enumerated",
        ["audit/quality-native-accepted.json", "quality-trains-20/accepted-01.receipt.json", "quality-trains-21/accepted-01.receipt.json"])


def match(path, roots):
    return next((r for r in roots if path == r or path.startswith(r + ".")), None)


RUNTIME_COMPATIBLE = set("""
concepts.BlueprintEntity.type.variant_parameter_groups.container.parameters.bar.type
concepts.BlueprintEntity.type.variant_parameter_groups.infinity-container.parameters.bar.type
concepts.BlueprintEntity.type.variant_parameter_groups.logistic-container.parameters.bar.type
concepts.BlueprintEntity.type.variant_parameter_groups.infinity-container.parameters.request_filters.optional
concepts.LogisticContainerBlueprintControlBehavior.type.parameters.circuit_condition_enabled.optional
concepts.ReactorBlueprintControlBehavior.type.parameters.temperature_signal.optional
concepts.PipeConnection.type.parameters.target.type
""".split())
RUNTIME_METADATA = {"concepts.SoundPath.lists", "concepts.UndoRedoAction.type.variant_parameter_description", "concepts.IDType.type.options"}
REMOVED_ENUM = {"concepts.EntityPrototypeFilter.type.parameters.filter.type.options", "concepts.RecipePrototypeFilter.type.parameters.filter.type.options", "concepts.SpoilPriority.type.options"}
PROTOTYPE_PORTED = set("""
prototypes.AmbientSound.properties.planet
prototypes.AsteroidPrototype.properties.mass
prototypes.EntityWithHealthPrototype.properties.loot.type.value
prototypes.GeneratorPrototype.properties.horizontal_animation
prototypes.GeneratorPrototype.properties.vertical_animation
prototypes.ItemPrototype.properties.fuel_category
prototypes.LogisticContainerPrototype.properties.animation
prototypes.RecipePrototype.properties.additional_categories
prototypes.RecipePrototype.properties.always_show_products
prototypes.RecipePrototype.properties.category
prototypes.RecipePrototype.properties.reset_freshness_on_craft
prototypes.RecipePrototype.properties.result_is_always_fresh
prototypes.RecipePrototype.properties.show_amount_in_title
prototypes.VehiclePrototype.properties.braking_power
prototypes.VehiclePrototype.properties.friction
types.FluidBox.properties.maximum_temperature
types.FluidBox.properties.minimum_temperature
types.FluidProductPrototype.properties.probability
types.ItemProductPrototype.properties.probability
types.LootItem
""".split())
PROTOTYPE_COMPATIBLE = set("""
prototypes.CollisionLayerPrototype.instance_limit
prototypes.ContainerPrototype.properties.circuit_connector.type
prototypes.ContainerPrototype.properties.picture.type
prototypes.FluidTurretPrototype.properties.enough_fuel_indicator_picture.type
prototypes.FluidTurretPrototype.properties.not_enough_fuel_indicator_picture.type
prototypes.InfinityContainerPrototype.properties.logistic_mode.type
prototypes.LogisticContainerPrototype.properties.logistic_mode.type
prototypes.ProxyContainerPrototype.properties.circuit_connector.type
prototypes.ProxyContainerPrototype.properties.picture.type
prototypes.RailPrototype.properties.pictures.optional
prototypes.RailRemnantsPrototype.properties.pictures.optional
prototypes.RollingStockPrototype.properties.max_speed.optional
prototypes.TilePrototype.properties.collision_mask.type
prototypes.UtilityConstants.properties.bonus_gui_ordering.type
prototypes.UtilitySprites.properties.starmap_star.optional
types.BonusGuiOrdering
types.CargoBayConnectableGraphicsSet.properties.picture.type
types.FluidProductPrototype.properties.show_details_in_recipe_tooltip
types.HeatBuffer.properties.connections.type.value
types.HeatConnection
types.HeatEnergySource.properties.connections.type.value
types.ItemProductPrototype.properties.show_details_in_recipe_tooltip
types.StateSteeringSettings.properties.radius.optional
types.StateSteeringSettings.properties.separation_factor.optional
types.StateSteeringSettings.properties.separation_force.optional
""".split())
PROTOTYPE_METADATA = {"prototypes.CustomInputPrototype.properties.key_sequence.lists", "prototypes.GuiStyle.custom_properties.lists",
    "types.ChartUtilityConstants.properties.custom_tag_max_scale.default", "types.ChartUtilityConstants.properties.custom_tag_scale.default",
    "types.CircularParticleCreationSpecification.properties.center.default", "types.SteeringSettings.inline"}
CONNECTORS = {"types.CircuitConnectorLayer", "types.CircuitConnectorSecondaryDrawOrder",
    "types.MiningDrillGraphicsSet.properties.circuit_connector_layer", "types.MiningDrillGraphicsSet.properties.circuit_connector_secondary_draw_order"}
for connector_path in CONNECTORS | {"types.CircuitConnectorSprites.properties.render_layer", "types.CircuitConnectorSprites.properties.secondary_draw_order"}:
    NATIVE_EVIDENCE[connector_path] = (
        "Four-direction authored connector data assertions and 16 native working dry/wet rigs; inspected captures show attached wires/connector layers on both custom drills",
        ["presentation-native-21/native-01.receipt.json", "presentation-native-21/rendered-01.receipt.json"])
for rocket_field in ("arms_speed_modifier_per_quality_level", "rocket_engine_starting_speed_modifier_per_quality_level", "rocket_rising_speed_modifier_per_quality_level", "lift_weight"):
    NATIVE_EVIDENCE["prototypes.RocketSiloPrototype.properties." + rocket_field] = (
        "Approved native quality modifiers 0.2/0.45/0.15 and lift weight 1000000. Physical delivery, 45 pollution/plume cases, all-five-quality rendered phases and real 2.0 in-flight migration pass; configured emissions remain unchanged",
        ["rocket-delivery-21/native-02.receipt.json", "rocket-quality-21/rendered-01.receipt.json", "rocket-quality-21/reload-during-01.receipt.json", "rocket-migration-21/migration-ascent-01.checkpoint.json", "rocket-migration-21/second-load-01.receipt.json"])
DEFAULTS = {"types.FluidIngredientPrototype.properties.fluidbox_multiplier.default.value",
    "types.MainSound.properties.fade_in_ticks.default.value", "types.MainSound.properties.fade_out_ticks.default.value"}


def structural_cohort(row):
    return row["change"] != "added" and not row["path"].startswith(("classes.", "defines.", "events.")) and row["path"] != "application_version"


def classify_structure(row):
    path = row["path"]
    if row["stage"] == "runtime":
        if path in RUNTIME_COMPATIBLE:
            return "compatible-qualified-use-reviewed", "Native blueprint tables are passed through; PipeConnection.target is compared as entity identity, not old target.owner"
        if path in RUNTIME_METADATA:
            return "documentation-representation", "Equivalent metadata/ID representation"
        if path.endswith(".options") and path not in REMOVED_ENUM:
            return "additive-enum-reviewed", "Canonical alternatives retain the complete old set"
    else:
        if path in PROTOTYPE_PORTED:
            return "ported-source-reviewed", "Qualified shipping owner converted; see subsystem synopsis and source manifest for runtime/graphics validation gates"
        if path in PROTOTYPE_COMPATIBLE:
            return "compatible-qualified-use-reviewed", "Parent-type and native shape review: tooltip flags inherited; heat connections retain direction/position; sprite fallback and existing connector vectors remain supported"
        if path in PROTOTYPE_METADATA:
            return "documentation-representation", "Unchanged described defaults or presentation metadata"
        if path in CONNECTORS:
            return "ported-connector-native-rendered", "Both custom drills retain authored four-direction connector vectors, object layer and draw orders 14/48; 16 working dry/wet native rigs and their exact rendered captures pass in presentation-native-21/rendered-01"
        if path in DEFAULTS:
            if "MainSound" in path:
                return "ported-default-parity", "working-sound-defaults.lua explicitly retains 0/0 fades on ESIR identities; audit/sound-defaults-23 compares 26,253 shared working sounds with zero ESIR differences; audible listening remains separate"
            return "approved-native-quality-buffers", "User approved native default multiplier 3 (four input batches) with Quality; shared fallback preserves old capacities only without Quality. 24 native cases and reload pass; locked railgun stays 30/60"
        if path == "types.FluidEnergySource.properties.maximum_temperature.default":
            return "compatible-default-reviewed", "Old omitted zero sentinel and new omitted value both mean unlimited; no authored FluidEnergySource zero sentinel remains"
        if path.endswith(".options"):
            return "additive-enum-reviewed", "Recursive canonical union comparison retains old alternatives, including nested TriggerEffect array union"
    return "unused-qualified-use-reviewed", "Completed qualified audit of the pinned 205-row non-class cohort against live Lua and preserved 1.3.41 ZIP; not an automatic token-search fallback"


FLUID_METHODS = set("add_fluid clear_fluid clear_fluid_segment_fluid clear_fluids extract_fluid get_fluid_box_neighbours get_fluid_box_pipe_connections get_fluid_box_prototype get_fluid_capacity get_fluid_filter get_fluid_segment_filter get_fluid_segment_fluid get_fluid_segment_id has_fluid_segment".split())
REPLACEMENT_TYPES = {"types." + name for name in ("ProductPrototypeBase", "SharedProbabilityDefinition", "GeneratorPictureSet",
    "GeneratorPictures", "RobotDoorSpecification", "HeatConnectionDefinition", "BonusUtilityConstants", "LogisticMode",
    "LayeredSprite4Way", "Sprite8Way", "TileCollisionMaskConnector")}
IMPLICIT_DEFAULTS = set("""
prototypes.CraftingMachinePrototype.properties.use_mirroring
prototypes.ModulePrototype.properties.consumption_quality_multiplier
prototypes.ModulePrototype.properties.pollution_quality_multiplier
prototypes.ModulePrototype.properties.productivity_quality_multiplier
prototypes.ModulePrototype.properties.quality_quality_multiplier
prototypes.ModulePrototype.properties.speed_quality_multiplier
prototypes.ReactorPrototype.properties.temperature_to_suppress_energy_icons
prototypes.RecipePrototype.properties.can_set_quality
types.ProductionHealthEffect.properties.damage_type
types.RadiusVisualisationSpecification.properties.distance_quality_multiplier
types.SignalIDConnector.properties.quality
""".split())
CONDITIONAL_UNUSED = {"types.CargoBayConnections.properties.tileset_mapping", "types.WaterTileEffectParameters.properties.image_textures", "types.WaterTileEffectParameters.properties.noise_textures"}
REPLACEMENTS = {"prototypes.AmbientSound.properties.planets", "prototypes.GeneratorPrototype.properties.pictures",
    "prototypes.LogisticContainerPrototype.properties.robot_door", "prototypes.ReactorPrototype.properties.neighbour_connectable"}


def classify_added(row):
    path, value = row["path"], row["after"]
    parts = path.split(".")
    if parts[0] == "defines":
        return "additive-defines-reviewed", "Adds define constants; removed constants have a separate qualified-use audit"
    if row["stage"] == "runtime":
        if parts[0] == "events":
            return ("additive-event-reviewed" if len(parts) == 2 else "additive-event-data-reviewed"), "Existing dispatcher receives compatible events; new fields do not require a new receiver"
        if parts[0] == "classes":
            if len(parts) == 2:
                return "additive-class-reviewed", "New/shared native class surface; replacement uses linked to ported API roots"
            if len(parts) == 4 and parts[2] == "attributes":
                return "additive-attribute-reviewed", "Native attribute projection; new force unlock flags require donor assertions, and direct fluid/storage fields require focused runtime evidence"
            if len(parts) == 4 and parts[2] == "methods":
                if parts[1] == "LuaEntity" and parts[3] in FLUID_METHODS:
                    return "ported-fluid-method-reviewed", "Direct-fluid owners use this method; native transaction/capacity acceptance remains separate"
                return "additive-method-reviewed", "New method surface; no new required argument on an old call"
            if parts[2] == "methods" and ".parameters." in path and isinstance(value, dict) and value.get("optional") is False:
                if path == "classes.LuaEntity.methods.remove_fluid.parameters.index":
                    return "ported-required-parameter-reviewed", "Explicit fluid index selected by ported owner"
                if path.startswith(("classes.LuaPlayer.methods.get_alerts.", "classes.LuaPlayer.methods.remove_alert.")):
                    return "compatible-required-parameter-reviewed", "Existing calls already pass one AlertFilter table"
                assert path.startswith(("classes.LuaPlayer.methods.get_quick_bar_slot.", "classes.LuaPlayer.methods.set_quick_bar_slot.")), path
                return "unused-required-parameter-reviewed", "No ESIR quick-bar slot method caller"
            if path == "classes.LuaBootstrap.attributes.feature_flags.read_type.parameters.expansion":
                return "native-feature-projection-reviewed", "Native feature flag result; ESIR does not reconstruct it"
            if path.endswith(".write_type"):
                return "expanded-writeability-reviewed", "Previously readable property gains write access; existing callers remain valid"
            if path.endswith(".variant_parameter_description"):
                return "documentation-representation", "Descriptive metadata only"
            if path == "classes.LuaSurface.methods.create_cargo_pod.format.table_optional":
                return "relaxed-call-format-reviewed", "Existing call format remains accepted"
            return "optional-call-extension-reviewed", "Recursive inspection found no new required nested parameter in these optional arguments/variants"
        if len(parts) == 2:
            return "additive-concept-reviewed", "New/shared runtime concept definition; existing typed result handling reviewed separately"
        if isinstance(value, dict) and value.get("optional") is False:
            return "native-required-record-reviewed", "Native result projection, allowlisted enemy-expansion settings, read-only GameViewSettings or unused decider parameters; no wholesale authored record replacement"
        if path in {"concepts.MouseButtonFlags.type.value.full_format", "concepts.MouseButtonFlags.type.value.options"}:
            return "unused-gui-filter-shape-reviewed", "No authored mouse_button_filter or GUI MouseButtonFlags consumer"
        return "optional-record-extension-reviewed", "Optional record fields/variants; no new mandatory member of an ESIR-authored old record"
    if len(parts) == 2:
        if path in REPLACEMENT_TYPES:
            return "replacement-type-reviewed", "Shared/replacement type linked to the corresponding removed/changed schema; native validation belongs to its owner"
        return "native-new-definition-reviewed", "Native/new type; no authored existing-shape conversion; native presentation and progression still have semantic gates"
    if path in {"types.ItemProductPrototype.parent", "types.FluidProductPrototype.parent"}:
        return "product-inheritance-reviewed", "ProductPrototypeBase supplies independent probability 1, shared full interval and tooltip true; validate crystal and unrelated-product behavior"
    if len(parts) == 5 and path.endswith(".default"):
        return "documented-existing-default-reviewed", "50 GUI style defaults plus unused custom-stack maximum are newly documented, not evidence of an engine behavior change"
    assert len(parts) == 4 and parts[2] == "properties" and isinstance(value, dict), path
    if path == "types.FluidProductPrototype.properties.fluidbox_multiplier":
        return "approved-native-buffer-sizing-reviewed", "User approved native three-batch output floor with Quality; fallback without Quality retains two. Native capacity/reload and exact final-data field-difference receipts linked"
    if value.get("optional") is False:
        if parts[1] == "VehiclePrototype":
            return "ported-required-property-reviewed", "braking_force and friction_force supplied by the vehicle port"
        if parts[1] == "MineEntityTechnologyTrigger":
            return "unused-required-property-reviewed", "ESIR research triggers use craft-item; no authored mine-entity trigger"
        return "native-required-property-reviewed", "Native utility, enemy-expansion or feature schema retained; ESIR edits only selected existing fields"
    if "default" in value:
        return "explicit-default-control-reviewed", "Requires semantic-family disposition; omission is not proof of unchanged native behavior"
    if path in IMPLICIT_DEFAULTS:
        return "implicit-default-control-reviewed", "Default is defined in official prose; link mirroring, quality, recipe, damage, radius, signal or reactor acceptance"
    if path == "prototypes.ItemPrototype.properties.fuel_categories":
        return "ported-conditional-property-reviewed", "Nonzero fuel_value requires a nonempty array; source and final fuel membership port"
    if path in CONDITIONAL_UNUSED:
        return "unused-conditional-schema-reviewed", "Qualified audit found no ESIR cargo tileset or water shader texture authoring"
    if path.endswith((".maximum_input_temperature", ".minimum_input_temperature", ".maximum_fuel_temperature", ".minimum_fuel_temperature", ".maximum_oxidizer_temperature", ".minimum_oxidizer_temperature")):
        return "fluid-admission-policy-reviewed", "Fluid admission is distinct from energy conversion temperature; native boundary/capacity checks remain required"
    if path in REPLACEMENTS:
        return "ported-replacement-structure-reviewed", "Music planets, generator pictures, robot doors or reactor topology port implemented; presentation/runtime evidence separate"
    return "optional-property-extension-reviewed", "No new mandatory input in the old authored shape; copied native prototype behavior still belongs to its semantic owner"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    raw = args.input.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == LEDGER_HASH, "Review cohort changed; re-audit before applying dispositions"
    ledger = json.loads(raw)
    added_rows = [{k: r[k] for k in ("stage", "path", "change", "before", "after") if k in r}
                  for r in ledger["entries"] if r["change"] == "added"]
    added_rows.sort(key=lambda r: (r["stage"], r["path"]))
    assert len(added_rows) == 1330
    assert hashlib.sha256(json.dumps(added_rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest() == "95080a5a7856f44d0bc26cd15dc7bfee79f2acc238145f930a757eb3da9ddda4"
    added_reviews = []
    structural_rows = [{k: r[k] for k in ("stage", "path", "change", "before", "after") if k in r}
                       for r in ledger["entries"] if structural_cohort(r)]
    structural_rows.sort(key=lambda r: (r["stage"], r["path"]))
    structural_bytes = json.dumps(structural_rows, sort_keys=True, separators=(",", ":")).encode()
    assert hashlib.sha256(structural_bytes).hexdigest() == "6c23285bb4cadf1f678e33d359c3c597688351da18c64977730a00aa2fde375c"
    structural_reviews = []
    cohort = []
    for row in ledger["entries"]:
        path, disposition, reason = row["path"], None, None
        if row["change"] == "added":
            disposition, reason = classify_added(row)
            added_reviews.append({"stage": row["stage"], "path": path, "disposition": disposition})
        elif row["stage"] == "runtime" and path.startswith("classes."):
            root = match(path, PORTED)
            compatible = match(path, COMPATIBLE)
            if root:
                disposition, reason = "ported-source-reviewed", PORTED[root]
            elif compatible:
                disposition, reason = "compatible-qualified-use-reviewed", COMPATIBLE[compatible]
            elif path in CONTAINERS:
                disposition, reason = "additive-api-surface", "Empty method list becomes a map because methods were added"
            else:
                disposition, reason = "unused-qualified-use-reviewed", "Completed qualified caller audit of the fixed 179-row runtime class cohort; lexical matches belong to other classes, records, comments or prototypes"
            cohort.append({"stage": row["stage"], "path": path, "disposition": disposition})
        elif structural_cohort(row):
            disposition, reason = classify_structure(row)
            structural_reviews.append({"stage": row["stage"], "path": path, "disposition": disposition})
        elif row["change"] == "removed" and path.startswith("defines."):
            disposition, reason = "unused-define-reviewed", "All 20 removed define names checked as qualified expressions and literals across shipping Lua; other-stage duplicate references the same audit"
        elif path == "events.on_player_respawned.data.player_port":
            disposition, reason = "unused-event-field-reviewed", "No shipping receiver reads the removed player_port field"
        elif path in DOC_ONLY:
            disposition, reason = "documentation-representation", "Version or descriptive/schema metadata; no callable contract change"
        elif row["stage"] == "runtime" and row["change"] == "added":
            root = match(path, ("classes.LuaPlayer.methods.get_alerts.parameters.filter", "classes.LuaPlayer.methods.remove_alert.parameters.filter"))
            if root:
                disposition, reason = "compatible-qualified-use-reviewed", "Existing single-table AlertFilter calls match the renamed parameter"
            elif path == "classes.LuaEntity.methods.remove_fluid.parameters.index":
                disposition, reason = "ported-source-reviewed", "Fluid owners now choose explicit entity fluid indices"
        if path in QUALITY_ACCEPTED:
            disposition = "approved-native-quality-verified"
            reason = "Explicit user approval retains native 2.1 precision and locomotive/wagon scaling; paired normal-value preservation and exact changed values verified in quality-native-accepted.json"
        elif disposition in ("explicit-default-control-reviewed", "implicit-default-control-reviewed"):
            disposition, reason = review_default(path)
        if disposition:
            row["disposition"] = disposition
            row["evidence"] = [{"review": "qualified-use-2.0.77-to-2.1.23", "reason": reason,
                                "validation": "source-review; native acceptance tracked separately"}]
        native_root = match(path, NATIVE_EVIDENCE)
        if native_root:
            reason, receipts = NATIVE_EVIDENCE[native_root]
            for receipt in receipts:
                target = args.input.parent.parent / receipt
                assert target.is_file(), target
                row.setdefault("evidence", []).append({"validation": "focused-native-engine",
                    "reason": reason, "receipt": receipt,
                    "receipt_sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    counts = Counter(x["disposition"] for x in cohort)
    assert counts == {"ported-source-reviewed": 16, "compatible-qualified-use-reviewed": 36,
                      "additive-api-surface": 3, "unused-qualified-use-reviewed": 124}, counts
    assert len(structural_reviews) == 205
    structural_counts = Counter((r["stage"], r["disposition"]) for r in structural_reviews)
    expected = {("runtime", "compatible-qualified-use-reviewed"): 7, ("runtime", "additive-enum-reviewed"): 14,
        ("runtime", "documentation-representation"): 3, ("runtime", "unused-qualified-use-reviewed"): 34,
        ("prototype", "ported-source-reviewed"): 20, ("prototype", "compatible-qualified-use-reviewed"): 25,
        ("prototype", "additive-enum-reviewed"): 12, ("prototype", "documentation-representation"): 6,
        ("prototype", "ported-connector-native-rendered"): 4, ("prototype", "compatible-default-reviewed"): 1,
        ("prototype", "ported-default-parity"): 2, ("prototype", "approved-native-quality-buffers"): 1,
        ("prototype", "unused-qualified-use-reviewed"): 76}
    assert structural_counts == expected, structural_counts
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {p.as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(Path("exotic-space-industries-remembrance").rglob("*.lua"))}
    (args.output / "source-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    (args.output / "reviewed-runtime-keys.json").write_text(json.dumps(cohort, indent=2), encoding="utf-8")
    (args.output / "reviewed-structural-keys.json").write_text(json.dumps(structural_reviews, indent=2), encoding="utf-8")
    (args.output / "reviewed-added-keys.json").write_text(json.dumps(added_reviews, indent=2), encoding="utf-8")
    (args.output / "api-differences.json").write_text(json.dumps(ledger, indent=2), encoding="utf-8")
    totals = dict(Counter(r["disposition"] for r in ledger["entries"]))
    (args.output / "receipt.json").write_text(json.dumps({"input_sha256": LEDGER_HASH, "counts": totals,
        "structural_classification_complete": "pending-review" not in totals,
        "release_acceptance": False, "source_files": len(manifest)}, indent=2), encoding="utf-8")
    print(json.dumps(totals))


if __name__ == "__main__":
    main()
