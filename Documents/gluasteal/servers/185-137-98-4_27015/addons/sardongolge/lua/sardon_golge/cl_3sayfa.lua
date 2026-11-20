-- "addons\\sardongolge\\lua\\sardon_golge\\cl_3sayfa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gölge :: istemci — Shine Admin "Gölge · Levazımatçı" sayfası. Sekmeler:
--   Ayarlar  : fiyat, hak, paket, hediye/Bakanlık olasılığı, gezinti, hançer/kılık süreleri, tezgâh kapalı
--              (sunucu sv_3golge S.AYAR_SEMA; kaydetme süper admin, görme yetkili)
--   Noktalar : Gölge'nin ışınlandığı noktalar — ekle (bulunduğun yer + ipucu), git, ipucu yaz, sil, şimdi ışınla
--   Kayıtlar : son 200 saplama / alışveriş / kılık / ışınlanma / ayar kaydı (sqlite sardon_golge_kayit)
-- Ağ: "SardonGolge.Ayar" (JSON; {admin = ...} sayfa verisi, {istemci = ...} herkesin kullandığı ayarlar).
-- Kalıp: [sardon] ck cl_2sayfa.lua, [sardon] portkey cl_5shine.lua.
local S = SardonGolge

S.AdminVeri = S.AdminVeri or nil
S.AdminSurum = S.AdminSurum or 0
S.KayitSurum = S.KayitSurum or 0

local TURLER = {
     saplama = "Saplama", satin = "Satın alma", donus = "Kılığa büründü", kilik_bitti = "Kılık bitti",
     isinlanma = "Gölge ışınlandı", hak_sifirla = "Hak sıfırlandı", ayar = "Ayar değişti", nokta = "Nokta",
     mal = "Mal satışı", mal_ayar = "Mal ayarı", dolandirma = "Dolandırma",
}

local SEKMELER = { { "ayar", "Ayarlar" }, { "mal", "Mallar" }, { "nokta", "Noktalar" }, { "kayit", "Kayıtlar" } }
local KAYIT_SEKME = { { "hepsi", "Hepsi" }, { "saplama", "Saplama" }, { "satin", "Satın alma" }, { "mal", "Mallar" }, { "kilik", "Kılık" }, { "isinlanma", "Gölge" }, { "ayar", "Ayar" } }

local function Admin(islem, t)
     t = t or {}
     t.islem = islem
     net.Start("SardonGolge.Ayar")
     net.WriteString(util.TableToJSON(t))
     net.SendToServer()
end

net.Receive("SardonGolge.Ayar", function()
     local t = util.JSONToTable(net.ReadString() or "") or {}
     if istable(t.istemci) then table.Merge(S.Ayar, t.istemci) end
     if istable(t.admin) then
          S.AdminVeri = t.admin
          S.AdminSurum = S.AdminSurum + 1
     end
end)

local function Gosterim(a, v)
     if a.tur == "bool" then return v == true end
     return math.Round((tonumber(v) or 0) / (a.birim or 1))
end

local function Saklama(a, g)
     if a.tur == "bool" then return g == true end
     return math.Round(tonumber(g) or 0) * (a.birim or 1)
end

