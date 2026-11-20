-- "addons\\sardonshineadmin\\lua\\sardon_shineadmin\\cl_init.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Shine Admin :: istemci çerçevesi
--
-- Sunucudaki yönetim / ayar ekranlarını tek pencerede sayfa sayfa toplar.
-- Görsel dil ve kontroller asa menüsünden ([hogwarts] wand, Nocturne) gelir:
-- HpwRewrite.Nocturne teması, düğme / anahtar / alt sekme / bilgi rayı
-- bileşenleri doğrudan kullanılır. Yerleşim de asa menüsüyle aynı tuvalde:
--
--   pencere 1520 x 790 (1920x1080'e göre ölçeklenir)
--     başlık 106 :: arma · SHINE ADMIN · sayfa adı · yetkili bilgisi
--     kenar çubuğu 238 :: gruplanmış sayfa listesi (kaydırılabilir)
--     içerik :: sayfa başlığı 96 + ana içerik (+ isteğe bağlı 338 bilgi rayı)
--     alt şerit 44
--
-- Sayfa eklemek:
--   ShineAdmin:RegisterPage("id", {
--        label, icon, group, order, title, subtitle, rail,
--        access = "staff" | function(ply) end,   -- _sh_core.lua kuralları
--        available = function() end,             -- eklenti yüklü mü
--        build = function(ctx) return refreshFn end
--   })

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Routes = ShineAdmin.Routes or {}

ShineAdmin.Groups = {
     {id = "home", label = "General"},
     {id = "systems", label = "Sistemas"},
     {id = "players", label = "Jugadores"},
     {id = "magic", label = "Hechizos"},
     {id = "tools", label = "Herramientas"}
}

function ShineAdmin.GetN()
     return HpwRewrite and HpwRewrite.Nocturne and HpwRewrite.Nocturne.Button and HpwRewrite.Nocturne or nil
end

function ShineAdmin:RegisterPage(id, def)
     def.id = id
     def.order = def.order or 100
     self.Pages[id] = def
end

function ShineAdmin:Request(action)
     net.Start("ShineAdmin.Request")
          net.WriteString(action)
     net.SendToServer()
end

function ShineAdmin:CanSee(id)
     local page = self.Pages[id]
     if (!page) then return false end
     if (page.available and !page.available()) then return false end

     local access = page.access
     if (isfunction(access)) then return access(LocalPlayer()) and true or false end
     if (isstring(access)) then return ShineAdmin.Can(LocalPlayer(), access) end

     return true
end

-- Grup ve sıraya göre görünür sayfalar
function ShineAdmin:VisiblePages()
     local out = {}

     for _, group in ipairs(self.Groups) do
          local list = {}

          for id, page in pairs(self.Pages) do
               if ((page.group or "tools") == group.id and self:CanSee(id)) then
                    list[#list + 1] = page
               end
          end

          table.sort(list, function(a, b)
               if (a.order != b.order) then return a.order < b.order end
               return a.label < b.label
          end)

          if (#list > 0) then
               out[#out + 1] = {group = group, pages = list}
          end
     end

     return out
end

--[[
*   ağ yönlendirme
*
*   Eski tek başına pencereleri açan mesajlar (ör. /kademe, skor tablosundaki
*   "Whitelistlerini Düzenle") Shine Admin'in ilgili sayfasına yönlendirilir.
*   Kaynak eklentinin alıcısı silinmez; Nocturne yoksa ona düşülür.
*   fn(len, original, ply) mesajı kendisi okur.
]]

local installed = {}

function ShineAdmin:InstallRoutes()
     for name, fn in pairs(self.Routes) do
          local current = net.Receivers[name]

          if (current and current != installed[name]) then
               local original = current
               local wrapper = function(len, ply)
                    if (!ShineAdmin.GetN()) then
                         return original(len, ply)
                    end

                    fn(len, original, ply)
               end

               installed[name] = wrapper
               net.Receivers[name] = wrapper
          end
     end
end

function ShineAdmin:Route(name, fn)
     self.Routes[string.lower(name)] = fn
     self:InstallRoutes()
end

hook.Add("InitPostEntity", "ShineAdmin.Routes", function()
     timer.Simple(2, function() ShineAdmin:InstallRoutes() end)
end)

--[[
*   ölçüler :: asa menüsüyle aynı
]]

local FW, FH = 1520, 790
local HEAD_H = 106
local FOOT_H = 44
local SIDE_W = 238
local CA_W = FW - SIDE_W
local BODY_H = FH - HEAD_H - FOOT_H
local PHEAD_H = 96
local PAD = 30
local RAIL_W = 338

local function StaffOnline()
     local n = 0

     for _, ply in ipairs(player.GetAll()) do
          if (ply:IsAdmin()) then n = n + 1 end
     end

     return n
end

local function BuildWindow()
     local N = ShineAdmin.GetN()
     local u = N.u

     N:Prepare()

     local fw, fh = u(FW), u(FH)
     local ox = math.floor((ScrW() - fw) / 2)
     local oy = math.floor((ScrH() - fh) / 2)

     local frame = vgui.Create("DFrame")
     frame:SetSize(ScrW(), ScrH())
     frame:SetPos(0, 0)
     frame:SetTitle("")
     frame:ShowCloseButton(false)
     frame:SetDraggable(false)
     frame:SetSizable(false)
     frame:MakePopup()

     frame.OpenTime = RealTime()
     frame.ScrW, frame.ScrH = ScrW(), ScrH()
     frame.Page = nil

     frame.Paint = function(s, w, h)
          Derma_DrawBackgroundBlur(s, s.OpenTime)
          N.Box(0, 0, w, h, N.Clr.shade)

          N.Box(ox, oy, fw, fh, N.Clr.bg)
          N.Outline(ox, oy, fw, fh, N.Clr.railLine, 1)
          N.Corners(ox, oy, fw, fh, u(30), N.Clr.goldSoft)

          -- başlık
          N.Box(ox + 1, oy + 1, fw - 2, u(HEAD_H) - 1, N.Clr.header)
          N.Box(ox + 1, oy + u(HEAD_H), fw - 2, 1, N.Clr.headLine)

          local hx = ox + u(26)
          local crest = u(52)

          if (!N.Fit("ornaments/crest", hx, oy + u(26), crest, crest, N.Clr.gold)) then
               N.Icon("shield", hx + u(6), oy + u(32), u(40), N.Clr.gold)
          end

          local tx = hx + crest + u(22)
          N.Eyebrow("SHINE  ·  PANEL DE ADMINISTRACIÓN", tx, oy + u(28), N.Clr.gold)

          local page = ShineAdmin.Pages[s.Page or ""]
          N.TextSpaced(page and string.utf8upper(page.label) or "SHINE ADMIN", "display", tx, oy + u(46), N.Clr.text, u(2))

          -- sağ üst :: yetkili bilgisi
          local ply = LocalPlayer()

          if (IsValid(ply)) then
               local rx = ox + fw - u(96)

               N.Text(ply:Nick(), "serifitalic", rx, oy + u(30), N.Clr.text, TEXT_ALIGN_RIGHT)
               N.TextSpaced(string.utf8upper(ply:GetUserGroup() or "user") .. "  ·  " .. StaffOnline() .. " STAFF EN LÍNEA",
                    "micro", rx, oy + u(58), N.Clr.gold, u(2), TEXT_ALIGN_RIGHT)
               N.SplitRule(rx - u(190), oy + u(78), u(190), math.Clamp(#player.GetAll() / math.max(1, game.MaxPlayers()), 0, 1), N.Clr.gold, N.Clr.headLine)
          end

          -- kenar çubuğu ayırıcısı
          N.Box(ox + u(SIDE_W), oy + u(HEAD_H) + 1, 1, u(BODY_H) - 1, N.Clr.headLine)

          -- alt şerit
          local fy = oy + fh - u(FOOT_H)
          N.Box(ox + 1, fy, fw - 2, 1, N.Clr.headLine)

          local kx, ky = ox + u(26), fy + u(13)
          kx = kx + N.Keycap("ESC", kx, ky, u(17)) + u(8)
          N.Text("Cerrar", "tiny", kx, ky + u(4), N.Clr.faint)

          N.TextSpaced("SHINE  /  ADMIN", "micro", ox + fw - u(26), fy + u(18), N.Clr.faint, u(2), TEXT_ALIGN_RIGHT)

          if (s.FlashUntil and s.FlashUntil > RealTime()) then
               N.Text(s.FlashText, "tiny", ox + fw / 2, fy + u(18), s.FlashKind == "bad" and N.Clr.bad or N.Clr.gold, TEXT_ALIGN_CENTER)
          end
     end

     -- kapatma
     local close = vgui.Create("DButton", frame)
     close:SetPos(ox + fw - u(44), oy + u(16))
     close:SetSize(u(28), u(28))
     close:SetText("")
     close:SetTooltip("Cerrar  (ESC)")
     close.Paint = function(s, w, h)
          local hov = s:IsHovered()

          if (!N.Icon("close", u(6), u(6), u(16), hov and N.Clr.bad or N.Clr.muted)) then
               N.Text("X", "small", w / 2, h / 2, hov and N.Clr.bad or N.Clr.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     end
     close.DoClick = function() frame:Close() end

     --[[
     *   kenar çubuğu :: gruplanmış sayfalar
     ]]

     local side = N.Scroll(frame, ox + 1, oy + u(HEAD_H) + 1, u(SIDE_W) - 1, u(BODY_H) - 1)
     side.Paint = function(s, w, h)
          N.Box(0, 0, w, h, Color(13, 20, 32, 120))
     end

     local navY = u(18)

     for _, entry in ipairs(ShineAdmin:VisiblePages()) do
          local label = side:Add("DPanel")
          label:SetPos(0, navY)
          label:SetSize(u(SIDE_W) - 1, u(26))
          label.Paint = function(s, w, h)
               N.Eyebrow(entry.group.label, u(20), u(8), N.Clr.goldSoft)
          end
          navY = navY + u(28)

          for _, page in ipairs(entry.pages) do
               local b = side:Add("DButton")
               b:SetPos(u(14), navY)
               b:SetSize(u(SIDE_W - 34), u(38))
               b:SetText("")
               b:SetTooltip(page.subtitle or page.label)
               b.OnCursorEntered = function() N.SndHover() end
               b.Paint = function(s, w, h)
                    local on = frame.Page == page.id

                    if (on) then
                         N.Box(0, 0, w, h, Color(201, 174, 119, 14))
                         N.Outline(0, 0, w, h, N.Clr.btnLine, 1)
                         N.Box(0, 0, u(2), h, N.Clr.gold)
                    elseif (s:IsHovered()) then
                         N.Box(0, 0, w, h, N.Clr.hoverRow)
                    end

                    if (!N.Icon(page.icon or "settings", u(12), (h - u(16)) / 2, u(16), on and N.Clr.gold or N.Clr.muted)) then
                         N.Box(u(14), (h - u(6)) / 2, u(6), u(6), on and N.Clr.gold or N.Clr.muted)
                    end

                    N.Text(N.Clip(page.label, "body", w - u(60)), "body", u(38), h / 2,
                         on and N.Clr.text or N.Clr.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                    if (on) then
                         N.Box(w - u(14), h / 2 - u(1), u(3), u(3), N.Clr.gold)
                    end
               end
               b.DoClick = function()
                    N.SndClick()
                    frame:SwitchPage(page.id)
               end

               navY = navY + u(42)
          end

          navY = navY + u(10)
     end

     --[[
     *   içerik alanı
     ]]

     local caX = ox + u(SIDE_W) + 1
     local caY = oy + u(HEAD_H) + 1

     local head = vgui.Create("DPanel", frame)
     head:SetPos(caX, caY)
     head:SetSize(u(CA_W) - 1, u(PHEAD_H))
     head.Cfg = {}
     head.Paint = function(s, w, h)
          local c = s.Cfg

          N.Box(0, h - 1, w, 1, N.Clr.headLine)
          N.Eyebrow(c.eyebrow or "SHINE · ADMINISTRACIÓN", u(PAD), u(26), N.Clr.gold)

          if (c.title) then
               N.Text(N.Clip(c.title, "title", w - u(PAD) * 2 - u(320)), "title", u(PAD), u(40))
          end

          if (c.subtitle) then
               N.Text(N.Clip(c.subtitle, "small", w - u(PAD) * 2 - u(320)), "small", u(PAD) + u(2), u(74), N.Clr.muted)
          end

          local rx = w - u(PAD)

          if (c.badge) then
               local bw = N.SpacedWidth(c.badge, "micro", u(2))
               local bx = rx - bw
               N.Icon(c.badgeIcon or "shield", bx - u(19), u(45), u(13), N.Clr.gold)
               N.TextSpaced(c.badge, "micro", bx, u(47), N.Clr.gold, u(2))
               rx = bx - u(34)
          end

          if (c.count) then
               local cnt = tostring(isfunction(c.count) and c.count() or c.count)
               N.Text(cnt, "count", rx, u(34), N.Clr.gold, TEXT_ALIGN_RIGHT)
               rx = rx - N.TextW(cnt, "count") - u(16)
          end

          if (c.note) then
               local note = isfunction(c.note) and c.note() or c.note

               if (note and note != "") then
                    N.TextSpaced(note, "micro", rx, u(47), N.Clr.demoText, u(1), TEXT_ALIGN_RIGHT)
               end
          end
     end

     local content = vgui.Create("DPanel", frame)
     content:SetPos(caX + u(PAD), caY + u(PHEAD_H) + u(20))
     content.Paint = function() end

     local railHolder = vgui.Create("DPanel", frame)
     railHolder:SetPos(caX + u(CA_W - RAIL_W) - 1, caY + u(PHEAD_H))
     railHolder:SetSize(u(RAIL_W), u(BODY_H - PHEAD_H) - 1)
     railHolder.Paint = function() end

     function frame:Flash(text, kind)
          self.FlashText = text
          self.FlashKind = kind or "info"
          self.FlashUntil = RealTime() + 6
     end

     -- arg: sayfaya dışarıdan verilen başlangıç verisi (ör. yönlendirilen ağ mesajı)
     function frame:SwitchPage(id, arg, bForce)
          local page = ShineAdmin.Pages[id]
          if (!page or !ShineAdmin:CanSee(id)) then return end
          if (self.Page == id and !bForce) then return end

          if (self.Ctx and self.Ctx.OnLeave) then
               self.Ctx.OnLeave()
          end

          content:Clear()
          railHolder:Clear()

          self.Page = id

          local useRail = page.rail and true or false
          local mainW = useRail and (CA_W - RAIL_W - PAD * 2) or (CA_W - PAD * 2)
          local mainH = BODY_H - PHEAD_H - 30

          content:SetSize(u(mainW), u(mainH))
          railHolder:SetVisible(useRail)

          head.Cfg = {
               eyebrow = "SHINE · " .. string.utf8upper(page.groupLabel or "ADMINISTRACIÓN"),
               title = page.title or page.label,
               subtitle = page.subtitle
          }

          local ctx = {
               menu = self,
               page = page,
               arg = arg,
               panel = content,
               head = head,
               w = mainW,
               h = mainH,
               rail = useRail and railHolder or nil,
               railW = RAIL_W
          }

          function ctx.SetHead(t)
               for k, v in pairs(t) do head.Cfg[k] = v end
          end

          function ctx.SetRail(cfg)
               if (!useRail) then return end

               railHolder:Clear()
               if (!cfg) then return end

               return N.InfoRail(railHolder, 0, 0, u(RAIL_W), railHolder:GetTall(), cfg)
          end

          function ctx.Flash(text, kind)
               frame:Flash(text, kind)
          end

          self.Ctx = ctx
          self.Refresh = page.build(ctx) or function() end
     end

     -- asa yönetim sayfası bir büyüye tıklanınca asa menüsünde açmak istiyor
     function frame:OpenSpell(name)
          self:Close()

          local win = HpwRewrite.VGUI:OpenNewSpellManager()
          if (IsValid(win) and win.OpenSpell) then win:OpenSpell(name) end
     end

     frame.Close = function(s)
          if (s.Ctx and s.Ctx.OnLeave) then
               s.Ctx.OnLeave()
          end

          if (N.CancelCapture) then N.CancelCapture() end
          s:Remove()
          gui.EnableScreenClicker(false)
     end

     frame.Think = function(s)
          if (ScrW() != s.ScrW or ScrH() != s.ScrH) then
               local page = s.Page
               s:Close()
               timer.Simple(0, function() ShineAdmin:Open(page) end)
               return
          end

          local esc = input.IsKeyDown(KEY_ESCAPE)

          if (esc and !s.EscDown) then
               s:Close()
               if (gui.IsGameUIVisible()) then gui.HideGameUI() end
               return
          end

          s.EscDown = esc

          -- asa sayfaları: sunucudan büyü verisi güncellenince yenile (asa menüsüyle aynı)
          local page = ShineAdmin.Pages[s.Page or ""]

          if (page and page.wand and HpwRewrite and HpwRewrite.VGUI and HpwRewrite.VGUI.ShouldUpdate) then
               HpwRewrite.VGUI.ShouldUpdate = false
               s.RefreshAt = RealTime() + 0.25
          end

          if (s.RefreshAt and RealTime() >= s.RefreshAt) then
               s.RefreshAt = nil
               if (s.Refresh) then s.Refresh() end
          end
     end

     return frame
end

function ShineAdmin:FirstPage()
     local visible = self:VisiblePages()
     return visible[1] and visible[1].pages[1].id or nil
end

function ShineAdmin:Open(id, arg)
     if (!self.GetN()) then
          chat.AddText(Color(191, 96, 88), "[Shine Admin] ", color_white, "La interfaz del menú de varita (Nocturne) no está cargada; no se puede abrir el panel.")
          return
     end

     self:InstallRoutes()

     -- grup etiketlerini sayfalara işle (başlık üst satırı için)
     for _, group in ipairs(self.Groups) do
          for _, page in pairs(self.Pages) do
               if ((page.group or "tools") == group.id) then page.groupLabel = group.label end
          end
     end

     local target = (id and self:CanSee(id)) and id or nil

     if (!IsValid(self.Window)) then
          target = target or self:FirstPage()

          if (!target) then
               chat.AddText(Color(191, 96, 88), "[Shine Admin] ", color_white, "No hay ninguna página de administración visible para ti.")
               return
          end

          self.Window = BuildWindow()
     end

     if (target) then
          self.Window:SwitchPage(target, arg, arg != nil)
     end

     return self.Window
end

function ShineAdmin:Close()
     if (IsValid(self.Window)) then self.Window:Close() end
end

-- Sayfa açıksa ve bu sayfaysa bağlamını döndürür (yönlendirilen veriler için)
function ShineAdmin:ActiveCtx(id)
     local win = self.Window
     if (IsValid(win) and win.Page == id and win.Ctx) then return win.Ctx end
end

concommand.Add("shine_admin", function(_, _, args)
     ShineAdmin:Open(args[1])
end, nil, "Abre el panel Shine Admin (opcional: id de página)")

--[[
*   ------------------------------------------------------------------
*   sayfalar için ortak parçalar
*   ------------------------------------------------------------------
]]

-- Arama kutulu oyuncu listesi. getSel() seçili oyuncu, onPick(ply) seçim.
function ShineAdmin.PlayerList(parent, x, y, w, h, getSel, onPick)
     local N = ShineAdmin.GetN()
     local u = N.u
     local search = ""

     local list

     local function refresh()
          local out = {}

          for _, p in ipairs(player.GetHumans()) do
               if (search == "" or string.find(string.lower(p:Nick()), search, 1, true) or string.find(string.lower(p:SteamID()), search, 1, true)) then
                    out[#out + 1] = p
               end
          end

          table.sort(out, function(a, b) return string.lower(a:Nick()) < string.lower(b:Nick()) end)

          if (IsValid(list)) then list:SetItems(out, true) end
     end

     N.TextEntry(parent, x, y, w, u(36), "Buscar jugador (nombre / SteamID)", function(v)
          search = string.lower(string.Trim(v or ""))
          refresh()
     end)

     list = N.VList(parent, x, y + u(46), w, h - u(46), {
          rowH = u(58),
          gapY = u(8),
          emptyText = "No se encontró ningún jugador.",
          tooltip = function(p) return IsValid(p) and (p:Nick() .. " · " .. p:SteamID()) or "" end,
          onClick = function(p)
               if (IsValid(p)) then onPick(p) end
          end,
          paintRow = function(p, i, rx, ry, rw, rh, hovered)
               if (!IsValid(p)) then return end

               local on = getSel() == p

               N.Box(rx, ry, rw, rh, on and Color(201, 174, 119, 16) or N.Clr.toolBg)
               N.Outline(rx, ry, rw, rh, on and N.Clr.gold or (hovered and N.Clr.btnLine or Color(125, 148, 160, 43)), 1)

               local av = u(34)
               N.AvatarTile(rx + u(12), ry + (rh - av) / 2, av, string.sub(p:Nick(), 1, 1), on)

               local tx = rx + u(12) + av + u(12)
               N.Text(N.Clip(p:Nick(), "serifsm", rw - (tx - rx) - u(12)), "serifsm", tx, ry + u(12))
               N.Text(N.Clip(p:SteamID() .. "  ·  " .. (p:GetUserGroup() or "user"), "tiny", rw - (tx - rx) - u(12)), "tiny", tx, ry + u(36), N.Clr.rowDesc)
          end
     })

     refresh()

     -- oyuncu girip çıkınca listeyi güncel tut
     list.NextRefresh = 0
     local think = list.Think
     list.Think = function(s)
          think(s)

          if (RealTime() >= s.NextRefresh) then
               s.NextRefresh = RealTime() + 2
               refresh()
          end
     end

     return list
end

-- Seçim yapılmamışken sağ alanda gösterilen yer tutucu
function ShineAdmin.Placeholder(parent, x, y, w, h, text)
     local N = ShineAdmin.GetN()
     local u = N.u

     local p = vgui.Create("DPanel", parent)
     p:SetPos(x, y)
     p:SetSize(w, h)
     p.Paint = function(s, pw, ph)
          N.Box(0, 0, pw, ph, N.Clr.toolBg)
          N.Outline(0, 0, pw, ph, N.Clr.toolLine, 1)
          N.Tex("ornaments/astrolabe", pw / 2 - u(70), ph / 2 - u(90), u(140), u(140), Color(201, 174, 119, 16))
          N.Text(text, "serif", pw / 2, ph / 2 + u(64), N.Clr.emptyText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     return p
end

-- Kendi penceresini açan araçlar için sayfa: açıklama + adımlar + "Aç" düğmesi
function ShineAdmin.LauncherPage(def)
     def.rail = true

     def.build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel

          local info = vgui.Create("DPanel", P)
          info:SetPos(0, 0)
          info:SetSize(u(ctx.w), u(ctx.h))
          info.Paint = function(s, w, h)
               N.SectionLabel("Qué hace esta herramienta", 0, 0, w, "info")

               local lines = N.Wrap(def.description or "", "body", w - u(10))
               for i = 1, #lines do
                    N.Text(lines[i], "body", 0, u(28) + (i - 1) * u(21), N.Clr.infoText)
               end

               local sy = u(40) + #lines * u(21) + u(20)

               if (def.steps) then
                    N.SectionLabel("Uso", 0, sy, w, "book")
                    sy = sy + u(30)

                    for i, step in ipairs(def.steps) do
                         sy = sy + N.Step(0, sy, w, i, step[1], step[2], false)
                    end
               end
          end

          ctx.SetRail({
               hero = "icons/" .. (def.icon or "settings"),
               badge = {text = def.badge or "Ventana aparte", icon = "info"},
               title = def.label,
               body = def.railBody or "Esta herramienta se abre en su propia ventana. Shine Admin se cierra; cuando termines, vuelve con: /ShineAdmin",
               props = def.props,
               note = def.note,
               button = {
                    label = def.buttonLabel or "Abrir herramienta",
                    style = "primary",
                    fn = function()
                         ShineAdmin:Close()
                         timer.Simple(0, def.launch)
                    end
               }
          })
     end

     return def
end

--[[
*   genel bakış
]]

ShineAdmin:RegisterPage("overview", {
     label = "Vista general",
     icon = "star",
     group = "home",
     order = 1,
     title = "Vista general",
     subtitle = "Todas las páginas de administración a tu alcance, en un solo sitio.",
     access = function(ply) return ShineAdmin.CanOpen(ply) end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel

          local cards = {}

          for _, entry in ipairs(ShineAdmin:VisiblePages()) do
               for _, page in ipairs(entry.pages) do
                    if (page.id != "overview") then
                         cards[#cards + 1] = {page = page, group = entry.group.label}
                    end
               end
          end

          ctx.SetHead({count = #cards, note = "PÁGINAS"})

          local stats = vgui.Create("DPanel", P)
          stats:SetPos(0, 0)
          stats:SetSize(u(ctx.w), u(84))
          stats.Paint = function(s, w, h)
               local items = {
                    {"Jugadores en línea", #player.GetHumans() .. " / " .. game.MaxPlayers()},
                    {"Staff en línea", StaffOnline()},
                    {"Páginas accesibles", #cards},
                    {"Mapa", game.GetMap()}
               }

               local cw = (w - u(12) * 3) / 4

               for i, it in ipairs(items) do
                    local x = (i - 1) * (cw + u(12))
                    N.Box(x, 0, cw, h - u(8), N.Clr.toolBg)
                    N.Outline(x, 0, cw, h - u(8), N.Clr.toolLine, 1)
                    N.Box(x, u(12), u(2), h - u(32), N.Clr.gold)
                    N.TextSpaced(string.utf8upper(it[1]), "micro", x + u(16), u(14), N.Clr.thText, u(2))
                    N.Text(N.Clip(tostring(it[2]), "count", cw - u(28)), "count", x + u(16), u(32), N.Clr.bigStat)
               end
          end

          N.SectionLabel("Páginas", 0, u(98), u(ctx.w), "sliders")

          local grid = N.VList(P, 0, u(124), u(ctx.w), u(ctx.h - 124), {
               rowH = u(78),
               cols = 3,
               gapX = u(12),
               gapY = u(12),
               onClick = function(card)
                    ctx.menu:SwitchPage(card.page.id)
               end,
               paintRow = function(card, i, x, y, w, h, hovered)
                    local page = card.page

                    N.Box(x, y, w, h, hovered and N.Clr.cardHover or N.Clr.cardBg)
                    N.Outline(x, y, w, h, hovered and N.Clr.gold or N.Clr.cardLine, 1)

                    N.Icon(page.icon or "settings", x + u(16), y + u(16), u(20), hovered and N.Clr.gold or N.Clr.goldSoft)
                    N.Text(N.Clip(page.label, "serif", w - u(70)), "serif", x + u(48), y + u(14))
                    N.TextSpaced(string.utf8upper(card.group), "micro", x + w - u(14), y + u(18), N.Clr.faint, u(2), TEXT_ALIGN_RIGHT)
                    N.Text(N.Clip(page.subtitle or "", "tiny", w - u(32)), "tiny", x + u(16), y + u(50), N.Clr.rowDesc)
               end
          })

          grid:SetItems(cards)
     end
})
