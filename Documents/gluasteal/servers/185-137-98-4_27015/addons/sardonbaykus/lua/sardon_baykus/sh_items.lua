-- "addons\\sardonbaykus\\lua\\sardon_baykus\\sh_items.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
do
     local ITEM = ix.item.Register("owl_scroll_box", nil, false, nil, true)

     ITEM.name = "Tubo de pergaminos"
     ITEM.description = "Guarda todos los mensajes de lechuza que has recibido."
     ITEM.model = "models/food/hotdog.mdl"

     ITEM.functions.Use = {
          name = "openScroll",
          icon = "icon16/eye.png",
          OnRun = function(item)
               local ply = item.player
               if not ply then return false end
               if SERVER and SardonBaykus.OpenScrollList then
                    SardonBaykus.OpenScrollList(ply)
               end
               return false
          end
     }

     ix.lang.AddTable("english", {
          openScroll = "Abrir"
     })
end

do
     local ITEM = ix.item.Register("owl_scroll", nil, false, nil, true)

     ITEM.name = "Pergamino de lechuza"
     ITEM.description = "Un mensaje traído por lechuza."
     ITEM.model = "models/items/magic/scrolls/scroll_rolled.mdl"

     ITEM.functions.Use = {
          name = "openScroll",
          icon = "icon16/eye.png",
          OnRun = function(item)
               if not item.player then return false end
               if SERVER and SardonBaykus.OpenSingleScroll then
                    return SardonBaykus.OpenSingleScroll(item.player, item)
               end
               return false
          end
     }

     ITEM.functions.Tear = {
          name = "tearScroll",
          icon = "icon16/gun.png",
          OnRun = function(item)
               return true
          end
     }

     ix.lang.AddTable("english", {
          openScroll = "Abrir",
          tearScroll = "Rasgar"
     })
end