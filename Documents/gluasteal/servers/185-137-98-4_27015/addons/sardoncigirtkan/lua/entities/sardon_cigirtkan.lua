-- "addons\\sardoncigirtkan\\lua\\entities\\sardon_cigirtkan.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Çığırtkan :: alıcının önünde süzülen kırmızı zarf.
-- Sunucu yalnızca durumu ve konumu yürütür (alıcının yüzünün önüne yaylı takip). Çizim, ses ve
-- efektler istemcide SardonCigirtkan.Zarf'tadır (lua/sardon_cigirtkan/cl_4zarf.lua).
-- Toplu çığırtkanın küme zarfı: kümenin üstünde süzülür (C.KumeNoktasi), kümedeki herhangi bir alıcı
-- açar / tekrar ister. Grup bilgisi NW2'de (canlı yeniden yüklemede DT yuvaları kaymasın):
-- SardonCigirtkanGrup (bool), SardonCigirtkanGrupAd, SardonCigirtkanAlicilar ("12,15,19" ent index).
-- Yazılı çığırtkan (sistem tebligatı): NW2Bool SardonCigirtkanYazili; ses yerine belge yazılır, zarf
-- yazarken alıcının sağına kayar ki ekrandaki daktilonun kâğıdı onu örtmesin.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Vociferador"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
     self:NetworkVar("Int", 0, "Durum")
     self:NetworkVar("Int", 1, "Kimlik")
     self:NetworkVar("Float", 0, "DurumZaman")
     self:NetworkVar("Float", 1, "Basla")
     self:NetworkVar("Float", 2, "Sure")
     self:NetworkVar("Bool", 0, "Patlama")
     self:NetworkVar("Bool", 1, "Tekrar")
     self:NetworkVar("Entity", 0, "Hedef")
     self:NetworkVar("String", 0, "Gonderen")
end

local function Ayarlar()
     local C = SardonCigirtkan
     return C, C and C.Ayar, C and C.Z
end

