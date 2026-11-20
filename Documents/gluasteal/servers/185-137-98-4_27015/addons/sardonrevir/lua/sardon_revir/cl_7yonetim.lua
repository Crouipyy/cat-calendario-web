-- "addons\\sardonrevir\\lua\\sardon_revir\\cl_7yonetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: Shine Admin sayfası "revir" (yalnızca süper admin).
-- Sekmeler: Ayarlar · Nöbetler · Oyuncular · Yerleşim

local R = SardonRevir

local OP = {AYAR = 1, HARITA = 2, HARITA_SIFIRLA = 3, OYUNCU = 4, SIFIRLA = 5, TEST = 6, IPTAL = 7, LISTE = 8, USTALIK = 9, YER = 10}

local function Istek(op, yaz)
     net.Start("SardonRevir.Yonetim")
          net.WriteUInt(op, 4)
          if (yaz) then yaz() end
     net.SendToServer()
end

R.YonetimVeri = R.YonetimVeri or {}
net.Receive("SardonRevir.YonetimVeri", function()
     local tur = net.ReadString()
     R.YonetimVeri[tur] = net.ReadTable()
     hook.Run("SardonRevirYonetim", tur)
end)

local function Esit(a, b) return util.TableToJSON(a or {}) == util.TableToJSON(b or {}) end

local AYAR_SATIRLARI = {
     {"hastaSayisi", "Nöbetteki hasta", 1, 3},
     {"eszamanli", "Aynı anda gönüllü", 1, 6},
     {"gunluk", "Günlük nöbet (karakter / hesap)", 1, 10},
     {"sifirlamaSaat", "Günlük hak yenilenme saati", 0, 23},
     {"esik", "Rün eşiği (%)", 40, 95},
     {"tutunma", "Bilinmeyen büyü tutunma (%)", 0, 100},
     {"garanti", "En geç tutunduğu iyi çizim", 1, 10},
     {"yanlisSiniri", "Pomfrey'in devraldığı yanlış", 1, 6},
     {"deneyimTaban", "Zorluk başına deneyim", 1, 200},
     {"dalPuaniEsik", "1 Şifa puanı için deneyim", 10, 2000},
     {"pomfreyBonus", "Pomfrey (oyuncu) bonusu %", 0, 200},
     {"onur", "Hasta başına Onur", 0, 50},
     {"nobetDakika", "Nöbet süresi (dk)", 5, 120},
     {"uzaklasma", "Revirden uzak kalma (sn)", 20, 900},
     {"ogrenmeKademe", "Büyünün verildiği ustalık kademesi", 1, 5}
}

