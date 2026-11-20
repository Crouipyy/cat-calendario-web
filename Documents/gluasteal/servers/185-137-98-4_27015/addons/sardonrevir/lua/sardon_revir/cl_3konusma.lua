-- "addons\\sardonrevir\\lua\\sardon_revir\\cl_3konusma.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: diyalog paneli, hasta kartı, Accio listesi, E ile etkileşim.

local R = SardonRevir
local SA = setmetatable({}, {__index = function(_, k) local A = SardonAkran return A and A[k] end}) -- akran sonradan yüklenebilir
local C = R.C

R.Diy = R.Diy or nil

--[[
*   diyalog
]]

local HIZ = 52 -- harf / sn

local function DiyKapat()
     if (R.Diy and IsValid(R.Diy.panel)) then R.Diy.panel:Remove() end
     R.Diy = nil
end
R.DiyalogKapat = DiyKapat

local function HarfSayisi(s) return utf8.len(s) or #s end

local function IlkHarfler(s, n)
     if (n <= 0) then return "" end
     local bayt = utf8.offset(s, n + 1)
     if (!bayt) then return s end
     return string.sub(s, 1, bayt - 1)
end

local function Secim(D, i)
     local o = D.secenekler[i]
     if (!o) then return end
     surface.PlaySound("buttons/lightswitch2.wav")
     local aktor = D.aktor
     DiyKapat()
     R.Islem(R.ISLEM.SECIM, aktor, function() net.WriteString(o[1]) end)
end

