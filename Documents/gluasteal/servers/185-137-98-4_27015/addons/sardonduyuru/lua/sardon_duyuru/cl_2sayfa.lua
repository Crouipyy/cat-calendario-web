-- "addons\\sardonduyuru\\lua\\sardon_duyuru\\cl_2sayfa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
--[[
     Sardon Duyuru :: Shine Admin › Duyuru sayfası (istemci). Sunucu tarafı sv_1duyuru.lua.

     Yeni duyuru: tür, başlık (isteğe bağlı), metin, geri sayım, ses ve imza; sağda ekrandaki bandın
     birebir önizlemesi (gerçek boyutta yerleşip pencereye sığacak kadar küçültülür), süren geri sayımlar
     ve komut kısa yolları. "Bende önizle" bandı yalnız kendi ekranında oynatır.
     Geçmiş: son 60 duyuru; forma al, yeniden gönder, geri sayımı kaldır.
     Taslak sayfa değişse de kalır (D.Taslak).
]]

local D = SardonDuyuru

D.Taslak = D.Taslak or { tur = "duyuru", baslik = "", metin = "", dk = 0, ses = true, imza = true }

local function Iste(islem, yaz)
     net.Start(D.NET)
          net.WriteUInt(islem, 3)
          if yaz then yaz() end
     net.SendToServer()
end

local function GonderAg(t)
     Iste(2, function()
          net.WriteString(t.tur or "duyuru")
          net.WriteString(t.baslik or "")
          net.WriteString(t.metin or "")
          net.WriteUInt(math.Clamp(math.floor(tonumber(t.dk) or 0), 0, D.SayacEnCok), 16)
          net.WriteBool(t.ses ~= false)
          net.WriteBool(t.imza ~= false)
     end)
end

local mGokyuzu = Material("vgui/gradient-u")

local function Uzunluk(s) return utf8.len(s or "") or #(s or "") end

local function Tarih(t) return t and os.date("%d.%m %H:%M", t) or "—" end

-- süren geri sayımın şu anki kalanı (sn) ya da nil
local function Kalan(id)
     local v = D.SayfaVeri
     local a = v and v.aktif
     if not a then return end
     local k = a[id] or a[tostring(id)]
     if not k then return end
     local kalan = k - (RealTime() - (D.SayfaVeriT or RealTime()))
     return kalan > 0 and kalan or nil
end

