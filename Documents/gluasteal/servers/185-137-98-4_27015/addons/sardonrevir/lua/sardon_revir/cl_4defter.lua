-- "addons\\sardonrevir\\lua\\sardon_revir\\cl_4defter.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: Hastalık Defteri (masada, E ile açılır).
-- Sol sayfa: hasta sekmeleri, hastada bulunan belirtiler (süzgeç), kalıntı / yol süzgeci, arama, sonuçlar.
-- Sağ sayfa: seçilen hastalık; belirtiler (hastada bulunanlar işaretli), tedavi adımları ve rünleri, uyarı, teşhis.

local R = SardonRevir
local SA = setmetatable({}, {__index = function(_, k) local A = SardonAkran return A and A[k] end}) -- akran sonradan yüklenebilir
local C = R.C

local defter

local function Doku(ad) return SA and SA.Doku and SA.Doku(ad) or nil end

local function KucukHarf(s)
     s = string.lower(tostring(s or ""))
     for b, k in pairs({["İ"] = "i", ["I"] = "ı", ["Ş"] = "ş", ["Ğ"] = "ğ", ["Ü"] = "ü", ["Ö"] = "ö", ["Ç"] = "ç"}) do s = string.Replace(s, b, k) end
     return s
end

local aramaOnbellek = {}
local function AramaMetni(h)
     if (aramaOnbellek[h.id]) then return aramaOnbellek[h.id] end
     local p = {h.ad, h.neden, h.aciklama, R.Yollar[h.yol].ad}
     for _, b in ipairs(h.belirtiler) do p[#p + 1] = R.Belirtiler[b].ad end
     for _, a in ipairs(h.tedavi) do p[#p + 1] = R.AdimYaz(a) end
     aramaOnbellek[h.id] = KucukHarf(table.concat(p, " "))
     return aramaOnbellek[h.id]
end

function R.DefterKapat()
     if (IsValid(defter)) then defter:Remove() end
     defter = nil
end

local function SeciliHasta(D)
     return D.hasta and R.BenimHasta(D.hasta)
end

-- süzgeç: seçili belirtilerin HEPSİNİ taşıyanlar; yoksa en çok taşıyanlar (kısmi)
local function Sonuclar(D)
     local secili = {}
     for b in pairs(D.secili) do secili[#secili + 1] = b end
     local aranan = KucukHarf(string.Trim(D.arama or ""))
     local tam, kismi = {}, {}
     for _, h in ipairs(R.Hastaliklar) do
          local uygun = (!D.yol or h.yol == D.yol) and (aranan == "" or string.find(AramaMetni(h), aranan, 1, true))
          if (uygun) then
               local n = 0
               for _, b in ipairs(secili) do if (h.belirtiSet[b]) then n = n + 1 end end
               if (n == #secili) then tam[#tam + 1] = {h = h, n = n} elseif (n > 0) then kismi[#kismi + 1] = {h = h, n = n} end
          end
     end
     table.sort(tam, function(a, b) if (#a.h.belirtiler != #b.h.belirtiler) then return #a.h.belirtiler < #b.h.belirtiler end return a.h.ad < b.h.ad end)
     table.sort(kismi, function(a, b) if (a.n != b.n) then return a.n > b.n end return a.h.ad < b.h.ad end)
     return tam, kismi, #secili
end

local function Cip(parent, x, y, metin, aktif, renk, tik)
     R.Fontlar()
     local w = R.YaziG(metin, "kucuk") + 22
     local b = vgui.Create("DButton", parent)
     b:SetPos(x, y)
     b:SetSize(w, 24)
     b:SetText("")
     b.Paint = function(s, bw, bh)
          local a = aktif()
          local ust = s:IsHovered()
          local r = renk or C.murekkepK
          surface.SetDrawColor(r.r, r.g, r.b, a and 210 or (ust and 60 or 30))
          surface.DrawRect(0, 0, bw, bh)
          surface.SetDrawColor(r.r, r.g, r.b, 200)
          surface.DrawOutlinedRect(0, 0, bw, bh, 1)
          R.Yazi(metin, "kucuk", bw / 2, bh / 2, a and C.parsomen or C.murekkep, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
     b.DoClick = function() surface.PlaySound("buttons/lightswitch2.wav") tik() end
     return b, w
end

local function SayfaZemin(x, y, w, h)
     surface.SetDrawColor(C.parsomen.r, C.parsomen.g, C.parsomen.b, 255)
     surface.DrawRect(x, y, w, h)
     local m = Doku("parchment_band")
     if (m) then
          surface.SetMaterial(m)
          surface.SetDrawColor(255, 255, 255, 60)
          surface.DrawTexturedRect(x, y, w, h)
          draw.NoTexture()
     end
     -- sırta doğru gölge
     for i = 0, 18 do
          surface.SetDrawColor(80, 60, 40, 3 * (18 - i))
          surface.DrawRect(x + w - 1 - i, y, 1, h)
     end
end

local function SagSayfaCiz(D, x, y, w, h)
     local t = D.secim and R.Hastalik(D.secim)
     if (!t) then
          R.Yazi("Bir hastalık seç.", "defterI", x + w / 2, y + h / 2 - 20, C.murekkepK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          R.Yazi("Hastanın bulgularını soldan işaretle; uyan sayfalar listelenir.", "defterK", x + w / 2, y + h / 2 + 6, C.murekkepK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          return
     end
     local hasta = SeciliHasta(D)
     local yol = R.Yollar[t.yol]
     local cy = y + 8
     R.Yazi(t.ad, "defterBaslik", x, cy, C.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     cy = cy + 38
     local zor = string.rep("●", t.zorluk) .. string.rep("○", 4 - t.zorluk)
     R.Yazi(string.upper(yol.ad) .. "   " .. zor, "etiket", x, cy, yol.renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     local kez = R.Benim and R.Benim.tk and tonumber(R.Benim.tk[t.id]) or 0
     if (kez > 0) then R.Yazi(kez .. " kez iyileştirdin", "etiket", x + w, cy, C.sifaK, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP) end
     cy = cy + 24

     local function Paragraf(baslik, metin, font, renk)
          if (baslik) then
               R.Yazi(baslik, "etiket", x, cy, C.murekkepK, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
               cy = cy + 17
          end
          for _, s in ipairs(R.Sar(metin, font or "defterK", w)) do
               R.Yazi(s, font or "defterK", x, cy, renk or C.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
               cy = cy + 20
          end
          cy = cy + 6
     end
     Paragraf("NEDEN", t.neden, "defterI")
     Paragraf(nil, t.aciklama)

     -- belirtiler
     R.Yazi("BELİRTİLER", "etiket", x, cy, C.murekkepK, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     cy = cy + 18
     local bx = x
     for _, b in ipairs(t.belirtiler) do
          local bel = R.Belirtiler[b]
          local var = hasta and hasta.acik[b]
          local isaret = var and "✓ " or "○ "
          local metin = isaret .. bel.ad
          local k = bel.kalinti and R.Kalintilar[bel.kalinti]
          local bw = R.YaziG(metin, "defterK") + 16
          if (bx + bw > x + w) then bx = x cy = cy + 22 end
          local renk = var and C.sifaK or C.murekkepK
          if (k) then
               surface.SetDrawColor(k.renk.r, k.renk.g, k.renk.b, 200)
               surface.DrawRect(bx, cy + 3, 6, 14)
               bx = bx + 9
          end
          R.Yazi(metin, "defterK", bx, cy, renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
          bx = bx + bw
     end
     cy = cy + 30

     -- tedavi
     R.Yazi("TEDAVİ", "etiket", x, cy, C.murekkepK, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     cy = cy + 18
     for i, a in ipairs(t.tedavi) do
          local yapildi = hasta and hasta.teshis == t.id and i <= hasta.gAdim
          if (a[1] == "buyu") then
               local renk = R.BuyuRenk(a[2])
               surface.SetDrawColor(40, 30, 20, 230)
               surface.DrawRect(x, cy, 64, 64)
               if (SA and SA.Run2D) then
                    R.Sablon(a[2])
                    SA.Run2D(a[2], x + 32, cy + 32, 24, ((RealTime() * 0.5 + i * 0.3) % 1.4), renk, 2, 255, true)
               end
               local biliyor = R.Biliyor(a[2])
               local kademe = R.Ustalik(a[2])
               R.Yazi(i .. ". " .. a[2], "defter", x + 76, cy + 2, yapildi and C.sifaK or C.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
               local durum = (biliyor and "Biliyorsun" or "Bilmiyorsun · kılavuzla çizilir") .. "  ·  ustalık: " .. R.UstalikAdlari[kademe]
               R.Yazi(durum, "kucuk", x + 76, cy + 24, biliyor and C.sifaK or C.murekkepK, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
               local sablon = R.Sablon(a[2])
               local tarif = sablon and sablon.tarif or ""
               local satir = R.Sar(tarif, "kucuk", w - 80)
               for k2, s in ipairs(satir) do
                    if (k2 > 2) then break end
                    R.Yazi(s, "kucuk", x + 76, cy + 26 + k2 * 15, C.murekkepK, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
               end
               cy = cy + 72
          else
               local e = a[1] == "esya" and R.Esya(a[2])
               R.Yazi(i .. ". " .. R.AdimYaz(a), "defter", x, cy, yapildi and C.sifaK or C.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
               if (e) then R.Yazi(e.aciklama .. "  (hastanın yanından Accio)", "kucuk", x + 14, cy + 22, C.murekkepK, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
               if (a[1] == "sevk") then R.Yazi("Hastanın yanında: Pomfrey'e sevk et", "kucuk", x + 14, cy + 22, C.murekkepK, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
               cy = cy + 44
          end
     end
     cy = cy + 4
     Paragraf("UYARI", t.uyari, "defterI", Color(130, 54, 40))
end

function R.DefterAc()
     R.DefterKapat()
     R.Fontlar()
     local W, H = math.min(1180, ScrW() - 60), math.min(740, ScrH() - 60)
     local p = vgui.Create("EditablePanel")
     defter = p
     p:SetSize(W, H)
     p:Center()
     p:MakePopup()
     p:SetKeyboardInputEnabled(true)
     surface.PlaySound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7) .. ".wav")

     local D = {secili = {}, arama = "", yol = nil, secim = nil, hasta = nil, otoSecili = {}}
     p.D = D
     local PAY = 26
     local sayfaW = (W - PAY * 2 - 30) / 2
     local solX, sagX, ustY = PAY, PAY + sayfaW + 30, PAY
     local sayfaH = H - PAY * 2

     -- ilk hasta: teşhissiz yatanlardan
     for _, h in ipairs(R.Nobet and R.Nobet.hastalar or {}) do
          if (h.durum == "yatiyor" and (!D.hasta or (h.teshis == "" and SeciliHasta(D).teshis != ""))) then D.hasta = h.id end
     end

     local sol = vgui.Create("DPanel", p)
     sol:SetPos(solX + 18, ustY + 70)
     sol:SetSize(sayfaW - 36, sayfaH - 84)
     sol.Paint = function() end

     local liste
     local Kur

     local function OtoSec()
          local h = SeciliHasta(D)
          if (!h) then return end
          for b in pairs(h.acik) do
               if (!D.otoSecili[b]) then
                    D.otoSecili[b] = true
                    D.secili[b] = true
               end
          end
     end

     local function ListeKur()
          if (IsValid(liste)) then liste:Remove() end
          local ly = sol.listeY or 200
          liste = vgui.Create("DScrollPanel", sol)
          liste:SetPos(0, ly)
          liste:SetSize(sol:GetWide(), sol:GetTall() - ly)
          local vbar = liste:GetVBar()
          vbar:SetWide(6)
          vbar.Paint = function(s, w, h) surface.SetDrawColor(120, 96, 66, 60) surface.DrawRect(0, 0, w, h) end
          vbar.btnUp.Paint, vbar.btnDown.Paint = function() end, function() end
          vbar.btnGrip.Paint = function(s, w, h) surface.SetDrawColor(110, 84, 56, 200) surface.DrawRect(0, 0, w, h) end

          local tam, kismi, n = Sonuclar(D)
          local function Satir(x, kis)
               local h = x.h
               local b = vgui.Create("DButton", liste)
               b:Dock(TOP)
               b:DockMargin(0, 0, 8, 3)
               b:SetTall(34)
               b:SetText("")
               b.Paint = function(s, w, hh)
                    local secili = D.secim == h.id
                    local ust = s:IsHovered()
                    if (secili or ust) then
                         surface.SetDrawColor(110, 84, 56, secili and 70 or 30)
                         surface.DrawRect(0, 0, w, hh)
                    end
                    local yr = R.Yollar[h.yol].renk
                    surface.SetDrawColor(yr.r, yr.g, yr.b, 255)
                    surface.DrawRect(4, 8, 4, hh - 16)
                    R.Yazi(h.ad, "defter", 16, hh / 2, kis and C.murekkepK or C.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    local sag = (n > 0 and (x.n .. "/" .. n .. "  ") or "") .. string.rep("●", h.zorluk)
                    local kez = R.Benim and R.Benim.tk and tonumber(R.Benim.tk[h.id]) or 0
                    if (kez > 0) then sag = "×" .. kez .. "   " .. sag end
                    R.Yazi(sag, "kucuk", w - 8, hh / 2, C.murekkepK, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    if (SeciliHasta(D) and SeciliHasta(D).teshis == h.id) then
                         R.Yazi("TEŞHİS", "etiket", w - 110, hh / 2, C.sifaK, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               end
               b.DoClick = function()
                    D.secim = h.id
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7) .. ".wav")
               end
          end
          for _, x in ipairs(tam) do Satir(x, false) end
          if (#tam == 0) then
               local bos = vgui.Create("DLabel", liste)
               bos:Dock(TOP)
               bos:SetTall(40)
               bos:SetFont("srv.defterI")
               bos:SetTextColor(C.murekkepK)
               bos:SetText(n > 0 and "Seçili bulguların hepsini taşıyan sayfa yok. Belki biri yanlış?" or "Uyan sayfa yok.")
               bos:SetWrap(true)
               for _, x in ipairs(kismi) do Satir(x, true) end
          end
          if (!D.secim and tam[1]) then D.secim = tam[1].h.id end
     end

     Kur = function()
          sol:Clear()
          OtoSec()
          local y = 0

          -- hasta sekmeleri
          local N = R.Nobet
          if (N and #N.hastalar > 0) then
               local x = 0
               for _, h in ipairs(N.hastalar) do
                    if (h.durum == "yatiyor" or h.durum == "geliyor") then
                         local metin = h.yatak .. " · " .. R.IlkAd(h.ad) .. (h.teshis != "" and " ✓" or "")
                         local _, w = Cip(sol, x, y, metin, function() return D.hasta == h.id end, C.sifaK, function()
                              D.hasta = h.id
                              D.otoSecili, D.secili = {}, {}
                              D.secim = h.teshis != "" and h.teshis or nil
                              Kur()
                         end)
                         x = x + w + 6
                    end
               end
               y = y + 32
          else
               local b = vgui.Create("DButton", sol)
               b:SetPos(0, y)
               b:SetSize(sol:GetWide(), 34)
               b:SetText("")
               b.Paint = function(s, w, hh)
                    surface.SetDrawColor(96, 150, 104, s:IsHovered() and 230 or 170)
                    surface.DrawRect(0, 0, w, hh)
                    local kalan = R.Benim and R.Benim.kalanHak or 1
                    R.Yazi(kalan > 0 and "Nöbete başla (gönüllü ol)" or "Bugünkü nöbet hakkın bitti", "orta", w / 2, hh / 2, C.parsomen, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               end
               b.DoClick = function()
                    R.Islem(R.ISLEM.BASLA, 0)
                    R.DefterKapat()
               end
               y = y + 44
          end

          -- hastada bulunanlar
          local h = SeciliHasta(D)
          local baslik = vgui.Create("DLabel", sol)
          baslik:SetPos(0, y)
          baslik:SetFont("srv.etiket")
          baslik:SetTextColor(C.murekkepK)
          baslik:SetText(h and ("BULGULAR · " .. string.upper(h.ad)) or "BULGULAR")
          baslik:SizeToContents()
          y = y + 20
          local x = 0
          local bulgu = {}
          for b in pairs(h and h.acik or {}) do bulgu[#bulgu + 1] = b end
          for b in pairs(D.secili) do if (!table.HasValue(bulgu, b)) then bulgu[#bulgu + 1] = b end end
          table.sort(bulgu, function(a, b) return R.Belirtiler[a].ad < R.Belirtiler[b].ad end)
          for _, b in ipairs(bulgu) do
               local bel = R.Belirtiler[b]
               local k = bel.kalinti and R.Kalintilar[bel.kalinti]
               local w = R.YaziG(bel.ad, "kucuk") + 22
               if (x + w > sol:GetWide()) then x = 0 y = y + 28 end
               Cip(sol, x, y, bel.ad, function() return D.secili[b] == true end, k and k.renk or C.murekkepK, function()
                    D.secili[b] = !D.secili[b] or nil
                    ListeKur()
               end)
               x = x + w + 5
          end
          if (#bulgu == 0) then
               local l = vgui.Create("DLabel", sol)
               l:SetPos(0, y)
               l:SetFont("srv.defterI")
               l:SetTextColor(C.murekkepK)
               l:SetText(h and "Henüz bulgu yok: hastayı dinle, muayene et, tara." or "Hasta seçili değil; aramayla gezinebilirsin.")
               l:SizeToContents()
          end
          y = y + 34

          -- yol süzgeci
          x = 0
          for _, id in ipairs(R.YolSira) do
               local yol = R.Yollar[id]
               local _, w = Cip(sol, x, y, yol.ad, function() return D.yol == id end, yol.renk, function()
                    D.yol = D.yol != id and id or nil
                    ListeKur()
               end)
               x = x + w + 5
          end
          y = y + 32

          -- arama
          local ara = vgui.Create("DTextEntry", sol)
          ara:SetPos(0, y)
          ara:SetSize(sol:GetWide(), 28)
          ara:SetFont("srv.defterK")
          ara:SetPlaceholderText("Ara: hastalık, belirti, büyü...")
          ara:SetValue(D.arama)
          ara:SetUpdateOnType(true)
          ara.OnValueChange = function(s, v)
               D.arama = v
               ListeKur()
          end
          ara.Paint = function(s, w, hh)
               surface.SetDrawColor(250, 240, 214, 255)
               surface.DrawRect(0, 0, w, hh)
               surface.SetDrawColor(120, 96, 66, 200)
               surface.DrawOutlinedRect(0, 0, w, hh, 1)
               s:DrawTextEntryText(C.murekkep, C.sifaK, C.murekkep)
               if (s:GetValue() == "" and !s:HasFocus()) then R.Yazi(s:GetPlaceholderText(), "defterK", 8, hh / 2, C.murekkepK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
          end
          y = y + 38
          sol.listeY = y
          ListeKur()
     end
     Kur()

     -- teşhis düğmesi (sağ sayfanın altı)
     local tes = vgui.Create("DButton", p)
     tes:SetSize(sayfaW - 36, 40)
     tes:SetPos(sagX + 18, ustY + sayfaH - 56)
     tes:SetText("")
     tes.Paint = function(s, w, hh)
          local h = SeciliHasta(D)
          local t = D.secim and R.Hastalik(D.secim)
          if (!h or !t or h.durum != "yatiyor") then return end
          local ayni = h.teshis == t.id
          surface.SetDrawColor(ayni and 120 or 96, ayni and 110 or 150, ayni and 90 or 104, s:IsHovered() and 240 or 190)
          surface.DrawRect(0, 0, w, hh)
          R.Yazi(ayni and ("Teşhis kondu: " .. h.ad) or ("Teşhis koy  →  " .. h.ad), "orta", w / 2, hh / 2, C.parsomen, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
     tes.DoClick = function()
          local h = SeciliHasta(D)
          local t = D.secim and R.Hastalik(D.secim)
          if (!h or !t or h.durum != "yatiyor" or h.teshis == t.id) then return end
          R.Islem(R.ISLEM.TESHIS, h.id, function() net.WriteString(t.id) end)
          surface.PlaySound("ambient/water/drip" .. math.random(1, 4) .. ".wav")
     end

     function p:Paint(w, h)
          -- deri kapak
          surface.SetDrawColor(48, 30, 20, 255)
          surface.DrawRect(0, 0, w, h)
          local m = Doku("leather_dark")
          if (m) then
               surface.SetMaterial(m)
               surface.SetDrawColor(255, 255, 255, 140)
               surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, w / 512, h / 512)
               draw.NoTexture()
          end
          surface.SetDrawColor(C.altinK.r, C.altinK.g, C.altinK.b, 120)
          surface.DrawOutlinedRect(6, 6, w - 12, h - 12, 1)
          SayfaZemin(solX, ustY, sayfaW, sayfaH)
          SayfaZemin(sagX, ustY, sayfaW, sayfaH)
          -- sırt
          surface.SetDrawColor(30, 18, 12, 255)
          surface.DrawRect(solX + sayfaW, ustY - 4, 30, sayfaH + 8)

          R.Yazi("Hastalık Defteri", "defterBaslik", solX + 18, ustY + 14, C.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
          R.Yazi("Revir · Madam Pomfrey'in notları · " .. #R.Hastaliklar .. " sayfa", "defterI", solX + 18, ustY + 46, C.murekkepK, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
          local ikon = Doku("cat_healing")
          if (ikon) then
               surface.SetMaterial(ikon)
               surface.SetDrawColor(110, 84, 56, 180)
               surface.DrawTexturedRect(solX + sayfaW - 64, ustY + 14, 44, 44)
               draw.NoTexture()
          end
          SagSayfaCiz(D, sagX + 22, ustY + 14, sayfaW - 44, sayfaH - 80)
          R.Yazi("Esc: kapat", "kucuk", w - 30, h - 13, C.altinK, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     end

     function p:OnKeyCodePressed(kod)
          if (kod == KEY_ESCAPE or kod == KEY_E) then R.DefterKapat() end
     end

     function p:Think()
          if (gui.IsGameUIVisible()) then return R.DefterKapat() end
          local h = R.Harita
          if (h and LocalPlayer():GetPos():DistToSqr(h.defter.pos) > 300 * 300) then R.DefterKapat() end
     end

     -- nöbet değişince sol sayfayı tazele
     hook.Add("SardonRevirNobet", p, function()
          if (IsValid(p)) then Kur() end
     end)
end
