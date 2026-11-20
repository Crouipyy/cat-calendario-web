-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_8ders.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: ders — profesör tarafı
--   L menüsü: "Asa Hareketini Denetle" (bakılan öğrenci; profesör büyüyü seçer)
--   Ders eşyası C menüsü ([sardon] dersesya, kanca SardonDersEsyaPanel): "Tüm sınıf asa hareketi yapsın",
--   "Sayfa açtır", kitapsız gelenler ve her biri için −1 hane puanı kararı.
--   Sunucu yetkiyi ayrıca denetler (sv_5ders SK.DersProfesoru).

local SK = SardonKitap
local R = SK.R

SK.DersVeri = SK.DersVeri or nil
SK.DersVeriSurum = SK.DersVeriSurum or 0

local function DersIstek(islem, yaz)
     net.Start("SardonKitap.Ders")
     net.WriteString(islem)
     if yaz then yaz() end
     net.SendToServer()
end
SK.DersIstek = DersIstek

net.Receive("SardonKitap.DersVeri", function()
     local v = {ders = net.ReadString(), kitaplar = {}, kitapsiz = {}}
     for i = 1, net.ReadUInt(5) do v.kitaplar[i] = net.ReadString() end
     for i = 1, net.ReadUInt(8) do
          v.kitapsiz[i] = {ent = net.ReadEntity(), charid = net.ReadUInt(32), ad = net.ReadString(), dusulen = net.ReadBool()}
     end
     v.acemi = net.ReadTable()
     SK.DersVeri = v
     SK.DersVeriSurum = SK.DersVeriSurum + 1
end)

/*
*   seçici pencere (büyü / sayfa)
*/
local function Pencere(baslik, w, h)
     SK.Fontlar()
     if IsValid(SK.Secici) then SK.Secici:Remove() end
     local f = vgui.Create("EditablePanel")
     f:SetSize(SK.S(w), SK.S(h))
     f:Center()
     f:MakePopup()
     f.Paint = function(s, pw, ph)
          SK.Kutu(0, 0, pw, ph, R.hud)
          surface.SetDrawColor(R.hudCizgi) surface.DrawOutlinedRect(0, 0, pw, ph, 1)
          SK.Yazi(baslik, "hud", SK.S(16), SK.S(14), R.hudYazi)
          SK.Yazi("Esc · kapat", "ust", pw - SK.S(16), SK.S(18), R.hudSoluk, TEXT_ALIGN_RIGHT)
     end
     f.OnKeyCodePressed = function(s, k) if k == KEY_ESCAPE then s:Remove() end end
     SK.Secici = f
     return f
end

