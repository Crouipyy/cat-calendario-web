-- "addons\\sardonyaratik\\lua\\entities\\sardon_yaratik.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: dünyadaki yaratık / kuluçkadaki yumurta
--
-- Hareket ağdan "bölüt" olarak gelir: A'dan B'ye, T0..T1 arasında doğrusal (CurTime iki tarafta
-- eş). Sunucu yalnız yeni bölüt başlarken yazar (birkaç saniyede bir); istemci konumu, zemine
-- oturmayı, yönü ve animasyon karesini her karede kendisi hesaplar. Sunucudaki gerçek origin bölüt
-- başında güncellenir (PVS için); çizim SetRenderOrigin ile yapılır.
--
-- Animasyonlar ADIYLA gider (Anim + AnimT); döngüsel olanların karesi zamandan, "pet" gibi tek
-- seferlik olanlar başta tutulup sonda bırakılır. Modellerde kök hareketi yok: yürüme/koşma oynatma
-- hızı = hız / tur.animHiz.
--
-- Bu dosya SardonUtil'den önce yüklenir; SardonYaratik'e yalnız işlev içinde erişilir.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Sihirli Yaratık"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.IsSardonYaratik = true

-- Durum (DT Int) kodları
ENT.DURUM_VIVARYUM = 1
ENT.DURUM_TAKIP = 2
ENT.DURUM_KULUCKA = 3

function ENT:SetupDataTables()
     self:NetworkVar("Int", 0, "Kimlik")
     self:NetworkVar("Int", 1, "RenkBG")
     self:NetworkVar("Int", 2, "Nadir")
     self:NetworkVar("Int", 3, "Evre")
     self:NetworkVar("Int", 4, "Ihtiyac")      -- a + t*128 + s*16384 (0..100)
     self:NetworkVar("Int", 5, "Durum")
     self:NetworkVar("String", 0, "Tur")
     self:NetworkVar("String", 1, "Ad")
     self:NetworkVar("String", 2, "Anim")
     self:NetworkVar("Entity", 0, "Sahip")
     self:NetworkVar("Vector", 0, "A")
     self:NetworkVar("Vector", 1, "B")
     self:NetworkVar("Float", 0, "T0")
     self:NetworkVar("Float", 1, "T1")
     self:NetworkVar("Float", 2, "AnimT")
     self:NetworkVar("Float", 3, "Yon")
     self:NetworkVar("Float", 4, "AnimHizi")
     self:NetworkVar("Float", 5, "KBas")        -- kuluçka başlangıcı (CurTime cinsinden)
     self:NetworkVar("Float", 6, "KSure")
     self:NetworkVar("Float", 7, "Sicak")       -- kuluçka sıcaklığı (son yazıldığı an)
     self:NetworkVar("Float", 8, "SicakT")
end