local function Ilerle(D)
     local s = D.satirlar[D.i]
     if (!s) then return DiyKapat() end
     local n = HarfSayisi(s[3])
     local gosterilen = (RealTime() - D.harfBas) * HIZ
     if (gosterilen < n) then
          D.harfBas = RealTime() - n / HIZ - 0.01
          return
     end
     if (D.i < #D.satirlar) then
          D.i = D.i + 1
          D.harfBas = RealTime()
          return
     end
     if (#D.secenekler == 0) then DiyKapat() end
end

local function SecenekKutulari(D, x, y, w)
     local kutu = {}
     local oy = y
     for i, o in ipairs(D.secenekler) do
          kutu[i] = {x = x, y = oy, w = w, h = 30}
          oy = oy + 34
     end
     return kutu
end

local function DiyPanel()
     local p = vgui.Create("EditablePanel")
     p:SetSize(ScrW(), ScrH())
     p:SetPos(0, 0)
     p:MakePopup()
     p:SetKeyboardInputEnabled(true)
     p.acilis = RealTime()

     function p:Paint(sw, sh)
          local D = R.Diy
          if (!D) then return end
          R.Fontlar()
          local W = math.min(920, sw - 80)
          local secV = D.i == #D.satirlar and #D.secenekler > 0
          local s = D.satirlar[D.i] or {"anlatici", "", ""}
          local satirlar = R.Sar(s[3], s[1] == "anlatici" and "diyalogI" or "diyalog", W - 60)
          local metinH = #satirlar * 26
          local secH = secV and (#D.secenekler * 34 + 10) or 0
          local H = 70 + metinH + secH + 20
          local x, y = sw / 2 - W / 2, sh - H - 70
          local a = math.Clamp((RealTime() - self.acilis) / 0.2, 0, 1)

          if (SA and SA.Kart) then SA.Kart(x, y, W, H, 0.96 * a, 22) else draw.RoundedBox(6, x, y, W, H, C.zemin) end

          -- konuşan
          local kim = s[1]
          local adRenk = kim == "pomfrey" and C.altin or (kim == "oyuncu" and C.mavi or (kim == "anlatici" and C.soluk or C.sifa))
          local ad = kim == "anlatici" and "REVİR" or string.upper(s[2] or "")
          R.Yazi(ad, "etiket", x + 30, y + 24, adRenk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)
          if (SA and SA.Isik) then SA.Isik(x + 20, y + 24, 9, adRenk, 160 * a) end

          -- daktilo
          local kalan = math.floor((RealTime() - D.harfBas) * HIZ)
          local font = kim == "anlatici" and "diyalogI" or "diyalog"
          local renk = kim == "anlatici" and C.parsomenK or C.fildisi
          for i, satir in ipairs(satirlar) do
               local n = HarfSayisi(satir)
               local goster = kalan >= n and satir or IlkHarfler(satir, kalan)
               R.Yazi(goster, font, x + 30, y + 50 + (i - 1) * 26, renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 255 * a)
               kalan = kalan - n - 1
               if (kalan < 0) then break end
          end
          local bitti = (RealTime() - D.harfBas) * HIZ >= HarfSayisi(s[3])

          -- seçenekler
          D.kutu = nil
          if (secV and bitti) then
               local oy = y + 58 + metinH + 4
               D.kutu = SecenekKutulari(D, x + 26, oy, W - 52)
               local mx, my = input.GetCursorPos()
               for i, o in ipairs(D.secenekler) do
                    local k = D.kutu[i]
                    local ust = mx >= k.x and mx <= k.x + k.w and my >= k.y and my <= k.y + k.h
                    surface.SetDrawColor(ust and 60 or 30, ust and 70 or 40, ust and 54 or 34, 200 * a)
                    surface.DrawRect(k.x, k.y, k.w, k.h)
                    surface.SetDrawColor(C.altinK.r, C.altinK.g, C.altinK.b, (ust and 160 or 70) * a)
                    surface.DrawOutlinedRect(k.x, k.y, k.w, k.h, 1)
                    R.Yazi(i .. ".", "isim", k.x + 14, k.y + k.h / 2, C.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)
                    R.Yazi(o[2], "orta", k.x + 40, k.y + k.h / 2, ust and C.fildisi or C.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)
               end
          elseif (bitti) then
               R.Yazi(D.i < #D.satirlar and "Boşluk / tık: devam" or "Boşluk / tık: kapat", "kucuk", x + W - 26, y + H - 16, C.sonuk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 200 * a)
          end
          R.Yazi("Esc: kapat", "kucuk", x + 30, y + H - 16, C.sonuk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 150 * a)
     end

     function p:OnMousePressed(kod)
          local D = R.Diy
          if (!D) then return self:Remove() end
          if (D.kutu) then
               local mx, my = input.GetCursorPos()
               for i, k in ipairs(D.kutu) do
                    if (mx >= k.x and mx <= k.x + k.w and my >= k.y and my <= k.y + k.h) then return Secim(D, i) end
               end
               return
          end
          Ilerle(D)
     end

     function p:OnKeyCodePressed(kod)
          local D = R.Diy
          if (!D) then return self:Remove() end
          if (kod == KEY_ESCAPE) then return DiyKapat() end
          if (kod == KEY_SPACE or kod == KEY_ENTER or kod == KEY_E) then
               if (!D.kutu) then Ilerle(D) end
               return
          end
          local no = kod - KEY_1 + 1
          if (D.kutu and no >= 1 and no <= #D.secenekler) then Secim(D, no) end
     end

     function p:Think()
          if (gui.IsGameUIVisible()) then DiyKapat() end
     end
     return p
end

net.Receive("SardonRevir.Diyalog", function()
     local aktor = net.ReadUInt(16)
     local satirlar = {}
     for i = 1, net.ReadUInt(5) do satirlar[i] = {net.ReadString(), net.ReadString(), net.ReadString()} end
     local sec = {}
     for i = 1, net.ReadUInt(4) do sec[i] = {net.ReadString(), net.ReadString()} end

     if (#satirlar == 0) then return DiyKapat() end
     if (R.CizimModu) then
          -- çizim sırasında panel açılmasın; anlatıyı şerit olarak göster
          for _, s in ipairs(satirlar) do if (s[1] == "anlatici") then R.Serit("Revir", s[3]) end end
          return
     end
     local panel = R.Diy and IsValid(R.Diy.panel) and R.Diy.panel
     R.Diy = {aktor = aktor != 0 and aktor or nil, satirlar = satirlar, secenekler = sec, i = 1, harfBas = RealTime(), panel = panel}
     if (!panel) then R.Diy.panel = DiyPanel() end
     if (R.KartKapat) then R.KartKapat() end
end)

--[[
*   hasta kartı
]]

local kart

function R.KartKapat()
     if (IsValid(kart)) then kart:Remove() end
     kart = nil
end

local DUGMELER = {
     {"konus", "Konuş", "Hikâyesini ve yakınmalarını dinle"},
     {"muayene", "Muayene et", "Nabız, deri, gözler"},
     {"tara", "Asayla tara", "Kalıntının rengi (asa elde)"},
     {"tedavi", "Tedavi et", "Sıradaki büyünün rününü çiz"},
     {"accio", "Dolaptan getir", "Accio ile ilaç çağır"},
     {"sevk", "Pomfrey'e sevk et", "Bazı vakalar sana göre değildir"}
}

local function Dugme(p, x, y, w, h, metin, alt, aktif, tik)
     local b = vgui.Create("DButton", p)
     b:SetPos(x, y)
     b:SetSize(w, h)
     b:SetText("")
     b.Paint = function(s, bw, bh)
          local en = aktif == nil or (isfunction(aktif) and aktif()) or aktif == true
          local ust = s:IsHovered() and en
          surface.SetDrawColor(ust and 52 or 26, ust and 66 or 36, ust and 50 or 30, en and 235 or 140)
          surface.DrawRect(0, 0, bw, bh)
          surface.SetDrawColor(C.altinK.r, C.altinK.g, C.altinK.b, ust and 180 or 70)
          surface.DrawOutlinedRect(0, 0, bw, bh, 1)
          R.Yazi(metin, "orta", 12, alt and 13 or bh / 2, en and (ust and C.fildisi or C.soluk) or C.sonuk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          if (alt) then R.Yazi(alt, "kucuk", 12, 31, C.sonuk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
     end
     b.DoClick = function()
          local en = aktif == nil or (isfunction(aktif) and aktif()) or aktif == true
          if (!en) then surface.PlaySound("buttons/button10.wav") return end
          surface.PlaySound("buttons/lightswitch2.wav")
          tik()
     end
     return b
end

local function AccioListesi(parent, id)
     if (IsValid(parent.accio)) then parent.accio:Remove() parent.accio = nil return end
     local W = parent:GetWide()
     local l = vgui.Create("DPanel", parent)
     l:SetPos(0, parent:GetTall())
     parent.accio = l
     local h = 14
     for i, e in ipairs(R.Esyalar) do
          Dugme(l, 14, h, W - 28, 44, e.ad, e.aciklama, true, function()
               R.Islem(R.ISLEM.ESYA, id, function() net.WriteUInt(i, 4) end)
               R.KartKapat()
          end)
          h = h + 48
     end
     l:SetSize(W, h + 10)
     l.Paint = function(s, w, hh)
          surface.SetDrawColor(10, 15, 13, 245)
          surface.DrawRect(0, 0, w, hh)
          surface.SetDrawColor(C.altinK.r, C.altinK.g, C.altinK.b, 80)
          surface.DrawOutlinedRect(0, 0, w, hh, 1)
     end
     parent:SetTall(parent:GetTall() + h + 10)
     local x, y = parent:GetPos()
     parent:SetPos(x, math.max(20, ScrH() / 2 - parent:GetTall() / 2))
end

function R.KartAc(id, sessiz)
     R.KartKapat()
     local h = R.BenimHasta(id)
     if (!h) then return end
     R.Fontlar()

     local W, H = 440, 0
     local p = vgui.Create("EditablePanel")
     kart = p
     p:SetSize(W, 600)
     p:MakePopup()
     p:SetKeyboardInputEnabled(true)
     p.id = id

     local plan, t = R.PlanAdimC(h)
     local yBul = 200

     -- düğmeler
     local dy = 0
     local function Ekle(d)
          local en = true
          local alt = d[3]
          if (d[1] == "tedavi") then
               en = plan != nil and plan[1] == "buyu"
               if (!t) then alt = "Önce masadaki defterden teşhis koy"
               elseif (plan and plan[1] != "buyu") then alt = "Sıradaki adım: " .. R.AdimYaz(plan)
               elseif (plan) then alt = plan[2] .. (R.Biliyor(plan[2]) and "  ·  biliyorsun" or "  ·  bilmiyorsun, kılavuzla") end
          elseif (d[1] == "konus" and h.belirti and h.hikaye) then
               alt = "Konuştun; yine de sohbet edebilirsin"
          elseif (d[1] == "muayene" and h.muayene) then
               alt = "Muayene edildi"
          elseif (d[1] == "tara" and h.tarama) then
               alt = "Tarandı"
          end
          local b = Dugme(p, 16, 0, W - 32, 44, (#p:GetChildren() + 1) .. ".  " .. d[2], alt, en, function()
               if (d[1] == "konus") then R.KartKapat() R.Islem(R.ISLEM.KONUS, id)
               elseif (d[1] == "muayene") then R.KartKapat() R.Islem(R.ISLEM.MUAYENE, id) R.Islemde = {ad = "Muayene ediliyor", bas = RealTime(), sure = 1.6}
               elseif (d[1] == "tara") then R.KartKapat() R.Islem(R.ISLEM.TARA, id) R.Islemde = {ad = "Taranıyor", bas = RealTime(), sure = 1.3}
               elseif (d[1] == "tedavi") then R.KartKapat() if (R.CizimBasla) then R.CizimBasla(id) end
               elseif (d[1] == "accio") then AccioListesi(p, id)
               elseif (d[1] == "sevk") then R.KartKapat() R.Islem(R.ISLEM.SEVK, id) end
          end)
          b.sira = #p:GetChildren()
          b:SetPos(16, yBul + dy)
          dy = dy + 48
     end
     for _, d in ipairs(DUGMELER) do Ekle(d) end
     H = yBul + dy + 14
     p:SetTall(H)
     p:SetPos(ScrW() - W - 60, ScrH() / 2 - H / 2)

     function p:Paint(w, hh)
          local hh2 = H
          if (SA and SA.Kart) then SA.Kart(0, 0, w, hh2, 0.97, 22) else draw.RoundedBox(6, 0, 0, w, hh2, C.zemin) end
          local hx = R.BenimHasta(self.id) or h
          R.Yazi("HASTA · YATAK " .. hx.yatak, "etiket", 22, 22, C.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          R.Yazi(hx.ad, "defterAlt", 22, 46, C.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          R.Yazi(hx.hane .. "  ·  " .. hx.yil .. ". yıl", "kucuk", 22, 68, C.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          if (hx.yanlis > 0) then R.Yazi("Yanlış tedavi: " .. hx.yanlis, "kucuk", w - 22, 22, C.kotu, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end

          -- bulgular
          local by = 92
          R.Yazi("BULGULAR", "etiket", 22, by, C.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          local adlar = {}
          for _, kaynak in ipairs(R.KaynakSira) do
               for b in pairs(hx.acik) do
                    local bel = R.Belirtiler[b]
                    if (bel and bel.kaynak == kaynak) then adlar[#adlar + 1] = bel.ad end
               end
          end
          local metin = #adlar > 0 and table.concat(adlar, " · ") or "Henüz bir şey bilmiyorsun. Konuş, muayene et, tara."
          local satirlar = R.Sar(metin, "kucuk", w - 44)
          for i, s in ipairs(satirlar) do
               if (i > 3) then break end
               R.Yazi(s, "kucuk", 22, by + 4 + i * 17, #adlar > 0 and C.fildisi or C.sonuk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end

          -- teşhis
          local ty = 160
          local planX, tX = R.PlanAdimC(hx)
          R.Yazi("TEŞHİS", "etiket", 22, ty, C.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          if (tX) then
               local adimlar = {}
               for i, a in ipairs(tX.tedavi) do
                    adimlar[#adimlar + 1] = (i <= hx.gAdim and "✓ " or (i == hx.gAdim + 1 and "› " or "")) .. R.AdimYaz(a)
               end
               R.Yazi(tX.ad, "orta", 90, ty, C.sifa, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               R.Yazi(table.concat(adimlar, "   "), "kucuk", 22, ty + 20, C.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          else
               R.Yazi("yok — defter masada", "orta", 90, ty, C.sonuk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
     end

     function p:OnKeyCodePressed(kod)
          if (kod == KEY_ESCAPE or kod == KEY_E or kod == KEY_TAB) then return R.KartKapat() end
          local no = kod - KEY_1 + 1
          for _, c in ipairs(self:GetChildren()) do
               if (c.sira == no and c.DoClick) then return c:DoClick() end
          end
     end

     function p:OnMousePressed()
          -- kart dışına tık kapatır
          local mx, my = input.GetCursorPos()
          local x, y = self:GetPos()
          if (mx < x or my < y or mx > x + self:GetWide() or my > y + self:GetTall()) then R.KartKapat() end
     end

     function p:Think()
          if (gui.IsGameUIVisible()) then return R.KartKapat() end
          local hx = R.BenimHasta(self.id)
          if (!hx or hx.durum != "yatiyor") then return R.KartKapat() end
          local c = R.CA[self.id]
          if (c and c.cizPos and LocalPlayer():GetPos():DistToSqr(c.cizPos) > 260 * 260) then R.KartKapat() end
     end
     if (!sessiz) then surface.PlaySound("buttons/button9.wav") end
end

-- nöbet güncellenince açık kartı tazele (teşhis ve ilerleme değişir)
hook.Add("SardonRevirNobet", "SardonRevir.Kart", function()
     if (IsValid(kart) and !IsValid(kart.accio)) then
          local id = kart.id
          timer.Simple(0, function() if (IsValid(kart) and kart.id == id) then R.KartAc(id, true) end end)
     end
end)

--[[
*   E ile hedef
]]

local HEDEF_YATIK, HEDEF_AYAKTA = Vector(0, 0, 4), Vector(0, 0, 48) -- 11-13 opt: karede yeni Vector yerine sabit ofsetler (yalnız toplamada okunur)

-- {tur = "hasta"/"baska"/"pomfrey"/"defter", id, c}
function R.Bakilan()
     local lp = LocalPlayer()
     if (!IsValid(lp) or !lp:Alive() or !R.RevirYakin or !R.RevirYakin(lp)) then return nil end
     local goz, yon = lp:EyePos(), lp:GetAimVector()
     local en, enDot = nil, 0.9
     for id, c in pairs(R.CA) do
          if (c.cizPos and !c.v.gizli and (c.alfa or 0) > 0.5 and !c.v.yol) then
               local hedef = c.yatiyor and (c.cizPos + c.cizAng:Up() * 36 + HEDEF_YATIK) or (c.cizPos + HEDEF_AYAKTA) -- 11-13 opt: sabit ofsetler
               local d = hedef - goz
               local m = d:Length()
               if (m < (c.v.tur == "pomfrey" and 150 or 170)) then
                    local dot = yon:Dot(d / m)
                    if (dot > enDot) then
                         local tur = c.v.tur == "pomfrey" and "pomfrey" or (R.BenimHasta(id) and "hasta" or "baska")
                         en, enDot = {tur = tur, id = id, c = c}, dot
                    end
               end
          end
     end
     local h = R.Harita
     if (h) then
          local d = h.defter.pos - goz
          local m = d:Length()
          if (m < 130 and yon:Dot(d / m) > math.max(enDot, 0.86)) then en = {tur = "defter"} end
     end
     return en
end

hook.Add("PlayerBindPress", "SardonRevir.Kullan", function(ply, bind, basili)
     if (!basili or !string.find(bind, "+use", 1, true)) then return end
     if (R.CizimModu or vgui.CursorVisible()) then return end
     local b = R.Bakilan()
     if (!b) then return end
     if (b.tur == "hasta") then
          local h = R.BenimHasta(b.id)
          if (h and h.durum == "yatiyor") then R.KartAc(b.id) end
     elseif (b.tur == "baska" or b.tur == "pomfrey") then
          R.Islem(R.ISLEM.KONUS, b.id)
     elseif (b.tur == "defter") then
          if (R.DefterAc) then R.DefterAc() end
     end
     return true
end)