if SERVER then
     function ENT:Initialize()
          self:SetModel("models/hunter/plates/plate025x025.mdl")
          self:SetMoveType(MOVETYPE_NOCLIP)
          self:SetSolid(SOLID_NONE)
          self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
          self:DrawShadow(false)
          local C, A, Z = Ayarlar()
          if not C then
               self:Remove()
               return
          end
          if self:GetDurum() == 0 then self:DurumYap(Z.DUSUS) end
          self.sonYayin = 0
     end

     function ENT:Kur(F)
          self.F = F
          self:SetHedef(F.hedef)
          self:SetKimlik(F.id)
          self:SetSure(F.sure or 0)
          self:SetGonderen(F.anonim and "" or (F.gonderenAd or ""))
          if F.yazi then
               self.yazili = true
               self:SetNW2Bool("SardonCigirtkanYazili", true)
          end
          if F.grup then
               local t = {}
               for _, p in ipairs(F.grup.uyeler) do
                    if IsValid(p) then t[#t + 1] = p:EntIndex() end
               end
               self:SetNW2Bool("SardonCigirtkanGrup", true)
               self:SetNW2String("SardonCigirtkanGrupAd", F.grup.ad or "")
               self:SetNW2String("SardonCigirtkanAlicilar", string.sub(table.concat(t, ","), 1, 500))
          end
     end

     function ENT:DurumYap(d)
          self:SetDurum(d)
          self:SetDurumZaman(CurTime())
     end

     function ENT:Ac(patlama)
          local C, A, Z = Ayarlar()
          self:SetPatlama(patlama == true)
          self:SetBasla(CurTime() + A.AcilisPayi)
          self:DurumYap(Z.CAL)
          if self.F then C.Yayin(self.F, self:GetPos(), self:Menzil()) end
          if C.Gunluk and self.F then C.Gunluk(patlama and "açılmadan patladı" or "açıldı", self.F) end
     end

     function ENT:Menzil()
          local C, A = Ayarlar()
          if self.F and self.F.grup then return math.max(A.MenzilGrup, self:GetPatlama() and A.MenzilPatlama or 0) end
          return self:GetPatlama() and A.MenzilPatlama or A.Menzil
     end

     function ENT:Kullan(ply)
          local C, A, Z = Ayarlar()
          local grup = self.F and self.F.grup
          if grup then
               if not C.GrupUyesi(self.F, ply) or ply:EyePos():DistToSqr(self:GetPos()) > A.GrupAcmaMenzil * A.GrupAcmaMenzil then return end
          elseif ply ~= self:GetHedef() then
               return
          end
          local d = self:GetDurum()
          if d == Z.BEKLE then
               -- alıcı zarfa aşağı yukarı bakıyor olmalı
               local yon = (self:GetPos() - ply:EyePos())
               if (not grup and yon:LengthSqr() > 200 * 200) or ply:GetAimVector():Dot(yon:GetNormalized()) < (grup and 0.5 or 0.55) then return end
               self:Ac(false)
          elseif d == Z.SOR then
               self:SetTekrar(true)
               self:SetBasla(CurTime() + 0.3)
               self:DurumYap(Z.CAL)
          end
     end

     function ENT:Think()
          local C, A, Z = Ayarlar()
          local simdi = CurTime()
          local d = self:GetDurum()
          local gecen = simdi - self:GetDurumZaman()
          -- toplu zarfta tohum ölse de küme geçerlidir (HedefGecerli gerekirse başka üyeye geçer)
          local gecerli = self.F and C.HedefGecerli(self.F) and (self.F.grup ~= nil or self.F.hedef:Alive())
          local h = self.F and self.F.hedef or self:GetHedef()
          if IsValid(h) and h ~= self:GetHedef() then self:SetHedef(h) end
          local grup = self.F and self.F.grup

          if grup then
               -- kümenin üstü; üyeler dağılırsa yavaşça kalanların ortasına kayar
               if gecerli and d ~= Z.YOK and (self.sonNokta or 0) < simdi then
                    self.sonNokta = simdi + 0.5
                    self.nokta = C.KumeNoktasi(self.F) or self.nokta
               end
               if self.nokta and d ~= Z.YOK then
                    local k = d == Z.DUSUS and math.Clamp(gecen / A.DusmeSuresi, 0.04, 0.2) or 0.05
                    self:SetPos(LerpVector(k, self:GetPos(), self.nokta))
               end
          elseif gecerli and d ~= Z.YOK then
               -- alıcının yüzünün önü (yalnızca yatay bakış; duvara girmesin)
               local goz = h:EyePos()
               local ileri = Angle(0, h:EyeAngles().y, 0):Forward()
               local hedefPos = goz + ileri * A.Uzaklik - Vector(0, 0, 2)
               if self.yazili and (d == Z.CAL or d == Z.SOR) then
                    hedefPos = hedefPos + Angle(0, h:EyeAngles().y, 0):Right() * A.DaktiloYan + Vector(0, 0, A.DaktiloYukseklik)
               end
               local tr = util.TraceLine({start = goz, endpos = hedefPos, filter = {h, self}, mask = MASK_SOLID_BRUSHONLY})
               if tr.Hit then hedefPos = tr.HitPos - ileri * 6 end
               local k = d == Z.DUSUS and math.Clamp(gecen / A.DusmeSuresi, 0.06, 0.3) or 0.22
               self:SetPos(LerpVector(k, self:GetPos(), hedefPos))
          end

          if d == Z.DUSUS then
               if gecen >= A.DusmeSuresi then self:DurumYap(Z.BEKLE) end
          elseif d == Z.BEKLE then
               if not gecerli or gecen >= A.AcmaSuresi then self:Ac(true) end
          elseif d == Z.CAL then
               if simdi > self:GetBasla() + self:GetSure() + 0.5 then
                    if not self:GetTekrar() and gecerli then
                         self:DurumYap(Z.SOR)
                    else
                         self:DurumYap(Z.YOK)
                    end
               end
          elseif d == Z.SOR then
               if not gecerli or gecen >= A.TekrarSoru then self:DurumYap(Z.YOK) end
          elseif d == Z.YOK then
               if gecen >= A.YokOlma then
                    self:Remove()
                    return
               end
          end

          -- yeni gelenlere sesi yolla (zaten alanları atlar)
          if self.F and d ~= Z.YOK and simdi > self.sonYayin then
               self.sonYayin = simdi + 0.5
               C.Yayin(self.F, self:GetPos(), self:Menzil())
          end

          self:NextThink(simdi)
          return true
     end

     function ENT:OnRemove()
          local C = SardonCigirtkan
          if C and self.F then C.Bitir(self.F, "yandı") end
     end

     function ENT:UpdateTransmitState()
          return TRANSMIT_PVS
     end
else
     function ENT:Initialize()
          self:SetRenderBounds(Vector(-80, -80, -80), Vector(80, 80, 80))
          local C = SardonCigirtkan
          if C and C.Zarf then C.Zarf.Ekle(self) end
     end

     function ENT:Draw() end

     function ENT:DrawTranslucent()
          local C = SardonCigirtkan
          if C and C.Zarf then C.Zarf.Ciz(self) end
     end

     function ENT:Think()
          local C = SardonCigirtkan
          if C and C.Zarf then C.Zarf.Dusun(self) end
          self:SetNextClientThink(CurTime())
          return true
     end

     function ENT:OnRemove()
          local C = SardonCigirtkan
          if C and C.Zarf then C.Zarf.Kaldir(self) end
     end
end
