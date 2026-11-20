-- "addons\\sardoncigirtkan\\lua\\sardon_cigirtkan\\cl_3kayit.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Çığırtkan :: istemci — gönderenin kayıt penceresi.
--
-- Pencerenin durumu sunucudadır (SardonCigirtkan.Durum); buradan yalnızca işlem yollanır.
-- Klavye girdisi pencereye ALINMAZ: bas-konuş tuşu oyunda çalışmaya devam etsin diye
-- (SetKeyboardInputEnabled(false)). Fareyle basılı tutulan "konuş" düğmesi de var.
local C = SardonCigirtkan
local R = C.Renk
local O = C.O

C.KD = C.KD or {durum = C.K.KAPALI}

local function Islem(no, deger)
     net.Start("SardonCigirtkan.Islem")
          net.WriteUInt(no, 3)
          net.WriteBool(deger == true)
     net.SendToServer()
end

local function OnizlemeKanal()
     local id = C.KD.onizleme
     return id and id ~= 0 and C.Kanal(id, false) or nil
end

local function OnizlemeDurdur()
     local ch = OnizlemeKanal()
     if ch then ch:Pause() ch:SetTime(0) end
     C.KD.caliyor = false
end

local function KonusmaBirak()
     if C.KD.basili then
          C.KD.basili = false
          if permissions and permissions.EnableVoiceChat then pcall(permissions.EnableVoiceChat, false) end
     end
end

----------------------------------------------------------------------------------------
-- Parçalar
----------------------------------------------------------------------------------------
local function Dugme(ust, x, y, w, h, yazi, stil, fn)
     local b = vgui.Create("DButton", ust)
     b:SetPos(x, y)
     b:SetSize(w, h)
     b:SetText("")
     b.yazi = yazi
     b.DoClick = function(s)
          if s.kapali then return end
          surface.PlaySound("ui/buttonclick.wav")
          fn(s)
     end
     b.Paint = function(s, pw, ph)
          local yz = isfunction(s.yazi) and s.yazi() or s.yazi
          local a = s.kapali and 90 or 255
          local ust2 = s:IsHovered() and not s.kapali
          if stil == "ana" then
               local r = ust2 and R.kizilAcik or R.kizil
               surface.SetDrawColor(r.r, r.g, r.b, a)
               surface.DrawRect(0, 0, pw, ph)
               surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, a * 0.55)
               surface.DrawOutlinedRect(0, 0, pw, ph, 1)
               C.Aralikli(C.Buyuk(yz), C.Font(15, true), pw / 2, ph / 2 - O(9), Color(R.fildisi.r, R.fildisi.g, R.fildisi.b, a), O(2), 1)
          else
               surface.SetDrawColor(R.zeminKoyu.r, R.zeminKoyu.g, R.zeminKoyu.b, ust2 and 255 or 200)
               surface.DrawRect(0, 0, pw, ph)
               local c = ust2 and R.altinAcik or R.cizgiGuclu
               surface.SetDrawColor(c.r, c.g, c.b, a)
               surface.DrawOutlinedRect(0, 0, pw, ph, 1)
               local yr = ust2 and R.altinAcik or R.altin
               C.Aralikli(C.Buyuk(yz), C.Font(14, true), pw / 2, ph / 2 - O(8), Color(yr.r, yr.g, yr.b, a), O(2), 1)
          end
          return true
     end
     return b
end

local function Kutucuk(ust, x, y, w, yazi, aciklama, deger, fn)
     local p = vgui.Create("DButton", ust)
     p:SetPos(x, y)
     p:SetSize(w, O(40))
     p:SetText("")
     p.deger = deger
     p.DoClick = function(s)
          if s.kapali then return end
          s.deger = not s.deger
          surface.PlaySound("ui/buttonclick.wav")
          fn(s.deger)
     end
     p.Paint = function(s, pw, ph)
          local k = O(16)
          local c = s:IsHovered() and R.altinAcik or R.altin
          surface.SetDrawColor(c.r, c.g, c.b, 255)
          surface.DrawOutlinedRect(0, O(3), k, k, 1)
          if s.deger then
               surface.SetDrawColor(R.kizilAcik.r, R.kizilAcik.g, R.kizilAcik.b, 255)
               surface.DrawRect(O(3), O(6), k - O(6), k - O(6))
          end
          draw.SimpleText(yazi, C.Font(15, true), k + O(10), O(1), R.fildisi)
          draw.SimpleText(aciklama, C.Font(13), k + O(10), O(21), R.soluk)
          return true
     end
     return p
