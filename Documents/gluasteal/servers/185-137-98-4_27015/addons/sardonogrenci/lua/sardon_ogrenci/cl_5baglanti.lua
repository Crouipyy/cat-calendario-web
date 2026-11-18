-- "addons\\sardonogrenci\\lua\\sardon_ogrenci\\cl_5baglanti.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Öğrenci :: Helix yaratma akışına bağlantı, /Gorunum düzenleme kipi, Helix model panelleri, giysi renk
-- seçici. Fraksiyon adımından "description"a geçiş öğrenci fraksiyonunda Görünüm Aynası'nı açar; aynanın DEVAM'ı
-- Helix açıklama adımı yerine aynı sahnedeki Kimlik ekranını (isim, soyisim, açıklama) açar, oradan karakter
-- doğrudan oluşturulur. Nitelik (attributes) adımı hiçbir fraksiyonda gösterilmez. Helix dosyalarına dokunulmaz.
local O = SardonOgrenci

function O.AkisAcik(pnl)
     return O.Hazir() and O.Erisebilir(LocalPlayer()) and pnl.payload ~= nil and O.FraksiyonUygun(pnl.payload.faction)
end

-- nitelik puanı dağıtma adımı kaldırıldı: değişken gösterilmezse nitelik paneli boş kalır, Helix açıklamadan sonra
-- karakteri doğrudan oluşturur ve ilerleme çubuğuna "Nitelikler" bölümünü eklemez (değer nil, sunucu kabul eder)
local function nitelikGizle()
     local a = ix and ix.char and ix.char.vars and ix.char.vars.attributes
     if a then a.ShouldDisplay = function() return false end end
end
nitelikGizle()
timer.Simple(0, nitelikGizle)

local function eternalCreateMi(pnl)
     -- et_charmenuload_interface: una sola página (sin progress / SetActiveSubpanel de Helix)
     return isfunction(pnl.CreateAppearanceSelection) or isfunction(pnl.CreateCreateButton)
end

local function eternalChrome(pnl, visible)
     if IsValid(pnl.mainPanel) then pnl.mainPanel:SetVisible(visible) end
     if IsValid(pnl.backgroundPanel) then pnl.backgroundPanel:SetVisible(visible) end
end

local function eternalSalirCrear(pnl)
     if IsValid(O.AynaPanel) then O.AynaPanel:Remove() end
     if IsValid(O.KimlikPanel) then O.KimlikPanel:Remove() end
     eternalChrome(pnl, true)
     if pnl.SlideDown then pnl:SlideDown() end
     local parent = pnl:GetParent()
     if IsValid(parent) and IsValid(parent.mainPanel) and parent.mainPanel.Undim then
          parent.mainPanel:Undim()
     end
end

function O.AkisAynaAc(pnl, eskiAktif)
     local tekFraksiyon = #(pnl.factionButtons or {}) <= 1
     local eternal = eternalCreateMi(pnl)
     local hane = O.HaneNo(pnl.payload.faction)
     if eternal then eternalChrome(pnl, false) end
     O.AynaAc({
          ebeveyn = pnl:GetParent(),
          kip = "yarat",
          durum = pnl.sogDurum or O.Varsayilan("m"),
          hane = hane,
          baslangic = true,
          geri = function(ayna)
               pnl.sogDurum = ayna.durum
               ayna:Remove()
               if IsValid(pnl.progress) then
                    pnl.progress:DecrementProgress()
               end
               if eternal or tekFraksiyon then
                    if isfunction(eskiAktif) then eskiAktif(pnl, "faction", 0) end
                    if eternal then
                         eternalSalirCrear(pnl)
                    else
                         pnl:SlideDown()
                         local parent = pnl:GetParent()
                         if IsValid(parent) and IsValid(parent.mainPanel) then
                              parent.mainPanel:Undim()
                         end
                    end
               else
                    eskiAktif(pnl, "faction")
               end
          end,
          tamam = function(ayna, durum)
               pnl.sogDurum = durum
               pnl.payload:Set(O.VERI, durum)
               ayna:Remove()
               O.KimlikAc(pnl, eskiAktif, durum, hane)
          end,
     })
end

----------------------------------------------------------------------------------------
-- Kimlik ekranı (yaratmanın son adımı): aynanın ortamı ve modeli, sağda cam kartta isim / soyisim / açıklama,
-- modelin altında ad levhası. KAYDI TAMAMLA Helix doğrulamasını yapıp yükü gönderir.
----------------------------------------------------------------------------------------
local gradU, gradD = Material("vgui/gradient-u"), Material("vgui/gradient-d")
local gradL, gradR = Material("vgui/gradient-l"), Material("vgui/gradient-r")

