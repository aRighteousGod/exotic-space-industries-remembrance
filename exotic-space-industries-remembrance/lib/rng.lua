--linear congruential generator rng generator for use outside of events, or for high performance
ei_rng = {}

-- Toggle for in-game print debug
local debug_rng = false

-- LCG Parameters (these can be tuned based on your needs)
local modulus = 2^32      -- Large modulus for high range (2^32 is common)
local a = 1664525         -- Multiplier (this is a known good choice for LCG)
local c = 1013904223      -- Increment (also a commonly used value for LCG)

-- Util
local function serialize_seed(input)
  if type(input) == "string" then return input end
  if type(input) == "number" then return tostring(input) end
  if type(input) == "table" then return serpent.line(input, {sortkeys = true}) end
  return tostring(input)
end

local function hash(str)
  local h = 5381
  for i = 1, #str do
    h = (bit32.lshift(h, 5) + h) + str:byte(i)
    h = bit32.band(h, 0x7FFFFFFF)
  end
  return h
end

local function log_echo(msg)
  log(msg)
  if debug_rng and game and game.print then
    game.print(msg)
  end
end

-- Linear Congruential Generator (LCG)
local function lcg(seed)
  return (a * seed + c) % modulus
end

-- Create fresh RNG per call
function create_ephemeral_rng(name, entropy1, entropy2, entropy3, entropy4)
  -- Use only deterministic factors if calling from outside an event
  local entropy = table.concat({
    name or "default_rng",
    entropy1 or "",
    entropy2 or "",
    entropy3 or "",
    entropy4 or ""
  }, "::")
  local seed = hash(serialize_seed(entropy))  -- Combine dynamic factors for better randomness
  return seed
end

function ei_rng.int(name, min, max, entropy1, entropy2, entropy3, entropy4)
  if min == nil or max == nil then
    log_echo("[ei_rng.int]: Missing min or max for '" .. tostring(name) .. "'")
    return 1
  elseif min > max then
    log_echo("⚠ [ei_rng.int] Swapping min > max for '" .. name .. "'")
    min, max = max, min
  elseif min == max then
    log_echo("⚠ [ei_rng.int] min == max for '" .. name .. "'")
	  return min
  end

  local seed = create_ephemeral_rng(name, entropy1, entropy2, entropy3, entropy4)
  local rng_value = lcg(seed or "ephemeral")  -- Generate a random number using LCG
  local result = min + (rng_value % (max - min + 1))  -- Scale it to the desired range
  
  -- Logging for debugging
  if debug_rng then
    log_echo("ei_rng.int: Generated value for '" .. tostring(name) .. "' = " .. result)
  end
  
  return result
end

function ei_rng.float(name, min, max, entropy1, entropy2, entropy3, entropy4)
  if min == nil or max == nil then
    log_echo("⚠ [ei_float.int]: Missing min or max for '" .. tostring(name) .. "'")
    return 1
  elseif min > max then
    log_echo("⚠ [ei_float.int] Swapping min > max for '" .. name .. "'")
    min, max = max, min
  elseif min == max then
    log_echo("⚠ [ei_float.int] min == max for '" .. name .. "'")
	  return min
  end
  local seed = create_ephemeral_rng(name or "default_rng", entropy1, entropy2, entropy3, entropy4) 
  local rng_value = lcg(seed) / modulus  -- Normalize to [0, 1)

  -- Logging for debugging
  if debug_rng then
    log_echo("ei_rng.float: Generated value for '" .. tostring(name) .. "' = " .. rng_value)
  end

  
  return rng_value
end


return ei_rng
