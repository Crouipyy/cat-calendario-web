-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_9c_dunya.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Dünya araçları (editör): yerler, dünyada işaretleyerek seçme, yol noktaları, kamera yerleri,
*   misión veren dünya actorleri, Sinema rotası içe aktarma, 3B yer görselleştirmesi, araç (toolgun).
*/
-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_900 = Vector(0, 0, 900)
local OPT_R_255_240_200_200 = Color(255, 240, 200, 200)
local OPT_V_0_0_2 = Vector(0, 0, 2)
local OPT_V_0_0_1 = Vector(0, 0, 1)
local OPT_V_0_0_72 = Vector(0, 0, 72)
local OPT_V_0_0_4 = Vector(0, 0, 4)
local OPT_V_0_0_6 = Vector(0, 0, 6)
local OPT_V_0_0_3 = Vector(0, 0, 3)
local OPT_V_0_0_84 = Vector(0, 0, 84)
local OPT_R_0_0_0_200 = Color(0, 0, 0, 200)
local OPT_R_220_220_220 = Color(220, 220, 220)
local G = SardonGorev
local R, O, F = G.R, G.O, G.F
local K = G.K
local E = G.E

/*
*   Dünyadan seçim kipi
*   cb(pos, yaw, iz) ; sol tık: baktığın nokta, sağ tık: durduğun yer
*/
local secim = nil
local gizlenen = {}

