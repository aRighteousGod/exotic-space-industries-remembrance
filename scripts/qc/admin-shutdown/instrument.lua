
-- Isolated full-coordinator shutdown fixture bridge.
local shutdown_qc_probe=require("__zzz-esir-admin-shutdown-qc__/probe")
shutdown_qc_probe.configure(require("scripts/control/admin/common"),require("scripts/control/admin/targeting"))
local shutdown_qc_configuration=ei_admin_tools.on_configuration_changed
ei_admin_tools.on_configuration_changed=function(tick)
 shutdown_qc_probe.before_configuration(tick)
 return shutdown_qc_configuration(tick)
end
remote.add_interface("esir-admin-shutdown-qc",{
 step=function(enabled,tick)return shutdown_qc_probe.step(ei_admin_tools,enabled,tick)end,
})
