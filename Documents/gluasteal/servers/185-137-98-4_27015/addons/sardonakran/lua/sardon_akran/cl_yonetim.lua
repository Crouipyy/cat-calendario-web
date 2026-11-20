-- "addons\\sardonakran\\lua\\sardon_akran\\cl_yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Akran Yardımı :: Shine Admin sayfası "akran" (yalnızca süper admin)
--
--   Ayarlar        :: seviye eşikleri, okuma süresi, rün eşiği, ödüller, sınırlar (Kaydet ile herkese)
--   Raflar         :: kütüphane rafları (kat + numara); yerleştirme modu ile dünyada eklenir/taşınır
--   Talim Alanları :: ad + şekil (daire: yarıçap · dikdörtgen: en/boy, yön = baktığın yön); yerleştirme
--                     modu ile durduğun yere eklenir
--   Büyüler        :: Temel büyüler, rün önizlemesi, burada kapatma, kendine test görevi
--   Görevler       :: süren görevler (cancelada / aşamayı ilerlet / ışınlan) + son kayıtlar
--
-- Yerleştirme modu: pencere kapanır, bakılan yerde plaka (ya da ayağının altında halka) önizlenir.
--   sol tık ekle · tekerlek raf no · ok tuşları alan ölçüsü (daire: yarıçap · dikdörtgen: ← → en, ↑ ↓ boy, PgUp / PgDn ikisi birden) · R kat · sağ tık çık (sayfa yeniden açılır)

-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_R_140_200_255_120 = Color(140, 200, 255, 120)
local OPT_R_200_230_255 = Color(200, 230, 255)
local OPT_R_160_200_240 = Color(160, 200, 240)
local OPT_V_0_0_3 = Vector(0, 0, 3)
local OPT_R_200_230_255_120 = Color(200, 230, 255, 120)
local OPT_V_0_0_1 = Vector(0, 0, 1)
local OPT_R_140_200_255_160 = Color(140, 200, 255, 160)
local SA = SardonAkran

SA.YonetimVeri = SA.YonetimVeri or {gorevler = {}, log = {}}

local function Istek(islem, yaz)
     net.Start("SardonAkran.Yonetim")
          net.WriteString(islem)
          if (yaz) then yaz() end
     net.SendToServer()
end
SA.YonetimIstek = Istek

net.Receive("SardonAkran.YonetimVeri", function()
     SA.YonetimVeri = net.ReadTable()
     local ctx = ShineAdmin and ShineAdmin.ActiveCtx and ShineAdmin:ActiveCtx("akran")
     if (ctx and ctx.GorevYenile) then ctx.GorevYenile() end
end)

local function Esit(a, b)
     if (type(a) != type(b)) then return false end
     if (!istable(a)) then return a == b end
     for k, v in pairs(a) do if (!Esit(v, b[k])) then return false end end
     for k in pairs(b) do if (a[k] == nil) then return false end end
     return true
end

/*
*   yerleştirme modu
*/

SA.Yerlestir = nil

local function SonrakiNo(kat)
     local en = 0
     for _, r in ipairs(SA.HaritaVeri.raflar) do
          if (r.kat == kat) then en = math.max(en, r.no) end
     end
     return en + 1
end

function SA.YerlestirmeBaslat(t)
     SA.Yerlestir = t
     t.basili = true -- pencereyi kapatan tık sayılmasın
     if (ShineAdmin and ShineAdmin.Close) then ShineAdmin:Close() end
end

local function YerlestirmeBitir()
     SA.Yerlestir = nil
     timer.Simple(0.1, function()
          if (ShineAdmin and ShineAdmin.Open) then ShineAdmin:Open("akran", {sekme = SA.SonSekme}) end
     end)
end

-- sunucudaki AlanSekilOku'nun karşılığı: t.dik ise en/boy, değilse r
function SA.AlanSekilYaz(t)
     net.WriteBool(t.dik and true or false)
     if (t.dik) then
          net.WriteUInt(t.en, 12)
          net.WriteUInt(t.boy, 12)
     else
          net.WriteUInt(t.r, 12)
     end
end

local function Bakis()
     local ply = LocalPlayer()
     return util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 400, filter = ply})
end

hook.Add("CreateMove", "SardonAkran.Yerlestir", function(cmd)
     if (!SA.Yerlestir) then return end
     cmd:RemoveKey(IN_ATTACK)
     cmd:RemoveKey(IN_ATTACK2)
     cmd:RemoveKey(IN_RELOAD)
end)

-- alan ölçüsü ok tuşlarıyla ayarlanır (basılı tutunca hızlanarak tekrarlar)
-- PgUp / PgDn en ve boyu birlikte büyütür / küçültür
local OK_TUSLARI = {[KEY_UP] = true, [KEY_DOWN] = true, [KEY_LEFT] = true, [KEY_RIGHT] = true, [KEY_PAGEUP] = true, [KEY_PAGEDOWN] = true}