local function PencereleriGizle()
     gizlenen = {}
     for _, p in ipairs({ G.EditorPencere, G.YerPencere, G.DunyaPencere }) do
          if IsValid(p) and p:IsVisible() then
               p:SetVisible(false)
               gizlenen[#gizlenen + 1] = p
          end
     end
     gui.EnableScreenClicker(false)
end

local function PencereleriGoster()
     for _, p in ipairs(gizlenen) do
          if IsValid(p) then
               p:SetVisible(true)
               p:MakePopup()
          end
     end
     gizlenen = {}
end

function G.DunyadanSec(ipucu, cb)
     PencereleriGizle()
     secim = { ipucu = ipucu, cb = cb, bas = RealTime() }
end

hook.Add("PlayerBindPress", "SardonGorev.Secim", function(ply, bind, basili)
     if not secim or not basili then return end
     if RealTime() - secim.bas < 0.3 then return true end
     local s = secim
     if string.find(bind, "+attack2", 1, true) then
          secim = nil
          PencereleriGoster()
          s.cb(ply:GetPos(), ply:EyeAngles().y)
          return true
     elseif string.find(bind, "+attack", 1, true) then
          local iz = ply:GetEyeTrace()
          secim = nil
          PencereleriGoster()
          s.cb(iz.HitPos, ply:EyeAngles().y, iz)
          return true
     elseif string.find(bind, "cancelselect", 1, true) or string.find(bind, "+reload", 1, true) then
          secim = nil
          PencereleriGoster()
          return true
     end
end)

hook.Add("HUDPaint", "SardonGorev.Secim", function()
     if not secim then return end
     local W, H = ScrW(), ScrH()
     G.Pano(W / 2 - O(320), O(80), O(640), O(96), 1)
     G.Yaz(secim.ipucu or "Elegir lugar", F(18, "baslik"), W / 2, O(108), R.fildisiAcik, 1)
     G.Yaz("Clic izq.: donde miras   ·   Clic der.: donde estás (y tu orientación)   ·   R: cancelar", F(13, "kalin"), W / 2, O(146), R.altin, 1)
     local iz = LocalPlayer():GetEyeTrace()
     local e = iz.HitPos:ToScreen()
     G.Baklava(e.x, e.y, O(8), R.altinAcik, 255, false)
end)

/*
*   Yer kaydetme
*/
local function YerGonder(ad, yer, eskiAd)
     G.EditorIste("yer_kaydet", { ad = ad, eskiAd = eskiAd, yer = yer })
end

-- Yeni yer: ad sor → dünyadan seç → kaydet → cb(ad)
function G.YerYeniAkisi(tur, cb)
     Derma_StringRequest("Yeni yer", "Yer adı (küçük harf, rakam, alt çizgi):", "", function(ad)
          ad = G.Kimlik(ad)
          if ad == "" then return end
          G.DunyadanSec("“" .. ad .. "” yerini seç", function(pos, yaw)
               local yer = { tur = tur or "nokta", pos = pos, ang = Angle(0, yaw, 0), yaricap = 150, fov = 60, noktalar = {} }
               if tur == "kamera" then
                    local lp = LocalPlayer()
                    yer.pos, yer.ang = lp:EyePos(), lp:EyeAngles()
               end
               YerGonder(ad, yer)
               if cb then
                    hook.Add("SardonGorevEditorListe", "SardonGorev.YeniYer", function()
                         hook.Remove("SardonGorevEditorListe", "SardonGorev.YeniYer")
                         cb(ad)
                    end)
               end
          end)
     end)
end

local vurgu = nil
function G.YerVurgula(ad)
     vurgu = { ad = ad, bas = RealTime() }
end

/*
*   Yerler penceresi
*/
local seciliYer = nil
G.YolDuzenlenen = G.YolDuzenlenen or nil

function G.YerPenceresi(sec)
     if IsValid(G.YerPencere) then G.YerPencere:Remove() end
     seciliYer = sec or seciliYer
     local p = K.Pencere("Yerler · " .. (E.harita or ""), O(980), O(720))
     G.YerPencere = p

     local sol = vgui.Create("EditablePanel", p.govde)
     sol:Dock(LEFT)
     sol:SetWide(O(360))
     local ara = K.Giris(sol, "", false)
     ara:Dock(TOP)
     ara:SetTall(O(30))
     ara:SetPlaceholderText("Yer ara…")
     local liste = K.Kaydir(sol)
     liste:Dock(FILL)
     liste:DockMargin(0, O(6), 0, 0)
     local alt = vgui.Create("EditablePanel", sol)
     alt:Dock(BOTTOM)
     alt:SetTall(O(34))
     local function YeniDugme(m, tur)
          local b = K.Dugme(alt, m, function()
               G.YerYeniAkisi(tur, function(ad) G.YerPenceresi(ad) end)
          end, tur == "nokta" and "ana" or nil)
          b:Dock(LEFT)
          b:SetWide(O(112))
          b:DockMargin(0, 0, O(6), 0)
     end
     YeniDugme("+ Nokta", "nokta")
     YeniDugme("+ Yol", "yol")
     YeniDugme("+ Kamera", "kamera")

     local sag = K.Kaydir(p.govde)
     sag:Dock(FILL)
     sag:DockMargin(O(16), 0, 0, 0)

     local function Doldur()
          liste:Clear()
          local f = G.Kucuk(ara:GetValue() or "")
          local lp = LocalPlayer()
          local sirali = {}
          for ad, y in pairs(E.yerler or {}) do
               if f == "" or string.find(ad, f, 1, true) then sirali[#sirali + 1] = { ad = ad, y = y, d = lp:GetPos():Distance(y.pos) } end
          end
          table.sort(sirali, function(a, b) return a.d < b.d end)
          for _, x in ipairs(sirali) do
               local b = liste:Add("DButton")
               b:Dock(TOP)
               b:SetTall(O(40))
               b:DockMargin(0, 0, O(6), O(3))
               b:SetText("")
               b.Paint = function(s, w, h)
                    local sec = seciliYer == x.ad
                    G.Kutu(0, 0, w, h, sec and Color(34, 46, 36, 240) or Color(16, 24, 20, s:IsHovered() and 240 or 200))
                    if sec then G.Kutu(0, 0, O(3), h, R.altin) end
                    G.Yaz(x.ad, F(14, "kalin"), O(12), O(14), R.fildisi)
                    G.Yaz((x.y.tur or "nokta") .. ((x.y.tur == "yol") and (" · " .. #(x.y.noktalar or {}) .. " nokta") or ""), F(11, "govde"), O(12), O(30), R.soluk)
                    G.Yaz(math.Round(x.d * 0.01905) .. " m", F(12, "govde"), w - O(10), h / 2, R.soluk, 2)
               end
               b.DoClick = function() G.YerPenceresi(x.ad) end
          end
     end
     ara.OnChange = Doldur
     Doldur()

     local y = seciliYer and E.yerler[seciliYer]
     if not y then
          local l = K.Etiket(sag, "Soldan bir yer seçin ya da yeni yer ekleyin. Misiónler yerlere adlarıyla başvurur; misióni başka haritaya taşırken yalnız yerleri yeniden koymak yeter.", R.soluk, F(14, "italik"))
          l:Dock(TOP)
          l:SetWrap(true)
          l:SetTall(O(80))
          return
     end

     local kopya = table.Copy(y)
     kopya.ad = seciliYer
     local form = K.Form(sag, {
          { k = "ad", ad = "Ad", tip = "metin" },
          { k = "tur", ad = "Tür", tip = "secim", secenekler = { { id = "nokta", ad = "Nokta" }, { id = "yol", ad = "Yol (noktalar)" }, { id = "kamera", ad = "Kamera" } } },
          { k = "yaricap", ad = "Yarıçap", tip = "sayi", min = 10, max = 10000 },
          { k = "fov", ad = "Görüş açısı (kamera)", tip = "sayi", min = 10, max = 120, goster = function(d) return d.tur == "kamera" end },
          { k = "not", ad = "Not", tip = "yazi" },
     }, kopya, {})
     form:DockMargin(0, 0, O(10), 0)

     local function Kaydet()
          local ad = G.Kimlik(kopya.ad)
          if ad == "" then return end
          YerGonder(ad, { tur = kopya.tur, pos = kopya.pos, ang = kopya.ang, yaricap = kopya.yaricap, fov = kopya.fov, noktalar = kopya.noktalar, ["not"] = kopya["not"] }, seciliYer)
          seciliYer = ad
          hook.Add("SardonGorevEditorListe", "SardonGorev.YerPencere", function()
               hook.Remove("SardonGorevEditorListe", "SardonGorev.YerPencere")
               if IsValid(G.YerPencere) then G.YerPenceresi(ad) end
          end)
     end

     local dugmeler = vgui.Create("DIconLayout", sag)
     dugmeler:Dock(TOP)
     dugmeler:DockMargin(0, O(10), O(10), 0)
     dugmeler:SetSpaceX(O(6))
     dugmeler:SetSpaceY(O(6))
     local function D(m, f, tur)
          local b = K.Dugme(dugmeler, m, f, tur)
          b:SetSize(G.Genislik(m, F(13, "kalin")) + O(30), O(32))
     end
     D("Kaydet", Kaydet, "ana")
     D("Durduğum yere taşı", function()
          local lp = LocalPlayer()
          if kopya.tur == "kamera" then kopya.pos, kopya.ang = lp:EyePos(), lp:EyeAngles()
          else kopya.pos, kopya.ang = lp:GetPos(), Angle(0, lp:EyeAngles().y, 0) end
          Kaydet()
     end)
     D("Dünyadan seç…", function()
          G.DunyadanSec("“" .. seciliYer .. "” için yeni konum", function(pos, yaw)
               kopya.pos, kopya.ang = pos, Angle(0, yaw, 0)
               Kaydet()
          end)
     end)
     if kopya.tur == "kamera" then
          D("Şu anki görüşümü kaydet", function()
               local lp = LocalPlayer()
               kopya.pos, kopya.ang, kopya.fov = lp:EyePos(), lp:EyeAngles(), math.Round(lp:GetFOV())
               Kaydet()
          end)
     end
     if kopya.tur == "yol" then
          D(G.YolDuzenlenen == seciliYer and "Yol çizimini bitir" or "Yolu araçla çiz", function()
               G.YolDuzenlenen = G.YolDuzenlenen ~= seciliYer and seciliYer or nil
               if G.YolDuzenlenen then
                    notification.AddLegacy("Misión aracı: sol tık nokta ekler, sağ tık son noktayı siler (" .. seciliYer .. ")", NOTIFY_HINT, 8)
                    RunConsoleCommand("gmod_tool", "sardon_gorev")
                    p:Remove()
               else
                    G.YerPenceresi(seciliYer)
               end
          end)
          D("Noktaları temizle", function() kopya.noktalar = {} Kaydet() end, "tehlike")
     end
     D("Işınlan", function() G.EditorIste("isinla", { ad = seciliYer }) end)
     D("Mostrar", function() G.YerVurgula(seciliYer) end)
     D("Sil", function()
          Derma_Query("“" .. seciliYer .. "” silinsin mi? Bu yeri kullanan misiónler bozulur.", "Yeri sil", "Sil", function()
               G.EditorIste("yer_sil", { ad = seciliYer })
               seciliYer = nil
               timer.Simple(0.3, function() if IsValid(G.YerPencere) then G.YerPenceresi() end end)
          end, "Cancelar")
     end, "tehlike")

     local bilgi = K.Etiket(sag, string.format("Konum: %.0f, %.0f, %.0f   ·   Yön: %.0f°", kopya.pos.x, kopya.pos.y, kopya.pos.z, kopya.ang.y), R.soluk, F(12, "govde"))
     bilgi:Dock(TOP)
     bilgi:DockMargin(0, O(10), 0, 0)
     bilgi:SetTall(O(24))

end

/*
*   Yol çizimi araçla
*/
function G.AracSol(iz)
     if not G.Editor(LocalPlayer()) then return end
     if G.YolDuzenlenen and E.yerler[G.YolDuzenlenen] then
          local y = table.Copy(E.yerler[G.YolDuzenlenen])
          y.noktalar = y.noktalar or {}
          y.noktalar[#y.noktalar + 1] = iz.HitPos
          YerGonder(G.YolDuzenlenen, y)
          surface.PlaySound("buttons/blip1.wav")
          return
     end
     -- yeni nokta yeri
     Derma_StringRequest("Yeni yer", "Yer adı:", "", function(ad)
          ad = G.Kimlik(ad)
          if ad == "" then return end
          YerGonder(ad, { tur = "nokta", pos = iz.HitPos, ang = Angle(0, LocalPlayer():EyeAngles().y + 180, 0), yaricap = 150, fov = 60, noktalar = {} })
     end)
end

function G.AracSag(iz)
     if not G.Editor(LocalPlayer()) then return end
     if G.YolDuzenlenen and E.yerler[G.YolDuzenlenen] then
          local y = table.Copy(E.yerler[G.YolDuzenlenen])
          if #(y.noktalar or {}) > 0 then
               table.remove(y.noktalar)
               YerGonder(G.YolDuzenlenen, y)
               surface.PlaySound("buttons/button15.wav")
          end
          return
     end
     -- en yakın yer
     local enYakin, enD = nil, 160
     for ad, y in pairs(E.yerler or {}) do
          local d = y.pos:Distance(iz.HitPos)
          if d < enD then enYakin, enD = ad, d end
     end
     if enYakin then G.YerPenceresi(enYakin) else notification.AddLegacy("Yakında yer yok.", NOTIFY_HINT, 3) end
end

/*
*   3B görselleştirme (editör açıkken ya da misión aracı eldeyken)
*/
local function AracElde()
     local w = LocalPlayer():GetActiveWeapon()
     if not IsValid(w) or w:GetClass() ~= "gmod_tool" then return false end
     local t = w.GetMode and w:GetMode()
     return t == "sardon_gorev"
end

local matIsin = Material("effects/lamp_beam")
local matHalka = Material("effects/select_ring")
local renkler = { nokta = Color(223, 193, 128), yol = Color(150, 196, 214), kamera = Color(214, 150, 200) }

hook.Add("PostDrawTranslucentRenderables", "SardonGorev.Yerler", function(_, gok)
     if gok then return end
     if not (IsValid(G.EditorPencere) or AracElde() or vurgu or secim) then return end
     if not G.Editor(LocalPlayer()) then return end
     local goz = LocalPlayer():EyePos()
     local t = RealTime()
     local aci = Angle(0, EyeAngles().y - 90, 90)

     for ad, y in pairs(E.yerler or {}) do
          local d = goz:Distance(y.pos)
          local vurgulu = vurgu and vurgu.ad == ad
          if d < 4500 or vurgulu then
               local renk = renkler[y.tur or "nokta"] or renkler.nokta
               if vurgulu then
                    render.SetMaterial(matIsin)
                    render.DrawBeam(y.pos, y.pos + OPT_V_0_0_900, 80, 0, 1, OPT_R_255_240_200_200)
               end
               if y.tur == "kamera" then
                    local ileri, sag, ust = y.ang:Forward(), y.ang:Right(), y.ang:Up()
                    render.DrawLine(y.pos, y.pos + ileri * 60, renk, true)
                    local u = y.pos + ileri * 60
                    for _, k in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
                         render.DrawLine(y.pos, u + sag * 30 * k[1] + ust * 18 * k[2], renk, true)
                    end
               else
                    render.SetMaterial(matHalka)
                    render.DrawQuadEasy(y.pos + OPT_V_0_0_2, OPT_V_0_0_1, (y.yaricap or 150) * 2, (y.yaricap or 150) * 2, Color(renk.r, renk.g, renk.b, 70), 0)
                    render.DrawLine(y.pos, y.pos + OPT_V_0_0_72, renk, true)
                    render.DrawLine(y.pos + OPT_V_0_0_4, y.pos + OPT_V_0_0_4 + Angle(0, y.ang.y, 0):Forward() * 40, renk, true)
               end
               if y.tur == "yol" then
                    local once = y.pos
                    for i, p in ipairs(y.noktalar or {}) do
                         render.DrawLine(once + OPT_V_0_0_6, p + OPT_V_0_0_6, renk, true)
                         render.SetMaterial(matHalka)
                         render.DrawQuadEasy(p + OPT_V_0_0_3, OPT_V_0_0_1, 24, 24, renk, 0)
                         once = p
                    end
               end
               if d < 1600 or vurgulu then
                    cam.Start3D2D(y.pos + OPT_V_0_0_84, aci, 0.12)
                         draw.SimpleTextOutlined(ad, "SardonGorev.D_Ad", 0, 0, renk, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, OPT_R_0_0_0_200)
                         draw.SimpleTextOutlined((y.tur or "nokta") .. (G.YolDuzenlenen == ad and "  · ÇİZİLİYOR" or ""), "SardonGorev.D_Unvan", 0, 4, OPT_R_220_220_220, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, OPT_R_0_0_0_200)
                    cam.End3D2D()
               end
          end
     end
     if vurgu and t - vurgu.bas > 6 then vurgu = nil end
end)

/*
*   Dünya actorleri (misión verenler)
*/
local SATIR = {
     { k = "metin", ad = "Söz", tip = "yazi", v = "" },
     { k = "ses", ad = "Ses dosyası", tip = "ses", v = "" },
     { k = "anim", ad = "Hareket", tip = "anim", v = "" },
}
local function SatirOzet(s) return "“" .. G.Kisalt(s.metin or "", 50) .. "”" .. ((s.ses or "") ~= "" and "  ♪" or "") end

local DUNYA_ALANLARI = {
     { k = "id", ad = "Kimlik", tip = "metin", v = "" },
     { k = "ad", ad = "Görünen ad", tip = "metin", v = "" },
     { k = "unvan", ad = "Unvan", tip = "metin", v = "" },
     { k = "yer", ad = "Yer", tip = "yer", v = "" },
     { k = "model", ad = "Model", tip = "model", v = "models/player/group01/male_07.mdl" },
     { k = "skin", ad = "Skin", tip = "sayi", v = 0, min = 0, max = 32 },
     { k = "bg", ad = "Bodygroup (no=değer, virgülle)", tip = "metin", v = "" },
     { k = "boy", ad = "Boy ölçeği", tip = "sayi", v = 1, min = 0.5, max = 1.6 },
     { k = "bekleAnim", ad = "Bekleme animasyonu", tip = "anim", v = "" },
     { k = "isimRenk", ad = "İsim rengi", tip = "renk", v = { 232, 219, 182 } },
     { k = "isimGoster", ad = "Baş üstünde ad", tip = "bool", v = true },
     { k = "gorevler", ad = "Verdiği misiónler", tip = "liste", v = {}, alanlar = { { k = "gorev", ad = "Misión", tip = "gorev", v = "" } }, ozet = function(s) return s.gorev or "?" end },
     { k = "cagri", ad = "Yaklaşana seslenme", tip = "liste", v = {}, alanlar = SATIR, ozet = SatirOzet },
     { k = "selam", ad = "Konuşunca (misión varken)", tip = "liste", v = {}, alanlar = SATIR, ozet = SatirOzet },
     { k = "bos", ad = "Konuşunca (misión yokken)", tip = "liste", v = {}, alanlar = SATIR, ozet = SatirOzet },
     { k = "menu", ad = "Konuşunca açılan menü", tip = "secim", v = "", secenekler = { { id = "", ad = "Yok (misión verir)" }, { id = "aksesuar", ad = "Madam Malkin aksesuar dükkânı" }, { id = "berber", ad = "Kuaför (saç, kaş ve makyaj; ücretli)" } } },
}

local dunyaSecili = 1

function G.DunyaPenceresi()
     if IsValid(G.DunyaPencere) then G.DunyaPencere:Remove() end
     local liste = table.Copy(E.dunya or {})
     -- eski düz liste guardarlarını kayda çevir
     for _, d in ipairs(liste) do
          for i, x in ipairs(d.gorevler or {}) do if isstring(x) then d.gorevler[i] = { gorev = x } end end
     end
     local p = K.Pencere("Dünya actorleri (misión verenler) · " .. (E.harita or ""), O(1100), O(760))
     G.DunyaPencere = p
     dunyaSecili = math.Clamp(dunyaSecili, 1, math.max(1, #liste))

     local sol = vgui.Create("EditablePanel", p.govde)
     sol:Dock(LEFT)
     sol:SetWide(O(300))
     local kay = K.Kaydir(sol)
     kay:Dock(FILL)
     for i, d in ipairs(liste) do
          local b = kay:Add("DButton")
          b:Dock(TOP)
          b:SetTall(O(44))
          b:DockMargin(0, 0, O(6), O(3))
          b:SetText("")
          b.Paint = function(s, w, h)
               local sec = dunyaSecili == i
               G.Kutu(0, 0, w, h, sec and Color(34, 46, 36, 240) or Color(16, 24, 20, s:IsHovered() and 240 or 200))
               if sec then G.Kutu(0, 0, O(3), h, R.altin) end
               G.Yaz(d.ad or d.id or "?", F(14, "kalin"), O(12), O(14), R.fildisi)
               G.Yaz((d.yer or "yer yok") .. " · " .. #(d.gorevler or {}) .. " misión", F(11, "govde"), O(12), O(31), R.soluk)
          end
          b.DoClick = function() dunyaSecili = i G.DunyaPenceresiYenile(liste) end
     end
     local alt = vgui.Create("EditablePanel", sol)
     alt:Dock(BOTTOM)
     alt:SetTall(O(34))
     local ekle = K.Dugme(alt, "+ Actor", function()
          local yeni = {}
          for _, a in ipairs(DUNYA_ALANLARI) do yeni[a.k] = istable(a.v) and table.Copy(a.v) or a.v end
          yeni.id = "veren" .. (#liste + 1)
          yeni.ad = "Nueva misión veren"
          liste[#liste + 1] = yeni
          dunyaSecili = #liste
          G.DunyaPenceresiYenile(liste)
     end, "ana")
     ekle:Dock(LEFT)
     ekle:SetWide(O(110))
     local sil = K.Dugme(alt, "Sil", function()
          table.remove(liste, dunyaSecili)
          G.DunyaPenceresiYenile(liste)
     end, "tehlike")
     sil:Dock(RIGHT)
     sil:SetWide(O(70))

     local sag = K.Kaydir(p.govde)
     sag:Dock(FILL)
     sag:DockMargin(O(16), 0, 0, 0)
     local d = liste[dunyaSecili]
     if d then
          local form = K.Form(sag, DUNYA_ALANLARI, d, { def = { aktorler = {} }, model = d.model })
          form:DockMargin(0, 0, O(10), 0)
     else
          local l = K.Etiket(sag, "Misión verenler haritada sürekli duran figürlerdir; başlarında “!” belirir, E ile misión teklif ederler.", R.soluk, F(14, "italik"))
          l:Dock(TOP)
          l:SetWrap(true)
          l:SetTall(O(60))
     end

     local kaydet = K.Dugme(p, "Kaydet ve dünyaya uygula", function()
          G.EditorIste("dunya_kaydet", { dunya = liste })
          notification.AddLegacy("Dünya actorleri kaydedildi.", NOTIFY_GENERIC, 3)
     end, "ana")
     kaydet:SetSize(O(240), O(36))
     kaydet:SetPos(p:GetWide() - O(256), p:GetTall() - O(50))
     p.liste = liste
end

function G.DunyaPenceresiYenile(liste)
     E.dunya = liste
     G.DunyaPenceresi()
end

/*
*   Sinema rotası içe aktarma (Sinema Kamerası'nın kaydettiği rotalar, bu istemcide)
*/
function G.SinemaRotaSec(cb)
     local klasor = "sardon_sinema/rotalar/" .. string.lower(game.GetMap())
     local dosyalar = file.Find(klasor .. "/*.json", "DATA", "datedesc") or {}
     local ogeler = {}
     for _, d in ipairs(dosyalar) do
          local veri = util.JSONToTable(file.Read(klasor .. "/" .. d, "DATA") or "") or {}
          ogeler[#ogeler + 1] = { ad = string.StripExtension(d), alt = #(veri.anahtarlar or {}) .. " anahtar · " .. #(veri.aktorler or {}) .. " actor · " .. ((veri.ayar or {}).rotaSure or "?") .. " sn", deger = d }
     end
     if #ogeler == 0 then
          ogeler[1] = { ad = "(guardarlı rota yok)", alt = "Sinema Kamerası (F9) ile rota kurup kaydedin", deger = "" }
     end
     K.AramaListesi("Sinema rotası seç", ogeler, function(d)
          if d == "" then return end
          local veri = util.JSONToTable(file.Read(klasor .. "/" .. d, "DATA") or "")
          if not istable(veri) then return end
          cb({ ad = string.StripExtension(d), anahtarlar = veri.anahtarlar or {}, ayar = veri.ayar or {}, aktorler = veri.aktorler or {} })
     end)
end

/*
*   Shine Admin sayfası: editöre kısayol + özet
*/
local function ShineKaydet()
     if not ShineAdmin or not ShineAdmin.RegisterPage then return end
     ShineAdmin:RegisterPage("gorev", {
          label = "Misiónler", icon = "book", group = "systems", order = 40,
          title = "Misión Sistemi", subtitle = "Taller de misiones, yerler ve misión verenler",
          access = function(ply) return G.Editor(ply) end,
          build = function(ctx)
               local N = ShineAdmin.GetN and ShineAdmin.GetN()
               local panel = ctx.panel
               local u = N and N.u or function(x) return x end
               local function Dugme(m, y, f)
                    if N then
                         N.Button(panel, u(30), y, u(320), u(40), m, f, "primary")
                    else
                         local b = K.Dugme(panel, m, f, "ana")
                         b:SetPos(u(30), y)
                         b:SetSize(u(320), u(40))
                    end
               end
               Dugme("Taller de misionesni aç", u(30), function()
                    if IsValid(ShineAdmin.Frame) then ShineAdmin.Frame:Remove() end
                    G.EditorAc()
               end)
               Dugme("Yerler", u(84), function() G.EditorAc() timer.Simple(0.3, G.YerPenceresi) end)
               Dugme("Dünya actorleri", u(138), function() G.EditorAc() timer.Simple(0.3, G.DunyaPenceresi) end)
          end,
     })
end
ShineKaydet()
timer.Simple(5, ShineKaydet)