----------------------------------------------------------------------------------------
-- Ayarlar sekmesi
----------------------------------------------------------------------------------------
local function AyarlarKur(N, kok, W, H, ctx)
     local u = N.u
     local V = S.AdminVeri
     if not V then
          kok.Paint = function(_, w, h) N.Text("Ayarlar yükleniyor…", "body", w / 2, h / 2, N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
          return
     end
     kok.Paint = nil
     local taslak = table.Copy(V.ayar or {})
     kok.taslak = taslak

     local function Kirli()
          local n = 0
          for _, a in ipairs(V.sema or {}) do
               if Gosterim(a, taslak[a.k]) ~= Gosterim(a, V.ayar[a.k]) then n = n + 1 end
          end
          return n
     end
     kok.Kirli = Kirli

     local sc = N.Scroll(kok, 0, 0, u(W), u(H - 64))
     local kolW = math.floor((W - 16) / 2)
     local y = 0
     local gruplar, sira = {}, {}
     for _, a in ipairs(V.sema or {}) do
          if not gruplar[a.grup] then gruplar[a.grup] = {} sira[#sira + 1] = a.grup end
          table.insert(gruplar[a.grup], a)
     end

     for _, grup in ipairs(sira) do
          local bas = vgui.Create("DPanel", sc)
          bas:SetPos(0, u(y))
          bas:SetSize(u(W) - u(12), u(30))
          bas.Paint = function(_, w, h)
               N.Text(grup, "body", u(4), h / 2, N.Clr.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Box(0, h - 1, w, 1, N.Clr.tableLine)
          end
          y = y + 38
          local i = 0
          for _, a in ipairs(gruplar[grup]) do
               local x = (i % 2) * (kolW + 16)
               if a.tur == "bool" then
                    N.Toggle(sc, u(x), u(y), u(kolW), u(54), a.ad, function() return taslak[a.k] == true end,
                         function(v) if V.yaz then taslak[a.k] = v end end, a.aciklama, not V.yaz)
               else
                    local etiket = a.ad .. "   ·   varsayılan " .. Gosterim(a, (V.varsayilan or {})[a.k])
                    local sl = N.Slider(sc, u(x), u(y), u(kolW), etiket, a.min, a.max, 0, function() return Gosterim(a, taslak[a.k]) end,
                         function(v) taslak[a.k] = Saklama(a, v) end)
                    if not V.yaz and sl.Slider then sl.Slider:SetEnabled(false) end
               end
               i = i + 1
               if i % 2 == 0 then y = y + 62 end
          end
          if i % 2 == 1 then y = y + 62 end
          y = y + 10
     end

     local bar = N.StickyBar(kok, 0, u(H - 56), u(W), function()
          if not V.yaz then return "Görüntüleme: ayarları yalnız süper admin değiştirebilir.", N.Clr.warn end
          local n = Kirli()
          if n > 0 then return n .. " kaydedilmemiş değişiklik.", N.Clr.warn end
          return "Bu hafta (" .. tostring(V.hafta) .. ") diğerlerinin fiyatı " .. tostring(V.digerFiyat) .. " Galleon. Kaydedince hemen geçerli olur."
     end)
     local kaydet = N.Button(bar, u(W) - u(170), u(9), u(170), u(36), "Kaydet", function()
          Admin("yaz", { ayar = taslak })
          ctx.Flash("Gölge ayarları gönderildi.")
     end)
     kaydet.Think = function(s) s:SetEnabled(V.yaz == true and Kirli() > 0) end
     local sifirla = N.Button(bar, u(W) - u(170) - u(200), u(9), u(190), u(36), "Varsayılana dön", function()
          N.Confirm("Varsayılana dön", "Bütün Gölge ayarları kurulumdaki değerlere döner (fiyatlar, haklar, süreler).", "Sıfırla", function()
               Admin("sifirla")
          end, true)
     end, "ghost")
     sifirla.Think = function(s) s:SetEnabled(V.yaz == true) end
     local geri = N.Button(bar, u(W) - u(170) - u(200) - u(160), u(9), u(150), u(36), "Değişiklikleri at", function()
          for k in pairs(taslak) do taslak[k] = V.ayar[k] end
          kok:Yeniden()
     end, "quiet")
     geri.Think = function(s) s:SetEnabled(Kirli() > 0) end
end

----------------------------------------------------------------------------------------
-- Noktalar sekmesi
----------------------------------------------------------------------------------------
local function NoktalarKur(N, kok, W, H, ctx)
     local u = N.u
     local sel
     local function V() return S.AdminVeri or {} end
     local function Secili()
          for _, n in ipairs(V().noktalar or {}) do if n.no == sel then return n end end
     end

     local durum = vgui.Create("DPanel", kok)
     durum:SetPos(0, 0)
     durum:SetSize(u(W), u(34))
     durum.Paint = function(_, w, h)
          local v = V()
          local metin = (v.aktorVar and ("Gölge şu an: " .. ((v.aktorAlan or "") ~= "" and v.aktorAlan or "alan dışı") .. (v.simdiki and v.simdiki > 0 and ("  (nokta " .. v.simdiki .. ")") or "")) or "Gölge dünyada yok")
               .. "   ·   sıradaki: " .. ((v.siradaki or 0) > 0 and ("nokta " .. v.siradaki) or "—")
               .. "   ·   kendiliğinden yer değiştirmeye " .. S.Sure(v.gezintiKalan or 0)
               .. ((v.muhatap or "") ~= "" and ("   ·   konuşuyor: " .. v.muhatap) or "")
          N.Text(N.Clip(metin, "tiny", w - u(8)), "tiny", u(4), h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end

     local head = vgui.Create("DPanel", kok)
     head:SetPos(0, u(36))
     head:SetSize(u(W), u(30))
     head.Paint = function(_, w)
          N.TableHead(0, 0, w, { { "No", u(16) }, { "İpucu / alan", w * 0.1 }, { "Uzaklık", w - u(24), TEXT_ALIGN_RIGHT } })
     end

     local list = N.VList(kok, 0, u(66), u(W), u(H - 66 - 132), {
          rowH = u(46),
          gapY = 0,
          emptyText = "Hiç nokta yok. Gölge görev yerinde (Domuz Kafası) duruyor.",
          onClick = function(n) sel = n.no end,
          paintRow = function(n, _, x, y, w, h, hovered)
               local on = sel == n.no
               if on then
                    N.Box(x, y, w, h, N.Clr.selRow)
                    N.Box(x, y, u(2), h, N.Clr.gold)
               elseif hovered then
                    N.Box(x, y, w, h, N.Clr.hoverRow)
               end
               N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
               local v = V()
               local rozet = (n.no == v.simdiki and "ŞU AN" or "") .. (n.no == v.siradaki and ((n.no == v.simdiki and " · " or "") .. "SIRADAKİ") or "")
               N.Text(tostring(n.no), "row", x + u(16), y + h / 2, on and N.Clr.text or N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip(n.ipucu ~= "" and n.ipucu or "(ipucu yok: bölgeden söylenir)", "row", w * 0.72), "row", x + w * 0.1, y + h / 2 - u(8),
                    n.ipucu ~= "" and N.Clr.tdText or N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip((n.alan ~= "" and n.alan or "alan dışı") .. "  ·  " .. n.pos, "tiny", w * 0.72), "tiny", x + w * 0.1, y + h / 2 + u(9), N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(rozet, "tiny", x + w - u(110), y + h / 2, N.Clr.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               N.Text(n.uz .. " birim", "tiny", x + w - u(24), y + h / 2, N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end
     })
     kok.Yenile = function() list:SetItems(V().noktalar or {}, true) end
     kok.Yenile()

     local alt = u(H - 126)
     local _, giris = N.PlainEntry(kok, 0, alt, u(W), u(36), "İpucu (Snatcher'a alışverişten sonra söylenir; boşsa bölgeden genel ipucu)")
     local bw = math.floor((W - 4 * 10) / 5)
     local function B(i, metin, fn, stil, etkin)
          local b = N.Button(kok, u((bw + 10) * (i - 1)), alt + u(46), u(bw), u(36), metin, fn, stil)
          if etkin then b.Think = function(s) s:SetEnabled(etkin()) end end
          return b
     end
     B(1, "Bulunduğum yere ekle", function()
          Admin("nokta_ekle", { ipucu = giris:GetValue() })
          ctx.Flash("Nokta eklendi: baktığın yön Gölge'nin yönü olur.")
     end)
     B(2, "Seçiliye git", function() local n = Secili() if n then Admin("nokta_git", { no = n.no }) end end, "ghost", function() return Secili() ~= nil end)
     B(3, "Seçilinin ipucunu yaz", function()
          local n = Secili()
          if n then Admin("nokta_ipucu", { no = n.no, ipucu = giris:GetValue() }) end
     end, "ghost", function() return Secili() ~= nil end)
     B(4, "Seçiliyi sil", function()
          local n = Secili()
          if not n then return end
          N.Confirm("Noktayı sil", "Nokta " .. n.no .. " silinir; Gölge oraya bir daha ışınlanmaz.", "Sil", function()
               Admin("nokta_sil", { no = n.no })
               sel = nil
          end, true)
     end, "danger", function() return Secili() ~= nil end)
     B(5, "Gölge'yi şimdi ışınla", function() Admin("simdi") end, nil, function() return #(V().noktalar or {}) > 0 end)
end

----------------------------------------------------------------------------------------
-- Kayıtlar sekmesi
----------------------------------------------------------------------------------------
local function KayitUyar(r, sekme)
     if sekme == "hepsi" then return true end
     if sekme == "kilik" then return r.tur == "donus" or r.tur == "kilik_bitti" end
     if sekme == "isinlanma" then return r.tur == "isinlanma" or r.tur == "nokta" end
     if sekme == "mal" then return r.tur == "mal" or r.tur == "mal_ayar" end
     if sekme == "satin" then return r.tur == "satin" or r.tur == "dolandirma" end
     return r.tur == sekme
end

local function KayitlarKur(N, kok, W, H, ctx)
     local u = N.u
     local sekme, sel, list = "hepsi", nil, nil
     local function satirlar()
          local out = {}
          for _, r in ipairs(S.Kayitlar or {}) do if KayitUyar(r, sekme) then out[#out + 1] = r end end
          return out
     end
     kok.Secili = function()
          for _, r in ipairs(S.Kayitlar or {}) do if r.id == sel then return r end end
     end
     kok.Yenile = function() if IsValid(list) then list:SetItems(satirlar(), true) end end

     N.SubTabs(kok, 0, 0, u(W), KAYIT_SEKME, function() return sekme end, function(id) sekme, sel = id, nil kok.Yenile() end)

     local head = vgui.Create("DPanel", kok)
     head:SetPos(0, u(54))
     head:SetSize(u(W), u(30))
     head.Paint = function(_, w)
          N.TableHead(0, 0, w, { { "Tür", u(16) }, { "Kim", w * 0.24 }, { "Ayrıntı", w * 0.5 }, { "Tarih", w - u(24), TEXT_ALIGN_RIGHT } })
     end

     list = N.VList(kok, 0, u(84), u(W), u(H - 84 - 8), {
          rowH = u(46),
          gapY = 0,
          emptyText = "Kayıt yok.",
          onClick = function(r) sel = r.id end,
          paintRow = function(r, _, x, y, w, h, hovered)
               local on = sel == r.id
               if on then
                    N.Box(x, y, w, h, N.Clr.selRow)
                    N.Box(x, y, u(2), h, N.Clr.gold)
               elseif hovered then
                    N.Box(x, y, w, h, N.Clr.hoverRow)
               end
               N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
               local ust, alt = y + h / 2 - u(8), y + h / 2 + u(9)
               N.Text(TURLER[r.tur] or r.tur or "?", "row", x + u(16), y + h / 2, on and N.Clr.text or N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip((r.kim or "") ~= "" and r.kim or "—", "row", w * 0.25), "row", x + w * 0.24, ust, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip((r.hedef or "") ~= "" and ("→ " .. r.hedef) or "", "tiny", w * 0.25), "tiny", x + w * 0.24, alt, N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip(r.ayrinti or "", "tiny", w * 0.34), "tiny", x + w * 0.5, y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(r.zaman and os.date("%d.%m %H:%M", r.zaman) or "—", "tiny", x + w - u(24), y + h / 2, N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end
     })
     kok.Yenile()
     S.Iste(S.ISTEK.KAYIT)
end

----------------------------------------------------------------------------------------
-- Mallar sekmesi: Gölge'nin tezgâhına konan Helix eşyaları (sv_3golge S.Mallar; yazma süper admin)
----------------------------------------------------------------------------------------
local KIM_SECENEK = { { "herkes", "Herkes" }, { "snatcher", "Yalnız Snatcher" }, { "diger", "Snatcher dışındakiler" } }

local function KimAd(k)
     for _, x in ipairs(KIM_SECENEK) do if x[1] == k then return x[2] end end
     return tostring(k)
end

local function EsyaAd(id)
     local it = ix.item.list[id or ""]
     return it and isstring(it.name) and it.name or tostring(id or "?")
end

local function EsyaAra(metin)
     metin = string.lower(string.Trim(metin or ""))
     local t = {}
     if metin == "" then return t end
     for id, it in SortedPairs(ix.item.list) do
          local ad = isstring(it.name) and it.name or ""
          if string.find(string.lower(id), metin, 1, true) or string.find(string.lower(ad), metin, 1, true) then
               t[#t + 1] = { id = id, ad = ad ~= "" and ad or id }
               if #t >= 150 then break end
          end
     end
     return t
end

local function MallarKur(N, kok, W, H, ctx)
     local u = N.u
     local function V() return S.AdminVeri or {} end
     local LW = math.floor(W * 0.4)
     local RX = LW + 16
     local RW = W - RX
     local secId = S.MalSecili
     local sag, FormKur

     local function Bos()
          return { id = 0, esya = "", ad = "", fiyat = 100, snatcherFiyat = 0, stok = -1, kisiSinir = 1, kimler = "herkes", aktif = true, soz = "", veri = "" }
     end
     local function Bul(id)
          for _, m in ipairs(V().mallar or {}) do if m.id == id then return m end end
     end

     N.Button(kok, 0, 0, u(LW), u(36), "Yeni mal", function()
          secId, S.MalSecili = 0, 0
          FormKur(Bos())
     end)
     local list = N.VList(kok, 0, u(44), u(LW), u(H - 44), {
          rowH = u(52),
          gapY = 0,
          emptyText = "Tezgâhta mal yok. \"Yeni mal\" ile ekle.",
          onClick = function(m)
               secId, S.MalSecili = m.id, m.id
               FormKur(table.Copy(m))
          end,
          paintRow = function(m, _, x, y, w, h, hovered)
               local on = secId == m.id
               if on then
                    N.Box(x, y, w, h, N.Clr.selRow)
                    N.Box(x, y, u(2), h, N.Clr.gold)
               elseif hovered then
                    N.Box(x, y, w, h, N.Clr.hoverRow)
               end
               N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
               local ad = (m.ad or "") ~= "" and m.ad or EsyaAd(m.esya)
               N.Text(N.Clip(ad, "row", w - u(130)), "row", x + u(14), y + h / 2 - u(9), m.aktif and N.Clr.text or N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(N.Clip(m.esya .. "  ·  " .. KimAd(m.kimler) .. (m.gecerli and "" or "  ·  EŞYA YOK"), "tiny", w - u(130)), "tiny", x + u(14), y + h / 2 + u(10),
                    m.gecerli and N.Clr.faint or N.Clr.bad, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               N.Text(string.Comma(m.fiyat) .. " G", "row", x + w - u(14), y + h / 2 - u(9), N.Clr.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               local stok = m.stok < 0 and ("satılan " .. (m.satilan or 0)) or ((m.satilan or 0) .. "/" .. m.stok .. " satıldı")
               N.Text(stok .. (m.aktif and "" or " · kapalı"), "tiny", x + w - u(14), y + h / 2 + u(10), N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end
     })

     FormKur = function(m)
          if IsValid(sag) then sag:Remove() end
          sag = vgui.Create("DPanel", kok)
          sag:SetPos(u(RX), 0)
          sag:SetSize(u(RW), u(H))
          sag.Paint = nil
          if not m then
               sag.Paint = function(_, w, h) N.Text("Soldan bir mal seç ya da \"Yeni mal\" ile ekle.", "body", w / 2, h / 2, N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
               return
          end
          -- yetki her karede güncel veriden (form, sunucu verisi gelmeden kurulmuş olabilir)
          local function Yaz() return V().yaz == true end
          local half = math.floor((RW - 12) / 2)
          local y = 0

          local bas = vgui.Create("DPanel", sag)
          bas:SetPos(0, 0)
          bas:SetSize(u(RW), u(28))
          bas.Paint = function(_, w, h)
               local secili = (m.esya or "") ~= "" and (EsyaAd(m.esya) .. "  (" .. m.esya .. ")") or "Eşya seçilmedi: aşağıda ara ve tıkla"
               N.Text(N.Clip((m.id > 0 and ("Mal #" .. m.id .. " · ") or "Yeni mal · ") .. secili, "body", w), "body", 0, h / 2,
                    (m.esya or "") ~= "" and N.Clr.gold or N.Clr.warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
          y = y + 32

          local sonuc
          N.PlainEntry(sag, 0, u(y), u(RW), u(34), "Eşya ara (ad ya da kimlik, ör. iksir, kitap, hanceri)", function(v)
               if IsValid(sonuc) then sonuc:SetItems(EsyaAra(v), false) end
          end)
          y = y + 40
          sonuc = N.VList(sag, 0, u(y), u(RW), u(112), {
               rowH = u(28),
               gapY = 0,
               emptyText = "Aramak için yaz.",
               onClick = function(e) m.esya = e.id end,
               paintRow = function(e, _, x, yy, w, h, hovered)
                    if m.esya == e.id then N.Box(x, yy, w, h, N.Clr.selRow) elseif hovered then N.Box(x, yy, w, h, N.Clr.hoverRow) end
                    N.Text(N.Clip(e.ad .. "   ·   " .. e.id, "tiny", w - u(16)), "tiny", x + u(8), yy + h / 2, m.esya == e.id and N.Clr.gold or N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
          })
          y = y + 120

          local _, adE = N.PlainEntry(sag, 0, u(y), u(RW), u(34), "Görünen ad (boşsa eşyanın adı)", function(v) m.ad = v end)
          adE:SetValue(m.ad or "")
          y = y + 42

          N.Slider(sag, 0, u(y), u(half), "Fiyat (Galleon)", 0, 20000, 0, function() return m.fiyat end, function(v) m.fiyat = math.Round(v) end)
          N.Slider(sag, u(half + 12), u(y), u(half), "Snatcher fiyatı (0 = aynı)", 0, 20000, 0, function() return m.snatcherFiyat end, function(v) m.snatcherFiyat = math.Round(v) end)
          y = y + 62
          N.Slider(sag, 0, u(y), u(half), "Haftalık stok (-1 = sınırsız)", -1, 500, 0, function() return m.stok end, function(v) m.stok = math.Round(v) end)
          N.Slider(sag, u(half + 12), u(y), u(half), "Kişi başı haftalık (0 = sınırsız)", 0, 50, 0, function() return m.kisiSinir end, function(v) m.kisiSinir = math.Round(v) end)
          y = y + 62

          N.Combo(sag, 0, u(y + 9), u(half), u(36), KimAd(m.kimler), { "Herkes", "Yalnız Snatcher", "Snatcher dışındakiler" }, function(val)
               for _, x in ipairs(KIM_SECENEK) do if x[2] == val then m.kimler = x[1] end end
          end)
          N.Toggle(sag, u(half + 12), u(y), u(half), u(54), "Tezgâhta", function() return m.aktif == true end, function(v) m.aktif = v end, "Kapalıyken satılmaz, listede kalır.")
          y = y + 62

          local _, sozE = N.PlainEntry(sag, 0, u(y), u(RW), u(34), "Gölge'nin sözü (kartta tırnak içinde; boşsa eşyanın açıklaması)", function(v) m.soz = v end)
          sozE:SetValue(m.soz or "")
          y = y + 42
          local _, veriE = N.PlainEntry(sag, 0, u(y), u(RW), u(34), "Eşya verisi, JSON (gelişmiş; çoğu eşyada boş bırak)", function(v) m.veri = v end)
          veriE:SetValue(m.veri or "")
          y = y + 46

          local kay = N.Button(sag, 0, u(y), u(half), u(36), m.id > 0 and "Kaydet" or "Tezgâha ekle", function()
               if (m.esya or "") == "" then return ctx.Flash("Önce bir eşya seç.", "bad") end
               Admin("mal_kaydet", { mal = m })
               if m.id == 0 then
                    secId, S.MalSecili = nil, nil
                    FormKur(nil)
               end
          end)
          kay.Think = function(s) s:SetEnabled(Yaz() and (m.esya or "") ~= "") end
          if m.id > 0 then
               local sil = N.Button(sag, u(half + 12), u(y), u(half), u(36), "Sil", function()
                    N.Confirm("Malı sil", ((m.ad or "") ~= "" and m.ad or EsyaAd(m.esya)) .. " Gölge'nin tezgâhından kaldırılır.", "Sil", function()
                         Admin("mal_sil", { id = m.id })
                         secId, S.MalSecili = nil, nil
                         FormKur(nil)
                    end, true)
               end, "danger")
               sil.Think = function(s) s:SetEnabled(Yaz()) end
          end
          local not1 = vgui.Create("DPanel", sag)
          not1:SetPos(0, u(y + 42))
          not1:SetSize(u(RW), u(24))
          not1.Paint = function(_, w, h)
               if not S.AdminVeri then
                    N.Text("Sunucudan veri bekleniyor…", "tiny", 0, h / 2, N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               elseif not Yaz() then
                    N.Text("Görüntüleme: malları yalnız süper admin değiştirebilir.", "tiny", 0, h / 2, N.Clr.warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               end
          end
     end

     kok.Yenile = function() list:SetItems(V().mallar or {}, true) end
     kok.Yenile()
     local m = secId and secId > 0 and Bul(secId)
     FormKur(m and table.Copy(m) or (secId == 0 and Bos() or nil))
end

local KURUCU = { ayar = AyarlarKur, mal = MallarKur, nokta = NoktalarKur, kayit = KayitlarKur }

----------------------------------------------------------------------------------------
-- Sayfa
----------------------------------------------------------------------------------------
local function SayfaKaydet()
     if not (ShineAdmin and ShineAdmin.RegisterPage and ShineAdmin.GetN) then return false end

     ShineAdmin:RegisterPage("golge", {
          label = "Sombra · Proveedor",
          icon = "lock",
          group = "players",
          order = 34,
          title = "Sombra · Proveedor",
          subtitle = "Mercado negro del Cuchillo de la Realidad: precios y cupos semanales, puntos de Sombra, registros de plantación y compras.",
          access = "staff",
          rail = true,

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local Pn, W, H = ctx.panel, ctx.w, ctx.h
               local sekme = KURUCU[ctx.arg or ""] and ctx.arg or (S.SonSekme or "ayar")
               local kok

               local function Kur()
                    if IsValid(kok) then kok:Remove() end
                    S.SonSekme = sekme
                    kok = vgui.Create("DPanel", Pn)
                    kok:SetPos(0, u(56))
                    kok:SetSize(u(W), u(H - 56))
                    kok.Paint = nil
                    kok.surum = S.AdminSurum
                    kok.kayitSurum = S.KayitSurum
                    kok.Yeniden = function() Kur() end
                    KURUCU[sekme](N, kok, W, H - 56, ctx)
                    kok.Think = function(s)
                         if s.surum ~= S.AdminSurum then
                              s.surum = S.AdminSurum
                              -- ayarlarda kaydedilmemiş değişiklik varken yeniden kurma (yazılanlar gitmesin)
                              if sekme == "ayar" and (not s.Kirli or s.Kirli() == 0) then return Kur() end
                              if (sekme == "nokta" or sekme == "mal") and s.Yenile then s.Yenile() end
                         end
                         if s.kayitSurum ~= S.KayitSurum then
                              s.kayitSurum = S.KayitSurum
                              if sekme == "kayit" and s.Yenile then s.Yenile() end
                         end
                    end
               end

               N.SubTabs(Pn, 0, 0, u(W), SEKMELER, function() return sekme end, function(id)
                    sekme = id
                    Kur()
                    Admin("iste")
               end)

               ctx.SetRail({
                    hero = "icons/lock",
                    badge = { text = "Karaborsa", icon = "lock", color = N.Clr.warn },
                    title = function()
                         if sekme == "kayit" and IsValid(kok) and kok.Secili and kok.Secili() then
                              local r = kok.Secili()
                              return TURLER[r.tur] or r.tur
                         end
                         return "Gölge · Levazımatçı"
                    end,
                    body = function()
                         if sekme == "kayit" and IsValid(kok) and kok.Secili and kok.Secili() then return kok.Secili().ayrinti or "" end
                         local v = S.AdminVeri
                         if not v then return "Yükleniyor…" end
                         local a = v.ayar or {}
                         return (a.Kapali and "TEZGÂH KAPALI. " or "") .. "Snatcher haftada " .. tostring(a.SnatcherSinir) .. " kez "
                              .. tostring(a.SnatcherPaket) .. " hançerlik paket alır (" .. tostring(a.SnatcherFiyat) .. " G); diğerleri haftada "
                              .. tostring(a.DigerSinir) .. " kez " .. tostring(a.DigerAdet) .. " hançer (bu hafta " .. tostring(v.digerFiyat)
                              .. " G). Hak SteamID başına, Pazartesi 07:00'de yenilenir."
                    end,
                    props = function()
                         if sekme == "kayit" and IsValid(kok) and kok.Secili and kok.Secili() then
                              local r = kok.Secili()
                              return {
                                   { "Kim", (r.kim or "") ~= "" and r.kim or "—" },
                                   { "Kim SteamID", (r.kimSid or "") ~= "" and util.SteamIDFrom64(r.kimSid) or "—" },
                                   { "Hedef", (r.hedef or "") ~= "" and r.hedef or "—" },
                                   { "Hedef SteamID", (r.hedefSid or "") ~= "" and util.SteamIDFrom64(r.hedefSid) or "—" },
                                   { "Tarih", r.zaman and os.date("%d.%m.%Y %H:%M", r.zaman) or "—" },
                              }
                         end
                         local v = S.AdminVeri or {}
                         return {
                              { "Hafta", tostring(v.hafta or "—") },
                              { "Diğer fiyat (bu hafta)", tostring(v.digerFiyat or "—") .. " G" },
                              { "Nokta", #(v.noktalar or {}) },
                              { "Yetki", v.yaz and "süper admin (yazar)" or "yetkili (görür)" },
                         }
                    end
               })
               ctx.SetHead({ count = function() return #((S.AdminVeri or {}).noktalar or {}) end, note = "NOKTA" })

               Kur()
               Admin("iste")
               return function() Admin("iste") end
          end
     })
     return true
end

-- kayıt listesi gelince (cl_1kopya S.OP.KAYIT) sayfa yenilensin
hook.Add("Think", "SardonGolge.KayitIzle", function()
     if S.Kayitlar ~= S.sonKayitlar then
          S.sonKayitlar = S.Kayitlar
          S.KayitSurum = S.KayitSurum + 1
     end
end)

-- sardon_golge, sardon_shineadmin'den önce yükleniyor (alfabetik); ShineAdmin gelene kadar dene
if not SayfaKaydet() then
     timer.Create("SardonGolge.Sayfa", 1, 120, function()
          if SayfaKaydet() then timer.Remove("SardonGolge.Sayfa") end
     end)
end
