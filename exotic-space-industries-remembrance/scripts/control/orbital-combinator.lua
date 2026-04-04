local model = {}

local ORBITAL_COMBINATOR_NAME = "ei-orbital-combinator"
local OVERFLOW_SECTION_GROUP = "Scanner overflow"
local DEFAULT_MEMBER_SLOT_CAPACITY = 10000
local ADJACENT_OFFSETS = {
  {x = 2, y = 0},
  {x = -2, y = 0},
  {x = 0, y = 2},
  {x = 0, y = -2},
}
local OVERFLOW_SIGNAL = {
  type = "virtual",
  name = "ei-orbital-overflow",
  quality = "normal",
}

local snapshot_cache_tick = -1
local snapshot_cache = {}


local function clear_snapshot_cache()
  snapshot_cache_tick = -1
  snapshot_cache = {}
end


function model.entity_check(entity)
  if entity == nil then return false end
  if not entity.valid then return false end
  return true
end


local function is_registered_scanner(entity)
  return model.entity_check(entity) and entity.name == ORBITAL_COMBINATOR_NAME and entity.unit_number ~= nil
end


local function get_signal_name(signal_name)
  if signal_name == nil then
    return nil
  end

  if type(signal_name) == "string" then
    return signal_name
  end

  if signal_name.name then
    return signal_name.name
  end

  return tostring(signal_name)
end


local function get_quality_name(quality)
  if quality == nil then
    return "normal"
  end

  if type(quality) == "string" then
    return quality
  end

  if quality.name then
    return quality.name
  end

  return tostring(quality)
end


local function normalize_signal_id(value)
  if not value then
    return nil
  end

  local signal_name = get_signal_name(value.name)
  if not signal_name then
    return nil
  end

  return {
    type = value.type or "item",
    name = signal_name,
    quality = get_quality_name(value.quality),
  }
end


local function copy_signal_id(value)
  local normalized = normalize_signal_id(value)
  if not normalized then
    return nil
  end

  return {
    type = normalized.type,
    name = normalized.name,
    quality = normalized.quality,
  }
end


local function make_filter(value, min, max)
  local signal = copy_signal_id(value)
  if not signal then
    return nil
  end

  return {
    value = signal,
    min = min,
    max = max,
  }
end


local function signal_key(value)
  return table.concat({
    value.type or "item",
    value.name or "",
    value.quality or "normal",
  }, "|")
end


local function compare_signal_values(a, b)
  if a.type ~= b.type then
    return a.type < b.type
  end
  if a.name ~= b.name then
    return a.name < b.name
  end
  return (a.quality or "normal") < (b.quality or "normal")
end


local function compare_filters(a, b)
  return compare_signal_values(a.value, b.value)
end


local function compare_entities(a, b)
  local pos_a = a.position
  local pos_b = b.position

  if pos_a.y ~= pos_b.y then
    return pos_a.y < pos_b.y
  end
  if pos_a.x ~= pos_b.x then
    return pos_a.x < pos_b.x
  end

  return (a.unit_number or 0) < (b.unit_number or 0)
end


local function compare_platforms(a, b)
  if a.name ~= b.name then
    return a.name < b.name
  end

  return (a.sort_id or 0) < (b.sort_id or 0)
end


local function hash_update(hash, value)
  local text = tostring(value)

  for i = 1, #text do
    hash = ((hash * 33) + string.byte(text, i)) % 4294967296
  end

  return hash
end


local function get_grid_coordinate(value)
  return math.floor((value * 2) + 0.5)
end


local function get_position_key_from_xy(grid_x, grid_y)
  return tostring(grid_x) .. ":" .. tostring(grid_y)
end


local function get_position_key(entity)
  local pos = entity.position
  return get_position_key_from_xy(get_grid_coordinate(pos.x), get_grid_coordinate(pos.y))
end


