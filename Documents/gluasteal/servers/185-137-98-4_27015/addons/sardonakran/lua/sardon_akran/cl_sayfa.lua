-- "addons\\sardonakran\\lua\\sardon_akran\\cl_sayfa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Akran Yardımı :: asa menüsü (Büyü Kitabı teması) > "Akran Yardımı" sekmesi
--
-- Sayfa HpwRewrite.Nocturne.Pages.akran olarak kaydolur; sekme düğmesi
-- [hogwarts] wand/lua/hpwrewrite/nocturne/15_kitap_menu.lua TABS listesinde.
--
-- Tek tuval, anlık çizim (immediate mode): her karede tıklanabilir bölgeler yeniden kaydedilir.
-- İçerik alanı 1080 x 520 tasarım birimi, K.S ile ölçeklenir.
--
--   Öğretmen görünümü  :: öğretmen kartı (unvan, Büyü Puanı mühürleri) · öğrencilerim (onay / iptal)
--                         · yakındaki öğrenciler (yön oku) · Temel büyü ızgarası · rün önizlemeli teklif
--   Öğrenci görünümü   :: takımyıldız yolculuk çizgisi · aşama kartı · okundukça beliren rün
--   Bilgi görünümü     :: sistemin anlatımı + öğretmenliğe kalan seviye

local SA = SardonAkran

