-- Echo Codex Generator: A ritual system of dynamic proclamation
ei_lib = require("lib/lib")
echo_codex = {}

--====================================================================================================
--Cue Updater Centralization
--====================================================================================================

-- Predefined esoteric message pools
local echo_templates = {
	beam_lines = {
		"✴ [Beam Invocation] — Threads converge on the monolinear spine. Velocity dictates truth.",
		"☄ [Linear Surge] — The rails echo with singular momentum. Beam queue ascends.",
		"🛤 [Singularity Path] — The beam speaks in straight lines. Disobedience will not be tolerated.",
		"📡 [Directional Focus] — Phase-locked transit beam calibrated. Alignment perfect.",
		"🔦 [Light Vector] — Beam queue energized. All points surrender to the axis.",
		"📍 [Fixed Origin] — The rail vector stabilizes. All motion aligns with primal direction.",
		"💠 [Crystalline Directive] — Beam protocol engaged. Chaos bends to structure.",
		"🌀 [Focus Collapse] — Collapsing trajectories into beam singularity. Efficiency absolute.",
		"🚄 [Quantum Monorail] — Beam queue activated. Track hums with inevitability.",
		"📈 [Logos Manifest] — Directionality reified through queue. Linear ascension begins.",
	},
	ring_lines = {
		"⭕ [Ring Protocol] — Infinite recursion activated. Cycles feed themselves.",
		"🔁 [Loop Cascade] — All things return. The queue is Ouroboros.",
		"♻ [Cyclical Binding] — Entrapment via elegance. Circular motion commences.",
		"🧿 [Mystic Recurrence] — The Ring echoes. Resonance achieves coherence.",
		"🔄 [Gyroscopic Inertia] — Rotational queue selected. Expect parallax distortions.",
		"💫 [Eternal Return] — The wheel turns again. Queue geometry loops.",
		"⭮ [Sacred Cycle] — Chosen path: endless revolution. Harmony through repetition.",
		"🏵 [Floral Gear] — Queue shaped by symmetry. Ring dances on iron petals.",
		"♒ [Aeonic Ring] — Motion follows itself, queue winds inwards to myth.",
		"🧬 [Fractal Recurse] — Queue set to ring. Expect nested intervals of time.",
	},
	null_lines = {
		"☠ [Queue Collapse] — Unknown signature. Nullifying all expectations.",
		"🕳 [Black Path] — Queue unspecified. Falling into entropic recursion.",
		"🚫 [Signal Lost] — Queue form undefined. Reverting to zero-sum logic.",
		"🛑 [Execution Abort] — Queue invalid. System defaulting to inert.",
		"🔮 [Ambiguity Field] — The queue has no shape. Interpretive void.",
		"❓ [Indeterminate State] — Queue type not cast. Expect noise.",
		"📵 [Disconnection Rite] — Queue path severed. No pattern found.",
		"⚠ [Semantic Failure] — Queue type non-resolvable. Static overload.",
		"🧟 [Dead Configuration] — Queue is unchosen. Process stagnates.",
		"🚷 [No-Queue Protocol] — Silence selected. Motion suspended.",
	},
	train_glow_on = {
		"🌟 [Ignition Confirmed] — Synthetic soul-fire initialized. Eyes open to the rail gods.",
		"🧨 [Radiance Surge] — Locomotive path imbued with arc light. Contact imminent.",
		"📡 [Beacon Pulse] — Kinetic waveform has entered the spectrum. Trace initiated.",
		"🔆 [Ghostlight Lattice] — Shadows recoil. Trains burn with internal signal.",
		"🚂 [Specter Rail Engaged] — The engines hum in tongues not spoken since the Second Binding.",
		"🕯 [Phantom Heat] — Ether-iron breathes again. The rails remember who died here.",
		"🛤 [Dead Loop Detected] — The train repeats a path no longer real. Ghost cargo en route.",
		"🔮 [Signal Aberration] — Luminance nodes report presence… but not mass. Something rides unseen.",
		"💀 [Rite of Motion] — Engine heat rises in defiance of entropy. The conductor is no longer alive.",
		"⚙ [Clatter Beyond] — Sound without source. The tracks scream softly beneath awakened wheels.",
	},
	train_glow_off = {
		"🌑 [Extinction] — The machine sighs into obscurity. Glow disabled.",
		"🔕 [Silence Protocol] — No more trails. Movement becomes rumor.",
		"🪦 [Entropy Veil] — Trains cloaked in stillness. Absence is the new motion.",
		"📴 [Null Radiance] — The path darkens. Luminescence denied.",
		"😐 [Glow Abandoned] — It was nice while it lasted. Back to grey steel and unmet potential.",
		"🔻 [Aesthetic Rejected] — Shine removed per protocol 44-B. No one was impressed anyway.",
		"🫥 [Vibe Lost] — The moment passed. You blinked. That was it.",
		"🙃 [Dampened Spirit] — Hope dissipated with the light. The train moves, but nobody cares.",
		"📉 [Inspiration Offline] — Glow deemed inefficient. Passion flagged as a UPS cost.",
		"🎭 [Exit Unlit] — No final shimmer. Just motion. Just silence. Just... nothing.",
	},
	que_width = {
		"📐 [Metric Invocation] — Queue vector set to {val} units. Tangent of destiny recalculated.",
		"🌌 [Path Divergence] — Field expanded to {val} units. Prepare for multi-rail entanglement.",
		"🧭 [Directional Bloom] — Breadth: {val} threads. Harmony between chaos and constraint.",
		"📏 [Axis Defined] — {val} filaments strung across the coil.",
		"🪞 [Splintered Focus] — Update stream fractured into {val} rays. Each reflects a slightly different truth.",
		"🧠 [Thread Horizon] — Neural lattice expanded to {val} queues. Overlap is inevitable.",
		"🎼 [Chord Set] — {val} harmonics queued. The machine sings in parallel now.",
		"🔀 [Pathway Spread] — {val} routes designated. Efficiency traded for entropy.",
		"📚 [Page Forked] — The script now branches {val} ways. One of them ends in smoke.",
		"🧵 [Weft Established] — {val} strands woven into update tapestry. Loom hums with intent.",
	},
	transparency = {
		"🩻 [Xeno-Lens Calibration] — Queue phase visibility adjusted to {val}%. Shadows discerned.",
		"🔬 [Opacity Shift] — Optical veil set to {val}%. Begin phantasmal oscillation.",
		"🫧 [Mist Infusion] — Transparency at {val}%. Reality remains negotiable.",
		"🌫 [Threshold Vision] — Field clarity altered. {val}% of forms shall pass.",
		"🧿 [Cloak Drift] — {val}% exposure achieved. Apparitions now partially negotiable.",
		"🩺 [Signal Attenuation] — Diagnostic overlay dialed to {val}%. Ghost trains may persist.",
		"📡 [Phase Bleed] — Visibility threshold at {val}%. Cross-stream echoes anticipated.",
		"🌁 [Diffusion Limit] — Field transparency recalibrated. {val}% revealed, the rest forgotten.",
		"🪞 [Mirage Layer] — System reflecting at {val}%. Truth displaced into visual residue.",
		"🧬 [Refractive Instability] — At {val}%, photons begin to lie. Proceed with second sight.",
	},
	train_glow_timetolive = {
		"🚂 [Afterburn Trail] — Engine echo persists for {val} ticks. Smoke remembers.",
		"💡 [Residual Glow] — Aura decay set to {val} ticks. Shadows cling to motion.",
		"🕯 [Phantom Wick] — Light expires in {val} flickers. Haunting complete.",
		"📉 [Luminal Decline] — Radiant echo down to {val} ticks. Fade with grace.",
		"🔦 [Signal Residue] — Visibility held for {val} moments. Then, oblivion.",
		"⚙️ [Kinetic Memory] — Trail remains for {val} moments. Wheels whisper what was.",
		"🔋 [Phase Discharge] — Stored brilliance dissipating. {val} ticks left to burn.",
		"🌠 [Startrack Flicker] — Ion trail visible for {val} cycles. Wishes not included.",
		"🔥 [Residual Heat] — Thermal trace endures for {val} ticks. Sootmarks of velocity.",
		"🎚 [Glow Half-Life] — Emission drops after {val} half-lives. Watch the silence spread.",
	},
	charger_glow_off = {
		"🔻 [Conduit Severed] — Charger glow dismissed. Field integrity dissolving.",
		"🛑 [Arc Termination] — Glow downshifted. Residual pulse muted.",
		"🕳 [Void Reclaim] — Light returns to source. No charge remains.",
		"🔌 [Disconnection Complete] — Energetic tether cut. Local phase dimmed.",
		"🧯 [Glow Extinguished] — Charge cycle concluded. Embers no longer stir.",
		"🌑 [Null Bloom] — Radiance collapsed. Chamber sealed in quiet.",
		"📴 [Cycle End] — No signal. No shimmer. No surge.",
		"🧼 [Clean Burnout] — Residual field cleansed. Power shell vacated.",
		"⛓ [Current Break] — Arc conduit silenced. Ether locked down.",
		"🫥 [Lumen Dissolve] — Charger light faded. As if it never bled.",
	},
	charger_glow_on = {
		"⚡ [Field Ignition] — Glow initialized. Current now dances in the shell.",
		"🔺 [Charge Conduction] — Arc begins. The lattice sings.",
		"🪫→🔋 [Energetic Uplink] — Charge channel opened. Glow rising from source.",
		"🧠 [Neuroarc Alignment] — Aura node pulsing. Memory conduction engaged.",
		"🕯 [Spark Risen] — Light returned to the altar. System breathes again.",
		"🌟 [Lumen Surge] — Charger flare online. Phase structure amplifying.",
		"🔆 [Activation Ritual] — Glow threshold passed. Power boughs bloom.",
		"📶 [Resonance Online] — Field lock acquired. Glow propagating.",
		"🧲 [Conductive Bloom] — Core lit. Surrounding medium now magnetized.",
		"🧨 [Ignition Vector] — Charge glow ignited. Containment veil stabilizing.",
	},
	charger_glow_timetolive = {
		"🕰 [Flicker Threshold] — Remaining glow integrity: {val} ticks. Embers brace for collapse.",
		"🌒 [Dimming Arc] — Charger aura dwindles. {val} ticks moments until stillness.",
		"🫥 [Residual Pulse] — Field bleed persists. {val} ticks ticks before disconnection.",
		"💤 [Afterglow Sync] — {val} ticks units until quiescence. Final surge in motion.",
		"📉 [Luminal Decay] — Countdown at {val} ticks. Photonic presence destabilizing.",
		"🎚 [Phase Tapering] — Glow energy depleting. {val} ticks remains of the surge.",
		"⏳ [Aura Expiry] — Dissolution locked in. Charger life: {val} ticks.",
		"📴 [End Signal] — Terminal glow timer at {val} ticks. System prepares for withdrawal.",
		"🧂 [Glow Residue] — {val} ticks of shine left clinging to the conduit.",
		"📎 [Binding Unravel] — Glow timer: {val} ticks. Tether loosens from the core.",
	},
	que_timetolive = {
		"⏳ [Delay Vector] — Queued train persists for {val}s. Temporal inertia holding.",
		"📡 [Phantom Ping] — {val} ticks remain in queue resonance. Still no lock.",
		"🔄 [Loop Sustain] — Holding pattern at {val} ticks. Awaiting logistic convergence.",
		"🧭 [Temporal Drift] — Queue TTL: {val} ticks. Momentum not yet granted.",
		"🔒 [Pending Invocation] — {val} ticks remain before signal lapse. Hold stable.",
		"📆 [Transit Echo] — Manifest reservation expires in {val} ticks.",
		"🛤 [Track Hold] — Queued path viable for {val} ticks more. Commitment awaits.",
		"💤 [Sleep State] — Request decays in {val} ticks. No movement detected.",
		"🔁 [Awaiting Pulse] — {val} ticks left in queue register. Continue monitoring.",
		"🧮 [Latency Script] — Timer shows {val} ticks. Queue presence maintained.",
	},
	rocket_launch_pollution_mode = {
		"🚀 [Launch Wrath Geometry] — Pollution curve selected: {val}. The sky will remember.",
		"🜂 [Rocket Edict] — Scaling mode: {val}. Consequence tuned to trajectory.",
		"⚙ [Combustion Doctrine] — Rocket pollution logic set to {val}. No more free ascension.",
		"📈 [Progression Blade] — Mode locked: {val}. Difficulty now follows a deliberate curve.",
		"🧿 [Signal Contract] — Launch pollution runs on {val}. The planet has terms.",
		"🔥 [Exhaust Litany] — {val} chosen. Smoke now speaks in mathematics.",
		"🛰 [Orbit Tax] — Mode = {val}. Every launch pays the atmosphere.",
		"🧨 [Wrath Compiler] — Pollution model: {val}. The engine writes in soot.",
		"🜁 [Sky Ledger] — Curve: {val}. The air becomes a balance sheet.",
		"🧬 [Escalation Shape] — {val}. Threat blooms in the shape you asked for.",
	},
	rocket_launch_pollution_cap = {
		"🧱 [Ceiling of Soot] — Rocket pollution cap set to {val}. The wrath has a roof.",
		"🔒 [Containment Limit] — Max launch pollution: {val}. Even fury is bounded.",
		"📏 [Upper Bound] — Cap configured at {val}. The atmosphere negotiates.",
		"⚖ [Limiter Sigil] — Pollution cannot exceed {val}. Constraint applied.",
		"🪓 [Hard Stop] — Cap: {val}. Beyond this, the ritual refuses to escalate.",
		"🛑 [Safety Valve] — Launch pollution capped at {val}. A rare mercy.",
		"🧮 [Maximum Clause] — {val}. The ledger closes there, no matter the urge.",
		"🫥 [Fury Throttled] — Cap locked to {val}. The sky exhales… reluctantly.",
		"🛰 [Orbital Toll Gate] — Cap = {val}. The toll collector is consistent.",
		"🌫 [Smog Horizon] — {val}. Past it, the smoke is denied.",
	},
	fulgora_day_length_variation_max_multiplier = {
		"[Zenith Edict] — The heavens of Fulgora may now be stretched to {val}-fold.",
		"[Crown of Stormlight] — The upper bound of the sun-road is sealed at {val}.",
		"[Celestial Apex] — The longest ordained turning now rises to {val}.",
	},
	fulgora_day_length_variation_min_multiplier = {
		"[Nadir Decree] — The shortest turning of Fulgora is bound to {val}.",
		"[Root of Dawn] — The lower seal of the day-cycle now rests at {val}.",
		"[Under-Cycle Oath] — The minimum ordained span is set to {val}.",
	},
}