local function sanitize_registered_entities()
  local removed_any = false

  for unit_number, entity in pairs(storage.ei.orbital_combinators) do
    if not is_registered_scanner(entity) or entity.unit_number ~= unit_number then
      storage.ei.orbital_combinators[unit_number] = nil
      removed_any = true
    end
  end

  if removed_any then
    clear_snapshot_cache()
  end

  return removed_any
end


local function rebuild_registry_from_world()
  if not game or not game.surfaces then
    return
  end

  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{name = ORBITAL_COMBINATOR_NAME}) do
      if is_registered_scanner(entity) then
        storage.ei.orbital_combinators[entity.unit_number] = entity
      end
    end
  end
end


function model.check_init(rebuild_banks)
  if not storage.ei then
    storage.ei = {}
  end

  if not storage.ei.orbital_combinators then
    storage.ei.orbital_combinators = {}
  end
  if storage.ei.orbital_combinators_break_point == nil then
    storage.ei.orbital_combinators_break_point = nil
  end

  if not storage.ei.orbital_combinator_banks then
    storage.ei.orbital_combinator_banks = {}
  end
  if not storage.ei.orbital_combinator_bank_by_unit then
    storage.ei.orbital_combinator_bank_by_unit = {}
  end
  if storage.ei.orbital_combinator_banks_break_point == nil then
    storage.ei.orbital_combinator_banks_break_point = nil
  end
  if storage.ei.orbital_combinator_bank_count == nil then
    storage.ei.orbital_combinator_bank_count = 0
  end

  if rebuild_banks == nil then
    rebuild_banks = true
  end

  if rebuild_banks then
    if ei_lib.getn(storage.ei.orbital_combinators) == 0 then
      rebuild_registry_from_world()
    end
    model.rebuild_banks()
  end
end