local function AlanOlcuAyarla(t)
     local dikey = (input.IsKeyDown(KEY_UP) and 1 or 0) - (input.IsKeyDown(KEY_DOWN) and 1 or 0)
     local yatay = (input.IsKeyDown(KEY_RIGHT) and 1 or 0) - (input.IsKeyDown(KEY_LEFT) and 1 or 0)
     local ikisi = (input.IsKeyDown(KEY_PAGEUP) and 1 or 0) - (input.IsKeyDown(KEY_PAGEDOWN) and 1 or 0)
     dikey, yatay = math.Clamp(dikey + ikisi, -1, 1), math.Clamp(yatay + ikisi, -1, 1)
     if (dikey == 0 and yatay == 0) then t.okSonra = nil return end

     local now = RealTime()
     if (t.okSonra and now < t.okSonra) then return end
     t.okSonra = now + (t.okSonra and 0.07 or 0.35)

     if (t.dik) then
          t.boy = math.Clamp(t.boy + dikey * 25, 50, 3000)
          t.en = math.Clamp(t.en + yatay * 25, 50, 3000)
     else
          t.r = math.Clamp(t.r + (dikey != 0 and dikey or yatay) * 25, 50, 2000)
     end
     surface.PlaySound("buttons/lightswitch2.wav")
end

hook.Add("PlayerBindPress", "SardonAkran.Yerlestir", function(_, bind, basildi, tus)
     local t = SA.Yerlestir
     if (!t or !basildi) then return end
     -- ok tuşları ölçü ayarlarken yürütmesin / döndürmesin
     if (t.tip == "alan" and OK_TUSLARI[tus]) then return true end
     local yukari = string.find(bind, "invprev", 1, true)
     local asagi = string.find(bind, "invnext", 1, true)
     if (yukari or asagi) then
          local d = yukari and 1 or -1
          if (t.tip == "raf") then
               t.no = math.Clamp(t.no + d, 1, 999)
               surface.PlaySound("buttons/lightswitch2.wav")
               return true
          end
          return
     end
     if (string.find(bind, "+reload", 1, true) and t.tip == "raf") then
          t.kat = t.kat % 6 + 1
          t.no = SonrakiNo(t.kat)
          surface.PlaySound("buttons/lightswitch2.wav")
          return true
     end
end)

hook.Add("Think", "SardonAkran.Yerlestir", function()
     local t = SA.Yerlestir
     if (!t) then return end
     if (vgui.CursorVisible()) then return end
     if (t.tip == "alan") then AlanOlcuAyarla(t) end

     local sol, sag = input.IsMouseDown(MOUSE_LEFT), input.IsMouseDown(MOUSE_RIGHT)
     if (sag) then return YerlestirmeBitir() end

     if (sol and !t.basili) then
          t.basili = true
          if (t.tip == "raf") then
               if (!Bakis().Hit) then return surface.PlaySound("buttons/button10.wav") end
               Istek("rafEkle", function()
                    net.WriteUInt(t.kat, 4)
                    net.WriteUInt(t.no, 12)
               end)
               t.no = math.min(999, t.no + 1)
          elseif (t.tip == "rafTasi") then
               Istek("rafTasi", function() net.WriteUInt(t.id, 16) end)
               return YerlestirmeBitir()
          elseif (t.tip == "alan") then
               Istek("alanEkle", function()
                    net.WriteString(t.ad or "")
                    SA.AlanSekilYaz(t)
               end)
               return YerlestirmeBitir()
          elseif (t.tip == "alanTasi") then
               Istek("alanTasi", function() net.WriteUInt(t.id, 16) end)
               return YerlestirmeBitir()
          end
          surface.PlaySound("buttons/blip1.wav")
     elseif (!sol) then
          t.basili = false
     end
end)