local function kimlikFontlari()
     local S = O.Olcek
     if not S then return end
     surface.CreateFont("SOg.Alan", {font = "Montserrat Medium", size = S(19), extended = true})
     surface.CreateFont("SOg.AlanK", {font = "Montserrat Medium", size = S(16), extended = true})
     surface.CreateFont("SOg.Levha", {font = "Cinzel SemiBold", size = S(40), weight = 600, extended = true})
end
kimlikFontlari()
hook.Add("OnScreenSizeChanged", "SardonOgrenci.KimlikFont", kimlikFontlari)

-- yazı kutusu: kesik köşeli koyu yüzey (kutu), içinde boşluklu DTextEntry; odakta altın kenar ve alt çizgi
local function alan(ebeveyn, ipucu, cokSatir, degisti)
     local U, S, R = O.UI, O.UI.S, O.UI.R
     local kutu = ebeveyn:Add("Panel")
     kutu.vurgu = 0
     local g = kutu:Add("DTextEntry")
     g:SetFont(cokSatir and "SOg.AlanK" or "SOg.Alan")
     g:SetPaintBackground(false)
     g:SetUpdateOnType(true)
     g:Dock(FILL)
     g:DockMargin(S(14), cokSatir and S(10) or 0, S(14), cokSatir and S(10) or 0)
     if cokSatir then
          g:SetMultiline(true)
          -- Helix açıklamada satır sonunu siler: Enter hiç yazılmasın
          g.AllowInput = function(_, c) if c == "\n" or c == "\r" then return true end end
     end
     g.Paint = function(this)
          this:DrawTextEntryText(R.metin, R.soluk, R.parlak)
     end
     g.OnValueChange = function(_, v) degisti(v) end
     kutu.giris = g
     kutu.Paint = function(this, w, h)
          local odak = g:HasFocus()
          this.vurgu = Lerp(FrameTime() * 10, this.vurgu, odak and 1 or 0)
          local v = this.vurgu
          local k = S(9)
          local p = U.kesik(0, 0, w, h, k)
          U.poly(p, Color(8, 10, 17, 238))
          for i = 1, #p do
               local a, b = p[i], p[i % #p + 1]
               surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 46 + 120 * v)
               surface.DrawLine(a.x, a.y, b.x, b.y)
          end
          local cw = (w - k * 2) * (0.18 + 0.82 * v)
          surface.SetDrawColor(R.parlak.r, R.parlak.g, R.parlak.b, 90 + 140 * v)
          surface.DrawRect(w / 2 - cw / 2, h - S(2), cw, S(2))
          if g:GetValue() == "" and not odak then
               local y = cokSatir and S(10) or h / 2
               draw.SimpleText(ipucu, g:GetFont(), S(16), y, R.sonuk, TEXT_ALIGN_LEFT, cokSatir and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
          end
          if not g:IsEnabled() then
               U.ikon("kilit", w - h * 0.5 - S(9), h * 0.5 - S(9), S(18), R.soluk)
          end
     end
     kutu.OnMousePressed = function() g:RequestFocus() end
     return kutu
end

local KIMLIK = {}

function KIMLIK:Init()
     self:SetSize(ScrW(), ScrH())
     self:SetPos(0, 0)
     self.sahne = O.SahneYarat()
     self.sahne.yukseklik = -7
     self.acilis = 0
     self.hata = nil
end

-- t: {pnl, durum, hane, geri = fn(kimlik)}
function KIMLIK:Kur(t)
     self.secenek = t
     self.pnl = t.pnl
     self.durum = t.durum
     self.hane = t.hane or 1
     local f = ix.faction.indices[self.pnl.payload.faction]
     self.haneAd = f and L(f.name) or ""
     self.haneRenk = f and f.color or O.UI.R.altin
     self.alanlar = t.pnl.sogKimlik or {isim = "", soyisim = "", aciklama = ""}
     t.pnl.sogKimlik = self.alanlar

     self.sahne:Kur(O.Ayarlar(self.durum, O.BaslangicGiyili(self.durum.gender, self.durum.kiyafet), self.hane, false))
     self.sahne:Poz(2)
     self:Yerlesim()

     -- fraksiyonun sabit adı varsa (GetDefaultCharacterName) alanlar dolu ve kilitli
     local ad, kilit = hook.Run("GetDefaultCharacterName", LocalPlayer(), self.pnl.payload.faction)
     if isstring(ad) then
          local i, s = ad:match("^(%S+)%s+(.+)$")
          self.alanlar.isim, self.alanlar.soyisim = i or ad, s or ""
          self.isim.giris:SetValue(self.alanlar.isim)
          self.soyisim.giris:SetValue(self.alanlar.soyisim)
          if kilit then
               self.isim.giris:SetEnabled(false)
               self.soyisim.giris:SetEnabled(false)
          end
     end
     self.sahne:Parilti("govde")
end

function KIMLIK:Yerlesim()
     local U, S = O.UI, O.UI.S
     local w, h = self:GetWide(), self:GetTall()
     local pad = S(42)

     -- kart sağda, model sol yarının ortasında
     local kw = math.min(S(620), math.floor(w * 0.42))
     local kx = w - pad - kw - S(24)
     -- yükseklik içeriğe göre: başlık 132 + ad satırı 100 + açıklama etiketi 22 + kutu 190 + alt yazı / hata 78
     local aciklamaH = S(190)
     local kh = S(132) + S(100) + S(22) + aciklamaH + S(78)
     local ky = math.max(S(196), math.floor((h - kh) / 2 - S(20)))
     self.kartK = {kx, ky, kw, kh}
     self.merkezX = math.floor(kx / 2 + S(20))

     local ic = S(30)
     local iw = kw - ic * 2
     local y = ky + S(132)
     local yarim = math.floor((iw - S(16)) / 2)
     local ah = S(48)
     self.etiketY = y

     self.isim = self.isim or alan(self, "Nombre", false, function(v)
          self.alanlar.isim = v
          self.hata = nil
     end)
     self.isim:SetPos(kx + ic, y + S(22))
     self.isim:SetSize(yarim, ah)
     self.isim.giris:SetValue(self.alanlar.isim)

     self.soyisim = self.soyisim or alan(self, "Apellido", false, function(v)
          self.alanlar.soyisim = v
          self.hata = nil
     end)
     self.soyisim:SetPos(kx + ic + yarim + S(16), y + S(22))
     self.soyisim:SetSize(yarim, ah)
     self.soyisim.giris:SetValue(self.alanlar.soyisim)

     y = y + S(22) + ah + S(30)
     self.aciklamaY = y
     self.aciklama = self.aciklama or alan(self, "Tu aspecto, gesto, lo que se nota a simple vista…", true, function(v)
          self.alanlar.aciklama = v
          self.hata = nil
     end)
     self.aciklama:SetPos(kx + ic, y + S(22))
     self.aciklama:SetSize(iw, aciklamaH)
     self.aciklama.giris:SetValue(self.alanlar.aciklama)
     self.altY = y + S(22) + self.aciklama:GetTall()

     -- Enter: sonraki alana
     self.isim.giris.OnEnter = function() self.soyisim.giris:RequestFocus() end
     self.soyisim.giris.OnEnter = function() self.aciklama.giris:RequestFocus() end

     self.geri = self.geri or self:Add("SOg.Hayalet")
     self.geri.metin = "ATRÁS"
     self.geri:SetSize(S(200), S(52))
     self.geri:SetPos(pad, h - S(52) - S(41))
     self.geri.DoClick = function()
          if self.gonderildi then return end
          U.ses("tik")
          self.secenek.geri(self)
     end

     local dw = S(320)
     self.devam = self.devam or self:Add("SOg.Ana")
     self.devam.metin = "COMPLETAR REGISTRO"
     self.devam:SetSize(dw, S(54))
     self.devam:SetPos(w - pad - dw, h - S(54) - S(40))
     self.devam.DoClick = function() self:Gonder() end
end

local function sigdirMetin(...)
     return O.UI.sigdir(...)
end

function KIMLIK:AdMetni()
     local i, s = string.Trim(self.alanlar.isim or ""), string.Trim(self.alanlar.soyisim or "")
     return string.Trim(i .. " " .. s)
end

function KIMLIK:Gonder()
     if self.gonderildi then return end
     local pnl = self.pnl
     local isim, soy = string.Trim(self.alanlar.isim or ""), string.Trim(self.alanlar.soyisim or "")
     local hata
     if isim == "" then
          hata = "Escribe tu nombre."
     elseif soy == "" then
          hata = "Escribe tu apellido."
     end

     local ad, aciklama = isim .. " " .. soy, self.alanlar.aciklama or ""
     if not hata then
          for _, v in ipairs({{"name", ad}, {"description", aciklama}}) do
               local var = ix.char.vars[v[1]]
               if var and var.OnValidate then
                    local r = {var:OnValidate(v[2], pnl.payload, LocalPlayer())}
                    if r[1] == false then
                         hata = L(unpack(r, 2))
                         break
                    end
               end
          end
     end
     if hata then
          self.hata = hata
          self.hataZaman = RealTime()
          O.UI.ses("hata")
          return
     end

     pnl.payload:Set("name", ad)
     pnl.payload:Set("description", aciklama)
     -- Eternal VerifyProgression exige model; el SV de ogrenciGorunum lo sustituye en OnAdjust.
     if pnl.payload.model == nil then
          pnl.payload:Set("model", 1)
     end
     self.gonderildi = true
     self.devam:SetEnabled(false)
     self.devam.metin = "GUARDANDO…"
     pnl:SendPayload()
     -- istemci doğrulaması geçmediyse (Helix bildirimi bu ekranın arkasında kalır)
     if not pnl.awaitingResponse then
          self.gonderildi = nil
          self.devam:SetEnabled(true)
          self.devam.metin = "COMPLETAR REGISTRO"
          self.hata = "No se pudo validar el registro; revisa los datos."
          self.hataZaman = RealTime()
     end
end

function KIMLIK:OnMousePressed(kod)
     if kod ~= MOUSE_LEFT and kod ~= MOUSE_RIGHT then return end
     self:MouseCapture(true)
     self.surukle = {kod = kod, x = gui.MouseX(), y = gui.MouseY()}
     self:RequestFocus()
end

function KIMLIK:OnMouseReleased()
     self.surukle = nil
     self:MouseCapture(false)
end

function KIMLIK:OnMouseWheeled(d)
     self.sahne:Yakinlas(d)
end

function KIMLIK:Think()
     local pnl = self.pnl
     -- yanıt geldi (oluşturuldu ya da reddedildi): Helix menüsü kendi akışını sürdürür
     if not IsValid(pnl) or (self.gonderildi and not pnl.awaitingResponse) then
          self:Remove()
          return
     end
     local s = self.surukle
     if s then
          local mx, my = gui.MouseX(), gui.MouseY()
          if s.kod == MOUSE_LEFT then
               self.sahne:Dondur((mx - s.x) * 0.45)
          else
               self.sahne.yukseklik = math.Clamp(self.sahne.yukseklik + (my - s.y) * 0.05, -30, 30)
          end
          s.x, s.y = mx, my
          if not input.IsMouseDown(s.kod) then self:OnMouseReleased() end
     end
end

function KIMLIK:Paint(w, h)
     if not self.durum then return end
     local U, S, R = O.UI, O.UI.S, O.UI.R
     local dt = math.min(FrameTime(), 0.1)
     self.acilis = math.min(1, self.acilis + dt * 1.6)
     local zaman = RealTime()
     local pad = S(42)
     local merkezX = self.merkezX

     -- zemin (aynanınkiyle aynı): gece mavisi, modelin arkasında sıcak ışık, soğuk huzmeler
     surface.SetDrawColor(5, 7, 13, 255)
     surface.DrawRect(0, 0, w, h)
     local radyal = O.Doku("radyal")
     if radyal then
          surface.SetMaterial(radyal)
          surface.SetDrawColor(160, 112, 54, 70)
          surface.DrawTexturedRect(merkezX - h * 0.55, h * 0.02, h * 1.1, h * 1.1)
          surface.SetDrawColor(60, 86, 140, 40)
          surface.DrawTexturedRect(-h * 0.35, -h * 0.45, h * 1.1, h * 1.1)
     end
     surface.SetMaterial(gradU)
     for i = 0, 2 do
          local x = merkezX - h * 0.45 + i * h * 0.22 + math.sin(zaman * 0.21 + i) * S(18)
          surface.SetDrawColor(120, 150, 210, 10 + i * 3)
          surface.DrawTexturedRectRotated(x, h * 0.32, S(120), h * 0.95, -18)
     end

     self.sahne:Ciz(0, 0, w, h, merkezX)

     surface.SetDrawColor(0, 0, 0, 210)
     surface.SetMaterial(gradU)
     surface.DrawTexturedRect(0, 0, w, h * 0.22)
     surface.SetMaterial(gradD)
     surface.DrawTexturedRect(0, h * 0.74, w, h * 0.26)
     surface.SetMaterial(gradL)
     surface.DrawTexturedRect(0, 0, w * 0.2, h)
     surface.SetMaterial(gradR)
     surface.DrawTexturedRect(w * 0.8, 0, w * 0.2, h)

     -- başlık ve adım çizgisi (KİMLİK etkin)
     U.aralikli("HOGWARTS · REGISTRO DE ESTUDIANTE", "SOg.Ust", pad, S(42), R.soluk, S(3))
     draw.SimpleText("Libro de registro", "SOg.Baslik", pad, S(58), R.parlak, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     draw.SimpleText("Escribe tu nombre en el registro; el castillo te conocerá así.", "SOg.Inferior", pad, S(104), R.gri, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     local x, y = pad, S(144)
     local adimlar = {"CASA", "APARIENCIA", "IDENTIDAD"}
     for i, ad in ipairs(adimlar) do
          local aktif = i == 3
          local renk = aktif and R.parlak or R.altin
          U.poly(U.elmas(x + S(5), y, S(aktif and 5 or 4)), renk)
          local tw = U.aralikli(ad, "SOg.Etiket", x + S(16), y - S(7), renk, S(2))
          x = x + S(16) + tw + S(14)
          if i < #adimlar then
               surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 120)
               surface.DrawRect(x, y, S(28), 1)
               x = x + S(28) + S(10)
          end
     end

     -- ad levhası: modelin altında, iki yanda elmaslı altın çizgi
     local adMetin = self:AdMetni()
     local ly = math.floor(h * 0.855)
     local bos = adMetin == ""
     local levha = sigdirMetin(bos and "Nombre" or adMetin, "SOg.Levha", math.min(S(560), merkezX * 2 - S(80)))
     surface.SetFont("SOg.Levha")
     local tw = surface.GetTextSize(levha)
     draw.SimpleText(levha, "SOg.Levha", merkezX + S(1), ly + S(2), Color(0, 0, 0, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     draw.SimpleText(levha, "SOg.Levha", merkezX, ly, bos and R.sonuk or R.parlak, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     local cizgi = S(90)
     for yon = -1, 1, 2 do
          local x0 = merkezX + yon * (tw / 2 + S(22))
          surface.SetMaterial(yon < 0 and gradL or gradR)
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 150)
          surface.DrawTexturedRect(yon < 0 and x0 - cizgi or x0, ly, cizgi, 1)
          U.poly(U.elmas(x0, ly, S(4)), R.altin)
     end
     local hr = self.haneRenk
     U.aralikli(self.haneAd:utf8upper() .. " · ESTUDIANTE", "SOg.Etiket", merkezX, ly + S(30), Color(hr.r, hr.g, hr.b, 220), S(4), TEXT_ALIGN_CENTER)

     -- kart
     local kx, ky, kw, kh = unpack(self.kartK)
     U.cam(kx, ky, kw, kh, S(18), self.acilis)
     local ic = S(30)
     U.aralikli("IDENTIDAD", "SOg.Ust", kx + ic, ky + S(28), R.soluk, S(3))
     draw.SimpleText("Datos del estudiante", "SOg.Kat", kx + ic, ky + S(44), R.parlak, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     U.daire(kx + ic + S(5), ky + S(96), S(5), hr)
     draw.SimpleText(self.haneAd, "SOg.Metin", kx + ic + S(18), ky + S(96), R.metin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 34)
     surface.DrawRect(kx + ic, ky + S(116), kw - ic * 2, 1)

     local yarim = self.isim:GetWide()
     U.aralikli("NOMBRE", "SOg.Etiket", kx + ic, self.etiketY, R.altin, S(2))
     U.aralikli("APELLIDO", "SOg.Etiket", kx + ic + yarim + S(16), self.etiketY, R.altin, S(2))
     U.aralikli("DESCRIPCIÓN", "SOg.Etiket", kx + ic, self.aciklamaY, R.altin, S(2))

     local enAz = ix.config.Get("minDescriptionLength", 16)
     local uz = utf8.len(string.Trim(self.alanlar.aciklama or "")) or 0
     draw.SimpleText(uz .. " / mín. " .. enAz, "SOg.Deger", kx + kw - ic, self.aciklamaY, uz >= enAz and R.altin or R.gri, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
     draw.SimpleText("Esto es lo que ven los demás al mirarte.", "SOg.Kucuk", kx + ic, self.altY + S(12), R.sonuk, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

     if self.hata then
          local t = RealTime() - (self.hataZaman or 0)
          local sall = math.sin(t * 40) * S(4) * math.max(0, 1 - t * 3)
          draw.SimpleText(self.hata, "SOg.Metin", kx + ic + sall, self.altY + S(40), R.kirmizi, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     end

     draw.SimpleText("Arrastra: girar  ·  Clic der. arrastrar: altura  ·  Rueda: zoom", "SOg.Kucuk", w / 2, h - S(20), R.sonuk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function KIMLIK:PaintOver(w, h)
     if self.acilis < 1 then
          surface.SetDrawColor(0, 0, 0, 255 * (1 - self.acilis))
          surface.DrawRect(0, 0, w, h)
     end
end

function KIMLIK:OnRemove()
     self.sahne:Kaldir()
     if O.KimlikPanel == self then O.KimlikPanel = nil end
end

vgui.Register("SOg.Kimlik", KIMLIK, "EditablePanel")

function O.KimlikAc(pnl, eskiAktif, durum, hane)
     if IsValid(O.KimlikPanel) then O.KimlikPanel:Remove() end
     local k = vgui.Create("SOg.Kimlik", pnl:GetParent())
     O.KimlikPanel = k
     k:Kur({
          pnl = pnl,
          durum = durum,
          hane = hane,
          geri = function(kimlik)
               kimlik:Remove()
               O.AkisAynaAc(pnl, eskiAktif)
          end,
     })
     return k
end

-- Bir ixCharMenuNew örneğine akış:
--  - Helix multi-step: fraksiyondan "description"a geçişte Ayna.
--  - Eternal et_charmenuload (página única): al SlideUp del crear, Ayna en lugar del UI Eternal.
function O.AkisBagla(self)
     if self.sogAkis then return end
     self.sogAkis = true

     if eternalCreateMi(self) then
          self.SetActiveSubpanel = function(pnl, id)
               if id == "faction" then
                    eternalSalirCrear(pnl)
                    return true
               end
               return true
          end

          local eskiSlide = self.OnSlideUp
          self.OnSlideUp = function(pnl)
               if eskiSlide then eskiSlide(pnl) end
               if O.AkisAcik(pnl) then
                    pnl.payload[O.VERI] = nil
                    pnl.sogDurum = nil
                    pnl.sogKimlik = nil
                    O.AkisAynaAc(pnl, pnl.SetActiveSubpanel)
               else
                    eternalChrome(pnl, true)
               end
          end

          local eskiDown = self.OnSlideDown
          self.OnSlideDown = function(pnl)
               if IsValid(O.AynaPanel) then O.AynaPanel:Remove() end
               if IsValid(O.KimlikPanel) then O.KimlikPanel:Remove() end
               eternalChrome(pnl, true)
               if eskiDown then eskiDown(pnl) end
          end

          local eskiSend = self.SendPayload
          self.SendPayload = function(pnl)
               if pnl.payload and pnl.payload[O.VERI] ~= nil and pnl.payload.model == nil then
                    if pnl.payload.Set then
                         pnl.payload:Set("model", 1)
                    else
                         pnl.payload.model = 1
                    end
               end
               return eskiSend(pnl)
          end
          return
     end

     local eskiAktif = self.SetActiveSubpanel
     if not isfunction(eskiAktif) then return end

     self.SetActiveSubpanel = function(pnl, id, uzunluk)
          if id == "description" and O.AkisAcik(pnl) then
               pnl.payload[O.VERI] = nil
               O.AkisAynaAc(pnl, eskiAktif)
               return true
          end
          return eskiAktif(pnl, id, uzunluk)
     end

     -- açıklama adımının GERİ'si aynaya dönsün (tek fraksiyonda tüm ekranı kapatıyordu)
     local liste = IsValid(self.descriptionModel) and self.descriptionModel:GetParent()
     for _, c in ipairs(IsValid(liste) and liste:GetChildren() or {}) do
          if c.ClassName == "ixMenuButton" then
               local eski = c.DoClick
               c.DoClick = function(b)
                    if O.AkisAcik(self) and self.payload[O.VERI] ~= nil then
                         O.AkisAynaAc(self, eskiAktif)
                    else
                         eski(b)
                    end
               end
          end
     end
end

local function bagla()
     local P = vgui.GetControlTable("ixCharMenuNew")
     if P and not P.sogBagli then
          P.sogBagli = true
          local eskiInit = P.Init
          P.Init = function(self, ...)
               eskiInit(self, ...)
               O.AkisBagla(self)
          end
     end

     local m = ix and ix.gui and ix.gui.characterMenu
     if IsValid(m) and IsValid(m.newCharacterPanel) then O.AkisBagla(m.newCharacterPanel) end
end

bagla()
hook.Add("OnGamemodeLoaded", "SardonOgrenci.Bagla", bagla)
timer.Create("SardonOgrenci.Bagla", 2, 0, bagla)

-- Helix model panelleri (açıklama adımı, silme ekranı): parçaları tabanın ardından çiz
hook.Add("PostDrawHelixModelView", "SardonOgrenci", function(panel, ent)
     if IsValid(ent) then O.ParcaCiz(ent) end
end)

-- Karakter silme ekranı (ixCharMenuLoad.deleteModel): kanca kapalı çiziliyordu ve otomatik giydirme silinecek
-- karakteri değil oynanan karakteri tanır → silinecek karakterin kayıtlı giyimiyle (kart gibi) giydir
local function silmeBagla()
     local m = ix and ix.gui and ix.gui.characterMenu
     local yp = IsValid(m) and m.loadCharacterPanel
     local mp = IsValid(yp) and yp.deleteModel
     if IsValid(mp) and mp.sogSilme ~= yp then
          mp.enableHook = true
          mp.sogSilme = yp
     end
end
silmeBagla()
timer.Create("SardonOgrenci.SilmeBagla", 1, 0, silmeBagla)

-- Carrusel Eternal (ixCharMenuCarousel): SetCharacter solo pone modelo+bodygroups;
-- el cuerpo Staylofft queda en cabeza flotante si no vestimos con ogrenciKart/ogrenciGorunum.
local function carruselBagla()
     local m = ix and ix.gui and ix.gui.characterMenu
     local load = IsValid(m) and m.loadCharacterPanel
     local car = IsValid(load) and load.carousel
     if not IsValid(car) then return end

     local function wrapEnt(ent)
          if not IsValid(ent) or ent.sogCarruselSet then return end
          local eski = ent.SetCharacter
          if not isfunction(eski) then return end
          ent.sogCarruselSet = true
          ent.SetCharacter = function(self, character)
               eski(self, character)
               if character and O.Hazir() then
                    timer.Simple(0, function()
                         if IsValid(self) and self.character == character then
                              O.KarakterKartGiydir(self, character)
                         end
                    end)
                    timer.Simple(0.08, function()
                         if IsValid(self) and self.character == character then
                              O.KarakterKartGiydir(self, character)
                         end
                    end)
               elseif IsValid(self) then
                    O.OnizlemeTemizle(self)
               end
          end
     end

     wrapEnt(car.activeCharacter)
     wrapEnt(car.lastCharacter)
end
carruselBagla()
timer.Create("SardonOgrenci.CarruselBagla", 1, 0, carruselBagla)

hook.Add("DrawHelixModelView", "SardonOgrenci.Silme", function(panel, ent)
     local yp = panel.sogSilme
     if IsValid(yp) and IsValid(ent) and yp.character then O.KarakterKartGiydir(ent, yp.character) end
end)

----------------------------------------------------------------------------------------
-- /Gorunum: düzenleme kipi
----------------------------------------------------------------------------------------
net.Receive("SardonOgrenci.AynaAc", function()
     local durum, ilk, baslangic, giyili, hane = net.ReadTable(), net.ReadBool(), net.ReadBool(), net.ReadTable(), net.ReadUInt(4)
     O.AynaAc({
          kip = "duzenle",
          durum = durum,
          giyili = giyili,
          hane = hane,
          baslangic = baslangic,
          geri = function(ayna) ayna:Remove() end,
          tamam = function(ayna, d)
               ayna.devam:SetEnabled(false)
               net.Start("SardonOgrenci.Kaydet")
                    net.WriteTable(d)
               net.SendToServer()
          end,
     })
end)

net.Receive("SardonOgrenci.Sonuc", function()
     local ok, metin = net.ReadBool(), net.ReadString()
     local p = O.AynaPanel
     if ok then
          if IsValid(p) then p:Remove() end
          notification.AddLegacy(metin, NOTIFY_GENERIC, 4)
     else
          if IsValid(p) and IsValid(p.devam) then p.devam:SetEnabled(true) end
          notification.AddLegacy(metin, NOTIFY_ERROR, 5)
          O.UI.ses("hata")
     end
end)

----------------------------------------------------------------------------------------
-- Giysi renk seçici (eşya > Rengini değiştir): giysinin bütün görünümleri, hane renkli olanlar giyenin
-- hanesinin renginde
----------------------------------------------------------------------------------------
local SECICI = {}

function SECICI:Init()
     local U = O.UI
     self:SetSize(math.min(ScrW() - U.S(40), U.S(560)), math.min(ScrH() - U.S(80), U.S(620)))
     self:Center()
     self:MakePopup()
     self.acilis = 0
end

function SECICI:Kur(item)
     local U, S = O.UI, O.UI.S
     self.item = item
     local char = LocalPlayer():GetCharacter()
     local hane = char and O.HaneNo(char:GetFaction()) or 1
     local p = O.EsyaParca(item, LocalPlayer())
     self.p = p

     local kapat = self:Add("SOg.Yuvarlak")
     kapat:SetSize(S(36), S(36))
     kapat:SetPos(self:GetWide() - S(54), S(18))
     kapat.ipucu = "Cerrar"
     kapat.cizim = function(cx, cy, r, renk)
          U.kalinCizgi(cx - r * 0.38, cy - r * 0.38, cx + r * 0.38, cy + r * 0.38, S(2), renk)
          U.kalinCizgi(cx - r * 0.38, cy + r * 0.38, cx + r * 0.38, cy - r * 0.38, S(2), renk)
     end
     kapat.DoClick = function() self:Remove() end

     local kaydir = self:Add("DScrollPanel")
     kaydir:SetPos(S(24), S(96))
     kaydir:SetSize(self:GetWide() - S(40), self:GetTall() - S(116))
     local bar = kaydir:GetVBar()
     bar:SetWide(S(4))
     bar:SetHideButtons(true)
     bar.Paint = function() end
     bar.btnGrip.Paint = function(_, gw, gh) draw.RoundedBox(gw / 2, 0, 0, gw, gh, U.R.soluk) end

     local l = kaydir:Add("DIconLayout")
     l:Dock(TOP)
     l:SetSpaceX(S(8))
     l:SetSpaceY(S(8))
     local sutun = 5
     local b = math.floor((self:GetWide() - S(56) - S(8) * (sutun - 1)) / sutun)
     for i = 1, p and #p.looks or 0 do
          local k = l:Add("SOg.Karo")
          k:SetSize(b, b + S(18))
          k.mat = O.IkonMat(O.GiysiIkonYolu(p, i, hane))
          k.yazi = O.RenkAdi(p, i)
          k.ipucu = O.HaneRengiMi(p, i) and "Se tiñe con el color de la casa" or nil
          k.secili = function() return self.item:GetData("l", 1) == i end
          k.Sec = function()
               U.ses("buyu")
               net.Start("SardonOgrenci.Renk")
                    net.WriteUInt(self.item.id, 32)
                    net.WriteUInt(i, 8)
               net.SendToServer()
               self:Remove()
          end
     end
end

function SECICI:Paint(w, h)
     local U, S = O.UI, O.UI.S
     self.acilis = math.min(1, self.acilis + FrameTime() * 5)
     Derma_DrawBackgroundBlur(self, self.acilisZaman or 0)
     U.cam(0, 0, w, h, S(18), self.acilis)
     local g = O.Giysi[self.item and self.item.giysi or ""]
     U.aralikli("ELEGIR COLOR", "SOg.Ust", S(24), S(20), U.R.soluk, S(3))
     draw.SimpleText(g and g.ad or "", "SOg.Kat", S(24), S(34), U.R.parlak, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     draw.SimpleText((O.SlotAd[g and g.slot or ""] or "") .. "  ·  " .. (self.p and #self.p.looks or 0) .. " colores", "SOg.Kucuk", S(24), S(70), U.R.gri, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function SECICI:PaintOver(w, h)
     local S = O.UI.S
     local p = vgui.GetHoveredPanel()
     if not IsValid(p) or not p.ipucu then return end
     local px, py = p:LocalToScreen(0, 0)
     local ox, oy = self:LocalToScreen(0, 0)
     px, py = px - ox, py - oy
     surface.SetFont("SOg.Kucuk")
     local tw, th = surface.GetTextSize(p.ipucu)
     local bw, bh = tw + S(20), th + S(10)
     local x = math.Clamp(px + p:GetWide() / 2 - bw / 2, S(8), w - bw - S(8))
     local y = math.max(S(8), py - bh - S(6))
     draw.RoundedBox(bh / 2, x, y, bw, bh, Color(8, 10, 17, 235))
     draw.SimpleText(p.ipucu, "SOg.Kucuk", x + bw / 2, y + bh / 2, O.UI.R.metin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function SECICI:OnKeyCodePressed(k)
     if k == KEY_ESCAPE then self:Remove() end
end

function SECICI:Think()
     if not self.item or not ix.item.instances[self.item.id] then self:Remove() end
end

vgui.Register("SOg.GiysiRenk", SECICI, "EditablePanel")

function O.RenkSeciciAc(item)
     if IsValid(O.RenkPanel) then O.RenkPanel:Remove() end
     if not O.UI then return end
     local p = vgui.Create("SOg.GiysiRenk")
     p.acilisZaman = SysTime()
     p:Kur(item)
     O.RenkPanel = p
end
