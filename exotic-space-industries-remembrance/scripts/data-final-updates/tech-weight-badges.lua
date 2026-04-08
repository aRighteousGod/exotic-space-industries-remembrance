local tech_weighting = require("lib/tech-weighting")

local MARKER_ICON_ROOT = "__exotic-space-industries-remembrance__/graphics/icons/"
local MARKER_ICON_BY_LEVEL = {
  [1] = MARKER_ICON_ROOT .. "weight-marker-1.png",
  [2] = MARKER_ICON_ROOT .. "weight-marker-2.png",
  [3] = MARKER_ICON_ROOT .. "weight-marker-3.png",
}

local function is_weight_marker_icon(icon_path)
  for _, marker_path in pairs(MARKER_ICON_BY_LEVEL) do
    if icon_path == marker_path then
      return true
    end
  end

  return false
end

local function normalize_technology_icons(technology)
  if technology.icons then
    return technology.icons
  end

  if not technology.icon then
    return nil
  end

  technology.icons = {{
    icon = technology.icon,
    icon_size = technology.icon_size or 256,
    icon_mipmaps = technology.icon_mipmaps,
  }}
  technology.icon = nil
  technology.icon_mipmaps = nil

  return technology.icons
end

local function get_base_icon_size(technology, icons)
  local first_icon = icons and icons[1]
  return (first_icon and first_icon.icon_size) or technology.icon_size or 256
end

local function apply_weight_marker(technology)
  local marker_level = tech_weighting.get_weight_marker_level(technology.name, technology)
  if not marker_level then
    return
  end

  local icons = normalize_technology_icons(technology)
  if not icons then
    return
  end

  for index = #icons, 1, -1 do
    if is_weight_marker_icon(icons[index].icon) then
      table.remove(icons, index)
    end
  end

  -- The marker art is authored on a transparent 256px canvas with a tiny high-contrast fraction
  -- label parked in the extreme lower-right corner. Scale it to the technology's base icon size
  -- so 64/128/256 icons all keep the same relative marker footprint.
  icons[#icons + 1] = {
    icon = MARKER_ICON_BY_LEVEL[marker_level],
    icon_size = 256,
    scale = get_base_icon_size(technology, icons) / 256,
  }
end

for _, technology in pairs(data.raw.technology or {}) do
  apply_weight_marker(technology)
end
