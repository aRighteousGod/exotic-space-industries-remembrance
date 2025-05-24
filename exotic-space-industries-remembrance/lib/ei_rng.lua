ei_rng = {}

-- Toggle for in-game print debug
local debug_rng = false

-- Internal entropy
--storage.ei.rng_counter = storage.ei.rng_counter or 0  -- Store rng_counter in storage.ei
--storage.ei.last_tick = storage.ei.last_tick or -1       -- Store last_tick in storage.ei

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
function create_ephemeral_rng(name)
  -- Persist rng_counter and last_tick globally
  if game.tick ~= storage.ei.last_tick then
    storage.ei.rng_counter = 0
    storage.ei.last_tick = game.tick
  end
  storage.ei.rng_counter = storage.ei.rng_counter + 1
  
  -- Generate a more unique seed by incorporating game.tick, rng_counter, and the rng name
  local seed_input = name .. "::" .. game.tick .. "::" .. storage.ei.rng_counter .. "::" .. game.tick * storage.ei.rng_counter
  -- Additional entropy, if we need even more we'll go back thru and pull surface seeds
  local additional_entropy = game.tick + storage.ei.rng_counter
  local seed = hash(serialize_seed(seed_input .. "::" .. additional_entropy))  -- Combine dynamic factors for better randomness
  return seed
end

function ei_rng.int(name, min, max)
  if min == nil or max == nil then
    log_echo("ei_rng.int: Missing min or max for '" .. tostring(name) .. "'")
	local fallback = 1
	log_echo("🛑 [ei_rng.int] Fallback for '" .. name .. "'. Returning " .. fallback)
	return fallback
  end
  if min > max then
    log_echo("⚠ [ei_rng.int] Swapping min > max for '" .. name .. "'")
    min, max = max, min
  end
  if min == max then
	return min
  end

  local seed = create_ephemeral_rng(name)
  local rng_value = lcg(seed)
  local result = min + (rng_value % (max - min + 1))  -- Scale it to the desired range
  
  -- Logging for debugging
  if debug_rng then
    log_echo("ei_rng.int: Generated value for '" .. tostring(name) .. "' = " .. result)
  end
  
  return result
end

function ei_rng.float(name, min, max)
  local seed = create_ephemeral_rng(name)
  local rng_value = lcg(seed) / modulus  -- Normalize to [0, 1)

  -- Logging for debugging
  if debug_rng then
    log_echo("ei_rng.float: Generated value for '" .. tostring(name) .. "' = " .. rng_value)
  end

  if min and max then
    if min > max then
      log_echo("⚠ [ei_rng.float] Swapping min > max for '" .. name .. "'")
      min, max = max, min
    end
    return min + rng_value * (max - min)
  end
  
  return rng_value
end

-- Optional inspection utility (shows only counter)
function ei_rng.inspect()
  log_echo("🔍 [ei_rng] Current tick: " .. game.tick .. ", counter: " .. storage.ei.rng_counter)
end

return ei_rng