local sayfa = {
     id = "revir",
     label = "Guardia de enfermería",
     icon = "plus",
     group = "magic",
     order = 37,
     title = "Guardia de enfermería",
     subtitle = "Turnos voluntarios de la rama de sanación: ajustes, turnos en curso, progreso del jugador, camas y ubicación de Pomfrey.",
     access = "superadmin",
     available = function() return SardonRevir != nil and SardonRevir.AyarTemizle != nil end,

     build = function(ctx)
          local N = ShineAdmin.GetN()
          local u = N.u
          local P = ctx.panel
          local W, H = ctx.w, ctx.h
          local taslak = table.Copy(R.Ayar)
          local aktif = R.SonSekme or "ayar"
          local govde
          local SekmeKur

          N.SubTabs(P, 0, 0, u(W), {{"ayar", "Ayarlar"}, {"nobet", "Nöbetler"}, {"oyuncu", "Oyuncular"}, {"yer", "Yerleşim"}}, function() return aktif end, function(id)
               if (aktif == id) then return end
               aktif = id
               R.SonSekme = id
               SekmeKur()
          end)

          local GY = 56
          local GH = H - GY

          local function AyarKur(g)
               local sc = N.Scroll(g, 0, 0, u(W), u(GH - 60))
               local y = 0
               N.Toggle(sc, 0, y, u(W - 20), u(48), "Revir gönüllü kabul ediyor", function() return taslak.acik end, function(v) taslak.acik = v end, "Kapalıyken yeni nöbet başlamaz (test nöbeti hariç).")
               y = y + 56
               local kol = (W - 40) / 2
               for i, s in ipairs(AYAR_SATIRLARI) do
                    local x = (i - 1) % 2 == 0 and 0 or u(kol + 20)
                    if ((i - 1) % 2 == 0 and i > 1) then y = y + 62 end
                    N.Slider(sc, x, u(y), u(kol), s[2], s[3], s[4], 0, function() return taslak[s[1]] end, function(v) taslak[s[1]] = math.floor(v) end)
               end
               y = y + 70
               -- ustalık eşikleri ve dış bonus
               for i = 1, 5 do
                    N.Slider(sc, 0, u(y), u(kol), "Ustalık " .. i .. " (" .. R.UstalikAdlari[i] .. ") uygulama", 1, 200, 0, function() return taslak.ustalik[i] end, function(v) taslak.ustalik[i] = math.floor(v) end)
                    N.Slider(sc, u(kol + 20), u(y), u(kol), R.UstalikAdlari[i] .. " · revir dışı şifa +%", 0, 15, 0, function() return taslak.disBonus[i] end, function(v) taslak.disBonus[i] = math.floor(v) end)
                    y = y + 62
               end

               local bar = N.StickyBar(g, 0, u(GH - 52), u(W), function()
                    if (!Esit(taslak, R.Ayar)) then return "Kaydedilmemiş değişiklik var.", N.Clr.warn end
                    return "Ayarlar sunucuyla aynı."
               end)
               local kaydet = N.Button(bar, u(W) - u(150), u(8), u(150), u(36), "Kaydet", function()
                    Istek(OP.AYAR, function() net.WriteTable(taslak) end)
                    ctx.Flash("Revir ayarları kaydedildi.")
               end, "primary")
               kaydet.Think = function(s) s:SetEnabled(!Esit(taslak, R.Ayar)) end
               N.Button(bar, u(W) - u(150) - u(8) - u(130), u(8), u(130), u(36), "Geri al", function()
                    taslak = table.Copy(R.Ayar)
                    SekmeKur()
               end)
          end

          local function NobetKur(g)
               N.Button(g, 0, 0, u(220), u(36), "Kendime test nöbeti", function() Istek(OP.TEST) ctx.Flash("Test nöbeti başlatıldı (ödülsüz).") end, "primary")
               N.Button(g, u(230), 0, u(160), u(36), "Yenile", function() Istek(OP.LISTE) end)
               N.Button(g, u(400), 0, u(220), u(36), "Bütün nöbetleri bitir", function()
                    N.Confirm("Nöbetler bitirilsin mi?", "Süren bütün nöbetler biter, hastaları Pomfrey alır.", "Bitir", function() Istek(OP.IPTAL) end, true)
               end, "danger")
               local liste = vgui.Create("DPanel", g)
               liste:SetPos(0, u(50))
               liste:SetSize(u(W), u(GH - 60))
               liste.Paint = function(s, w, h)
                    local L = R.YonetimVeri.liste or {}
                    if (#L == 0) then N.Text("Süren nöbet yok.", "body", u(10), u(14), N.Clr.textDim) return end
                    local y = 0
                    for _, n in ipairs(L) do
                         N.Text(n.oyuncu .. "  (" .. n.ad .. ")" .. (n.test and "  · TEST" or "") .. "  ·  " .. math.floor(n.kalan / 60) .. " dk kaldı  ·  +" .. n.kazanc, "body", u(6), y + u(10), N.Clr.text)
                         y = y + u(28)
                         for _, h in ipairs(n.hastalar) do
                              N.Text("    Yatak " .. h.yatak .. " · " .. h.ad .. " · " .. h.hastalik .. " · " .. h.durum .. " · adım " .. h.gAdim .. (h.teshis != "" and (" · teşhis: " .. h.teshis) or "") .. (h.yanlis > 0 and (" · yanlış " .. h.yanlis) or ""), "small", u(6), y + u(8), N.Clr.textDim)
                              y = y + u(22)
                         end
                         y = y + u(10)
                    end
               end
               Istek(OP.LISTE)
          end

          local function OyuncuKur(g)
               local secili
               local sol = N.Scroll(g, 0, 0, u(260), u(GH - 10))
               local sag = vgui.Create("DPanel", g)
               sag:SetPos(u(280), 0)
               sag:SetSize(u(W - 280), u(GH - 10))
               for _, p in player.Iterator() do
                    local c = p:GetCharacter()
                    if (c) then
                         local b = N.Button(sol, 0, 0, u(240), u(34), p:Nick() .. " · " .. c:GetName(), function()
                              secili = c:GetID()
                              Istek(OP.OYUNCU, function() net.WriteUInt(secili, 32) end)
                         end, "ghost")
                         b:Dock(TOP)
                         b:DockMargin(0, 0, 0, u(4))
                    end
               end
               sag.Paint = function(s, w, h)
                    local k = R.YonetimVeri.oyuncu
                    if (!k or k.charid != secili) then N.Text("Soldan bir oyuncu seç.", "body", u(10), u(14), N.Clr.textDim) return end
                    local y = u(6)
                    local function S(t, c) N.Text(t, "body", u(10), y, c or N.Clr.text) y = y + u(24) end
                    S((k.ad or "?") .. "  ·  " .. k.unvan, N.Clr.gold)
                    S("Deneyim " .. k.deneyim .. "  ·  birikim " .. k.birikim .. "  ·  verilen Şifa puanı " .. k.dalpuan)
                    S("İyileştirdiği " .. k.iyilesen .. "  ·  Pomfrey'e kalan " .. k.devredilen .. "  ·  nöbet " .. k.nobet .. "  ·  ilk teşhis doğru " .. k.dogru)
                    S("Son nöbet günü " .. (k.gun != "" and k.gun or "-") .. " (" .. k.gunsayi .. ")")
                    y = y + u(6)
                    S("Ustalık:", N.Clr.gold)
                    local adlar = table.GetKeys(k.u or {})
                    table.sort(adlar)
                    for _, b in ipairs(adlar) do S("   " .. b .. ": " .. k.u[b] .. " uygulama · " .. R.UstalikAdlari[R.UstalikKademe(k.u[b])], N.Clr.textDim) end
                    if (#(k.b or {}) > 0) then S("Bekleyen büyüler: " .. table.concat(k.b, ", "), N.Clr.warn) end
               end
               local by = u(GH - 60)
               N.Button(sag, 0, by, u(170), u(36), "Günlük hakkı sıfırla", function() if (secili) then Istek(OP.SIFIRLA, function() net.WriteUInt(secili, 32) net.WriteString("gun") end) end end)
               N.Button(sag, u(180), by, u(170), u(36), "Ustalığı sıfırla", function() if (secili) then Istek(OP.SIFIRLA, function() net.WriteUInt(secili, 32) net.WriteString("ustalik") end) end end)
               N.Button(sag, u(360), by, u(170), u(36), "Hepsini sil", function()
                    if (!secili) then return end
                    N.Confirm("Revir kaydı silinsin mi?", "Deneyim, ustalık ve geçmiş silinir. Verilmiş Şifa puanları ve öğrenilmiş büyüler kalır.", "Sil", function()
                         Istek(OP.SIFIRLA, function() net.WriteUInt(secili, 32) net.WriteString("hepsi") end)
                    end, true)
               end, "danger")
               local buyuler = R.TedaviBuyuleri()
               local secBuyu, secSayi = buyuler[1], R.Ayar.ustalik[R.Ayar.ogrenmeKademe] or 4
               N.Combo(sag, 0, by - u(50), u(220), u(36), secBuyu, buyuler, function(v) secBuyu = v end)
               N.Slider(sag, u(230), by - u(60), u(260), "Uygulama sayısı", 0, 100, 0, function() return secSayi end, function(v) secSayi = math.floor(v) end)
               N.Button(sag, u(500), by - u(50), u(140), u(36), "Ustalık ata", function()
                    if (secili) then Istek(OP.USTALIK, function() net.WriteUInt(secili, 32) net.WriteString(secBuyu) net.WriteUInt(secSayi, 10) end) end
               end)
          end

          local function YerKur(g)
               local sc = N.Scroll(g, 0, 0, u(W), u(GH - 10))
               local y = 0
               local function Satir(etiket, alan, bakisDa)
                    local p = vgui.Create("DPanel", sc)
                    p:SetPos(0, u(y))
                    p:SetSize(u(W - 20), u(40))
                    p.Paint = function(s, w, h) N.Text(etiket, "body", u(6), h / 2, N.Clr.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
                    N.Button(p, u(W - 20) - u(170), u(2), u(170), u(36), "Durduğum yer", function() Istek(OP.YER, function() net.WriteString(alan) net.WriteBool(false) end) end)
                    if (bakisDa) then
                         N.Button(p, u(W - 20) - u(350), u(2), u(170), u(36), "Baktığım nokta", function() Istek(OP.YER, function() net.WriteString(alan) net.WriteBool(true) end) end)
                    end
                    y = y + 44
               end
               Satir("Madam Pomfrey (bakış yönü kaydedilir)", "pomfrey", false)
               Satir("Hastalık Defteri (masa üstü)", "defter", true)
               Satir("İlaç dolabı (Accio çıkış noktası)", "dolap", true)
               Satir("Revir girişi (hastalar buradan gelir)", "giris", false)
               y = y + 10
               for no, yt in ipairs(R.Harita and R.Harita.yataklar or {}) do
                    Satir("Yatak " .. no .. " · başucu (gönüllünün durduğu yer)", "yan:" .. no, false)
                    Satir("Yatak " .. no .. " · şiltede baş ucu", "bas:" .. no, true)
                    Satir("Yatak " .. no .. " · şiltede ayak ucu", "ayak:" .. no, true)
                    local p = vgui.Create("DPanel", sc)
                    p:SetPos(0, u(y))
                    p:SetSize(u(W - 20), u(40))
                    p.Paint = function() end
                    N.Toggle(p, 0, 0, u(W - 20), u(40), "Yatak " .. no .. " kullanılmasın", function() return R.Harita and R.Harita.yataklar[no] and R.Harita.yataklar[no].kapali end, function() Istek(OP.YER, function() net.WriteString("kapat:" .. no) net.WriteBool(false) end) end)
                    y = y + 54
               end
               N.Button(sc, 0, u(y), u(240), u(36), "Varsayılan yerleşime dön", function()
                    N.Confirm("Yerleşim sıfırlansın mı?", "Bu haritanın revir yerleşimi BSP'den ölçülen varsayılana döner.", "Sıfırla", function() Istek(OP.HARITA_SIFIRLA) end, true)
               end, "danger")
          end

          SekmeKur = function()
               if (IsValid(govde)) then govde:Remove() end
               govde = vgui.Create("DPanel", P)
               govde:SetPos(0, u(GY))
               govde:SetSize(u(W), u(GH))
               govde.Paint = function() end
               if (aktif == "ayar") then AyarKur(govde)
               elseif (aktif == "nobet") then NobetKur(govde)
               elseif (aktif == "oyuncu") then OyuncuKur(govde)
               else YerKur(govde) end
          end

          local izleyici = vgui.Create("DPanel", P)
          izleyici:SetSize(0, 0)
          izleyici.Paint = function() end
          local onceki = table.Copy(R.Ayar)
          hook.Add("SardonRevirVeri", izleyici, function()
               if (Esit(taslak, onceki)) then
                    taslak = table.Copy(R.Ayar)
                    if (aktif == "ayar") then SekmeKur() end
               end
               onceki = table.Copy(R.Ayar)
          end)

          ctx.SetHead({note = function()
               local n = R.Harita and #R.Harita.yataklar or 0
               return n .. " YATAK  ·  " .. #R.Hastaliklar .. " HASTALIK"
          end})
          SekmeKur()
     end
}

ShineAdmin = ShineAdmin or {}
ShineAdmin.Pages = ShineAdmin.Pages or {}
ShineAdmin.Pages.revir = sayfa

concommand.Add("sardon_revir_admin", function()
     if (ShineAdmin and ShineAdmin.Open) then ShineAdmin:Open("revir") end
end, nil, "Shine Admin > Revir Nöbeti sayfasını açar")
