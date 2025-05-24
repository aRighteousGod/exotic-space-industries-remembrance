local model = {}

--====================================================================================================
--INFORMATRON
--====================================================================================================

remote.add_interface("exotic-industries-fueler-informatron", {
    informatron_menu = function(data)
      return {}
    end,
    informatron_page_content = function(data)
      return model.page_content(data.page_name, data.player_index, data.element)
    end
})

--CONTENT
------------------------------------------------------------------------------------------------------

function model.page_content(page_name, player_index, element)
  if page_name == "exotic-industries-fueler-informatron" then
    element.add{type = "label", caption = {"exotic-industries-fueler-informatron.welcome"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-fueler-informatron.welcome-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_fueler-sprite"}

    element.add{type = "label", caption = {"exotic-industries-fueler-informatron.welcome-text-2"}}
  end
end