end

----------------------------------------------------------------------------------------
-- Pencere
----------------------------------------------------------------------------------------
local GEN, YUK = 640, 400
local SOL = 230

local function SolCiz(p, w, h)
     local kd = C.KD
     local lp = LocalPlayer()
     local t = CurTime()
     local agiz, titre = 0, 0

     if kd.durum == C.K.KAYIT then
          if IsValid(lp) and lp:IsSpeaking() then
               local v = lp:VoiceVolume()
               agiz = v > 0.01 and math.Clamp(v * 1.8, 0.15, 1) or (0.25 + 0.55 * math.abs(math.sin(t * 9 + math.sin(t * 3.7) * 2)))
          end
     elseif kd.durum == C.K.ISLENIYOR then
          titre = 0.6
     elseif kd.durum == C.K.ONIZLEME and kd.caliyor then
          local ch = OnizlemeKanal()
          if ch then agiz = math.Clamp(((ch:GetLevel()) or 0) * 1.6, 0, 1) end
     end
     kd.agiz2 = Lerp(FrameTime() * 18, kd.agiz2 or 0, agiz)

     local zw, zh = O(170), O(110)
     local zx, zy = O(30), O(118)
     C.ZarfCiz2D(zx, zy + (math.sin(t * 2) * O(3)), zw, zh, kd.agiz2, titre)

     -- altında durum yazısı
     local yazi, renk = "", R.soluk
     if kd.durum == C.K.KAYIT then
          if IsValid(lp) and lp:IsSpeaking() then
               local a = 150 + 105 * math.abs(math.sin(t * 4))
               yazi, renk = "GRABANDO", Color(R.kizilAcik.r, R.kizilAcik.g, R.kizilAcik.b, a)
               -- Montserrat'ta ● yok: kayıt noktası çizilir
               surface.SetFont(C.Font(13, true))
               local yw = surface.GetTextSize(yazi) + O(2) * 11
               C.Baklava(zx + zw / 2 - yw / 2 - O(12), zy + zh + O(26) + O(8), O(5), renk)
          else
               yazi = "EL SOBRE ESCUCHA"
          end
     elseif kd.durum == C.K.ISLENIYOR then
          yazi = "SELLANDO" .. string.rep(".", math.floor(t * 3) % 4)
     elseif kd.durum == C.K.ONIZLEME then
          yazi = kd.anonim and "ANÓNIMO · SELLADO" or "SELLADO"
          renk = R.altin
     elseif kd.durum == C.K.HATA then
          yazi, renk = "EL SELLO FALLÓ", R.kizilAcik
     end
     C.Aralikli(yazi, C.Font(13, true), zx + zw / 2, zy + zh + O(26), renk, O(2), 1)
end