hook.Add("PostDrawTranslucentRenderables", "SardonAkran.Yerlestir", function(_, gokyuzu)
     local t = SA.Yerlestir
     if (!t or gokyuzu) then return end
     SA.Fontlar()
     local ply = LocalPlayer()

     if (t.tip == "raf" or t.tip == "rafTasi") then
          local tr = Bakis()
          if (!tr.Hit) then return end
          local ang = tr.HitNormal:Angle()
          ang:RotateAroundAxis(ang:Up(), 90)
          ang:RotateAroundAxis(ang:Forward(), 90)
          render.SetMaterial(SA.M3.isik)
          render.DrawSprite(tr.HitPos + tr.HitNormal * 2, 30, 30, OPT_R_140_200_255_120)
          cam.Start3D2D(tr.HitPos + tr.HitNormal * 1.6, ang, 0.05)
               surface.SetDrawColor(18, 24, 34, 220)
               surface.DrawRect(-115, -56, 230, 112)
               surface.SetDrawColor(140, 200, 255, 255)
               surface.DrawOutlinedRect(-115, -56, 230, 112, 3)
               local no = t.tip == "raf" and t.no or "#" .. t.id
               draw.SimpleText(no, "sak.plaka", 0, 4, OPT_R_200_230_255, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               if (t.tip == "raf") then draw.SimpleText((SA.Roma[t.kat] or t.kat) .. ". PLANTA", "sak.plakaK", 0, -34, OPT_R_160_200_240, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
          cam.End3D2D()
     else
          local p = ply:GetPos() + OPT_V_0_0_3
          if (t.dik) then
               -- yön = bakış yönü; boy ekseni ileri doğru uzanır
               local yaw = math.Round(ply:EyeAngles().y)
               SA.DikdortgenCiz(p, t.en, t.boy, yaw, 1, Color(140, 200, 255), true)
               render.SetMaterial(SA.M3.isin)
               render.DrawBeam(p, p + Angle(0, yaw, 0):Forward() * (t.boy / 2), 4, 0, 1, OPT_R_200_230_255_120)
          else
               render.SetMaterial(SA.M3.halka)
               local r = t.r or 200
               render.DrawQuadEasy(p, OPT_V_0_0_1, r * 2, r * 2, OPT_R_140_200_255_160, RealTime() * 10 % 360)
          end
     end
end)

hook.Add("HUDPaint", "SardonAkran.Yerlestir", function()
     local t = SA.Yerlestir
     if (!t) then return end
     SA.Fontlar()
     local satir
     if (t.tip == "raf") then
          satir = "AÑADIR ESTANTE  ·  " .. (SA.Roma[t.kat] or t.kat) .. ". planta · nº " .. t.no .. "     clic izq.: añadir   rueda: nº ±1   R: planta   clic der.: terminar"
     elseif (t.tip == "rafTasi") then
          satir = "RAF #" .. t.id .. " MOVER     mira estante, clic izq.: mover aquí   clic der.: cancelar"
     elseif (t.tip == "alan" and t.dik) then
          satir = "AÑADIR ZONA RECTANGULAR  ·  an " .. t.en .. " · largo " .. t.boy .. "     clic izq.: añadir donde estás (dirección = mirada)   ← →: ancho   ↑ ↓: largo   PgUp/PgDn: ambos   clic der.: cancelar"
     elseif (t.tip == "alan") then
          satir = "AÑADIR ZONA DE PRÁCTICA  ·  radio " .. t.r .. "     clic izq.: añadir donde estás   ↑ ↓: radio   clic der.: cancelar"
     elseif (t.dik) then
          satir = "MOVER ZONA #" .. t.id .. "     clic izq.: mover donde estás (dirección = mirada)   clic der.: cancelar"
     else
          satir = "MOVER ZONA #" .. t.id .. "     clic izq.: mover donde estás   clic der.: cancelar"
     end
     local w = SA.MetinG(satir, "alt") + 60
     SA.Kart(ScrW() / 2 - w / 2, ScrH() - 160, w, 44, 0.95, false)
     SA.Metin(satir, "alt", ScrW() / 2, ScrH() - 138, Color(200, 225, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

/*
*   sayfa
*/

local sayfa = {
     id = "akran",
     label = "Tutoría entre pares",
     icon = "users",
     group = "magic",
     order = 36,
     title = "Tutoría entre pares",
     subtitle = "Estudiantes mayores enseñan hechizos básicos: ajustes, estanterías de biblioteca, zonas de práctica y tareas en curso.",
     access = "superadmin",
     available = function() return SardonAkran != nil and SardonAkran.AyarTemizle != nil end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel
          local W, H = ctx.w, ctx.h

          SA.Fontlar()
          local taslak = table.Copy(SA.Ayar)
          local aktif = ctx.arg and ctx.arg.sekme or SA.SonSekme or "ayar"
          local govde

          local function Degisti() return !Esit(taslak, SA.Ayar) end

          local SEKMELER = {
               {"ayar", "Ajustes"},
               {"raf", "Estantes"},
               {"alan", "Zonas de práctica"},
               {"buyu", "Hechizos"},
               {"gorev", "Tareas"}
          }

          local SekmeKur

          N.SubTabs(P, 0, 0, u(W), SEKMELER, function() return aktif end, function(id)
               if (aktif == id) then return end
               aktif = id
               SA.SonSekme = id
               SekmeKur()
          end)

          local GY = 56
          local GH = H - GY

          local function KaydetSeridi(parent, ph)
               local bar = N.StickyBar(parent, 0, u(ph - 52), u(W), function()
                    if (Degisti()) then return "Hay cambios sin guardar. Al pulsar Guardar se aplican a todos.", N.Clr.warn end
                    return "Los ajustes coinciden con el servidor."
               end)
               local kaydet = N.Button(bar, u(W) - u(150), u(8), u(150), u(36), "Guardar", function()
                    Istek("ayar", function() net.WriteTable(taslak) end)
                    ctx.Flash("Ajustes de tutoría entre pares guardados.")
               end, "primary")
               kaydet.Think = function(s) s:SetEnabled(Degisti()) end
               local geri = N.Button(bar, u(W) - u(150) - u(8) - u(130), u(8), u(130), u(36), "Deshacer", function()
                    taslak = table.Copy(SA.Ayar)
                    SekmeKur()
               end)
               geri.Think = function(s) s:SetEnabled(Degisti()) end
               return bar
          end

          local function Bilgi(parent, x, y, w, metin)
               local p = vgui.Create("DPanel", parent)
               p:SetPos(x, y)
               p:SetSize(w, u(96))
               p.Paint = function(s, pw, ph)
                    local satirlar = N.Wrap and N.Wrap(metin, "tiny", pw) or {metin}
                    for i, satir in ipairs(satirlar) do
                         N.Text(satir, "tiny", 0, (i - 1) * u(15), N.Clr.rowDesc)
                    end
               end
               return p
          end

          /*
          *   ayarlar
          */

          local function AyarKur(G, gh)
               local cols = 3
               local colW = math.floor((W - (cols - 1) * 10) / cols)
               for i, a in ipairs(SA.AyarAlanlari) do
                    local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
                    N.Slider(G, u(c * (colW + 10)), u(r * 64), u(colW), a[2], a[3], a[4], 0,
                         function() return taslak[a[1]] end,
                         function(v) taslak[a[1]] = math.floor(v) end)
               end
               local satir = math.ceil(#SA.AyarAlanlari / cols)
               Bilgi(G, 0, u(satir * 64 + 10), u(W), "Profesor = personaje con umbral mínimo de año escolar, alumno = umbral máximo (cada 5 niveles = 1 año). Los Puntos de Hechizo se suman al árbol. Umbral de runa: trazo cuidado ~85 %, tembloroso ~60 %, garabato ~0 %; 72 % por defecto.")
               KaydetSeridi(G, gh)
          end

          /*
          *   raflar
          */

          local function RafKur(G, gh)
               local LIST_W = W - 360
               local secili
               local liste, detay
               local kat, no = 1, SonrakiNo(1)

               local function Satirlar()
                    local out = {}
                    local goz = LocalPlayer():EyePos()
                    for _, r in ipairs(SA.HaritaVeri.raflar) do out[#out + 1] = {r = r, d = goz:Distance(r.pos)} end
                    table.sort(out, function(a, b)
                         if (a.r.kat != b.r.kat) then return a.r.kat < b.r.kat end
                         return a.r.no < b.r.no
                    end)
                    return out
               end

               local head = vgui.Create("DPanel", G)
               head:SetPos(0, 0)
               head:SetSize(u(LIST_W), u(30))
               head.Paint = function(s, w, h)
                    N.TableHead(0, 0, w, {
                         {"Kat", u(16)},
                         {"Raf no", u(110)},
                         {"Kimlik", u(220)},
                         {"Distancia", w - u(24), TEXT_ALIGN_RIGHT}
                    })
               end

               liste = N.VList(G, 0, u(30), u(LIST_W), u(gh - 30), {
                    rowH = u(34),
                    gapY = 0,
                    emptyText = "Aún no hay estantes. Inicia el modo de colocación a la derecha.",
                    onClick = function(r)
                         secili = r.r.id
                         kat, no = r.r.kat, r.r.no
                         if (IsValid(detay)) then detay.Kur() end
                    end,
                    paintRow = function(r, i, x, y, w, h, hovered)
                         local on = secili == r.r.id
                         if (on) then
                              N.Box(x, y, w, h, N.Clr.selRow)
                              N.Box(x, y, u(2), h, N.Clr.gold)
                         elseif (hovered) then
                              N.Box(x, y, w, h, N.Clr.hoverRow)
                         end
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
                         N.Text((SA.Roma[r.r.kat] or r.r.kat) .. ". kat", "row", x + u(16), y + h / 2, N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(tostring(r.r.no), "strong", x + u(110), y + h / 2, N.Clr.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text("#" .. r.r.id, "small", x + u(220), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(math.floor(r.d * 0.019) .. " m", "small", x + w - u(24), y + h / 2, N.Clr.tdText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               })

               detay = vgui.Create("DPanel", G)
               detay:SetPos(u(LIST_W + 20), 0)
               detay:SetSize(u(340), u(gh))
               detay.Paint = function() end

               function detay.Kur()
                    detay:Clear()
                    local y = 0

                    N.Slider(detay, 0, y, u(340), "Kat", 1, 6, 0, function() return kat end, function(v) kat = math.floor(v) end)
                    y = y + 62
                    N.Slider(detay, 0, u(y), u(340), "Número de estante", 1, 300, 0, function() return no end, function(v) no = math.floor(v) end)
                    y = y + 66

                    N.Button(detay, 0, u(y), u(340), u(38), "Iniciar colocación (mira el estante, clic izq.)", function()
                         SA.YerlestirmeBaslat({tip = "raf", kat = kat, no = secili and SonrakiNo(kat) or no})
                    end, "primary")
                    y = y + 48

                    N.Toggle(detay, 0, u(y), u(340), u(52), "Mostrar todos los estantes y zonas en el mundo",
                         function() return GetConVar("sardon_akran_goster"):GetBool() end,
                         function(v) RunConsoleCommand("sardon_akran_goster", v and "1" or "0") end,
                         "Placas y zonas visibles hasta 3000 unidades, con id.")
                    y = y + 64

                    local r = secili and SA.RafBul(secili)
                    if (r) then
                         N.Button(detay, 0, u(y), u(165), u(34), "Teletransportarse", function()
                              Istek("git", function() net.WriteString("raf") net.WriteUInt(r.id, 16) end)
                         end)
                         N.Button(detay, u(175), u(y), u(165), u(34), "Guardar planta / nº", function()
                              Istek("rafDuzenle", function() net.WriteUInt(r.id, 16) net.WriteUInt(kat, 4) net.WriteUInt(no, 12) end)
                              ctx.Flash("Estante #" .. r.id .. " actualizado.")
                         end)
                         y = y + 42
                         N.Button(detay, 0, u(y), u(165), u(34), "Mover donde estoy", function()
                              SA.YerlestirmeBaslat({tip = "rafTasi", id = r.id})
                         end)
                         N.Button(detay, u(175), u(y), u(165), u(34), "Borrar", function()
                              N.Confirm("Borrar estante", "Estante #" .. r.id .. " se borrará. Los alumnos que lo busquen podrán leer en cualquier sitio.", "Borrar", function()
                                   Istek("rafSil", function() net.WriteUInt(r.id, 16) end)
                                   secili = nil
                              end, true)
                         end, "quiet")
                         y = y + 44
                    end

                    Bilgi(detay, 0, u(y + 6), u(340), "El modo cierra el panel: mira el estante, clic izq.; el número sube solo. Rueda cambia nº, R cambia planta. Clic der. termina.")
               end

               liste:SetItems(Satirlar())
               detay.Kur()

               hook.Add("SardonAkranHarita", liste, function()
                    if (IsValid(liste)) then liste:SetItems(Satirlar(), true) end
                    if (IsValid(detay)) then detay.Kur() end
               end)
          end

          /*
          *   talim alanları
          */

          local function AlanKur(G, gh)
               local LIST_W = W - 360
               local secili
               local liste, detay
               local ad, yaricap = "", 220
               local dik, en, boy = false, 400, 600

               local head = vgui.Create("DPanel", G)
               head:SetPos(0, 0)
               head:SetSize(u(LIST_W), u(30))
               head.Paint = function(s, w, h)
                    N.TableHead(0, 0, w, {
                         {"Ad", u(16)},
                         {"Medida", u(260)},
                         {"Kimlik", u(370)},
                         {"Distancia", w - u(24), TEXT_ALIGN_RIGHT}
                    })
               end

               local function Satirlar()
                    local out = {}
                    for _, a in ipairs(SA.HaritaVeri.alanlar) do out[#out + 1] = {a = a, d = LocalPlayer():GetPos():Distance(a.pos)} end
                    return out
               end

               liste = N.VList(G, 0, u(30), u(LIST_W), u(gh - 30), {
                    rowH = u(34),
                    gapY = 0,
                    emptyText = "Aún no hay zonas. Ve al centro y añade desde la derecha.",
                    onClick = function(r)
                         secili = r.a.id
                         ad = r.a.ad or ""
                         dik = SA.AlanDikdortgenMi(r.a)
                         if (dik) then en, boy = r.a.en, r.a.boy else yaricap = r.a.r end
                         if (IsValid(detay)) then detay.Kur() end
                    end,
                    paintRow = function(r, i, x, y, w, h, hovered)
                         local on = secili == r.a.id
                         if (on) then
                              N.Box(x, y, w, h, N.Clr.selRow)
                              N.Box(x, y, u(2), h, N.Clr.gold)
                         elseif (hovered) then
                              N.Box(x, y, w, h, N.Clr.hoverRow)
                         end
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
                         N.Text(N.Clip(r.a.ad or "?", "row", u(230)), "row", x + u(16), y + h / 2, N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(SA.AlanOlcuYaz(r.a), "strong", x + u(260), y + h / 2, N.Clr.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text("#" .. r.a.id, "small", x + u(370), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(math.floor(r.d * 0.019) .. " m", "small", x + w - u(24), y + h / 2, N.Clr.tdText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               })

               detay = vgui.Create("DPanel", G)
               detay:SetPos(u(LIST_W + 20), 0)
               detay:SetSize(u(340), u(gh))
               detay.Paint = function() end

               function detay.Kur()
                    detay:Clear()
                    local y = 0
                    local giris = N.TextEntry(detay, 0, 0, u(340), u(36), "Nombre de zona (ej. Patio de práctica)", function(v) ad = v end)
                    giris:SetValue(ad)
                    y = y + 46
                    N.Button(detay, 0, u(y), u(165), u(32), "Circular", function() dik = false detay.Kur() end, !dik and "primary" or nil)
                    N.Button(detay, u(175), u(y), u(165), u(32), "Rectangular", function() dik = true detay.Kur() end, dik and "primary" or nil)
                    y = y + 42
                    if (dik) then
                         N.Slider(detay, 0, u(y), u(340), "Ancho (unidades)", 50, 3000, 0, function() return en end, function(v) en = math.floor(v) end)
                         y = y + 64
                         N.Slider(detay, 0, u(y), u(340), "Largo (unidades, dirección de mirada)", 50, 3000, 0, function() return boy end, function(v) boy = math.floor(v) end)
                    else
                         N.Slider(detay, 0, u(y), u(340), "Radio (unidades)", 50, 1500, 0, function() return yaricap end, function(v) yaricap = math.floor(v) end)
                    end
                    y = y + 64

                    N.Button(detay, 0, u(y), u(340), u(38), "Añadir donde estoy", function()
                         SA.YerlestirmeBaslat({tip = "alan", ad = ad, r = yaricap, dik = dik, en = en, boy = boy})
                    end, "primary")
                    y = y + 48

                    local a = secili and SA.AlanBul and SA.AlanBul(secili)
                    if (!a) then
                         for _, x in ipairs(SA.HaritaVeri.alanlar) do if (x.id == secili) then a = x end end
                    end
                    if (a) then
                         N.Button(detay, 0, u(y), u(165), u(34), "Teletransportarse", function()
                              Istek("git", function() net.WriteString("alan") net.WriteUInt(a.id, 16) end)
                         end)
                         N.Button(detay, u(175), u(y), u(165), u(34), "Guardar nombre / forma", function()
                              Istek("alanDuzenle", function()
                                   net.WriteUInt(a.id, 16)
                                   net.WriteString(ad)
                                   SA.AlanSekilYaz({dik = dik, en = en, boy = boy, r = yaricap})
                              end)
                              ctx.Flash("Zona de práctica actualizada.")
                         end)
                         y = y + 42
                         N.Button(detay, 0, u(y), u(165), u(34), "Mover donde estoy", function()
                              SA.YerlestirmeBaslat({tip = "alanTasi", id = a.id, r = a.r, dik = SA.AlanDikdortgenMi(a), en = a.en, boy = a.boy})
                         end)
                         N.Button(detay, u(175), u(y), u(165), u(34), "Borrar", function()
                              N.Confirm("Borrar zona de práctica", (a.ad or "Alan") .. " silinecek.", "Borrar", function()
                                   Istek("alanSil", function() net.WriteUInt(a.id, 16) end)
                                   secili = nil
                              end, true)
                         end, "quiet")
                         y = y + 44
                    end
                    Bilgi(detay, 0, u(y + 6), u(340), "En la práctica el alumno debe estar dentro de la zona y el profesor a la distancia configurada. El círculo es esférico; en plantas, centra cerca del suelo. El rectángulo se alinea a tu mirada al crearlo; cuenta " .. SA.AlanAlt .. " unidades bajo el centro y " .. SA.AlanUst .. " arriba.")
               end

               liste:SetItems(Satirlar())
               detay.Kur()

               hook.Add("SardonAkranHarita", liste, function()
                    if (IsValid(liste)) then liste:SetItems(Satirlar(), true) end
                    if (IsValid(detay)) then detay.Kur() end
               end)
          end

          /*
          *   büyüler
          */

          local function BuyuKur(G, gh)
               local LIST_W = W - 360
               local secili
               local liste, detay
               local BA = SardonBuyuAgaci

               local head = vgui.Create("DPanel", G)
               head:SetPos(0, 0)
               head:SetSize(u(LIST_W), u(30))
               head.Paint = function(s, w, h)
                    N.TableHead(0, 0, w, {
                         {"Hechizo", u(16)},
                         {"Runa", u(260)},
                         {"Estado", w - u(24), TEXT_ALIGN_RIGHT}
                    })
               end

               local function Durum(b)
                    if (!SA.BuyuVar(b)) then return "no en servidor", N.Clr.bad end
                    if (BA and BA.Ayar and BA.Ayar.kapali and BA.Ayar.kapali[b]) then return "Cerrado en Árbol de hechizos", N.Clr.bad end
                    if (taslak.kapali[b]) then return "cerrado aquí", N.Clr.bad end
                    return "enseñable", N.Clr.ok or N.Clr.gold
               end

               liste = N.VList(G, 0, u(30), u(LIST_W), u(gh - 30 - 64), {
                    rowH = u(34),
                    gapY = 0,
                    emptyText = "No se encontraron hechizos básicos.",
                    onClick = function(r)
                         secili = r
                         if (IsValid(detay)) then detay.Kur() end
                    end,
                    paintRow = function(b, i, x, y, w, h, hovered)
                         local on = secili == b
                         if (on) then
                              N.Box(x, y, w, h, N.Clr.selRow)
                              N.Box(x, y, u(2), h, N.Clr.gold)
                         elseif (hovered) then
                              N.Box(x, y, w, h, N.Clr.hoverRow)
                         end
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
                         N.Text(b, "row", x + u(16), y + h / 2, N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         local s = SA.Sablon(b)
                         N.Text(s and s.uretildi and "derivado de ada" or "personalizado", "small", x + u(260), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         local d, c = Durum(b)
                         N.Text(d, "tiny", x + w - u(24), y + h / 2, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               })

               detay = vgui.Create("DPanel", G)
               detay:SetPos(u(LIST_W + 20), 0)
               detay:SetSize(u(340), u(gh - 64))
               detay.Paint = function() end

               function detay.Kur()
                    detay:Clear()
                    if (!secili) then
                         ShineAdmin.Placeholder(detay, 0, 0, u(340), detay:GetTall(), "Elige un hechizo a la izquierda.")
                         return
                    end
                    local b = secili

                    local on = vgui.Create("DPanel", detay)
                    on:SetPos(0, 0)
                    on:SetSize(u(340), u(250))
                    on.Paint = function(s, w, h)
                         N.Box(0, 0, w, h, N.Clr.toolBg)
                         N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                         local cx, cy, r = w / 2, h / 2 - u(10), math.min(w, h) * 0.34
                         SA.GokPlaka(cx, cy, r * 1.25, 0.3, RealTime() * 6)
                         local f = (RealTime() * 0.35) % 1.3
                         SA.Run2D(b, cx, cy, r, 1, SA.R.parsomen, 1.5, 50)
                         SA.Run2D(b, cx, cy, r, math.min(1, f), SA.R.altin, 2.5, 255, true)
                         N.Text(b, "serifsm", u(12), u(16), N.Clr.text)
                         N.Text("anillo verde = inicio", "tiny", u(12), h - u(14), N.Clr.rowDesc)
                    end

                    local s = SA.Sablon(b)
                    local t = vgui.Create("DPanel", detay)
                    t:SetPos(0, u(258))
                    t:SetSize(u(340), u(56))
                    t.Paint = function(p, w, h)
                         local satirlar = N.Wrap and N.Wrap(s and s.tarif or "", "tiny", w) or {s and s.tarif or ""}
                         for i, satir in ipairs(satirlar) do N.Text(satir, "tiny", 0, (i - 1) * u(14), N.Clr.rowDesc) end
                    end

                    N.Toggle(detay, 0, u(318), u(340), u(52), "Cerrado en tutoría entre pares",
                         function() return taslak.kapali[b] == true end,
                         function(v) taslak.kapali[b] = v or nil end,
                         "No sale en la lista de oferta. Se aplica al guardar.")

                    N.Button(detay, 0, u(378), u(340), u(34), "Abrir tarea de prueba (sin recompensa)", function()
                         Istek("testGorev", function() net.WriteString(b) end)
                    end)
               end

               liste:SetItems(SA.TemelHam())
               detay.Kur()
               KaydetSeridi(G, gh)
          end

          /*
          *   görevler
          */

          local function GorevKur(G, gh)
               local LIST_W = W - 360
               local secili
               local liste, detay, kayit

               local head = vgui.Create("DPanel", G)
               head:SetPos(0, 0)
               head:SetSize(u(LIST_W), u(30))
               head.Paint = function(s, w, h)
                    N.TableHead(0, 0, w, {
                         {"Alumno", u(16)},
                         {"Profesor", u(200)},
                         {"Hechizo", u(380)},
                         {"Fase", w - u(220)},
                         {"Restante", w - u(24), TEXT_ALIGN_RIGHT}
                    })
               end

               local LH = math.floor((gh - 30) * 0.58)
               liste = N.VList(G, 0, u(30), u(LIST_W), u(LH), {
                    rowH = u(34),
                    gapY = 0,
                    emptyText = "No hay tareas entre pares activas.",
                    onClick = function(g)
                         secili = g.ogrenci
                         if (IsValid(detay)) then detay.Kur() end
                    end,
                    paintRow = function(g, i, x, y, w, h, hovered)
                         local on = secili == g.ogrenci
                         if (on) then
                              N.Box(x, y, w, h, N.Clr.selRow)
                              N.Box(x, y, u(2), h, N.Clr.gold)
                         elseif (hovered) then
                              N.Box(x, y, w, h, N.Clr.hoverRow)
                         end
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
                         N.Text(N.Clip(g.ogrenciAd or "?", "row", u(170)), "row", x + u(16), y + h / 2, g.cevrimici and N.Clr.tdFirst or N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(N.Clip(g.ogretmenAd or "?", "small", u(170)), "small", x + u(200), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(N.Clip(g.buyu, "small", w - u(220) - u(390)), "small", x + u(380), y + h / 2, N.Clr.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         local a = SA.Asamalar[g.asama]
                         local ek = g.asama == 2 and (" %" .. math.floor(g.okunan / (g.gerek or SA.Ayar.okumaDakika * 60) * 100)) or (g.asama == 3 and (" " .. g.basari .. "/" .. SA.Ayar.basariGerek) or "")
                         N.Text((a and a.kisa or "?") .. ek, "small", x + w - u(220), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(SA.SureYaz(g.kalan), "tiny", x + w - u(24), y + h / 2, N.Clr.tdText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               })

               -- son kayıtlar
               kayit = N.VList(G, 0, u(30 + LH + 10), u(LIST_W), u(gh - 30 - LH - 10), {
                    rowH = u(26),
                    gapY = 0,
                    emptyText = "Sin registros.",
                    paintRow = function(l, i, x, y, w, h)
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
                         local olaylar = {basladi = "iniciada", ogretildi = "enseñado", cancelada = "cancelada", sure = "tiempo agotado", admin_cancelada = "cancelación admin", admin_ilerlet = "admin avanzó fase"}
                         N.Text(os.date("%d.%m %H:%M", tonumber(l.zaman) or 0), "tiny", x + u(12), y + h / 2, N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(olaylar[l.olay] or l.olay, "tiny", x + u(110), y + h / 2, l.olay == "ogretildi" and N.Clr.gold or N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(N.Clip((l.ogretmen or "") .. " → " .. (l.ogrenci or "") .. " · " .. (l.buyu or ""), "tiny", w - u(240)), "tiny", x + u(220), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
               })

               detay = vgui.Create("DPanel", G)
               detay:SetPos(u(LIST_W + 20), 0)
               detay:SetSize(u(340), u(gh))
               detay.Paint = function() end

               local function Bul()
                    for _, g in ipairs(SA.YonetimVeri.gorevler or {}) do
                         if (g.ogrenci == secili) then return g end
                    end
               end

               function detay.Kur()
                    detay:Clear()
                    local g = Bul()
                    if (!g) then
                         ShineAdmin.Placeholder(detay, 0, 0, u(340), u(200), "Elige una tarea a la izquierda.")
                         return
                    end

                    local bilgi = vgui.Create("DPanel", detay)
                    bilgi:SetPos(0, 0)
                    bilgi:SetSize(u(340), u(124))
                    bilgi.Paint = function(s, w, h)
                         N.Box(0, 0, w, h, N.Clr.toolBg)
                         N.Outline(0, 0, w, h, N.Clr.toolLine, 1)
                         N.Text(N.Clip(g.ogrenciAd or "?", "serifsm", w - u(24)), "serifsm", u(14), u(12), N.Clr.text)
                         N.Text("Profesor: " .. (g.ogretmenAd or "?"), "tiny", u(14), u(40), N.Clr.rowDesc)
                         N.Text("Hechizo: " .. g.buyu, "tiny", u(14), u(58), N.Clr.gold)
                         local raf = SA.RafBul(g.raf)
                         N.Text("Fase: " .. (SA.Asamalar[g.asama] and SA.Asamalar[g.asama].ad or "?") .. "  ·  raf " .. (raf and ((SA.Roma[raf.kat] or raf.kat) .. "/" .. raf.no) or "?"), "tiny", u(14), u(76), N.Clr.rowDesc)
                         N.Text((g.cevrimici and "en línea" or "desconectado") .. "  ·  restante " .. SA.SureYaz(g.kalan), "tiny", u(14), u(94), g.cevrimici and N.Clr.ok or N.Clr.faint)
                    end

                    local y = 134
                    N.Button(detay, 0, u(y), u(165), u(34), "Ir al alumno", function()
                         Istek("git", function() net.WriteString("gorev") net.WriteUInt(g.ogrenci, 32) end)
                    end)
                    N.Button(detay, u(175), u(y), u(165), u(34), g.asama == 4 and "Dar hechizo (sin recompensa)" or "Avanzar fase", function()
                         Istek("gorevIlerlet", function() net.WriteUInt(g.ogrenci, 32) end)
                    end)
                    y = y + 44
                    N.Button(detay, 0, u(y), u(340), u(34), "Cancelar tarea", function()
                         N.Confirm("Cancelar tarea", (g.ogrenciAd or "?") .. " del alumno " .. g.buyu .. " la tarea se cerrará.", "Cancelar", function()
                              Istek("gorevIptal", function() net.WriteUInt(g.ogrenci, 32) end)
                         end, true)
                    end, "quiet")
               end

               ctx.GorevYenile = function()
                    if (IsValid(liste)) then liste:SetItems(SA.YonetimVeri.gorevler or {}, true) end
                    if (IsValid(kayit)) then kayit:SetItems(SA.YonetimVeri.log or {}, true) end
                    if (IsValid(detay)) then detay.Kur() end
               end

               liste:SetItems(SA.YonetimVeri.gorevler or {})
               kayit:SetItems(SA.YonetimVeri.log or {})
               detay.Kur()
               Istek("gorevler")

               local sonra = RealTime() + 5
               detay.Think = function()
                    if (RealTime() > sonra) then
                         sonra = RealTime() + 5
                         Istek("gorevler")
                    end
               end
          end

          SekmeKur = function()
               if (IsValid(govde)) then govde:Remove() end
               ctx.GorevYenile = nil
               govde = vgui.Create("DPanel", P)
               govde:SetPos(0, u(GY))
               govde:SetSize(u(W), u(GH))
               govde.Paint = function() end

               if (aktif == "ayar") then AyarKur(govde, GH)
               elseif (aktif == "raf") then RafKur(govde, GH)
               elseif (aktif == "alan") then AlanKur(govde, GH)
               elseif (aktif == "buyu") then BuyuKur(govde, GH)
               else GorevKur(govde, GH) end
          end

          local izleyici = vgui.Create("DPanel", P)
          izleyici:SetSize(0, 0)
          izleyici.Paint = function() end
          local onceki = table.Copy(SA.Ayar)
          hook.Add("SardonAkranAyar", izleyici, function()
               if (Esit(taslak, onceki)) then
                    taslak = table.Copy(SA.Ayar)
                    if (aktif == "ayar" or aktif == "buyu") then SekmeKur() end
               end
               onceki = table.Copy(SA.Ayar)
          end)

          ctx.SetHead({
               note = function()
                    return #SA.HaritaVeri.raflar .. " ESTANTES  ·  " .. #SA.HaritaVeri.alanlar .. " ZONAS PRÁCTICA"
               end
          })

          SekmeKur()
     end
}

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.akran = sayfa

concommand.Add("sardon_akran_admin", function()
     if (ShineAdmin and ShineAdmin.Open) then ShineAdmin:Open("akran") end
end, nil, "Shine Admin > Tutoría entre pares")
