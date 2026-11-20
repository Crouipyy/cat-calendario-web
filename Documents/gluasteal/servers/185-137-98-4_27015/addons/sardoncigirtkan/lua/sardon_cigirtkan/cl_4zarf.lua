-- "addons\\sardoncigirtkan\\lua\\sardon_cigirtkan\\cl_4zarf.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Çığırtkan :: istemci — dünyadaki zarf.
--
-- sardon_cigirtkan varlığı yalnızca durumu taşır; çizim, ses ve efektler buradadır (ZF.*), böylece bu
-- dosya canlıda düzenlenince varlıklar da yeni davranışı alır.
--   DUSUS  baykuşun bıraktığı zarf alıcının önüne süzülür
--   BEKLE  dikey zarf titrer, köşelerinden duman tüter (süre doldukça artar); alıcıda "[E] Aç"
--   CAL    zarf döner, kapağı üst dudak olur; ağız 3B sesin seviyesiyle açılıp kapanır, bağırırken
--          alıcının üstüne atılır, kıvılcım saçar. Açılmadan patladıysa alev patlamasıyla başlar.
--   SOR    alıcıda "[E] Bir kez daha"
--   YOK    zarf parçalara yırtılır, parçalar havada yanıp kül olur
-- Toplu çığırtkanın küme zarfı daha büyüktür, kümenin üstünde süzülür, bağırırken üyelere sırayla döner;
-- istem / sarsıntı kümedeki her alıcıda çıkar.
-- Ayrıca: baykuşun pençesindeki zarf, kayıt yapan oyuncunun elindeki zarf.
-- YAZILI ÇIĞIRTKAN (sistem tebligatı): ses yok; CAL'de belge vuruş vuruş "yazılır" (C.DaktiloBelge zaman
-- çizelgesi), her vuruşta zarf ağzını şaklatır, daktilo sesleri zarftan 3B çalar. Alıcının ekranının
-- üst yarısında daktilo ve kâğıt (DaktiloEkran); çevredekiler zarfın üstünde son satırları görür (ZF.DaktiloSerit).
-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_K = {
     V_0_0_25 = Vector(0, 0, 25),
     V_0_0_18 = Vector(0, 0, 18),
     V_0_0_46 = Vector(0, 0, 46),
}
local C = SardonCigirtkan
local R = C.Renk
local A = C.Ayar
local Z = C.Z
local O = C.O

C.Zarf = C.Zarf or {}
local ZF = C.Zarf
ZF.aktif = ZF.aktif or {}
ZF.parcalar = ZF.parcalar or {}

local MAT_PARILTI = Material("sprites/light_glow02_add")
local MAT_GRAD = {u = Material("vgui/gradient-u"), d = Material("vgui/gradient-d"), l = Material("vgui/gradient-l"), r = Material("vgui/gradient-r")}

local function Hedef(e)
     local h = e:GetHedef()
     return IsValid(h) and h or nil
end

local function Grup(e)
     return e:GetNW2Bool("SardonCigirtkanGrup", false)
end

