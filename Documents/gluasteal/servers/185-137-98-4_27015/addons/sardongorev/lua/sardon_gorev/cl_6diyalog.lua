-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_6diyalog.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Diyalog arayüzü, altyazılar, anlatıcı ve görev veren teklif penceresi.
*
*   Sinematik kip: sinema şeritleri, alt şeritte konuşanın adı + söz (daktilo), seçenekler
*   fareyle ya da 1-4 tuşlarıyla. Boşluk / E / sol tık sözü geçer.
*   Serbest kip: oyuncu yürür; söz altyazı, seçenekler sağda, 1-4 tuşlarıyla.
*/
local G = SardonGorev
local R, O, F = G.R, G.O, G.F

G.Diy = G.Diy or nil
G.Altyazilar = G.Altyazilar or {}

function G.DiyalogAcik() return G.Diy ~= nil end

/*
*   Altyazılar
*/
function G.AltyaziEkle(t)
     t.bas = RealTime()
     t.sure = t.sure or 4
     table.insert(G.Altyazilar, t)
     while #G.Altyazilar > 3 do table.remove(G.Altyazilar, 1) end
end

local function IsimRengi(renk)
     if istable(renk) then
          return Color(renk[1] or renk.r or 232, renk[2] or renk.g or 219, renk[3] or renk.b or 182)
     end
     return R.altinAcik
end

