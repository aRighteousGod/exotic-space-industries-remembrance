local test = require("test-config")
local expected = {
    restrained = {8,16,16,24,32,64}, standard = {8,16,24,32,64,128},
    expanded = {16,24,32,48,96,192}, generous = {16,32,48,64,128,256},
    industrial = {24,48,64,96,192,384}, massive = {32,64,96,128,256,512},
    vast = {48,96,128,192,384,768}, extreme = {64,128,192,256,512,1024},
}
local row = expected[test.profile]
local checks = 0
local function check(name, slots, kind)
    local entity = data.raw[kind or "container"][name]
    assert(entity, "missing " .. name)
    assert(entity.inventory_size == slots, name .. ": " .. entity.inventory_size .. " ~= " .. slots)
    checks = checks + 1
end
for index, name in ipairs({"wooden-chest", "iron-chest", "steel-chest"}) do check(name, row[index]) end
for index, size in ipairs({1,2,6}) do
    for _, suffix in ipairs({"", "-filter", "-blue", "-red", "-pink", "-yellow", "-green"}) do
        check("ei-" .. size .. "x" .. size .. "-container" .. suffix, row[index+3],
            (suffix == "" or suffix == "-filter") and "container" or "logistic-container")
    end
end
for _, mode in ipairs({"active-provider", "passive-provider", "storage", "buffer", "requester"}) do
    check("rp-steam-logistic-chest-" .. mode, row[5], "logistic-container")
    if data.raw["logistic-container"][mode .. "-chest"] then check(mode .. "-chest", row[4], "logistic-container") end
end
for name, index in pairs({small=4,medium=5,boundary=5,warehouse=6,rectangle=6,declared=6}) do
    check("container-qc-" .. name, row[index])
end
check("container-qc-linked", row[5], "linked-container")
for _, name in ipairs({"hidden", "weight", "custom", "unplaced"}) do check("container-qc-" .. name, 80) end
check("container-qc-zero", 0)
for name, original in pairs(container_qc_untouched) do check(name, original.slots, original.kind) end
if test.k2so then
    for _, kind in ipairs({"container", "logistic-container"}) do
        for name, entity in pairs(data.raw[kind]) do
            if name:match("^kr%-.*strongbox$") then check(name, row[5], kind) end
            if name:match("^kr%-.*warehouse$") then check(name, row[6], kind) end
            if name:match("^kr%-medium%-.*container$") then check(name, row[5], kind) end
            if name:match("^kr%-big%-.*container$") then check(name, row[6], kind) end
        end
    end
    check("kr-strongbox", row[5])
    check("kr-warehouse", row[6])
end
log("CONTAINER_QC_DATA " .. test.profile .. " checks=" .. checks .. " all_pass=true")
