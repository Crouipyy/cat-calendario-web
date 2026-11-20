-- "addons\\sardonshineadmin\\lua\\sardon_shineadmin\\cl_page_wand.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Shine Admin :: asa sayfaları. [hogwarts] wand Nocturne sayfaları zaten build(ctx)
-- sözleşmesiyle yazılmış; aynı kodu Shine Admin penceresinde çalıştırıyoruz.
-- Yetki kontrolleri (A.CanSeeAdmin / A.CanSeeServerSettings) asa menüsünün kendi kontrolleri.

local function WandSource(id)
     local N = ShineAdmin.GetN()
     return N and N.Pages and N.Pages[id], N and N.A
end

ShineAdmin:RegisterPage("wand_admin", {
     label = "Gestión de hechizos",
     icon = "wand",
     group = "magic",
     order = 10,
     title = "Gestión de hechizos",
     subtitle = "Dar o quitar hechizos a jugadores; añadir hechizos a lista negra o lista de staff.",
     rail = true,
     wand = true,
     available = function()
          local page, A = WandSource("admin")
          return page and A and true or false
     end,
     access = function()
          local _, A = WandSource("admin")
          return A and A.CanSeeAdmin() or false
     end,

     build = function(ctx)
          local page = WandSource("admin")
          return page.build(ctx)
     end
})

ShineAdmin:RegisterPage("wand_server", {
     label = "Ajustes del servidor (varita)",
     icon = "server",
     group = "magic",
     order = 20,
     title = "Ajustes del servidor (varita)",
     subtitle = "Ajustes globales del complemento de varita (ConVar).",
     rail = true,
     wand = true,
     available = function()
          local page, A = WandSource("settings")
          return page and A and true or false
     end,
     access = function()
          local _, A = WandSource("settings")
          return A and A.CanSeeServerSettings() or false
     end,

     build = function(ctx)
          local page = WandSource("settings")
          local refresh = page.build(ctx)

          -- ayarlar sayfası istemci sekmesiyle açılıyor; doğrudan sunucu sekmesine geç
          if (ctx.SwitchSub) then ctx.SwitchSub("server") end

          return refresh
     end
})
