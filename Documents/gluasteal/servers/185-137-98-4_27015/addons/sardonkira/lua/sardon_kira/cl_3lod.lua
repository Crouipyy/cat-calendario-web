-- "addons\\sardonkira\\lua\\sardon_kira\\cl_3lod.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kira v2 :: kira modellerinde uzaklığa göre LOD. GMod motoru LOD'u kendisi seçmiyor (11-03 denemesi),
-- atölye VTX geçiş noktalarını çok uzağa koyuyor; seçim burada ply:SetLOD ile, saniyede 4 kez.
-- Ölçüt: tam boyun ekrandaki piksel yüksekliği (öğrenci sistemiyle aynı formül; FPS uyarlama çarpanı da oradan).
-- Öğrenci sistemi bir model değişiminde SetLOD(-1) yapabildiği için değer her turda yeniden yazılır (ucuz).
local K = SardonKira

local cv = CreateClientConVar("sardon_kira_lod", "1", true, false, "Kiralık modellerde uzaklığa göre ayrıntı (1 açık, 0 kapalı)")
local ARALIK = 1.15
local sonraki = 0

local function hedefLod(ply, eski, pikselK)
     local d = ply:GetPos():Distance(EyePos())
     if d < 250 then return 0 end
     local px = 72 * ply:GetModelScale() * pikselK / d
     local m = (SardonOgrenci and SardonOgrenci.LOD and SardonOgrenci.LOD.carpan) or 1
     local e = K.LOD_ESIK
     local k = 3
     for i = 1, 3 do
          -- daha ayrıntılı LOD'a geçerken eşiğin %15 üstü istenir (sınırda titreme olmasın)
          local esik = e[i] * m * ((eski or 0) > (i - 1) and ARALIK or 1)
          if px > esik then k = i - 1 break end
     end
     return k
end

hook.Add("Think", "SardonKira.LOD", function()
     local t = RealTime()
     if t < sonraki then return end
     sonraki = t + 0.25
     local acik = cv:GetBool()
     local lp = LocalPlayer()
     local fov = IsValid(lp) and lp:GetFOV() or 75
     local pikselK = ScrH() / (2 * math.tan(math.rad(math.Clamp(fov, 5, 170)) / 2) * 0.75)
     for _, ply in player.Iterator() do
          local mdl = ply:GetModel()
          if K.KiraModeliMi(mdl) then
               local lod = 0
               if acik and ply ~= lp then lod = hedefLod(ply, ply.kiraLod, pikselK) end
               ply:SetLOD(lod)
               ply.kiraLod = lod
          elseif ply.kiraLod then
               ply:SetLOD(-1)
               ply.kiraLod = nil
          end
     end
end)

concommand.Add("sardon_kira_lod_durum", function()
     for _, ply in player.Iterator() do
          if ply.kiraLod then print(ply:Nick(), ply:GetModel(), "LOD " .. ply.kiraLod, math.floor(ply:GetPos():Distance(EyePos()))) end
     end
end)

-- ------------------------------------------------------------------ yedek görünüm (anlık yayın)
-- Model istemciye henüz inmediyse oyuncu ERROR yerine sıradan bir modelle çizilir; hıza göre durma/yürüme/koşma.
-- Yalnız inme süresince (genelde saniyeler) ve yalnız o oyuncu için çalışır.
K.ModelVarOnb = K.ModelVarOnb or {}
local function modelVar(mdl)
     local o = K.ModelVarOnb[mdl]
     local t = RealTime()
     if not o or (not o.var and o.t < t) then
          o = { var = file.Exists(mdl, "GAME"), t = t + 2 }
          K.ModelVarOnb[mdl] = o
     end
     return o.var
end

local yedekler = {}
hook.Add("PrePlayerDraw", "SardonKira.Yedek", function(ply)
     local mdl = ply:GetModel()
     if not K.KiraModeliMi(mdl) or modelVar(mdl) then return end
     local e = yedekler[ply]
     if not IsValid(e) then
          e = ClientsideModel(K.YEDEK_MODEL, RENDERGROUP_OPAQUE)
          if not IsValid(e) then return end
          e:SetNoDraw(true)
          yedekler[ply] = e
     end
     local hiz = ply:GetVelocity():Length2D()
     local ad = hiz > 160 and "run_all_01" or (hiz > 10 and "walk_all" or "idle_all_01")
     if e.kiraSeq ~= ad then
          e.kiraSeq = ad
          local s = e:LookupSequence(ad)
          e:ResetSequence(s and s > 0 and s or 0)
     end
     e:SetCycle((e:GetCycle() + FrameTime() * (hiz > 10 and 1.1 or 0.35)) % 1)
     e:SetPos(ply:GetPos())
     e:SetAngles(Angle(0, ply:EyeAngles().y, 0))
     e:SetupBones()
     e:DrawModel()
     return true
end)

timer.Create("SardonKira.YedekTemizle", 2, 0, function()
     for ply, e in pairs(yedekler) do
          if not IsValid(ply) or not K.KiraModeliMi(ply:GetModel()) or modelVar(ply:GetModel()) then
               if IsValid(e) then e:Remove() end
               yedekler[ply] = nil
          end
     end
end)
