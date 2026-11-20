-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_3cizim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: rün çizimi, havada 3B (Akran talimi gibi)
--   Okunmuş büyü bölümünde "<büyü> rününü çiz" → kitap gizlenir (okuma duruşu sürer), karakterin önünde
--   kameranın baktığı hizada bir rün düzlemi açılır. Büyünün yolu havada görünür: yeşil başlangıç halkası,
--   yol boyunca akan oklar, kat edilen kısım altına döner, çizerken sıradaki hedefte bir kıvılcım bekler.
--   Ekranın ortası asanın ucudur (ana kameranın ışını düzlemi kestiği yer; thirdperson'da da doğru).
--   Sol tık basılı tek hamle çizilir; bırakınca noktalar ([-1,1], y yukarı) SardonKitap.Cizim ile sunucuya
--   gider, puanı sunucu verir (Akran tanıyıcısı). Sağ tık / Esc kitaba döner. Çizerken yürüme, ateş ve
--   silah değiştirme kapalı, fare yavaşlar.
--   Denetim kipi (11-09): profesörün "Asa Hareketini Denetle"si de bu düzlemi kullanır (cl_4denetim çağırır):
--   kitap paneli yok, süre + barem var, tek geçerli hamle SardonKitap.DenetimIz paketleriyle gider.

-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_n8 = Vector(0, 0, -8)
local OPT_R_255_214_140_28 = Color(255, 214, 140, 28)
local OPT_R_200_180_120_18 = Color(200, 180, 120, 18)
local OPT_R_255_200_95_255 = Color(255, 200, 95, 255)
local OPT_R_255_200_110_120 = Color(255, 200, 110, 120)
local OPT_R_255_225_170_120 = Color(255, 225, 170, 120)
local OPT_R_255_240_200_255 = Color(255, 240, 200, 255)
local OPT_R_140_255_170_240 = Color(140, 255, 170, 240)
local OPT_R_140_255_170_220 = Color(140, 255, 170, 220)
local OPT_R_255_180_120_200 = Color(255, 180, 120, 200)
local SK = SardonKitap
local R = SK.R

local MESAFE = 120   -- düzlemin karakterin gözünden ileri uzaklığı (birim)
local ORAN = 0.28    -- rünün yarı boyu = kamera-düzlem uzaklığı × ORAN (ekranda hep aynı boy)
local AZAMI = 600    -- bir hamlede en çok nokta
local GONDER = 380   -- sunucuya giden en çok nokta (sunucu 400'e kadar okur)
local ARALIK = 1.6   -- iki gönderim arası en az süre (sunucu 1,5 sn'de bir kabul eder)
local SOLMA = 2.6    -- bitmiş çizimin havada solma süresi
local ILERI = 0.6    -- ilerleme takibinde yol boyunca ileri bakış (normalleştirilmiş uzunluk)
local TOLERANS = 0.24
local OK_ARALIK = 0.3

local M = {
     iz = Material("trails/laser"),
     isik = Material("sprites/light_glow02_add"),
     halka = Material("effects/select_ring"),
     dalga = Material("particle/particle_ring_wave_additive"),
     keskin = Material("particle/particle_ring_sharp"),
     parlak = Material("sprites/glow04_noz"),
}

SK.C3 = SK.C3 or {}
local C3 = SK.C3
C3.izler = C3.izler or {}

/*
*   ana kamera: RenderScene ana görüntü için karede bir kez gelir (ayna / RT kameraları bunu değiştirmez)
*/
local kamPos, kamAng, kamT = nil, nil, 0
hook.Add("RenderScene", "SardonKitap.Cizim3B", function(o, a)
     kamPos, kamAng, kamT = o, a, RealTime()
end)

local function Kamera()
     if kamPos and RealTime() - kamT < 0.25 then return kamPos, kamAng end
     local ply = LocalPlayer()
     return ply:EyePos(), ply:EyeAngles()
end

local fontOlcek
local function Fontlar()
     local o = math.Clamp(ScrH() / 1080, 0.72, 1.4)
     if fontOlcek == o then return end
     fontOlcek = o
     local function F(ad, yuz, boy, kalin)
          surface.CreateFont("sk.c3" .. ad, {font = yuz, size = math.max(16, math.Round(boy * o)), weight = kalin or 500, extended = true, antialias = true})
     end
     F("ust", "Montserrat SemiBold", 16, 600)
     F("baslik", "Playfair Display SemiBold", 30, 600)
     F("metin", "Montserrat Medium", 17, 500)
     F("alt", "Montserrat SemiBold", 17, 600)
end

/*
*   düzlem geometrisi
*/
local function Nokta(T, x, y)
     return T.merkez + T.sag * (x * T.olcek) + T.yuk * (y * T.olcek)
end

local function NisanNoktasi(T)
     local o, a = Kamera()
     local yon = a:Forward()
     local payda = yon:Dot(T.ileri)
     if payda < 0.15 then return nil end
     local t = (T.merkez - o):Dot(T.ileri) / payda
     if t <= 0 then return nil end
     local p = o + yon * t
     local d = p - T.merkez
     return d:Dot(T.sag) / T.olcek, d:Dot(T.yuk) / T.olcek, p
end

-- yol uzunluğunda s'ye ilk ulaşan nokta
local function Indeks(T, s)
     local kum = T.kum
     local lo, hi = 1, #kum
     while lo < hi do
          local orta = math.floor((lo + hi) / 2)
          if kum[orta] < s then lo = orta + 1 else hi = orta end
     end
     return lo
end

-- çizilen nokta yolu izliyorsa ilerleme öne kayar (yalnız ileri, ILERI kadar ötesine bakar)
local function Ilerlet(T, x, y)
     local ham, kum = T.sablon.ham, T.kum
     local bas = T.ilerleme
     local enI, enD = nil, TOLERANS * TOLERANS
     for j = bas, #ham do
          if kum[j] - kum[bas] > ILERI then break end
          local d = (ham[j].x - x) ^ 2 + (ham[j].y - y) ^ 2
          if d < enD then enI, enD = j, d end
     end
     if enI and enI > bas then T.ilerleme = enI end
end

/*
*   başlat / bitir
*/
function C3.Bitir(sessiz)
     local T = C3.T
     if not T then return end
     C3.T = nil
     if T.em then T.em:Finish() T.em = nil end
     local D = T.denetim
     if D and not D.gonderildi then
          D.gonderildi = true
          net.Start("SardonKitap.DenetimBitir")
          net.WriteUInt(D.id, 16)
          net.WriteBool(true)
          net.SendToServer()
     end
     local p = T.panel
     if IsValid(p) then
          p:SetVisible(true)
          p:MakePopup()
     end
     if not sessiz then surface.PlaySound("buttons/lightswitch2.wav") end
     local k = C3.bekleyenKart
     C3.bekleyenKart = nil
     if k then SK.Kart(k[1], k[2], k[3]) end
end

function SK.Cizim3BAcik() return C3.T ~= nil end
function SK.Cizim3BBitir(sessiz) return C3.Bitir(sessiz) end

-- denetim = {id, sure, barem, prof} → profesör denetimi kipi (panel nil)
function SK.Cizim3BBasla(panel, kitapId, bolumId, buyu, denetim)
     local ply = LocalPlayer()
     if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then return end
     local sab = SardonAkran and SardonAkran.Sablon and SardonAkran.Sablon(buyu)
     if not sab or not sab.ham or #sab.ham < 2 or not SardonAkran.Yakinlik then
          SK.Kart("Rün tanıma şu anda kullanılamıyor", "[sardon] akran yüklü değil.", "uyari")
          return
     end
     if C3.T then C3.Bitir(true) end

     local o, a = Kamera()
     local ang = Angle(math.Clamp(a.p, -25, 25), a.y, 0)
     local ileri = ang:Forward()
     local uzak = math.max(0, (ply:EyePos() - o):Dot(ileri)) + MESAFE

     -- yol uzunluğu (ilerleme, oklar, akan kıvılcım hep uzunluğa göre)
     local ham = sab.ham
     local kum = {0}
     for i = 2, #ham do
          kum[i] = kum[i - 1] + math.sqrt((ham[i].x - ham[i - 1].x) ^ 2 + (ham[i].y - ham[i - 1].y) ^ 2)
     end
     local oklar = {}
     local sonrakiOk = OK_ARALIK * 0.6
     for i = 2, #ham - 1 do
          if kum[i] >= sonrakiOk and kum[#ham] - kum[i] > 0.08 then
               local dx, dy = ham[i + 1].x - ham[i - 1].x, ham[i + 1].y - ham[i - 1].y
               local u = math.sqrt(dx * dx + dy * dy)
               if u > 1e-5 then
                    oklar[#oklar + 1] = {i = i, tx = dx / u, ty = dy / u}
                    sonrakiOk = kum[i] + OK_ARALIK
               end
          end
     end

     local ode
     local char = ply:GetCharacter()
     if not denetim and char and SK.KitapMaliyeti then ode = SK.KitapMaliyeti(char, buyu) end
     if denetim then
          denetim.bas = RealTime()
          denetim.bitis = RealTime() + (denetim.sure or 20)
     end

     C3.T = {
          kitap = kitapId, bolum = bolumId, buyu = buyu, sablon = sab, panel = panel,
          ileri = ileri, sag = ang:Right(), yuk = ang:Up(),
          merkez = o + ileri * uzak, olcek = uzak * ORAN,
          kum = kum, oklar = oklar, noktalar = {}, ilerleme = 1,
          acilis = RealTime(), serbest = false, ode = ode, denetim = denetim,
     }
     if IsValid(panel) then
          panel:SetVisible(false)
          panel:SetMouseInputEnabled(false)
          panel:SetKeyboardInputEnabled(false)
     end
     ply:EmitSound("ambient/levels/citadel/strange_talk" .. math.random(3, 9) .. ".wav", 75, 130, 0.5, CHAN_STATIC)
     return true
end

/*
*   gönderim ve sonuç
*/
local function Gonder(T, pts)
     local secilen = {}
     local adim = math.max(1, math.ceil(#pts / GONDER))
     for i = 1, #pts, adim do secilen[#secilen + 1] = pts[i] end
     if secilen[#secilen] ~= pts[#pts] then secilen[#secilen + 1] = pts[#pts] end
     while #secilen > GONDER do table.remove(secilen, #secilen - 1) end

     net.Start("SardonKitap.Cizim")
     net.WriteString(T.kitap)
     net.WriteString(T.bolum)
     net.WriteUInt(#secilen, 10)
     for _, p in ipairs(secilen) do
          net.WriteInt(math.Clamp(math.Round(p.x * 1000), -32000, 32000), 16)
          net.WriteInt(math.Clamp(math.Round(p.y * 1000), -32000, 32000), 16)
     end
     net.SendToServer()
     C3.sonGonderim = RealTime()
     T.bekliyorT = RealTime() + 6
end

-- denetim: tek geçerli hamle, 40'lık paketlerle (sunucu 0,05 sn'de bir paket kabul eder), sonra DenetimBitir
local function DenetimGonder(T, pts)
     local D = T.denetim
     D.gonderildi = true
     T.bekleyen = {pts = pts}
     T.bekliyorT = RealTime() + 12
     local sec = {}
     local adim = math.max(1, math.ceil(#pts / 380))
     for i = 1, #pts, adim do sec[#sec + 1] = pts[i] end
     if sec[#sec] ~= pts[#pts] then sec[#sec + 1] = pts[#pts] end
     local merkez, sag, yuk, gonderilen = T.merkez, T.sag, T.yuk, 0
     local function Paket()
          local k = math.min(40, #sec - gonderilen)
          if k > 0 then
               net.Start("SardonKitap.DenetimIz")
               net.WriteUInt(D.id, 16)
               net.WriteVector(merkez)
               net.WriteNormal(sag)
               net.WriteNormal(yuk)
               net.WriteUInt(k, 6)
               for i = gonderilen + 1, gonderilen + k do
                    net.WriteInt(math.Clamp(math.Round(sec[i].x * 1000), -2000, 2000), 16)
                    net.WriteInt(math.Clamp(math.Round(sec[i].y * 1000), -2000, 2000), 16)
               end
               net.SendToServer()
               gonderilen = gonderilen + k
          end
          if gonderilen < #sec then
               timer.Simple(0.08, Paket)
          else
               timer.Simple(0.08, function()
                    net.Start("SardonKitap.DenetimBitir")
                    net.WriteUInt(D.id, 16)
                    net.WriteBool(false)
                    net.SendToServer()
               end)
          end
     end
     Paket()
end

local function HamleBitti(T)
     T.ciziyor = false
     local pts = T.noktalar
     T.noktalar = {}
     T.ilerleme = 1
     if #pts < 8 or SardonAkran.Uzunluk(pts) < 0.5 then
          T.mesaj = {"Çok kısa: rünü tek ve kesintisiz bir hareketle sonuna kadar çiz.", false}
          surface.PlaySound("buttons/button10.wav")
          return
     end
     if T.denetim then return DenetimGonder(T, pts) end
     T.bekleyen = {pts = pts}
     local kalan = (C3.sonGonderim or -10) + ARALIK - RealTime()
     if kalan > 0 then
          T.bekliyorT = RealTime() + kalan + 6
          timer.Simple(kalan, function()
               if C3.T == T and T.bekleyen and T.bekleyen.pts == pts then Gonder(T, pts) end
          end)
     else
          Gonder(T, pts)
     end
end

local function Parlat(T, pts, ok)
     if #pts == 0 then return end
     local em = ParticleEmitter(Nokta(T, pts[1].x, pts[1].y), false)
     if not em then return end
     local k = T.olcek / 34
     local adim = math.max(1, math.floor(#pts / (ok and 50 or 18)))
     for i = 1, #pts, adim do
          local p = em:Add(ok and "sprites/light_glow02_add" or "particle/smokesprites_0001", Nokta(T, pts[i].x, pts[i].y))
          if p then
               p:SetVelocity(VectorRand() * (ok and 26 or 8) * k)
               p:SetGravity(Vector(0, 0, ok and 20 or -30))
               p:SetDieTime(math.Rand(0.7, 1.6))
               p:SetStartAlpha(ok and 255 or 120)
               p:SetEndAlpha(0)
               p:SetStartSize((ok and math.Rand(1.5, 3.5) or math.Rand(3, 5)) * k)
               p:SetEndSize(ok and 0 or math.Rand(8, 12) * k)
               p:SetRoll(math.Rand(0, 360))
               if ok then p:SetColor(255, 220, 150) else p:SetColor(120, 110, 100) end
               p:SetAirResistance(40)
          end
     end
     em:Finish()
end

-- cl_2kitap'ın CizimSonuc alıcısı çağırır; kip açıksa true döner (kartı kip kapanınca gösterir)
function SK.Cizim3BSonuc(ok, skor, metin)
     local T = C3.T
     if not T then return false end
     T.bekliyorT = nil
     local pts = T.bekleyen and T.bekleyen.pts
     T.bekleyen = nil

     local kalite, renk = "", ok and Color(150, 220, 140) or Color(235, 140, 120)
     if skor > 0 and SardonAkran and SardonAkran.Kalite and SardonAkran.Ayar then kalite, renk = SardonAkran.Kalite(skor) end
     T.sonuc = {ok = ok, skor = skor, metin = metin, kalite = kalite, renk = renk, t = RealTime()}
     T.mesaj = nil

     if pts then
          C3.izler[#C3.izler + 1] = {T = T, pts = pts, ok = ok, bas = RealTime()}
          while #C3.izler > 6 do table.remove(C3.izler, 1) end
          Parlat(T, pts, ok)
     end
     local ply = LocalPlayer()
     if ok then
          ply:EmitSound("ambient/energy/whiteflash.wav", 70, 160, 0.35, CHAN_STATIC)
          surface.PlaySound("buttons/blip1.wav")
          T.kapanis = RealTime() + 2.4
          C3.bekleyenKart = {"Büyü öğrenildi", metin, "iyi"}
     else
          ply:EmitSound("ambient/fire/ignite.wav", 60, 120, 0.3, CHAN_STATIC)
          surface.PlaySound("buttons/button10.wav")
     end
     return true
end

-- cl_4denetim'in DenetimSonuc alıcısı çağırır; denetim kipi açıksa true döner (kart kip kapanınca)
function SK.Cizim3BDenetimSonuc(id, skor, basari, metin)
     local T = C3.T
     if not T or not T.denetim or T.denetim.id ~= id then return false end
     T.bekliyorT = nil
     local pts = T.bekleyen and T.bekleyen.pts
     T.bekleyen = nil
     local kalite, renk = "", basari and Color(150, 220, 140) or Color(235, 140, 120)
     if skor > 0 and SardonAkran and SardonAkran.Kalite and SardonAkran.Ayar then kalite, renk = SardonAkran.Kalite(skor) end
     T.sonuc = {ok = basari, skor = skor, metin = metin, kalite = kalite, renk = renk, t = RealTime()}
     T.mesaj = nil
     if pts then
          C3.izler[#C3.izler + 1] = {T = T, pts = pts, ok = basari, bas = RealTime()}
          while #C3.izler > 6 do table.remove(C3.izler, 1) end
          Parlat(T, pts, basari)
     end
     local ply = LocalPlayer()
     if basari then
          ply:EmitSound("ambient/energy/whiteflash.wav", 70, 160, 0.35, CHAN_STATIC)
          surface.PlaySound("buttons/blip1.wav")
     else
          ply:EmitSound("ambient/fire/ignite.wav", 60, 120, 0.3, CHAN_STATIC)
          surface.PlaySound("buttons/button10.wav")
     end
     T.kapanis = RealTime() + 3
     C3.bekleyenKart = {basari and "Denetim: başarılı" or "Denetim: başarısız", "%" .. math.floor(skor * 100) .. " · " .. metin, basari and "iyi" or "uyari"}
     return true
end

/*
*   giriş
*/
hook.Add("Think", "SardonKitap.Cizim3B", function()
     local T = C3.T
     if not T then return end
     local ply = LocalPlayer()
     -- kitap başka yoldan kapandı (başka kitap, denetim, eşya gitti): gösterilecek kitap yok
     if not T.denetim and not IsValid(T.panel) then
          if T.em then T.em:Finish() end
          C3.T = nil
          local k = C3.bekleyenKart
          C3.bekleyenKart = nil
          if k then SK.Kart(k[1], k[2], k[3]) end
          return
     end
     if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then return C3.Bitir(true) end
     if T.kapanis then
          if RealTime() > T.kapanis then C3.Bitir(true) end
          return
     end

     -- düğmeye basan tık bırakılmadan çizim başlamasın
     if not T.serbest then
          if not input.IsMouseDown(MOUSE_LEFT) then T.serbest = true end
          return
     end
     local imlec = vgui.CursorVisible() or gui.IsGameUIVisible()
     if input.IsMouseDown(MOUSE_RIGHT) and not imlec then return C3.Bitir() end

     local D = T.denetim
     if D then
          if D.gonderildi then
               -- sonuç gelmezse (sunucu kendi süresinde yine sonuç yollar) kip kapanır
               if T.bekliyorT and RealTime() > T.bekliyorT then return C3.Bitir(true) end
               return
          end
          if RealTime() > D.bitis then
               if T.ciziyor and #T.noktalar >= 8 then return HamleBitti(T) end
               T.ciziyor = false
               D.gonderildi = true
               T.bekleyen = {pts = {}}
               T.bekliyorT = RealTime() + 8
               net.Start("SardonKitap.DenetimBitir")
               net.WriteUInt(D.id, 16)
               net.WriteBool(false)
               net.SendToServer()
               return
          end
     end

     if T.bekliyorT and RealTime() > T.bekliyorT then
          T.bekliyorT, T.bekleyen = nil, nil
          T.mesaj = {"Sunucu cevap vermedi; rünü yeniden çiz.", false}
     end

     local basili = input.IsMouseDown(MOUSE_LEFT) and not imlec and not T.bekleyen
     if basili then
          local x, y, nokta = NisanNoktasi(T)
          if x then
               x, y = math.Clamp(x, -2.5, 2.5), math.Clamp(y, -2.5, 2.5)
               if not T.ciziyor then
                    T.ciziyor = true
                    T.noktalar = {}
                    T.ilerleme = 1
                    T.sonuc, T.mesaj = nil, nil
                    local b = T.sablon.ham[1]
                    T.uzakBasladi = (x - b.x) ^ 2 + (y - b.y) ^ 2 > 0.3 * 0.3
                    ply:EmitSound("weapons/physcannon/energy_sing_flyby1.wav", 60, 180, 0.2, CHAN_STATIC)
               end
               local son = T.noktalar[#T.noktalar]
               if not son or (son.x - x) ^ 2 + (son.y - y) ^ 2 > 0.0003 then
                    T.noktalar[#T.noktalar + 1] = {x = x, y = y, yakin = SardonAkran.Yakinlik(T.sablon.ham, x, y, 0.28)}
                    Ilerlet(T, x, y)
                    if math.random() < 0.5 then
                         T.em = T.em or ParticleEmitter(nokta, false)
                         local pr = T.em and T.em:Add("sprites/light_glow02_add", nokta)
                         if pr then
                              local k = T.olcek / 34
                              pr:SetVelocity(VectorRand() * 6 * k + OPT_V_0_0_n8)
                              pr:SetDieTime(math.Rand(0.4, 0.9))
                              pr:SetStartAlpha(255)
                              pr:SetEndAlpha(0)
                              pr:SetStartSize(math.Rand(0.8, 1.8) * k)
                              pr:SetEndSize(0)
                              pr:SetColor(255, 220, 150)
                              pr:SetGravity(Vector(0, 0, -30))
                         end
                    end
               end
               if #T.noktalar >= AZAMI then HamleBitti(T) end
          end
     elseif T.ciziyor then
          HamleBitti(T)
     end
end)

hook.Add("CreateMove", "SardonKitap.Cizim3B", function(cmd)
     if not C3.T then return end
     cmd:ClearMovement()
     cmd:RemoveKey(IN_ATTACK)
     cmd:RemoveKey(IN_ATTACK2)
     cmd:RemoveKey(IN_JUMP)
     cmd:RemoveKey(IN_DUCK)
     cmd:RemoveKey(IN_RELOAD)
     cmd:RemoveKey(IN_USE)
     cmd:RemoveKey(IN_SPEED)
end)

hook.Add("AdjustMouseSensitivity", "SardonKitap.Cizim3B", function()
     if C3.T and not C3.T.kapanis then return 0.6 end
end)

hook.Add("PlayerBindPress", "SardonKitap.Cizim3B", function(_, bind)
     if not C3.T then return end
     if string.find(bind, "attack", 1, true) or string.find(bind, "invnext", 1, true) or string.find(bind, "invprev", 1, true) or string.find(bind, "slot", 1, true) then return true end
end)

hook.Add("HUDShouldDraw", "SardonKitap.Cizim3B", function(ad)
     if C3.T and ad == "CHudCrosshair" then return false end
end)

/*
*   3B çizim
*/
local function KendiCiz(T)
     local now = RealTime()
     local ham = T.sablon.ham
     local n = #ham
     local kum = T.kum
     local L = kum[n]
     local O = T.olcek
     local k = O / 34
     local normal = -T.ileri
     local ac = math.Clamp((now - T.acilis) / 0.6, 0, 1)
     local ilr = T.ciziyor and T.ilerleme or 1
     local gorunen = math.max(2, math.floor(n * ac))

     cam.IgnoreZ(true)

     -- arka plan: dönen rün çemberleri + yayılan dalga
     render.SetMaterial(M.halka)
     render.DrawQuadEasy(T.merkez + T.ileri * 2, normal, O * 3.1 * ac, O * 3.1 * ac, OPT_R_255_214_140_28, now * 10 % 360)
     render.DrawQuadEasy(T.merkez + T.ileri * 2.5, normal, O * 2.6 * ac, O * 2.6 * ac, OPT_R_200_180_120_18, -now * 14 % 360)
     render.SetMaterial(M.dalga)
     local dg = (now * 0.5) % 1
     render.DrawQuadEasy(T.merkez + T.ileri * 3, normal, O * 3.2 * dg, O * 3.2 * dg, Color(255, 220, 160, 30 * (1 - dg)), 0)

     -- kat edilen yol: altın, kalın
     if ilr >= 2 then
          render.SetMaterial(M.iz)
          render.StartBeam(ilr)
          for i = 1, ilr do
               render.AddBeam(Nokta(T, ham[i].x, ham[i].y), 6 * k, i / ilr * 3, OPT_R_255_200_95_255)
          end
          render.EndBeam()
          render.SetMaterial(M.isik)
          for i = 1, ilr, 3 do
               render.DrawSprite(Nokta(T, ham[i].x, ham[i].y), 9 * k, 9 * k, OPT_R_255_200_110_120)
          end
     end

     -- kalan yol: ince kılavuz + nabız atan noktalar (açılışta sırayla belirir)
     if gorunen - ilr + 1 >= 2 then
          render.SetMaterial(M.iz)
          render.StartBeam(gorunen - ilr + 1)
          for i = ilr, gorunen do
               render.AddBeam(Nokta(T, ham[i].x, ham[i].y), 3 * k, i / n * 4, OPT_R_255_225_170_120)
          end
          render.EndBeam()
     end
     render.SetMaterial(M.isik)
     for i = ilr, gorunen, 2 do
          local nab = 0.6 + 0.4 * math.sin(now * 3 - i * 0.15)
          render.DrawSprite(Nokta(T, ham[i].x, ham[i].y), 7 * k, 7 * k, Color(255, 225, 170, 170 * nab))
     end

     -- yön okları: kalan yolda, öne doğru akan parıltıyla
     render.SetMaterial(M.iz)
     local a = 0.12
     for _, ok in ipairs(T.oklar) do
          if ok.i > ilr and ok.i <= gorunen then
               local p = ham[ok.i]
               local dalga = math.max(0, math.sin(now * 5 - kum[ok.i] * 7))
               local renk = Color(255, 236, 190, 90 + 165 * dalga)
               local uc = Nokta(T, p.x + ok.tx * a * 0.6, p.y + ok.ty * a * 0.6)
               local kx, ky = p.x - ok.tx * a * 0.5, p.y - ok.ty * a * 0.5
               render.DrawBeam(Nokta(T, kx - ok.ty * a * 0.7, ky + ok.tx * a * 0.7), uc, 3.2 * k, 0, 1, renk)
               render.DrawBeam(Nokta(T, kx + ok.ty * a * 0.7, ky - ok.tx * a * 0.7), uc, 3.2 * k, 0, 1, renk)
          end
     end

     render.SetMaterial(M.isik)
     if T.ciziyor then
          -- sıradaki hedef: kaldığın yerin biraz ötesinde bekleyen kıvılcım
          if L - kum[ilr] > 0.05 then
               local hi = Indeks(T, math.min(L, kum[ilr] + 0.3))
               local nab = 0.75 + 0.25 * math.sin(now * 9)
               render.DrawSprite(Nokta(T, ham[hi].x, ham[hi].y), 24 * k * nab, 24 * k * nab, OPT_R_255_240_200_255)
               render.SetMaterial(M.parlak)
               render.DrawSprite(Nokta(T, ham[hi].x, ham[hi].y), 5 * k, 5 * k, color_white)
               render.SetMaterial(M.isik)
               for q = 1, 4 do
                    local qi = Indeks(T, kum[ilr] + (kum[hi] - kum[ilr]) * q / 5)
                    render.DrawSprite(Nokta(T, ham[qi].x, ham[qi].y), 9 * k, 9 * k, Color(255, 230, 180, 100 + q * 30))
               end
          end
     elseif not T.bekleyen then
          -- yolun başından sonuna akan kuyruklu kıvılcım (sonda kısa bekler)
          local s = math.min(L, (now * 1.15) % (L + 0.5))
          local bi = Indeks(T, s)
          for q = 0, 9 do
               local p = ham[math.max(1, bi - q * 2)]
               render.DrawSprite(Nokta(T, p.x, p.y), (20 - q * 1.4) * k, (20 - q * 1.4) * k, Color(255, 235, 190, 255 * (1 - q / 10)))
          end
     end

     -- başlangıç halkası (çizerken söner), bitiş işareti
     local b, s = ham[1], ham[n]
     if not T.ciziyor then
          render.SetMaterial(M.keskin)
          local nab = 1 + math.sin(now * 5) * 0.15
          render.DrawQuadEasy(Nokta(T, b.x, b.y), normal, 13 * k * nab, 13 * k * nab, OPT_R_140_255_170_240, 0)
          render.SetMaterial(M.isik)
          render.DrawSprite(Nokta(T, b.x, b.y), 17 * k, 17 * k, OPT_R_140_255_170_220)
     end
     render.SetMaterial(M.keskin)
     render.DrawQuadEasy(Nokta(T, s.x, s.y), normal, 8 * k, 8 * k, OPT_R_255_180_120_200, 0)
     render.SetMaterial(M.isik)
     render.DrawSprite(Nokta(T, s.x, s.y), 10 * k, 10 * k, OPT_R_255_180_120_200)

     -- oyuncunun izi: yola yakın kısımlar altın, uzak kısımlar kızıl; sonuç beklerken nabız atar
     local pts = T.ciziyor and T.noktalar or (T.bekleyen and T.bekleyen.pts)
     if pts and #pts >= 2 then
          render.SetMaterial(M.iz)
          render.StartBeam(#pts)
          for i, p in ipairs(pts) do
               local renk
               if T.ciziyor then
                    local f = p.yakin or 1
                    renk = Color(220 + 35 * f, 90 + 130 * f, 70 + 80 * f, 255)
               else
                    renk = Color(255, 226, 150, 160 + 60 * math.sin(now * 8))
               end
               render.AddBeam(Nokta(T, p.x, p.y), 4.2 * k, i / #pts * 4 - now, renk)
          end
          render.EndBeam()
     end

     -- asanın ucu (ekran ortası)
     if not T.kapanis then
          local _, _, nokta = NisanNoktasi(T)
          if nokta then
               render.SetMaterial(M.isik)
               local r = (T.ciziyor and 12 or 8) * k
               render.DrawSprite(nokta, r, r, T.ciziyor and Color(255, 230, 170) or Color(200, 220, 255, 180))
               render.SetMaterial(M.parlak)
               render.DrawSprite(nokta, r * 0.4, r * 0.4, color_white)
          end
     end

     cam.IgnoreZ(false)
end

local function IzleriCiz()
     local now = RealTime()
     cam.IgnoreZ(true)
     for i = #C3.izler, 1, -1 do
          local d = C3.izler[i]
          local t = (now - d.bas) / SOLMA
          if t >= 1 then
               table.remove(C3.izler, i)
          elseif #d.pts >= 2 then
               local T = d.T
               local k = T.olcek / 34
               local a = d.ok and (1 - t) ^ 0.6 or (1 - t) ^ 2
               local renk = d.ok and Color(255, 214, 140, 255 * a) or Color(220, 110, 90, 200 * a)
               render.SetMaterial(M.iz)
               render.StartBeam(#d.pts)
               for j, p in ipairs(d.pts) do
                    render.AddBeam(Nokta(T, p.x, p.y), (d.ok and 5.5 or 4) * k, j / #d.pts * 3, renk)
               end
               render.EndBeam()
               if d.ok and t < 0.35 then
                    local f = t / 0.35
                    local boy = T.olcek * (1.2 + f * 4)
                    render.SetMaterial(M.dalga)
                    render.DrawQuadEasy(T.merkez, -T.ileri, boy, boy, Color(255, 220, 160, 200 * (1 - f)), 0)
               end
          end
     end
     cam.IgnoreZ(false)
end

hook.Add("PostDrawTranslucentRenderables", "SardonKitap.Cizim3B", function(derinlik, gok)
     if derinlik or gok then return end
     local T = C3.T
     if T and (T.denetim or IsValid(T.panel)) then KendiCiz(T) end
     if #C3.izler > 0 then IzleriCiz() end
end)

/*
*   ekran
*/
hook.Add("HUDPaint", "SardonKitap.Cizim3B", function()
     local T = C3.T
     if not T then return end
     SK.Fontlar()
     Fontlar()

     local W = SK.S(660)
     local x, y = math.floor(ScrW() / 2 - W / 2), SK.S(96) -- üstte oyunun pusulası var
     local pad = SK.S(20)
     local tarif = SK.Sar(T.sablon.tarif or "", "c3metin", W - pad * 2)
     local nT = math.min(#tarif, 3)
     local lh = SK.S(22)
     local H = SK.S(84) + nT * lh + SK.S(34)

     SK.Kutu(x, y, W, H, R.hud)
     SK.Kutu(x, y, SK.S(4), H, R.altin)
     surface.SetDrawColor(R.hudCizgi)
     surface.DrawOutlinedRect(x, y, W, H, 1)
     local D = T.denetim
     if D then
          SK.Yazi("ASA HAREKETİ DENETİMİ  ·  " .. SK.Buyuk(D.prof or ""), "c3ust", x + pad, y + SK.S(12), R.altinA)
          local kalan = math.max(0, D.bitis - RealTime())
          if not D.gonderildi then
               SK.Yazi(math.ceil(kalan) .. " sn  ·  barem %" .. (D.barem or 60), "c3ust", x + W - pad, y + SK.S(12), kalan < 5 and Color(235, 150, 125) or R.hudSoluk, TEXT_ALIGN_RIGHT)
          end
     else
          SK.Yazi("KİTAPTAN ÖĞREN  ·  RÜNÜ HAVADA ÇİZ", "c3ust", x + pad, y + SK.S(12), R.altinA)
     end
     if T.ode then SK.Yazi("Bedel: " .. T.ode .. " Büyü Puanı", "c3ust", x + W - pad, y + SK.S(12), R.hudSoluk, TEXT_ALIGN_RIGHT) end
     SK.Yazi(T.buyu, "c3baslik", x + pad, y + SK.S(34), R.hudYazi)
     for i = 1, nT do
          SK.Yazi(tarif[i], "c3metin", x + pad, y + SK.S(78) + (i - 1) * lh, R.hudSoluk)
     end

     -- alt çubuk: çizerken yolun ne kadarı, sonra puan (eşik çizgisiyle)
     local by = y + H - SK.S(22)
     local bx, bw = x + pad, W - pad * 2 - SK.S(200)
     local sagX = x + W - pad
     SK.Kutu(bx, by, bw, SK.S(6), Color(255, 255, 255, 25))
     local esik = D and (D.barem or 60) / 100 or SK.RunEsik()
     local s = T.sonuc
     if T.ciziyor then
          local f = T.kum[T.ilerleme] / math.max(1e-4, T.kum[#T.kum])
          SK.Kutu(bx, by, bw * f, SK.S(6), R.altinA)
          SK.Isik(bx + bw * f, by + SK.S(3), SK.S(10), R.altinA, 200)
          SK.Yazi("Yol  %" .. math.floor(f * 100), "c3alt", sagX, by + SK.S(3), R.altinA, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     else
          SK.Kutu(bx + bw * esik, by - SK.S(3), 1, SK.S(12), Color(238, 228, 206, 160))
          if T.bekleyen then
               SK.Yazi("Değerlendiriliyor…", "c3alt", sagX, by + SK.S(3), R.hudSoluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          elseif s and s.skor > 0 then
               local anim = math.Clamp((RealTime() - s.t) / 0.5, 0, 1)
               local f = s.skor * (1 - (1 - anim) ^ 3)
               SK.Kutu(bx, by, bw * f, SK.S(6), s.renk)
               SK.Isik(bx + bw * f, by + SK.S(3), SK.S(10), s.renk, 220)
               SK.Yazi((s.kalite ~= "" and (s.kalite .. "  ") or "") .. "%" .. math.floor(s.skor * 100), "c3alt", sagX, by + SK.S(3), s.renk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          else
               SK.Yazi("eşik %" .. math.floor(esik * 100 + 0.5), "c3alt", sagX, by + SK.S(3), R.hudSoluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end
     end

     -- sonuç / uyarı satırı (kartın altında)
     local metin, renk
     if s and s.metin and s.metin ~= "" then
          metin, renk = s.metin, s.ok and Color(150, 220, 140) or Color(235, 150, 125)
     elseif T.mesaj then
          metin, renk = T.mesaj[1], Color(235, 150, 125)
     elseif T.ciziyor and T.uzakBasladi then
          metin, renk = "Yeşil halkadan başlamadın: yol, başlangıçtan izlersen altına döner.", Color(230, 180, 110)
     end
     if metin then
          local satir = SK.Sar(metin, "c3metin", W - pad * 2)
          local mh = SK.S(16) + math.min(#satir, 3) * lh
          local my = y + H + SK.S(8)
          SK.Kutu(x, my, W, mh, R.hud)
          SK.Kutu(x, my, SK.S(4), mh, renk)
          for i = 1, math.min(#satir, 3) do
               SK.Yazi(satir[i], "c3metin", x + pad, my + SK.S(8) + (i - 1) * lh, renk)
          end
     end

     -- alt ipucu
     local ipucu
     if D then
          if T.kapanis then
               ipucu = s and s.ok and "Denetim başarılı" or "Denetim bitti"
          elseif D.gonderildi then
               ipucu = "Profesör çizimini değerlendiriyor…"
          elseif not T.serbest then
               ipucu = "Fareyi bırak, sonra çizmeye başla"
          else
               ipucu = "Sol tık basılı tut: tek hamlede çiz   ·   yeşil halkadan başla, okları izle   ·   sağ tık / Esc: vazgeç"
          end
     elseif T.kapanis then
          ipucu = "Büyü öğrenildi! Kitabına dönülüyor…"
     elseif not T.serbest then
          ipucu = "Fareyi bırak, sonra çizmeye başla"
     else
          ipucu = "Sol tık basılı tut: çiz   ·   yeşil halkadan başla, okları izle   ·   sağ tık / Esc: kitaba dön"
     end
     local iw = SK.Olc(ipucu, "c3alt") + SK.S(40)
     local iy = ScrH() - SK.S(222)
     SK.Kutu(ScrW() / 2 - iw / 2, iy, iw, SK.S(38), Color(R.hud.r, R.hud.g, R.hud.b, 215))
     surface.SetDrawColor(R.hudCizgi)
     surface.DrawOutlinedRect(ScrW() / 2 - iw / 2, iy, iw, SK.S(38), 1)
     SK.Yazi(ipucu, "c3alt", ScrW() / 2, iy + SK.S(19), T.kapanis and R.altinA or R.hudYazi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
