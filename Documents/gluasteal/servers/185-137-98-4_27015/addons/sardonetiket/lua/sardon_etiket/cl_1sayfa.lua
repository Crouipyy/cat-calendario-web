-- "addons\\sardonetiket\\lua\\sardon_etiket\\cl_1sayfa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sardon Etiket — TAB › Shine Store › "Discord Etiketi" sayfası (istemci).
*
*   [sardon] gacha'nın mağaza sekmesine SardonShineStoreSayfalar kancasıyla eklenir; tema gacha'nın
*   (SardonGacha: SG.F/Yazi/Kutu/Cerceve/Koseler/Hap/Parilti/UrlMat). Düzen (kullanıcının referansının
*   Celestial uyarlaması): solda büyük SHNE rozeti; sağda Discord profil kartı önizlemesi, durum başlığı,
*   iki kazanım kartı, iki adım ya da bu saatin ilerlemesi, büyük düğme, altta bağlı hesap.
*   Tasarım tuvali 1360×860, S ile ölçeklenir.
*/
SardonEtiket = SardonEtiket or {}
local E = SardonEtiket
local OP = E.OP

/*
*   Ağ
*/
function E.Iste(op, t)
     net.Start("SardonEtiket")
     net.WriteUInt(op, 4)
     net.WriteString(util.TableToJSON(t or {}) or "{}")
     net.SendToServer()
end

function E.DurumAl(t)
     t.alindi = RealTime()
     t.bekleBitis = RealTime() + (tonumber(t.bekle) or 0)
     E.Durum = t
end

net.Receive("SardonEtiket", function()
     local op = net.ReadUInt(4)
     local t = util.JSONToTable(net.ReadString() or "") or {}
     if op == OP.DURUM then
          E.DurumAl(t)
     elseif op == OP.Y_VERI then
          E.YVeri = t
          if E.YYenile then E.YYenile() end
     end
end)

/*
*   Metinler
*/
-- büyük harfle yazılı (SG.Buyuk "Discord"u "DİSCORD" yapardı)
local function Baslik(d)
     local durum = d and d.durum or "bekliyor"
     if durum == "etiket" then return "ETİKET TAKILI" end
     if durum == "etiket_yok" then return "AZ KALDI" end
     if durum == "bagli_degil" then return "DISCORD'U BAĞLA" end
     if durum == "sunucuda_degil" then return "ÖNCE SUNUCUYA KATIL" end
     if durum == "cakisma" then return "HESAP ÇAKIŞMASI" end
     if durum == "kapali" then return "ŞU AN KAPALI" end
     if durum == "hata" then return "DISCORD'A ULAŞILAMADI" end
     return "YOKLANIYOR…"
end

local function Aciklama(d)
     local durum = d and d.durum or "bekliyor"
     local sc = d and d.scSaat or 1
     if durum == "etiket" then
          if d.neden == "afk" then return "Sayaç duruyor: AFK görünüyorsun. Hareket edince kaldığı yerden devam eder." end
          if d.neden == "karakter" or d.neden == "giris" then return "Sayaç duruyor: önce bir karakterle oyuna gir." end
          return "Teşekkürler. Herkese verilen ShineCoin'e ek olarak, aktif geçen " .. E.AralikMetni(d.dkSaat) .. " " .. sc .. " ShineCoin daha kazanırsın."
     end
     if durum == "etiket_yok" then
          if d.diger then return "Discord'da şu an " .. d.diger .. " etiketi takılı. Sunucu Etiketi olarak SHNE'yi seçince sayaç başlar." end
          return "Sunucumuzdasın. Profilinde Sunucu Etiketi olarak SHNE'yi seç, sonra yeniden kontrol et."
     end
     if durum == "bagli_degil" then return "Etiketini görebilmemiz için önce Discord hesabını oyun hesabına bağlamalısın. Kod Discord'dan özel mesajla gelir." end
     if durum == "sunucuda_degil" then return "Bağlı Discord hesabın Shine Roleplay sunucusunda görünmüyor. Etiketi takabilmek için önce sunucuya katıl." end
     if durum == "cakisma" then return "Bu Discord hesabı birden çok oyun hesabına bağlı görünüyor. Düzeltmesi için bir yetkiliye yaz." end
     if durum == "kapali" then return "Etiket ödülü yönetim tarafından şimdilik durduruldu." end
     if durum == "hata" then return "Discord şu an cevap vermiyor. Biraz sonra yeniden dene; sayacın kaybolmaz." end
     return "Discord'daki etiketin kontrol ediliyor."
