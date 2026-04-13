function get_empty_picture()
  return 
  {
    filename = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/invisible.png",
    priority = "high",
    width = 20,
    height = 20,
  }
end

function get_empty_animation()
  local anim = get_empty_picture()
  anim.line_length = 1
  anim.frame_count = 1
  anim.direction_count = 1
  return anim
end


