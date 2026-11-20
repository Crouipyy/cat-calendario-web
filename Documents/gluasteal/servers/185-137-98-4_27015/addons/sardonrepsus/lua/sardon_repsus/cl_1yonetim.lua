-- "addons\\sardonrepsus\\lua\\sardon_repsus\\cl_1yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
--[[
     Sardon Repsus :: Shine Admin › Repsus sayfası (istemci). Veri sv_3yonetim.lua.
     Anahtarlar hemen, kaydırıcılar bırakıldıktan yarım saniye sonra kaydedilir.
]]

local R = SardonRepsus

local function Iste(islem, t)
     net.Start(R.NET)
          net.WriteString(islem or "yenile")
          net.WriteTable(t or {})
     net.SendToServer()
end

local function SayfaKaydet()
     if not (ShineAdmin and ShineAdmin.RegisterPage) then return false end
     ShineAdmin:RegisterPage("repsus", {
          label = "Repsus",
          icon = "heart",
          group = "systems",
          order = 6,
          title = "Repsus · Servicio de comida",
          subtitle = "El elfo doméstico Repsus trae comida, bebida y café a jugadores con hambre, sed o sueño; velocidad de hambre/sed.",
          access = function(ply) return ply:IsAdmin() end,
          available = function() return SardonRepsus ~= nil end,

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local P = ctx.panel
               local W, H = ctx.w, ctx.h
               R.Ctx = ctx
               R.Panel = P
               R.Veri = nil   -- eski açılıştan kalan ayar taslağa girmesin
               Iste("yenile")

               local function V() return R.Veri end
               local taslak

               -- üst kutular
               local ust = vgui.Create("DPanel", P)
               ust:SetPos(0, 0)
               ust:SetSize(u(W), u(84))
               ust.Paint = function(_, w, h)
                    local v = V()
                    local kutular = {
                         { "Servis", v and (v.ayar.acik and "Açık" or "Kapalı") or "—", v and (v.ayar.acik and N.Clr.ok or N.Clr.warn) },
                         { "Şu an yolda", v and tostring(v.yolda) or "—" },
                         { "Bugün ziyaret", v and tostring(v.bugun) or "—" },
                         { "Eşikteki oyuncu", v and tostring(v.esikte) or "—" },
                    }
                    local cw = (w - u(12) * 3) / 4
                    for i, k in ipairs(kutular) do
                         local x = (i - 1) * (cw + u(12))
                         N.Box(x, 0, cw, h - u(8), N.Clr.toolBg)
                         N.Outline(x, 0, cw, h - u(8), N.Clr.toolLine, 1)
                         N.Box(x, u(12), u(2), h - u(32), N.Clr.gold)
                         N.TextSpaced(string.utf8upper(k[1]), "micro", x + u(16), u(14), N.Clr.thText, u(2))
                         N.Text(N.Clip(k[2], "count", cw - u(28)), "count", x + u(16), u(32), k[3] or N.Clr.bigStat)
                    end
               end

               local SOL_W = 380
               local ICERIK_Y = 96

               -- sol: ayarlar (veri gelince bir kez kurulur; sonraki yanıtlar taslağı ezmez)
               local sol = N.Scroll(P, 0, u(ICERIK_Y), u(SOL_W), u(H - ICERIK_Y))

               local function Gonder() Iste("ayar", taslak) end

               local function SolKur()
                    local v = V()
                    if not v or taslak then return end
                    taslak = table.Copy(v.ayar)
                    local y = 0

                    local t1 = N.Toggle(sol, 0, u(y), u(SOL_W - 14), u(52), "Repsus yiyecek servisi",
                         function() return taslak.acik end,
                         function(b) taslak.acik = b Gonder() end,
                         "Eşiğe inen oyuncuya yiyecek, içecek ve kahve getirir")
                    sol:AddItem(t1)
                    y = y + 56

                    local t2 = N.Toggle(sol, 0, u(y), u(SOL_W - 14), u(52), "Başka oyuncular da görsün",
                         function() return taslak.herkes end,
                         function(b) taslak.herkes = b Gonder() end,
                         "Kapalıyken Repsus'u yalnız aç oyuncu görür")
                    sol:AddItem(t2)
                    y = y + 64

                    for _, a in ipairs(R.AyarAlanlari) do
                         local k, ondalik = a[1], a[5] or 0
                         local s = N.Slider(sol, 0, u(y), u(SOL_W - 14), a[2], a[3], a[4], ondalik,
                              function() return taslak[k] end,
                              function(val)
                                   val = ondalik > 0 and math.Round(val, ondalik) or math.floor(val + 0.5)
                                   if val == taslak[k] then return end
                                   taslak[k] = val
                                   timer.Create("SardonRepsus.AyarGonder", 0.5, 1, Gonder)
                              end)
                         sol:AddItem(s)
                         y = y + 62
                    end

                    y = y + 4
                    local b = N.Button(sol, 0, u(y), u(SOL_W - 14), u(38), "REPSUS'U BANA GÖNDER (DENEME)", function()
                         Iste("gonder")
                    end, "primary")
                    sol:AddItem(b)
                    y = y + 48

                    local bilgi = vgui.Create("DPanel", sol)
                    bilgi:SetPos(0, u(y))
                    bilgi:SetSize(u(SOL_W - 14), u(260))
                    bilgi.Paint = function(_, pw)
                         local metin = "Repsus oyuncunun göremeyeceği bir yerde belirir, yürüyerek gelir, açlığa göre bir yiyecek ve susuzluğa göre bir içecek bırakıp kaybolur. Uykusu uyku eşiğine inen oyuncuya bir kahve de getirir (yalnız uykusu gelmişse yalnız kahve); yatakhanede uyuyana kahve götürmez. Stok önlemi: Repsus'un son getirdiklerini karakter kendisi bitirmedikçe (depoya koymak, yere atmak, başkasına vermek sayılmaz) en çok 6 saat yeniden gelmez. Çantasında o ihtiyaca yarayan yiyecek, içecek ya da kahve olan, meşgul olan (düello, görev diyaloğu, süpürge, bağlı...) oyuncuya gelmez. Deneme düğmesi eşik, bekleme ve çanta denetimini atlar. Açlık/susuzluk süreleri duran oyuncu içindir, yürüyen oyuncuda %25 daha hızlı düşer."
                         local satirlar = N.Wrap and N.Wrap(metin, "tiny", pw) or { metin }
                         for i, satir in ipairs(satirlar) do
                              N.Text(satir, "tiny", 0, (i - 1) * u(16), N.Clr.rowDesc)
                         end
                    end
                    sol:AddItem(bilgi)
               end

               -- sağ: oyuncular
               local SAG_X = SOL_W + 12
               local sagW = W - SAG_X
               local bas = vgui.Create("DPanel", P)
               bas:SetPos(u(SAG_X), u(ICERIK_Y))
               bas:SetSize(u(sagW), u(28))
               bas.Paint = function(_, w, h)
                    N.Box(0, 0, w, h, N.Clr.toolBg)
                    N.TextSpaced("OYUNCU", "micro", u(12), u(8), N.Clr.thText, u(2))
                    N.TextSpaced("AÇLIK", "micro", w * 0.42, u(8), N.Clr.thText, u(2))
                    N.TextSpaced("SUSUZLUK", "micro", w * 0.53, u(8), N.Clr.thText, u(2))
                    N.TextSpaced("UYKU", "micro", w * 0.68, u(8), N.Clr.thText, u(2))
                    N.TextSpaced("SON ZİYARET", "micro", w * 0.78, u(8), N.Clr.thText, u(2))
               end

               local liste = N.VList(P, u(SAG_X), u(ICERIK_Y + 32), u(sagW), u(H - ICERIK_Y - 32), {
                    rowH = u(36),
                    paintRow = function(r, i, x, y, cw, ch, hovered)
                         local esik = V() and V().ayar.esik or 25
                         local uykuEsik = V() and V().ayar.uykuEsik or esik
                         N.Box(x, y, cw, ch, hovered and N.Clr.btnLine or N.Clr.toolBg)
                         N.Text(N.Clip((r.yolda and "» " or "") .. r.ad, "tiny", cw * 0.38), "tiny", x + u(12), y + u(10), r.yolda and N.Clr.gold or N.Clr.thText)
                         N.Text(tostring(r.aclik), "tiny", x + cw * 0.42, y + u(10), r.aclik <= esik and N.Clr.warn or N.Clr.rowDesc)
                         N.Text(tostring(r.susuzluk), "tiny", x + cw * 0.53, y + u(10), r.susuzluk <= esik and N.Clr.warn or N.Clr.rowDesc)
                         N.Text(r.uyku and tostring(r.uyku) or "—", "tiny", x + cw * 0.68, y + u(10), r.uyku and r.uyku <= uykuEsik and N.Clr.warn or N.Clr.rowDesc)
                         local yenmedi = (r.bekleyen or 0) > 0 and (" · " .. r.bekleyen .. " yenmedi") or ""
                         N.Text(N.Clip((r.son >= 0 and (r.son .. " dk önce") or "—") .. yenmedi, "tiny", cw * 0.21), "tiny", x + cw * 0.78, y + u(10), yenmedi ~= "" and N.Clr.warn or N.Clr.rowDesc)
                    end
               })

               local function Yenile()
                    local v = V()
                    if not v then return end
                    SolKur()
                    if IsValid(liste) and liste.SetItems then liste:SetItems(v.oyuncular or {}, true) end
                    ctx.SetHead({ count = #(v.oyuncular or {}), note = "OYUNCU" })
               end
               R.Yenile = Yenile
               Yenile()

               -- açıkken 10 saniyede bir tazele
               local zaman = vgui.Create("DPanel", P)
               zaman:SetSize(0, 0)
               zaman.sonraki = RealTime() + 10
               zaman.Think = function(s)
                    if RealTime() >= s.sonraki then
                         s.sonraki = RealTime() + 10
                         Iste("yenile")
                    end
               end

               return function() Iste("yenile") end
          end
     })
     return true
end

if not SayfaKaydet() then
     hook.Add("InitPostEntity", "SardonRepsus.Yonetim", function() timer.Simple(2, SayfaKaydet) end)
     timer.Simple(5, function() if not (ShineAdmin and ShineAdmin.Pages and ShineAdmin.Pages.repsus) then SayfaKaydet() end end)
end

net.Receive(R.NET, function()
     R.Veri = net.ReadTable()
     if R.Veri.mesaj and R.Ctx and IsValid(R.Panel) then R.Ctx.Flash(R.Veri.mesaj) end
     if R.Yenile and IsValid(R.Panel) then R.Yenile() end
end)


--[[
     Mutfak masası menüsü: "Servis Çemberi" (SHINE_Kepce_Servis_Cemberi_v2 tasarımı; sunucu: sv_4masa.lua).
     Solda dairesel servis tepsisi ve çevresinde Yemek / İçecek / Kahve mühürleri (0-3 doluluk), sağda tepsinin
     kavsini izleyen ürün listesi (yuvarlak +), altta altın "Eksikleri tamamla" mührü. + ile alınan ürünün altın
     noktası 440 ms'de tepsinin doluluk yuvasına uçar. Tek panel, her şey Paint'te çizilir; tıklama geometriyle.
     Duran her şey (arka plan, yörünge, tepsi, ayraç) tek dokuda (masa_zemin.jpg); resimler ve simge atlası sunucudan
     bir kez iner (SardonRepsus.MasaDoku, data/sardon_repsus/doku/). Yerleşim sabitleri ~/araclar/repsus_masa/doku/uret.py
     ile aynı. Restart'sız eklenebilsin diye yüklü dosyanın sonunda.
]]
do
     local NET, NET_DOKU = "SardonRepsus.Masa", "SardonRepsus.MasaDoku"
     local KLASOR = "sardon_repsus/doku/"

     -- taban birim: 1080p'de 1 birim = 1 px
     local L = {
          W = 800, H = 600, PAD = 34,
          tx = 232, ty = 290, tr = 116,
          muhur = { yemek = { 111, 132 }, icecek = { 65, 255 }, kahve = { 110, 378 } },
          muhurR = 22,
          lx = 392, lr = 766, ly = 186, satir = 54, kavis = 280,
          kapat = { 749, 58 }, muhurT = { 734, 550 },
     }
     local SIRA = { "yemek", "icecek", "kahve" }
     local BASLIK = { yemek = "Yemekler", icecek = "İçecekler", kahve = "Kahveler" }
     local TUR_AD = { yemek = "Yemek", icecek = "İçecek", kahve = "Kahve" }
     local TUR_SIMGE = { yemek = 2, icecek = 3, kahve = 4 }
     local SANAT_OLCEK = { yemek = 1.04, icecek = 0.9, kahve = 1.04 }
     local AD_DUZELT = { fltrecof = "Filtre Kahve" }
     local DOKULAR = { "masa_zemin", "masa_ikon", "masa_logo", "masa_yemek", "masa_icecek", "masa_kahve" }

     local function R(h, a)
          h = h:gsub("#", "")
          return Color(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), a or (#h == 8 and tonumber(h:sub(7, 8), 16)) or 255)
     end
     local C = {
          ink = R("09140f"), altin = R("c3a76e"), kagit = R("efe4c8"),
          ihtiyacAd = R("b9c1ab"), ihtiyacDeger = R("e5ddc3"), ihtiyacSimge = R("b5a06c"),
          kapatCizgi = R("b49f6938"), kapatSimge = R("b2b79f"),
          muhurYuz = R("122216"), muhurKenar = R("a8945f76"), muhurYazi = R("afb59e"), muhurUst = R("dbbf7a"),
          muhurEtkin = R("bca268"), muhurEtkinKenar = R("e1c894"), muhurEtkinSimge = R("142113"), muhurEtkinHalka = R("c2ac6842"),
          muhurEtkinYazi = R("efe0ba"), sayiAltin = R("d5c393"), sayiSoluk = R("aab59e"),
          yuvaDolu = R("cbb57c"), yuvaBos = R("303f2c"), cantaYazi = R("a6b59d"), cantaGuclu = R("ddcfaa"),
          ust = R("a5b09a"), baslik = R("efe4c8"), kalan = R("c1cca9"),
          urun = R("eee4c9"), etki = R("adb99e"), eksi = R("cda581"), nokta = R("6f8268"),
          satirCizgi = R("a18c57", 40), satirUst = R("4e684e", 46),
          ekleZemin = R("1a2a1b"), ekleKenar = R("b8a16a70"), ekleYazi = R("d3bd84"),
          ekleUstZemin = R("bea36a"), ekleUstYazi = R("10200f"), ekleUstKenar = R("d9bd7f"),
          ekleKapaliKenar = R("84907835"), ekleKapaliYazi = R("849078"),
          not_ = R("95a38d"), iyi = R("c7d4b4"), uyari = R("cda581"),
          altGuclu = R("dfd7ba"), altYazi = R("aab79e"),
          tamamUst = R("bcbfa6"), tamamGuclu = R("e4d3aa"), tamamSayi = R("14200f"), tamamOk = R("ead3a2"),
          tamamHalka = R("c5a86b38"), tamamKapaliYazi = R("b4c6a2"), tamamKapaliZemin = R("30452b"),
          tamamKapaliKenar = R("749064"), tamamKapaliSayi = R("c9d5af"),
          ucan = R("e6ce96"), ucanIsik = R("dbc282", 90),
     }

     /*
     *   Dokular: sunucudan istek üzerine, CRC ile diskte
     */
     local D = { liste = nil, mat = {}, gelen = {}, istenen = {}, yukle = {}, istek = {}, yuklenme = {} }

     local function Yol(kok)
          local b = D.liste and D.liste[kok]
          return b and (KLASOR .. kok .. "_" .. b.crc .. "." .. b.uzanti)
     end

     local function Hazirla(kok)
          local b = D.liste and D.liste[kok]
          if not b then return end
          local yol = Yol(kok)
          if file.Exists(yol, "DATA") and file.Size(yol, "DATA") == b.boyut then
               D.yukle[#D.yukle + 1] = kok
          elseif not D.gelen[kok] then
               D.gelen[kok] = { parca = {}, n = 0, t = RealTime() + 40 }
               D.istek[#D.istek + 1] = kok
          end
     end

     local function ListeIste()
          if (D.listeIstendi or 0) > RealTime() then return end
          D.listeIstendi = RealTime() + 12
          net.Start(NET_DOKU)
               net.WriteUInt(1, 3)
          net.SendToServer()
     end

     net.Receive(NET_DOKU, function()
          local op = net.ReadUInt(3)
          if op == 1 then
               D.liste = {}
               for _ = 1, net.ReadUInt(6) do
                    local kok, crc, boyut, uz = net.ReadString(), net.ReadString(), net.ReadUInt(32), net.ReadString()
                    D.liste[kok] = { crc = crc, boyut = boyut, uzanti = uz }
               end
               for kok in pairs(D.istenen) do Hazirla(kok) end
          elseif op == 2 then
               local kok = net.ReadString()
               local sira, toplam = net.ReadUInt(8), net.ReadUInt(8)
               local veri = net.ReadData(net.ReadUInt(16))
               local g = D.gelen[kok]
               if not g or g.parca[sira] then return end
               g.parca[sira], g.n = veri, g.n + 1
               if g.n < toplam then return end
               file.CreateDir("sardon_repsus")
               file.CreateDir("sardon_repsus/doku")
               local yol = Yol(kok)
               if yol then
                    file.Write(yol, table.concat(g.parca))
                    D.yukle[#D.yukle + 1] = kok
               end
               D.gelen[kok] = nil
          end
     end)

     local function Doku(kok)
          local m = D.mat[kok]
          if m then return m end
          if m == false then return nil end
          if not D.istenen[kok] then
               D.istenen[kok] = true
               if D.liste then Hazirla(kok) else ListeIste() end
          end
     end

     local function OnYukle()
          for _, kok in ipairs(DOKULAR) do Doku(kok) end
     end

     hook.Add("Think", "SardonRepsus.MasaDoku", function()
          if #D.yukle == 0 and #D.istek == 0 and (D.liste or not next(D.istenen)) then return end
          local kok = table.remove(D.yukle, 1)
          if kok then
               local m = Material("../data/" .. Yol(kok), "smooth mips")
               D.mat[kok] = (m and not m:IsError()) and m or false
               D.yuklenme[kok] = RealTime()
          end
          if #D.istek > 0 then
               local n = math.min(#D.istek, 12)
               net.Start(NET_DOKU)
                    net.WriteUInt(2, 3)
                    net.WriteUInt(n, 4)
                    for _ = 1, n do net.WriteString(table.remove(D.istek, 1)) end
               net.SendToServer()
          end
          if not D.liste and next(D.istenen) then ListeIste() end
     end)

     -- yarım kalan inişler 40 sn sonra yeniden istenir; masanın yakınına gelen oyuncu dokuları önceden indirir
     timer.Create("SardonRepsus.MasaDoku", 3, 0, function()
          for kok, g in pairs(D.gelen) do
               if g.t < RealTime() then D.gelen[kok] = nil if D.liste then Hazirla(kok) end end
          end
          if D.onYuklendi then return end
          local lp = LocalPlayer()
          if not IsValid(lp) then return end
          for _, e in ipairs(ents.FindInSphere(lp:GetPos(), 700)) do
               if e:GetNW2Bool("SardonRepsusMasa", false) then
                    D.onYuklendi = true
                    OnYukle()
                    return
               end
          end
     end)

     /*
     *   Çizim yardımcıları
     */
     local K = 1
     local fontlar = {}
     local function F(ad, yuz, px, kalin, enaz)
          local boyut = math.max(enaz or 16, math.Round(px * K))
          local anahtar = "SRMasa." .. ad .. "." .. boyut
          if not fontlar[anahtar] then
               surface.CreateFont(anahtar, { font = yuz, size = boyut, weight = kalin or 500, extended = true, antialias = true })
               fontlar[anahtar] = true
          end
          return anahtar
     end
     local function Serif(px) return F("serif", "Playfair Display", px, 400, 16) end
     -- Montserrat 16-17 px'te Türkçe harf aralığı kayıyor ("Mutfak C ini"); gövde en az 18
     local function Govde(px) return F("govde", "Montserrat Medium", px, 500, 18) end
     local function GovdeK(px) return F("govdeK", "Montserrat SemiBold", px, 600, 18) end
     -- Playfair'in rakamları eski stil (aşağı sarkar): sayılar düz rakamlı yazı tipleriyle
     local function Rakam(px) return F("rakam", "Cinzel", px, 700, 18) end
     local function Baslik(px) return F("cinzel", "Cinzel", px, 500, 16) end

     local function Alfa(c, a) return Color(c.r, c.g, c.b, c.a * a) end
     local GRAD = Material("vgui/gradient-l")

     -- atlas: 4x3 hücre (128 px); 0 disk, 1 halka, 2 çatal-bıçak, 3 kadeh, 4 fincan, 5 damla, 6 ay, 7 x, 8 +, 9 ok, 10 ışık, 11 altın mühür
     local function Ikon(no, cx, cy, boy, renk)
          local m = Doku("masa_ikon")
          if not m then return false end
          local hx, hy = no % 4, math.floor(no / 4)
          local du, dv = 0.5 / 512, 0.5 / 384
          surface.SetMaterial(m)
          surface.SetDrawColor(renk)
          surface.DrawTexturedRectUV(cx - boy / 2, cy - boy / 2, boy, boy, hx / 4 + du, hy / 3 + dv, (hx + 1) / 4 - du, (hy + 1) / 3 - dv)
          return true
     end
     -- disk/halka hücrede 120/128 çaplı: r yarıçaplı daire için hücre boyu
     local function Daire(cx, cy, r, renk)
          if not Ikon(0, cx, cy, r * 2 * 128 / 120, renk) then
               draw.RoundedBox(r, cx - r, cy - r, r * 2, r * 2, renk)
          end
     end
     local function Halka(cx, cy, r, renk) Ikon(1, cx, cy, r * 2 * 128 / 120, renk) end

     local function Yazi(s, font, x, y, renk, ax, ay)
          draw.SimpleText(s, font, x, y, renk, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
     end
     local function Gen(s, font)
          surface.SetFont(font)
          return (surface.GetTextSize(s))
     end

     local function Yumusak(p) return 1 - (1 - math.Clamp(p, 0, 1)) ^ 3 end

     -- Türkçe büyük harf ve tamlayan eki ("Kepçe" → "KEPÇE'NİN")
     local function TrBuyuk(s)
          s = s:gsub("i", "İ"):gsub("ı", "I"):gsub("ç", "Ç"):gsub("ş", "Ş"):gsub("ğ", "Ğ"):gsub("ü", "Ü"):gsub("ö", "Ö")
          return string.upper(s)
     end
     local UNLU = { a = "ın", ["ı"] = "ın", e = "in", i = "in", o = "un", u = "un", ["ö"] = "ün", ["ü"] = "ün",
          A = "ın", I = "ın", E = "in", ["İ"] = "in", O = "un", U = "un", ["Ö"] = "ün", ["Ü"] = "ün" }
     local function Tamlayan(ad)
          local son, sonUnlu = nil, false
          for _, kod in utf8.codes(ad) do
               local h = utf8.char(kod)
               if UNLU[h] then son, sonUnlu = UNLU[h], true else sonUnlu = false end
          end
          if not son then return "'in" end
          return "'" .. (sonUnlu and "n" or "") .. son
     end

     local function UrunAdi(id)
          if AD_DUZELT[id] then return AD_DUZELT[id] end
          local it = ix.item.list[id]
          return it and (it.GetName and it:GetName() or it.name) or id
     end

     local function Etkiler(s)
          local t = {}
          if (s.a or 0) ~= 0 then t[#t + 1] = { "Açlık", s.a } end
          if (s.s or 0) ~= 0 then t[#t + 1] = { "Susuzluk", s.s } end
          if (s.u or 0) ~= 0 then t[#t + 1] = { "Uyku", s.u } end
          return t
     end

     /*
     *   Pencere
     */
     local Pencere

     local function Islem(islem, id)
          net.Start(NET)
          net.WriteString(islem)
          net.WriteString(id or "")
          net.SendToServer()
     end

     local function TurVeri(f, id)
          for _, t in ipairs(f.veri.turler or {}) do
               if t.id == id then return t end
          end
     end

     local function Kalan(f)
          local n = 0
          for _, t in ipairs(f.veri.turler or {}) do n = n + (t.alabilir or 0) end
          return n
     end

     -- liste 5 satır gösterir (VT..VB), fazlası kayar; satırlar kayarken tepsinin kavsini izler
     local GORUNUR = 5
     local VT, VB = L.ly, L.ly + L.satir * GORUNUR
     local function UrunSayisi(f)
          local t = TurVeri(f, f.kat)
          return t and #(t.secenek or {}) or 0
     end
     local function EnCok(f) return math.max(0, (UrunSayisi(f) - GORUNUR) * L.satir) end
     local function SatirY(f, i) return L.ly + (i - 1) * L.satir - (f.kaydir or 0) end
     local function Girinti(y)
          local dy = y + L.satir / 2 - (VT + VB) / 2
          return L.kavis - math.sqrt(math.max(0, L.kavis ^ 2 - dy ^ 2))
     end
     -- kaydırma çubuğu (taban birim): x, iz üstü, iz boyu, tutamak boyu, tutamak y
     local function Cubuk(f)
          local n, enc = UrunSayisi(f), EnCok(f)
          if enc <= 0 then return nil end
          local iz0, izH = VT + 6, (VB - VT) - 12
          local tH = math.max(24, izH * GORUNUR / n)
          return L.lr + 10, iz0, izH, tH, iz0 + (izH - tH) * math.Clamp((f.kaydir or 0) / enc, 0, 1)
     end

     -- (x, y) taban birimde; dönüş: { tur, ... } ya da nil
     local function Isabet(f, x, y)
          if math.Distance(x, y, L.kapat[1], L.kapat[2]) <= 19 then return { tur = "kapat" } end
          for _, kat in ipairs(SIRA) do
               local m = L.muhur[kat]
               if math.Distance(x, y, m[1], m[2]) <= L.muhurR + 4 or (math.abs(x - m[1]) <= 46 and y >= m[2] and y <= m[2] + 66) then
                    return { tur = "muhur", kat = kat }
               end
          end
          local cx = Cubuk(f)
          if cx and x >= cx - 8 and x <= cx + 8 and y >= VT and y < VB then return { tur = "cubuk" } end
          local t = TurVeri(f, f.kat)
          if t and y >= VT and y < VB then
               for i, s in ipairs(t.secenek or {}) do
                    local sy = SatirY(f, i)
                    if x >= L.lx + Girinti(sy) and x <= L.lr and y >= sy and y < sy + L.satir then
                         return { tur = "ekle", id = s.id, i = i }
                    end
               end
          end
          local tx, ty = L.muhurT[1], L.muhurT[2]
          if x >= tx - 32 - 20 - f.tamamGen - 8 and x <= tx + 38 and math.abs(y - ty) <= 38 then return { tur = "tamamla" } end
          if y <= 100 then return { tur = "tasi" } end
     end

     local function Kapat(f)
          if f.kapaniyor then return end
          f.kapaniyor = RealTime()
          f:SetMouseInputEnabled(false)
          f:SetKeyboardInputEnabled(false)
     end

     local function KategoriSec(f, kat)
          if f.kat == kat then return end
          f.kat = kat
          f.sanatT, f.listeT = RealTime(), RealTime()
          f.kaydir, f.kaydirHedef = 0, 0
          f.mesaj = nil
          surface.PlaySound("garrysmod/ui_hover.wav")
     end

     local function Ekle(f, id, i)
          local t = TurVeri(f, f.kat)
          if not t or (t.alabilir or 0) <= 0 or RealTime() < f.bekle then return end
          f.bekle = RealTime() + 0.3
          t.alabilir, t.sayilan, t.sahip = t.alabilir - 1, (t.sayilan or 0) + 1, (t.sahip or 0) + 1
          local tavan = f.veri.tavan or 3
          local yuva = math.Clamp(t.sayilan, 1, tavan)
          f.ucanlar[#f.ucanlar + 1] = { L.lr - 20, math.Clamp(SatirY(f, i) + L.satir / 2, VT, VB), L.tx + (yuva - (tavan + 1) / 2) * 24, L.ty + L.tr + 6, RealTime() }
          f.mesaj = { metin = UrunAdi(id) .. " çantana eklendi.", tur = "iyi", t = RealTime() }
          surface.PlaySound("garrysmod/ui_click.wav")
          Islem("al", id)
     end

     local function Tamamla(f)
          local n = Kalan(f)
          if n <= 0 or RealTime() < f.bekle then return end
          f.bekle = RealTime() + 0.8
          for _, t in ipairs(f.veri.turler or {}) do
               t.sahip, t.sayilan, t.alabilir = (t.sahip or 0) + (t.alabilir or 0), (t.sayilan or 0) + (t.alabilir or 0), 0
          end
          f.nabizT = RealTime()
          f.mesaj = { metin = n .. " adet hazırlanıyor…", tur = "iyi", t = RealTime() }
          surface.PlaySound("garrysmod/ui_click.wav")
          Islem("tamamla")
     end

     local function Ciz(f, w, h)
          local simdi = RealTime()
          local v = f.veri
          local mx, my = f:CursorPos()
          mx, my = mx / K, my / K
          local ust = (f:IsHovered() and not f.suruk) and Isabet(f, mx, my) or nil
          f.ust = ust
          local function S(x) return x * K end

          -- zemin
          local zemin = Doku("masa_zemin")
          if zemin then
               surface.SetMaterial(zemin)
               surface.SetDrawColor(255, 255, 255, 255)
               surface.DrawTexturedRect(0, 0, w, h)
          else
               surface.SetDrawColor(C.ink)
               surface.DrawRect(0, 0, w, h)
               Daire(S(L.tx), S(L.ty), S(L.tr), Color(18, 38, 25))
               surface.SetDrawColor(175, 151, 89, 70)
               surface.DrawRect(S(L.PAD), S(504), w - S(L.PAD * 2), 1)
          end
          surface.SetDrawColor(195, 167, 110, 50)
          surface.DrawOutlinedRect(0, 0, w, h, 1)

          -- başlık
          local logo = Doku("masa_logo")
          if logo then
               surface.SetMaterial(logo)
               surface.SetDrawColor(255, 255, 255, 255)
               surface.DrawTexturedRect(S(30), S(28), S(40), S(40))
          end
          local ad = v.ad or "Kepçe"
          Yazi(TrBuyuk(ad .. Tamlayan(ad)), Baslik(17), S(76), S(24), C.altin)
          Yazi("Mutfak Masası", Serif(32), S(75), S(40), C.kagit)

          -- ihtiyaçlar (sağdan sola)
          local x = S(714)
          local cy = S(60)
          for _, n in ipairs({ { "Uyku", v.uyku, 6 }, { "Susuzluk", v.susuzluk, 5 }, { "Açlık", v.aclik, 2 } }) do
               local deger = tostring(n[2] or "—")
               local dfont, afont = GovdeK(19), Govde(18)
               local dw = Gen(deger, dfont)
               Yazi(deger, dfont, x, cy, (n[2] or 100) <= 25 and C.eksi or C.ihtiyacDeger, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               x = x - dw - S(5)
               local aw = Gen(n[1], afont)
               Yazi(n[1], afont, x, cy, C.ihtiyacAd, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               x = x - aw - S(6)
               Ikon(n[3], x - S(8), cy, S(18), C.ihtiyacSimge)
               x = x - S(16) - S(20)
          end

          -- kapat
          local kx, ky = S(L.kapat[1]), S(L.kapat[2])
          local kUst = ust and ust.tur == "kapat"
          Halka(kx, ky, S(19), kUst and C.altin or C.kapatCizgi)
          Ikon(7, kx, ky, S(20), kUst and C.kagit or C.kapatSimge)

          -- tepsi resmi (kategori değişince -14°'den dönerek ve büyüyerek gelir)
          local kat = f.kat
          local sanat = Doku("masa_" .. kat)
          if sanat then
               local p = Yumusak((simdi - math.max(f.sanatT, D.yuklenme["masa_" .. kat] or 0)) / 0.33)
               local boy = S(L.tr * 2 * SANAT_OLCEK[kat]) * (0.88 + 0.12 * p)
               surface.SetMaterial(sanat)
               surface.SetDrawColor(255, 255, 255, 255 * p)
               surface.DrawTexturedRectRotated(S(L.tx), S(L.ty), boy, boy, 14 * (1 - p))
          end

          -- mühürler
          for _, k in ipairs(SIRA) do
               local t = TurVeri(f, k) or {}
               local m = L.muhur[k]
               local etkin = k == kat
               local hov = ust and ust.tur == "muhur" and ust.kat == k
               f.kalk[k] = Lerp(FrameTime() * 14, f.kalk[k] or 0, hov and 3 or 0)
               local cx, cy2 = S(m[1]), S(m[2] - f.kalk[k])
               local r = S(L.muhurR)
               if etkin then Halka(cx, cy2, r + S(6), C.muhurEtkinHalka) end
               Daire(cx, cy2, r, etkin and C.muhurEtkin or C.muhurYuz)
               Halka(cx, cy2, r, etkin and C.muhurEtkinKenar or (hov and C.muhurUst or C.muhurKenar))
               Ikon(TUR_SIMGE[k], cx, cy2, S(22), etkin and C.muhurEtkinSimge or C.muhurYazi)
               Yazi(TUR_AD[k], Serif(19), cx, S(m[2] + L.muhurR + 3), etkin and C.muhurEtkinYazi or C.muhurYazi, TEXT_ALIGN_CENTER)
               local sayi, ek = tostring(t.sayilan or 0), " / " .. (v.tavan or 3)
               local sf, ef = GovdeK(18), Govde(18)
               local sw, ew = Gen(sayi, sf), Gen(ek, ef)
               local bx = cx - (sw + ew) / 2
               local by = S(m[2] + L.muhurR + 29)
               Yazi(sayi, sf, bx, by, C.sayiAltin)
               Yazi(ek, ef, bx + sw, by + S(1), C.sayiSoluk)
          end

          -- doluluk yuvaları + "Çantanda n / 3"
          local t = TurVeri(f, kat) or {}
          local tavan = v.tavan or 3
          local nabiz = f.nabizT and math.max(0, 1 - math.abs((simdi - f.nabizT) / 0.33 - 0.4) / 0.6) or 0
          for j = 1, tavan do
               local yx, yy = S(L.tx + (j - (tavan + 1) / 2) * 24), S(L.ty + L.tr + 6)
               local dolu = j <= (t.sayilan or 0)
               local r = S(5) * (1 + 0.2 * nabiz)
               if dolu then Ikon(10, yx, yy, S(26), Alfa(C.ucanIsik, 0.45)) end
               Daire(yx, yy, r, dolu and C.yuvaDolu or C.yuvaBos)
          end
          local c1, c2 = "Çantanda  ", (t.sayilan or 0) .. " / " .. tavan
          local f1, f2 = Govde(18), GovdeK(18)
          local w1, w2 = Gen(c1, f1), Gen(c2, f2)
          Yazi(c1, f1, S(L.tx) - (w1 + w2) / 2, S(L.ty + L.tr + 18), C.cantaYazi)
          Yazi(c2, f2, S(L.tx) - (w1 + w2) / 2 + w1, S(L.ty + L.tr + 18), C.cantaGuclu)

          -- liste başlığı
          local pl = Yumusak((simdi - f.listeT) / 0.23)
          local kay = S(10) * (1 - pl)
          local la = 0.3 + 0.7 * pl
          Yazi(v.unvan or "Mutfak Cini", Govde(18), S(L.lx), S(110), C.ust)
          Yazi(BASLIK[kat], Serif(36), S(L.lx - 2) + kay, S(128), Alfa(C.baslik, la))
          local kalan = t.alabilir or 0
          local kalanY = (t.disari or 0) > 0 and S(140) or S(152)
          Yazi(kalan > 0 and (kalan .. " adet alabilirsin") or "Bu türde hakkın doldu", Govde(18), S(L.lr), kalanY, C.kalan, TEXT_ALIGN_RIGHT)
          if (t.disari or 0) > 0 then
               Yazi(t.disari .. " tanesi çantanda değil", Govde(18), S(L.lr), S(162), C.uyari, TEXT_ALIGN_RIGHT)
          end

          -- ürünler: tepsinin kavsini izleyen satırlar; 5'ten fazlası kırpılıp kayar
          local ox, oy = f:LocalToScreen(0, 0)
          render.SetScissorRect(ox + S(L.lx - 40), oy + S(VT), ox + S(L.lr + 1), oy + S(VB), true)
          for i, s in ipairs(t.secenek or {}) do
               local yb = SatirY(f, i)
               if yb + L.satir > VT and yb < VB then
               local orta = yb + L.satir / 2
               -- görünür alanın kenarını geçen satır solar
               local ka = math.Clamp(math.min(orta - VT, VB - orta) / (L.satir * 0.5), 0, 1)
               local la = la * ka
               local sy = S(yb)
               local sx = S(L.lx + Girinti(yb)) + kay
               local sh = S(L.satir)
               local hov = ust and ust.tur == "ekle" and ust.i == i
               local acik = kalan > 0
               if hov and acik then
                    surface.SetMaterial(GRAD)
                    surface.SetDrawColor(Alfa(C.satirUst, ka))
                    surface.DrawTexturedRect(sx, sy, S(L.lr) - sx, sh)
               end
               Yazi(UrunAdi(s.id), Serif(21), sx + S(15), sy + S(3), Alfa(C.urun, la))
               local ex = sx + S(15)
               local ef = Govde(18)
               for j, e in ipairs(Etkiler(s)) do
                    if j > 1 then
                         Yazi("·", ef, ex + S(5), sy + S(29), Alfa(C.nokta, ka))
                         ex = ex + S(5) + Gen("·", ef) + S(6)
                    end
                    local metin = e[1] .. " " .. (e[2] < 0 and "−" or "+") .. math.abs(e[2])
                    Yazi(metin, ef, ex, sy + S(29), Alfa(e[2] < 0 and C.eksi or C.etki, la))
                    ex = ex + Gen(metin, ef)
               end
               surface.SetMaterial(GRAD)
               surface.SetDrawColor(Alfa(C.satirCizgi, ka))
               surface.DrawTexturedRect(sx + S(15), sy + sh - 1, S(L.lr - 58) - sx - S(15), 1)
               -- yuvarlak +
               local bx, by = S(L.lr - 20), sy + sh / 2
               local br = S(19)
               if acik then
                    Daire(bx, by, br, Alfa(hov and C.ekleUstZemin or C.ekleZemin, ka))
                    Halka(bx, by, br, Alfa(hov and C.ekleUstKenar or C.ekleKenar, ka))
                    Ikon(8, bx, by, S(20), Alfa(hov and C.ekleUstYazi or C.ekleYazi, ka))
               else
                    Halka(bx, by, br, Alfa(C.ekleKapaliKenar, ka))
                    surface.SetDrawColor(Alfa(C.ekleKapaliYazi, ka))
                    surface.DrawRect(bx - S(5), by - math.max(1, S(1)) / 2, S(10), math.max(1, S(1.4)))
               end
               end
          end
          render.SetScissorRect(0, 0, 0, 0, false)

          -- kaydırma çubuğu: ince altın iz + tutamak (tekerlek, sürükleme, ize tıklama)
          local cx, iz0, izH, tH, tY = Cubuk(f)
          if cx then
               local cHov = (ust and ust.tur == "cubuk") or f.cubukSuruk
               surface.SetDrawColor(195, 167, 110, 26)
               surface.DrawRect(S(cx) - math.max(1, S(1)) / 2, S(iz0), math.max(1, S(1)), S(izH))
               local tw = S(cHov and 4 or 3)
               draw.RoundedBox(math.floor(tw / 2), S(cx) - tw / 2, S(tY), tw, S(tH), Alfa(C.altin, cHov and 0.9 or 0.55))
          end
          -- durum satırı: işlem mesajı birkaç saniye notun yerini alır
          local ms = f.mesaj
          local nx, ny = S(L.lx + 15), S(L.ly + L.satir * 5 + 10)
          local ma = ms and math.Clamp(4.5 - (simdi - ms.t), 0, 1) or 0
          if ms and ma <= 0 then f.mesaj, ms = nil, nil end
          if ms then
               Yazi(ms.metin, Govde(18), nx, ny, Alfa(ms.tur == "uyari" and C.uyari or C.iyi, ma))
          else
               Yazi("Değerler, tüketildiğinde uygulanır.", Govde(18), nx, ny, C.not_)
          end

          -- alt bilgi
          Yazi("Her türden en çok " .. tavan .. ".", Serif(19), S(L.PAD), S(518), C.altGuclu)
          Yazi("Çantandakiler ve henüz tüketmediklerin birlikte sayılır.", Govde(18), S(L.PAD), S(546), C.altYazi)

          -- altın tamamlama mührü
          local eksik = Kalan(f)
          local tx, ty = S(L.muhurT[1]), S(L.muhurT[2])
          local tHov = ust and ust.tur == "tamamla" and eksik > 0
          f.muhurOlcek = Lerp(FrameTime() * 14, f.muhurOlcek or 1, tHov and 1.06 or 1)
          local tr = S(32) * f.muhurOlcek
          local ust1, ust2 = eksik > 0 and "Eksikleri" or "Çantan", eksik > 0 and "Tamamla" or "tamam"
          local gf = Serif(28)
          f.tamamGen = Gen(ust2, gf) / K
          local x0 = tx - S(32) - S(20) - Gen(ust2, gf)
          Yazi(ust1, Govde(18), x0, ty - S(33), eksik > 0 and C.tamamUst or C.tamamKapaliYazi)
          Yazi(ust2, gf, x0, ty - S(12), eksik > 0 and C.tamamGuclu or C.tamamKapaliYazi)
          if eksik > 0 then
               Halka(tx, ty, S(38), C.tamamHalka)
               if not Ikon(11, tx, ty, tr * 2 * 128 / 120, color_white) then Daire(tx, ty, tr, C.altin) end
               Yazi(tostring(eksik), Rakam(28), tx, ty - S(6), C.tamamSayi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               Yazi("adet", Govde(18), tx, ty + S(15), C.tamamSayi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               Ikon(9, tx + S(34), ty - S(32), S(18), C.tamamOk)
          else
               Daire(tx, ty, tr, C.tamamKapaliZemin)
               Halka(tx, ty, tr, C.tamamKapaliKenar)
               -- ✓
               surface.SetDrawColor(C.tamamKapaliSayi)
               local k1 = { tx - S(11), ty + S(1) }
               local k2 = { tx - S(3), ty + S(9) }
               local k3 = { tx + S(12), ty - S(9) }
               for o = -1, 1 do
                    surface.DrawLine(k1[1], k1[2] + o, k2[1], k2[2] + o)
                    surface.DrawLine(k2[1], k2[2] + o, k3[1], k3[2] + o)
               end
          end

          -- uçan altın noktalar (440 ms)
          for n = #f.ucanlar, 1, -1 do
               local u = f.ucanlar[n]
               local p = (simdi - u[5]) / 0.44
               if p >= 1 then table.remove(f.ucanlar, n)
               else
                    local e = 1 - (1 - p) ^ 2.2
                    local dx, dy = u[3] - u[1], u[4] - u[2]
                    local ax, ay = dx * 0.45, math.min(dy * 0.45, -50)
                    local px, py, olc, a
                    if e < 0.45 then
                         local q = e / 0.45
                         px, py, olc, a = ax * q, ay * q, 1 - 0.15 * q, 1
                    else
                         local q = (e - 0.45) / 0.55
                         px, py, olc, a = ax + (dx - ax) * q, ay + (dy - ay) * q, 0.85 - 0.45 * q, 1 - q
                    end
                    local ux, uy = S(u[1] + px), S(u[2] + py)
                    Ikon(10, ux, uy, S(28) * olc, Alfa(C.ucanIsik, a))
                    Daire(ux, uy, S(5) * olc, Alfa(C.ucan, a))
               end
          end

          if f.imlec ~= (ust and ust.tur ~= "tasi" and "hand" or "arrow") then
               f.imlec = ust and ust.tur ~= "tasi" and "hand" or "arrow"
               f:SetCursor(f.imlec)
          end
     end

     local function Kur(v)
          K = math.Clamp(ScrH() / 1080, 0.85, 1.4)
          local f = vgui.Create("EditablePanel")
          f:SetSize(math.Round(L.W * K), math.Round(L.H * K))
          f:Center()
          f:MakePopup()
          f:SetAlpha(0)
          f.veri = v
          f.kat = "yemek"
          for _, t in ipairs(v.turler or {}) do
               if (t.alabilir or 0) > 0 then f.kat = t.id break end
          end
          f.sanatT, f.listeT, f.acilis = RealTime(), RealTime(), RealTime()
          f.bekle, f.ucanlar, f.kalk, f.tamamGen = 0, {}, {}, 120
          f.kaydir, f.kaydirHedef = 0, 0
          f.konum = LocalPlayer():GetPos()
          OnYukle()

          f.Paint = function(s, w, h) Ciz(s, w, h) end

          f.OnMousePressed = function(s, kod)
               if kod ~= MOUSE_LEFT then return end
               local mx, my = s:CursorPos()
               local hit = Isabet(s, mx / K, my / K)
               if not hit then return end
               if hit.tur == "kapat" then Kapat(s)
               elseif hit.tur == "muhur" then KategoriSec(s, hit.kat)
               elseif hit.tur == "ekle" then Ekle(s, hit.id, hit.i)
               elseif hit.tur == "tamamla" then Tamamla(s)
               elseif hit.tur == "cubuk" then
                    local _, _, izH, tH, tY = Cubuk(s)
                    local y = my / K
                    -- tutamağın dışına tıklandıysa tutamak oraya gelir, sonra sürüklenir
                    if y < tY or y > tY + tH then
                         s.kaydirHedef = math.Clamp((y - tH / 2 - VT - 6) / math.max(1, izH - tH) * EnCok(s), 0, EnCok(s))
                    end
                    s.cubukSuruk = { y, s.kaydirHedef, izH - tH }
                    s:MouseCapture(true)
               elseif hit.tur == "tasi" then
                    s.suruk = { gui.MouseX() - s.x, gui.MouseY() - s.y }
                    s:MouseCapture(true)
               end
          end
          f.OnMouseReleased = function(s)
               if s.suruk or s.cubukSuruk then s.suruk, s.cubukSuruk = nil, nil s:MouseCapture(false) end
          end
          f.OnMouseWheeled = function(s, delta)
               s.kaydirHedef = math.Clamp((s.kaydirHedef or 0) - delta * L.satir, 0, EnCok(s))
               return true
          end
          f.OnKeyCodePressed = function(s, tus)
               if tus == KEY_1 or tus == KEY_2 or tus == KEY_3 then KategoriSec(s, SIRA[tus - KEY_1 + 1]) end
          end

          f.Think = function(s)
               local simdi = RealTime()
               if s.kapaniyor then
                    local a = 1 - (simdi - s.kapaniyor) / 0.12
                    if a <= 0 then s:Remove() return end
                    s:SetAlpha(255 * a)
                    return
               end
               s:SetAlpha(255 * Yumusak((simdi - s.acilis) / 0.18))
               if s.suruk then
                    s:SetPos(math.Clamp(gui.MouseX() - s.suruk[1], 0, ScrW() - s:GetWide()), math.Clamp(gui.MouseY() - s.suruk[2], 0, ScrH() - s:GetTall()))
               end
               local enc = EnCok(s)
               if s.cubukSuruk then
                    local _, my = s:CursorPos()
                    local c = s.cubukSuruk
                    s.kaydirHedef = math.Clamp(c[2] + (my / K - c[1]) * enc / math.max(1, c[3]), 0, enc)
               end
               s.kaydirHedef = math.Clamp(s.kaydirHedef, 0, enc)
               s.kaydir = Lerp(math.min(1, FrameTime() * 16), s.kaydir, s.kaydirHedef)
               if math.abs(s.kaydir - s.kaydirHedef) < 0.05 then s.kaydir = s.kaydirHedef end
               if input.IsKeyDown(KEY_ESCAPE) then
                    gui.HideGameUI()
                    Kapat(s)
                    return
               end
               local lp = LocalPlayer()
               if not IsValid(lp) or not lp:Alive() or lp:GetPos():DistToSqr(s.konum) > 260 * 260 then Kapat(s) end
          end
          return f
     end

     net.Receive(NET, function()
          local v = util.JSONToTable(net.ReadString() or "")
          if not istable(v) then return end
          if IsValid(Pencere) and not Pencere.kapaniyor then
               Pencere.veri = v
               if v.mesaj then Pencere.mesaj = { metin = v.mesaj.metin, tur = v.mesaj.tur, t = RealTime() } end
               if v.ac then Pencere.konum = LocalPlayer():GetPos() Pencere:MoveToFront() end
               return
          end
          if v.ac then Pencere = Kur(v) end
     end)
end
