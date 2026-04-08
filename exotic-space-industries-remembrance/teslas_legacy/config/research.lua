function get_research_array()
  -- these values are also presented in the cocalization file as hard coded values.
  -- if you change them here, thes should be changed there as well
  return {
    -- single zap not used for 'basic' turret because if the target does not die
	-- and is also stationary (eg spitter) then the next zap tries to target it
	-- again which effectively blocks any chain reaction.
	-- instead it is used for the advanced turrets to branch out when an enemy dies
    single_zap = {
	  -- capacity: damage multiplier of each zap compared to normal damage 
	  -- (heavy lightning)
	  damage = { 0.3, 0.4, 0.5, 0.6, 0.7, 0.8 },
	  -- discharge: the number of potential zaps
	  -- (lightning trio)
      count = {  1, 2, 3, 4, 5, 6 },
	  -- overcharge: the probability of a zap (on-death)
	  probability = { nil, 0.20, 0.30, 0.40, 0.50, 0.60 },
    },
	flames = {
	  -- flash fire: the number of placed flames
	  -- (lightning flame)
	  count = { 1, 2, 3, 4, 5, 6 },
	  -- eruption: the radius/area of the explosion
	  -- (explosive materials)
	  explosion = { 1, 1.5, 2, 2.5, 3, 4 },
	  -- combustion: the probability of the explosion/each-flame (on-hit)
	  probability = { nil, 0.20, 0.30, 0.40, 0.50, 0.60 },
	},
    multi_zap = {
	  -- ionization: damage multiplier of each zap compared to normal damage 
	  -- (power lightning)
	  damage = { 0.2, 0.4, 0.6, 0.8, 1.0, 1.2  },
	  -- conductivity: effective range of each zap 
	  -- (electric whip)
      range = { 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 },
	  -- static field: the probability of the multi zasp (on-hit)
	  -- (static)
	  probability = { nil, 0.10, 0.20, 0.30, 0.40, 0.50 },
    },
	slowdown = {
	  -- persistence: the time it takes for the slowdown to wear off (in sec)
	  -- (stopwatch)
	  duration = { 0.5, 0.8, 1.3, 1.8, 2.3, 3 },
	  -- paralyze: the slowdonw effect multiplier ( 0 = stopped )
	  -- (round knob)
	  multiplier = { 0.75, 0.60, 0.45, 0.30, 0.15, 0.0 },
	  -- electroshock: the probability of the slowdown effect (on-hit)
	  -- (tunder struck)
	  probability = { nil, 0.35, 0.45, 0.55, 0.70, 0.90 },
	},
	volatility = {
	  -- bionization: a bonus damage multiplier which greatly increase damage potential,
	  --             but at the same time increase the chance of doing less damage
	  -- (lightning helix)
	  modulation = { 
	    { minimal = 1.0, maximal = 1.0 },
	    { minimal = 0.9, maximal = 1.5 },
	    { minimal = 0.8, maximal = 2.0 },
	    { minimal = 0.7, maximal = 2.5 },
	    { minimal = 0.6, maximal = 3.0 },
	    { minimal = 0.5, maximal = 3.5 },
	  },
	  -- vaporize: chance to instant death with a nice blood splatter
	  -- (deadly strike)
	  probability = { nil, 0.02, 0.04, 0.06, 0.08, 0.10 }
	}
  }
end

function get_default_index()
  local index = {
    single_zap = {
	  damage = 1,
      count = 1,
	  probability = 1,
    },
    multi_zap = {
	  damage = 1,
	  range = 1,
	  probability = 1,
    },
	flames = {
	  count = 1,
	  explosion = 1,
	  probability = 1,
	},
	slowdown = {
	  duration = 1,
	  multiplier = 1,
	  probability = 1,
	},
	volatility = {
	  modulation = 1,
	  probability = 1,
	}
  }
  return index
end

function get_research(index)
  local research = get_research_array() -- TODO should I make this a variable instead?
  return {
    single_zap = {
	  damage = research.single_zap.damage[index.single_zap.damage],
      count = research.single_zap.count[index.single_zap.count],
	  probability = research.single_zap.probability[index.single_zap.probability],
    },
    multi_zap = {
	  damage = research.multi_zap.damage[index.multi_zap.damage],
      range = research.multi_zap.range[index.multi_zap.range],
	  probability = research.multi_zap.probability[index.multi_zap.probability],
    },
	flames = {
	  count = research.flames.count[index.flames.count],
	  explosion = research.flames.explosion[index.flames.explosion],
	  probability = research.flames.probability[index.flames.probability],
	},
	slowdown = {
	  duration = research.slowdown.duration[index.slowdown.duration],
	  multiplier = research.slowdown.multiplier[index.slowdown.multiplier],
	  probability = research.slowdown.probability[index.slowdown.probability],
	},
	volatility = {
	  modulation = research.volatility.modulation[index.volatility.modulation],
	  probability = research.volatility.probability[index.volatility.probability],
	},
  }  
end



