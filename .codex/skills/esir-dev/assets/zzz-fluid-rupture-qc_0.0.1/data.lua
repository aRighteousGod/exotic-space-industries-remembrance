local ignored_pipe_name = "tnd-pipe-name"

if data.raw.pipe and data.raw.pipe.pipe and not data.raw.pipe[ignored_pipe_name] then
  local ignored_pipe = table.deepcopy(data.raw.pipe.pipe)
  ignored_pipe.name = ignored_pipe_name
  ignored_pipe.hidden = true
  ignored_pipe.hidden_in_factoriopedia = true
  ignored_pipe.minable = nil
  ignored_pipe.placeable_by = nil

  data:extend({ignored_pipe})
end
