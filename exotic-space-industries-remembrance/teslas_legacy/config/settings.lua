function get_settings()
  return
  {
    behavior_mode = settings.startup["ei-tl-behavior-mode"].value,
    text = {
	  
      critical = settings.startup["tl-flying-text-critical"].value,
      vaporize = settings.startup["tl-flying-text-vaporize"].value,
      damage = settings.startup["tl-flying-text-damage"].value,
	},
    flames =
	{
	  damage = 50,
	},
    critical =
	{
	  multiplier = settings.startup["tl-critical-multiplier"].value,
	  probability = settings.startup["tl-critical-chance"].value / 100,
	},
    turret =
    {
      basic = 
      {
		health = settings.startup["tl-basic-health"].value,
        damage = settings.startup["tl-basic-damage"].value,
        fire_rate = settings.startup["tl-basic-fire-rate"].value,
        range = 
        {
          min = 0,
          max = settings.startup["tl-basic-range"].value,
        },
        
      },
      advanced =
      {
	    anim = settings.startup["tl-advanced-attack-anim"].value,
		health = settings.startup["tl-advanced-health"].value,
        damage = settings.startup["tl-advanced-damage"].value,
        fire_rate = settings.startup["tl-advanced-fire-rate"].value,
        range = 
        {
          min = 0,
          max = settings.startup["tl-advanced-range"].value,
        },
      },
    },
	vehicle =
	{
	  tank =
	  {
		health = settings.startup["tl-tank-health"].value,
	    damage = settings.startup["tl-tank-damage"].value,
		range = settings.startup["tl-tank-range"].value,
		fire_rate = settings.startup["tl-tank-fire-rate"].value,
	  }
	}
  }
end