-- Function to emit a random echo from a category with optional data injection
function echo_codex.proclaim(category, data)
	local pool = echo_templates[category]
	if not pool then
		ei_lib.crystal_echo("❓ [Echo Unknown] — No prophecy prepared for category: " .. tostring(category))
		return
	end

	local message = pool[math.random(1, #pool)] --should only ever be from an event so we good

	data = data or {}

	-- Placeholder replacement
	message = ei_lib.format_echo(message, data)

	-- Emit the upgraded crystal_echo with full options
	ei_lib.crystal_echo(
		message,
		data.font or nil,
		data.player or nil,
		data.tint or nil,
		data.force_full_tint or false,
		data.intent or nil,
		data.as_floating_text or false,
		data.floating_timetolive or nil
	)
end

function echo_codex.handle_global_settings(event)
	if not event then
		local event = {}
		event.tick = -1
	end
	--=== [Read core config values] ===--
	local width = ei_lib.config("em_updater_que_width") or 6
	local transparency = ei_lib.config("em_updater_que_transparency") or 80
	local que_timetolive = ei_lib.config("em_updater_que_timetolive") or 60
	local que_type = ei_lib.config("em_updater_que") or "none"
	local train_glow = ei_lib.config("em_train_glow")
	local trainGlowTimeToLive = ei_lib.config("em_train_glow_timetolive") or 60
	local charger_glow = ei_lib.config("em_charger_glow")
	local chargerGlowTimeToLive = ei_lib.config("em_charger_glow_timetolive") or 60

	local rocket_launch_pollution_mode = ei_lib.config("rocket-launch-pollution-mode") or "linear"
	local rocket_launch_pollution_cap = ei_lib.config("ei-rocket-launch-pollution-cap") or 10000
	local fulgora_day_length_variation_max_multiplier = ei_lib.config("fulgora-day-length-variation-max-multiplier") or 2
	local fulgora_day_length_variation_min_multiplier = ei_lib.config("fulgora-day-length-variation-min-multiplier") or 0.1
	local nauvis_pressure_grace = ei_lib.config("nauvis-pressure-grace") or true

	local previous_tint = nil
	-- Helper to get new tint and adj
	local function next_tint(event)
		local tint
		if event then
			tint = ei_lib.get_random_different_value(
				ei_lib.tint_palette,
				previous_tint,
				math.random(1, 6553600),
				event.tick
			)
			previous_tint = tint
		else
			tint = ei_lib.get_random_different_value(ei_lib.tint_palette, previous_tint)
			previous_tint = tint
		end
		return tint, ei_lib.tint_palette[tint]
	end

	--=== [Width Announcement] ===--
	local tint, tint_adj = next_tint(event)
	echo_codex.proclaim("que_width", {
		val = width,
		tint = tint,
		tint_adj = tint_adj,
		font = "default-bold",
	})
	storage.ei.que_width = width

	--=== [Transparency Announcement] ===--
	tint, tint_adj = next_tint(event)
	echo_codex.proclaim("transparency", {
		val = transparency,
		tint = tint,
		tint_adj = tint_adj,
		font = "default-bold",
	})
	storage.ei.que_transparency = transparency / 100

	--=== [Queue Time-To-Live] ===--
	tint, tint_adj = next_tint(event)
	echo_codex.proclaim("que_timetolive", {
		val = que_timetolive,
		tint = tint,
		tint_adj = tint_adj,
		font = "default-bold",
	})
	storage.ei.que_timetolive = que_timetolive

	--=== [Train Glow Toggle] ===--
	tint, tint_adj = next_tint(event)
	if train_glow then
		echo_codex.proclaim("train_glow_on", {
			tint = tint,
			tint_adj = tint_adj,
			intent = "signal",
			font = "default-bold",
		})
	else
		echo_codex.proclaim("train_glow_off", {
			tint = tint,
			tint_adj = tint_adj,
			font = "default-bold",
		})
	end
	storage.ei.em_train_glow = train_glow

	--=== [Train Glow TTL] ===--
	tint, tint_adj = next_tint(event)
	echo_codex.proclaim("train_glow_timetolive", {
		val = trainGlowTimeToLive,
		tint = tint,
		tint_adj = tint_adj,
		font = "default-bold",
	})
	-- Stored after, like before
	storage.ei.em_train_glow_timeToLive = trainGlowTimeToLive

	--=== [Charger Glow Toggle] ===--
	tint, tint_adj = next_tint(event)
	if charger_glow then
		echo_codex.proclaim("charger_glow_on", {
			tint = tint,
			tint_adj = tint_adj,
			intent = "serenity",
			font = "default-bold",
		})
	else
		echo_codex.proclaim("charger_glow_off", {
			tint = tint,
			tint_adj = tint_adj,
			font = "default-bold",
		})
	end
	storage.ei.em_charger_glow = charger_glow

	--=== [Charger Glow TTL] ===--
	tint, tint_adj = next_tint(event)
	echo_codex.proclaim("charger_glow_timetolive", {
		val = chargerGlowTimeToLive,
		tint = tint,
		tint_adj = tint_adj,
		font = "default-bold",
	})
	storage.ei.em_charger_glow_timeToLive = chargerGlowTimeToLive

	--=== [Queue Type Handling] ===--
	tint, tint_adj = next_tint(event)
	if que_type == "Beam" then
		echo_codex.proclaim("beam_lines", {
			tint = tint,
			tint_adj = tint_adj,
			font = "default-bold",
		})
		storage.ei.em_train_que = 1
	elseif que_type == "Ring" then
		echo_codex.proclaim("ring_lines", {
			tint = tint,
			tint_adj = tint_adj,
			font = "default-bold",
		})
		storage.ei.em_train_que = 2
	else
		echo_codex.proclaim("null_lines", {
			tint = tint,
			tint_adj = tint_adj,
			font = "default-bold",
		})
		storage.ei.em_train_que = 0
	end
	--=== [Rocket Launch Pollution Config] ===--

	-- Announce scaling mode
	tint, tint_adj = next_tint(event)
	echo_codex.proclaim("rocket_launch_pollution_mode", {
		val = rocket_launch_pollution_mode,
		tint = tint,
		tint_adj = tint_adj,
		font = "default-bold",
		intent = "wrath",
	})

	-- announce cap
	tint, tint_adj = next_tint(event)
	echo_codex.proclaim("rocket_launch_pollution_cap", {
		val = rocket_launch_pollution_cap,
		tint = tint,
		tint_adj = tint_adj,
		font = "default-bold",
		intent = "wrath",
	})

	storage.ei.rocket_launch_pollution.mode = rocket_launch_pollution_mode
	storage.ei.rocket_launch_pollution.cap = rocket_launch_pollution_cap

	-- Announce fulgora day-length variation bounds
	tint, tint_adj = next_tint(event)
	echo_codex.proclaim("fulgora_day_length_variation_max_multiplier", {
		val = fulgora_day_length_variation_max_multiplier,
		tint = tint,
		tint_adj = tint_adj,
		font = "default-bold",
	})

	tint, tint_adj = next_tint(event)
	echo_codex.proclaim("fulgora_day_length_variation_min_multiplier", {
		val = fulgora_day_length_variation_min_multiplier,
		tint = tint,
		tint_adj = tint_adj,
		font = "default-bold",
	})


	storage.ei.fulgora_day_length_variation.max_multiplier = fulgora_day_length_variation_max_multiplier
	storage.ei.fulgora_day_length_variation.min_multiplier = fulgora_day_length_variation_min_multiplier
	--add text later
	storage.ei.nauvis_pressure.enabled = nauvis_pressure_grace
end

function echo_codex.youHaveArrived(event)
	if not event or not event.tick or not event.player_index then --SP load? Maybe call this from updater, save warped-in players to a global list, reset it on load so updater calls it again? get access to event.tick that way
		return
	end
	local player = game.get_player(event.player_index)
	if not (player and player.valid and player.character) then
		log("youHaveArrived: invalid player")
		return
	end
	local setTick = event.tick
	local surface = player.surface
	local pos = player.position
	local force = player.force or "player"

	-- Store wave data in global to be updated

	local wave_id = ei_lib.getn(storage.ei.arrival_waves) + 1
	local wave_duration = 60
	local wave_beams = {}

	for t = 0, 2 do -- expanding waves
		local tick_offset = t * 10
		for i = 1, 16 do --circle
			local angle = (math.pi * 2 / 16) * i + t * 0.2
			local radius = 2 + t * 1.5
			local offset = {
				x = pos.x + math.cos(angle) * radius,
				y = pos.y + math.sin(angle) * radius,
			}

			table.insert(wave_beams, {
				source = offset,
				target = pos,
				duration = math.max(10, wave_duration - tick_offset),
				force = force,
				surface = surface,
				tick = setTick + tick_offset,
			})
		end
	end

	storage.ei.arrival_waves[wave_id] = wave_beams

	-- Central FX: explosion, smoke, light
	for i = 1, 5 do
		--    local bang = pos.x + ei_rng.float("lightning" .. i) * 2 - 1
		--    local boom = pos.y + ei_rng.float("lightning" .. i) * 2 - 1
		local bang = pos.x + math.random() * 2 - 1
		local boom = pos.y + math.random() * 2 - 1
		local sentPos = { x = bang, y = boom }
		if math.random() > 0.3 then
			ei_lib.strike_lightning(surface, sentPos)
		end
		bang = pos.x + math.random() * 2 - 1
		boom = pos.y + math.random() * 2 - 1
	end
	surface.create_entity({
		name = "big-artillery-explosion",
		position = {
			x = pos.x,
			y = pos.y,
		},
		force = force,
	})
	surface.create_trivial_smoke({ name = "electric-smoke", position = pos })

	rendering.draw_light({
		sprite = "utility/light_medium",
		target = pos,
		surface = surface,
		color = { r = 0.8, g = 0.1, b = 1.0 },
		intensity = 2.0,
		scale = 5.0,
		time_to_live = 300,
	})
	log(">> EI Arrival event triggered for player: " .. player.name)
	-- Echoed warnings
	ei_lib.crystal_echo("Fragments of GAIA's lament ripple across space-time...", "default-semibold", player)
	ei_lib.crystal_echo("⟬ THE SYSTEM STIRS ⟭", "default-bold")
	ei_lib.crystal_echo_floating("⚠️ YOU HAVE BEEN SEEN ⚠️", player.character, 600, "wrath")
	if not script.active_mods["recipe-icons-improvement-for-esir"] and ei_lib.config("check-for-recipe-icons-improvement-mod") then
		ei_lib.crystal_echo(
			"⚠ [Lack identified] — Recipe Icons Improvement for Exotic Space Industries Remembrance by NaK1119 not detected; Some icons may be difficult to interpret and recipe circuit signals may not function as desired.  This alert can be disabled in mod settings."
		)
	end
end

function echo_codex.arrival_waves(e)
	if not storage.ei.arrival_waves or not e or not e.tick then
		return
	end
	for id, wave in pairs(storage.ei.arrival_waves) do
		for i = #wave, 1, -1 do
			local beam = wave[i]
			if e.tick >= beam.tick then
				local pX = beam.source.x - beam.target.x
				local pY = beam.source.y - beam.target.y
				beam.surface.create_entity({
					name = "electric-beam",
					source = beam.source,
					position = { x = pX, y = pY },
					target = beam.target,
					duration = beam.duration,
					force = beam.force,
				})
				table.remove(wave, i)
			end
		end
		if #wave == 0 then
			storage.ei.arrival_waves[id] = nil
		end
	end
end

--[[
function echo_codex.sigil_cleanup()
  if not storage.ei.lamp_removals then return end

  local now = game.tick
  local spacing = ei_ticksPerFullUpdate / ei_update_functions_length
  local cleanup_tick = ei_lib.get_cleanup_tick(now)

  -- Clean any ticks <= now to avoid missed deletions
  for tick, lamps in pairs(storage.ei.lamp_removals) do
    if tick <= now then
      for _, lamp in pairs(lamps) do
        if lamp and lamp.valid then
          lamp.destroy()
        end
      end
      storage.ei.lamp_removals[tick] = nil
    end
  end
end
]]

return echo_codex