local function Aktifler()
     local out = {}
     local v = D.SayfaVeri
     for _, k in ipairs(v and v.gecmis or {}) do
          if Kalan(k.id) then out[#out + 1] = k end
     end
     return out
end

local function KendiImzam()
     local lp = LocalPlayer()
     return IsValid(lp) and (lp.SteamName and lp:SteamName() or lp:Nick()) or "Yönetim"
end

local function DuzMetin(k)
     return ((k.baslik or "") ~= "" and (k.baslik .. " — ") or "") .. (string.gsub(k.metin or "", "\n+", " "))
end

local function SayfaKaydet()
     if not (ShineAdmin and ShineAdmin.RegisterPage) then return false end

     ShineAdmin:RegisterPage("duyuru", {
          label = "Anuncio",
          icon = "mic",
          group = "home",
          order = 3,
          title = "Anuncio",
          subtitle = "Anuncio OOC en juego: franja arriba al centro en todas las pantallas y línea en el chat. Los anuncios con cuenta atrás quedan bajo la brújula.",
          access = function(ply) return SardonDuyuru.Yetkili(ply) end,
          available = function() return SardonDuyuru ~= nil and SardonDuyuru.OnizlemeCiz ~= nil end,
          rail = false,

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local P = ctx.panel
               local W, H = ctx.w, ctx.h
               local taslak = D.Taslak
               local sekme = "yeni"
               local sel
               local bekliyor = false

               local ICERIK_Y, ICERIK_H = 54, H - 54 - 60

               N.SubTabs(P, 0, 0, u(W), {
                    { "yeni", "Yeni duyuru" },
                    { "gecmis", "Geçmiş" },
               }, function() return sekme end, function(id)
                    sekme = id
                    if ctx.Sekme then ctx.Sekme() end
               end)

               /*
               *   YENİ DUYURU
               */
               local yeni = vgui.Create("DPanel", P)
               yeni:SetPos(0, u(ICERIK_Y))
               yeni:SetSize(u(W), u(ICERIK_H))

               local SOL = 520
               local SAG_X = 544
               local SAG_W = W - SAG_X
               local girisBaslik, girisMetin

               yeni.Paint = function(_, pw)
                    N.Eyebrow("Tür", 0, 0, N.Clr.gold)
                    N.Eyebrow("Başlık · isteğe bağlı", 0, u(74), N.Clr.gold)
                    local bu = Uzunluk(taslak.baslik)
                    N.Text(bu .. "/" .. D.BaslikEnCok, "micro", u(SOL), u(74), bu > D.BaslikEnCok and N.Clr.bad or N.Clr.faint, TEXT_ALIGN_RIGHT)
                    N.Eyebrow("Metin", 0, u(142), N.Clr.gold)
                    local mu = Uzunluk(taslak.metin)
                    N.Text(mu .. "/" .. D.MetinEnCok, "micro", u(SOL), u(142), mu > D.MetinEnCok and N.Clr.bad or N.Clr.faint, TEXT_ALIGN_RIGHT)

                    N.Eyebrow("Önizleme", u(SAG_X), 0, N.Clr.gold)
                    N.Eyebrow("Süren geri sayımlar", u(SAG_X), u(262), N.Clr.gold)
               end

               -- tür seçimi
               local tw = (SOL - 3 * 8) / 4
               for i, T in ipairs(D.Turler) do
                    local b = vgui.Create("DButton", yeni)
                    b:SetPos(u((i - 1) * (tw + 8)), u(18))
                    b:SetSize(u(tw), u(42))
                    b:SetText("")
                    b.OnCursorEntered = function() N.SndHover() end
                    b.Paint = function(s, pw, ph)
                         local on = taslak.tur == T.id
                         if on then
                              N.Box(0, 0, pw, ph, Color(T.renk.r, T.renk.g, T.renk.b, 30))
                         else
                              N.Box(0, 0, pw, ph, s:IsHovered() and N.Clr.btnHover or N.Clr.toolBg)
                         end
                         N.Outline(0, 0, pw, ph, on and T.renk or N.Clr.toolLine, 1)
                         if on then N.Box(0, 0, u(2), ph, T.renk) end
                         local r = u(4)
                         draw.NoTexture()
                         surface.SetDrawColor(on and T.renk or N.Clr.faint)
                         surface.DrawPoly({ { x = u(18), y = ph / 2 - r }, { x = u(18) + r, y = ph / 2 }, { x = u(18), y = ph / 2 + r }, { x = u(18) - r, y = ph / 2 } })
                         N.Text(T.ad, "body", u(32), ph / 2, on and N.Clr.text or N.Clr.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    b.DoClick = function()
                         N.SndClick()
                         taslak.tur = T.id
                    end
               end

               girisBaslik = N.PlainEntry(yeni, 0, u(92), u(SOL), u(38), "Ör. Quidditch Maçı", function(v) taslak.baslik = v end)
               girisBaslik:SetValue(taslak.baslik or "")

               local em
               girisMetin, em = N.PlainEntry(yeni, 0, u(160), u(SOL), u(104), "Oyunculara ne duyurmak istiyorsun?", function(v) taslak.metin = v end)
               em:SetMultiline(true)
               em:SetVerticalScrollbarEnabled(false)
               em:SetPos(u(12), u(8))
               em:SetSize(u(SOL) - u(20), u(104) - u(12))
               girisMetin:SetValue(taslak.metin or "")

               local kaydirici = N.Slider(yeni, 0, u(276), u(SOL), "Geri sayım", 0, 120, 0,
                    function() return taslak.dk or 0 end,
                    function(v) taslak.dk = math.floor(v + .5) end)
               kaydirici.Paint = function(_, pw, ph)
                    N.RBox(u(3), 0, 0, pw, ph, N.Clr.card)
                    N.Outline(0, 0, pw, ph, N.Clr.lineSoft, 1)
                    local dk = taslak.dk or 0
                    N.Text(dk > 0 and ("Geri sayım: " .. D.DakikaYazi(dk) .. " · pusula altında kalır, 5 ve 1 dk kala yeniden çıkar") or "Geri sayım: yok",
                         "body", u(14), u(10), dk > 0 and N.Clr.text or N.Clr.muted)
               end

               N.Toggle(yeni, 0, u(340), u(254), u(52), "Ses çalsın",
                    function() return taslak.ses end, function(b) taslak.ses = b end, "Bant açılırken kısa ses")
               N.Toggle(yeni, u(266), u(340), u(254), u(52), "Adımla imzala",
                    function() return taslak.imza end, function(b) taslak.imza = b end, "Kapalı: \"Yönetim\" yazar")

               -- canlı önizleme
               local onizlemeAnahtar, onizlemeV
               local function OnizlemeVerisi()
                    local t = {
                         tur = taslak.tur,
                         baslik = D.Temiz(taslak.baslik, D.BaslikEnCok, false),
                         metin = D.Temiz(taslak.metin, D.MetinEnCok, true),
                         imza = taslak.imza and KendiImzam() or "Yönetim",
                         dk = taslak.dk or 0,
                    }
                    return t
               end

               local sahne = vgui.Create("DPanel", yeni)
               sahne:SetPos(u(SAG_X), u(18))
               sahne:SetSize(u(SAG_W), u(232))
               sahne.Paint = function(s, pw, ph)
                    N.Box(0, 0, pw, ph, Color(9, 13, 19))
                    surface.SetMaterial(mGokyuzu)
                    surface.SetDrawColor(40, 52, 66, 90)
                    surface.DrawTexturedRect(0, 0, pw, ph * .6)
                    N.Outline(0, 0, pw, ph, N.Clr.inputLine, 1)

                    local t = OnizlemeVerisi()
                    if t.metin == "" then
                         N.Text("Metni yazdıkça bant burada görünür.", "small", pw / 2, ph / 2, N.Clr.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                         return
                    end
                    local anahtar = table.concat({ t.tur, t.baslik, t.metin, t.imza, t.dk, ScrW(), ScrH() }, "\1")
                    if anahtar ~= onizlemeAnahtar then
                         onizlemeAnahtar, onizlemeV = anahtar, D.Onizleme(t)
                    end
                    local v = onizlemeV
                    local olcek = math.min(1, (pw - u(16)) / v.W, (ph - u(16)) / v.H)
                    local bx, by = (pw - v.W * olcek) / 2, (ph - v.H * olcek) / 2
                    local sx, sy = s:LocalToScreen(0, 0)
                    local m = Matrix()
                    m:Translate(Vector(sx + bx, sy + by, 0))
                    m:Scale(Vector(olcek, olcek, 1))
                    m:Translate(Vector(-(sx + bx), -(sy + by), 0))
                    render.PushFilterMag(TEXFILTER.ANISOTROPIC)
                    render.PushFilterMin(TEXFILTER.ANISOTROPIC)
                    -- panel kırpması matristen önceki konuma bakıyor: küçültülmüş bant panele sığdığı için kapatılır
                    local kirpma = DisableClipping(true)
                    cam.PushModelMatrix(m)
                    local ok, hata = pcall(D.OnizlemeCiz, v, bx, by)
                    cam.PopModelMatrix()
                    DisableClipping(kirpma)
                    render.PopFilterMin()
                    render.PopFilterMag()
                    if not ok then ErrorNoHalt("[SardonDuyuru] önizleme: " .. tostring(hata) .. "\n") end
                    N.Text("ekrandaki boyutun %" .. math.Round(olcek * 100) .. "'i", "micro", pw - u(10), ph - u(16), N.Clr.faint, TEXT_ALIGN_RIGHT)
               end

               -- süren geri sayımlar
               local hepsiniKaldir = N.Button(yeni, u(W) - u(150), u(256), u(150), u(22), "Ekrandan kaldır", function()
                    N.Confirm("Duyuruları kaldır", "Süren bütün geri sayımlar ve şu an ekranda olan duyuru bantları herkesten kaldırılır.", "Kaldır", function()
                         Iste(3, function() net.WriteUInt(0, 32) end)
                    end, true)
               end, "ghost")
               hepsiniKaldir:SetTooltip("Yanlış gönderilen duyuruyu herkesin ekranından siler (/DuyuruKaldir)")

               local aktifListe = N.VList(yeni, u(SAG_X), u(280), u(SAG_W), u(56), {
                    rowH = u(28),
                    gapY = 0,
                    emptyText = "Süren geri sayım yok.",
                    onClick = function(k)
                         N.Confirm("Geri sayımı kaldır", "\"" .. DuzMetin(k) .. "\" geri sayımı herkesin ekranından kaldırılır.", "Kaldır", function()
                              Iste(3, function() net.WriteUInt(k.id, 32) end)
                         end, true)
                    end,
                    paintRow = function(k, _, x, y, w, h, hovered)
                         local T = D.Tur[k.tur] or D.Tur.duyuru
                         N.Box(x, y, w, h, hovered and N.Clr.hoverRow or N.Clr.toolBg)
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
                         N.Box(x, y, u(2), h, T.renk)
                         local kalan = Kalan(k.id)
                         N.Text(N.Clip(DuzMetin(k), "tiny", w - u(180)), "tiny", x + u(12), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(hovered and "kaldır" or (kalan and D.SayacYazi(kalan) or "bitti"), "tiny", x + w - u(14), y + h / 2,
                              hovered and N.Clr.bad or T.renk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               })

               local bilgi = vgui.Create("DPanel", yeni)
               bilgi:SetPos(u(SAG_X), u(344))
               bilgi:SetSize(u(SAG_W), u(56))
               bilgi.Paint = function(_, pw)
                    N.InfoBox(0, 0, pw, {
                         "Sohbet: /Duyuru #etkinlik #15dk Başlık | metin  ·  /DuyuruKaldir",
                         "Konsol: sardon_duyuru #sunucu #5dk Yeniden başlatma | Sunucu birazdan yeniden başlıyor",
                    }, "info")
               end

               local yeniBar = N.StickyBar(P, 0, u(H - 52), u(W), function()
                    if bekliyor then return "Gönderiliyor…" end
                    local t = OnizlemeVerisi()
                    if t.metin == "" then return "Metin yaz; başlık, geri sayım ve ses isteğe bağlı." end
                    if Uzunluk(taslak.metin) > D.MetinEnCok or Uzunluk(taslak.baslik) > D.BaslikEnCok then
                         return "Sınırı aşan kısım gönderilirken kesilir.", N.Clr.warn
                    end
                    local n = player.GetCount()
                    return "Çevrimiçi " .. n .. " oyuncunun ekranında üst ortada ve sohbetinde görünür.", N.Clr.ok
               end)

               local function Gonder(t, sonra)
                    local tt = D.Tur[t.tur] or D.Tur.duyuru
                    local govde = "Çevrimiçi " .. player.GetCount() .. " oyuncunun ekranında \"" .. tt.ad .. "\" bandı ve sohbetinde satır olarak görünecek."
                    if (t.dk or 0) > 0 then govde = govde .. " " .. D.DakikaYazi(t.dk) .. " geri sayım pusula altında kalır." end
                    N.Confirm("Duyuruyu gönder", govde .. "\n\n" .. N.Clip(DuzMetin(t), "body", u(440)), "Gönder", function()
                         bekliyor = true
                         D.SonGonderilen = sonra
                         GonderAg(t)
                    end)
               end

               local gonderDugme = N.Button(yeniBar, u(W) - u(190), u(8), u(190), u(36), "Herkese gönder", function()
                    local t = OnizlemeVerisi()
                    if t.metin == "" then return end
                    t.ses, t.imza = taslak.ses, taslak.imza
                    Gonder(t, "form")
               end, "primary")
               gonderDugme.Think = function(s)
                    s:SetEnabled(not bekliyor and string.Trim(taslak.metin or "") ~= "")
               end

               local onizleDugme = N.Button(yeniBar, u(W) - u(190) - u(170), u(8), u(160), u(36), "Bende önizle", function()
                    local t = OnizlemeVerisi()
                    if t.metin == "" then return end
                    D.Al({ id = -1, tur = t.tur, baslik = t.baslik, metin = t.metin, imza = t.imza, kalan = t.dk * 60, ses = taslak.ses }, true)
               end, "ghost")
               onizleDugme:SetTooltip("Bandı yalnız kendi ekranında oynatır (ses dahil); kimseye gitmez")
               onizleDugme.Think = function(s)
                    s:SetEnabled(string.Trim(taslak.metin or "") ~= "")
               end

               /*
               *   GEÇMİŞ
               */
               local gecmis = vgui.Create("DPanel", P)
               gecmis:SetPos(0, u(ICERIK_Y))
               gecmis:SetSize(u(W), u(ICERIK_H))
               gecmis.Paint = function(_, w)
                    N.TableHead(0, 0, w, {
                         { "Tarih", u(16) },
                         { "Tür", w * 0.12 },
                         { "Duyuru", w * 0.22 },
                         { "Gönderen", w - u(24), TEXT_ALIGN_RIGHT },
                    })
               end

               local function Secili()
                    local v = D.SayfaVeri
                    for _, k in ipairs(v and v.gecmis or {}) do
                         if k.id == sel then return k end
                    end
               end

               local gecmisListe = N.VList(gecmis, 0, u(30), u(W), u(ICERIK_H - 30), {
                    rowH = u(50),
                    gapY = 0,
                    emptyText = "Henüz duyuru gönderilmedi.",
                    onClick = function(k) sel = k.id end,
                    paintRow = function(k, _, x, y, w, h, hovered)
                         local T = D.Tur[k.tur] or D.Tur.duyuru
                         local on = sel == k.id
                         if on then
                              N.Box(x, y, w, h, N.Clr.selRow)
                              N.Box(x, y, u(2), h, N.Clr.gold)
                         elseif hovered then
                              N.Box(x, y, w, h, N.Clr.hoverRow)
                         end
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)

                         local ust, alt = y + h / 2 - u(9), y + h / 2 + u(10)
                         N.Text(Tarih(k.zaman), "tiny", x + u(16), y + h / 2, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(T.ad, "tiny", x + w * 0.12, y + h / 2, T.renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                         local metinW = w * 0.58
                         local baslik = (k.baslik or "") ~= "" and k.baslik or nil
                         N.Text(N.Clip(baslik or string.gsub(k.metin or "", "\n+", " "), "row", metinW), "row", x + w * 0.22, baslik and ust or y + h / 2,
                              on and N.Clr.text or N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         if baslik then
                              N.Text(N.Clip((string.gsub(k.metin or "", "\n+", " ")), "tiny", metinW), "tiny", x + w * 0.22, alt, N.Clr.rowDesc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         end

                         N.Text(N.Clip(k.gonderen or "?", "tiny", w * 0.16), "tiny", x + w - u(24), ust, N.Clr.tdText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                         local kalan = Kalan(k.id)
                         local durum, renk
                         if kalan then
                              durum, renk = "sürüyor · " .. D.SayacYazi(kalan), T.renk
                         elseif k.kaldirildi then
                              durum, renk = "kaldırıldı", N.Clr.bad
                         elseif (k.dk or 0) > 0 then
                              durum, renk = D.DakikaYazi(k.dk) .. " geri sayım", N.Clr.faint
                         elseif (k.imza or "") == "Yönetim" and k.gonderen ~= "Konsol" then
                              durum, renk = "imzasız", N.Clr.faint
                         end
                         if durum then N.Text(durum, "tiny", x + w - u(24), alt, renk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
                    end
               })

               local gecmisBar = N.StickyBar(P, 0, u(H - 52), u(W), function()
                    local k = Secili()
                    if not k then return "Listeden bir duyuru seç." end
                    return Tarih(k.zaman) .. " · " .. (k.gonderen or "?") .. " (" .. (k.sid or "?") .. ")"
               end)

               local function FormaAl(k)
                    taslak.tur = D.Tur[k.tur] and k.tur or "duyuru"
                    taslak.baslik, taslak.metin = k.baslik or "", k.metin or ""
                    taslak.dk = k.dk or 0
                    if IsValid(girisBaslik) then girisBaslik:SetValue(taslak.baslik) end
                    if IsValid(girisMetin) then girisMetin:SetValue(taslak.metin) end
                    if IsValid(kaydirici) and kaydirici.Slider then kaydirici.Slider:SetValue(taslak.dk) end
               end

               local kaldirDugme = N.Button(gecmisBar, u(W) - u(150), u(8), u(150), u(36), "Kaldır", function()
                    local k = Secili()
                    if not k or not Kalan(k.id) then return end
                    N.Confirm("Geri sayımı kaldır", "\"" .. DuzMetin(k) .. "\" geri sayımı herkesin ekranından kaldırılır.", "Kaldır", function()
                         Iste(3, function() net.WriteUInt(k.id, 32) end)
                    end, true)
               end, "danger")
               kaldirDugme.Think = function(s)
                    local k = Secili()
                    s:SetEnabled(k ~= nil and Kalan(k.id) ~= nil)
               end

               local yenidenDugme = N.Button(gecmisBar, u(W) - u(150) - u(200), u(8), u(190), u(36), "Yeniden gönder", function()
                    local k = Secili()
                    if not k then return end
                    Gonder({ tur = k.tur, baslik = k.baslik, metin = k.metin, dk = k.dk, ses = k.ses ~= false, imza = (k.imza or "") ~= "Yönetim" })
               end, "primary")
               yenidenDugme.Think = function(s) s:SetEnabled(not bekliyor and Secili() ~= nil) end

               local formaDugme = N.Button(gecmisBar, u(W) - u(150) - u(200) - u(150), u(8), u(140), u(36), "Forma al", function()
                    local k = Secili()
                    if not k then return end
                    FormaAl(k)
                    sekme = "yeni"
                    ctx.Sekme()
               end, "ghost")
               formaDugme.Think = function(s) s:SetEnabled(Secili() ~= nil) end

               function ctx.Sekme()
                    local y = sekme == "yeni"
                    yeni:SetVisible(y)
                    yeniBar:SetVisible(y)
                    gecmis:SetVisible(not y)
                    gecmisBar:SetVisible(not y)
               end
               ctx.Sekme()
               function ctx.SekmeAc(id)
                    sekme = id
                    ctx.Sekme()
               end

               local function Yenile()
                    if not IsValid(P) then return end
                    local v = D.SayfaVeri or {}
                    if IsValid(gecmisListe) then gecmisListe:SetItems(v.gecmis or {}, true) end
                    if IsValid(aktifListe) then aktifListe:SetItems(Aktifler(), true) end
               end

               D.SayfaYenile = Yenile
               D.SayfaSonuc = function(ok, mesaj)
                    bekliyor = false
                    if IsValid(P) then ctx.Flash(mesaj, not ok and "bad" or nil) end
                    if ok and D.SonGonderilen == "form" then
                         taslak.baslik, taslak.metin, taslak.dk = "", "", 0
                         if IsValid(girisBaslik) then girisBaslik:SetValue("") end
                         if IsValid(girisMetin) then girisMetin:SetValue("") end
                         if IsValid(kaydirici) and kaydirici.Slider then kaydirici.Slider:SetValue(0) end
                    end
                    D.SonGonderilen = nil
               end

               ctx.SetHead({ count = function() return player.GetCount() end, note = "ÇEVRİMİÇİ" })
               ctx.OnLeave = function()
                    D.SayfaYenile, D.SayfaSonuc = nil, nil
               end

               Yenile()
               Iste(4)

               -- açıkken 15 sn'de bir tazele (süren geri sayımlar, başka yetkilinin duyurusu)
               local zaman = vgui.Create("DPanel", P)
               zaman:SetSize(0, 0)
               zaman.sonraki = RealTime() + 15
               zaman.Think = function(s)
                    if RealTime() >= s.sonraki then
                         s.sonraki = RealTime() + 15
                         Iste(4)
                    end
               end

               return function() Iste(4) end
          end
     })
     return true
end

-- sardon_duyuru, sardon_shineadmin'den önce yükleniyor (alfabetik); ShineAdmin gelene kadar dene
if not SayfaKaydet() then
     timer.Create("SardonDuyuru.Sayfa", 1, 120, function()
          if SayfaKaydet() then timer.Remove("SardonDuyuru.Sayfa") end
     end)
end