-- Küme zarfının alıcıları: {ent index}, {[ent index] = true}
local function Uyeler(e)
     local s = e:GetNW2String("SardonCigirtkanAlicilar", "")
     if e.uyeS ~= s then
          e.uyeS = s
          local t, set = {}, {}
          for n in string.gmatch(s, "%d+") do
               local i = tonumber(n)
               t[#t + 1] = i
               set[i] = true
          end
          e.uyeT, e.uyeSet = t, set
     end
     return e.uyeT or {}, e.uyeSet or {}
end

-- ply bu zarfın alıcısı mı
local function Alici(e, ply)
     if not IsValid(ply) then return false end
     if Grup(e) then
          local _, set = Uyeler(e)
          return set[ply:EntIndex()] == true
     end
     return Hedef(e) == ply
end
ZF.Alici = Alici

local function Yazili(e)
     return e:GetNW2Bool("SardonCigirtkanYazili", false)
end
ZF.Yazili = Yazili

-- Küme zarfı kime bakar: bağırırken üyeler arasında 2,4 sn'de bir döner, yoksa en yakın üye
local function GrupBakilan(e, pos, d, t)
     local adaylar = {}
     local r2 = (A.KumeYaricap * 1.6) ^ 2
     for _, i in ipairs((Uyeler(e))) do
          local p = Entity(i)
          if IsValid(p) and p:IsPlayer() and p:GetPos():DistToSqr(pos) < r2 then adaylar[#adaylar + 1] = p end
     end
     if #adaylar == 0 then return nil end
     if d == Z.CAL then
          return adaylar[math.floor(math.max(0, t - e:GetBasla()) / 2.4) % #adaylar + 1]
     end
     local en, enD
     for _, p in ipairs(adaylar) do
          local dd = p:GetPos():DistToSqr(pos)
          if not enD or dd < enD then en, enD = p, dd end
     end
     return en
end

function ZF.Ekle(e)
     ZF.aktif[e] = true
end

function ZF.Kaldir(e)
     ZF.aktif[e] = nil
     local v = C.veri[e:GetKimlik()]
     if v and v.k3 and v.k3:IsValid() then v.k3:Pause() end
     if e.yayici and e.yayici:IsValid() then e.yayici:Finish() end
     e.yayici = nil
end

local function Yayici(e, pos)
     if not (e.yayici and e.yayici:IsValid()) then e.yayici = ParticleEmitter(pos) end
     e.yayici:SetPos(pos)
     return e.yayici
end

----------------------------------------------------------------------------------------
-- Parçacık tarifleri (stok HL2 dokuları)
----------------------------------------------------------------------------------------
local function Duman(em, pos, koyu, boy)
     local p = em:Add("particle/smokesprites_000" .. math.random(1, 9), pos)
     if not p then return end
     p:SetVelocity(Vector(0, 0, math.Rand(6, 14)) + VectorRand() * 3)
     p:SetDieTime(math.Rand(1.2, 2.2))
     p:SetStartAlpha(koyu and 110 or 60)
     p:SetEndAlpha(0)
     p:SetStartSize(boy or 1.2)
     p:SetEndSize((boy or 1.2) * 4.5)
     local g = koyu and 30 or 70
     p:SetColor(g, g * 0.9, g * 0.9)
     p:SetRoll(math.Rand(0, 360))
     p:SetRollDelta(math.Rand(-0.6, 0.6))
     p:SetAirResistance(25)
     p:SetGravity(Vector(0, 0, 8))
end

local function Kor(em, pos, hiz, boy)
     local p = em:Add("sprites/light_glow02_add", pos)
     if not p then return end
     p:SetVelocity(hiz or (VectorRand() * 30 + OPT_K.V_0_0_25))
     p:SetDieTime(math.Rand(0.4, 0.9))
     p:SetStartAlpha(255)
     p:SetEndAlpha(0)
     p:SetStartSize(boy or math.Rand(0.8, 1.6))
     p:SetEndSize(0)
     p:SetColor(255, math.random(90, 160), 40)
     p:SetGravity(Vector(0, 0, -60))
     p:SetAirResistance(40)
end

local function Alev(em, pos, boy)
     local p = em:Add("effects/fire_cloud" .. math.random(1, 2), pos)
     if not p then return end
     p:SetVelocity(VectorRand() * 40 + Vector(0, 0, 30))
     p:SetDieTime(math.Rand(0.35, 0.6))
     p:SetStartAlpha(230)
     p:SetEndAlpha(0)
     p:SetStartSize(boy or math.Rand(3, 6))
     p:SetEndSize((boy or 5) * 2.6)
     p:SetRoll(math.Rand(0, 360))
     p:SetRollDelta(math.Rand(-2, 2))
     p:SetColor(255, 200, 160)
     p:SetAirResistance(60)
end

local function Kivilcim(em, pos, yon)
     local p = em:Add("effects/spark", pos)
     if not p then return end
     p:SetVelocity(yon * math.Rand(60, 140) + VectorRand() * 50)
     p:SetDieTime(math.Rand(0.25, 0.5))
     p:SetStartAlpha(255)
     p:SetEndAlpha(0)
     p:SetStartSize(0.6)
     p:SetEndSize(0)
     p:SetStartLength(4)
     p:SetEndLength(1)
     p:SetColor(255, 120, 60)
     p:SetGravity(Vector(0, 0, -200))
end

----------------------------------------------------------------------------------------
-- Duruş: konum, açı, ağzın yarım açısı
----------------------------------------------------------------------------------------
local function Poz(e)
     local d = e:GetDurum()
     local t = CurTime()
     local gecen = t - e:GetDurumZaman()
     local pos = e:GetPos()
     local grup = Grup(e)
     local h = grup and GrupBakilan(e, pos, d, t) or Hedef(e)
     local bak = h and (h:EyePos() - pos) or e:GetForward()
     if bak:LengthSqr() < 1 then bak = Vector(1, 0, 0) end
     local yon = bak:GetNormalized()
     local bakAci = bak:Angle()
     local yaw = bakAci.y
     if grup then
          -- üyeler arasında yumuşak dönüş
          e.bakYaw = math.ApproachAngle(e.bakYaw or yaw, yaw, FrameTime() * 160)
          yaw = e.bakYaw
          yon = Angle(0, yaw, 0):Forward()
     end
     local acikPitch = grup and math.Clamp(math.NormalizeAngle(bakAci.p), -5, 40) or -3   -- ağız alıcının yüzüne
     local pitch, roll, aci = 90, 0, 0
     local sv = e.agiz or 0

     pos = pos + Vector(0, 0, math.sin(t * 2.1 + e:EntIndex()) * 0.8)

     if d == Z.DUSUS then
          roll = math.sin(t * 7) * 18 * (1 - math.Clamp(gecen / A.DusmeSuresi, 0, 1))
     elseif d == Z.BEKLE then
          local k = math.Clamp(gecen / A.AcmaSuresi, 0, 1)
          pos = pos + VectorRand() * (0.1 + k * 0.6)
          roll = math.sin(t * 31) * (2 + k * 9)
          aci = 0.015 + math.max(0, math.sin(t * 6)) * 0.05 * k
     elseif d == Z.CAL then
          local ac = math.Clamp((t - (e:GetBasla() - A.AcilisPayi)) / A.AcilisPayi, 0, 1)
          local yum = ac * ac * (3 - 2 * ac)
          pitch = Lerp(yum, 90, acikPitch)
          aci = Lerp(yum, 0, 0.2) + sv * 0.55
          pos = pos + yon * (sv * (grup and 8 or 5))
          yaw = yaw + math.sin(t * 13) * sv * 9
          roll = math.sin(t * 9.3) * sv * 7
     elseif d == Z.SOR then
          pitch = acikPitch
          aci = 0.16 + math.abs(math.sin(t * 2.4)) * 0.06
     else
          pitch = acikPitch
          aci = 0.16
     end
     return pos, Angle(pitch, yaw, roll), aci, yon
end

----------------------------------------------------------------------------------------
-- Ses seviyesi: menzil kenarında sönme + duvar / kapı arkasında kısılma
----------------------------------------------------------------------------------------
local function Engelli(a, b)
     if gspeak and gspeak.range and gspeak.range.Blocked then
          local ok, r = pcall(gspeak.range.Blocked, a, b)
          if ok then return r end
     end
     return util.TraceLine({start = a, endpos = b, mask = MASK_SOLID_BRUSHONLY}).Hit
end

local function SesSeviye(e, pos)
     local goz = EyePos()
     local r = Grup(e) and math.max(A.MenzilGrup, e:GetPatlama() and A.MenzilPatlama or 0) or (e:GetPatlama() and A.MenzilPatlama or A.Menzil)
     local mesafe = goz:Distance(pos)
     local son = 1 - math.Clamp((mesafe - r * 0.8) / (r * 0.3), 0, 1)
     local t = CurTime()
     if (e.engelZaman or 0) < t then
          e.engelZaman = t + 0.3
          e.engel = mesafe > 60 and Engelli(goz, pos) or false
     end
     e.engelK = Lerp(FrameTime() * 4, e.engelK or 1, e.engel and A.EngelCarpan or 1)
     return A.Ses * son * e.engelK
end

----------------------------------------------------------------------------------------
-- Yazılı çığırtkan: vuruşlar (ses + ağız)
----------------------------------------------------------------------------------------
local SES_CARPAN = {harf = 0.55, bosluk = 0.45, zil = 0.6, satir = 0.75, besleme = 0.6, damga = 0.9}

-- Döndürür: ağzın hedef açıklığı. Belge zaman çizelgesindeki olaylar gerçekleştikçe çalınır.
function ZF.DaktiloDusun(e, d, t, pos)
     local Y = C.yazilar[e:GetKimlik()]
     if d ~= Z.CAL or not Y then
          e.dkBasla = nil
          return 0
     end
     local olaylar = Y.belge.olaylar
     local gec = t - e:GetBasla()
     if e.dkBasla ~= e:GetBasla() then
          e.dkBasla, e.dkSira, e.dkVurus = e:GetBasla(), 0, nil
     end
     local ses = SesSeviye(e, pos)
     local calinan = 0
     while e.dkSira < #olaylar and olaylar[e.dkSira + 1].t <= gec do
          e.dkSira = e.dkSira + 1
          local o = olaylar[e.dkSira]
          -- sekme değişimi / düşük FPS'te biriken vuruşlar sessiz geçilir
          if gec - o.t < 0.2 and calinan < 3 and ses > 0.01 then
               local hiz = o.tur == "harf" and (0.93 + 0.14 * C.DaktiloTitrek(e.dkSira)) or 1
               C.DaktiloSes(o.tur, pos, ses * (SES_CARPAN[o.tur] or 1), hiz)
               calinan = calinan + 1
          end
          if o.tur == "harf" then
               e.dkVurus, e.dkGuc, e.dkTus = t, 0.4 + 0.45 * C.DaktiloTitrek(e.dkSira * 3), o
          elseif o.tur == "satir" then
               e.dkVurus, e.dkGuc, e.dkSatirAn = t, o.bos and 0.5 or 0.95, t
          elseif o.tur == "damga" then
               e.dkVurus, e.dkGuc = t, 1
               if Alici(e, LocalPlayer()) then util.ScreenShake(EyePos(), 3, 12, 0.35, 40) end
          end
     end
     if not e.dkVurus then return 0 end
     return e.dkGuc * math.max(0, 1 - (t - e.dkVurus) / 0.11)
end

----------------------------------------------------------------------------------------
-- Durum geçişleri
----------------------------------------------------------------------------------------
function ZF.Yirt(pos, ang, patlama, olcek)
     olcek = olcek or 1
     local em = ParticleEmitter(pos)
     local W2, L = C.ZarfW / 2, C.ZarfL
     local t = CurTime()
     for i = 1, 18 do
          local yerel = Vector(math.Rand(0, L), math.Rand(-W2, W2), math.Rand(-0.5, 0.5))
          local p = C.YerelDunya(pos, ang, olcek, yerel)
          local boy = math.Rand(1.6, 3.6) * olcek
          local dis = (p - pos):GetNormalized()
          ZF.parcalar[#ZF.parcalar + 1] = {
               p = p,
               v = (dis + VectorRand() * 0.6 + Vector(0, 0, 0.7)) * math.Rand(30, 95),
               a = AngleRand(),
               w = Angle(math.Rand(-400, 400), math.Rand(-400, 400), math.Rand(-400, 400)),
               k = {Vector(0, 0, 0), Vector(math.Rand(0.6, 1) * boy, math.Rand(-0.4, 0.4) * boy, 0), Vector(math.Rand(-0.2, 0.5) * boy, math.Rand(0.6, 1) * boy, 0)},
               renk = math.random() < 0.7 and R.kagit or R.kagitIc,
               b0 = t,
               yanma = math.Rand(0.05, 0.4),
               omur = math.Rand(1.6, 2.6),
               sonAlev = 0,
          }
     end
     for i = 1, (patlama and 14 or 9) do Alev(em, pos + VectorRand() * 3, math.Rand(3, 6)) end
     for i = 1, 16 do Kor(em, pos + VectorRand() * 4) end
     for i = 1, 7 do Duman(em, pos + VectorRand() * 4, true, math.Rand(2, 4)) end
     em:Finish()
     sound.Play("physics/cardboard/cardboard_box_break" .. math.random(1, 3) .. ".wav", pos, 72, math.random(118, 132))
     sound.Play("ambient/fire/ignite.wav", pos, 70, 110)
end

local function Patlama(e, pos)
     local em = Yayici(e, pos)
     for i = 1, 16 do Alev(em, pos + VectorRand() * 4, math.Rand(5, 9)) end
     for i = 1, 22 do Kor(em, pos + VectorRand() * 3, VectorRand() * 120 + Vector(0, 0, 60)) end
     for i = 1, 8 do Duman(em, pos + VectorRand() * 5, true, math.Rand(3, 5)) end
     sound.Play("ambient/fire/mtov_flame2.wav", pos, 80, 115)
     sound.Play("ambient/fire/ignite.wav", pos, 78, 85)
     if EyePos():DistToSqr(pos) < 600 * 600 then util.ScreenShake(pos, 4, 12, 0.5, 600) end
end

local function DurumDegisti(e, eski, yeni)
     local lp = LocalPlayer()
     local bana = Alici(e, lp)
     local pos = e.cizPos or e:GetPos()

     if yeni == Z.BEKLE and bana then
          local g = e:GetGonderen()
          if Yazili(e) and not Grup(e) then
               chat.AddText(R.kizilAcik, "[Vociferador] ", color_white, (g ~= "" and g or "Alguien") .. " te ha enviado un aviso oficial. ", R.soluk, "Ábrelo con [E]; si no, estalla solo.")
          elseif Grup(e) then
               local ad = e:GetNW2String("SardonCigirtkanGrupAd", "")
               chat.AddText(R.kizilAcik, "[Vociferador] ", color_white, (g ~= "" and g or "Alguien") .. " ha enviado un vociferador masivo (" .. ad .. "). ", R.soluk, "Mira el sobre y ábrelo con [E]; si nadie lo abre, estalla solo.")
          else
               chat.AddText(R.kizilAcik, "[Vociferador] ", color_white, g ~= "" and (g .. " te ha enviado un vociferador. ") or "¡Te ha llegado un vociferador! ", R.soluk, "Ábrelo con [E]; si no, estalla solo.")
          end
          surface.PlaySound("spg/owlboi.wav")
     elseif yeni == Z.CAL then
          if eski == Z.BEKLE or eski == Z.DUSUS then
               if e:GetPatlama() then
                    Patlama(e, pos)
               else
                    sound.Play("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7) .. ".wav", pos, 70, 120)
               end
          end
     elseif yeni == Z.YOK and not e.yirtildi then
          e.yirtildi = true
          local v = C.veri[e:GetKimlik()]
          if v and v.k3 and v.k3:IsValid() then v.k3:Pause() end
          ZF.Yirt(e.cizPos or e:GetPos(), e.cizAng or e:GetAngles(), e:GetPatlama(), e.cizOlcek)
     end
end

----------------------------------------------------------------------------------------
-- Her kare (varlığın ENT:Think'i)
----------------------------------------------------------------------------------------
function ZF.Dusun(e)
     local d = e:GetDurum()
     local t = CurTime()
     if d ~= e.sonDurum then
          DurumDegisti(e, e.sonDurum, d)
          e.sonDurum = d
     end

     local id = e:GetKimlik()
     local yazili = Yazili(e)
     local ch = not yazili and C.Kanal(id, true)
     local hedefAgiz = 0
     local pos = e.cizPos or e:GetPos()

     if yazili then
          hedefAgiz = ZF.DaktiloDusun(e, d, t, pos)
     elseif d == Z.CAL then
          local gec = t - e:GetBasla()
          if ch and gec >= 0 and gec < e:GetSure() + 0.3 then
               if e.calanBasla ~= e:GetBasla() then
                    e.calanBasla = e:GetBasla()
                    ch:Set3DFadeDistance(Grup(e) and A.SesTamGrup or (e:GetPatlama() and A.SesTamPatlama or A.SesTam), 100000)
                    ch:SetPos(pos)
                    ch:SetVolume(SesSeviye(e, pos))
                    ch:SetTime(math.max(0, gec))
                    ch:Play()
               end
               ch:SetPos(pos)
               ch:SetVolume(SesSeviye(e, pos))
               if ch:GetState() == GMOD_CHANNEL_PLAYING then
                    local l, r = ch:GetLevel()
                    hedefAgiz = math.Clamp(((l or 0) + (r or l or 0)) * 0.75, 0, 1)
               end
          end
     elseif e.calanBasla then
          e.calanBasla = nil
          if ch then ch:Pause() end
     end

     local onceki = e.agiz or 0
     e.agiz = Lerp(math.min(1, FrameTime() * (hedefAgiz > onceki and 24 or 9)), onceki, hedefAgiz)

     -- alıcıda sarsıntı (yazılıda yalnız damgada, DaktiloDusun)
     if d == Z.CAL and not yazili and e.agiz > 0.7 and (e.sonSarsinti or 0) < t and Alici(e, LocalPlayer()) and EyePos():DistToSqr(pos) < 500 * 500 then
          e.sonSarsinti = t + 0.3
          util.ScreenShake(EyePos(), 1.6 * e.agiz, 9, 0.25, 40)
     end

     -- parçacıklar
     if d == Z.YOK or not e.cizAng then return end
     if (e.sonParcacik or 0) > t then return end
     local cpos, cang, caci, col = e.cizPos, e.cizAng, e.cizAci or 0, e.cizOlcek or 1
     local em = Yayici(e, cpos)
     if d == Z.BEKLE or d == Z.DUSUS then
          local k = d == Z.BEKLE and math.Clamp((t - e:GetDurumZaman()) / A.AcmaSuresi, 0, 1) or 0
          e.sonParcacik = t + Lerp(k, 0.22, 0.05)
          local kose = C.Koseler[math.random(1, #C.Koseler)]
          Duman(em, C.YerelDunya(cpos, cang, col, kose), k > 0.6, (1 + k) * col)
          if k > 0.5 and math.random() < k then Kor(em, C.YerelDunya(cpos, cang, col, kose), Vector(0, 0, 20) + VectorRand() * 10, 0.9 * col) end
     elseif d == Z.CAL then
          e.sonParcacik = t + 0.05
          if e.agiz > 0.5 then
               local agiz = C.YerelDunya(cpos, cang, col, C.AgizMerkez(caci))
               for i = 1, math.Round(e.agiz * 3) do Kivilcim(em, agiz, cang:Forward()) end
          end
          if math.random() < 0.15 then
               Duman(em, C.YerelDunya(cpos, cang, col, C.Koseler[math.random(1, 2)]), false, 0.8 * col)
          end
     elseif d == Z.SOR then
          e.sonParcacik = t + 0.3
          Duman(em, C.YerelDunya(cpos, cang, col, C.Koseler[math.random(1, #C.Koseler)]), false, col)
     end
end

----------------------------------------------------------------------------------------
-- Çizim (varlığın DrawTranslucent'ı)
----------------------------------------------------------------------------------------
local function Etiket(e, pos, d)
     local goz = EyePos()
     local mesafe = goz:Distance(pos)
     if mesafe > 700 or d == Z.YOK then return end
     local alfa = 255 * (1 - math.Clamp((mesafe - 450) / 250, 0, 1))
     local grup = Grup(e)
     local bana = Alici(e, LocalPlayer())
     if bana and not grup and d ~= Z.BEKLE then return end      -- alıcı yüzünün dibindeki zarfta yazı görmesin; ekranda istem var
     local yazili = Yazili(e)
     if yazili and (d == Z.CAL or d == Z.SOR) then return end    -- yerine yazılan satırlar (ZF.DaktiloSerit)

     local ang = Angle(0, (goz - pos):Angle().y + 90, 90)
     local olcek = e.cizOlcek or 1
     cam.Start3D2D(pos + Vector(0, 0, 11 * olcek), ang, 0.045 * olcek)
          C.Aralikli("VOCIFERADOR", "SardonCigirtkan.Etiket", 0, -28, Color(R.kizilAcik.r, R.kizilAcik.g, R.kizilAcik.b, alfa), 6, 1)
          local g = e:GetGonderen()
          local alt = grup and e:GetNW2String("SardonCigirtkanGrupAd", "") or (((bana or yazili) and g ~= "") and g or "")
          if alt ~= "" then
               draw.SimpleText(alt, "SardonCigirtkan.EtiketAlt", 0, 22, Color(R.fildisi.r, R.fildisi.g, R.fildisi.b, alfa), TEXT_ALIGN_CENTER)
          end
     cam.End3D2D()
end

function ZF.Ciz(e)
     local d = e:GetDurum()
     if d == Z.YOK and e.yirtildi then return end
     local pos, ang, aci = Poz(e)
     local olcek = Grup(e) and A.GrupOlcek or 1
     e.cizPos, e.cizAng, e.cizAci, e.cizOlcek = pos, ang, aci, olcek

     local mr
     if d == Z.BEKLE then
          -- mühür közleniyor: süre doldukça kızarır
          local k = math.Clamp((CurTime() - e:GetDurumZaman()) / A.AcmaSuresi, 0, 1)
          local n = 0.5 + 0.5 * math.sin(CurTime() * (4 + k * 10))
          mr = Color(Lerp(k * n, R.muhur.r, 255), Lerp(k * n, R.muhur.g, 120), Lerp(k * n, R.muhur.b, 40))
     end
     C.ZarfCiz3D(pos, ang, olcek, aci, {dil = e.agiz or 0, muhurRenk = mr})

     render.SetMaterial(MAT_PARILTI)
     if d == Z.CAL and (e.agiz or 0) > 0.05 then
          local m = C.YerelDunya(pos, ang, olcek, C.AgizMerkez(aci))
          local s = (8 + e.agiz * 30) * olcek
          render.DrawSprite(m, s, s, Color(255, 70, 40, 150 * e.agiz))
     elseif d == Z.BEKLE and mr then
          local m = C.YerelDunya(pos, ang, olcek, Vector(C.ZarfL * 0.68, 0, 0.6))
          render.DrawSprite(m, 7 * olcek, 7 * olcek, Color(255, 110, 50, (mr.r - R.muhur.r)))
     end

     Etiket(e, pos, d)
     -- ZF.DaktiloSerit bu dosyada ZF.Ciz'den sonra tanımlı (DK, Yazilan yanında): tablo üzerinden çağrılır
     if (d == Z.CAL or d == Z.SOR) and Yazili(e) then ZF.DaktiloSerit(e, pos) end
end

----------------------------------------------------------------------------------------
-- Yazılı çığırtkan: çevredekilerin gördüğü satırlar (zarfın üstünde süzülen kâğıt şerit)
----------------------------------------------------------------------------------------
surface.CreateFont("SardonCigirtkan.Daktilo3D", {font = "Courier New", size = 30, weight = 700, extended = true, antialias = true})

local DK = {
     kagit = Color(238, 229, 207), murekkep = Color(30, 26, 23), cizgi = Color(96, 84, 64),
     merdane = Color(22, 22, 24), merdaneAcik = Color(92, 90, 86), metal = Color(170, 172, 168),
}

-- Satırın şu ana kadar vurulmuş harf sayısı
local function Yazilan(sat, gec)
     if gec >= sat.bitis then return #sat.harfler end
     local n = 0
     for j = 1, #sat.harfler do
          if sat.zaman[j] > gec then break end
          n = j
     end
     return n
end
ZF.DaktiloYazilan = Yazilan

function ZF.DaktiloSerit(e, pos)
     local Y = C.yazilar[e:GetKimlik()]
     if not Y or Alici(e, LocalPlayer()) then return end
     local mesafe = EyePos():Distance(pos)
     if mesafe > A.DaktiloMenzil then return end
     local alfa = 1 - math.Clamp((mesafe - A.DaktiloMenzil * 0.75) / (A.DaktiloMenzil * 0.25), 0, 1)
     local b, yazi = Y.belge, Y.yazi
     local gec = CurTime() - e:GetBasla()
     local son = 0
     for i, sat in ipairs(b.satirlar) do
          if gec >= sat.basla then son = i end
     end
     if son == 0 then return end
     local ilk = math.max(1, son - 3)

     surface.SetFont("SardonCigirtkan.Daktilo3D")
     local cw = math.max(surface.GetTextSize("MMMMMMMMMM") / 10, 17)
     local lh, N = 38, A.DaktiloSatir
     local W = math.Round(N * cw + 48)
     local H = 66 + (son - ilk + 1) * lh + 14
     local olcek = 0.03 * (e.cizOlcek or 1)
     local renk = yazi.renk
     cam.Start3D2D(pos + Vector(0, 0, 13 * (e.cizOlcek or 1) + H * olcek), Angle(0, (EyePos() - pos):Angle().y + 90, 90), olcek)
          draw.NoTexture()
          surface.SetDrawColor(0, 0, 0, 90 * alfa)
          surface.DrawRect(-W / 2 + 6, 8, W, H)
          surface.SetDrawColor(DK.kagit.r, DK.kagit.g, DK.kagit.b, 238 * alfa)
          surface.DrawRect(-W / 2, 0, W, H)
          surface.SetDrawColor(renk[1], renk[2], renk[3], 230 * alfa)
          surface.DrawRect(-W / 2, 0, W, 5)
          C.Aralikli(C.Buyuk(yazi.antet ~= "" and yazi.antet or yazi.tur), "SardonCigirtkan.EtiketAlt", 0, 16, Color(renk[1], renk[2], renk[3], 255 * alfa), 5, 1)
          surface.SetFont("SardonCigirtkan.Daktilo3D")
          for i = ilk, son do
               local sat = b.satirlar[i]
               local y = 66 + (i - ilk) * lh
               local r = sat.kirmizi and Color(renk[1], renk[2], renk[3]) or DK.murekkep
               surface.SetTextColor(r.r, r.g, r.b, 235 * alfa)
               for j = 1, Yazilan(sat, gec) do
                    local h = sat.harfler[j]
                    if h ~= " " then
                         surface.SetTextPos(math.Round(-W / 2 + 24 + (sat.sutun + j - 1) * cw), y)
                         surface.DrawText(h)
                    end
               end
          end
     cam.End3D2D()
end

----------------------------------------------------------------------------------------
-- Yırtılan parçalar (varlık silindikten sonra da yaşar)
----------------------------------------------------------------------------------------
local GEC = Color(36, 20, 16)
hook.Add("PostDrawTranslucentRenderables", "SardonCigirtkan.Parcalar", function(derinlik, gok)
     if gok or #ZF.parcalar == 0 then return end
     local t = CurTime()
     local dt = FrameTime()
     local em

     render.SetMaterial(C.MatSaydam)
     mesh.Begin(MATERIAL_TRIANGLES, #ZF.parcalar)
     for i = #ZF.parcalar, 1, -1 do
          local p = ZF.parcalar[i]
          local yas = t - p.b0
          if yas > p.omur then
               table.remove(ZF.parcalar, i)
               -- mesh.Begin sayısını tutmak için boş üçgen
               for _ = 1, 3 do
                    mesh.Position(vector_origin)
                    mesh.Color(0, 0, 0, 0)
                    mesh.AdvanceVertex()
               end
          else
               -- kâğıt: hafif yerçekimi, güçlü hava direnci, yanlara salınım
               p.v.z = p.v.z - 70 * dt
               p.v:Mul(math.max(0, 1 - 1.9 * dt))
               p.p:Add(p.v * dt + Vector(math.sin(t * 5 + i) * 6 * dt, math.cos(t * 4 + i) * 6 * dt, 0))
               p.a:Add(p.w * dt)
               local yan = math.Clamp((yas - p.yanma) / (p.omur * 0.7), 0, 1)
               local alfa = 255 * (1 - math.Clamp((yas - (p.omur - 0.5)) / 0.5, 0, 1))
               local r = Lerp(yan, p.renk.r, GEC.r)
               local g = Lerp(yan, p.renk.g, GEC.g)
               local b = Lerp(yan, p.renk.b, GEC.b)
               local F, Rt, U = p.a:Forward(), p.a:Right(), p.a:Up()
               for j = 1, 3 do
                    local k = p.k[j]
                    mesh.Position(p.p + F * k.x - Rt * k.y + U * k.z)
                    mesh.Color(r, g, b, alfa)
                    mesh.AdvanceVertex()
               end
               if yan > 0 and yan < 0.85 and p.sonAlev < t then
                    p.sonAlev = t + 0.09
                    p.alevVar = true
               end
          end
     end
     mesh.End()

     -- yanan kenarlardan kor ve küçük alev
     for _, p in ipairs(ZF.parcalar) do
          if p.alevVar then
               p.alevVar = false
               em = em or ParticleEmitter(p.p)
               if math.random() < 0.6 then Kor(em, p.p, OPT_K.V_0_0_18 + VectorRand() * 8, math.Rand(0.5, 1.1)) end
               if math.random() < 0.35 then
                    local f = em:Add("particles/flamelet" .. math.random(1, 5), p.p)
                    if f then
                         f:SetVelocity(Vector(0, 0, 14))
                         f:SetDieTime(0.3)
                         f:SetStartAlpha(220)
                         f:SetEndAlpha(0)
                         f:SetStartSize(1.4)
                         f:SetEndSize(0.3)
                         f:SetRoll(math.Rand(0, 360))
                    end
               end
               if math.random() < 0.08 then Duman(em, p.p, true, 0.8) end
          end
     end
     if em then em:Finish() end
end)

----------------------------------------------------------------------------------------
-- Baykuşun pençesindeki zarf, kayıt yapanın elindeki zarf
----------------------------------------------------------------------------------------
-- Baykuşlar oluşup silindikçe kümede tutulur: her karede ents.FindByClass bütün varlıkları tarıyordu
-- (ölçüm: 2700 varlıkta ~110 µs / kare, kimse çığırtkan kullanmazken bile).
ZF.baykuslar = ZF.baykuslar or {}
hook.Add("OnEntityCreated", "SardonCigirtkan.Baykus", function(e)
     if e:GetClass() == "pet_owl" then ZF.baykuslar[e] = true end
end)
hook.Add("EntityRemoved", "SardonCigirtkan.Baykus", function(e)
     ZF.baykuslar[e] = nil
end)
for _, e in ipairs(ents.FindByClass("pet_owl")) do ZF.baykuslar[e] = true end

hook.Add("PostDrawOpaqueRenderables", "SardonCigirtkan.Tasinan", function(derinlik, gok)
     if gok then return end
     local t = CurTime()

     for owl in pairs(ZF.baykuslar) do
          if not IsValid(owl) then
               ZF.baykuslar[owl] = nil
          elseif owl:GetNWBool("SardonCigirtkan", false) and not owl:IsDormant() then
               local sol = owl:LookupBone("ValveBiped.Bip01_L_Hand")
               local sag = owl:LookupBone("ValveBiped.Bip01_R_Hand")
               local pos = (sol and sag) and (owl:GetBonePosition(sol) + owl:GetBonePosition(sag)) / 2 or owl:LocalToWorld(OPT_K.V_0_0_46)
               local hedef = owl:GetNWEntity("target")
               local yakin = IsValid(hedef) and hedef:GetPos():DistToSqr(pos) < 1600 * 1600
               local sallan = Angle(90 + math.sin(t * 2.3 + owl:EntIndex()) * 6, owl:GetAngles().y, math.sin(t * 3.1) * 8)
               if yakin then sallan.r = sallan.r + math.sin(t * 29) * 4 end
               local zpos = pos - Vector(0, 0, C.ZarfL * 0.55 * 0.6)
               C.ZarfCiz3D(zpos, sallan, 0.55, yakin and (0.02 + math.max(0, math.sin(t * 7)) * 0.05) or 0)

               if yakin and (owl.cigDuman or 0) < t then
                    owl.cigDuman = t + 0.12
                    if not (owl.cigYayici and owl.cigYayici:IsValid()) then owl.cigYayici = ParticleEmitter(zpos) end
                    Duman(owl.cigYayici, C.YerelDunya(zpos, sallan, 0.55, C.Koseler[math.random(1, 4)]), false, 0.9)
               end
          elseif owl.cigYayici then
               if owl.cigYayici:IsValid() then owl.cigYayici:Finish() end
               owl.cigYayici = nil
          end
     end

     if GetGlobalInt("SardonCigirtkanKayit", 0) == 0 then return end
     local lp = LocalPlayer()
     for _, ply in player.Iterator() do
          if ply:GetNWBool("SardonCigirtkanKayit", false) and not ply:IsDormant() and ply:Alive()
               and (ply ~= lp or ply:ShouldDrawLocalPlayer()) then
               local kemik = ply:LookupBone("ValveBiped.Bip01_R_Hand")
               if kemik then
                    local kp, ka = ply:GetBonePosition(kemik)
                    if kp then
                         local bas = ply:EyePos()
                         local yon = (bas - kp)
                         local acili = yon:Angle()
                         local aci = ply:IsSpeaking() and (0.12 + 0.18 * math.abs(math.sin(t * 11))) or 0.06
                         C.ZarfCiz3D(kp + ka:Forward() * 3 - acili:Forward() * 2, Angle(10, acili.y, 0), 0.42, aci)
                    end
               end
          end
     end
end)

----------------------------------------------------------------------------------------
-- Alıcının ekranı: istem ve kızıl kenarlık
----------------------------------------------------------------------------------------
local function Istem(baslik, alt, oran, gonderen, x, y)
     local w, h = O(470), O(84)
     x, y = x or (ScrW() / 2 - w / 2), y or ScrH() * 0.74
     surface.SetDrawColor(R.zemin.r, R.zemin.g, R.zemin.b, 235)
     surface.DrawRect(x, y, w, h)
     surface.SetDrawColor(R.cizgiGuclu.r, R.cizgiGuclu.g, R.cizgiGuclu.b, R.cizgiGuclu.a)
     surface.DrawOutlinedRect(x, y, w, h, 1)
     surface.SetDrawColor(R.kizil.r, R.kizil.g, R.kizil.b, 255)
     surface.DrawRect(x, y, w, O(3))
     C.Aralikli(gonderen ~= "" and ("VOCIFERADOR  ·  " .. C.Buyuk(gonderen)) or "VOCIFERADOR", C.Font(12, true), x + O(18), y + O(12), R.ust, O(3), 0)
     draw.SimpleText(baslik, C.Font(22, true), x + O(18), y + O(28), R.fildisi)
     draw.SimpleText(alt, C.Font(13), x + O(18), y + O(56), R.soluk)
     surface.SetDrawColor(R.zeminKoyu.r, R.zeminKoyu.g, R.zeminKoyu.b, 255)
     surface.DrawRect(x, y + h - O(4), w, O(4))
     surface.SetDrawColor(R.kizilAcik.r, R.kizilAcik.g, R.kizilAcik.b, 255)
     surface.DrawRect(x, y + h - O(4), w * math.Clamp(oran, 0, 1), O(4))
end

local function Kenarlik(guc)
     local a = 110 * guc
     if a < 2 then return end
     local w, h = ScrW(), ScrH()
     local k = h * 0.22
     surface.SetDrawColor(150, 10, 14, a)
     surface.SetMaterial(MAT_GRAD.u) surface.DrawTexturedRect(0, 0, w, k)
     surface.SetMaterial(MAT_GRAD.d) surface.DrawTexturedRect(0, h - k, w, k)
     surface.SetMaterial(MAT_GRAD.l) surface.DrawTexturedRect(0, 0, k, h)
     surface.SetMaterial(MAT_GRAD.r) surface.DrawTexturedRect(w - k, 0, k, h)
end

----------------------------------------------------------------------------------------
-- Yazılı çığırtkan: alıcının ekranındaki daktilo
----------------------------------------------------------------------------------------
-- Gerçek daktilo gibi: harfler hep aynı vuruş noktasına düşer, kâğıt şaryoyla birlikte sola kayar
-- (burada okunsun diye kısmen), satır bitince şaryo geri döner ve kâğıt bir satır yukarı çıkar.
-- Damga en sonda basılır; zarf yanarken kâğıt merdaneden yukarı doğru yanar.
local dkFont = {}
local function DaktiloFont(px)
     local ad = "SardonCigirtkan.Daktilo" .. px
     if not dkFont[ad] then
          surface.CreateFont(ad, {font = "Courier New", size = px, weight = 700, extended = true, antialias = true})
          dkFont[ad] = true
     end
     return ad
end

-- [sardon] bakanlik'in gömülü dokuları (mühür, mum, kâğıt); yoksa düz çizim
local function Doku(yazi, ad)
     local B = SardonBakanlik
     if yazi.muhur ~= "bakanlik" or not (B and B.Doku) then return nil end
     return B.Doku(ad)
end

local function Yumusak(x) return x * x * (3 - 2 * x) end

local function Daire2D(x, y, r, renk, n)
     local t = {}
     n = n or 20
     for i = 0, n - 1 do
          local a = i / n * math.pi * 2
          t[#t + 1] = {x = x + math.cos(a) * r, y = y + math.sin(a) * r}
     end
     draw.NoTexture()
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a or 255)
     surface.DrawPoly(t)
end

-- Döndürülmüş damga: çift çerçeve + harf aralıklı yazı + lastiğin bıraktığı boşluklar
local function Damga(metin, cx, cy, aci, olcek, renk, alfa)
     local font = C.Font(26, true)
     surface.SetFont(font)
     local tw = 0
     for _, kod in utf8.codes(metin) do tw = tw + surface.GetTextSize(utf8.char(kod)) + O(4) end
     local w, h = tw + O(34), O(56)
     local m = Matrix()
     m:Translate(Vector(cx, cy, 0))
     m:Rotate(Angle(0, aci, 0))
     m:Scale(Vector(olcek, olcek, 1))
     m:Translate(Vector(-w / 2, -h / 2, 0))
     render.PushFilterMag(TEXFILTER.ANISOTROPIC)
     render.PushFilterMin(TEXFILTER.ANISOTROPIC)
     cam.PushModelMatrix(m, true)
     ZF.matrisAcik = true
          draw.NoTexture()
          surface.SetDrawColor(renk[1], renk[2], renk[3], alfa)
          surface.DrawOutlinedRect(0, 0, w, h, O(3))
          surface.DrawOutlinedRect(O(6), O(6), w - O(12), h - O(12), 1)
          C.Aralikli(metin, font, w / 2, h / 2 - O(15), Color(renk[1], renk[2], renk[3], alfa), O(4), 1)
          -- mürekkep tutmamış yerler
          surface.SetDrawColor(DK.kagit.r, DK.kagit.g, DK.kagit.b, alfa * 0.8)
          for i = 1, 26 do
               local rx, ry = C.DaktiloTitrek(i * 17), C.DaktiloTitrek(i * 29 + 5)
               local boy = 1 + math.floor(C.DaktiloTitrek(i * 41) * 3)
               surface.DrawRect(rx * w, ry * h, boy, boy)
          end
     cam.PopModelMatrix()
     render.PopFilterMin()
     render.PopFilterMag()
     ZF.matrisAcik = false
end

-- Döndürür: daktilo gövdesinin alt kenarı (istem onun altına konur)
local function DaktiloEkran(e, Y, d, t)
     local b, yazi = Y.belge, Y.yazi
     local renk = yazi.renk
     local N = A.DaktiloSatir
     local sw, sh = ScrW(), ScrH()
     local gec = t - e:GetBasla()
     local S = b.satirlar

     local font = DaktiloFont(O(19))
     surface.SetFont(font)
     local cw = math.max(surface.GetTextSize("MMMMMMMMMM") / 10, O(19) * 0.58)
     local lh = math.Round(O(19) * 1.34)
     local ml = O(34)
     local PW = math.Round(N * cw + ml * 2)
     local ustPay, antetH = O(18), O(112)
     local PH = ustPay + antetH + #S * lh + O(86)
     local merdaneY = math.Round(sh * A.DaktiloEkranY)
     local vurusY = merdaneY - O(12)

     -- yok oluş: kâğıt merdaneden yukarı yanar, sonra daktilo söner
     local yokK = d == Z.YOK and math.Clamp((t - e:GetDurumZaman()) / 1.9, 0, 1) or 0
     local sonA = 1 - math.Clamp((yokK - 0.6) / 0.4, 0, 1)
     local giris = 1 - (1 - math.Clamp((gec + A.AcilisPayi) / 0.5, 0, 1)) ^ 3
     local inis = math.Round((1 - giris) * O(160))
     merdaneY, vurusY = merdaneY + inis, vurusY + inis

     -- hangi satırdayız: satır numarası (kesirli: şaryo dönerken kâğıt yukarı kayar)
     local akis, sutun = 0, (S[1] and S[1].sutun or 0)
     local besleme = Yumusak(math.Clamp(gec / A.DaktiloBesleme, 0, 1))
     for i, sat in ipairs(S) do
          if gec >= sat.basla then
               akis = i - 1
               sutun = sat.sutun + Yazilan(sat, gec)
               local sonraki = S[i + 1]
               if sonraki and gec > sat.bitis then
                    local k = Yumusak(math.Clamp((gec - sat.bitis) / math.max(0.05, sonraki.basla - sat.bitis), 0, 1))
                    akis = akis + k
                    sutun = Lerp(k, sutun, sonraki.sutun)
               end
          end
     end
     local bitti = gec >= b.bitis
     -- belge bitince kâğıt biraz yukarı salınır: imza ve damga merdanenin dibinde kalmasın
     akis = akis + Yumusak(math.Clamp((gec - b.damga - 0.1) / 0.7, 0, 1)) * 1.6
     local hedefY = vurusY - lh * 0.8 - ustPay - antetH - akis * lh
     local kagitY = math.Round(Lerp(besleme, merdaneY + O(8), hedefY))

     -- şaryo: kâğıt, yazılan sütun vuruş noktasına gelecek yönde (yüzde 30) kayar
     local kayHedef = bitti and 0 or -((ml + sutun * cw) - PW / 2) * 0.3
     e.dkKay = Lerp(math.min(1, FrameTime() * 14), e.dkKay or kayHedef, kayHedef)
     local kagitX = math.Round(sw / 2 - PW / 2 + e.dkKay)
     local vurusX = kagitX + ml + sutun * cw

     -- kâğıt (merdanenin altında kalan kısmı görünmez; yanarken alttan yukarı kesilir)
     local yanmaY = Lerp(yokK ^ 0.8, merdaneY + O(4), kagitY - O(30))
     local kesY = math.min(merdaneY + O(4), yanmaY)
     render.SetScissorRect(0, 0, sw, math.max(0, kesY), true)
          draw.NoTexture()
          surface.SetDrawColor(0, 0, 0, 80 * sonA)
          surface.DrawRect(kagitX + O(7), kagitY + O(9), PW, PH)
          local kagit = Doku(yazi, "kagit")
          if kagit then
               surface.SetMaterial(kagit)
               surface.SetDrawColor(255, 250, 238, 255)
          else
               draw.NoTexture()
               surface.SetDrawColor(DK.kagit.r, DK.kagit.g, DK.kagit.b, 255)
          end
          surface.DrawTexturedRect(kagitX, kagitY, PW, PH)
          surface.SetDrawColor(0, 0, 0, 34)
          surface.SetMaterial(MAT_GRAD.l) surface.DrawTexturedRect(kagitX, kagitY, O(14), PH)
          surface.SetMaterial(MAT_GRAD.r) surface.DrawTexturedRect(kagitX + PW - O(14), kagitY, O(14), PH)

          -- antet
          local ay = kagitY + ustPay
          local muhur = Doku(yazi, "muhur")
          if muhur then
               surface.SetMaterial(muhur)
               surface.SetDrawColor(255, 255, 255, 235)
               surface.DrawTexturedRect(kagitX + PW / 2 - O(26), ay - O(4), O(52), O(52))
          else
               C.Baklava(kagitX + PW / 2, ay + O(22), O(12), Color(renk[1], renk[2], renk[3]))
          end
          local murekkepYesil = Color(26, 48, 40)
          if yazi.antet ~= "" then C.Aralikli(C.Buyuk(yazi.antet), C.Font(15, true), kagitX + PW / 2, ay + O(52), murekkepYesil, O(4), 1) end
          if yazi.daire ~= "" then draw.SimpleText(yazi.daire, C.Font(11), kagitX + PW / 2, ay + O(74), DK.cizgi, TEXT_ALIGN_CENTER) end
          draw.NoTexture()
          surface.SetDrawColor(DK.cizgi.r, DK.cizgi.g, DK.cizgi.b, 200)
          surface.DrawRect(kagitX + ml, ay + O(96), PW - ml * 2, 2)
          surface.DrawRect(kagitX + ml, ay + O(101), PW - ml * 2, 1)

          -- satırlar: her harf kendi ızgara gözüne; mürekkep yoğunluğu ve hizası vuruştan vuruşa oynar
          surface.SetFont(font)
          local sayac = 0
          for i, sat in ipairs(S) do
               local n = Yazilan(sat, gec)
               local y = ay + antetH + (i - 1) * lh
               if n > 0 and y < kesY and y + lh > 0 then
                    local r = sat.kirmizi and Color(renk[1], renk[2], renk[3]) or DK.murekkep
                    for j = 1, n do
                         local h = sat.harfler[j]
                         local k = sayac + j
                         if h ~= " " then
                              local taze = gec - sat.zaman[j] < 0.15
                              local a = taze and 255 or (190 + 65 * C.DaktiloTitrek(k * 7))
                              local x = kagitX + ml + (sat.sutun + j - 1) * cw
                              local oy = math.Round((C.DaktiloTitrek(k * 13) - 0.5) * 1.2)
                              surface.SetTextColor(r.r, r.g, r.b, a)
                              surface.SetTextPos(math.Round(x), y + oy)
                              surface.DrawText(h)
                              -- ağır vuruş: harf iki kez basılmış gibi
                              if taze or C.DaktiloTitrek(k * 31) > 0.9 then
                                   surface.SetTextColor(r.r, r.g, r.b, a * 0.45)
                                   surface.SetTextPos(math.Round(x) + 1, y + oy)
                                   surface.DrawText(h)
                              end
                         end
                    end
               end
               sayac = sayac + #sat.harfler
          end

          -- damga ve mum mühür: mühür sol altta, damga mühürle imzanın (sağa yaslı son satırlar) arasında
          if gec >= b.damga and yazi.damga ~= "" then
               local k = math.Clamp((gec - b.damga) / 0.12, 0, 1)
               local sonSatirY = ay + antetH + (#S - 1) * lh
               local imzaSutun = N
               for i = #S, math.max(1, #S - 1), -1 do
                    if S[i].hiza == 2 then imzaSutun = math.min(imzaSutun, S[i].sutun) end
               end
               local solX, sagX = kagitX + ml + O(78), kagitX + ml + imzaSutun * cw - O(8)
               local dx = math.Clamp((solX + sagX) / 2, kagitX + ml + O(170), kagitX + PW - ml - O(100))
               Damga(C.Buyuk(yazi.damga), dx, sonSatirY - O(2), -8, 1.35 - 0.35 * Yumusak(k), renk, 215 * k)
               local mum = Doku(yazi, "mum")
               if mum then
                    local mb = O(64) * (1.25 - 0.25 * Yumusak(k))
                    surface.SetMaterial(mum)
                    surface.SetDrawColor(255, 255, 255, 255 * k)
                    surface.DrawTexturedRect(kagitX + ml + O(30) - mb / 2, sonSatirY + O(10) - mb / 2, mb, mb)
               end
          end
     render.SetScissorRect(0, 0, 0, 0, false)

     -- yanma çizgisi: kömürleşmiş şerit + kor ışığı + kıvılcımlar
     if yokK > 0 and yanmaY < merdaneY then
          draw.NoTexture()
          surface.SetDrawColor(40, 22, 12, 220 * sonA)
          surface.SetMaterial(MAT_GRAD.d)
          surface.DrawTexturedRect(kagitX, yanmaY - O(22), PW, O(22))
          surface.SetMaterial(MAT_PARILTI)
          surface.SetDrawColor(255, 120, 40, 200 * sonA)
          surface.DrawTexturedRect(kagitX - O(20), yanmaY - O(10), PW + O(40), O(20))
          draw.NoTexture()
          for i = 1, 22 do
               local u = C.DaktiloTitrek(i * 19)
               local yuk = ((t * (0.6 + u) + u) % 1) * O(70)
               surface.SetDrawColor(255, 150 + 80 * u, 60, 230 * (1 - yuk / O(70)) * sonA)
               surface.DrawRect(kagitX + u * PW, yanmaY - yuk, O(3), O(3))
          end
     end

     -- daktilo gövdesi (sabit) ve merdane (şaryoyla kayar)
     local govdeW = PW + O(150)
     local gx = sw / 2 - govdeW / 2
     local altY = merdaneY + O(108)
     draw.NoTexture()
     surface.SetDrawColor(0, 0, 0, 110 * sonA)
     surface.DrawPoly({{x = gx + O(6), y = merdaneY + O(26)}, {x = gx + govdeW + O(6), y = merdaneY + O(26)}, {x = gx + govdeW + O(46), y = altY + O(8)}, {x = gx - O(34), y = altY + O(8)}})
     surface.SetDrawColor(R.zemin.r, R.zemin.g, R.zemin.b, 248 * sonA)
     surface.DrawPoly({{x = gx, y = merdaneY + O(18)}, {x = gx + govdeW, y = merdaneY + O(18)}, {x = gx + govdeW + O(40), y = altY}, {x = gx - O(40), y = altY}})
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 160 * sonA)
     surface.DrawRect(gx - O(40), altY - 2, govdeW + O(80), 2)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 220 * sonA)
     surface.DrawRect(gx, merdaneY + O(18), govdeW, 2)
     surface.SetDrawColor(R.cizgi.r, R.cizgi.g, R.cizgi.b, R.cizgi.a * sonA)
     surface.DrawRect(gx + O(10), merdaneY + O(24), govdeW - O(20), 1)
     C.Aralikli(yazi.antet ~= "" and (C.Buyuk(yazi.antet) .. "  ·  DAKTİLO") or "DAKTİLO", C.Font(10, true), sw / 2, merdaneY + O(32), Color(R.altin.r, R.altin.g, R.altin.b, 200 * sonA), O(3), 1)

     -- tuşlar: son vuruşun harfi (yoksa sözde rastgele bir tuş) içeri basılır
     local TUSLAR = "QWERTYUIOPĞÜ"
     local tuslar = {}
     for _, kod in utf8.codes(TUSLAR) do tuslar[#tuslar + 1] = utf8.char(kod) end
     local basili
     if e.dkTus and e.dkVurus and t - e.dkVurus < 0.09 then
          local h = C.Buyuk(S[e.dkTus.satir] and S[e.dkTus.satir].harfler[e.dkTus.sira] or "")
          for i, tt in ipairs(tuslar) do
               if tt == h then basili = i end
          end
          basili = basili or (math.floor(C.DaktiloTitrek(e.dkSira or 1) * #tuslar) + 1)
     end
     local tr = O(15)
     local aralik = (govdeW - O(40)) / #tuslar
     for i, h in ipairs(tuslar) do
          local tx = gx + O(20) + (i - 0.5) * aralik
          local ty = merdaneY + O(78) + (i == basili and O(4) or 0)
          Daire2D(tx, ty + O(3), tr, Color(0, 0, 0, 160 * sonA), 18)
          Daire2D(tx, ty, tr, Color(R.altin.r, R.altin.g, R.altin.b, 230 * sonA), 18)
          Daire2D(tx, ty, tr - O(2), Color(18, 22, 20, 250 * sonA), 18)
          draw.SimpleText(h, C.Font(12, true), tx, ty, Color(R.fildisi.r, R.fildisi.g, R.fildisi.b, 220 * sonA), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     -- merdane
     local mx0, mx1 = kagitX - O(36), kagitX + PW + O(36)
     draw.NoTexture()
     surface.SetDrawColor(DK.merdane.r, DK.merdane.g, DK.merdane.b, 255 * sonA)
     surface.DrawRect(mx0, merdaneY, mx1 - mx0, O(26))
     surface.SetDrawColor(DK.merdaneAcik.r, DK.merdaneAcik.g, DK.merdaneAcik.b, 200 * sonA)
     surface.DrawRect(mx0, merdaneY + O(4), mx1 - mx0, 2)
     surface.SetDrawColor(0, 0, 0, 120 * sonA)
     surface.DrawRect(mx0, merdaneY + O(20), mx1 - mx0, O(6))
     for _, kx in ipairs({mx0, mx1}) do
          Daire2D(kx, merdaneY + O(13), O(19), Color(R.altin.r, R.altin.g, R.altin.b, 240 * sonA), 22)
          Daire2D(kx, merdaneY + O(13), O(14), Color(DK.merdane.r, DK.merdane.g, DK.merdane.b, 255 * sonA), 22)
          Daire2D(kx, merdaneY + O(13), O(5), Color(R.altinAcik.r, R.altinAcik.g, R.altinAcik.b, 220 * sonA), 12)
     end
     -- şaryo kolu: soldaki düğmeden yukarı; satır dönüşünde itilir
     local kol = e.dkSatirAn and math.max(0, 1 - (t - e.dkSatirAn) / 0.3) or 0
     local kolA = math.rad(-150 + 25 * math.sin(kol * math.pi))
     local kx, ky = mx0, merdaneY + O(13)
     local ux, uy = kx + math.cos(kolA) * O(62), ky + math.sin(kolA) * O(62)
     local nx, ny = -math.sin(kolA) * O(2.5), math.cos(kolA) * O(2.5)
     draw.NoTexture()
     surface.SetDrawColor(DK.metal.r, DK.metal.g, DK.metal.b, 230 * sonA)
     surface.DrawPoly({{x = kx + nx, y = ky + ny}, {x = kx - nx, y = ky - ny}, {x = ux - nx, y = uy - ny}, {x = ux + nx, y = uy + ny}})
     Daire2D(ux, uy, O(6), Color(R.altin.r, R.altin.g, R.altin.b, 240 * sonA), 14)

     -- vuruş noktası kılavuzu
     if not bitti then
          surface.SetDrawColor(R.altinAcik.r, R.altinAcik.g, R.altinAcik.b, 230 * sonA)
          surface.DrawPoly({{x = vurusX - O(6), y = merdaneY - O(1)}, {x = vurusX, y = merdaneY - O(8)}, {x = vurusX + O(6), y = merdaneY - O(1)}})
     end

     return altY
end

hook.Add("HUDPaint", "SardonCigirtkan.Istem", function()
     if not next(ZF.aktif) then return end
     local lp = LocalPlayer()
     local t = CurTime()
     for e in pairs(ZF.aktif) do
          local yakin = IsValid(e) and Alici(e, lp)
          if yakin and Grup(e) then
               yakin = EyePos():DistToSqr(e.cizPos or e:GetPos()) < A.GrupAcmaMenzil * A.GrupAcmaMenzil
          end
          if yakin then
               local d = e:GetDurum()
               local gecen = t - e:GetDurumZaman()
               local ix, iy
               local Y = Yazili(e) and C.yazilar[e:GetKimlik()]
               if Y and d ~= Z.BEKLE and d ~= Z.DUSUS then
                    local ok, alt = pcall(DaktiloEkran, e, Y, d, t)
                    if not ok then
                         render.SetScissorRect(0, 0, 0, 0, false)
                         if ZF.matrisAcik then
                              ZF.matrisAcik = false
                              cam.PopModelMatrix()
                              render.PopFilterMin()
                              render.PopFilterMag()
                         end
                         if not ZF.daktiloHata then
                              ZF.daktiloHata = true
                              ErrorNoHalt("[SardonCigirtkan] daktilo: " .. tostring(alt) .. "\n")
                         end
                    elseif alt then
                         ix, iy = ScrW() / 2 - O(235), alt + O(16)
                    end
               end
               if d == Z.BEKLE then
                    local kalan = math.max(0, A.AcmaSuresi - gecen)
                    Istem(Grup(e) and "[E]  Mira el sobre y ábrelo" or "[E]  Abrir el sobre", (Grup(e) and "Si nadie lo abre, " or "Si no lo abres, ") .. "estalla solo en " .. math.ceil(kalan) .. " s.", kalan / A.AcmaSuresi, e:GetGonderen())
               elseif d == Z.SOR then
                    local kalan = math.max(0, A.TekrarSoru - gecen)
                    if Y then
                         Istem("[E]  Leer otra vez", "Si no, el documento se quema en " .. math.ceil(kalan) .. " s.", kalan / A.TekrarSoru, e:GetGonderen(), ix, iy)
                    else
                         Istem("[E]  Escuchar otra vez", "Si no, el sobre se quema en " .. math.ceil(kalan) .. " s.", kalan / A.TekrarSoru, e:GetGonderen())
                    end
               elseif d == Z.CAL and not Yazili(e) then
                    Kenarlik(e.agiz or 0)
               end
          end
     end
end)
