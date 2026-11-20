-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_9b_ambiyans.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: kütüphane ambiyansı, istemci (sv_9b_ambiyans; HL kitapları [sardon] anims sh_kitap.lua)
--   Nokta 1200 birimden yakınsa sahnesi kurulur, uzaklaşınca silinir; aynı anda en çok 24 model, en yakın
--   noktalar önce (sınır dolunca uzaktaki sahne yakındakine yer açar; 11-05: 12'de yeni nokta görünmüyordu).
--     ucan  : üç kitap noktanın 90 birim üstünde dolaşır, kapaklarını kanat gibi çırpar
--     yasak : Yasak Bölüm kitabı yatar; 4-11 sn'de bir sarsılır ya da kapağını şaklatır
--     raf   : kütüphane kitabı 5-14 sn'de bir rafta sarsılır
--     canli : Canlı Kitap yerde merakla döner; ara ara zıplar ya da havalanıp açık süzülür, sonra iner
--   Ara sıra bir Canlı Kitap yakındaki öğrencinin peşine takılır, bir süre omzunun arkasında uçar, yerine
--   döner (öğrenciyi sunucu seçer: SardonKitap.AmbTakip).
--   Akran rafının altındaki nokta (sv_9b, SKAmbAkran) o rafta okuyan öğrenci varken uyanır: Canlı Kitap
--   yükselip okuma boyunca havada süzülür; yasak/raf kitabı sık sık sarsılır.

-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_12 = Vector(0, 0, 12)
local OPT_V_0_0_2 = Vector(0, 0, 2)
local OPT_V_0_0_n1 = Vector(0, 0, -1)
local OPT_V_0_0_8 = Vector(0, 0, 8)
local OPT_R_255_210_120_220 = Color(255, 210, 120, 220)
local OPT_V_0_0_28 = Vector(0, 0, 28)
local OPT_R_255_226_170 = Color(255, 226, 170)
local OPT_R_0_0_0_200 = Color(0, 0, 0, 200)
local SK = SardonKitap

SK.AMB_TURLER = SK.AMB_TURLER or {ucan = "Uçan kitaplar", yasak = "Yasak Bölüm kitabı", raf = "Rafta sarsılan kitap", canli = "Canlı Kitap"}
SK.AmbNoktalar = SK.AmbNoktalar or {}
SK.AmbSahneler = SK.AmbSahneler or {}
SK.AmbOnizle = SK.AmbOnizle or false

local MESAFE = 1200
local AZAMI_MODEL = 24

local UCANLAR = {"flying_book", "bragbor_journal", "restricted_e_animated"}
local YASAKLAR = {"restricted_a_animated", "restricted_e_animated", "salazar_journal"}
local RAFLAR = {"library_bash_large_a", "library_bash_large_b", "library_bash_small_a"}

local function KA() return SardonKitapAnim end

local function Sil(i)
     local s = SK.AmbSahneler[i]
     if not s then return end
     for _, m in ipairs(s.modeller or {}) do
          if IsValid(m.e) then m.e:Remove() end
     end
     SK.AmbSahneler[i] = nil
end

local function ModelSayisi()
     local n = 0
     for _, s in pairs(SK.AmbSahneler) do n = n + #s.modeller end
     return n
end

local function Model(id)
     local K = KA()
     if not K then return nil end
     K.Hazirla(id)
     local e = K.KitapYap(id)
     if IsValid(e) then e:SetNoDraw(false) end
     return e
end

local sonTarama = 0

local function Kur(i, n)
     local s = {tur = n.tur, n = n, modeller = {}, t0 = CurTime()}
     local adet = n.tur == "ucan" and 3 or 1
     if ModelSayisi() + adet > AZAMI_MODEL then return end
     local sec = n.tur == "ucan" and UCANLAR or n.tur == "yasak" and YASAKLAR or n.tur == "raf" and RAFLAR or {"living_book"}
     local tohum = math.floor(n.pos.x * 7 + n.pos.y * 13) % 97
     for k = 1, adet do
          local id = sec[(tohum + k - 1) % #sec + 1]
          local e = Model(id)
          if IsValid(e) then
               s.modeller[#s.modeller + 1] = {e = e, faz = (k - 1) / adet + tohum * 0.013, sonraki = CurTime() + math.Rand(1.5, 6)}
          end
     end
     SK.AmbSahneler[i] = s
end

net.Receive("SardonKitap.Ambiyans", function()
     for i in pairs(SK.AmbSahneler) do Sil(i) end
     SK.AmbNoktalar = {}
     for i = 1, net.ReadUInt(10) do
          SK.AmbNoktalar[i] = {tur = net.ReadString(), pos = net.ReadVector(), yaw = net.ReadFloat()}
     end
     sonTarama = 0
end)

net.Receive("SardonKitap.AmbiyansOnizle", function() SK.AmbOnizle = net.ReadBool() end)

net.Receive("SardonKitap.AmbTakip", function()
     local i, ply, sure = net.ReadUInt(10), net.ReadEntity(), net.ReadFloat()
     local s = SK.AmbSahneler[i]
     local m = s and s.tur == "canli" and s.modeller[1]
     if m and IsValid(ply) then m.takip = {ply = ply, bit = CurTime() + sure} end
end)

-- uçuş çerçevesi (cl_5sahne Accio ile aynı): başı önde, sayfalar aşağı, kapaklar iki yana
local function UcusAci(ileri, yatis)
     local X = Vector(0, 0, 1):Cross(ileri)
     if X:LengthSqr() < 0.01 then X = Vector(0, 1, 0) end
     X:Normalize()
     local Y = Vector(0, 0, -1)
     Y = Y - ileri * Y:Dot(ileri)
     Y:Normalize()
     local r = math.rad(yatis)
     X, Y = X * math.cos(r) + Y * math.sin(r), Y * math.cos(r) - X * math.sin(r)
     return X:AngleEx(X:Cross(Y))
end

-- 11-07 ("kitap seslerinde tekrar/döngü"): sesler üst üste binmesin; kameranın arkasından dönünce birikmiş
-- sahneler aynı anda ses çıkarmasın
local sesSon = 0
local function Ses(pos, ad, seviye, perde, ses)
     local simdi = CurTime()
     if simdi < sesSon then return end
     sesSon = simdi + 0.5
     sound.Play(ad, pos, seviye or 55, perde or 100, ses or 0.3)
end

-- Canlı Kitap. Reaction'ın ilk %10'u kitabı ~12 birim kaldırıp kapaklarını açar, %10-45 arası havada süzülür
-- (sırt kemiği yüksekliği ölçüldü 11-05; IdleCurious ve Loop yerinde döner). Kalkış = Reaction ileri,
-- iniş = ilk %10 geri. Yerdeki merak döngüsü inişten sonra baştan başlar; kendi hareketi döngü başında
-- (yön sıçramasın).
local CIKIS = 0.1
local function CanliKare(K, e, m, s, n, simdi)
     local q = K.Sekans(e, "tepki")
     local sure = q >= 0 and math.max(e:SequenceDuration(q), 1) or 12.3
     local cikSure = CIKIS * sure
     m.durum = m.durum or "yer"
     m.merak0 = m.merak0 or simdi
     if s.akran and m.durum == "durul" then
          -- inişe hazırlanırken okuyan geldi: yeniden havada kalır
          m.durum, m.dt0, m.kendi, m.durulX = "havada", simdi, nil, nil
     elseif s.akran and (m.durum == "yer" or m.durum == "in" or m.durum == "zipla") then
          m.durum, m.dt0, m.kendi, m.takip = "cik", simdi, nil, nil
          Ses(n.pos, "npc/crow/hop2.wav", 55, 115, 0.3)
     end
     if m.takip and not s.akran and (m.durum == "yer" or m.durum == "zipla") then
          m.durum, m.dt0, m.kendi = "cik", simdi, nil
          Ses(n.pos, "npc/crow/hop2.wav", 55, 125, 0.3)
     end
     if m.durum == "cik" then
          local f = (simdi - m.dt0) / cikSure
          if f < 1 then K.Poz(e, "tepki", CIKIS * f) return end
          if m.takip then
               -- havalandı: peşine takılır (sırt kemiği şu anki yerinden başlar)
               local bc = e:LookupBone("binding_center") or 0
               local mb = e:GetBoneMatrix(bc)
               m.durum, m.dt0 = "takip", simdi
               m.ucPos = mb and mb:GetTranslation() or (n.pos + OPT_V_0_0_12)
               m.ucAng = mb and mb:GetAngles() or Angle(0, n.yaw or 0, 0)
          else
               m.durum, m.dt0 = "havada", simdi
          end
     end
     if m.durum == "takip" then
          local t = m.takip
          local tg = t and t.ply
          -- yuva: havadaki duruşun (Reaction %10) sırt kemiğinin masadaki yeri/açısı; dönüşte buraya gelir, iniş sıçramaz
          if not m.yuva then
               local o = K.BCOrnek(e:GetModel(), q)
               if o then
                    local lp, la = K.BCYer(o, CIKIS)
                    local bp, ba = WorldToLocal(vector_origin, angle_zero, lp, la)
                    m.yuva = {LocalToWorld(bp, ba, n.pos, Angle(0, n.yaw or 0, 0))}
               else
                    m.yuva = {n.pos + OPT_V_0_0_12, Angle(0, n.yaw or 0, 0)}
               end
          end
          local don = not IsValid(tg) or not tg:Alive() or simdi > t.bit or s.akran or tg:GetPos():DistToSqr(n.pos) > 520 * 520
          local hedef = m.yuva[1]
          if not don then
               -- öğrencinin sağ yanında, omuz hizasında; yürürken hızı kadar önden gider (geride kalmasın)
               local ya = Angle(0, tg:EyeAngles().y, 0)
               hedef = tg:EyePos() - ya:Forward() * 14 + ya:Right() * 30 + OPT_V_0_0_2 + tg:GetVelocity() * 0.3
          end
          local dt = math.min(FrameTime(), 0.1)
          local fark = hedef - m.ucPos
          local uz = fark:Length()
          if uz > 0.2 then m.ucPos = m.ucPos + fark * (math.min(uz * 3, 320) * dt / uz) end
          -- yön: yanındayken öğrenciye dönüp açık sayfalarını gösterir; uzakta kapakları kanat gibi uçar
          local hedefAng
          if don and uz < 40 then
               hedefAng = m.yuva[2]
          elseif not don and uz < 45 then
               local Y = tg:EyePos() - m.ucPos
               Y:Normalize()
               local Z = OPT_V_0_0_n1 - Y * (-Y.z)
               Z:Normalize()
               local X = Y:Cross(Z)
               hedefAng = X:AngleEx(Z)
          else
               hedefAng = UcusAci(uz > 0.5 and fark / uz or Angle(0, n.yaw or 0, 0):Forward(), math.sin(simdi * 2.3) * 12)
          end
          m.ucAng = LerpAngle(math.min(dt * 5, 1), m.ucAng, hedefAng)
          -- kanat çırpma: havadaki duruş (%10-45); dönüşte yuvaya yaklaşınca %10'a durulur
          local x = ((simdi - m.dt0) / (0.35 * sure)) % 2
          if x > 1 then x = 2 - x end
          if don and uz < 40 then
               m.durul = math.max((m.durul or x) - dt * 1.5, 0)
               x = math.min(x, m.durul)
          else
               m.durul = nil
          end
          local p = m.ucPos + Vector(0, 0, math.sin(simdi * 3.1) * 1.2)
          K.Poz(e, "tepki", CIKIS + 0.35 * x)
          if not K.Yerlestir(e, p, m.ucAng, 1) then e:SetPos(p) end
          if simdi >= (m.kanat or 0) then
               m.kanat = simdi + math.Rand(3.5, 6)
               Ses(p, "npc/crow/hop2.wav", 50, math.random(130, 150), 0.16)
          end
          if don and uz < 1.5 and (m.durul or 1) <= 0.01 then
               -- yerine döndü: masadaki duruşa geç, havadan iner
               m.takip, m.yuva, m.durul = nil, nil, nil
               e:SetPos(n.pos)
               e:SetAngles(Angle(0, n.yaw or 0, 0))
               m.durum, m.dt0 = "in", simdi
          end
          return
     end
     if m.durum == "havada" then
          -- kendi süzülmesi (m.kendi sn) ya da Akran rafında okuyan varken havada kanat çırpar
          local tt = simdi - m.dt0
          local x = (tt / (0.35 * sure)) % 2
          if x > 1 then x = 2 - x end
          if s.akran or (m.kendi and tt <= m.kendi) then
               K.Poz(e, "tepki", CIKIS + 0.35 * x)
               if simdi >= (m.kanat or 0) then
                    m.kanat = simdi + math.Rand(8, 14)
                    Ses(n.pos + OPT_V_0_0_12, "npc/crow/hop2.wav", 48, math.random(135, 155), 0.1)
               end
               return
          end
          -- inişten önce havadaki duruşun başına (%10) durulur; iniş oradan geri oynar, sıçramaz
          m.durum, m.dt0, m.durulX = "durul", simdi, x
     end
     if m.durum == "durul" then
          local x = math.max((m.durulX or 0) - (simdi - m.dt0) * 1.2, 0)
          K.Poz(e, "tepki", CIKIS + 0.35 * x)
          if x > 0 then return end
          m.durum, m.dt0, m.durulX = "in", simdi, nil
     end
     if m.durum == "in" then
          local f = (simdi - m.dt0) / cikSure
          if f < 1 then K.Poz(e, "tepki", CIKIS * (1 - f)) return end
          m.durum, m.kendi, m.merak0 = "yer", nil, simdi
          m.sonraki = simdi + math.Rand(3, 8)
          Ses(n.pos, "physics/cardboard/cardboard_box_impact_soft2.wav", 52, 120, 0.25)
     end
     if m.durum == "zipla" then
          local f = (simdi - m.dt0) / (cikSure * 1.6)
          if f < 1 then
               K.Poz(e, "tepki", CIKIS * 0.9 * (f < 0.5 and f / 0.5 or (1 - f) / 0.5))
               return
          end
          m.durum, m.merak0 = "yer", simdi
          m.sonraki = simdi + math.Rand(3, 8)
          Ses(n.pos, "physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 3) .. ".wav", 52, 130, 0.22)
     end
     -- yerde
     local faz = ((simdi - m.merak0) / 4.5) % 1
     K.Poz(e, "merak", faz)
     if simdi >= (m.sonraki or 0) and faz < 0.04 then
          if math.random() < 0.55 then
               m.durum, m.dt0 = "zipla", simdi
          else
               m.durum, m.dt0, m.kendi = "cik", simdi, math.Rand(2.5, 5)
          end
          Ses(n.pos, "physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 3) .. ".wav", 50, 150, 0.2)
     end
end

hook.Add("Think", "SardonKitap.Ambiyans", function()
     if #SK.AmbNoktalar == 0 and next(SK.AmbSahneler) == nil then return end
     local K = KA()
     if not K then return end
     local simdi = CurTime()
     local goz -- 11-13 opt: göz konumu/bakış yalnız tarama ya da sahne varken alınır (çağrı içinde değişmez); boştayken ayırma yok

     -- kur / sil (saniyede bir): yakındakiler önce, model sınırına dek
     if simdi >= sonTarama then
          sonTarama = simdi + 1
          goz = EyePos()
          local aday = {}
          for i, n in ipairs(SK.AmbNoktalar) do
               local d = goz:DistToSqr(n.pos)
               if d < MESAFE * MESAFE then aday[#aday + 1] = {i, d} end
          end
          table.sort(aday, function(a, b) return a[2] < b[2] end)
          local izin, sayi = {}, 0
          for _, a in ipairs(aday) do
               local adet = SK.AmbNoktalar[a[1]].tur == "ucan" and 3 or 1
               if sayi + adet <= AZAMI_MODEL then
                    izin[a[1]] = true
                    sayi = sayi + adet
               end
          end
          for i in pairs(SK.AmbSahneler) do
               if not izin[i] then Sil(i) end
          end
          for _, a in ipairs(aday) do
               if izin[a[1]] and not SK.AmbSahneler[a[1]] then Kur(a[1], SK.AmbNoktalar[a[1]]) end
          end
          -- Akran: o rafta okuyan öğrenci varken uyanan noktalar (sv_9b_ambiyans)
          local etkin = {}
          for i in string.gmatch(GetGlobal2String("SKAmbAkran", ""), "%d+") do etkin[tonumber(i)] = true end
          for i, sh in pairs(SK.AmbSahneler) do sh.akran = etkin[i] or nil end
     end

     -- kameranın arkasındaki sahneler bu karede güncellenmez (hareketler zamana bağlı; dönünce yerinde olur).
     -- Peşine takılan kitap her karede (konumu kare kare ilerler).
     local bak
     for _, s in pairs(SK.AmbSahneler) do
          if not bak then goz, bak = goz or EyePos(), EyeAngles():Forward() end -- 11-13 opt: ilk sahnede bir kez
          local n = s.n
          local arkada = (n.pos - goz):Dot(bak) < -150
          for k, m in ipairs(s.modeller) do
               local e = m.e
               if not IsValid(e) then continue end
               if arkada and m.durum ~= "takip" then continue end
               if s.tur == "ucan" then
                    -- 70 birim yarıçaplı, hafif dalgalı daire; her kitap kendi evresinde
                    local a = simdi * 0.55 + m.faz * math.pi * 2
                    local r = 62 + 12 * math.sin(simdi * 0.4 + k)
                    local merkez = n.pos + Vector(0, 0, 90 + 14 * math.sin(simdi * 0.9 + k * 2))
                    local p = merkez + Vector(math.cos(a) * r, math.sin(a) * r, 0)
                    local ileri = Vector(-math.sin(a), math.cos(a), 0.12 * math.cos(simdi * 0.9 + k * 2))
                    ileri:Normalize()
                    K.Poz(e, e.skaAile == "rehber" and "cirp" or "suzul", (simdi * 1.3 + m.faz) % 1)
                    if not K.Yerlestir(e, p, UcusAci(ileri, -22 + 8 * math.sin(simdi * 2 + k)), 1) then e:SetPos(p) end
                    if simdi >= m.sonraki then
                         m.sonraki = simdi + math.Rand(3, 8)
                         if simdi >= (s.sesT or 0) then
                              s.sesT = simdi + math.Rand(6, 12)
                              Ses(p, "npc/crow/hop2.wav", 50, math.random(130, 150), 0.16)
                         end
                    end
               else
                    if not m.yer then
                         m.yer = true
                         e:SetPos(n.pos)
                         e:SetAngles(Angle(0, n.yaw or 0, 0))
                    end
                    if s.tur == "canli" then
                         CanliKare(K, e, m, s, n, simdi)
                         continue
                    end
                    -- yasak/raf: ara ara bir hareket oynar, sonra yeniden kapalı bekler (Akran rafında okuyan varken sık)
                    local h = m.hareket
                    if h then
                         local f = (simdi - h.t0) / h.sure
                         if f >= 1 then
                              m.hareket = nil
                              m.sonraki = simdi + (s.akran and math.Rand(1.2, 3) or math.Rand(4, 11))
                         else
                              K.Poz(e, h.islev, f)
                         end
                    else
                         K.Poz(e, "kapali", 0)
                         if simdi >= m.sonraki or (s.akran and not m.akranGordu) then
                              m.akranGordu = s.akran
                              local islev
                              if s.tur == "yasak" then islev = math.random() < 0.6 and "titre" or "sakla"
                              else islev = "sars" end
                              local q = K.Sekans(e, islev)
                              if q >= 0 then
                                   m.hareket = {islev = islev, t0 = simdi, sure = math.max(e:SequenceDuration(q), 0.3)}
                                   if simdi >= (m.sesT or 0) then
                                        m.sesT = simdi + (s.akran and math.Rand(6, 10) or 2)
                                        if islev == "sakla" then Ses(n.pos, "physics/wood/wood_box_impact_hard3.wav", 55, 140, 0.25)
                                        else Ses(n.pos, "physics/wood/wood_box_impact_soft" .. math.random(1, 3) .. ".wav", 52, 120, 0.22) end
                                   end
                              else
                                   m.sonraki = simdi + 10
                              end
                         end
                    end
               end
          end
     end
end)

-- önizleme (süper admin): noktalar ve türleri
hook.Add("PostDrawTranslucentRenderables", "SardonKitap.Ambiyans", function(_, gok)
     if gok or not SK.AmbOnizle then return end
     local mat = SK.M and SK.M.isik or Material("sprites/light_glow02_add")
     for i, n in ipairs(SK.AmbNoktalar) do
          if EyePos():DistToSqr(n.pos) < 3000 * 3000 then
               render.SetMaterial(mat)
               render.DrawSprite(n.pos + OPT_V_0_0_8, 18, 18, OPT_R_255_210_120_220)
               local a = Angle(0, EyeAngles().y - 90, 90)
               cam.Start3D2D(n.pos + OPT_V_0_0_28, a, 0.15)
                    draw.SimpleTextOutlined(i .. " · " .. (SK.AMB_TURLER and SK.AMB_TURLER[n.tur] or n.tur), "DermaLarge", 0, 0, OPT_R_255_226_170, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, OPT_R_0_0_0_200)
               cam.End3D2D()
          end
     end
end)