local function Build(ctx)
     local N = HpwRewrite.Nocturne
     local K = N.Kitap
     local C = K.C
     local S = K.S
     local P = ctx.panel
     local W, H = ctx.w, ctx.h
     local R = SA.R
     local SECILI = Color(46, 42, 26, 235)

     SA.Fontlar()
     SA.PanelIste()

     local st = {
          gorunum = nil,
          secOgrenci = nil,
          secBuyu = nil,
          bolgeler = {},
          kaydir = {},     -- ızgara id -> {hedef, simdi, max, ust, alt}
          kaydirAlan = {}, -- her karede: tekerleğin dinlendiği bölgeler
          P = SA.Parcacik(),
          sonIstek = RealTime(),
          iptal = nil, -- {id, t} ikinci tıklamada iptal
          acilis = RealTime()
     }

     local tuval = vgui.Create("DPanel", P)
     tuval:SetPos(0, 0)
     tuval:SetSize(S(W), S(H))

     /*
     *   çizim yardımcıları (tasarım birimi)
     */

     local function B(x, y, w, h, c) K.Box(S(x), S(y), S(w), S(h), c) end
     local function O(x, y, w, h, c) K.Outline(S(x), S(y), S(w), S(h), c) end
     local function T(str, font, x, y, c, ax, ay) return K.Text(str, font, S(x), S(y), c, ax, ay) end

     local mx, my = 0, 0
     local function Ust(x, y, w, h) return mx >= S(x) and mx <= S(x + w) and my >= S(y) and my <= S(y + h) end

     local function Bolge(x, y, w, h, fn)
          st.bolgeler[#st.bolgeler + 1] = {S(x), S(y), S(w), S(h), fn}
          return Ust(x, y, w, h)
     end

     /*
     *   kaydırılan ızgara :: Temel büyü listesi Büyü Ağacı'yla büyüdü (21 -> 44), kutu sabit kaldı.
     *   Tekerlekle kayar; pencere dışındaki satırlar çizilmez, tıklama bölgesi pencereye kırpılır.
     */

     local function KaydirBasla(id, x, y, w, h, icerik, adim)
          local k = st.kaydir[id]
          if (!k) then
               k = {hedef = 0, simdi = 0}
               st.kaydir[id] = k
          end
          k.max = math.max(0, icerik - h)
          k.hedef = math.Clamp(k.hedef, 0, k.max)
          k.simdi = Lerp(math.min(1, FrameTime() * 14), k.simdi, k.hedef)
          if (math.abs(k.simdi - k.hedef) < 0.5) then k.simdi = k.hedef end
          k.ust, k.alt = y, y + h
          st.kaydirAlan[#st.kaydirAlan + 1] = {S(x), S(y), S(w), S(h), id, adim}
          if (k.max > 0) then
               local sx, sy = tuval:LocalToScreen(0, 0)
               render.SetScissorRect(sx + S(x), sy + S(y), sx + S(x + w), sy + S(y + h), true)
               st.makas = true
          end
          return k
     end

     local function KaydirBitir(k, cx, y, h)
          if (k.max <= 0) then return end
          render.SetScissorRect(0, 0, 0, 0, false)
          st.makas = nil
          local th = math.max(18, h * h / (h + k.max))
          B(cx - 1, y, 2, h, C.rowLine)
          B(cx - 2, y + (h - th) * (k.simdi / k.max), 4, th, C.tabEdge)
     end

     local function Gorunur(k, y, h) return y + h > k.ust and y < k.alt end
     local function TamGorunur(k, y, h) return y >= k.ust and y + h <= k.alt end

     local function BolgeKirp(k, x, y, w, h, fn)
          local y1, y2 = math.max(y, k.ust), math.min(y + h, k.alt)
          if (y2 <= y1) then return false end
          return Bolge(x, y1, w, y2 - y1, fn)
     end

     local function Kart(x, y, w, h, ust, baslik)
          K.Box(S(x), S(y), S(w), S(h), Color(11, 19, 17, 170))
          K.Outline(S(x), S(y), S(w), S(h), C.detailLine)
          if (ust) then K.Spaced(ust, "sans10", S(x + 16), S(y + 12), C.eyebrow, 2) end
          if (baslik) then T(baslik, "serif15", x + 16, y + 38, C.heading, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
     end

     local function Dugme(x, y, w, h, yazi, fn, birincil, kapali)
          local hov = !kapali and Bolge(x, y, w, h, fn)
          local px, py, pw, ph = S(x), S(y), S(w), S(h)
          if (birincil and !kapali and K.Slice3(hov and "button_hover" or "button_primary", px, py, pw, ph, 24)) then
               draw.NoTexture()
          else
               K.Box(px, py, pw, ph, kapali and Color(20, 24, 20, 200) or (birincil and C.primFall or C.secBg))
               K.Outline(px, py, pw, ph, kapali and C.rowLine or (hov and C.searchFocus or C.secLine))
          end
          if (hov) then SA.Isik(px + pw / 2, py + ph / 2, pw * 0.4, R.altin, 26) end
          K.Text(yazi, birincil and "serif13" or "sans12", px + pw / 2, py + ph / 2, kapali and C.rowSub or (birincil and C.primText or C.secText), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          return hov
     end

     local function Ilerleme(x, y, w, f, renk)
          B(x, y, w, 4, C.progTrack)
          B(x, y, w * math.Clamp(f, 0, 1), 4, renk or C.gold)
          SA.Isik(S(x + w * math.Clamp(f, 0, 1)), S(y + 2), S(8), renk or C.gold, 160)
     end

     local function Yon(cx, cy, r, ent, renk)
          if (!IsValid(ent)) then return end
          local ply = LocalPlayer()
          local yon = (ent:GetPos() - ply:GetPos()):Angle().y
          local an = -math.rad(math.NormalizeAngle(yon - ply:EyeAngles().y)) - math.pi / 2
          local ux, uy = math.cos(an), math.sin(an)
          local px, py = -uy, ux
          local X, Y, Rr = S(cx), S(cy), S(r)
          draw.NoTexture()
          surface.SetDrawColor(renk.r, renk.g, renk.b, 220)
          surface.DrawPoly({{x = X + ux * Rr, y = Y + uy * Rr}, {x = X - ux * Rr * 0.6 - px * Rr * 0.6, y = Y - uy * Rr * 0.6 - py * Rr * 0.6}, {x = X, y = Y}})
          surface.DrawPoly({{x = X + ux * Rr, y = Y + uy * Rr}, {x = X, y = Y}, {x = X - ux * Rr * 0.6 + px * Rr * 0.6, y = Y - uy * Rr * 0.6 + py * Rr * 0.6}})
     end

     -- rün önizlemesi: gök plakası + akan kıvılcım
     local function RunOnizleme(buyu, cx, cy, r, oran, gizli)
          local now = RealTime()
          SA.GokPlaka(S(cx), S(cy), S(r * 1.25), 0.35, now * 6)
          if (gizli) then
               for i = 1, 3 do
                    local an = now * (0.6 + i * 0.2) + i * 2
                    SA.Isik(S(cx + math.cos(an) * r * 0.5), S(cy + math.sin(an) * r * 0.4), S(26), C.parchment, 40)
               end
               T("?", "h2", cx, cy, ColorAlpha(C.parchment, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               return
          end
          SA.Run2D(buyu, S(cx), S(cy), S(r), 1, C.parchment, S(1.5), 45)
          local ux, uy = SA.Run2D(buyu, S(cx), S(cy), S(r), oran, R.altin, S(2.4), 255, oran < 1)
          if (oran >= 1) then
               local sablon = SA.Sablon(buyu)
               local ham = sablon and sablon.ham
               if (ham) then
                    local u = (now * 0.42) % 1
                    local i = math.max(1, math.floor(u * #ham))
                    for k = 0, 7 do
                         local p = ham[math.max(1, i - k * 2)]
                         SA.Isik(S(cx) + p.x * S(r), S(cy) - p.y * S(r), S(9 - k), R.altin, 230 * (1 - k / 8))
                    end
                    if (math.random() < 0.2) then
                         local p = ham[i]
                         st.P:Ekle(S(cx) + p.x * S(r), S(cy) - p.y * S(r), math.Rand(-10, 10), math.Rand(-24, -6), 0.8, S(4), R.altin, 0)
                    end
               end
          elseif (ux and math.random() < 0.3) then
               st.P:Ekle(ux, uy, math.Rand(-10, 10), math.Rand(-24, -6), 0.8, S(4), R.altin, 0)
          end
     end

     local function Ad(charid, ad)
          local mc = LocalPlayer():GetCharacter()
          if (mc and mc.DoesRecognize and charid and !mc:DoesRecognize(charid)) then return "Tanımadığın öğrenci" end
          return ad or "?"
     end

     local function Bilir(buyu)
          return HpwRewrite:PlayerHasSpell(LocalPlayer(), buyu)
     end

     /*
     *   üst şerit
     */

     local function Baslik(v, secenekler)
          T("Akran Yardımı", "title", 0, 14, C.heading, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          T("Kıdemli öğrenciler yeni gelenlere Temel büyü öğretir: kütüphane · okuma · talim · onay", "sans12", 0, 38, C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

          local x = W
          if (v) then
               local chip = SA.YilYaz(v.seviye)
               local cw = K.TextW(chip, "sans12") / K.scale + 22
               x = x - cw
               B(x, 6, cw, 24, C.secBg)
               O(x, 6, cw, 24, C.secLine)
               T(chip, "sans12", x + cw / 2, 18, C.secText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               x = x - 8
          end

          if (#secenekler > 1) then
               for i = #secenekler, 1, -1 do
                    local s = secenekler[i]
                    local ad = s == "ogretmen" and "Öğretmen" or "Öğrenci"
                    local bw = 96
                    x = x - bw
                    local on = st.gorunum == s
                    local hov = Bolge(x, 6, bw, 24, function() st.gorunum = s end)
                    B(x, 6, bw, 24, on and C.primFall or (hov and C.secHover or C.secBg))
                    O(x, 6, bw, 24, on and C.tabEdge or C.secLine)
                    T(ad, "sans12", x + bw / 2, 18, on and C.ivoryHi or C.secText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    x = x - 4
               end
          end
     end

     /*
     *   öğretmen görünümü
     */

     local function OgretmenKarti(v)
          local x, y, w, h = 0, 60, 290, 204
          Kart(x, y, w, h, "ÖĞRETMEN KARTI")
          local ist = v.istatistik or {}
          local toplam = ist.toplam or 0
          local unvan, sonraki = SA.Unvan(toplam)

          T(unvan, "title", x + 16, y + 42, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          T(tostring(toplam), "h2", x + w - 16, y + 40, C.ivory, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          T("öğretim", "sans11", x + w - 16, y + 62, C.rowSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

          if (sonraki) then
               local onceki = 0
               for _, u in ipairs(SA.Unvanlar) do if (u[1] <= toplam) then onceki = u[1] end end
               Ilerleme(x + 16, y + 74, w - 32, (toplam - onceki) / math.max(1, sonraki[1] - onceki))
               T(sonraki[2] .. " için " .. (sonraki[1] - toplam) .. " öğretim", "sans11", x + 16, y + 88, C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          else
               T("En yüksek unvana ulaştın.", "sans11", x + 16, y + 80, C.ready, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end

          -- Büyü Puanı mühürleri
          local her = SA.Ayar.puanHer
          local sayac = ist.sayac or 0
          T("BÜYÜ PUANI", "sans10", x + 16, y + 112, C.eyebrow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          local now = RealTime()
          for i = 1, her do
               local cx, cy = x + 26 + (i - 1) * 30, y + 136
               if (i <= sayac) then
                    SA.Isik(S(cx), S(cy), S(16 + math.sin(now * 3 + i) * 2), R.altin, 150)
                    SA.Yildiz(S(cx), S(cy), S(9), R.altin, 255)
               else
                    SA.Halka(S(cx), S(cy), S(8), S(1.2), C.groupCount, 220, 20)
               end
          end
          T((her - sayac) .. " öğretim sonra +1", "sans11", x + w - 16, y + 136, C.rowMeta, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

          local gunluk = ist.gunluk or 0 -- sunucu gün değişince sıfırlıyor
          T("Bugün ödüllü: " .. gunluk .. " / " .. SA.Ayar.gunlukOdul, "sans12", x + 16, y + 166, gunluk >= SA.Ayar.gunlukOdul and C.warn or C.dd, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          T("Kazanç: " .. (ist.onur or 0) .. " onur · " .. (ist.puan or 0) .. " BP", "sans12", x + 16, y + 186, C.dd, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end

     local function Ogrencilerim(v)
          local x, y, w, h = 0, 276, 290, 244
          Kart(x, y, w, h, "ÖĞRENCİLERİM  ·  " .. #v.gorevler .. " / " .. SA.Ayar.eszamanli)

          if (#v.gorevler == 0) then
               for i, satir in ipairs(K.Wrap("Henüz öğrencin yok. Ortadaki listeden bir öğrenci, sağdan bir Temel büyü seç ve teklif et.", "sans12", S(w - 32))) do
                    K.Text(satir, "sans12", S(x + 16), S(y + 34) + (i - 1) * S(18), C.rowSub)
               end
               return
          end

          for i, g in ipairs(v.gorevler) do
               local gerek = g.gerek or SA.Ayar.okumaDakika * 60
               if (i > 4) then
                    T("+" .. (#v.gorevler - 4) .. " öğrenci daha", "sans11", x + 16, y + h - 12, C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    break
               end
               local ry = y + 30 + (i - 1) * 52
               B(x + 8, ry, w - 16, 48, g.asama == 4 and Color(60, 52, 28, 120) or Color(16, 24, 20, 200))
               if (g.asama == 4) then
                    O(x + 8, ry, w - 16, 48, C.tabEdge)
                    SA.Isik(S(x + 8), S(ry + 24), S(18 + math.sin(RealTime() * 4) * 4), R.altin, 120)
               end

               T(K.Clip(Ad(g.ogrenci, g.ad), "serif14", S(140)), "serif14", x + 18, ry + 14, g.cevrimici and C.ivory or C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               T(g.buyu, "sans11", x + 18, ry + 32, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

               -- aşama noktaları
               for a = 1, 4 do
                    local cx = x + 172 + (a - 1) * 10
                    SA.Daire(S(cx), S(ry + 14), S(a == g.asama and 3.5 or 2.5), a < g.asama and C.ready or (a == g.asama and R.altin or C.groupCount), 255, 12)
               end

               local durum
               if (g.asama == 1) then durum = "kitabı arıyor"
               elseif (g.asama == 2) then durum = "okuma %" .. math.floor(g.okunan / gerek * 100)
               elseif (g.asama == 3) then durum = "talim " .. g.basari .. "/" .. SA.Ayar.basariGerek .. (g.yakin and "" or " · uzaktasın")
               else durum = "ONAY BEKLİYOR" end
               if (!g.cevrimici) then durum = "çevrimdışı · " .. durum end
               T(durum, "sans11", x + 172, ry + 32, g.asama == 4 and R.altin or C.rowMeta, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

               -- iptal (iki tık)
               local iptalOnay = st.iptal and st.iptal.id == g.ogrenci and st.iptal.t > RealTime()
               local ix = x + w - 30
               local hov = Bolge(ix, ry + 6, 16, 16, function()
                    if (iptalOnay) then
                         SA.Iptal(g.ogrenci)
                         st.iptal = nil
                         timer.Simple(0.3, SA.PanelIste)
                    else
                         st.iptal = {id = g.ogrenci, t = RealTime() + 3}
                    end
               end)
               K.Cross(S(ix + 8), S(ry + 14), S(4), iptalOnay and C.bad or (hov and C.ivory or C.rowSub))
               if (iptalOnay) then T("emin misin?", "sans10", ix - 4, ry + 14, C.bad, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end

               if (g.asama == 4) then
                    Dugme(x + w - 124, ry + 24, 58, 20, "Öğret", function()
                         SA.Onayla(g.ogrenci, true)
                         timer.Simple(0.4, SA.PanelIste)
                    end, true, !g.cevrimici or !g.yakin)
                    Dugme(x + w - 62, ry + 24, 50, 20, "Tekrar", function()
                         SA.Onayla(g.ogrenci, false)
                         timer.Simple(0.4, SA.PanelIste)
                    end, false, !g.cevrimici)
               end
          end
     end

     local function YakinOgrenciler(v)
          local x, y, w, h = 304, 60, 330, 460
          Kart(x, y, w, h, "YAKINDAKİ ÖĞRENCİLER", nil)
          T(SA.Ayar.ogrenciYil .. ". yıl ve altı", "sans11", x + w - 16, y + 14, C.rowSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

          if (#v.yakin == 0) then
               local metin = "Yakında öğrenci yok. " .. SA.Ayar.ogrenciYil .. ". yıl ve altındaki öğrencilerin yanına git; liste kendiliğinden yenilenir."
               for i, satir in ipairs(K.Wrap(metin, "sans12", S(w - 40))) do
                    K.Text(satir, "sans12", S(x + w / 2), S(y + 200) + (i - 1) * S(18), C.rowSub, TEXT_ALIGN_CENTER)
               end
               RunOnizleme("Muffliato", x + w / 2, y + 140, 30, 1, true)
               return
          end

          local toplamTemel = #SA.TemelListe()
          for i, o in ipairs(v.yakin) do
               if (i > 6) then
                    T("+" .. (#v.yakin - 6) .. " öğrenci daha", "sans11", x + 16, y + h - 14, C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    break
               end
               local ry = y + 32 + (i - 1) * 68
               local on = st.secOgrenci == o.charid
               local uzak = o.mesafe > SA.Ayar.teklifMesafe
               local kapali = o.gorev or o.davet
               local hov = Bolge(x + 8, ry, w - 16, 62, function()
                    st.secOgrenci = o.charid
                    st.P:Patlama(S(x + 30), S(ry + 31), R.altin, 14, 0.6)
               end)

               B(x + 8, ry, w - 16, 62, on and SECILI or (hov and C.rowHover or Color(16, 24, 20, 200)))
               local renk = o.renk and Color(o.renk.r, o.renk.g, o.renk.b) or C.gold
               B(x + 8, ry, 3, 62, renk)
               if (on) then
                    O(x + 8, ry, w - 16, 62, C.tabEdge)
                    SA.Isik(S(x + 10), S(ry + 31), S(30), renk, 70)
               end

               T(K.Clip(Ad(o.charid, o.ad), "serif15", S(190)), "serif15", x + 22, ry + 16, kapali and C.rowSub or C.ivory, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               T(SA.YilYaz(o.seviye) .. "  ·  " .. #o.bilinen .. " / " .. toplamTemel .. " Temel büyü", "sans11", x + 22, ry + 35, C.rowMeta, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

               local rozet, rr = nil, C.rowSub
               if (o.gorev) then rozet, rr = "görevi sürüyor", C.warn
               elseif (o.davet) then rozet, rr = "davet bekliyor", C.ready
               elseif (uzak) then rozet, rr = "uzak, yanına git", C.warn end
               if (rozet) then T(rozet, "sans11", x + 22, ry + 51, rr, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end

               T(math.floor(o.mesafe * 0.019) .. " m", "sans12", x + w - 44, ry + 31, C.dd, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               Yon(x + w - 26, ry + 31, 8, o.ent, uzak and C.warn or C.gold)
          end
     end

     local function BuyuIzgarasi(v, ogr)
          local x, y, w, h = 648, 60, 432, 300
          Kart(x, y, w, h, "TEMEL BÜYÜLER")
          local liste = SA.TemelListe()
          local bilinen = {}
          for _, b in ipairs(ogr and ogr.bilinen or {}) do bilinen[b] = true end
          T(ogr and "öğrencinin bilmediği, senin bildiğin büyüyü seç" or "önce bir öğrenci seç", "sans11", x + w - 16, y + 14, C.rowSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

          local cols, tw, th, gap, adim = 3, 132, 32, 6, 37
          local gy, gh = y + 30, 7 * adim - 5 -- 7 satır görünür (eski yerleşimle aynı)
          local k = KaydirBasla("buyu", x, gy, w, gh, math.ceil(#liste / cols) * adim - 5, adim)
          for i, b in ipairs(liste) do
               local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
               local tx, ty = x + 14 + col * (tw + gap), gy + row * adim - k.simdi
               if (!Gorunur(k, ty, th)) then continue end

               local bende = Bilir(b)
               local onda = bilinen[b]
               local secilebilir = bende and !onda
               local on = st.secBuyu == b
               local hov = BolgeKirp(k, tx, ty, tw, th, function()
                    st.secBuyu = b
                    st.P:Patlama(S(tx + 16), S(ty + th / 2), R.altin, 12, 0.5)
               end)

               B(tx, ty, tw, th, on and SECILI or (hov and C.rowHover or Color(14, 21, 18, 220)))
               O(tx, ty, tw, th, on and C.tabEdge or C.rowLine)

               local ikon = SA.BuyuIkon(b)
               local a = secilebilir and 255 or 90
               if (ikon) then
                    surface.SetMaterial(ikon)
                    surface.SetDrawColor(255, 255, 255, a)
                    surface.DrawTexturedRect(S(tx + 5), S(ty + 5), S(22), S(22))
                    draw.NoTexture()
               else
                    SA.Run2D(b, S(tx + 16), S(ty + 16), S(9), 1, C.gold, S(1), a)
               end
               T(K.Clip(b, "sans12", S(tw - 50)), "sans12", tx + 32, ty + th / 2, secilebilir and C.ivory or C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

               -- durum işareti
               local ix, iy = S(tx + tw - 12), S(ty + th / 2)
               if (!bende) then
                    K.Cross(ix, iy, S(3), C.bad)
               elseif (onda) then
                    K.Check(ix - S(4), iy - S(4), S(8), C.ready)
               elseif (on) then
                    SA.Isik(ix, iy, S(10), R.altin, 220)
                    SA.Yildiz(ix, iy, S(5), R.altin, 255)
               end

               if (on and TamGorunur(k, ty, th) and math.random() < 0.12) then st.P:Yukselen(S(tx), S(ty), S(tw), S(th), R.altin, 1) end
          end
          KaydirBitir(k, x + w - 5, gy, gh)

          -- açıklama satırı
          K.Cross(S(x + 20), S(y + h - 10), S(3), C.bad)
          T("bilmiyorsun", "sans10", x + 28, y + h - 10, C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          K.Check(S(x + 112), S(y + h - 14), S(8), C.ready)
          T("öğrenci biliyor", "sans10", x + 126, y + h - 10, C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end

     local function TeklifEngeli(v, ogr)
          if (!ogr) then return "Ortadaki listeden bir öğrenci seç." end
          if (!st.secBuyu) then return "Yukarıdan bir Temel büyü seç." end
          if (!Bilir(st.secBuyu)) then return "Bu büyüyü sen bilmiyorsun." end
          for _, b in ipairs(ogr.bilinen) do if (b == st.secBuyu) then return "Öğrenci bu büyüyü zaten biliyor." end end
          if (ogr.gorev) then return "Öğrencinin süren bir görevi var." end
          if (ogr.davet) then return "Öğrenci bir daveti yanıtlıyor." end
          if (ogr.mesafe > SA.Ayar.teklifMesafe) then return "Öğrenci çok uzakta; yanına git." end
          if (#v.gorevler >= SA.Ayar.eszamanli) then return "Aynı anda en fazla " .. SA.Ayar.eszamanli .. " öğrenci." end
          if ((v.raflar or 0) == 0) then return "Kütüphanede raf tanımlanmamış (yetkiliye bildir)." end
          if ((v.alanlar or 0) == 0) then return "Talim alanı tanımlanmamış (yetkiliye bildir)." end
     end

     local function Teklif(v, ogr)
          local x, y, w, h = 648, 372, 432, 148
          Kart(x, y, w, h, "TEKLİF")

          if (st.secBuyu) then
               RunOnizleme(st.secBuyu, x + 76, y + 82, 46, 1)
          else
               RunOnizleme("Muffliato", x + 76, y + 82, 46, 1, true)
          end

          local tx = x + 150
          T(st.secBuyu or "Büyü seçilmedi", "serif15", tx, y + 30, st.secBuyu and C.gold or C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          T(ogr and ("→ " .. K.Clip(Ad(ogr.charid, ogr.ad), "sans12", S(240))) or "→ öğrenci seçilmedi", "sans12", tx, y + 50, ogr and C.ivory or C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

          local engel = TeklifEngeli(v, ogr)
          local sablon = st.secBuyu and SA.Sablon(st.secBuyu)
          local metin = engel or (sablon and sablon.tarif) or ""
          for i, satir in ipairs(K.Wrap(metin, "sans11", S(w - 166))) do
               if (i > 3) then break end
               K.Text(satir, "sans11", S(tx), S(y + 62) + (i - 1) * S(15), engel and C.warn or C.rowMeta)
          end

          Dugme(tx, y + h - 40, w - 166, 28, "Öğretmeyi teklif et", function()
               SA.Teklif(ogr.ent, st.secBuyu)
               st.P:Patlama(S(tx + (w - 166) / 2), S(y + h - 26), R.altin, 50, 1.1)
               timer.Simple(0.5, SA.PanelIste)
          end, true, engel != nil or !IsValid(ogr and ogr.ent))
     end

     local function OgretmenGorunumu(v)
          local ogr
          for _, o in ipairs(v.yakin) do
               if (o.charid == st.secOgrenci) then ogr = o end
          end
          if (!ogr and st.secOgrenci) then st.secOgrenci = nil end

          OgretmenKarti(v)
          Ogrencilerim(v)
          YakinOgrenciler(v)
          BuyuIzgarasi(v, ogr)
          Teklif(v, ogr)
     end

     /*
     *   öğrenci görünümü
     */

     local function Yolculuk(g)
          local x, y, w, h = 0, 60, W, 116
          Kart(x, y, w, h, "YOLCULUĞUN  ·  " .. g.buyu)
          local now = RealTime()
          local n = #SA.Asamalar
          local px = {}
          for i = 1, n do px[i] = x + 120 + (i - 1) * (w - 240) / (n - 1) end
          local cy = y + 62

          -- bağlantılar: tamamlananlarda akan ışık
          for i = 1, n - 1 do
               local tamam = i < g.asama
               SA.Kalin(S(px[i] + 14), S(cy), S(px[i + 1] - 14), S(cy), S(tamam and 2 or 1), tamam and R.altin or C.groupCount, tamam and 220 or 160)
               if (tamam or i == g.asama) then
                    local f = (now * 0.5 + i * 0.3) % 1
                    if (i == g.asama) then f = f * 0.5 end
                    SA.Isik(S(px[i] + 14 + (px[i + 1] - px[i] - 28) * f), S(cy), S(9), R.altin, tamam and 220 or 120)
               end
          end

          for i, a in ipairs(SA.Asamalar) do
               local cx = px[i]
               local tamam, simdi = i < g.asama, i == g.asama
               if (simdi) then
                    SA.Isik(S(cx), S(cy), S(30 + math.sin(now * 3) * 4), R.altin, 120)
                    SA.Halka(S(cx), S(cy), S(14), S(1.5), R.altin, 255, 32, 0, 1)
                    SA.Halka(S(cx), S(cy), S(19), S(1), R.altin, 140, 32, (now * 0.3) % 1, (now * 0.3) % 1 + 0.6)
                    SA.Yildiz(S(cx), S(cy), S(8), R.altin, 255)
                    if (math.random() < 0.15) then st.P:Ekle(S(cx), S(cy), math.Rand(-20, 20), math.Rand(-30, -10), 1, S(5), R.altin, 0) end
               elseif (tamam) then
                    SA.Daire(S(cx), S(cy), S(9), C.ready, 255, 20)
                    K.Check(S(cx - 4), S(cy - 4), S(8), C.dark)
               else
                    SA.Halka(S(cx), S(cy), S(9), S(1.2), C.groupCount, 255, 24)
                    T(SA.Roma[i], "sans11", cx, cy, C.groupCount, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               end
               T(a.ad, simdi and "serif14" or "sans12", cx, cy + 32, simdi and C.gold or (tamam and C.ready or C.rowSub), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     end

     local function AsamaKarti(g)
          local x, y, w, h = 0, 188, 560, 332
          local a = SA.Asamalar[g.asama]
          Kart(x, y, w, h, "AŞAMA " .. SA.Roma[g.asama] .. "  ·  " .. a.ust, a.ad)
          local ply = LocalPlayer()

          local ty = y + 64
          for _, satir in ipairs(K.Wrap(a.aciklama, "sans12", S(w - 32))) do
               K.Text(satir, "sans12", S(x + 16), S(ty), C.desc)
               ty = ty + 18
          end
          ty = ty + 12

          local function Bilgi(etiket, deger, renk)
               T(etiket, "sans11", x + 16, ty, C.dt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               T(deger, "serif14", x + 150, ty, renk or C.dd, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               ty = ty + 24
          end

          Bilgi("Öğretmen", g.ogretmenAd or "?")
          Bilgi("Kalan süre", SA.SureYaz(g.bitis - CurTime()), (g.bitis - CurTime()) < 900 and C.warn or nil)

          if (g.asama == 1) then
               local raf = SA.RafBul(g.raf)
               if (raf) then
                    Bilgi("Hedef raf", (SA.Roma[raf.kat] or raf.kat) .. ". kat  ·  " .. raf.no .. " numara", C.gold)
                    local kat = SA.KatBul(ply:GetPos())
                    Bilgi("Bulunduğun kat", kat and ((SA.Roma[kat] or kat) .. ". kat" .. (kat == raf.kat and "  ·  doğru kat" or "")) or "kütüphanede değilsin", kat == raf.kat and C.ready or C.warn)
               end
               local ceza = (g.cezaBitis or 0) - CurTime()
               if (ceza > 0) then Bilgi("Yanlış kitap", math.ceil(ceza) .. " saniye bekle", C.bad) end
          elseif (g.asama == 2) then
               local gerek = SA.OkumaGerek(ply)
               local okunan = ply:GetNW2Int("SardonAkranOkunan", g.okunan)
               local okuyor = ply:GetNW2Bool("SardonAkranOkuyor")
               Bilgi("Okuma", "%" .. math.floor(okunan / gerek * 100) .. "  ·  " .. SA.SureYaz(gerek - okunan) .. " kaldı", okuyor and C.ready or C.warn)
               Ilerleme(x + 16, ty, w - 32, okunan / gerek, okuyor and R.altin or C.warn)
               ty = ty + 18
               T(okuyor and "Rafın yakınındasın; okuma sürüyor." or "Raftan uzaklaştın; okuma durdu.", "sans11", x + 16, ty, okuyor and C.ready or C.warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          elseif (g.asama == 3) then
               local alan, uzak = SA.EnYakinAlan(ply:GetPos())
               local icinde = SA.AlandaMi(ply:GetPos())
               Bilgi("Talim alanı", icinde and "içindesin" or (alan and ((alan.ad or "Talim") .. " · " .. math.max(0, math.floor(uzak * 0.019)) .. " m") or "tanımlı değil"), icinde and C.ready or C.warn)
               local t = SA.CharOyuncu(g.ogretmen)
               local ok = IsValid(t) and t:GetPos():Distance(ply:GetPos()) <= SA.Ayar.ogretmenMesafe
               Bilgi("Öğretmenin", ok and "yakında" or "uzakta", ok and C.ready or C.warn)
               local tus = SardonConfig and SardonConfig.Options and SardonConfig.Options.akran_talim and input.GetKeyName(SardonConfig:Get("akran_talim")) or "J"
               Bilgi("Talim tuşu", string.upper(tus or "J") .. "  (TAB › Ayarlar › Tuş Atamaları)")

               T("BAŞARILI RÜN", "sans10", x + 16, ty + 4, C.eyebrow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               for i = 1, SA.Ayar.basariGerek do
                    local cx = x + 120 + (i - 1) * 26
                    if (i <= g.basari) then
                         SA.Isik(S(cx), S(ty + 4), S(14), R.altin, 140)
                         SA.Yildiz(S(cx), S(ty + 4), S(8), R.altin, 255)
                    else
                         SA.Halka(S(cx), S(ty + 4), S(7), S(1.2), C.groupCount, 255, 20)
                    end
               end
          else
               Bilgi("Durum", "öğretmeninin onayı bekleniyor", C.gold)
          end

          -- görevi bırak (iki tık)
          local iptalOnay = st.iptal and st.iptal.id == "ben" and st.iptal.t > RealTime()
          Dugme(x + w - 166, y + h - 40, 150, 26, iptalOnay and "Emin misin? Tekrar bas" or "Görevi bırak", function()
               if (iptalOnay) then
                    local c = LocalPlayer():GetCharacter()
                    if (c) then SA.Iptal(c:GetID()) end
                    st.iptal = nil
               else
                    st.iptal = {id = "ben", t = RealTime() + 3}
               end
          end)
     end

     local function RunKarti(g)
          local x, y, w, h = 574, 188, 506, 332
          Kart(x, y, w, h, "BÜYÜNÜN RÜNÜ", g.buyu)
          local ply = LocalPlayer()
          local oran, gizli = 1, false
          if (g.asama == 1) then
               gizli = true
          elseif (g.asama == 2) then
               oran = math.Clamp(ply:GetNW2Int("SardonAkranOkunan", g.okunan) / SA.OkumaGerek(ply), 0, 1)
          end

          RunOnizleme(g.buyu, x + w / 2, y + 160, 84, oran, gizli)

          local metin
          if (gizli) then
               metin = "Rün kitabın sayfalarında saklı. Kitabı bulup okudukça belirecek."
          elseif (oran < 0.5) then
               metin = "Okudukça rünün çizgileri belirginleşiyor..."
          else
               local s = SA.Sablon(g.buyu)
               metin = s and s.tarif or ""
          end
          for i, satir in ipairs(K.Wrap(metin, "sans12", S(w - 40))) do
               if (i > 3) then break end
               K.Text(satir, "sans12", S(x + w / 2), S(y + h - 64) + (i - 1) * S(17), C.desc, TEXT_ALIGN_CENTER)
          end
     end

     local function BilinenIzgara(x, y, w, h, baslik)
          Kart(x, y, w, h, baslik)
          local liste = SA.TemelListe()
          local n = 0
          for _, b in ipairs(liste) do if (Bilir(b)) then n = n + 1 end end
          T(n .. " / " .. #liste, "serif14", x + w - 16, y + 14, C.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

          local cols, tw, th, adim = 3, (w - 28 - 12) / 3, 30, 35
          local gy = y + 30
          local gh = math.floor((h - 36 + 5) / adim) * adim - 5 -- yalnız tam satırlar
          local k = KaydirBasla("bilinen", x, gy, w, gh, math.ceil(#liste / cols) * adim - 5, adim)
          for i, b in ipairs(liste) do
               local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
               local tx, ty = x + 14 + col * (tw + 6), gy + row * adim - k.simdi
               if (Gorunur(k, ty, th)) then
                    local bilir = Bilir(b)
                    B(tx, ty, tw, th, Color(14, 21, 18, 220))
                    O(tx, ty, tw, th, bilir and C.secLine or C.rowLine)
                    T(K.Clip(b, "sans12", S(tw - 30)), "sans12", tx + 10, ty + th / 2, bilir and C.ivory or C.rowSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    if (bilir) then K.Check(S(tx + tw - 18), S(ty + th / 2 - 4), S(8), C.ready) end
               end
          end
          KaydirBitir(k, x + w - 7, gy, gh)
     end

     local function Anlatim(x, y, w, h, baslik, ek)
          Kart(x, y, w, h, "NASIL İŞLER", baslik)
          local adimlar = {
               {"Teklif", SA.Ayar.ogretmenYil .. ". yıl ve üstü bir öğretmen, bildiği bir Temel büyüyü sana teklif eder."},
               {"Kütüphane", "Söylenen kata çık, numaralı rafı bul, rafta büyünün kitabını seç."},
               {"Okuma", SA.Ayar.okumaDakika .. " dakika rafın yakınında oku; rün sayfalarda belirir."},
               {"Talim", "Talim alanında öğretmeninin önünde rünü asanla havada " .. SA.Ayar.basariGerek .. " kez çiz."},
               {"Onay", "Öğretmenin onaylar, büyü artık senin."}
          }
          local ty = y + 66
          for i, a in ipairs(adimlar) do
               SA.Daire(S(x + 28), S(ty + 6), S(10), C.primFall, 255, 20)
               SA.Halka(S(x + 28), S(ty + 6), S(10), S(1), C.tabEdge, 255, 24)
               T(tostring(i), "sans11", x + 28, ty + 6, C.ivoryHi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               T(a[1], "serif14", x + 48, ty, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               local satirlar = K.Wrap(a[2], "sans11", S(w - 70))
               for j, satir in ipairs(satirlar) do
                    K.Text(satir, "sans11", S(x + 48), S(ty + 10) + (j - 1) * S(15), C.desc)
               end
               ty = ty + 24 + #satirlar * 15 + 6
          end
          if (ek) then ek(ty) end
     end

     local function OgrenciGorunumu(v)
          local g = SA.Gorev
          if (g) then
               Yolculuk(g)
               AsamaKarti(g)
               RunKarti(g)
               return
          end
          Anlatim(0, 60, 560, 460, "Bir öğretmenin seni seçmesini bekle", function(ty)
               for i, satir in ipairs(K.Wrap("Bir öğretmen teklif gönderdiğinde ekranında bir davet çıkar. Kabul ettiğinde yolculuğun burada görünür.", "sans12", S(528))) do
                    K.Text(satir, "sans12", S(16), S(ty + 8) + (i - 1) * S(18), C.ready)
               end
          end)
          BilinenIzgara(574, 60, 506, 460, "BİLDİĞİN TEMEL BÜYÜLER")
     end

     local function BilgiGorunumu(v)
          Anlatim(0, 60, 560, 460, "Akran Yardımı", function(ty)
               local sv = v and v.seviye or 0
               T("Öğretmenliğe kalan", "sans11", 16, ty + 10, C.dt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               T(SA.YilYaz(sv) .. "  /  " .. SA.Ayar.ogretmenYil .. ". Yıl", "serif14", 544, ty + 10, C.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               Ilerleme(16, ty + 24, 528, sv / math.max(1, (SA.Ayar.ogretmenYil - 1) * 5))
          end)
          BilinenIzgara(574, 60, 506, 460, "BİLDİĞİN TEMEL BÜYÜLER")
     end

     /*
     *   tuval
     */

     tuval.Paint = function(s, w, h)
          st.bolgeler = {}
          st.kaydirAlan = {}
          mx, my = s:CursorPos()

          local v = SA.PanelVeri
          local g = SA.Gorev
          local secenekler = {}
          if (v and v.ogretmen) then secenekler[#secenekler + 1] = "ogretmen" end
          if (g or (v and v.ogrenci)) then secenekler[#secenekler + 1] = "ogrenci" end
          if (!table.HasValue(secenekler, st.gorunum)) then
               st.gorunum = (g and "ogrenci") or secenekler[1] or "bilgi"
          end

          Baslik(v, secenekler)
          K.Box(0, S(50), w, 1, C.navLine)

          if (!v) then
               T("Yükleniyor...", "serif15", W / 2, H / 2, C.rowSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          elseif (st.gorunum == "ogretmen") then
               OgretmenGorunumu(v)
          elseif (st.gorunum == "ogrenci") then
               OgrenciGorunumu(v)
          else
               BilgiGorunumu(v)
          end

          st.P:Ciz()

          local el = false
          for _, b in ipairs(st.bolgeler) do
               if (mx >= b[1] and mx <= b[1] + b[3] and my >= b[2] and my <= b[2] + b[4]) then el = true break end
          end
          s:SetCursor(el and "hand" or "arrow")
     end

     -- Paint ızgaranın ortasında hata verirse kırpma açık kalıp bütün ekranı kesmesin
     tuval.PaintOver = function()
          if (st.makas) then
               render.SetScissorRect(0, 0, 0, 0, false)
               st.makas = nil
          end
     end

     tuval.OnMouseWheeled = function(s, delta)
          local x, y = s:CursorPos()
          for _, a in ipairs(st.kaydirAlan) do
               if (x >= a[1] and x <= a[1] + a[3] and y >= a[2] and y <= a[2] + a[4]) then
                    local k = st.kaydir[a[5]]
                    if (k and k.max > 0) then
                         k.hedef = math.Clamp(k.hedef - delta * a[6], 0, k.max)
                         return true
                    end
               end
          end
     end

     tuval.OnMousePressed = function(s, kod)
          if (kod != MOUSE_LEFT) then return end
          local x, y = s:CursorPos()
          for i = #st.bolgeler, 1, -1 do
               local b = st.bolgeler[i]
               if (x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4]) then
                    if (N.SndClick) then N.SndClick() end
                    b[5]()
                    return
               end
          end
     end

     tuval.Think = function()
          if (RealTime() - st.sonIstek > 2) then
               st.sonIstek = RealTime()
               SA.PanelIste()
          end
     end

     -- bildirimler pencere içinde de görünsün (HUD şeritleri menünün altında kalır)
     hook.Add("SardonAkranBildirim", tuval, function(_, baslik, alt, tur)
          if (IsValid(ctx.menu) and ctx.menu.Flash) then ctx.menu:Flash(baslik .. (alt != "" and ("  ·  " .. alt) or ""), tur == "kotu" and "bad" or nil) end
          if (tur == "iyi") then st.P:Patlama(S(W / 2), S(H / 2), R.altin, 50, 1.4) end
          timer.Simple(0.3, SA.PanelIste)
     end)

     hook.Add("SardonAkranGorev", tuval, function()
          timer.Simple(0.1, SA.PanelIste)
     end)

     ctx.SetHead({
          note = function()
               local g = SA.Gorev
               if (g) then return "AKRAN · " .. g.buyu .. " · " .. SA.Asamalar[g.asama].kisa end
               local v = SA.PanelVeri
               if (v and v.ogretmen) then return "AKRAN · " .. #(v.gorevler or {}) .. " ÖĞRENCİ" end
               return "AKRAN YARDIMI"
          end
     })

     return function() SA.PanelIste() end
end

/*
*   kayıt :: asa menüsü yüklendiğinde (yükleme sırası belli değil, birkaç kez denenir)
*/

local function Kaydol()
     local N = HpwRewrite and HpwRewrite.Nocturne
     if (!N or !N.Kitap or !N.Kitap.S) then return false end

     N.Pages = N.Pages or {}
     N.Pages.akran = {
          id = "akran",
          label = "Akran Yardımı",
          title = "Akran Yardımı  ·  kıdemli öğrenciler yeni gelenlere Temel büyü öğretir",
          build = Build
     }

     -- açık pencere eski sekme listesiyle kurulduysa yeniden kurulsun
     local win = HpwRewrite.VGUI and HpwRewrite.VGUI.Window
     if (IsValid(win) and win.Theme == "kitap" and !win:IsVisible()) then
          win:Remove()
          HpwRewrite.VGUI.Window = nil
     end

     return true
end

if (!Kaydol()) then
     timer.Create("SardonAkran.Sayfa", 2, 30, function()
          if (Kaydol()) then timer.Remove("SardonAkran.Sayfa") end
     end)
end
