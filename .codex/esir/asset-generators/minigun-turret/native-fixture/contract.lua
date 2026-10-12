-- Fixture-owned constants shared by prototype construction and runtime probes.
return {
    instrumentation = {
        shell_particles_disabled = true,
        shell_particle_scope = "disposable candidate and legacy clones only",
        ammo_source_observer_added = true,
        damage_delivery_unchanged = true,
        production_and_firing_fixture_shells_unchanged = true,
    },
    states = {"folded", "preparing", "prepared", "starting-attack", "attacking",
        "ending-attack", "rotate-for-folding", "folding"},
    sequences = {
        parked = {1}, running = {2},
        preparing = {1,3,4,5,6,7,8,9,10,11,12,2},
        folding = {2,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,1},
    },
    -- Base, upper, rotor alpha; final flag reverses the two state-owned leaves.
    shadows = {
        {"empty",0,0,0,false}, {"b64",64,0,0,false}, {"b128",128,0,0,false},
        {"b192",192,0,0,false}, {"u64",0,64,0,false}, {"u128",0,128,0,false},
        {"u192",0,192,0,false}, {"b64-u192",64,192,0,false},
        {"b128-u128",128,128,0,false}, {"triple",64,128,192,false},
        {"triple-reversed",64,128,192,true}, {"u64-r192",0,64,192,false},
        {"u64-r192-reversed",0,64,192,true}, {"control64",64,0,0,false},
        {"control128",128,0,0,false}, {"control192",192,0,0,false},
        {"control208",208,0,0,false}, {"control232",232,0,0,false},
        {"control255",255,0,0,false},
    },
    finish_tick = 1550,
}