end

local function Adimlar(d)
     local durum = d and d.durum or "bekliyor"
     local iki = "Discord'da profil ayarlarından Sunucu Etiketi olarak SHNE'yi seç"
     if durum == "bagli_degil" then
          return { { "Discord hesabını oyun hesabına bağla", false }, { iki, false } }
     elseif durum == "sunucuda_degil" then
          return { { "Discord'da Shine Roleplay sunucusuna katıl", false }, { iki, false } }
     elseif durum == "etiket_yok" then
          return { { "Discord hesabın bağlı ve sunucudasın", true }, { iki, false } }
     end
end

-- yazıyı genişliğe sığdır (UTF-8 güvenli, sonuna …)
local function Kisalt(metin, font, azami)
     metin = tostring(metin or "")
     surface.SetFont(font)
     if surface.GetTextSize(metin) <= azami then return metin end
     local son = ""
     for ch in metin:gmatch(utf8.charpattern) do
          if surface.GetTextSize(son .. ch .. "…") > azami then break end
          son = son .. ch
     end
     return son .. "…"
end

/*
*   Sayfa
*/
local PANEL = {}

function PANEL:Init()
     self.dugme = self:Add("DButton")
     self.dugme:SetText("")
     self.dugme.Paint = function(b, w, h) self:DugmeCiz(b, w, h) end
     self.dugme.DoClick = function() self:DugmeTik() end
     self.dugme.OnCursorEntered = function() local SG = SardonGacha if SG then SG.Cal("uzerinde") end end

     self.katil = self:Add("DButton")
     self.katil:SetText("")
     self.katil.Paint = function(b, w, h) self:KatilCiz(b, w, h) end
     self.katil.DoClick = function()
          local SG = SardonGacha
          if SG then SG.Cal("tik") end
          gui.OpenURL(E.Davet)
     end

     self.istendi = 0
end

function PANEL:Think()
     -- görünür olunca ve dakikada bir taze durum iste
     if self:IsVisible() and RealTime() - self.istendi > 60 then
          self.istendi = RealTime()
          E.Iste(OP.ISTE)
     end
     local d = E.Durum
     local durum = d and d.durum
     self.katil:SetVisible(durum == "sunucuda_degil" or durum == "bagli_degil")
end

function PANEL:Olcu()
     local w, h = self:GetSize()
     local S = math.min(w / 1360, h / 860)
     return S, (w - 1360 * S) / 2, (h - 860 * S) / 2
end

function PANEL:PerformLayout(w, h)
     local S, ox, oy = self:Olcu()
     self.S, self.ox, self.oy = S, ox, oy
     self.dugme:SetPos(ox + 560 * S, oy + 712 * S)
     self.dugme:SetSize(360 * S, 64 * S)
     self.katil:SetPos(ox + 944 * S, oy + 728 * S)
     self.katil:SetSize(330 * S, 32 * S)
end

function PANEL:Kalan()
     local d = E.Durum
     if not d then return 0 end
     return math.max(0, math.ceil((d.bekleBitis or 0) - RealTime()))
end