-- Bölüt üzerinde şimdiki konum (zemin z'si istemcide ayrıca oturtulur)
function ENT:Konum(t)
     t = t or CurTime()
     local a, b = self:GetA(), self:GetB()
     local t0, t1 = self:GetT0(), self:GetT1()
     if t1 <= t0 or t >= t1 then return b end
     if t <= t0 then return a end
     return LerpVector((t - t0) / (t1 - t0), a, b)
end

function ENT:Hareketli(t)
     t = t or CurTime()
     return self:GetT1() > t and self:GetA():DistToSqr(self:GetB()) > 1
end

function ENT:IhtiyacCoz()
     local v = self:GetIhtiyac()
     return v % 128, math.floor(v / 128) % 128, math.floor(v / 16384) % 128
end

function ENT:TurVeri()
     return SardonYaratik and SardonYaratik.Turler and SardonYaratik.Turler[self:GetTur()]
end

function ENT:Olcek()
     local tur = self:TurVeri()
     if not tur then return 1 end
     local evre = self:GetEvre()
     if evre == 0 then return (tur.yumurta and tur.yumurta.olcek) or 1 end
     local e = SardonYaratik.Evreler[evre] or SardonYaratik.Evreler[3]
     return (tur.olcek or 1) * (e.olcek or 1)
end

if SERVER then
     function ENT:Initialize()
          self:SetModel(self.BaslangicModel or "models/props_phx/misc/egg.mdl")
          self:SetMoveType(MOVETYPE_NONE)
          self:SetSolid(SOLID_NONE)
          self:DrawShadow(true)
          self:SetUseType(SIMPLE_USE)
          local p = self:GetPos()
          self:SetA(p)
          self:SetB(p)
          self:SetT0(CurTime())
          self:SetT1(CurTime())
          self:SetAnim("idle")
          self:SetAnimT(CurTime())
          self:SetAnimHizi(1)
          self:SetYon(self:GetAngles().y)
     end

     -- hedefe yürü/koş. anim: "walk" / "run"; hiz birim/sn
     function ENT:Yuru(hedef, hiz, anim, animHizi)
          local simdi = CurTime()
          local bas = self:Konum(simdi)
          local mesafe = bas:Distance(hedef)
          hiz = math.max(hiz or 40, 1)

          self:SetPos(bas)
          self:SetA(bas)
          self:SetB(hedef)
          self:SetT0(simdi)
          self:SetT1(simdi + mesafe / hiz)
          if self:GetAnim() ~= anim then
               self:SetAnim(anim)
               self:SetAnimT(simdi)
          end
          self:SetAnimHizi(animHizi or 1)
          if mesafe > 1 then
               local d = hedef - bas
               self:SetYon(math.deg(math.atan2(d.y, d.x)))
          end
          return mesafe / hiz
     end

     -- olduğu yerde dur; anim döngüsel ya da tek seferlik; yon nil ise eski yön
     function ENT:Dur(anim, yon, yenidenBaslat)
          local simdi = CurTime()
          local p = self:Konum(simdi)
          self:SetPos(p)
          self:SetA(p)
          self:SetB(p)
          self:SetT0(simdi)
          self:SetT1(simdi)
          if yon then self:SetYon(yon) end
          anim = anim or "idle"
          if yenidenBaslat or self:GetAnim() ~= anim then
               self:SetAnim(anim)
               self:SetAnimT(simdi)
          end
          self:SetAnimHizi(1)
     end

     function ENT:Isinla(p, yon)
          self:SetPos(p)
          self:SetA(p)
          self:SetB(p)
          local simdi = CurTime()
          self:SetT0(simdi)
          self:SetT1(simdi)
          if yon then self:SetYon(yon) end
     end

     function ENT:UpdateTransmitState()
          return TRANSMIT_PVS
     end

     return
end

------------------------------------------------------------------------ istemci

local YER_ARALIK = 0.1
local HAVA = {fly = true, glide = true}

function ENT:Initialize()
     self.cizYaw = self:GetYon()
     self.cizPitch, self.cizBank = 0, 0
     self.yerZ = nil
     self.yerT = 0
     self.sonAnim = nil
     -- çizim bölütün üzerinde, ağdaki origin'den bölüt boyu (≤ ~400) kadar uzakta olabilir
     self:SetRenderBounds(Vector(-560, -560, -40), Vector(560, 560, 280))
end

-- Bölütteki noktayı zemine oturt; zeminin üstünde yaratığı örtecek kadar su varsa (ya da altında
-- zemin bulunmayacak kadar derinse) yüzer: swim sekansının su çizgisi yüzeye oturur. Uçarken
-- (fly / glide) bölüt noktası olduğu gibi kullanılır.
function ENT:ZemineOturt(p)
     local simdi = CurTime()
     if self.yerZ and simdi - self.yerT < YER_ARALIK and self.yerP and self.yerP:DistToSqr(p) < 16 then
          return Vector(p.x, p.y, self.yerZ)
     end
     local tr = util.TraceLine({
          start = p + Vector(0, 0, 28),
          endpos = p - Vector(0, 0, 64),
          mask = MASK_SOLID_BRUSHONLY,
     })
     local z = tr.Hit and tr.HitPos.z or p.z
     -- su: yukarıdan aşağı (istemcide PointContents bu haritada yanlış, iz kullanılır)
     local suda = false
     -- altında zemin yoksa (derin göl) nokta yüzeyin biraz altında da olabilir
     local su = util.TraceLine({start = Vector(p.x, p.y, z + 400), endpos = Vector(p.x, p.y, z - (tr.Hit and 0 or 64)), mask = MASK_WATER})
     if su.Hit and not su.StartSolid then
          local tur = self:TurVeri()
          local h = ((tur and tur.kutu and tur.kutu[3]) or 30) * self:Olcek()
          local cizgi = (tur and tur.suCizgi) and tur.suCizgi * self:Olcek() or h * 0.4
          local derin = su.HitPos.z - z
          if derin > math.max(cizgi, h * 0.45) or not tr.Hit then
               z = su.HitPos.z - cizgi
               suda = true
          end
     end
     self.YSuda = suda
     self.yerZ = z
     self.yerT = simdi
     self.yerP = p
     return Vector(p.x, p.y, z)
end

-- dünyada çizilen konum/açı (etkileşim ve kart da bunu kullanır)
function ENT:CizimKonumu()
     local p = self:Konum()
     local yaw = self.cizYaw or self:GetYon()
     if HAVA[self:GetAnim()] then
          self.YSuda = false
          return p, Angle(self.cizPitch or 0, yaw, self.cizBank or 0)
     end
     local z = self:ZemineOturt(p)
     -- kuluçka yuvasının saman yatağındaki yumurta yatağın üstüne oturur
     local Y = SardonYaratik
     if self:GetEvre() == 0 and Y and Y.YatakUstu then z.z = z.z + Y.YatakUstu(z) end
     return z, Angle(0, yaw, 0)
end

local TEK_SEFER = {pet = true, eat = false}

function ENT:AnimAyarla(tur, ad)
     ad = ad or self:GetAnim()
     local gercek = (tur.anim and tur.anim[ad]) or ad
     local seq = self:LookupSequence(gercek)
     if not seq or seq < 0 then
          seq = self:LookupSequence((tur.anim and tur.anim.idle) or "idle")
     end
     if not seq or seq < 0 then return end

     if self.sonAnim ~= ad or self.sonAnimT ~= self:GetAnimT() then
          self:ResetSequence(seq)
          self.sonAnim = ad
          self.sonAnimT = self:GetAnimT()
     end

     local sure = math.max(self:SequenceDuration(seq), 0.05)
     local gecen = (CurTime() - self:GetAnimT()) * self:GetAnimHizi()
     local kare
     if TEK_SEFER[ad] then
          kare = math.Clamp(gecen / sure, 0, 0.999)
     else
          kare = (gecen / sure) % 1
     end
     self:SetCycle(kare)
     self:SetPlaybackRate(0)
end

function ENT:Think()
     -- yön: hareketliyse bölüt yönü, değilse Yon; yumuşak dönüş. Uçarken burun tırmanışa göre
     -- kalkar / iner, dönüşte gövde yana yatar.
     local hedef = self:GetYon()
     local ft = FrameTime()
     local fark = math.AngleDifference(hedef, self.cizYaw or hedef)
     local adim = math.Clamp(fark, -320 * ft, 320 * ft)
     self.cizYaw = (self.cizYaw or hedef) + adim

     local hedefPitch, hedefBank = 0, 0
     if HAVA[self:GetAnim()] and self:Hareketli() then
          local d = self:GetB() - self:GetA()
          local yatay = math.sqrt(d.x * d.x + d.y * d.y)
          hedefPitch = math.Clamp(-math.deg(math.atan2(d.z, math.max(yatay, 1))), -35, 35)
          hedefBank = math.Clamp(-adim / math.max(ft, 0.001) * 0.25, -35, 35)
     end
     self.cizPitch = Lerp(math.min(ft * 4, 1), self.cizPitch or 0, hedefPitch)
     self.cizBank = Lerp(math.min(ft * 3, 1), self.cizBank or 0, hedefBank)

     -- görmeyenin ekranında Thestral'in gölgesi de yok
     local Y = SardonYaratik
     local gizli = (Y and Y.CizimEngeli and Y.CizimEngeli(self)) or false
     if gizli ~= self.YGizli then
          self.YGizli = gizli
          self:DrawShadow(not gizli)
     end
     self:SetNextClientThink(CurTime())
     return true
end

function ENT:Draw()
     local Y = SardonYaratik
     local tur = self:TurVeri()
     if not Y or not tur then return end
     if Y.CizimEngeli and Y.CizimEngeli(self) then return end

     -- model, renk bodygroup'u ve ölçek sunucudan gelir (Y.VarlikGorunum)
     local p, a = self:CizimKonumu()
     local evre = self:GetEvre()

     if evre == 0 then
          local r = tur.yumurta and tur.yumurta.renk or color_white
          render.SetColorModulation(r.r / 255, r.g / 255, r.b / 255)
          -- iyi sıcaklıktayken hafifçe sallanır
          local s = (Y.KuluckaSicakNow and Y.KuluckaSicakNow(self)) or 50
          local salla = s > Y.Ayar.Kulucka.iyiAlt and math.sin(CurTime() * 3 + self:EntIndex()) * 3 or 0
          -- çatlamaya az kala ara ara sarsılır
          if self:GetDurum() == 3 and (CurTime() - self:GetKBas()) / math.max(self:GetKSure(), 1) > 0.9 then
               local faz = (CurTime() + self:EntIndex() * 0.7) % 2.4
               if faz < 0.6 then salla = salla + math.sin(CurTime() * 38) * 9 * (1 - faz / 0.6) end
          end
          a = Angle(salla, a.y, salla * 0.6)
     else
          a = Angle(a.p, a.y, a.r)
          a:RotateAroundAxis(a:Up(), tur.yonOfset or -90)
          -- suya girince ne yapıyor olursa olsun yüzer
          self:AnimAyarla(tur, self.YSuda and "swim" or nil)
     end

     self:SetRenderOrigin(p)
     self:SetRenderAngles(a)
     -- kanatlı türlerde uzak LOD'lar kanadı oynatmaz (cl_binek_1ciz.lua)
     if Y.KanatLOD then Y.KanatLOD(self, p) end
     self:InvalidateBoneCache()
     self:SetupBones()
     self:DrawModel()
     self:SetRenderOrigin()
     self:SetRenderAngles()

     if evre == 0 then render.SetColorModulation(1, 1, 1) end
     if Y.YaratikCizildi then Y.YaratikCizildi(self, p, a, tur) end
end
