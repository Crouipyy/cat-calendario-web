-- "addons\\sardonhayvan\\lua\\entities\\sardon_hayvan.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Hayvan :: bölgelerde doğan saldırgan hayvan (NextBot).
--
-- Haritada navmesh yok. Hedef düz görünüyorsa doğrudan yürür (loco:Approach);
-- duvar arkasındaysa ya da takıldıysa [sardon] gmap yol ağından rota çıkarır
-- (sv_yol.lua, ENT:Git). Mantık her tick değil, aralıklı çalışıyor:
--   hedef seçimi / tasma kontrolü 0.25 sn, dolaşma kontrolü 0.5 sn.
-- Hedef adayları bölgenin oyuncu listesinden gelir (sv_core her saniye
-- dolduruyor), hayvan kendisi player.GetAll() taramaz.
--
-- Modeller oyuncu modeli: HL2MP melee aktiviteleri kullanılıyor, silah yok.

AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.PrintName = "Hayvan"
ENT.Category = "Sardon"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.AutomaticFrameAdvance = true
ENT.RenderGroup = RENDERGROUP_BOTH

-- sv_core: NextBot:IsNPC() bu bayrağa bakıp true döner (büyüler NPC'lere vuruyor)
ENT.IsSardonHayvan = true

local ACT_KOS = ACT_HL2MP_RUN_MELEE
local ACT_YURU = ACT_HL2MP_WALK_MELEE
local ACT_DUR = ACT_HL2MP_IDLE_MELEE
local ACT_VUR = ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE

function ENT:SetupDataTables()
     self:NetworkVar("String", 0, "Tur")
     self:NetworkVar("Int", 0, "Can")
     self:NetworkVar("Int", 1, "MaksCan")
end

function ENT:TurVerisi()
     return SardonHayvan and SardonHayvan.Turler and SardonHayvan.Turler[self:GetTur()]
end

if (SERVER) then
     local vector_yukari = Vector(0, 0, 1)

     /*
     *   Büyüler IsNPC() true olan hedefte NPC metodları çağırabiliyor
     *   (StopMoving, ClearSchedule, GetActiveWeapon …). NextBot'ta bunlar yok;
     *   hepsine zararsız boş karşılık tanımlanır. (base_nextbot'un metodlarıyla
     *   çakışan ad yok; Entity/NextBot metatablosunda olanlar atlanır.)
     */
     do
          local npcMeta = FindMetaTable("NPC")
          local entMeta = FindMetaTable("Entity")
          local nbMeta = FindMetaTable("NextBot")
          local ozel = {
               GetActiveWeapon = function() return NULL end,
               GetWeapon = function() return NULL end,
               GetEnemy = function() return NULL end,
               GetTarget = function() return NULL end,
               GetWeapons = function() return {} end,
               GetShootPos = function(s) return s:WorldSpaceCenter() end,
               GetAimVector = function(s) return s:GetForward() end
          }
          local bos = function() end

          for ad, fn in pairs(npcMeta or {}) do
               if (isfunction(fn) and !string.StartWith(ad, "__") and entMeta[ad] == nil and (!nbMeta or nbMeta[ad] == nil) and ENT[ad] == nil) then
                    ENT[ad] = ozel[ad] or bos
               end
          end
     end

     function ENT:Initialize()
          local tur = self:TurVerisi()

          if (!tur) then
               self:Remove()
               return
          end

          self.Veri = tur

          local olcek = tur.olcek or 1
          local r, b = (tur.yaricap or 16) * olcek, (tur.boy or 64) * olcek

          self:SetModel(tur.model)
          if (olcek != 1) then self:SetModelScale(olcek, 0) end
          self:SetCollisionBounds(Vector(-r, -r, 0), Vector(r, r, b))
          self:SetBloodColor(BLOOD_COLOR_RED)

          self:SetHealth(tur.can)
          self:SetMaxHealth(tur.can)
          self:SetCan(tur.can)
          self:SetMaksCan(tur.can)

          self.loco:SetStepHeight(20)
          self.loco:SetJumpHeight(64)
          self.loco:SetAcceleration(700)
          self.loco:SetDeceleration(1200)
          self.loco:SetMaxYawRate(400)
          self.loco:SetDeathDropHeight(300)

          -- vuruş mesafesi: gövde yarıçapı + oyuncu yarıçapı + tür menzili
          self.Menzil = r + 16 + (tur.menzil or 45)
          self.SonrakiVurus = 0
          self.SonrakiAci = 0
          self.Hasarlar = {}
          self.Dogus = self:GetPos()
     end

     /*
     *   bölge / hedef
     */

     function ENT:Merkez()
          local b = self.Bolge
          if (b) then return b.pos, b.yaricap end
          return self.Dogus, 1000
     end

     function ENT:GecerliHedef(ply)
          if (!IsValid(ply) or !ply:IsPlayer() or !ply:Alive()) then return false end
          if (ply:GetMoveType() == MOVETYPE_NOCLIP or ply:GetNoDraw()) then return false end

          local merkez, yaricap = self:Merkez()
          local sinir = yaricap + SardonHayvan.Ayar.TasmaPayi

          return ply:GetPos():DistToSqr(merkez) <= sinir * sinir
     end

     function ENT:HedefSec()
          -- ölü gövde motor tarafından birkaç kare sonra kaldırılıyor; o arada saldırmasın
          if (self.Oldu) then self.Hedef = nil return end
          if (self:GecerliHedef(self.Hedef)) then return self.Hedef end

          self.Hedef = nil

          -- pasif hayvan yalnızca son 30 sn içinde kendisine vuranı kovalar
          if (self.Veri.saldirgan == false) then
               local v = self.SonVuran
               if (v and CurTime() - (self.SonVurulma or 0) < 30 and self:GecerliHedef(v)) then
                    self.Hedef = v
               end

               return self.Hedef
          end

          -- bölgesiz (konsoldan doğmuş test hayvanı) herkese bakar
          local liste = self.Bolge and self.Bolge.oyuncular or player.GetAll()

          local benim = self:GetPos()
          local enYakin, enAz

          for i = 1, #liste do
               local p = liste[i]

               if (self:GecerliHedef(p)) then
                    local d = benim:DistToSqr(p:GetPos())

                    if (!enAz or d < enAz) then
                         enYakin, enAz = p, d
                    end
               end
          end

          self.Hedef = enYakin
          return enYakin
     end

     /*
     *   hareket
     */

     function ENT:Akt(act)
          if (self.SonAkt != act) then
               self.SonAkt = act
               self:StartActivity(act)
          end
     end

     -- takılma: 1 sn'de 12 birimden az ilerlediyse zıpla; 3 kez üst üste olursa true
     function ENT:TakildiMi(simdi)
          if (simdi < (self.IlerlemeKontrol or 0)) then return false end
          self.IlerlemeKontrol = simdi + 1

          local pos = self:GetPos()
          local eski = self.IlerlemePos
          self.IlerlemePos = pos

          if (!eski or eski:DistToSqr(pos) > 144) then
               self.TakilmaSay = 0
               return false
          end

          self.TakilmaSay = (self.TakilmaSay or 0) + 1

          if (self.loco:IsOnGround()) then
               self.loco:Jump()
          end

          return self.TakilmaSay >= 3
     end

     function ENT:IlerlemeSifirla()
          self.IlerlemePos = nil
          self.IlerlemeKontrol = CurTime() + 1
          self.TakilmaSay = 0
     end

     /*
     *   Bir noktaya yürü. Nokta düz görünüyorsa doğrudan gider; duvar/bina
     *   arkasındaysa ya da hayvan takıldıysa gmap yol ağından rota çıkarır
     *   (sv_yol.lua). Karar 0.5 sn'de bir verilir, arada yalnızca Approach.
     */
     function ENT:Git(hedefPos, simdi)
          local benim = self:GetPos()
          local Y = SardonHayvan.Yol

          if (simdi >= (self.YolKarar or 0)) then
               self.YolKarar = simdi + 0.5

               local zorla = simdi < (self.ZorlaRota or 0)

               if (!zorla and (!Y or Y:Gorunur(benim, hedefPos))) then
                    self.Rota = nil
               elseif (Y and (!self.Rota or simdi >= (self.RotaYenile or 0) or self.RotaHedef:DistToSqr(hedefPos) > 300 * 300)) then
                    self.Rota, self.RotaIdx = Y:Rota(benim, hedefPos)
                    self.RotaI = 1
                    self.RotaHedef = hedefPos
                    self.RotaYenile = simdi + 3
               end

               -- sonraki düğüm zaten görünüyorsa aradakini atla (köşe kesme)
               local r = self.Rota
               if (r and r[self.RotaI + 1] and Y:Gorunur(benim, r[self.RotaI + 1])) then
                    self.RotaI = self.RotaI + 1
               end
          end

          local nokta = hedefPos
          local r = self.Rota

          if (r) then
               local w = r[self.RotaI]

               while (w and (w.x - benim.x) ^ 2 + (w.y - benim.y) ^ 2 < 70 * 70) do
                    self.RotaI = self.RotaI + 1
                    w = r[self.RotaI]
               end

               if (w) then
                    nokta = w
               else
                    -- rota bitti: son düğümden hedefe düz
                    self.Rota = nil
               end
          end

          self.loco:Approach(nokta, 1)
          self.loco:FaceTowards(nokta)
     end

     -- takıldıysa önce yol ağını dene; ağla da ilerleyemiyorsa true (vazgeç)
     function ENT:TakilmaCoz(simdi)
          if (!self:TakildiMi(simdi)) then return false end

          self:IlerlemeSifirla()

          local Y = SardonHayvan.Yol
          if (!Y) then return true end

          -- rota üzerindeyken takıldıysa o bağlantıyı tıkalı işaretle, başka yoldan dene
          if (self.Rota and self.RotaIdx and self.RotaI >= 2 and (self.EngelSay or 0) < 3) then
               Y:Engelle(self.RotaIdx[self.RotaI - 1], self.RotaIdx[self.RotaI])
               self.EngelSay = (self.EngelSay or 0) + 1
               self.ZorlaRota = simdi + 8
               self.YolKarar = 0
               self.Rota = nil
               return false
          end

          -- düz giderken takıldıysa bir kez yol ağına zorla
          if (simdi >= (self.ZorlaRota or 0)) then
               self.ZorlaRota = simdi + 6
               self.YolKarar = 0
               self.Rota = nil
               return false
          end

          return true
     end

     function ENT:Bekle(sure, kontrolAraligi)
          local bitis = CurTime() + sure
          local kontrol = 0

          self:Akt(ACT_DUR)

          while (CurTime() < bitis and !self.Oldu) do
               if (CurTime() >= kontrol) then
                    kontrol = CurTime() + (kontrolAraligi or 0.5)
                    if (self:HedefSec()) then return end
               end

               coroutine.yield()
          end
     end

     function ENT:Dolas()
          local merkez, yaricap = self:Merkez()
          local aci = math.Rand(0, math.pi * 2)
          local uzak = math.sqrt(math.Rand(0, 1)) * yaricap * 0.7
          local hedefPos = merkez + Vector(math.cos(aci) * uzak, math.sin(aci) * uzak, 0)

          -- kovalarken bölgeden çıktıysa yol ağıyla merkeze dön
          local disarida = self:GetPos():DistToSqr(merkez) > yaricap * yaricap
          if (disarida) then hedefPos = merkez end

          self.loco:SetDesiredSpeed(disarida and (self.Veri.kosu or 250) * 0.6 or (self.Veri.yuruyus or 90))
          self:Akt(disarida and ACT_KOS or ACT_YURU)
          self:IlerlemeSifirla()
          self.Rota = nil
          self.YolKarar = 0
          self.EngelSay = 0

          local bitis = CurTime() + (disarida and 25 or 8)
          local kontrol = 0

          while (CurTime() < bitis and !self.Oldu) do
               local simdi = CurTime()

               if (simdi >= kontrol) then
                    kontrol = simdi + 0.5
                    if (self:HedefSec()) then return end
               end

               local pos = self:GetPos()
               local fark = hedefPos - pos
               fark.z = 0

               if (fark:Length2DSqr() < 40 * 40) then break end
               if (self:TakilmaCoz(simdi)) then break end

               self:Git(hedefPos, simdi)

               coroutine.yield()
          end

          self:Bekle(math.Rand(2, 5))
     end

     /*
     *   saldırı
     */

     function ENT:Vur(hedef)
          local tur = self.Veri

          self:Akt(ACT_DUR)
          self:AddGesture(ACT_VUR, true)
          self.SonrakiVurus = CurTime() + (tur.bekleme or 1)

          -- animasyonun vuruş anına kadar hedefe dön
          local an = CurTime() + 0.3
          while (CurTime() < an) do
               if (!IsValid(hedef)) then return end
               self.loco:FaceTowards(hedef:GetPos())
               coroutine.yield()
          end

          if (self.Oldu or !IsValid(hedef) or !hedef:Alive()) then return end

          local menzil = self.Menzil * 1.3
          local benim, onun = self:GetPos(), hedef:GetPos()

          if (benim:DistToSqr(onun) > menzil * menzil or math.abs(benim.z - onun.z) > 80) then
               self:EmitSound("Zombie.AttackMiss")
               return
          end

          local dmg = DamageInfo()
          dmg:SetDamage(tur.hasar or 10)
          dmg:SetAttacker(self)
          dmg:SetInflictor(self)
          dmg:SetDamageType(DMG_SLASH)
          dmg:SetDamagePosition(hedef:WorldSpaceCenter())
          dmg:SetDamageForce(self:GetForward() * 4000 + vector_yukari * 1000)

          local onceki = hedef:Health()
          hedef:TakeDamageInfo(dmg)

          self:EmitSound("Zombie.AttackHit")

          -- türün etkisini bulaştır (kalkan/ölümsüzlük hasarı engellediyse bulaşmaz)
          if (tur.etki and SardonHayvan.EtkiUygula and hedef:Alive() and hedef:Health() < onceki) then
               SardonHayvan:EtkiUygula(hedef, tur.etki, self, tur.etkiHasar)
          end
     end

     function ENT:Kovala(hedef)
          local tur = self.Veri
          local kontrol = 0

          self.loco:SetDesiredSpeed(tur.kosu or 250)
          self:IlerlemeSifirla()
          self.Rota = nil
          self.YolKarar = 0
          self.EngelSay = 0

          while (IsValid(hedef) and !self.Oldu) do
               local simdi = CurTime()

               if (simdi >= kontrol) then
                    kontrol = simdi + 0.25

                    if (!self:GecerliHedef(hedef)) then break end
                    if (self:Health() != self:GetCan()) then self:SetCan(math.max(self:Health(), 0)) end
               end

               local benim, onun = self:GetPos(), hedef:GetPos()
               local menzil = self.Menzil

               if (benim:DistToSqr(onun) <= menzil * menzil and math.abs(benim.z - onun.z) < 72) then
                    if (simdi >= self.SonrakiVurus) then
                         self:Vur(hedef)
                         self:IlerlemeSifirla()
                    else
                         self:Akt(ACT_DUR)
                         self.loco:FaceTowards(onun)
                    end
               else
                    self:Akt(ACT_KOS)
                    self:Git(onun, simdi)

                    -- yol ağıyla da ulaşamıyorsa (uçurum, kapalı alan) bir süre bu hedefi bırak
                    if (self:TakilmaCoz(simdi)) then
                         self.Hedef = nil
                         self:Bekle(3)
                         break
                    end
               end

               coroutine.yield()
          end

          self.Hedef = nil
     end

     function ENT:RunBehaviour()
          while (true) do
               local hedef = self:HedefSec()

               if (hedef) then
                    self:Kovala(hedef)
               else
                    self:Dolas()
               end

               coroutine.yield()
          end
     end

     function ENT:BodyUpdate()
          local act = self:GetActivity()

          if (act == ACT_KOS or act == ACT_YURU) then
               -- BodyMoveXY zaten FrameAdvance çağırıyor
               self:BodyMoveXY()
               return
          end

          self:FrameAdvance()
     end

     function ENT:OnStuck()
          self.loco:ClearStuck()
     end

     /*
     *   hasar / ölüm
     */

     -- büyü mermisi gibi aracıların sahibine kadar in
     local function Oyuncusu(ent)
          for _ = 1, 3 do
               if (!IsValid(ent)) then return end
               if (ent:IsPlayer()) then return ent end

               ent = ent.Owner or ent:GetOwner()
          end
     end

     function ENT:OnInjured(dmginfo)
          local ply = Oyuncusu(dmginfo:GetAttacker()) or Oyuncusu(dmginfo:GetInflictor())

          if (ply) then
               self.Hasarlar[ply] = (self.Hasarlar[ply] or 0) + dmginfo:GetDamage()
               self.SonVuran = ply
               self.SonVurulma = CurTime()

               -- vurana dön (mevcut hedef zaten geçerliyse değiştirme)
               if (!self:GecerliHedef(self.Hedef) and self:GecerliHedef(ply)) then
                    self.Hedef = ply
               end
          end

          local ses = self.Veri and self.Veri.ses
          if (ses and CurTime() >= self.SonrakiAci) then
               self.SonrakiAci = CurTime() + 1.5
               self:EmitSound(ses .. ".pain")
          end

          -- can çubuğu bir sonraki kontrolü beklemesin
          timer.Simple(0, function()
               if (IsValid(self)) then self:SetCan(math.max(self:Health(), 0)) end
          end)
     end

     function ENT:OnKilled(dmginfo)
          if (self.Oldu) then return end
          self.Oldu = true
          self:SetCan(0)

          local oldurenOyuncu = Oyuncusu(dmginfo:GetAttacker()) or Oyuncusu(dmginfo:GetInflictor())

          hook.Run("OnNPCKilled", self, dmginfo:GetAttacker(), dmginfo:GetInflictor())

          if (SardonHayvan.Oldu) then
               SardonHayvan:Oldu(self, oldurenOyuncu)
          end

          local ses = self.Veri and self.Veri.ses
          if (ses) then self:EmitSound(ses .. ".die") end

          self:BecomeRagdoll(dmginfo)
     end

     function ENT:OnRemove()
          if (SardonHayvan.Kaldirildi) then
               SardonHayvan:Kaldirildi(self)
          end
     end
else
     local etiketMesafe

     surface.CreateFont("SardonHayvan.Ad", {font = "Montserrat SemiBold", size = 40, weight = 600, extended = true})

     local renkArka = Color(10, 12, 18, 200)
     local renkCan = Color(196, 72, 64)
     local renkCanAz = Color(120, 40, 36)
     local renkAd = Color(236, 226, 200)

     function ENT:Draw()
          self:DrawModel()
     end

     function ENT:DrawTranslucent()
          etiketMesafe = etiketMesafe or ((SardonHayvan and SardonHayvan.Ayar and SardonHayvan.Ayar.EtiketMesafe or 700) ^ 2)

          local eye = EyePos()
          local ust = self:GetPos()
          ust.z = ust.z + self:OBBMaxs().z + 14

          local d = eye:DistToSqr(ust)
          if (d > etiketMesafe) then return end

          local tur = self:TurVerisi()
          local maks = math.max(self:GetMaksCan(), 1)
          local frac = math.Clamp(self:GetCan() / maks, 0, 1)
          local alfa = 1 - math.Clamp((d / etiketMesafe - 0.7) / 0.3, 0, 1)

          local ang = EyeAngles()
          ang = Angle(0, ang.y - 90, 90)

          surface.SetAlphaMultiplier(alfa)
          cam.Start3D2D(ust, ang, 0.1)
               draw.SimpleText(tur and tur.ad or "Hayvan", "SardonHayvan.Ad", 0, -46, renkAd, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

               surface.SetDrawColor(renkArka)
               surface.DrawRect(-160, -36, 320, 22)
               surface.SetDrawColor(frac > 0.3 and renkCan or renkCanAz)
               surface.DrawRect(-157, -33, 314 * frac, 16)
          cam.End3D2D()
          surface.SetAlphaMultiplier(1)
     end
end