function model.rebuild_banks()
  model.check_init(false)
  sanitize_registered_entities()

  local grouped_entities = {}
  local banks = {}
  local bank_by_unit = {}

  for _, entity in pairs(storage.ei.orbital_combinators) do
    if is_registered_scanner(entity) then
      local group_key = tostring(entity.force.index) .. ":" .. tostring(entity.surface.index)
      local group = grouped_entities[group_key]

      if not group then
        group = {
          entities = {},
          by_position = {},
          force_index = entity.force.index,
          surface_index = entity.surface.index,
        }
        grouped_entities[group_key] = group
      end

      table.insert(group.entities, entity)
      group.by_position[get_position_key(entity)] = entity
    end
  end

  for _, group in pairs(grouped_entities) do
    table.sort(group.entities, compare_entities)

    local visited = {}

    for _, root in ipairs(group.entities) do
      local root_unit = root.unit_number

      if not visited[root_unit] then
        local queue = {root}
        local component = {}
        local head = 1
        visited[root_unit] = true

        while head <= #queue do
          local current = queue[head]
          head = head + 1
          component[#component + 1] = current

          local current_x = get_grid_coordinate(current.position.x)
          local current_y = get_grid_coordinate(current.position.y)

          for _, offset in ipairs(ADJACENT_OFFSETS) do
            local neighbor = group.by_position[get_position_key_from_xy(current_x + offset.x, current_y + offset.y)]
            if neighbor and not visited[neighbor.unit_number] then
              visited[neighbor.unit_number] = true
              queue[#queue + 1] = neighbor
            end
          end
        end

        table.sort(component, compare_entities)

        local members = {}
        for _, member in ipairs(component) do
          members[#members + 1] = member.unit_number
        end

        local bank_id = members[1]
        banks[bank_id] = {
          id = bank_id,
          anchor_unit_number = bank_id,
          force_index = group.force_index,
          surface_index = group.surface_index,
          members = members,
          signature = nil,
        }

        for _, unit_number in ipairs(members) do
          bank_by_unit[unit_number] = bank_id
        end
      end
    end
  end

  storage.ei.orbital_combinator_banks = banks
  storage.ei.orbital_combinator_bank_by_unit = bank_by_unit
  storage.ei.orbital_combinator_banks_break_point = nil
  storage.ei.orbital_combinator_bank_count = ei_lib.getn(banks)
  clear_snapshot_cache()
end


function model.add(entity)
  if not is_registered_scanner(entity) then
    return
  end

  model.check_init(false)
  storage.ei.orbital_combinators[entity.unit_number] = entity
  model.rebuild_banks()
end


function model.rem(entity)
  if not entity or not entity.valid or entity.name ~= ORBITAL_COMBINATOR_NAME or not entity.unit_number then
    return
  end

  model.check_init(false)
  storage.ei.orbital_combinators[entity.unit_number] = nil
  model.rebuild_banks()
end


local function merge_filter_entry(target, source)
  target.min = (target.min or 0) + (source.min or 0)

  if target.max ~= nil and source.max ~= nil then
    target.max = target.max + source.max
  else
    target.max = nil
  end
end


local function get_logistic_content(entity)
  if not entity or not entity.valid then
    return {}
  end

  local merged = {}
  local points = entity.get_logistic_point()

  for _, logistic_point in pairs(points) do
    for _, logistic_section in pairs(logistic_point.sections) do
      for i = 1, logistic_section.filters_count do
        local slot = logistic_section.get_slot(i)

        if slot and slot.value and slot.min and slot.min > 0 then
          local signal = copy_signal_id(slot.value)
          if signal then
            local key = signal_key(signal)
            local filter = make_filter(signal, slot.min, slot.max)

            if filter then
              if merged[key] then
                merge_filter_entry(merged[key], filter)
              else
                merged[key] = filter
              end
            end
          end
        end
      end
    end
  end

  local filters = {}
  for _, filter in pairs(merged) do
    filters[#filters + 1] = filter
  end

  table.sort(filters, compare_filters)
  return filters
end


local function build_surface_snapshot(force, surface)
  local platforms = {}

  for _, platform in pairs(force.platforms) do
    if platform and platform.valid then
      local location = platform.space_location
      local hub = platform.hub

      if location and location.name == surface.name and hub and hub.valid then
        platforms[#platforms + 1] = {
          name = platform.name or ("platform-" .. tostring(hub.unit_number or #platforms + 1)),
          sort_id = hub.unit_number or 0,
          filters = get_logistic_content(hub),
        }
      end
    end
  end

  table.sort(platforms, compare_platforms)

  return {
    platforms = platforms,
  }
end


local function get_surface_snapshot(force, surface)
  local current_tick = game.tick

  if snapshot_cache_tick ~= current_tick then
    snapshot_cache_tick = current_tick
    snapshot_cache = {}
  end

  local cache_key = tostring(force.index) .. ":" .. tostring(surface.index)
  if not snapshot_cache[cache_key] then
    snapshot_cache[cache_key] = build_surface_snapshot(force, surface)
  end

  return snapshot_cache[cache_key]
end


local function get_member_slot_capacity(entity)
  return DEFAULT_MEMBER_SLOT_CAPACITY
end


local function get_bank_members(bank)
  local members = {}
  local min_capacity = nil

  for _, unit_number in ipairs(bank.members or {}) do
    local entity = storage.ei.orbital_combinators[unit_number]
    if not is_registered_scanner(entity) then
      return nil
    end

    local capacity = math.max(1, get_member_slot_capacity(entity))
    members[#members + 1] = {
      unit_number = unit_number,
      entity = entity,
      capacity = capacity,
    }

    if not min_capacity or capacity < min_capacity then
      min_capacity = capacity
    end
  end

  return members, min_capacity or DEFAULT_MEMBER_SLOT_CAPACITY
end


local function make_page_label(platform_name, page_index, page_count)
  if page_index == 1 then
    return platform_name
  end

  return string.format("%s [%d/%d]", platform_name, page_index, page_count)
end


local function split_platform_into_pages(platform, page_capacity)
  local pages = {}
  local filters = platform.filters
  local filter_count = #filters
  local page_count = math.max(1, math.ceil(filter_count / page_capacity))

  for page_index = 1, page_count do
    local start_index = ((page_index - 1) * page_capacity) + 1
    local stop_index = math.min(start_index + page_capacity - 1, filter_count)
    local page_filters = {}

    if filter_count > 0 then
      for filter_index = start_index, stop_index do
        local filter = filters[filter_index]
        page_filters[#page_filters + 1] = make_filter(filter.value, filter.min, filter.max)
      end
    end

    pages[#pages + 1] = {
      label = make_page_label(platform.name, page_index, page_count),
      filters = page_filters,
      cost = math.max(1, #page_filters),
    }
  end

  return pages
end


local function build_bank_pages(snapshot, page_capacity)
  local pages = {}

  for _, platform in ipairs(snapshot.platforms) do
    local platform_pages = split_platform_into_pages(platform, page_capacity)
    for _, page in ipairs(platform_pages) do
      pages[#pages + 1] = page
    end
  end

  return pages
end


local function assign_pages_to_members(members, pages, reserved_anchor_cost)
  local layouts = {}
  local used_cost = {}
  local member_index = 1
  local omitted_filter_count = 0

  for index, member in ipairs(members) do
    layouts[member.unit_number] = {}
    used_cost[index] = 0
  end

  local function remaining_capacity(index)
    local reserve = 0
    if index == 1 then
      reserve = reserved_anchor_cost
    end

    return members[index].capacity - reserve - used_cost[index]
  end

  for _, page in ipairs(pages) do
    while member_index <= #members and remaining_capacity(member_index) < page.cost do
      member_index = member_index + 1
    end

    if member_index > #members then
      omitted_filter_count = omitted_filter_count + #page.filters
    else
      local member_layout = layouts[members[member_index].unit_number]
      member_layout[#member_layout + 1] = page
      used_cost[member_index] = used_cost[member_index] + page.cost
    end
  end

  return layouts, omitted_filter_count
end


local function append_overflow_page(layouts, anchor_unit_number, omitted_filter_count)
  if omitted_filter_count <= 0 then
    return
  end

  layouts[anchor_unit_number] = layouts[anchor_unit_number] or {}
  layouts[anchor_unit_number][#layouts[anchor_unit_number] + 1] = {
    label = OVERFLOW_SECTION_GROUP,
    filters = {
      {
        value = copy_signal_id(OVERFLOW_SIGNAL),
        min = omitted_filter_count,
        max = nil,
      }
    },
    cost = 1,
  }
end


local function build_layout_signature(bank, layouts)
  local hash = 5381

  for _, unit_number in ipairs(bank.members or {}) do
    local member_pages = layouts[unit_number] or {}
    hash = hash_update(hash, unit_number)
    hash = hash_update(hash, #member_pages)

    for _, page in ipairs(member_pages) do
      hash = hash_update(hash, page.label)
      hash = hash_update(hash, #page.filters)

      for _, filter in ipairs(page.filters) do
        hash = hash_update(hash, filter.value.type or "item")
        hash = hash_update(hash, filter.value.name or "")
        hash = hash_update(hash, filter.value.quality or "normal")
        hash = hash_update(hash, filter.min or 0)
        hash = hash_update(hash, filter.max == nil and "nil" or filter.max)
      end
    end
  end

  return string.format("%08x", hash)
end


local function filters_match(slot, expected_filter)
  if not slot or not slot.value then
    return false
  end

  local signal = normalize_signal_id(slot.value)
  if not signal then
    return false
  end

  if signal.type ~= expected_filter.value.type then
    return false
  end
  if signal.name ~= expected_filter.value.name then
    return false
  end
  if signal.quality ~= expected_filter.value.quality then
    return false
  end
  if slot.min ~= expected_filter.min then
    return false
  end
  if slot.max ~= expected_filter.max then
    return false
  end

  return true
end


local function section_matches_page(section, page)
  if not section then
    return false
  end

  if section.group ~= page.label then
    return false
  end

  if section.filters_count ~= #page.filters then
    return false
  end

  for index, filter in ipairs(page.filters) do
    if not filters_match(section.get_slot(index), filter) then
      return false
    end
  end

  return true
end


local function write_section(section, page)
  section.active = true
  section.group = page.label

  local current_count = section.filters_count
  local desired_count = #page.filters

  if current_count > desired_count then
    for index = current_count, desired_count + 1, -1 do
      section.clear_slot(index)
    end
  end

  for index, filter in ipairs(page.filters) do
    section.set_slot(index, {
      value = copy_signal_id(filter.value),
      min = filter.min,
      max = filter.max,
    })
  end
end


local function reconcile_entity(entity, desired_pages)
  local control = entity.get_control_behavior()
  if not control or not control.valid then
    return false
  end

  while control.sections_count > #desired_pages do
    if not control.remove_section(control.sections_count) then
      return false
    end
  end

  while control.sections_count < #desired_pages do
    if not control.add_section("") then
      return false
    end
  end

  for index, page in ipairs(desired_pages) do
    local section = control.get_section(index)
    if not section then
      return false
    end

    if not section_matches_page(section, page) then
      write_section(section, page)
    end
  end

  return true
end


local function build_bank_layout(bank)
  local members, page_capacity = get_bank_members(bank)
  if not members or #members == 0 then
    return nil
  end

  local anchor = members[1].entity
  local snapshot = get_surface_snapshot(anchor.force, anchor.surface)
  local pages = build_bank_pages(snapshot, page_capacity)
  local layouts, omitted_filter_count = assign_pages_to_members(members, pages, 0)

  if omitted_filter_count > 0 then
    local overflow_page_capacity = math.max(1, page_capacity - 1)
    pages = build_bank_pages(snapshot, overflow_page_capacity)
    layouts, omitted_filter_count = assign_pages_to_members(members, pages, 1)
    append_overflow_page(layouts, bank.anchor_unit_number, omitted_filter_count)
  end

  return layouts
end


function model.update_orbital_bank(bank)
  if not bank then
    return false
  end

  local layouts = build_bank_layout(bank)
  if not layouts then
    model.rebuild_banks()
    return false
  end

  local signature = build_layout_signature(bank, layouts)
  if bank.signature == signature then
    return true
  end

  for _, unit_number in ipairs(bank.members or {}) do
    local entity = storage.ei.orbital_combinators[unit_number]
    if not is_registered_scanner(entity) then
      model.rebuild_banks()
      return false
    end

    if not reconcile_entity(entity, layouts[unit_number] or {}) then
      return false
    end
  end

  bank.signature = signature
  return true
end


function model.get_bank_count()
  model.check_init(false)
  return storage.ei.orbital_combinator_bank_count or 0
end


function model.update()
  model.check_init(false)

  if not storage.ei or not storage.ei.orbital_combinator_banks then
    return false
  end

  if storage.ei.orbital_combinator_bank_count == nil then
    storage.ei.orbital_combinator_bank_count = ei_lib.getn(storage.ei.orbital_combinator_banks)
  end

  if not storage.ei.orbital_combinator_banks_break_point and next(storage.ei.orbital_combinator_banks) then
    storage.ei.orbital_combinator_banks_break_point = next(storage.ei.orbital_combinator_banks)
  end

  if not storage.ei.orbital_combinator_banks_break_point then
    return false
  end

  local break_id = storage.ei.orbital_combinator_banks_break_point
  local bank = storage.ei.orbital_combinator_banks[break_id]

  if not bank then
    model.rebuild_banks()
    return false
  end

  if not model.update_orbital_bank(bank) then
    storage.ei.orbital_combinator_banks_break_point = nil
    return false
  end

  local next_break_id = next(storage.ei.orbital_combinator_banks, break_id)
  if next_break_id then
    storage.ei.orbital_combinator_banks_break_point = next_break_id
    return true
  end

  storage.ei.orbital_combinator_banks_break_point = nil
  return false
end


return model
