-- "addons\\sardonbaykus\\lua\\sardon_baykus\\cl_bohca.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Baykuş Eşya Bohçası -- istemci: baykuşun ayağındaki kese ve gönderme menüsündeki
-- bohça listesi. Bohçanın kendisi Helix çantası olduğu için ayrı bir arayüzü yok
-- (bkz. sh_bohca.lua / sv_bohca.lua).
-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_46 = Vector(0, 0, 46)
SardonBaykus = SardonBaykus or {}

-- cl_ dosyaları sh_bohca.lua'dan ÖNCE yüklenebiliyor (alfabetik sıra) -- sabitler yedekli.
local BOHCA = SardonBaykus.BohcaID or "baykus_bohca"
local BOHCA_MODEL = SardonBaykus.BohcaModel or "models/items/jewels/purses/very_big_purse.mdl"

-- ============= BAYKUŞUN AYAĞINDAKİ KESE =============
-- Sunucu, bohça taşıyan baykuşa "SardonBohca" NWBool'u koyuyor; kese sadece istemcide,
-- baykuşun ayak kemiklerinin (modelde ValveBiped.Bip01_L/R_Hand) ortasına asılı çiziliyor.
-- pet_owl'un kendi Draw'ına ([st] pets) dokunmuyoruz.
local PURSE_SCALE = 0.45
local PURSE_HEIGHT = 21.8 * PURSE_SCALE
local purse

-- Baykuşlar oluşup silindikçe kümede tutulur: eskiden her karede ents.FindByClass("pet_owl") bütün
-- varlıkları tarıyordu (ölçüm 2026-10-14: ~2700 varlıkta ~110 µs / kare, kimse bohça yollamazken bile).
SardonBaykus.Baykuslar = SardonBaykus.Baykuslar or {}

hook.Add("OnEntityCreated", "SardonBaykus.BohcaBaykus", function(ent)
     if (ent:GetClass() == "pet_owl") then
          SardonBaykus.Baykuslar[ent] = true
     end
end)

hook.Add("EntityRemoved", "SardonBaykus.BohcaBaykus", function(ent)
     SardonBaykus.Baykuslar[ent] = nil
end)

-- Dosya canlıda yeniden yüklenirse ya da hook'lardan önce oluşmuş baykuşlar için bir kez topla
for _, owl in ipairs(ents.FindByClass("pet_owl")) do
     SardonBaykus.Baykuslar[owl] = true
end

hook.Add("PostDrawOpaqueRenderables", "SardonBaykus.BohcaPurse", function(_, bSkybox)
     if (bSkybox) then
          return
     end

     for owl in pairs(SardonBaykus.Baykuslar) do
          if (!IsValid(owl)) then
               SardonBaykus.Baykuslar[owl] = nil
          elseif (owl:GetNWBool("SardonBohca", false) and !owl:IsDormant()) then
               if (!IsValid(purse)) then
                    purse = ClientsideModel(BOHCA_MODEL, RENDERGROUP_OPAQUE)
                    purse:SetNoDraw(true)
                    purse:SetModelScale(PURSE_SCALE)
               end

               local left = owl:LookupBone("ValveBiped.Bip01_L_Hand")
               local right = owl:LookupBone("ValveBiped.Bip01_R_Hand")
               local pos

               if (left and right) then
                    pos = (owl:GetBonePosition(left) + owl:GetBonePosition(right)) / 2
               else
                    pos = owl:LocalToWorld(OPT_V_0_0_46)
               end

               -- Kese her zaman dik asılı (baykuşun eğimini almıyor), uçarken hafifçe sallanıyor.
               local t = CurTime() + owl:EntIndex()
               local ang = Angle(math.sin(t * 2.3) * 5, owl:GetAngles().y, math.sin(t * 3.1) * 7)

               purse:SetPos(pos - Vector(0, 0, PURSE_HEIGHT + 1))
               purse:SetAngles(ang)
               purse:SetupBones()
               purse:DrawModel()
          end
     end
end)

-- ============= GÖNDERME MENÜSÜ İÇİN BOHÇA LİSTESİ =============

-- Envanterdeki DOLU bohçalar: {{id, label, summary}} (cl_baykus.lua'daki BAYKUSMENU_OPEN kullanır).
function SardonBaykus.GetSendableBohcas()
     local out = {}
     local char = LocalPlayer():GetCharacter()
     local inventory = char and char:GetInventory()

     if (!inventory or !SardonBaykus.GetBohcaItems) then
          return out
     end

     for _, item in pairs(inventory:GetItemsByUniqueID(BOHCA, true)) do
          local count = #SardonBaykus.GetBohcaItems(item)
          local money = SardonBaykus.GetBohcaMoney(item)

          if (count > 0 or money > 0) then
               local label = "Bolsa: " .. count .. " objetos" .. (money > 0 and (" + " .. money .. " Galleon") or "")
               local parts = SardonBaykus.SummarizeBohca(item)

               -- Galleon zaten etikette, özetten çıkar.
               if (money > 0) then
                    table.remove(parts)
               end

               table.insert(out, {id = item.id, label = label, summary = table.concat(parts, ", ")})
          end
     end

     table.sort(out, function(a, b) return a.id < b.id end)

     return out
end
