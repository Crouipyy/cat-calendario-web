-- "addons\\sardonrevir\\lua\\sardon_revir\\cl_6hud.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: ekran (nöbet takip kartı, etkileşim ipucu, isim plakaları, balonlar, nöbet karnesi).

local R = SardonRevir
local SA = setmetatable({}, {__index = function(_, k) local A = SardonAkran return A and A[k] end}) -- akran sonradan yüklenebilir
local C = R.C

local DURUM = {geliyor = "Geliyor", yatiyor = "", iyilesti = "İyileşti", devrediliyor = "Pomfrey geliyor", devredildi = "Pomfrey'e devredildi", cikti = "Ayrıldı"}

local function Sure(sn)
     sn = math.max(0, math.floor(sn))
     return string.format("%02d:%02d", math.floor(sn / 60), sn % 60)
end

local function KalintiRengi(h)
     for b in pairs(h.acik) do
          local bel = R.Belirtiler[b]
          if (bel and bel.kalinti) then return R.Kalintilar[bel.kalinti].renk end
     end
end

local function NobetKarti()
     local N = R.Nobet
     if (!N or !SA or !SA.Kart) then return end
     local W = 320
     local satirH = 46
     local H = 62 + #N.hastalar * satirH + 8
     local x, y = ScrW() - W - 24, ScrH() * 0.24
     local a = math.Clamp((RealTime() - (R.NobetAcilis or 0)) / 0.4, 0, 1)
     SA.Kart(x, y, W, H, 0.9 * a, 18)
     R.Yazi(N.test and "REVİR NÖBETİ · TEST" or "REVİR NÖBETİ", "etiket", x + 18, y + 18, C.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)
     R.Yazi(Sure(N.bitis - CurTime()), "etiket", x + W - 18, y + 18, C.soluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 255 * a)
     R.Yazi("+" .. N.kazanc .. " Şifa deneyimi", "kucuk", x + 18, y + 38, C.sifa, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)

     for i, h in ipairs(N.hastalar) do
          local sy = y + 56 + (i - 1) * satirH
          local bitti = h.durum == "iyilesti" or h.durum == "devredildi" or h.durum == "cikti"
          local renk = bitti and (h.durum == "iyilesti" and C.sifa or C.sonuk) or C.fildisi
          R.Yazi(h.yatak .. " · " .. h.ad, "isim", x + 18, sy + 10, renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)
          local alt
          if (h.durum != "yatiyor") then
               alt = DURUM[h.durum] or h.durum
               if (bitti and h.gercek != "") then alt = alt .. " · " .. (R.Hastalik(h.gercek) and R.Hastalik(h.gercek).ad or "") end
          else
               local t = h.teshis != "" and R.Hastalik(h.teshis)
               local parca = {}
               parca[#parca + 1] = (h.belirti or h.hikaye) and "dinlendi" or "dinle"
               parca[#parca + 1] = h.muayene and "muayene ✓" or "muayene"
               parca[#parca + 1] = h.tarama and "tarandı" or "tara"
               if (t) then
                    alt = t.ad .. "  " .. h.gAdim .. "/" .. #t.tedavi
               else
                    alt = table.concat(parca, " · ")
               end
          end
          R.Yazi(alt, "kucuk", x + 18, sy + 28, h.yanlis > 0 and C.uyari or C.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 * a)
          local k = h.durum == "yatiyor" and KalintiRengi(h)
          if (k) then SA.Isik(x + W - 24, sy + 18, 12, k, 220 * a) end
          if (h.yanlis > 0 and h.durum == "yatiyor") then R.Yazi(string.rep("✕", h.yanlis), "kucuk", x + W - 40, sy + 18, C.kotu, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 255 * a) end
     end
end

local function Ipucu()
     if (R.CizimModu or vgui.CursorVisible()) then return end
     local b = R.Bakilan and R.Bakilan()
     if (!b) then return end
     local metin, ad, alt
     if (b.tur == "hasta") then
          local h = R.BenimHasta(b.id)
          if (!h or h.durum != "yatiyor") then return end
          ad = h.ad
          metin = "E · Hasta kartı"
          local plan = R.PlanAdimC(h)
          if (plan and plan[1] == "buyu") then
               local O = SardonConfig and SardonConfig.Options
               local tus = O and (O.revir_ciz and SardonConfig:Get("revir_ciz") or (O.akran_talim and SardonConfig:Get("akran_talim"))) or KEY_J
               metin = metin .. "     " .. string.upper(input.GetKeyName(tus) or "J") .. " · " .. plan[2]
          end
     elseif (b.tur == "pomfrey") then
          metin, ad = "E · Konuş", "Madam Pomfrey"
          alt = "Revir Hemşiresi"
     elseif (b.tur == "baska") then
          metin, ad = "E · Selam ver", b.c.v.ad
          alt = b.c.v.unvan
     elseif (b.tur == "defter") then
          metin, ad = "E · Hastalık Defteri", "Defter"
     end
     if (!metin) then return end

     -- isim plakası (aktörün üstünde)
     if (b.c and b.c.cizPos) then
          local pos = R.AktorBasPos(b.c)
          local sp = pos and pos:ToScreen()
          if (sp and sp.visible and !R.Balon[b.id]) then
               R.Yazi(ad, "isim", sp.x, sp.y - 30, b.tur == "pomfrey" and C.altin or C.fildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               if (alt) then R.Yazi(alt, "kucuk", sp.x, sp.y - 13, C.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
          end
     end
     local w = R.YaziG(metin, "orta") + 40
     if (SA and SA.Kart) then SA.Kart(ScrW() / 2 - w / 2, ScrH() - 170, w, 36, 0.85, false) end
     R.Yazi(metin, "orta", ScrW() / 2, ScrH() - 152, C.fildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function IslemCubugu()
     local I = R.Islemde
     if (!I) then return end
     local f = (RealTime() - I.bas) / I.sure
     if (f >= 1.15) then R.Islemde = nil return end
     local w, h = 260, 8
     local x, y = ScrW() / 2 - w / 2, ScrH() / 2 + 60
     R.Yazi(I.ad, "orta", ScrW() / 2, y - 14, C.fildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     surface.SetDrawColor(20, 26, 22, 220)
     surface.DrawRect(x, y, w, h)
     surface.SetDrawColor(C.sifa.r, C.sifa.g, C.sifa.b, 255)
     surface.DrawRect(x, y, w * math.min(1, f), h)
end

hook.Add("HUDPaint", "SardonRevir.Ekran", function()
     local lp = LocalPlayer()
     if (!IsValid(lp)) then return end
     R.Fontlar()
     if (R.RevirYakin and R.RevirYakin(lp)) then
          if (R.BalonlariCiz) then R.BalonlariCiz() end
          Ipucu()
     end
     NobetKarti()
     IslemCubugu()
end)

hook.Add("SardonRevirNobet", "SardonRevir.Serit", function(N, eski)
     if (N and !eski) then
          R.Serit("Revir nöbeti başladı", #N.hastalar .. " hasta geliyor. Dinle, muayene et, tara; teşhisi masadaki defterden koy.", "iyi")
     end
end)

--[[
*   nöbet karnesi
]]

local karne

function R.KarneAc(t)
     if (IsValid(karne)) then karne:Remove() end
     R.Fontlar()
     local W = 640
     local p = vgui.Create("EditablePanel")
     karne = p
     p:MakePopup()
     p:SetKeyboardInputEnabled(true)
     p.acilis = RealTime()

     local H = 150 + #t.hastalar * 40 + 120
     if (#(t.degisim or {}) > 0) then H = H + 26 + #t.degisim * 20 end
     if (#(t.ogrenilen or {}) > 0) then H = H + 26 + #t.ogrenilen * 20 end
     if (#(t.kilitli or {}) > 0) then H = H + 26 + #t.kilitli * 34 end
     if (t.unvanYeni) then H = H + 60 end
     H = math.min(H, ScrH() - 40)
     p:SetSize(W, H)
     p:Center()

     local kapat = vgui.Create("DButton", p)
     kapat:SetSize(140, 34)
     kapat:SetPos(W - 160, H - 50)
     kapat:SetText("")
     kapat.Paint = function(s, w, h)
          surface.SetDrawColor(96, 150, 104, s:IsHovered() and 240 or 180)
          surface.DrawRect(0, 0, w, h)
          R.Yazi("Tamam", "orta", w / 2, h / 2, C.fildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
     kapat.DoClick = function() p:Remove() end

     function p:OnKeyCodePressed(k) if (k == KEY_ESCAPE or k == KEY_ENTER or k == KEY_E) then self:Remove() end end

     function p:Paint(w, h)
          local a = math.Clamp((RealTime() - self.acilis) / 0.3, 0, 1)
          if (SA and SA.Kart) then SA.Kart(0, 0, w, h, 0.97 * a, 26) end
          local y = 28
          R.Yazi(t.test and "NÖBET KARNESİ · TEST (ödülsüz)" or "NÖBET KARNESİ", "etiket", 28, y, C.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          y = y + 24
          for _, s in ipairs(R.Sar("“" .. (t.pomfrey or "") .. "”", "diyalogI", w - 56)) do
               R.Yazi(s, "diyalogI", 28, y, C.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
               y = y + 24
          end
          R.Yazi("— Madam Pomfrey", "kucuk", w - 28, y + 4, C.soluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
          y = y + 32

          for _, hs in ipairs(t.hastalar) do
               local ok = hs.sonuc == "iyilesti"
               local yr = R.Yollar[hs.yol] and R.Yollar[hs.yol].renk or C.soluk
               surface.SetDrawColor(yr.r, yr.g, yr.b, 255)
               surface.DrawRect(28, y + 4, 4, 30)
               R.Yazi(hs.ad, "isim", 42, y + 11, C.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               R.Yazi(hs.hastalik .. (hs.dogru and "  · teşhis ilk seferde doğru" or (hs.teshis != "" and ("  · ilk teşhis: " .. hs.teshis) or "")), "kucuk", 42, y + 28, C.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               R.Yazi(ok and ("+" .. hs.deneyim) or "Pomfrey'e devredildi", "orta", w - 28, y + 11, ok and C.sifa or C.sonuk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               if (hs.yanlis > 0) then R.Yazi(hs.yanlis .. " yanlış tedavi", "kucuk", w - 28, y + 28, C.uyari, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
               y = y + 40
          end

          y = y + 8
          surface.SetDrawColor(C.altinK.r, C.altinK.g, C.altinK.b, 60)
          surface.DrawRect(28, y, w - 56, 1)
          y = y + 16
          R.Yazi("Şifa deneyimi", "orta", 28, y, C.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          R.Yazi("+" .. (t.deneyim or 0) .. (t.bonus and t.bonus > 0 and ("  (tam nöbet +" .. t.bonus .. ")") or ""), "orta", w - 28, y, C.sifa, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          y = y + 26
          -- [11-09] Karakter Gelişimi Şifa dal seviyesi ilerlemesi
          local esik = math.max(1, t.esik or 1)
          local f = math.Clamp((t.birikim or 0) / esik, 0, 1)
          R.Yazi("Şifa Sv " .. (t.dalSv or 0), "kucuk", 28, y, C.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          surface.SetDrawColor(26, 34, 28, 255)
          surface.DrawRect(140, y - 4, w - 290, 8)
          surface.SetDrawColor(C.sifa.r, C.sifa.g, C.sifa.b, 255)
          surface.DrawRect(140, y - 4, (w - 290) * f, 8)
          R.Yazi((t.birikim or 0) .. " / " .. esik, "kucuk", w - 28, y, C.soluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          y = y + 22
          if ((t.dalPuani or 0) > 0) then
               R.Yazi("+" .. t.dalPuani .. " Şifa XP  ·  TAB › Karakter Gelişimi › Şifa", "orta", 28, y, C.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               y = y + 26
          end

          local function Bolum(baslik)
               y = y + 8
               R.Yazi(baslik, "etiket", 28, y, C.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               y = y + 18
          end
          if (#(t.degisim or {}) > 0) then
               Bolum("USTALIK")
               for _, d in ipairs(t.degisim) do
                    R.Yazi(d.buyu .. ":  " .. R.UstalikAdlari[d.eski] .. "  →  " .. R.UstalikAdlari[d.yeni], "kucuk", 40, y, R.UstalikRenk[d.yeni] or C.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    y = y + 20
               end
          end
          if (#(t.ogrenilen or {}) > 0) then
               Bolum("ÖĞRENİLEN BÜYÜLER")
               for _, b in ipairs(t.ogrenilen) do
                    R.Yazi("✦ " .. b, "orta", 40, y, C.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    y = y + 20
               end
          end
          if (#(t.kilitli or {}) > 0) then
               Bolum("BEKLEYEN BÜYÜLER (Büyü Ağacı kilidi)")
               for _, k in ipairs(t.kilitli) do
                    R.Yazi(k.buyu, "kucuk", 40, y, C.uyari, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    R.Yazi(R.Sar(k.sebep or "", "kucuk", w - 100)[1] or "", "kucuk", 40, y + 15, C.sonuk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    y = y + 34
               end
          end
          if (t.unvanYeni) then
               y = y + 10
               R.Yazi("YENİ UNVAN: " .. string.upper(t.unvanYeni), "orta", w / 2, y, C.altin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               if (t.pomfreyUnvan) then R.Yazi("“" .. t.pomfreyUnvan .. "”", "kucuk", w / 2, y + 22, C.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
          end
          R.Yazi("Unvan: " .. (t.unvan or ""), "kucuk", 28, h - 33, C.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end
     surface.PlaySound("ambient/energy/whiteflash.wav")
end