local function SagCiz(p, w, h)
     local kd = C.KD
     local x = O(SOL + 24)
     local sw = w - x - O(28)

     if kd.durum == C.K.KAYIT then
          local sn = kd.konusma or 0
          draw.SimpleText(C.SureYazi(sn), C.Font(46, true), x, O(92), R.fildisi)
          surface.SetFont(C.Font(46, true))
          local tw = surface.GetTextSize(C.SureYazi(sn))
          draw.SimpleText("/ " .. C.SureYazi(C.Ayar.EnUzun), C.Font(18), x + tw + O(10), O(116), R.soluk)

          local by = O(156)
          surface.SetDrawColor(R.zeminKoyu.r, R.zeminKoyu.g, R.zeminKoyu.b, 255)
          surface.DrawRect(x, by, sw, O(6))
          surface.SetDrawColor(R.kizilAcik.r, R.kizilAcik.g, R.kizilAcik.b, 255)
          surface.DrawRect(x, by, sw * math.Clamp(sn / C.Ayar.EnUzun, 0, 1), O(6))

          draw.SimpleText("Mantén pulsado el push-to-talk o el botón de abajo", C.Font(14), x, O(176), R.govde)
          draw.SimpleText("para hablar. Cuando termines, sella el sobre.", C.Font(14), x, O(195), R.govde)
          draw.SimpleText("Mientras grabas, los cercanos te oyen apagado.", C.Font(13), x, O(220), R.soluk)
     elseif kd.durum == C.K.ISLENIYOR then
          draw.SimpleText("Sellando el sobre", C.Font(26, true), x, O(110), R.fildisi)
          draw.SimpleText("Se limpia tu voz y la magia la amplifica cien veces.", C.Font(14), x, O(150), R.govde)
          local t = CurTime()
          for i = 0, 5 do
               local a = (math.sin(t * 5 - i * 0.7) * 0.5 + 0.5)
               C.Baklava(x + O(10) + i * O(22), O(194), O(5), Color(R.altin.r, R.altin.g, R.altin.b, 60 + a * 195))
          end
     elseif kd.durum == C.K.ONIZLEME then
          draw.SimpleText("Sellado · " .. C.SureYazi(math.ceil(kd.sure or 0)), C.Font(24, true), x, O(84), R.fildisi)
          -- dalga
          local dy, dh = O(122), O(66)
          surface.SetDrawColor(R.zeminKoyu.r, R.zeminKoyu.g, R.zeminKoyu.b, 255)
          surface.DrawRect(x, dy, sw, dh)
          surface.SetDrawColor(R.cizgi.r, R.cizgi.g, R.cizgi.b, R.cizgi.a)
          surface.DrawOutlinedRect(x, dy, sw, dh, 1)
          local d = kd.dalgaT or {}
          local n = #d
          local oran = 0
          local ch = kd.caliyor and OnizlemeKanal()
          if ch and ch:GetLength() > 0 then oran = ch:GetTime() / ch:GetLength() end
          if n > 0 then
               local bw = (sw - O(12)) / n
               for i = 1, n do
                    local bh = math.max(O(2), d[i] * (dh - O(12)))
                    local c = (i / n <= oran) and R.kizilAcik or R.altin
                    surface.SetDrawColor(c.r, c.g, c.b, 220)
                    surface.DrawRect(x + O(6) + (i - 1) * bw, dy + dh / 2 - bh / 2, math.max(1, bw - 1), bh)
               end
          end
          if kd.caliyor and ch and ch:GetState() ~= GMOD_CHANNEL_PLAYING then kd.caliyor = false end
     elseif kd.durum == C.K.HATA then
          draw.SimpleText("El sello no aguantó", C.Font(26, true), x, O(96), R.fildisi)
          local satirlar = string.Explode("\n", kd.hata or "")
          for i, s in ipairs(satirlar) do
               draw.SimpleText(s, C.Font(14), x, O(132) + (i - 1) * O(20), R.govde)
          end
     end
end

