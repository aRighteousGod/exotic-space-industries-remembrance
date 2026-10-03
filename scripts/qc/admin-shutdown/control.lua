local fixture=require("fixture-config")
script.on_event(defines.events.on_tick,function(event)
 if storage.shutdown_done then return end
 local ok,result=pcall(remote.call,"esir-admin-shutdown-qc","step",fixture.enabled,event.tick)
 if not ok then
  helpers.write_file("shutdown-qc.json",helpers.table_to_json{all_pass=false,phase="error",error=tostring(result)},false)
  log("ADMIN_SHUTDOWN_QC ERROR "..tostring(result));storage.shutdown_done=true;return
 end
 if storage.shutdown_phase~=result.phase then
  storage.shutdown_phase=result.phase
  helpers.write_file("shutdown-qc.json",helpers.table_to_json(result),false)
  log("ADMIN_SHUTDOWN_QC PHASE "..result.phase)
 end
 if result.phase=="prepared" and fixture.enabled and not storage.shutdown_save_requested then
  storage.shutdown_save_requested=true
  helpers.write_file("shutdown-qc.json",helpers.table_to_json(result),false)
  log("ADMIN_SHUTDOWN_QC SAVE_REQUESTED")
  game.auto_save("admin-shutdown-enabled")
 elseif result.phase=="disabled_done" then
  helpers.write_file("shutdown-qc.json",helpers.table_to_json(result),false)
  log("ADMIN_SHUTDOWN_QC COMPLETE "..tostring(result.all_pass));storage.shutdown_done=true
 end
end)