local function AltyaziCiz()
     local simdi = RealTime()
     for i = #G.Altyazilar, 1, -1 do
          local a = G.Altyazilar[i]
          if simdi - a.bas > a.sure + 0.4 then table.remove(G.Altyazilar, i) end
     end
     if #G.Altyazilar == 0 then return end
     if G.Diy and G.Diy.kip == "sinematik" then return end

     local cx = ScrW() / 2
     local y = ScrH() - O(190)
     local font = F(20, "kalin")
     for i = #G.Altyazilar, math.max(1, #G.Altyazilar - 1), -1 do
          local a = G.Altyazilar[i]
          local gecen = simdi - a.bas
          local alfa = math.min(G.Yumusak(gecen / 0.2), G.Yumusak((a.sure + 0.4 - gecen) / 0.4))
          if i < #G.Altyazilar then alfa = alfa * 0.55 end

          local on = (a.ad and a.ad ~= "") and (a.ad .. ":  ") or ""
          local satirlar = G.Sar(on .. (a.metin or ""), font, O(980))
          for j = #satirlar, 1, -1 do
               local s = satirlar[j]
               if j == 1 and on ~= "" and string.sub(s, 1, #on) == on then
                    local w1 = G.Genislik(on, font)
                    local w2 = G.Genislik(string.sub(s, #on + 1), font)
                    local x0 = cx - (w1 + w2) / 2
                    G.Yaz(on, font, x0, y, IsimRengi(a.renk), 0, nil, 1, alfa)
                    G.Yaz(string.sub(s, #on + 1), font, x0 + w1, y, R.fildisiAcik, 0, nil, 1, alfa)
               else
                    G.Yaz(s, font, cx, y, R.fildisiAcik, 1, nil, 1, alfa)
               end
               y = y - O(27)
          end
          y = y - O(8)
     end
end

/*
*   Anlatıcı (ekranın ortasında italik)
*/
local anlatici

local function AnlaticiCiz()
     local t = anlatici
     if not t then return end
     local gecen = RealTime() - t.bas
     if gecen > t.sure + 0.6 then anlatici = nil return end
     local a = math.min(G.Yumusak(gecen / 0.6), G.Yumusak((t.sure + 0.6 - gecen) / 0.6))
     local font = F(24, "italik")
     local satirlar = G.Sar(t.metin, font, O(900))
     local y = ScrH() * 0.62 - #satirlar * O(16)
     for _, s in ipairs(satirlar) do
          G.Yaz(s, font, ScrW() / 2, y, R.fildisiAcik, 1, nil, 1, a)
          y = y + O(32)
     end
end

/*
*   Diyalog
*/
local function Istek(kod, yaz) G.Iste(kod, yaz) end

local function Sec(j)
     local d = G.Diy
     if not d or not d.secim or d.secim.secildi then return end
     local s = d.secim.secenekler[j]
     if not s then return end
     d.secim.secildi = j
     G.Cal("secim")
     Istek(G.ISTEK.SECIM, function()
          net.WriteUInt(d.gorev or 0, 32)
          net.WriteUInt(j, 8)
     end)
end

local sonAtla = 0
local function Atla()
     local d = G.Diy
     if not d or not d.satir or d.satir.gecilmez or RealTime() < sonAtla then return end
     sonAtla = RealTime() + 0.35
     -- önce daktiloyu tamamla, ikinci basışta sözü geç
     if not d.satir.tam then
          d.satir.tam = true
          return
     end
     if IsValid(d.kanal) then d.kanal:Stop() end
     local c = d.satir.aktor and G.Aktorler[d.satir.aktor]
     if c and IsValid(c.kanal) then c.kanal:Stop() end
     Istek(G.ISTEK.ATLA, function() net.WriteUInt(d.gorev or 0, 32) end)
end

local function Fare(ac)
     if G.Diy then G.Diy.fare = ac end
     gui.EnableScreenClicker(ac and true or false)
end

net.Receive("SardonGorev.Diyalog", function()
     local tur = net.ReadString()
     local t = G.OkuTablo()

     if tur == "basla" then
          G.Diy = { kip = t.kip, aktor = t.aktor, kamera = t.kamera, gorev = t.gorev, bas = RealTime() }
     elseif tur == "satir" then
          local d = G.Diy
          if not d then return end
          d.secim = nil
          if d.fare then Fare(false) end
          d.satir = { kim = t.kim, aktor = t.aktor, ad = t.ad, unvan = t.unvan, renk = t.renk, metin = t.metin or "", sure = t.sure or 3, gecilmez = t.gecilmez, bas = RealTime() }
          if d.kip ~= "sinematik" then
               G.AltyaziEkle({ ad = t.kim == "anlatici" and "" or t.ad, renk = t.kim == "oyuncu" and { 168, 196, 214 } or t.renk, metin = t.metin, sure = t.sure })
          end
          -- oyuncu / anlatıcı sesi 2B
          if t.ses and t.ses ~= "" then
               G.SesCal(t.ses, nil, { oncelik = true, zorla = true, cb = function(k) if G.Diy == d then d.kanal = k end end })
          end
     elseif tur == "secim" then
          local d = G.Diy
          if not d then return end
          d.secim = { secenekler = t.secenekler or {}, bas = RealTime() }
          d.satir = d.satir and d.kip == "sinematik" and d.satir or nil
          if d.kip == "sinematik" then Fare(true) end
          G.Cal("ustune")
     elseif tur == "secildi" then
          local d = G.Diy
          if d and d.secim then d.secim.secildi = t.j end
          if d and d.fare then Fare(false) end
     elseif tur == "bitir" then
          if G.Diy and G.Diy.fare then Fare(false) end
          G.Diy = nil
     elseif tur == "anlatici" then
          anlatici = { metin = t.metin or "", sure = t.sure or 4, bas = RealTime() }
          if t.ses and t.ses ~= "" then G.SesCal(t.ses, nil, { oncelik = true, zorla = true }) end
     elseif tur == "teklif" then
          G.TeklifAc(t)
     end
end)

/*
*   Seçenek numarası: slotN bağı ya da fiziksel 1-9 (üst sıra / numpad). Oyuncu Ayarlar › Tuş
*   Atamaları'nda 1-5'i başka işe bağlamışsa (ya da bağsız bıraktıysa) slot bağı hiç gelmiyordu.
*/
local function TusNo(kod)
     if not kod then return end
     if kod >= KEY_1 and kod <= KEY_9 then return kod - KEY_1 + 1 end
     if kod >= KEY_PAD_1 and kod <= KEY_PAD_9 then return kod - KEY_PAD_1 + 1 end
end

hook.Add("PlayerBindPress", "SardonGorev.Diyalog", function(ply, bind, basili, kod)
     local d = G.Diy
     if not d or not basili then return end
     local no = TusNo(kod) or tonumber(string.match(bind, "^slot(%d)") or "")
     if no and d.secim and not d.secim.secildi and d.secim.secenekler[no] then
          Sec(no)
          return true
     end
     if d.kip == "sinematik" then
          if string.find(bind, "+jump", 1, true) or string.find(bind, "+use", 1, true) or string.find(bind, "+attack", 1, true) then
               if d.secim then return true end
               Atla()
               return true
          end
     end
end)

-- Bağsız tuş PlayerBindPress'e hiç düşmez (ya da başka bir eklenti kancası bağı önce yutar): yokla.
local tusOnceki = {}
hook.Add("Think", "SardonGorev.DiyalogTus", function()
     local d = G.Diy
     local s = d and d.secim
     if not s or s.secildi then
          if next(tusOnceki) then tusOnceki = {} end
          return
     end
     local engel = gui.IsGameUIVisible() or vgui.GetKeyboardFocus() or (IsValid(LocalPlayer()) and LocalPlayer():IsTyping())
     for no = 1, math.min(#s.secenekler, 9) do
          local bas = not engel and (input.IsKeyDown(KEY_1 + no - 1) or input.IsKeyDown(KEY_PAD_1 + no - 1))
          if bas and tusOnceki[no] == false then Sec(no) return end
          tusOnceki[no] = bas and true or false
     end
end)

/*
*   1-4 tuşları: Helix eklenti kancaları hook.Add'den önce çalışır ve wepselect basılan her slot
*   tuşunu yutar; seçenekler tuşla hiç seçilemiyordu (serbest kipte 30 sn takılı kalıyordu).
*   Bir seçim beklenirken wepselect tuşu geçirir (nil), tuş yukarıdaki kancaya iner. Başka bir
*   sistem kendi seçimi için "SardonSlotTusu" kancasına true döner.
*   Düello wepselect'i önbellekte sarıp asıl işlevi plugin.SardonDuelloOrijinal'den çağırıyor:
*   düello sarmışsa o alanın, sarmamışsa önbellek girdisinin önüne bir kez girilir. İletici
*   yenilemede aynı kalır, iş ...Asil'de.
*/
hook.Add("SardonSlotTusu", "SardonGorev.Diyalog", function()
     local d = G.Diy
     if d and d.secim and not d.secim.secildi then return true end
end)

function G.SlotIleticiAsil(self, client, bind, basili)
     if basili and string.find(bind, "slot", 1, true) and hook.Run("SardonSlotTusu", bind) then return end
     local asil = self.SardonSlotAsil
     if asil and asil ~= G.SlotIletici then return asil(self, client, bind, basili) end
end
G.SlotIletici = G.SlotIletici or function(...) return G.SlotIleticiAsil(...) end

local function SlotIleticiKur()
     local pl = ix and ix.plugin and ix.plugin.list and ix.plugin.list.wepselect
     local onbellek = HOOKS_CACHE and HOOKS_CACHE.PlayerBindPress
     local fn = pl and onbellek and onbellek[pl]
     if not fn or fn == G.SlotIletici then return end
     if fn == pl.SardonDuelloSarmalayici and pl.SardonDuelloOrijinal then
          if pl.SardonDuelloOrijinal == G.SlotIletici then return end
          pl.SardonSlotAsil = pl.SardonDuelloOrijinal
          pl.SardonDuelloOrijinal = G.SlotIletici
     else
          pl.SardonSlotAsil = fn
          onbellek[pl] = G.SlotIletici
     end
end

timer.Create("SardonGorev.SlotIletici", 5, 0, SlotIleticiKur)
SlotIleticiKur()

local imlecSecili
hook.Add("GUIMousePressed", "SardonGorev.Diyalog", function(tus)
     local d = G.Diy
     if not d or tus ~= MOUSE_LEFT then return end
     if d.secim and imlecSecili then Sec(imlecSecili) return end
     if d.kip == "sinematik" and not d.secim then Atla() end
end)

-- GUIMousePressed imleç bir VGUI panelinin üstündeyken (başka eklentinin tam ekran / görünmez paneli) ya da
-- imleç başka bir sistemce kapatılınca (TAB menüsü kapanışı vb.) hiç gelmiyor: bazı oyuncular yalnız 1-9 ile
-- seçebiliyordu. Seçim beklenirken imleci açık tut ve sol tıkı doğrudan yokla.
local fareOnceki = true
hook.Add("Think", "SardonGorev.DiyalogFare", function()
     local d = G.Diy
     local s = d and d.secim
     if not s or s.secildi or not d.fare then
          fareOnceki = true
          return
     end
     if gui.IsGameUIVisible() then fareOnceki = true return end
     if not vgui.CursorVisible() then gui.EnableScreenClicker(true) end
     local bas = input.IsMouseDown(MOUSE_LEFT)
     if bas and not fareOnceki and imlecSecili then Sec(imlecSecili) end
     fareOnceki = bas
end)

local function DaktiloMetin(s)
     if s.tam then return s.metin end
     local n = utf8.len(s.metin) or #s.metin
     local hiz = math.max(40, n / math.max(s.sure * 0.55, 0.5))
     local k = math.floor((RealTime() - s.bas) * hiz)
     if k >= n then s.tam = true return s.metin end
     return G.Kes(s.metin, k)
end

local function SeritCiz(a)
     local W, H = ScrW(), ScrH()
     local h = math.Round(H * 0.11 * a)
     surface.SetDrawColor(0, 0, 0, 255)
     surface.DrawRect(0, 0, W, h)
     surface.DrawRect(0, H - h, W, h)
     return h
end
G.SeritCiz = SeritCiz

local function SecenekCiz(d, x, y, w, sag)
     local mx, my = gui.MousePos()
     imlecSecili = nil
     local font = F(19, "kalin")
     local secim = d.secim
     local a = G.Yumusak((RealTime() - secim.bas) / 0.25)
     local toplamH = 0
     local olcu = {}
     for j, s in ipairs(secim.secenekler) do
          local metin = s.metin or ""
          if s.fiyat then metin = metin .. "   (" .. G.Galleon(s.fiyat) .. ")" end
          local satirlar = G.Sar(metin, font, w - O(70))
          local h = #satirlar * O(25) + O(16)
          olcu[j] = { satirlar = satirlar, h = h }
          toplamH = toplamH + h + O(6)
     end
     if sag then y = y - toplamH end

     for j, s in ipairs(secim.secenekler) do
          local o = olcu[j]
          local ustunde = d.fare and mx >= x and mx <= x + w and my >= y and my <= y + o.h
          if ustunde and not secim.secildi then imlecSecili = j end
          local secildi = secim.secildi == j
          local soluk = s.yetmez or (secim.secildi and not secildi)
          local zemin = (ustunde or secildi) and Color(40, 52, 40, 230) or Color(11, 19, 17, 215)
          G.Kutu(x, y, w, o.h, Color(zemin.r, zemin.g, zemin.b, zemin.a * a))
          if ustunde or secildi then
               surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 255 * a)
               surface.DrawRect(x, y, O(3), o.h)
          end
          G.Cerceve(x, y, w, o.h, Color(R.cizgi.r, R.cizgi.g, R.cizgi.b, 140 * a))
          -- numara
          G.Baklava(x + O(24), y + o.h / 2, O(11), soluk and R.cizgi or R.altin, 230 * a, false)
          G.Yaz(tostring(j), F(15, "cokKalin"), x + O(24), y + o.h / 2, soluk and R.soluk or R.altinAcik, 1, nil, 0, a)
          local renk = soluk and R.soluk or (s.onceden and R.govde or R.fildisi)
          for k, satir in ipairs(o.satirlar) do
               G.Yaz(satir, font, x + O(50), y + O(8) + (k - 0.5) * O(25), renk, 0, nil, 0.7, a)
          end
          y = y + o.h + O(6)
     end
end

local function DiyalogCiz()
     local d = G.Diy
     if not d then return end
     local W, H = ScrW(), ScrH()

     if d.kip == "sinematik" then
          local a = G.Yumusak((RealTime() - d.bas) / 0.5)
          local h = SeritCiz(a)
          local s = d.satir
          if s then
               local ad = s.kim == "oyuncu" and LocalPlayer():Nick() or (s.ad or "")
               local renk = s.kim == "oyuncu" and Color(168, 196, 214) or IsimRengi(s.renk)
               local cx = W / 2
               local y = H - h + O(26)
               if s.kim ~= "anlatici" and ad ~= "" then
                    G.Yaz(G.Buyuk(ad), F(16, "baslik"), cx, y, renk, 1, O(3), 0.8, a)
                    if s.unvan and s.unvan ~= "" then G.Yaz(s.unvan, F(12, "italik"), cx, y + O(18), R.soluk, 1, nil, 0.6, a) end
               end
               local font = s.kim == "anlatici" and F(22, "italik") or F(22, "govde")
               local metin = DaktiloMetin(s)
               local satirlar = G.Sar(metin, font, W * 0.62)
               local ty = y + O(48)
               for _, satir in ipairs(satirlar) do
                    G.Yaz(satir, font, cx, ty, R.fildisiAcik, 1, nil, 0.8, a)
                    ty = ty + O(29)
               end
               if not d.secim and not s.gecilmez and RealTime() - s.bas > 0.6 then
                    G.Yaz("ESPACIO  ·  saltar", F(11, "kalin"), W - O(40), H - O(22), Color(R.soluk.r, R.soluk.g, R.soluk.b, 140), 2, O(2), 0, a)
               end
          end
          if d.secim then
               local w = math.min(O(560), W * 0.4)
               SecenekCiz(d, W - w - O(70), H - h - O(24), w, true)
          end
     else
          if d.secim then
               local w = math.min(O(480), W * 0.36)
               SecenekCiz(d, W - w - O(48), H * 0.5, w, false)
               G.Yaz("Para elegir: 1 – " .. #d.secim.secenekler, F(12, "kalin"), W - O(48), H * 0.5 - O(16), R.soluk, 2, O(2), 0.8)
          end
     end
end

hook.Add("HUDPaint", "SardonGorev.Diyalog", function()
     AnlaticiCiz()
     AltyaziCiz()
     DiyalogCiz()
end)

/*
*   Görev veren teklif penceresi
*/
local teklifPanel

function G.TeklifAc(t)
     if IsValid(teklifPanel) then teklifPanel:Remove() end
     if not t.gorevler or #t.gorevler == 0 then return end

     local W, H = ScrW(), ScrH()
     local pw, ph = math.min(O(620), W - O(40)), math.min(O(560), H - O(80))
     local p = vgui.Create("EditablePanel")
     teklifPanel = p
     p:SetSize(pw, ph)
     p:SetPos(W - pw - O(80), (H - ph) / 2)
     p:MakePopup()
     p:SetKeyboardInputEnabled(false)
     p.bas = RealTime()
     p.aktor = t.aktor
     p.secili = 1

     p.Paint = function(s, w, h)
          local a = G.Yumusak((RealTime() - s.bas) / 0.25)
          G.Pano(0, 0, w, h, a, Color(11, 19, 17, 245))
          G.Yaz("OFERTA DE MISIÓN", F(12, "kalin"), O(28), O(30), R.altin, 0, O(3), 0, a)
          G.Yaz(t.ad or "", F(26, "baslik"), O(28), O(62), R.fildisi, 0, nil, 0, a)
          if t.unvan and t.unvan ~= "" then G.Yaz(t.unvan, F(13, "italik"), O(28), O(88), R.soluk, 0, nil, 0, a) end
          G.AltinCizgi(O(28), O(106), w - O(56), 160 * a)

          local g = t.gorevler[s.secili]
          if not g then return end
          local y = O(124)
          if #t.gorevler > 1 then y = y + O(40) end
          local renk = G.TurRenk(g.tur)
          G.Baklava(O(34), y + O(8), O(5), renk, 255 * a)
          G.Yaz(G.Buyuk(G.Tur(g.tur).ad), F(12, "kalin"), O(46), y + O(8), renk, 0, O(2), 0, a)
          G.Yaz(g.ad or "", F(22, "baslik"), O(28), y + O(36), R.fildisiAcik, 0, nil, 0, a)
          y = y + O(62)
          local metin = (g.aciklama and g.aciklama ~= "") and g.aciklama or (g.ozet or "")
          for _, satir in ipairs(G.Sar(metin, F(16, "govde"), w - O(56))) do
               if y > h - O(150) then break end
               G.Yaz(satir, F(16, "govde"), O(28), y, R.govde, 0, nil, 0, a)
               y = y + O(22)
          end
          if g.oduller and #g.oduller > 0 then
               local oy = h - O(126)
               G.Yaz("RECOMPENSAS", F(12, "kalin"), O(28), oy, R.altin, 0, O(3), 0, a)
               G.Yaz(table.concat(g.oduller, "   ◆   "), F(15, "kalin"), O(28), oy + O(24), R.fildisi, 0, nil, 0, a)
          end
     end

     -- birden çok görev: sekmeler
     if #t.gorevler > 1 then
          local x = O(28)
          for i, g in ipairs(t.gorevler) do
               local b = vgui.Create("DButton", p)
               local font = F(13, "kalin")
               local bw = G.Genislik(G.Kisalt(g.ad, 22), font) + O(28)
               b:SetPos(x, O(122))
               b:SetSize(bw, O(30))
               b:SetText("")
               b.Paint = function(s, w, h)
                    local sec = p.secili == i
                    G.Kutu(0, 0, w, h, sec and Color(40, 52, 40, 230) or Color(7, 11, 9, 200))
                    G.Cerceve(0, 0, w, h, sec and R.altin or R.cizgi)
                    G.Yaz(G.Kisalt(g.ad, 22), font, w / 2, h / 2, sec and R.altinAcik or R.govde, 1)
               end
               b.DoClick = function() p.secili = i G.Cal("tik") end
               x = x + bw + O(8)
          end
     end

     local function Dugme(metin, x, w, birincil, fn)
          local b = vgui.Create("DButton", p)
          b:SetPos(x, ph - O(64))
          b:SetSize(w, O(42))
          b:SetText("")
          b.Paint = function(s, bw, bh)
               local ust = s:IsHovered()
               G.Kutu(0, 0, bw, bh, birincil and Color(60, 50, 30, ust and 255 or 220) or Color(7, 11, 9, ust and 240 or 200))
               G.Cerceve(0, 0, bw, bh, (birincil or ust) and R.altin or R.cizgi)
               G.Yaz(G.Buyuk(metin), F(14, "kalin"), bw / 2, bh / 2, birincil and R.altinAcik or R.govde, 1, O(2))
          end
          b.OnCursorEntered = function() G.Cal("ustune") end
          b.DoClick = fn
          return b
     end

     Dugme("Aceptar", O(28), (pw - O(68)) / 2, true, function()
          local g = t.gorevler[p.secili]
          if g then
               G.Iste(G.ISTEK.KABUL, function()
                    net.WriteUInt(t.aktor or 0, 16)
                    net.WriteString(g.id)
               end)
          end
          G.Cal("tik")
          p:Remove()
     end)
     Dugme("Ahora no", O(40) + (pw - O(68)) / 2, (pw - O(68)) / 2, false, function()
          G.Cal("tik")
          p:Remove()
     end)

     p.Think = function(s)
          if input.IsKeyDown(KEY_ESCAPE) then s:Remove() return end
          local c = G.Aktorler[s.aktor or 0]
          if not c or not c.cizPos or LocalPlayer():GetPos():DistToSqr(c.cizPos) > 360 * 360 then s:Remove() end
     end
end

-- Sinematik diyalogda diğer HUD'lar gizlensin
hook.Add("SardonHUDGizle", "SardonGorev.Diyalog", function()
     if G.Diy and G.Diy.kip == "sinematik" then return true end
end)
