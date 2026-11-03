-- QC-only support; each mod environment owns its own result table.
---@class EsirNativeCheck
---@field name string
---@field passed boolean
---@field detail string|nil
---@class EsirNativeContext
---@field run_id string
---@field suite string
---@field profile string
---@field phase string
---@field cases string[]
---@field input_hash string
---@field engine_version string
---@field deadline_ticks integer
---@field checkpoint boolean
---@field expected_mods table<string, boolean>
---@field parameters table Suite-owned runtime inputs, covered by the staged fingerprint.
---@class EsirNativeResult
---@field complete boolean
---@field checks EsirNativeCheck[]
---@field metrics table|nil Suite-owned measured values retained in the terminal receipt.
local support = {}
local config = require("__esir-qc-native-tests__.fixture-config")
---@type EsirNativeContext
support.config = script.test_arg and helpers.json_to_table(script.test_arg) or config
local checks = {}
function support.phase() return support.config.phase end
function support.record(name, passed, detail)
    checks[#checks + 1] = {name=name, passed=not not passed, detail=detail and tostring(detail) or nil}
end
support.case = support.record
function support.complete() support.done = true end
---@return EsirNativeResult
function support.poll() return {complete=support.done == true, checks=checks} end
return support