local function Satir(parent, metin, alt, fn, vurgu)
     local b = parent:Add("DButton")
     b:Dock(TOP)
     b:DockMargin(0, 0, SK.S(6), SK.S(4))
     b:SetTall(SK.S(alt and 40 or 30))
     b:SetText("")
     b.Paint = function(s, pw, ph)
          SK.Kutu(0, 0, pw, ph, s:IsHovered() and Color(196, 156, 74, 40) or Color(255, 255, 255, 8))
          if vurgu then SK.Kutu(0, 0, SK.S(3), ph, R.altin) end
          SK.Yazi(metin, "hudK", SK.S(12), alt and SK.S(5) or ph / 2, R.hudYazi, TEXT_ALIGN_LEFT, alt and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
          if alt then SK.Yazi(alt, "ust", SK.S(12), SK.S(23), R.hudSoluk) end
     end
     b.DoClick = function() surface.PlaySound("buttons/button14.wav") fn() end
     return b
end

-- büyü seçici: sınıftakilerin acemi büyüleri üstte (sayısıyla), sonra Büyü Ağacı'ndaki bütün büyüler
function SK.BuyuSec(baslik, fn)
     local f = Pencere(baslik, 440, 560)
     local ara = vgui.Create("DTextEntry", f)
     ara:SetPos(SK.S(16), SK.S(44))
     ara:SetSize(f:GetWide() - SK.S(32), SK.S(28))
     ara:SetPlaceholderText("Büyü ara…")
     ara:SetFont("sk.hudK")
     local liste = vgui.Create("DScrollPanel", f)
     liste:SetPos(SK.S(16), SK.S(80))
     liste:SetSize(f:GetWide() - SK.S(32), f:GetTall() - SK.S(96))

     local function Kur()
          liste:Clear()
          local q = SK.Kucuk(ara:GetValue() or "")
          local acemi = SK.DersVeri and SK.DersVeri.acemi or {}
          local gorulen = {}
          local function Uyar(ad) return q == "" or string.find(SK.Kucuk(ad), q, 1, true) end
          for buyu, n in SortedPairsByValue(acemi, true) do
               if Uyar(buyu) then
                    gorulen[buyu] = true
                    Satir(liste, buyu, n .. " öğrencide acemi", function() f:Remove() fn(buyu) end, true)
               end
          end
          local hepsi = {}
          local BA = SardonBuyuAgaci
          for _, agac in ipairs(BA and BA.Agaclar or {}) do
               for _, d in ipairs(agac.dugumler or {}) do
                    if not gorulen[d.buyu] and SK.BuyuVar(d.buyu) then
                         gorulen[d.buyu] = true
                         hepsi[#hepsi + 1] = {d.buyu, agac.ad, d.kademe}
                    end
               end
          end
          table.sort(hepsi, function(a, b) if a[3] ~= b[3] then return a[3] < b[3] end return a[1] < b[1] end)
          for _, h in ipairs(hepsi) do
               if Uyar(h[1]) then
                    local kad = BA.Kademeler and BA.Kademeler[h[3]] and BA.Kademeler[h[3]].kisa or ""
                    Satir(liste, h[1], h[2] .. " · " .. kad, function() f:Remove() fn(h[1]) end)
               end
          end
     end
     ara.OnChange = Kur
     Kur()
     f.surum = SK.DersVeriSurum
     f.Think = function(s) if s.surum ~= SK.DersVeriSurum then s.surum = SK.DersVeriSurum Kur() end end
end

-- sayfa seçici: dersin kitapları üstte, sonra birinci yıl kitapları; kitaba tıklayınca bölümler
function SK.SayfaSec(fn)
     local f = Pencere("Sayfa açtır", 460, 560)
     local liste = vgui.Create("DScrollPanel", f)
     liste:SetPos(SK.S(16), SK.S(48))
     liste:SetSize(f:GetWide() - SK.S(32), f:GetTall() - SK.S(64))

     local function Kitaplar()
          liste:Clear()
          local gorulen = {}
          for _, id in ipairs(SK.DersVeri and SK.DersVeri.kitaplar or {}) do
               local k = SK.Kitap[id]
               if k and not gorulen[id] then
                    gorulen[id] = true
                    Satir(liste, k.ad, "Bu dersin kitabı", function() f.Bolumler(id) end, true)
               end
          end
          for _, k in ipairs(SK.KITAPLAR) do
               if not gorulen[k.id] then Satir(liste, k.ad, k.yazar, function() f.Bolumler(k.id) end) end
          end
     end
     f.Bolumler = function(id)
          liste:Clear()
          Satir(liste, "‹ kitaplara dön", nil, Kitaplar)
          for i, b in ipairs(SK.Bolumler(id)) do
               Satir(liste, i .. ". " .. b.baslik, b.buyu and ("büyü: " .. b.buyu) or nil, function() f:Remove() fn(id, b.id) end)
          end
     end
     Kitaplar()
end

/*
*   ders eşyası C menüsüne bölüm
*/
hook.Add("SardonDersEsyaPanel", "SardonKitap.Ders", function(pnl, scroll, Y)
     if not Y or not Y.Bolum or not Y.Buton then return end
     DersIstek("veri")
     Y.Bolum(scroll, "Ders Kitabı · Asa Denetimi")

     local kutu = scroll:Add("DPanel")
     kutu:Dock(TOP)
     kutu:DockMargin(0, 0, 8, 4)
     kutu.Paint = nil
     kutu.surum = -1

     local function Kur()
          kutu:Clear()
          local v = SK.DersVeri
          local h = 0
          local function Ekle(yuk)
               local p = kutu:Add("DPanel")
               p:Dock(TOP)
               p:DockMargin(0, 0, 0, 4)
               p:SetTall(yuk)
               p.Paint = nil
               h = h + yuk + 4
               return p
          end
          local b1 = Y.Buton(Ekle(28), "Tüm sınıf asa hareketi yapsın…", false, function()
               SK.BuyuSec("Tüm sınıf hangi büyüyü çizsin?", function(buyu)
                    DersIstek("denetim", function() net.WriteString(buyu) net.WriteBool(true) net.WriteEntity(NULL) end)
               end)
          end)
          b1:Dock(FILL)
          local b2 = Y.Buton(Ekle(28), "Sayfa açtır…", false, function()
               SK.SayfaSec(function(kitap, bolum)
                    DersIstek("sayfa", function() net.WriteString(kitap) net.WriteString(bolum) end)
               end)
          end)
          b2:Dock(FILL)

          if v and #v.kitapsiz > 0 then
               local bas = Ekle(18)
               bas.Paint = function(_, w, hh)
                    draw.SimpleText("Kitapsız gelenler (" .. #v.kitapsiz .. ")", "SardonDE_Kucuk", 0, hh / 2, Y.C and Y.C.muted or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
               for _, o in ipairs(v.kitapsiz) do
                    local s = Ekle(26)
                    s.Paint = function(_, w, hh)
                         surface.SetDrawColor(Y.C and Y.C.card or Color(19, 28, 40))
                         surface.DrawRect(0, 0, w, hh)
                         draw.SimpleText(o.ad, "SardonDE_Yazi", 8, hh / 2, Y.C and Y.C.text or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    if o.dusulen then
                         local l = s:Add("DLabel")
                         l:Dock(RIGHT) l:SetWide(90) l:SetFont("SardonDE_Kucuk") l:SetText("−1 düşüldü")
                         l:SetTextColor(Y.C and Y.C.faint or color_white)
                    else
                         local b = Y.Buton(s, "−1 hane puanı", true, function()
                              DersIstek("hane", function() net.WriteEntity(o.ent) end)
                         end)
                         b:Dock(RIGHT) b:DockMargin(0, 3, 3, 3) b:SetWide(100)
                    end
               end
          elseif v then
               local l = Ekle(18)
               l.Paint = function(_, w, hh)
                    local m = #v.kitaplar == 0 and "Bu dersin bir kitabı yok." or "Herkesin kitabı yanında."
                    draw.SimpleText(m, "SardonDE_Kucuk", 0, hh / 2, Y.C and Y.C.faint or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
          end
          kutu:SetTall(h)
     end
     kutu.Think = function(s)
          if s.surum ~= SK.DersVeriSurum then
               s.surum = SK.DersVeriSurum
               Kur()
          end
     end
     Kur()
end)

/*
*   L menüsü
*/
local function LKaydet()
     SardonLMenu = SardonLMenu or {}
     SardonLMenu["Asa Hareketini Denetle"] = {
          Aciklama = "Profesör: öğrenci seçtiğin büyünün rününü havada çizsin",
          Sira = 62,
          Filter = function(hedef)
               local D = SardonDersEsya
               return IsValid(hedef) and hedef:IsPlayer() and D ~= nil and D.Yetkili ~= nil and D.Yetkili(LocalPlayer()) and (D.DersVar == nil or D.DersVar())
          end,
          Do = function(hedef)
               DersIstek("veri")
               SK.BuyuSec((IsValid(hedef) and hedef:Nick() or "Öğrenci") .. " hangi büyüyü çizsin?", function(buyu)
                    if not IsValid(hedef) then return end
                    DersIstek("denetim", function() net.WriteString(buyu) net.WriteBool(false) net.WriteEntity(hedef) end)
               end)
          end,
     }
end
LKaydet()
hook.Add("InitPostEntity", "SardonKitap.LMenu", LKaydet)
timer.Simple(10, LKaydet)
