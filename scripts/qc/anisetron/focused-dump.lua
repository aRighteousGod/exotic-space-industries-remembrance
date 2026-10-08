-- Opt-in data-final-fixes snapshot for machines without room for the full dump.
-- The normal engine load still validates the complete active mod set.
local output={}
for _,kind in ipairs{"technology","spider-vehicle","spider-leg","equipment-grid","gun","ammo","ammo-category","beam","animation","recipe","item-with-entity-data","sticker","simple-entity-with-owner"} do
 output[kind]={}
 for name,prototype in pairs(data.raw[kind] or {}) do
  if prototype.type==kind and prototype.name==name and (kind=="technology" or name:find("^ei%-anisetron") or name:find("^ei%-singularity%-lance") or name=="ei-gaian-saucer-leg") then output[kind][name]=prototype end
 end
end
local function quoted(value)
 return '"'..value:gsub('[%z\1-\31\\"]',function(c)
  if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' else return string.format('\\u%04x',string.byte(c)) end
 end)..'"'
end
local function json(value)
 local kind=type(value)
 if kind=="string" then return quoted(value)
 elseif kind=="boolean" then return tostring(value)
 elseif kind=="number" then return string.format("%.17g",value)
 elseif kind=="table" then
  local rows={};local array=#value>0
  for key in pairs(value) do
   if type(key)~="number" or key%1~=0 or key<1 or key>#value then array=false;break end
  end
  if array then for _,v in ipairs(value) do rows[#rows+1]=json(v) end
  else for k,v in pairs(value) do rows[#rows+1]=quoted(tostring(k))..":"..json(v) end;table.sort(rows) end
  return (array and "[" or "{")..table.concat(rows,",")..(array and "]" or "}")
 end
 error("Unsupported dump value: "..kind)
end
log("ANISETRON_FOCUSED_FINAL_DATA "..json(output))