function C.PencereKur()
     local kd = C.KD
     local p = C.Pencere
     if not IsValid(p) then
          p = vgui.Create("EditablePanel")
          C.Pencere = p
          p:SetSize(O(GEN), O(YUK))
          p:Center()
          p:MakePopup()
          p:SetKeyboardInputEnabled(false)
          p.acilis = SysTime()

          p.Paint = function(s, w, h)
               Derma_DrawBackgroundBlur(s, s.acilis)
               surface.SetDrawColor(R.zemin.r, R.zemin.g, R.zemin.b, 250)
               surface.DrawRect(0, 0, w, h)
               surface.SetDrawColor(R.cizgiGuclu.r, R.cizgiGuclu.g, R.cizgiGuclu.b, R.cizgiGuclu.a)
               surface.DrawOutlinedRect(0, 0, w, h, 1)
               surface.SetDrawColor(R.cizgi.r, R.cizgi.g, R.cizgi.b, R.cizgi.a)
               surface.DrawOutlinedRect(O(6), O(6), w - O(12), h - O(12), 1)
               -- kızıl şerit
               surface.SetDrawColor(R.kizil.r, R.kizil.g, R.kizil.b, 255)
               surface.DrawRect(O(6), O(6), w - O(12), O(3))

               local grup = (kd.grupAd or "") ~= ""
               C.Aralikli(grup and "VOCIFERADOR MASIVO  ·  LECHUZAS" or "VOCIFERADOR  ·  CORREO DE LECHUZA", C.Font(12, true), O(30), O(26), R.ust, O(3), 0)
               local ad
               if grup then
                    ad = kd.grupAd .. "  ·  " .. (kd.grupSayi or 0) .. " persona(s)"
               else
                    ad = IsValid(kd.hedef) and hook.Run("GetCharacterName", kd.hedef, "ooc") or nil
                    if not ad and IsValid(kd.hedef) and kd.hedef:GetCharacter() then ad = kd.hedef:GetCharacter():GetName() end
               end
               draw.SimpleText("Para: " .. (ad or "?"), C.Font(24, true), O(30), O(42), R.fildisi)

               surface.SetDrawColor(R.cizgi.r, R.cizgi.g, R.cizgi.b, R.cizgi.a)
               surface.DrawLine(O(SOL), O(84), O(SOL), h - O(24))
               C.Baklava(O(SOL), O(84), O(4), R.altin)

               SolCiz(s, w, h)
               SagCiz(s, w, h)
          end

          p.OnRemove = function()
               KonusmaBirak()
               OnizlemeDurdur()
               if C.KD.durum ~= C.K.KAPALI and not C.KD.sunucuKapatti then Islem(C.I.VAZGEC) end
          end

          p.Think = function(s)
               -- ağa düşen önizleme kanalını hazırla (ilk çağrı yüklemeyi başlatır)
               if C.KD.durum == C.K.ONIZLEME then OnizlemeKanal() end
               if C.KD.basili and not input.IsMouseDown(MOUSE_LEFT) then KonusmaBirak() end
          end

          local kapat = vgui.Create("DButton", p)
          kapat:SetSize(O(36), O(36))
          kapat:SetPos(O(GEN) - O(48), O(16))
          kapat:SetText("")
          kapat.Paint = function(s, w, h)
               local c = s:IsHovered() and R.kizilAcik or R.altin
               draw.SimpleText("×", C.Font(30, true), w / 2, h / 2, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               return true
          end
          kapat.DoClick = function() p:Remove() end
     end

     -- sağ sütunun düğmeleri her durum değişiminde yeniden kurulur
     for _, c in ipairs(p.dugmeler or {}) do
          if IsValid(c) then c:Remove() end
     end
     p.dugmeler = {}
     local function Ekle(c) p.dugmeler[#p.dugmeler + 1] = c return c end

     local x = O(SOL + 24)
     local sw = O(GEN) - x - O(28)
     local by = O(YUK) - O(62)
     local bh = O(40)

     if kd.durum == C.K.KAYIT then
          if permissions and permissions.EnableVoiceChat then
               local konus = Ekle(Dugme(p, x, O(250), sw, O(46), "Mantén · hablar", "ikinci", function() end))
               konus.OnMousePressed = function(s, tus)
                    if tus ~= MOUSE_LEFT then return end
                    C.KD.basili = true
                    pcall(permissions.EnableVoiceChat, true)
               end
               konus.OnMouseReleased = function() KonusmaBirak() end
               local eski = konus.Paint
               konus.Paint = function(s, w, h)
                    if C.KD.basili then
                         surface.SetDrawColor(R.kizilKoyu.r, R.kizilKoyu.g, R.kizilKoyu.b, 255)
                         surface.DrawRect(0, 0, w, h)
                    end
                    return eski(s, w, h)
               end
          end
          local bw = (sw - O(10)) / 2
          local muhurle = Ekle(Dugme(p, x, by, bw, bh, "Sellar", "ana", function() Islem(C.I.BITIR) end))
          muhurle.Think = function(s) s.kapali = (C.KD.konusma or 0) < C.Ayar.EnKisa end
          Ekle(Dugme(p, x + bw + O(10), by, bw, bh, "Cancelar", "ikinci", function() p:Remove() end))
     elseif kd.durum == C.K.ONIZLEME then
          Ekle(Kutucuk(p, x, O(204), sw, "Enviar anónimo", "Tu voz se deforma con magia y tu nombre no se ve.", kd.anonim, function(d)
               OnizlemeDurdur()
               Islem(C.I.ANONIM, d)
          end))
          local bw = math.floor((sw - O(20)) * 0.28)
          local bwAna = sw - O(20) - bw * 2
          Ekle(Dugme(p, x, by, bw, bh, function() return C.KD.caliyor and "Parar" or "Escuchar" end, "ikinci", function()
               local ch = OnizlemeKanal()
               if not ch then return end
               if C.KD.caliyor then
                    OnizlemeDurdur()
               else
                    ch:SetTime(0)
                    ch:SetVolume(1)
                    ch:Play()
                    C.KD.caliyor = true
               end
          end))
          Ekle(Dugme(p, x + bw + O(10), by, bw, bh, "Otra vez", "ikinci", function()
               OnizlemeDurdur()
               Islem(C.I.YENIDEN)
          end))
          Ekle(Dugme(p, x + (bw + O(10)) * 2, by, bwAna, bh, "Dar a la lechuza", "ana", function()
               OnizlemeDurdur()
               Islem(C.I.GONDER)
          end))
     elseif kd.durum == C.K.HATA then
          local bw = (sw - O(10)) / 2
          Ekle(Dugme(p, x, by, bw, bh, "Grabar de nuevo", "ana", function() Islem(C.I.YENIDEN) end))
          Ekle(Dugme(p, x + bw + O(10), by, bw, bh, "Cerrar", "ikinci", function() p:Remove() end))
     elseif kd.durum == C.K.ISLENIYOR then
          Ekle(Dugme(p, x, by, sw, bh, "Cancelar", "ikinci", function() p:Remove() end))
     end
end

net.Receive("SardonCigirtkan.Durum", function()
     local kd = C.KD
     local eski = kd.durum
     kd.durum = net.ReadUInt(3)
     if kd.durum == C.K.KAPALI then
          kd.sunucuKapatti = true
          if IsValid(C.Pencere) then C.Pencere:Remove() end
          kd.sunucuKapatti = false
          kd.onizleme = nil
          return
     end
     kd.hedef = net.ReadEntity()
     kd.konusma = net.ReadFloat()
     kd.anonim = net.ReadBool()
     kd.hata = net.ReadString()
     local onizleme = net.ReadUInt(32)
     kd.sure = net.ReadFloat()
     local dalga = net.ReadString()
     kd.grupAd = net.ReadString()
     kd.grupSayi = net.ReadUInt(8)
     if onizleme ~= kd.onizleme then
          kd.caliyor = false
          kd.onizleme = onizleme
     end
     if dalga ~= kd.dalga then
          kd.dalga = dalga
          kd.dalgaT = C.DalgaCoz(dalga)
     end
     if eski ~= kd.durum or not IsValid(C.Pencere) then
          if kd.durum ~= C.K.KAYIT then KonusmaBirak() end
          C.PencereKur()
     end
end)

----------------------------------------------------------------------------------------
-- Toplu çığırtkan: grup seçici (envanter > Toplu Gönder ya da /TopluCigirtkan)
----------------------------------------------------------------------------------------
-- liste: {{anahtar, ad, sayi, sinif}} — sunucu yalnızca yetkili olunan ve çevrimiçi üyesi olan grupları yollar
function C.TopluSecici(liste)
     if IsValid(C.Secici) then C.Secici:Remove() end
     local satirH = O(56)
     local gorunen = math.min(#liste, 7)
     local w, h = O(520), O(108) + gorunen * (satirH + O(6)) + O(18)

     local p = vgui.Create("EditablePanel")
     C.Secici = p
     p:SetSize(w, h)
     p:Center()
     p:MakePopup()
     p:SetKeyboardInputEnabled(false)
     p.acilis = SysTime()
     p.Paint = function(s, pw, ph)
          Derma_DrawBackgroundBlur(s, s.acilis)
          surface.SetDrawColor(R.zemin.r, R.zemin.g, R.zemin.b, 250)
          surface.DrawRect(0, 0, pw, ph)
          surface.SetDrawColor(R.cizgiGuclu.r, R.cizgiGuclu.g, R.cizgiGuclu.b, R.cizgiGuclu.a)
          surface.DrawOutlinedRect(0, 0, pw, ph, 1)
          surface.SetDrawColor(R.cizgi.r, R.cizgi.g, R.cizgi.b, R.cizgi.a)
          surface.DrawOutlinedRect(O(6), O(6), pw - O(12), ph - O(12), 1)
          surface.SetDrawColor(R.kizil.r, R.kizil.g, R.kizil.b, 255)
          surface.DrawRect(O(6), O(6), pw - O(12), O(3))
          C.Aralikli("VOCIFERADOR MASIVO", C.Font(12, true), O(30), O(26), R.ust, O(3), 0)
          draw.SimpleText("¿A quién se grita?", C.Font(24, true), O(30), O(42), R.fildisi)
          draw.SimpleText("Los destinatarios cercanos comparten un solo sobre; una lechuza lleva cada sobre.", C.Font(13), O(30), O(76), R.soluk)
     end

     local kapat = vgui.Create("DButton", p)
     kapat:SetSize(O(36), O(36))
     kapat:SetPos(w - O(48), O(16))
     kapat:SetText("")
     kapat.Paint = function(s, pw, ph)
          draw.SimpleText("×", C.Font(30, true), pw / 2, ph / 2, s:IsHovered() and R.kizilAcik or R.altin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          return true
     end
     kapat.DoClick = function() p:Remove() end

     local kaydir = vgui.Create("DScrollPanel", p)
     kaydir:SetPos(O(24), O(104))
     kaydir:SetSize(w - O(48), h - O(104) - O(18))
     local cubuk = kaydir:GetVBar()
     cubuk:SetWide(O(4))
     cubuk.Paint = function() end
     cubuk.btnUp.Paint = function() end
     cubuk.btnDown.Paint = function() end
     cubuk.btnGrip.Paint = function(_, gw, gh)
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 120)
          surface.DrawRect(0, 0, gw, gh)
     end

     for i, g in ipairs(liste) do
          local b = kaydir:Add("DButton")
          b:Dock(TOP)
          b:DockMargin(0, 0, O(6), O(6))
          b:SetTall(satirH)
          b:SetText("")
          b.Paint = function(s, pw, ph)
               local ust = s:IsHovered()
               surface.SetDrawColor(R.zeminKoyu.r, R.zeminKoyu.g, R.zeminKoyu.b, ust and 255 or 200)
               surface.DrawRect(0, 0, pw, ph)
               local c = ust and R.altinAcik or R.cizgiGuclu
               surface.SetDrawColor(c.r, c.g, c.b, c.a or 255)
               surface.DrawOutlinedRect(0, 0, pw, ph, 1)
               if ust then
                    surface.SetDrawColor(R.kizil.r, R.kizil.g, R.kizil.b, 255)
                    surface.DrawRect(0, 0, O(3), ph)
               end
               draw.SimpleText(g.ad, C.Font(18, true), O(16), O(8), R.fildisi)
               draw.SimpleText(g.sayi .. " en línea", C.Font(13), O(16), O(32), R.soluk)
               C.Aralikli(g.sinif and "CLASE" or (string.find(g.ad, " Evi$") and "CASA" or "FACCIÓN"), C.Font(11, true), pw - O(16), ph / 2 - O(7), R.altin, O(2), 2)
               return true
          end
          b.DoClick = function()
               surface.PlaySound("ui/buttonclick.wav")
               net.Start("SardonCigirtkan.Basla")
                    net.WriteEntity(NULL)
                    net.WriteString(g.anahtar)
               net.SendToServer()
               p:Remove()
          end
     end
end

net.Receive("SardonCigirtkan.TopluListe", function()
     C.TopluSecici(net.ReadTable() or {})
end)