function PANEL:DugmeTik()
     local d = E.Durum
     local durum = d and d.durum
     local SG = SardonGacha
     if durum == "kapali" then return end
     if durum == "bagli_degil" then
          if SG then SG.Cal("tik") end
          E.Iste(OP.BAGLA)
          if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
          return
     end
     if self:Kalan() > 0 or (d and d.istekte) then return end
     if SG then SG.Cal("tik") end
     E.Iste(OP.KONTROL)
     if d then
          d.istekte = true
          d.bekleBitis = RealTime() + 30
     end
end

function PANEL:DugmeCiz(b, w, h)
     local SG = SardonGacha
     if not SG then return end
     local R = SG.R
     local d = E.Durum
     local durum = d and d.durum
     local kalan = self:Kalan()
     local metin, etkin
     if durum == "bagli_degil" then
          metin, etkin = "Discord'u bağla", true
     elseif durum == "kapali" then
          metin, etkin = "Kapalı", false
     elseif d and d.istekte then
          metin, etkin = "Kontrol ediliyor…", false
     elseif kalan > 0 then
          metin, etkin = "Yeniden kontrol et (" .. kalan .. ")", false
     else
          metin, etkin = "Yeniden kontrol et", true
     end
     local ust = etkin and b:IsHovered()
     if etkin then SG.Parilti(w / 2, h / 2, w * 1.3, h * 2.2, R.altin, ust and 70 or 40) end
     SG.Hap(0, 0, w, h, etkin and (ust and Color(250, 242, 220) or R.krem) or Color(60, 62, 56), etkin and R.altin or nil)
     SG.Yazi(metin, SG.F(h * 0.36, "orta"), w / 2, h / 2, etkin and R.kremKoyu or R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:KatilCiz(b, w, h)
     local SG = SardonGacha
     if not SG then return end
     local R = SG.R
     local font = SG.F(17 * (self.S or 1))
     local metin = "Sunucuda değil misin? Önce katıl"
     local c = b:IsHovered() and R.altinAcik or R.altin
     SG.Yazi(metin, font, 0, h / 2, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     local tw = SG.Genislik(metin, font)
     SG.Kutu(0, h / 2 + 11 * (self.S or 1), tw, 1, c, 0.7)
end

-- solda büyük rozet: parıltı, dönen kıvılcımlar, SHNE yazısı
function PANEL:KahramanCiz(S, ox, oy)
     local SG = SardonGacha
     local R = SG.R
     local t = RealTime()
     local cx, cy = ox + 260 * S, oy + 330 * S
     local d = E.Durum
     local takili = d and d.durum == "etiket"
     local nabiz = 0.5 + 0.5 * math.sin(t * 1.6)

     SG.Parilti(cx, cy, 520 * S, 520 * S, R.altin, (takili and 70 or 45) + 20 * nabiz)
     SG.Parilti(cx, cy, 260 * S, 260 * S, R.altinAcik, takili and 60 or 30)
     for i = 1, 4 do
          local a = t * 0.35 + i * math.pi / 2
          local rx, ry = 170 * S, 120 * S
          SG.Kivilcim(cx + math.cos(a) * rx, cy + math.sin(a) * ry, (22 + 10 * math.sin(t * 2 + i)) * S, R.altinAcik, 160)
     end
     local boy = 192 * S
     local bob = math.sin(t * 1.2) * 6 * S
     E.RozetCiz(cx - boy / 2, cy - boy / 2 + bob, boy, takili and 1 or 0.85, true)

     SG.Yazi("S H I N E   R O L E P L A Y", SG.F(16 * S, "orta"), cx, oy + 486 * S, R.altin, TEXT_ALIGN_CENTER)
     SG.Yazi("SHNE", SG.F(84 * S, "baslik"), cx, oy + 508 * S, R.fildisiAcik, TEXT_ALIGN_CENTER)
     SG.Kesik(cx - 120 * S, oy + 612 * S, 240 * S, R.cizgi)
     SG.Baklava(cx, oy + 612 * S, 4 * S, R.altin, 1, true)
     SG.Yazi("Discord sunucu etiketi", SG.F(18 * S), cx, oy + 630 * S, R.soluk, TEXT_ALIGN_CENTER)
end

-- Discord profil kartı önizlemesi
function PANEL:KartCiz(S, ox, oy)
     local SG = SardonGacha
     local R = SG.R
     local d = E.Durum or {}
     local takili = d.durum == "etiket"
     local x, y, w, h = ox + 560 * S, oy + 80 * S, 720 * S, 150 * S

     SG.Kutu(x, y, w, h, Color(10, 16, 14, 228))
     SG.Gradyan(x, y, w * 0.6, h, Color(190, 162, 104, takili and 34 or 18), "sol")
     SG.Cerceve(x, y, w, h, R.cizgi)
     SG.Koseler(x - 4 * S, y - 4 * S, w + 8 * S, h + 8 * S, 16 * S, R.altin)

     -- avatar
     local ar = 50 * S
     local acx, acy = x + 30 * S + ar, y + h / 2
     E.Daire(acx, acy, ar + 3 * S, R.altinKoyu)
     local mat
     if d.id and d.avatar then
          mat = SG.UrlMat("https://cdn.discordapp.com/avatars/" .. d.id .. "/" .. d.avatar .. ".png?size=128")
     end
     if mat then
          E.DaireResim(mat, acx, acy, ar)
     else
          E.Daire(acx, acy, ar, R.zemin2)
          local harf = tostring(d.ad or LocalPlayer():SteamName() or "?"):match(utf8.charpattern) or "?"
          SG.Yazi(SG.Buyuk(harf), SG.F(44 * S, "baslik"), acx, acy, R.altin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
     -- çevrimiçi noktası
     E.Daire(acx + ar * 0.72, acy + ar * 0.72, 13 * S, Color(10, 16, 14))
     E.Daire(acx + ar * 0.72, acy + ar * 0.72, 9 * S, takili and R.iyi or R.sonuk)

     -- ad + etiket hapı
     local ad = d.ad or (d.durum == "bagli_degil" and "Discord hesabın" or LocalPlayer():SteamName())
     local tx = acx + ar + 30 * S
     local hapW, hapH = 150 * S, 50 * S
     local fontAd = SG.F(36 * S, "orta")
     local kisalt = Kisalt(ad, fontAd, x + w - tx - hapW - 40 * S)
     SG.Yazi(kisalt, fontAd, tx, y + h / 2, takili and R.altinAcik or R.fildisiAcik, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     local hx = tx + SG.Genislik(kisalt, fontAd) + 22 * S
     self:HapCiz(hx, y + h / 2 - hapH / 2, hapW, hapH, S, takili and 1 or 0.35)
end

-- SHNE etiket hapı (Discord'daki görünüşün Celestial karşılığı)
function PANEL:HapCiz(x, y, w, h, S, alfa)
     local SG = SardonGacha
     local R = SG.R
     draw.RoundedBox(math.floor(10 * S), x, y, w, h, Color(R.altin.r, R.altin.g, R.altin.b, 120 * alfa))
     draw.RoundedBox(math.floor(9 * S), x + 2, y + 2, w - 4, h - 4, Color(20, 28, 24, 240 * math.max(alfa, 0.6)))
     local ik = h - 18 * S
     E.RozetCiz(x + 12 * S, y + 9 * S, ik, alfa)
     SG.Yazi("SHNE", SG.F(h * 0.5, "kalin"), x + 12 * S + ik + 10 * S, y + h / 2, R.fildisiAcik, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, alfa)
end

function PANEL:KazanimCiz(S, ox, oy)
     local SG = SardonGacha
     local R = SG.R
     local d = E.Durum or {}
     local sc = d.scSaat or 1
     local y, kw, kh = oy + 452 * S, 350 * S, 84 * S
     local kartlar = {
          { "+" .. sc .. " ShineCoin", "Ek olarak, aktif " .. E.AralikMetni(d.dkSaat), function(x, yy, b) E.SikkeCiz(x, yy, b) end },
          { "SHNE rozeti", "TAB oyuncu listesinde", function(x, yy, b) E.RozetCiz(x, yy, b, 1) end },
     }
     for i, k in ipairs(kartlar) do
          local x = ox + 560 * S + (i - 1) * (kw + 20 * S)
          SG.Kutu(x, y, kw, kh, Color(14, 22, 19, 232))
          SG.Gradyan(x, y, kw * 0.5, kh, Color(190, 162, 104, 26), "sol")
          SG.Cerceve(x, y, kw, kh, R.cizgi)
          local b = 46 * S
          k[3](x + 18 * S, y + kh / 2 - b / 2, b)
          SG.Yazi(k[1], SG.F(24 * S, "kalin"), x + 80 * S, y + kh / 2 - 2 * S, R.fildisiAcik, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
          SG.Yazi(k[2], SG.F(16 * S), x + 80 * S, y + kh / 2 + 4 * S, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     end
     SG.Yazi("Etiket takılıyken ikisi de senin", SG.F(16 * S), ox + 560 * S + kw + 10 * S, y + kh + 10 * S, R.sonuk, TEXT_ALIGN_CENTER)
end

function PANEL:AltBolumCiz(S, ox, oy)
     local SG = SardonGacha
     local R = SG.R
     local d = E.Durum
     local x, y, w = ox + 560 * S, oy + 584 * S, 720 * S
     if d and d.durum == "etiket" then
          local dkSaat = math.max(1, d.dkSaat or 240)
          local dk = math.Clamp(d.dk or 0, 0, dkSaat)
          SG.Yazi(SG.Buyuk("Sonraki ödül"), SG.F(16 * S, "orta"), x, y, R.altin)
          SG.Yazi(E.SureMetni(dk) .. " / " .. E.SureMetni(dkSaat), SG.F(18 * S, "orta"), x + w, y - 2 * S, R.fildisiAcik, TEXT_ALIGN_RIGHT)
          local by, bh = y + 30 * S, 14 * S
          draw.RoundedBox(math.floor(bh / 2), x, by, w, bh, Color(30, 38, 33, 240))
          local dolu = w * dk / dkSaat
          if dolu > 1 then
               draw.RoundedBox(math.floor(bh / 2), x, by, math.max(bh, dolu), bh, d.neden and R.altinKoyu or R.altin)
               if not d.neden then SG.Parilti(x + dolu, by + bh / 2, 70 * S, 40 * S, R.altinAcik, 90 + 50 * math.sin(RealTime() * 3)) end
          end
          SG.Yazi("Bugün +" .. (d.gunSc or 0) .. " ShineCoin", SG.F(17 * S), x, by + 30 * S, R.govde)
          SG.Yazi("Toplam " .. (d.topSc or 0) .. " ShineCoin", SG.F(17 * S), x + w, by + 30 * S, R.govde, TEXT_ALIGN_RIGHT)
          if d.neden then
               SG.Yazi(d.neden == "afk" and "Sayaç duruyor (AFK)" or "Sayaç duruyor", SG.F(16 * S, "orta"), x, by + 60 * S, R.hata)
          end
          return
     end
     local adimlar = Adimlar(d)
     if not adimlar then return end
     for i, a in ipairs(adimlar) do
          local yy = y + (i - 1) * 54 * S
          local aktif = not a[2] and (i == 1 or adimlar[1][2])
          SG.Kutu(x, yy, w, 46 * S, Color(14, 22, 19, aktif and 232 or 160))
          if aktif then SG.Cerceve(x, yy, w, 46 * S, R.cizgi) end
          if a[2] then
               -- tamamlanan adım: yeşil baklava (✓ Montserrat'ta yok)
               SG.Baklava(x + 22 * S, yy + 23 * S, 8 * S, R.iyi, 1, true)
          else
               SG.Yazi(tostring(i), SG.F(24 * S, "baslik"), x + 22 * S, yy + 23 * S, aktif and R.altinAcik or R.altinKoyu, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
          local font = SG.F(17 * S, aktif and "orta" or "govde")
          SG.Yazi(a[1], font, x + 48 * S, yy + 23 * S, a[2] and R.soluk or (aktif and R.fildisiAcik or R.govde), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          if i == 2 and not a[2] then
               local hx = x + 48 * S + SG.Genislik(a[1], font) + 14 * S
               if hx + 96 * S < x + w then self:HapCiz(hx, yy + 9 * S, 92 * S, 28 * S, S, 1) end
          end
     end
end

function PANEL:Paint(w, h)
     local SG = SardonGacha
     if not SG then return end
     local R = SG.R
     local S, ox, oy = self.S or 1, self.ox or 0, self.oy or 0
     local d = E.Durum

     -- sağ sütunun arkası hafif koyulur
     SG.Gradyan(w * 0.35, 0, w * 0.65, h, Color(4, 8, 6, 170), "sag")

     self:KahramanCiz(S, ox, oy)
     self:KartCiz(S, ox, oy)

     -- etiket yokken kartın altında "uzatılan" hap (referanstaki elde tutulan etiket)
     if not (d and d.durum == "etiket") then
          local bob = math.sin(RealTime() * 1.4) * 5 * S
          SG.Parilti(ox + 680 * S, oy + 274 * S + bob, 200 * S, 80 * S, R.altin, 40)
          self:HapCiz(ox + 604 * S, oy + 250 * S + bob, 150 * S, 48 * S, S, 0.95)
     end

     local baslik = Baslik(d)
     local fb = SG.F(60 * S, "baslik")
     SG.Parilti(ox + 560 * S + SG.Genislik(baslik, fb) / 2, oy + 352 * S, SG.Genislik(baslik, fb) * 1.4, 120 * S, R.altin, 34)
     SG.Yazi(baslik, fb, ox + 556 * S, oy + 318 * S, (d and d.durum == "etiket") and R.altinAcik or R.fildisiAcik)
     local satirlar = SG.Sar(Aciklama(d), SG.F(18 * S), 720 * S)
     for i, s in ipairs(satirlar) do
          if i > 2 then break end
          SG.Yazi(s, SG.F(18 * S), ox + 560 * S, oy + (392 + (i - 1) * 25) * S, R.govde)
     end

     self:KazanimCiz(S, ox, oy)
     self:AltBolumCiz(S, ox, oy)

     -- alt satır: bağlı hesap + not
     local fy = oy + 806 * S
     SG.Kesik(ox + 560 * S, fy, 720 * S, R.cizgiSoluk)
     local sol
     if d and d.id then
          sol = "Discord: " .. (d.ad or "?") .. "  ·  bağlı"
     else
          sol = "Discord hesabı oyuna bağlı değil"
     end
     local fAlt = SG.F(16 * S)
     local sag = "Etiketi çıkarırsan sayaç durur, dakikaların saklanır"
     local sagW = SG.Genislik(sag, fAlt)
     SG.Yazi(Kisalt(sol, fAlt, 720 * S - sagW - 28 * S), fAlt, ox + 560 * S, fy + 14 * S, R.sonuk)
     SG.Yazi(sag, fAlt, ox + 1280 * S, fy + 14 * S, R.sonuk, TEXT_ALIGN_RIGHT)
end

vgui.Register("SardonEtiket.Sayfa", PANEL, "EditablePanel")

/*
*   Mağaza sol menüsüne kayıt
*/
hook.Add("SardonShineStoreSayfalar", "SardonEtiket", function(liste)
     liste[#liste + 1] = {
          id = "etiket", ad = "Discord Etiketi", alt = "SHNE", sinif = "SardonEtiket.Sayfa",
          ikonCiz = function(x, y, boy, alfa) E.RozetCiz(x + boy * 0.08, y + boy * 0.08, boy * 0.84, alfa) end,
     }
end)
