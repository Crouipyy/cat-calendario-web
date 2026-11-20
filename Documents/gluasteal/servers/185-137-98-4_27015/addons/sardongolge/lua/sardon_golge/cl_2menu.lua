-- "addons\\sardongolge\\lua\\sardon_golge\\cl_2menu.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gölge :: istemci — hançerin sağ tık menüsü: kopya kartı (önizleme, ad, hane, tarih, kalan süre; Kılığa
-- bürün / Eski hâline dön) ve eski 5 hane kılığı (yalnız Snatcher / Karanlık Büyücü; sabit model + elle yazılan ad).
local S = SardonGolge
local R = S.Renk

local HANELER = {
     { "slytherin", "Slytherin Öğrencisi", Color(28, 104, 66) },
     { "gryffindor", "Gryffindor Öğrencisi", Color(124, 34, 28) },
     { "ravenclaw", "Ravenclaw Öğrencisi", Color(30, 62, 120) },
     { "hufflepuff", "Hufflepuff Öğrencisi", Color(150, 112, 30) },
     { "genelprof", "Profesör", Color(150, 92, 40) },
}

local function HaneIzni(ply)
     local f = S.Fraksiyon(ply)
     return f == "snatcher" or f == "deatheaterr"
end

local function Dugme(ust, metin, renk, tikla)
     local b = vgui.Create("DButton", ust)
     b:SetText("")
     b.metin = metin
     b.renk = renk or R.cerceve
     b.Paint = function(s, w, h)
          local acik = s:IsEnabled()
          local zemin = acik and (s:IsHovered() and Color(s.renk.r, s.renk.g, s.renk.b, 230) or Color(s.renk.r, s.renk.g, s.renk.b, 150)) or Color(60, 56, 64, 120)
          draw.RoundedBox(4, 0, 0, w, h, zemin)
          draw.SimpleText(s.metin, "SardonGolge.Yazi", w / 2, h / 2, acik and R.kagit or R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
     b.DoClick = function(s)
          surface.PlaySound("ui/buttonclick.wav")
          tikla(s)
     end
     return b
end

local function Giris(ust, yer, deger, cokSatir)
     local e = vgui.Create("DTextEntry", ust)
     e:SetFont("SardonGolge.Yazi")
     e:SetPlaceholderText(yer)
     e:SetText(deger or "")
     e:SetMultiline(cokSatir == true)
     e:SetTextColor(R.kagit)
     e:SetCursorColor(R.altin)
     e:SetPaintBackground(false)
     e.Paint = function(s, w, h)
          draw.RoundedBox(4, 0, 0, w, h, Color(10, 8, 12, 220))
          surface.SetDrawColor(R.cerceve.r, R.cerceve.g, R.cerceve.b, s:HasFocus() and 220 or 90)
          surface.DrawOutlinedRect(0, 0, w, h, 1)
          s:DrawTextEntryText(R.kagit, R.altin, R.kagit)
          if s:GetText() == "" and not s:HasFocus() then
               draw.SimpleText(yer, "SardonGolge.Kucuk", 8, cokSatir and 8 or h / 2, R.soluk, TEXT_ALIGN_LEFT, cokSatir and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
          end
     end
     return e
end

-- kopyanın önizlemesi: öğrenci ayarlarından giydirilir ([sardon] ogrenci KayitGiydir + ParcaCiz)
local function Onizleme(ust, k)
     local m = vgui.Create("DModelPanel", ust)
     m:SetMouseInputEnabled(false)
     m.LayoutEntity = function(_, ent) ent:SetAngles(Angle(0, 20 + math.sin(RealTime() * 0.6) * 12, 0)) end
     m.PostDrawModel = function(_, ent)
          if ent.sogS and SardonOgrenci and SardonOgrenci.ParcaCiz then SardonOgrenci.ParcaCiz(ent) end
     end
     m:SetModel(k.s and HLStudents and HLStudents.ModelFor and HLStudents.ModelFor(k.s.gender == "f" and "f" or "m", k.s.face) or k.model)
     local ent = m.Entity
     if IsValid(ent) then
          if k.s and SardonOgrenci and SardonOgrenci.KayitGiydir and HLStudents and HLStudents.EncodeGear then
               local d = table.Copy(k.s)
               d.ifade, d.vucut = k.s.sogIfade, k.s.sogVucut
               local ok = pcall(SardonOgrenci.KayitGiydir, ent, { d = d, kod = HLStudents.EncodeGear(k.s) })
               if not ok then ent.sogElle = true end
          else
               ent.sogElle = true
               ent:SetSkin(k.skin or 0)
               for id, v in pairs(k.bg or {}) do ent:SetBodygroup(tonumber(id) or 0, tonumber(v) or 0) end
          end
          local seq = ent:LookupSequence("idle_all_01")
          if seq and seq > 0 then ent:ResetSequence(seq) end
          local mn, mx = ent:GetRenderBounds()
          local boy = math.max(40, mx.z - mn.z)
          m:SetLookAt(Vector(0, 0, boy * 0.55))
          m:SetCamPos(Vector(boy * 1.35, 0, boy * 0.62))
          m:SetFOV(34)
     end
     return m
end

function S.MenuAc()
     if IsValid(S.Menu) then S.Menu:Remove() end
     local ply = LocalPlayer()
     local char = ply:GetCharacter()
     if not char then return end
     S.Iste(S.ISTEK.DURUM)

     local hane = HaneIzni(ply)
     local W, H = 640, hane and 560 or 340
     local f = vgui.Create("DFrame")
     S.Menu = f
     f:SetSize(W, H)
     f:Center()
     f:SetTitle("")
     f:ShowCloseButton(false)
     f:SetDraggable(true)
     f:MakePopup()
     f.Paint = function(_, w, h)
          draw.RoundedBox(8, 0, 0, w, h, R.zemin)
          surface.SetDrawColor(R.cerceve.r, R.cerceve.g, R.cerceve.b, 200)
          surface.DrawOutlinedRect(0, 0, w, h, 1)
          surface.SetDrawColor(R.cerceve.r, R.cerceve.g, R.cerceve.b, 70)
          surface.DrawOutlinedRect(4, 4, w - 8, h - 8, 1)
          draw.SimpleText("GERÇEKLİK HANÇERİ", "SardonGolge.Baslik", 24, 26, R.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          draw.SimpleText("Hançer: " .. S.HancerSay(char), "SardonGolge.Kucuk", w - 60, 26, R.soluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     end
     f.OnKeyCodePressed = function(s, tus) if tus == KEY_ESCAPE then s:Remove() end end

     local kapat = Dugme(f, "×", Color(90, 70, 70), function() f:Remove() end)
     kapat:SetPos(W - 44, 12)
     kapat:SetSize(28, 28)

     -- Kopya kartı
     local kart = vgui.Create("DPanel", f)
     kart:SetPos(16, 52)
     kart:SetSize(W - 32, 270)
     local k = char:GetData("gerceklik")
     k = istable(k) and isstring(k.model) and k or nil
     kart.Paint = function(_, w, h)
          draw.RoundedBox(6, 0, 0, w, h, R.zeminAcik)
          local x = k and 210 or 20
          if not k then
               draw.SimpleText("Hançerde bir görünüm yok.", "SardonGolge.Baslik", w / 2, h / 2 - 14, R.kagit, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               draw.SimpleText("Birine sapladığında görünüşü hançere geçer; yenisi eskisini siler.", "SardonGolge.Kucuk", w / 2, h / 2 + 14, R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               return
          end
          local fr = ix.faction.Get(k.fraksiyon or "")
          draw.SimpleText(k.ad or "?", "SardonGolge.Baslik", x, 28, R.kagit, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          draw.SimpleText(fr and L(fr.name) or "Bilinmeyen", "SardonGolge.Yazi", x, 54, fr and fr.color or R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          draw.SimpleText("Saplandı: " .. os.date("%d.%m.%Y %H:%M", k.zaman or os.time()), "SardonGolge.Kucuk", x, 80, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

          local d = S.Durum
          local yazi, renk
          if d.aktif and ply:GetNW2Bool("GolgeKilik", false) then
               yazi, renk = "Kılıktasın  ·  kalan " .. S.Sure(S.Kalan("kalan")), R.mor
          elseif S.Kalan("bekle") > 0 then
               yazi, renk = "Hançer güç topluyor  ·  " .. S.Sure(S.Kalan("bekle")), R.kirmizi
          else
               yazi, renk = "Kılığa hazır  ·  süre " .. S.Sure(S.Kalan("kalan") > 0 and S.Kalan("kalan") or S.Ayar.KilikSure), R.yesil
          end
          draw.SimpleText(yazi, "SardonGolge.Yazi", x, 112, renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          local not1 = "Ölünce, Finite ya da Homenum Revelio ile kılık düşer."
          draw.SimpleText(not1, "SardonGolge.Kucuk", x, 140, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          draw.SimpleText("Sesin kendi sesin olarak kalır.", "SardonGolge.Kucuk", x, 160, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end
     if k then
          local m = Onizleme(kart, k)
          m:SetPos(10, 10)
          m:SetSize(180, 250)

          local bur = Dugme(kart, "Kılığa bürün", Color(96, 64, 150), function() S.Iste(S.ISTEK.DONUS) f:Remove() end)
          bur:SetPos(210, 206)
          bur:SetSize(180, 40)
          bur.Think = function(s) s:SetEnabled(not ply:GetNW2Bool("GolgeKilik", false) and S.Kalan("bekle") <= 0) end
     end
     local geri = Dugme(kart, "Eski hâline dön", Color(110, 84, 54), function() S.Iste(S.ISTEK.GERI) f:Remove() end)
     geri:SetPos(k and 400 or (W - 32) / 2 - 90, k and 206 or 210)
     geri:SetSize(180, 40)
     geri.Think = function(s) s:SetEnabled(ply:GetNWString("FakeFaction", "") ~= "") end

     if not hane then return f end

     -- Eski hane kılığı
     local alt = vgui.Create("DPanel", f)
     alt:SetPos(16, 334)
     alt:SetSize(W - 32, H - 334 - 16)
     alt.Paint = function(_, w, h)
          draw.RoundedBox(6, 0, 0, w, h, R.zeminAcik)
          draw.SimpleText("Hane kılığı", "SardonGolge.Yazi", 14, 18, R.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          draw.SimpleText("Hazır bir öğrenci ya da profesör görünümü; adını ve açıklamanı sen yazarsın.", "SardonGolge.Kucuk", 14, 38, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end
     local ad = Giris(alt, "Görünecek ad", ply:GetData("Gerceklik.Name", ""))
     ad:SetPos(14, 54)
     ad:SetSize(alt:GetWide() - 28, 30)
     local acik = Giris(alt, "Görünecek açıklama", ply:GetData("Gerceklik.Desc", ""), true)
     acik:SetPos(14, 90)
     acik:SetSize(alt:GetWide() - 28, 52)

     local bw = math.floor((alt:GetWide() - 28 - 4 * 6) / 5)
     for i, h in ipairs(HANELER) do
          local b = Dugme(alt, h[2], h[3], function()
               S.Iste(S.ISTEK.HANE, function()
                    net.WriteString(h[1])
                    net.WriteString(ad:GetText())
                    net.WriteString(acik:GetText())
               end)
               f:Remove()
          end)
          b:SetPos(14 + (i - 1) * (bw + 6), 152)
          b:SetSize(bw, 34)
          b.metin = string.gsub(h[2], " Öğrencisi", "")
     end
     return f
end

----------------------------------------------------------------------------------------
-- Gölge'nin mal tezgâhı (sv_3golge S.MalAc, net "SardonGolge.Mal"): Shine Admin'den konan eşyalar. Diyalogdaki
-- "Başka neler var?" seçilince açılır; kapatınca sunucuya bildirilir (bir şey alındıysa Gölge ışınlanır).
----------------------------------------------------------------------------------------
local function MalIste(t)
     net.Start("SardonGolge.Mal")
     net.WriteString(util.TableToJSON(t))
     net.SendToServer()
end

local function Kisalt(metin, font, w)
     surface.SetFont(font)
     if surface.GetTextSize(metin) <= w then return metin end
     local n = utf8.len(metin) or #metin
     while n > 1 do
          n = n - 1
          local k = metin:utf8sub(1, n) .. "…"
          if surface.GetTextSize(k) <= w then return k end
     end
     return metin
end

local function MalKart(ust, m, para, w)
     local it = ix.item.list[m.esya]
     local ad = (m.ad or "") ~= "" and m.ad or (it and isstring(it.name) and it.name) or m.esya
     local acik = (m.soz or "") ~= "" and ("“" .. m.soz .. "”") or (it and isstring(it.description) and it.description) or ""
     local kart = vgui.Create("DPanel", ust)
     kart:SetTall(100)
     kart:Dock(TOP)
     kart:DockMargin(0, 0, 0, 8)
     kart.Paint = function(_, pw, ph)
          draw.RoundedBox(6, 0, 0, pw, ph, R.zeminAcik)
          local yaziW = pw - 96 - 150
          draw.SimpleText(Kisalt(ad, "SardonGolge.Baslik", yaziW), "SardonGolge.Baslik", 96, 22, R.kagit, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          draw.SimpleText(Kisalt(string.gsub(acik, "\n", " "), "SardonGolge.Kucuk", yaziW), "SardonGolge.Kucuk", 96, 48, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          local stok = m.stok < 0 and "Stok bol" or (m.stok > 0 and ("Bu hafta kalan: " .. m.stok) or "Bu hafta kalmadı")
          local kisi = m.kisi < 0 and "" or ("   ·   senin hakkın: " .. m.kisi)
          draw.SimpleText(stok .. kisi, "SardonGolge.Kucuk", 96, 74, m.stok == 0 and R.kirmizi or R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          draw.SimpleText(string.Comma(m.fiyat) .. " G", "SardonGolge.Baslik", pw - 140, 26, para >= m.fiyat and R.altin or R.kirmizi, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     end
     local ikon = vgui.Create("SpawnIcon", kart)
     ikon:SetPos(12, 14)
     ikon:SetSize(72, 72)
     ikon:SetModel(it and it.model or "models/props_junk/cardboard_box004a.mdl", it and it.skin or 0)
     ikon:SetMouseInputEnabled(false)

     local al = Dugme(kart, "Satın al", Color(96, 64, 150), function(s)
          if s.onay and RealTime() < s.onay then
               s.onay, s.metin = nil, "Satın al"
               MalIste({ islem = "al", id = m.id })
          else
               s.onay, s.metin = RealTime() + 3, "Emin misin?"
          end
     end)
     al:SetPos(w - 132, 50)
     al:SetSize(120, 38)
     al.Think = function(s)
          s:SetEnabled(m.stok ~= 0 and m.kisi ~= 0 and para >= m.fiyat)
          if s.onay and RealTime() > s.onay then s.onay, s.metin = nil, "Satın al" end
     end
     return kart
end

function S.MalPanel(t)
     local eski = IsValid(S.MalMenu) and S.MalMenu
     local kaydirma = eski and IsValid(eski.liste) and eski.liste:GetVBar():GetScroll() or 0
     local x, y
     if eski then x, y = eski:GetPos() eski.sunucuKapatti = true eski:Remove() end

     local mallar = t.mallar or {}
     local para = tonumber(t.para) or 0
     local W = 640
     local H = math.Clamp(92 + math.max(1, #mallar) * 108 + 20, 220, ScrH() - 120)
     local f = vgui.Create("DFrame")
     S.MalMenu = f
     f:SetSize(W, H)
     if x then f:SetPos(x, y) else f:Center() end
     f:SetTitle("")
     f:ShowCloseButton(false)
     f:SetDraggable(true)
     f:MakePopup()
     f.Paint = function(_, w, h)
          draw.RoundedBox(8, 0, 0, w, h, R.zemin)
          surface.SetDrawColor(R.cerceve.r, R.cerceve.g, R.cerceve.b, 200)
          surface.DrawOutlinedRect(0, 0, w, h, 1)
          surface.SetDrawColor(R.cerceve.r, R.cerceve.g, R.cerceve.b, 70)
          surface.DrawOutlinedRect(4, 4, w - 8, h - 8, 1)
          draw.SimpleText("GÖLGE'NİN TEZGÂHI", "SardonGolge.Baslik", 24, 28, R.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          draw.SimpleText("Kesende: " .. string.Comma(para) .. " G", "SardonGolge.Yazi", w - 60, 28, R.kagit, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          draw.SimpleText("Satın almak için iki kez tıkla. Burada uzun durma; birileri bakıyor olabilir.", "SardonGolge.Kucuk", 24, 56, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          if #mallar == 0 then
               draw.SimpleText("Tezgâhta şu an sana göre bir şey yok.", "SardonGolge.Yazi", w / 2, h / 2 + 20, R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     end
     f.OnRemove = function(s)
          if not s.sunucuKapatti then MalIste({ islem = "kapat" }) end
     end

     local kapat = Dugme(f, "×", Color(90, 70, 70), function() f:Remove() end)
     kapat:SetPos(W - 44, 14)
     kapat:SetSize(28, 28)

     local liste = vgui.Create("DScrollPanel", f)
     f.liste = liste
     liste:SetPos(16, 76)
     liste:SetSize(W - 32, H - 76 - 16)
     local bar = liste:GetVBar()
     bar:SetWide(6)
     bar.Paint = function(_, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(0, 0, 0, 90)) end
     bar.btnUp.Paint, bar.btnDown.Paint = function() end, function() end
     bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(3, 0, 0, w, h, R.cerceve) end
     for _, m in ipairs(mallar) do MalKart(liste, m, para, W - 32 - 10) end
     timer.Simple(0, function() if IsValid(liste) then liste:GetVBar():SetScroll(kaydirma) end end)
     return f
end

net.Receive("SardonGolge.Mal", function()
     local t = util.JSONToTable(net.ReadString() or "") or {}
     if t.islem == "kapat" then
          if IsValid(S.MalMenu) then
               S.MalMenu.sunucuKapatti = true
               S.MalMenu:Remove()
          end
          return
     end
     if t.islem == "guncel" and not IsValid(S.MalMenu) then return end
     S.MalPanel(t)
end)
