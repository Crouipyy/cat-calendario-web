-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_3aktor.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Aktörler (istemci): ClientsideModel, hareket (sunucuyla aynı yol hesabı), animasyon ADIYLA
*   (model kopyaları arası sekans indeksi farkı sorun olmasın), bakış (head_yaw/head_pitch),
*   sese göre ağız, isim / görev işareti, beliriş efektleri, E ile konuşma, anı haresi.
*
*   Yerel aktörler (c.yerel): sinema sahnelerinde cl_7 tarafından konumu sürülen figüranlar.
*
*   Animasyon kuralları (istemci modelinde motor sekans geçişini harmanlamaz, katman da yoktur):
*     - sekans değişince son poz saklanır, BuildBonePositions'ta 0.2-0.4 sn'de yeni poza harmanlanır
*     - katman jestleri (gesture_agree vb.) ana sekans olarak başı/sonu T-poza düşer → "_original" hali
*     - delta sekanslar ve modelin kendi pozları (reference/ragdoll) hiç çalınmaz; çalınacak bir şey
*       yoksa model T-pozda gösterilmez, yeniden kurulur (DynaBase önbelleği boşaltınca da)
*     - yürürken jest yok; söz jesti söz bitince biter; yerinde dönerken küçük adımlar
*/
local G = SardonGorev
local R = G.R
local OP = G.AKTOR

G.Aktorler = G.Aktorler or {}   -- [no] = c

local VARSAYILAN_MODEL = "models/player/group01/male_07.mdl"
local HARMAN_SURUM = 10  -- BuildBonePositions geri çağrısı / model kurulumu değişirse artır: eski modeller yeniden kurulur

local ADAY = {
     bekle = { "idle_all_01", "idle_all_02", "idle_subtle", "idle_unarmed", "idle_relaxed_01", "lineidle01", "batonidle1", "idle01", "idle" },
     yuru = { "walk_all", "walk_all_moderate", "walkunarmed_all", "walk_suitcase", "walk_all_angry", "walk" },
     kos = { "run_all_01", "run_all", "run_all_02", "runall", "run" },
}
local KELIME = { bekle = "idle", yuru = "walk", kos = "run" }

-- modelin kendi pozları: animasyon değil, seçilirse aktör T-pozda kalır
local POZ = { reference = true, ragdoll = true, proportions = true }

-- Ad → çalınacak sekans (aktör başına önbellekli, -1 = çalınmaz)
local function Sekans(c, ent, ad)
     local t = c.sekans
     local s = t[ad or ""]
     if s then return s end
     local p = c.profil
     local gercek = p and p.esle and p.esle[ad or ""] or ad
     s = ent:LookupSequence(gercek or "") or -1
     if s >= 0 then
          local b = ent:GetSequenceInfo(s)
          local an = b and b.anims and b.anims[1]
          local ai = an and ent:GetAnimInfo(an)
          if b and bit.band(b.flags or 0, 4) ~= 0 then
               s = -1
          elseif ai and bit.band(ai.flags or 0, 4) ~= 0 then
               -- katman jesti: gövde pozu otomatik katmandan gelir, ağırlığı başta/sonda sıfır
               s = ent:LookupSequence(gercek .. "_original") or -1
          end
          if s >= 0 and POZ[string.lower(ent:GetSequenceName(s) or "")] then s = -1 end
     end
     t[ad or ""] = s
     return s
end

local function SekansCoz(c, ent, tur)
     for _, ad in ipairs(ADAY[tur]) do
          if Sekans(c, ent, ad) >= 0 then return ad end
     end
     for _, ad in pairs(ent:GetSequenceList() or {}) do
          if string.find(string.lower(ad), KELIME[tur], 1, true) and Sekans(c, ent, ad) >= 0 then return ad end
     end
     return ""
end

local AGIZ_FLEX = { "jaw_drop", "mouth_open", "jaw_open", "jaw", "mouthopen", "open_mouth" }

local function ModelVar(m)
     return isstring(m) and m ~= "" and file.Exists(m, "GAME")
end

/*
*   Model profilleri: oyuncu modeli olmayan (pose parametresi, jest katmanı, ValveBiped kemikleri
*   olmayan) modeller için yön düzeltmesi, jest adı eşlemesi, hıza göre yürüyüş, merdiven, uzun
*   beklemede çeşit, beliriş / kayboluş animasyonu ve kemikle baş, söz ve jest hareketleri.
*   Anahtar, model yolunda aranan desen.
*/
G.ModelProfil = G.ModelProfil or {}

-- Hogwarts Legacy ev cinleri (St_props2, ws 3821754049): 41 kemik, 12 sekans, önü +Y, boy ~39.
-- Yer hızları adım temasından ölçüldü (sunucuda olc.py): walk_slow 38 · walk 53.5 · walk_fast 91 · run 149
G.ModelProfil["hogwarts_pets/.*houseelf"] = {
     yaw = -90,
     bekle = "idle", yuru = "walk", kos = "run", donus = "walk_slow",
     yuruyus = { { "walk_slow", 38 }, { "walk", 53.5 }, { "walk_fast", 91 }, { "run", 149 } },
     -- merdivende yükseliş animasyonun içinde (döngü başına ~11.6 birim): gövde zemine geri çekilir
     merdiven = { yukari = "stairs_up", asagi = "stairs_down", yukselis = 11.6, egim = 0.3 },
     cesit = { { "clean_idle", 5.3 }, { "alert", 5.9 } },   -- uzun beklemede sırayla: el ovuşturur, etrafı kollar
     esle = { gesture_wave = "wave", gesture_becon = "wave", taunt_cheer = "appear", sit = "crouch" },
     tut = { wave = 2.5, appear = 2.4 },   -- jest bu kadar sürer (wave döner, appear son karede kalır)
     dongu = { wave = true },
     belir = "appear", kaybol = "crouch",  -- cisimlenince / kaybolurken
     kemikJest = { gesture_agree = "onay", gesture_bow = "selam" },
     kemik = { bas = "Head", boyun = "Neck", boyun2 = "Neck1", gogus = "Spine3", gogus2 = "Spine2", bel = "Spine", bel2 = "Spine1" },
     goz = 3,                              -- göz, baş kemiğinin bu kadar üstünde
}

local function ProfilBul(model)
     for desen, p in pairs(G.ModelProfil) do
          if string.find(model, desen) then return p end
     end
end

local function YuruyusSec(p, hiz)
     local en, enFark
     for _, y in ipairs(p.yuruyus) do
          local fark = math.abs(math.log(math.max(hiz, 1) / y[2]))
          if not enFark or fark < enFark then en, enFark = y[1], fark end
     end
     return en
end

/*
*   Kemik hareketleri (profilli modeller): model uzayındaki bir dönüş, kemiğin bekleme pozundaki
*   çerçevesine çevrilip ManipulateBoneAngles ile animasyonun üstüne eklenir. ManipulateBoneAngles'ın
*   hangi çerçevede döndürdüğü (kemiğin kendisi / ebeveyni / Euler toplamı) bir kez ölçülür.
*/
local KemikKural
local KemikSablon = {}   -- [model] = { [rol] = { i, C, Cters } } | false

local function Doner(M) local R = Matrix() R:Set(M) R:SetTranslation(vector_origin) return R end

local function TaziModel(model, seqAd)
     local m = ClientsideModel(model, RENDERGROUP_OPAQUE)
     if not IsValid(m) then return end
     m:SetNoDraw(true)
     m:SetPos(vector_origin)
     m:SetAngles(angle_zero)
     local q = seqAd and m:LookupSequence(seqAd) or -1
     if q >= 0 then m:ResetSequence(q) end
     m:SetCycle(0)
     m:InvalidateBoneCache()
     m:SetupBones()
     return m
end

local function YerelDonus(m, i)
     local M, p = m:GetBoneMatrix(i), m:GetBoneParent(i)
     if not M then return end
     local P = p >= 0 and m:GetBoneMatrix(p)
     return Doner(P and P:GetInverseTR() * M or M)
end

local function KuralOlc(model)
     local m = TaziModel(model)
     if not IsValid(m) then return end
     local b
     for i = m:GetBoneCount() - 1, 1, -1 do
          if m:GetBoneParent(i) >= 0 then b = i break end
     end
     local R0 = b and YerelDonus(m, b)
     local D = Angle(24, 31, 17)
     if R0 then
          m:ManipulateBoneAngles(b, D)
          m:InvalidateBoneCache()
          m:SetupBones()
     end
     local R1 = R0 and YerelDonus(m, b)
     m:Remove()
     if not R1 then return end
     local RD, E = Matrix(), Matrix()
     RD:SetAngles(D)
     E:SetAngles(R0:GetAngles() + D)
     local function Hata(R) return (R:GetForward() - R1:GetForward()):LengthSqr() + (R:GetUp() - R1:GetUp()):LengthSqr() end
     if Hata(R0) < 1e-4 then return end   -- ayar hiç işlemedi: ölçülemedi
     local en, enHata
     for ad, R in pairs({ kemik = R0 * RD, ebeveyn = RD * R0, euler = E }) do
          local h = Hata(R)
          if not enHata or h < enHata then en, enHata = ad, h end
     end
     print(string.format("[Sardon Görev] kemik açısı çerçevesi: %s (hata %.4f)", en, enHata))
     return en
end

local function KemikSablonu(model, p)
     local s = KemikSablon[model]
     if s ~= nil then return s or nil end
     KemikSablon[model] = false   -- hata verirse her karede yeniden denenmesin
     local ok, sonuc = pcall(function()
          KemikKural = KemikKural or KuralOlc(model) or "kemik"
          local m = TaziModel(model, p.bekle)
          if not IsValid(m) then return false end
          local t = {}
          for rol, ad in pairs(p.kemik or {}) do
               local i = m:LookupBone(ad)
               local M = i and m:GetBoneMatrix(i)
               if M then
                    local par = m:GetBoneParent(i)
                    local P = par >= 0 and m:GetBoneMatrix(par)
                    local C = Doner(KemikKural == "kemik" and M or P or Matrix())
                    t[rol] = { i = i, C = C, Cters = C:GetInverseTR() }
               end
          end
          m:Remove()
          return next(t) and t or false
     end)
     if not ok then ErrorNoHalt("[Sardon Görev] kemik şablonu: " .. tostring(sonuc) .. "\n") end
     s = ok and sonuc or false
     KemikSablon[model] = s
     return s or nil
end

-- 11-14 opt: KemikUygula'nın her çağrıda yeni kapanış olarak kurulan iç Ekle'si buraya katıldı (Don'un tek kullanıcısıydı;
-- dosya düzeyine yeni yerel eklenmedi, OPT bu satırdan sonra tanımlı). K ve don artık parametre; denetim, dönüş ve
-- çarpım sırası aynı.
local function Don(K, don, rol, eksen, derece)
     if not K[rol] or math.abs(derece) < 0.01 then return end
     local a = Angle(0, 0, 0)
     a:RotateAroundAxis(eksen, derece)
     local M = Matrix()
     M:SetAngles(a)
     don[rol] = don[rol] and M * don[rol] or M
end

local UST = Vector(0, 0, 1)

-- bak: bakılan dünya noktası · c.agiz: söz seviyesi · c.kjest: kemik jesti (onay / selam)
local function KemikUygula(c, ent, dt, bak, yurur)
     local K = c.kemik
     if not K then return end
     local ileri, sag = c.ileri, c.sag
     local don = {}
     -- sırayla eklenen dönüşler model uzayında art arda uygulanır (11-14 opt: Don(K, don, ...), kapanış yok)
     local simdi = RealTime()

     -- bakış: pose parametresi yok, baş / boyun / göğüs paylaşır (önce eğim, sonra dönüş)
     local hy, hp = 0, 0
     if bak then
          local l = ent:WorldToLocal(bak) - UST * (c.gozZ or 30)
          local on, sol = l:Dot(ileri), -l:Dot(sag)
          hy = math.Clamp(math.deg(math.atan2(sol, on)), -70, 70)
          hp = math.Clamp(math.deg(math.atan2(l.z, math.sqrt(on * on + sol * sol))), -30, 40)
     end
     c.kBasY = Lerp(math.min(1, dt * 5), c.kBasY or 0, hy)
     c.kBasP = Lerp(math.min(1, dt * 5), c.kBasP or 0, hp)
     Don(K, don, "boyun", sag, c.kBasP * 0.25)
     Don(K, don, "boyun2", sag, c.kBasP * 0.25)
     Don(K, don, "bas", sag, c.kBasP * 0.5)
     Don(K, don, "gogus", UST, c.kBasY * 0.1)
     Don(K, don, "boyun", UST, c.kBasY * 0.2)
     Don(K, don, "boyun2", UST, c.kBasY * 0.25)
     Don(K, don, "bas", UST, c.kBasY * 0.45)

     -- söz: hecelerde baş öne iner, cümle boyunca hafifçe yana yatar
     local s = c.agiz or 0
     Don(K, don, "bas", sag, -s * 7)
     Don(K, don, "gogus", sag, -s * 2)
     if c.konus then Don(K, don, "bas", ileri, math.sin(simdi * 1.7) * 3) end

     -- kemik jestleri: onay (üç kez baş sallar), selam (belden derin eğilir)
     local j = c.kjest
     if j then
          local t = simdi - j.bas
          if j.tur == "onay" and t < 1.5 then
               local a = -12 * (0.5 - 0.5 * math.cos(2 * math.pi * 3 * t / 1.5)) * math.sin(math.pi * t / 1.5)
               Don(K, don, "bas", sag, a * 0.65)
               Don(K, don, "boyun2", sag, a * 0.35)
          elseif j.tur == "selam" and t < 2.6 then
               local e = t < 0.6 and G.Yumusak(t / 0.6) or (t < 1.6 and 1 or 1 - G.Yumusak((t - 1.6) / 1))
               Don(K, don, "bel", sag, -8 * e)
               Don(K, don, "bel2", sag, -14 * e)
               Don(K, don, "gogus2", sag, -14 * e)
               Don(K, don, "gogus", sag, -10 * e)
               Don(K, don, "boyun", sag, -6 * e)
               Don(K, don, "bas", sag, -8 * e)
          else
               c.kjest = nil
          end
     end

     -- yürürken dönüşe doğru yatar
     local yr = c.kOncekiYaw and math.AngleDifference(c.yaw, c.kOncekiYaw) / math.max(dt, 0.001) or 0
     c.kOncekiYaw = c.yaw
     c.kEgim = Lerp(math.min(1, dt * 4), c.kEgim or 0, yurur and math.Clamp(-yr * 0.06, -12, 12) or 0)
     Don(K, don, "bel", ileri, c.kEgim * 0.5)
     Don(K, don, "bel2", ileri, c.kEgim * 0.5)

     for rol, b in pairs(K) do
          local M = don[rol]
          ent:ManipulateBoneAngles(b.i, M and (b.Cters * M * b.C):GetAngles() or angle_zero)
     end
end

/*
*   Geçiş harmanı. Her kemiğin dönüşü model uzayında (varlığın konum/açısına göre: aktör yürürken
*   de poz yerinde kalır), konumu ebeveyne göre öteleme olarak saklanır. Dönüş model uzayında
*   harmanlanır, konum harmanlanmış ebeveynden zincirle kurulur: kemik boyu korunur, ebeveyne göre
*   yerel harmandaki gibi bükülme (twist) farkı ara pozlarda kolu savurmaz.
*/
local function Quat(m)
     local t = m:ToTable()
     local r1, r2, r3 = t[1], t[2], t[3]
     local sx = math.sqrt(r1[1] ^ 2 + r2[1] ^ 2 + r3[1] ^ 2)
     local sy = math.sqrt(r1[2] ^ 2 + r2[2] ^ 2 + r3[2] ^ 2)
     local sz = math.sqrt(r1[3] ^ 2 + r2[3] ^ 2 + r3[3] ^ 2)
     if sx < 1e-6 or sy < 1e-6 or sz < 1e-6 then return { 1, 0, 0, 0 }, 1 end
     local m11, m21, m31 = r1[1] / sx, r2[1] / sx, r3[1] / sx
     local m12, m22, m32 = r1[2] / sy, r2[2] / sy, r3[2] / sy
     local m13, m23, m33 = r1[3] / sz, r2[3] / sz, r3[3] / sz
     local iz = m11 + m22 + m33
     local q
     if iz > 0 then
          local s = math.sqrt(iz + 1) * 2
          q = { 0.25 * s, (m32 - m23) / s, (m13 - m31) / s, (m21 - m12) / s }
     elseif m11 > m22 and m11 > m33 then
          local s = math.sqrt(1 + m11 - m22 - m33) * 2
          q = { (m32 - m23) / s, 0.25 * s, (m12 + m21) / s, (m13 + m31) / s }
     elseif m22 > m33 then
          local s = math.sqrt(1 + m22 - m11 - m33) * 2
          q = { (m13 - m31) / s, (m12 + m21) / s, 0.25 * s, (m23 + m32) / s }
     else
          local s = math.sqrt(1 + m33 - m11 - m22) * 2
          q = { (m21 - m12) / s, (m13 + m31) / s, (m23 + m32) / s, 0.25 * s }
     end
     return q, (sx + sy + sz) / 3
end

local function QuatMatris(q, t, s)
     local w, x, y, z = q[1], q[2], q[3], q[4]
     return Matrix({
          { (1 - 2 * (y * y + z * z)) * s, 2 * (x * y - z * w) * s, 2 * (x * z + y * w) * s, t.x },
          { 2 * (x * y + z * w) * s, (1 - 2 * (x * x + z * z)) * s, 2 * (y * z - x * w) * s, t.y },
          { 2 * (x * z - y * w) * s, 2 * (y * z + x * w) * s, (1 - 2 * (x * x + y * y)) * s, t.z },
          { 0, 0, 0, 1 },
     })
end

local function KokMatris(ent)
     local m = Matrix()
     m:SetTranslation(ent:GetPos())
     m:SetAngles(ent:GetAngles())
     return m
end

-- Şu an çizilen poz (sekans değiştirilmeden hemen önce çağrılır)
local function PozAl(ent)
     ent:SetupBones()
     local kok = KokMatris(ent)
     local kokTers = kok:GetInverseTR()
     local dunya, poz = {}, {}
     for i = 0, ent:GetBoneCount() - 1 do
          local m = ent:GetBoneMatrix(i)
          if m then
               dunya[i] = m
               local p = ent:GetBoneParent(i)
               local ters = (p >= 0 and dunya[p] or kok):GetInverse()
               if ters then
                    local model = kokTers * m
                    local q, s = Quat(model)
                    poz[i] = { q = q, s = s, t = (ters * m):GetTranslation(), y = model:GetTranslation() }
               end
          end
     end
     return poz
end

local function HarmanUygula(ent, n)
     local c = ent.SardonGorevAktor
     local h = c and c.harman
     if not h then return end
     -- ilerleme birikir: süre ilk karelerde uzarsa poz geri sarmaz
     local simdi = RealTime()
     h.ilerleme = h.ilerleme + (simdi - h.son) / h.sure
     h.son = simdi
     local f = h.ilerleme
     if f >= 1 then c.harman = nil return end
     local w = 1 - f * f * (3 - 2 * f)   -- eski pozun ağırlığı
     -- ilk 0.15 sn iki poz arasındaki en büyük kemik farkı ölçülür (bu arada geçiş en uzun süreyle
     -- yürür), sonra süre farka göre kurulur: uzak pozlar arası geçiş uzar, kol savrulmaz. Aynı karede
     -- SetupBones yeniden hesaplamadığı için burada, ham poz üstünden; kısmi kurulumlarda bayat
     -- kemikler küçük ölçülür, en büyüğü alınır.
     local olc, fark = simdi - h.bas < 0.15, h.fark
     local kok = KokMatris(ent)
     local kokTers = kok:GetInverseTR()
     local ham, son, oteleme = {}, {}, Matrix()   -- son: harmanlanmış model uzayı matrisleri
     for i = 0, n - 1 do
          local m = ent:GetBoneMatrix(i)
          if m then
               ham[i] = m
               local p = ent:GetBoneParent(i)
               local ustHam = p >= 0 and ham[p] or kok
               local ters = ustHam and ustHam:GetInverse()
               local model = kokTers * m
               local e = h.poz[i]
               if olc and e then fark = math.max(fark, model:GetTranslation():Distance(e.y)) end
               if e and ters then
                    local q, s = Quat(model)
                    -- dördeyin işareti kareden kareye sürekli; hedefin yarımküresi geçiş başında kilitlenir
                    -- (~180° farkta kısa yol tek karede öbür tarafa atlamasın)
                    local qo = e.qOnce
                    if qo and q[1] * qo[1] + q[2] * qo[2] + q[3] * qo[3] + q[4] * qo[4] < 0 then q = { -q[1], -q[2], -q[3], -q[4] } end
                    e.qOnce = q
                    local eq = e.hedef
                    if not eq then
                         eq = e.q
                         if q[1] * eq[1] + q[2] * eq[2] + q[3] * eq[3] + q[4] * eq[4] < 0 then eq = { -eq[1], -eq[2], -eq[3], -eq[4] } end
                         e.hedef = eq
                    end
                    -- küresel ara değer (sabit açısal hız; büyük açıda nlerp ortada iki kat hızlanır)
                    local d = math.Clamp(q[1] * eq[1] + q[2] * eq[2] + q[3] * eq[3] + q[4] * eq[4], -1, 1)
                    local ka, kb = 1 - w, w
                    if math.abs(d) < 0.9995 then
                         local aci = math.acos(d)
                         local sn = math.sin(aci)
                         ka, kb = math.sin((1 - w) * aci) / sn, math.sin(w * aci) / sn
                    end
                    local a, b2, c2, d2 = q[1] * ka + eq[1] * kb, q[2] * ka + eq[2] * kb, q[3] * ka + eq[3] * kb, q[4] * ka + eq[4] * kb
                    local u = math.sqrt(a * a + b2 * b2 + c2 * c2 + d2 * d2)
                    if u > 1e-6 then
                         local t = LerpVector(w, (ters * m):GetTranslation(), e.t)
                         local konum = t
                         if p >= 0 then
                              oteleme:SetTranslation(t)
                              konum = ((son[p] or kokTers * ham[p]) * oteleme):GetTranslation()
                         end
                         model = QuatMatris({ a / u, b2 / u, c2 / u, d2 / u }, konum, Lerp(w, s, e.s))
                    end
               elseif ters and p >= 0 and son[p] then
                    model = son[p] * (ters * m)
               end
               son[i] = model
               ent:SetBoneMatrix(i, kok * model)
          end
     end
     if olc then
          h.fark = fark
     elseif not h.olculdu then
          h.olculdu = true
          h.sure = math.max(h.taban, math.min(0.8, h.fark / 65))
     end
end

local function Harmanla(c, ent, sure)
     if not c.seq or c.tpoz then return end
     local ok, poz = pcall(PozAl, ent)
     if ok and poz and next(poz) then c.harman = { poz = poz, bas = RealTime(), son = RealTime(), ilerleme = 0, fark = 0, taban = sure, sure = 0.8 } end
end

local function ModelKur(c)
     if IsValid(c.ent) then c.ent:Remove() end
     local v = c.veri
     local model = ModelVar(v.model) and v.model or VARSAYILAN_MODEL
     local ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
     if not IsValid(ent) then return end

     ent:SetSkin(tonumber(v.skin) or 0)
     for no, deger in string.gmatch(tostring(v.bg or ""), "(%d+)%s*=%s*(%d+)") do
          ent:SetBodygroup(tonumber(no), tonumber(deger))
     end
     local boy = tonumber(v.boy) or 1
     if boy ~= 1 then ent:SetModelScale(boy, 0) end
     c.profil = ProfilBul(model)
     ent:SetPos(c.pos)
     ent:SetAngles(Angle(0, c.yaw + (c.profil and c.profil.yaw or 0), 0))
     ent:SetIK(false)
     ent.SardonGorevAktor = c
     ent.RenderOverride = G.AktorCizim
     ent:AddCallback("BuildBonePositions", HarmanUygula)
     ent.SardonHarman = HARMAN_SURUM

     c.ent = ent
     c.seq = nil
     c.harman = nil
     c.oynayan = nil
     c.kurZaman = RealTime()
     c.sekans = {}
     c.yerHiz = {}
     c.oto = { bekle = SekansCoz(c, ent, "bekle"), yuru = SekansCoz(c, ent, "yuru"), kos = SekansCoz(c, ent, "kos") }
     local p = c.profil
     c.kemik, c.gozZ, c.merdiven, c.zOfs = nil, nil, nil, 0
     if p then
          for _, tur in ipairs({ "bekle", "yuru", "kos" }) do
               if p[tur] and Sekans(c, ent, p[tur]) >= 0 then c.oto[tur] = p[tur] end
          end
          -- animasyonda yer hızı yok (yerinde yürür): ölçülen hızlar
          for _, y in ipairs(p.yuruyus or {}) do
               local s = Sekans(c, ent, y[1])
               if s >= 0 then c.yerHiz[s] = y[2] end
          end
          c.kemik = KemikSablonu(model, p)
          local yon = Angle(0, -(p.yaw or 0), 0)
          c.ileri, c.sag = yon:Forward(), yon:Right()
     end
     -- ilk kare de bekleme pozunda çizilsin (model "reference" sekansıyla, T-pozda doğar)
     local ilk = Sekans(c, ent, c.oto.bekle)
     if ilk >= 0 then ent:SetSequence(ilk) end
     c.basYaw = ent:LookupPoseParameter("head_yaw") >= 0
     c.basPitch = ent:LookupPoseParameter("head_pitch") >= 0
     c.flex = nil
     if ent:GetFlexNum() > 0 then
          for _, ad in ipairs(AGIZ_FLEX) do
               local id = ent:GetFlexIDByName(ad)
               if id then c.flex = id break end
          end
     end
end

/*
*   Hareket (sunucudaki YolKonum ile aynı)
*/
local function YolKonum(m, t)
     local s = math.max(0, (t - m.t0) * m.hiz)
     if s >= m.toplam then
          local son = m.yol[#m.yol]
          local once = m.yol[#m.yol - 1] or m.bas
          return son, (son - once):Angle().y, true
     end
     local onceL, once = 0, m.bas
     for i, p in ipairs(m.yol) do
          local l = m.uzun[i]
          if s <= l then
               local f = (l - onceL) > 0 and (s - onceL) / (l - onceL) or 1
               return LerpVector(f, once, p), (p - once):Angle().y, false
          end
          onceL, once = l, p
     end
     return m.yol[#m.yol], 0, true
end

local function HareketOku()
     local m = { t0 = net.ReadDouble(), bas = net.ReadVector(), hiz = net.ReadFloat(), tip = net.ReadString(), yol = {} }
     for i = 1, net.ReadUInt(8) do m.yol[i] = net.ReadVector() end
     m.uzun, m.toplam = {}, 0
     local once = m.bas
     for i, p in ipairs(m.yol) do
          m.toplam = m.toplam + once:Distance(p)
          m.uzun[i] = m.toplam
          once = p
     end
     return m
end

/*
*   Beliriş / kayboluş efektleri
*/
local EFEKT_SES = {
     isik = "ambient/energy/whiteflash.wav",
     duman = "ambient/levels/citadel/weapon_disintegrate2.wav",
     cinlama = "ambient/machines/teleport1.wav",
}

function G.AktorEfekt(pos, efekt)
     if not efekt or efekt == "" then return end
     if EFEKT_SES[efekt] then sound.Play(EFEKT_SES[efekt], pos + Vector(0, 0, 40), 70, efekt == "cinlama" and 130 or 100, 0.55) end
     local em = ParticleEmitter(pos, false)
     if not em then return end
     if efekt == "duman" or efekt == "cinlama" then
          for _ = 1, efekt == "cinlama" and 22 or 30 do
               local p = em:Add("particle/smokesprites_000" .. math.random(1, 9), pos + Vector(math.Rand(-14, 14), math.Rand(-14, 14), math.Rand(0, 70)))
               if p then
                    p:SetVelocity(VectorRand() * 40 + Vector(0, 0, 20))
                    p:SetDieTime(math.Rand(1, 2.2))
                    p:SetStartAlpha(efekt == "cinlama" and 120 or 160)
                    p:SetEndAlpha(0)
                    p:SetStartSize(math.Rand(10, 18))
                    p:SetEndSize(math.Rand(34, 52))
                    p:SetRoll(math.Rand(0, 360))
                    p:SetRollDelta(math.Rand(-1, 1))
                    p:SetAirResistance(60)
                    local g = math.random(150, 190)
                    p:SetColor(g, g, g + 8)
               end
          end
     end
     if efekt == "isik" or efekt == "cinlama" then
          for _ = 1, 26 do
               local p = em:Add("sprites/light_glow02_add", pos + Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(0, 72)))
               if p then
                    p:SetVelocity(VectorRand() * 30 + Vector(0, 0, math.Rand(10, 40)))
                    p:SetDieTime(math.Rand(0.8, 1.8))
                    p:SetStartAlpha(220)
                    p:SetEndAlpha(0)
                    p:SetStartSize(math.Rand(2, 6))
                    p:SetEndSize(0)
                    p:SetColor(255, 236, 196)
                    p:SetAirResistance(20)
               end
          end
          local d = DynamicLight(math.random(4000, 9000))
          if d then
               d.pos = pos + Vector(0, 0, 50)
               d.r, d.g, d.b = 255, 230, 190
               d.brightness = 3
               d.size = 260
               d.decay = 600
               d.dietime = CurTime() + 0.8
          end
     end
     em:Finish()
end

/*
*   Oluştur / sil
*/
function G.AktorYerel(veri)
     G.YerelNo = (G.YerelNo or 0) - 1
     local c = { no = G.YerelNo, veri = veri, pos = Vector(veri.pos or vector_origin), yaw = tonumber(veri.yaw) or 0, alfa = 1, yerel = true, durum = "dur" }
     c.hedefYaw = c.yaw
     G.Aktorler[c.no] = c
     ModelKur(c)
     return c
end

function G.AktorSil(c, efekt)
     if not c then return end
     if efekt and efekt ~= "" then
          G.AktorEfekt(c.pos, efekt)
          c.cikis = RealTime()
          if c.profil and c.profil.kaybol then c.anim = { ad = c.profil.kaybol, bas = RealTime(), bitis = CurTime() + 2 } end
          return
     end
     if IsValid(c.ent) then c.ent:Remove() end
     if IsValid(c.kanal) then c.kanal:Stop() end
     G.Aktorler[c.no] = nil
end

local function Al(no) return G.Aktorler[no] end

net.Receive("SardonGorev.Aktor", function()
     local kod = net.ReadUInt(4)
     local no = net.ReadUInt(16)
     local c = Al(no)

     if kod == OP.OLUSTUR then
          local veri = G.OkuTablo()
          local efekt = net.ReadString()
          local hareket = net.ReadBool() and HareketOku() or nil
          if c then G.AktorSil(c) end
          c = { no = no, veri = veri, pos = Vector(veri.pos or vector_origin), yaw = tonumber(veri.yaw) or 0, durum = hareket and "yuru" or "dur", hareket = hareket, alfa = 1 }
          c.hedefYaw = c.yaw
          c.bak = veri.bak
          if veri.anim and veri.anim.ad then c.anim = { ad = veri.anim.ad, dongu = veri.anim.dongu, bitis = veri.anim.bitis, bas = RealTime() } end
          c.hare = veri.hare or ""
          c.hareGuc = c.hare ~= "" and 1 or 0
          c.binis = istable(veri.binis) and veri.binis.no and veri.binis or nil
          G.Aktorler[no] = c
          ModelKur(c)
          if efekt ~= "" then
               c.alfa = 0
               c.giris = RealTime()
               G.AktorEfekt(c.pos, efekt)
               if not c.anim and c.profil and c.profil.belir then c.anim = { ad = c.profil.belir, bas = RealTime(), bitis = CurTime() + 2.6 } end
          end
          return
     end

     if kod == OP.SIL then
          G.AktorSil(c, net.ReadString())
          return
     end
     if not c then return end

     if kod == OP.HAREKET then
          c.hareket = HareketOku()
          c.durum = "yuru"
          c.anim = nil   -- yürüyüşten önce verilen jest yolda sürmesin
     elseif kod == OP.DUR then
          c.pos = net.ReadVector()
          c.hedefYaw = net.ReadFloat()
          c.hareket = nil
          c.durum = "dur"
     elseif kod == OP.KONUM then
          local pos, yaw, efekt = net.ReadVector(), net.ReadFloat(), net.ReadString()
          -- aynı yerde efektsiz yön değişimi ışınlama gibi çakmasın: adım atarak döner
          local yerinde = efekt == "" and not c.binis and c.pos:DistToSqr(pos) < 24 * 24
          local sicrama = c.pos:DistToSqr(pos) > 600 * 600
          c.pos = pos
          if not yerinde then c.yaw = yaw end
          c.hedefYaw = yaw
          c.hareket = nil
          c.durum = "dur"
          c.zeminZ = nil
          c.binis = nil
          G.AktorEfekt(c.pos, efekt)
          -- profilli model cisimlenince beliriş pozu (kararma açılırken görünsün diye son karede bekler)
          if (efekt ~= "" or sicrama) and c.profil and c.profil.belir then c.anim = { ad = c.profil.belir, bas = RealTime(), bitis = CurTime() + 3 } end
     elseif kod == OP.BAK then
          local t = G.OkuTablo()
          c.bak = next(t) and t or nil
     elseif kod == OP.ANIM then
          local ad, dongu, sure = net.ReadString(), net.ReadBool(), net.ReadFloat()
          c.anim = ad ~= "" and { ad = ad, dongu = dongu, bitis = sure > 0 and (CurTime() + sure) or nil, bas = RealTime() } or nil
     elseif kod == OP.KONUS then
          local metin, ses, crc, sure = net.ReadString(), net.ReadString(), net.ReadString(), net.ReadFloat()
          local anim, bakan, kanal, sahip = net.ReadString(), net.ReadUInt(16), net.ReadString(), net.ReadUInt(16)
          G.AktorKonustu(c, { metin = metin, ses = ses, crc = crc, sure = sure, anim = anim, bakan = bakan, kanal = kanal, sahip = sahip })
     elseif kod == OP.HARE then
          c.hare = net.ReadString()
          c.hareGecis = math.max(net.ReadFloat(), 0.01)
     elseif kod == OP.OZELLIK then
          local t = G.OkuTablo()
          for k, v in pairs(t) do c.veri[k] = v end
     elseif kod == OP.BINIS then
          local t = G.OkuTablo()
          c.binis = t.no and t or nil
          c.pos = net.ReadVector()
          c.yaw = net.ReadFloat()
          c.hedefYaw = c.yaw
          c.hareket, c.durum, c.zeminZ = nil, "dur", nil
     end
end)

-- Söz: ses (varsa) 3B olarak ağızdan, altyazı sahibine, balon diğerlerine
function G.AktorKonustu(c, s)
     c.konus = { metin = s.metin, bas = RealTime(), bitis = RealTime() + s.sure, kanal = s.kanal }
     if c.anim and c.anim.cesit then c.anim = nil end
     if s.anim and s.anim ~= "" then
          -- döngülü söz jesti (talk_pointing vb.) söz bitince biter, tek seferlik olan sonuna dek oynar
          c.anim = { ad = s.anim, bas = RealTime(), konusBitis = CurTime() + s.sure }
     end
     if s.bakan > 0 then
          local e = Entity(s.bakan)
          if IsValid(e) then c.bak = { e = s.bakan } end
     end

     local lp = LocalPlayer()
     local benim = s.sahip == lp:EntIndex()
     if benim and (s.kanal == "altyazi" or s.kanal == "" or not s.kanal) then
          G.AltyaziEkle({ ad = c.veri.ad, renk = c.veri.isimRenk, metin = s.metin, sure = s.sure })
     elseif not benim then
          c.balon = true
     end

     if s.ses ~= "" and G.SesCal then
          if IsValid(c.kanal) then c.kanal:Stop() end
          c.kanal = nil
          G.SesCal(s.ses, s.crc, { aktor = c, yakin = benim })
     end
end

/*
*   Kare başı
*/
-- 11-13 opt: kare başı ayırmaları azaltan sabitler / ara nesneler tek tabloda (dosya düzeyi yerel sayısı artmasın).
-- Sabit vektörler yalnız işlenen olarak kullanılır, hiç değiştirilmez; ara Angle / Color'ların alanları her
-- kullanımdan hemen önce yazılır ve yalnız kopyalayan / saklamayan çağrılara verilir.
local OPT = {
     zeminUst = Vector(0, 0, 40),     -- Zemin: iz başı
     zeminAlt = Vector(0, 0, 240),    -- Zemin: iz sonu
     aci = Angle(0, 0, 0),            -- Guncelle: ent:SetAngles kopyalar
     basUst = Vector(0, 0, 12),       -- BasNoktasi: baş kemiğinin üstü
     yaziAci = Angle(0, 0, 90),       -- AktorYazi: cam.Start3D2D kopyalar
     balonRenk = Color(232, 219, 182), -- AktorYazi: balon satırı
     isimRenk = Color(232, 219, 182), -- AktorYazi: v.isimRenk'ten kurulan ad rengi (nr)
     dolgu = Color(255, 255, 255),    -- AktorYazi: SimpleTextOutlined yazı rengi
     kontur = Color(0, 0, 0),         -- AktorYazi: SimpleTextOutlined kontur rengi
}

-- Color() ile aynı alan değerleri (math.min(tonumber(x), 255)); yeni tablo yerine verilen ara rengi doldurur
function OPT.Renk(c, r, g, b, a)
     c.r = math.min(tonumber(r), 255)
     c.g = math.min(tonumber(g), 255)
     c.b = math.min(tonumber(b), 255)
     c.a = math.min(tonumber(a or 255), 255)
     return c
end

-- G.Buyuk(unvan) aktörde önbellekte: unvan ya da G.Buyuk işlevi değişince yeniden (saf işlev: aynı girdi aynı çıktı)
function OPT.Unvan(c, unvan)
     if c.optUnvanF ~= G.Buyuk or c.optUnvanK ~= unvan then c.optUnvanK, c.optUnvanF, c.optUnvan = unvan, G.Buyuk, G.Buyuk(unvan) end
     return c.optUnvan
end

local izSonuc = {}
local iz = { output = izSonuc, mask = MASK_PLAYERSOLID_BRUSHONLY }

local function Zemin(c)
     -- 11-13 opt: sabit ofset vektörleri OPT'ta (toplam / fark yine her çağrıda yeni vektör)
     iz.start = c.pos + OPT.zeminUst
     iz.endpos = c.pos - OPT.zeminAlt
     util.TraceLine(iz)
     if izSonuc.Hit and not izSonuc.StartSolid then return izSonuc.HitPos.z end
     return c.pos.z
end

local function BakisNoktasi(c)
     local b = c.bak
     if b then
          if b.e then
               local e = Entity(b.e)
               if IsValid(e) then return e.EyePos and e:EyePos() or e:GetPos() end
          elseif b.a then
               local d = G.Aktorler[b.a]
               if d and d.cizPos then return d.cizPos + Vector(0, 0, d.gozZ or 64) end
          elseif isvector(b.p) then
               return b.p
          end
     end
     -- açık hedef yoksa yakındaki oyuncuya göz ucuyla bak
     if c.durum ~= "yuru" and not c.yerel then
          local lp = LocalPlayer()
          if lp:GetPos():DistToSqr(c.cizPos or c.pos) < 200 * 200 then return lp:EyePos() end
     end
end

local function Bos(a, b) return (a and a ~= "") and a or b end

-- Durum → sekans (-1: hiçbiri çalınamıyor). Öncelik: sandal > yürüyüş > jest > yerinde dönüş > bekleme
local function SekansSec(c, ent, yurur)
     local v = c.veri
     if c.binis then
          -- sandalda oturur; jest animasyonları ayağa kaldırmasın
          local s = Sekans(c, ent, c.binis.anim or "sit")
          if s >= 0 then return s end
     elseif yurur then
          local kos = c.hareket and c.hareket.tip == "kos"
          local p = c.profil
          if p and c.merdiven then
               local s = Sekans(c, ent, c.merdiven > 0 and p.merdiven.yukari or p.merdiven.asagi)
               if s >= 0 then return s end
          end
          -- profilli modelde tanımda yürüyüş yoksa yol hızına en yakın yürüyüş
          if p and p.yuruyus and Bos(kos and v.kosAnim or v.yuruAnim, "") == "" then
               local hiz = c.hareket and c.hareket.hiz or c.yerelHiz or 80
               local s = Sekans(c, ent, YuruyusSec(p, kos and math.max(hiz, 140) or hiz))
               if s >= 0 then return s end
          end
          local s = Sekans(c, ent, kos and Bos(v.kosAnim, c.oto.kos) or Bos(v.yuruAnim, c.oto.yuru))
          if s < 0 then s = Sekans(c, ent, kos and c.oto.kos or c.oto.yuru) end
          if s >= 0 then return s end
     elseif c.anim then
          local s = Sekans(c, ent, c.anim.ad)
          if s >= 0 then return s, c.anim end
          c.anim = nil
     elseif c.donus then
          local s = Sekans(c, ent, Bos(v.yuruAnim, c.profil and c.profil.donus or c.oto.yuru))
          if s >= 0 then return s, nil, true end
     end
     local s = Sekans(c, ent, Bos(v.bekleAnim, c.oto.bekle))
     if s < 0 then s = Sekans(c, ent, c.oto.bekle) end
     return s
end

local function Guncelle(c, dt)
     if c.yenidenKur and RealTime() >= c.yenidenKur then
          c.yenidenKur = nil
          ModelKur(c)
     end
     local ent = c.ent
     if not IsValid(ent) then
          ModelKur(c)
          ent = c.ent
          if not IsValid(ent) then return end
     end

     -- konum
     local yurur = false
     local sandal = c.binis and G.Sandallar and G.Sandallar[c.binis.no]
     if sandal and sandal.yol then
          local pos, yaw = G.SandalYeri(sandal, G.SandalZaman and G.SandalZaman(sandal) or CurTime(), c.binis.ofs, c.binis.yaw)
          c.pos, c.yaw, c.hedefYaw = pos, yaw, yaw
          c.zeminZ, c.cizZ = pos.z, pos.z
     elseif c.hareket and not c.yerel then
          local pos, yaw, bitti = YolKonum(c.hareket, CurTime())
          c.pos = pos
          if not bitti then
               c.hedefYaw = yaw
               yurur = true
          end
     elseif c.yerel then
          yurur = c.durum == "yuru"
     end

     c.zemSonra = c.zemSonra or 0
     if sandal then
          c.zemSonra = 0
     elseif RealTime() > c.zemSonra or not c.zeminZ then
          c.zemSonra = RealTime() + (yurur and 0.08 or 0.5)
          c.zeminZ = Zemin(c)
     end
     local z = c.zeminZ
     c.cizZ = c.cizZ and Lerp(math.min(1, dt * 12), c.cizZ, z) or z
     c.cizPos = Vector(c.pos.x, c.pos.y, c.cizZ)

     -- merdiven (profilli model): yol yeterince dikse merdiven animasyonu (eşikte histerezis)
     local p = c.profil
     if p and p.merdiven and not sandal then
          local vz = c.kOncekiZ and dt > 0 and (c.cizZ - c.kOncekiZ) / dt or 0
          c.kOncekiZ = c.cizZ
          c.kDikey = Lerp(math.min(1, dt * 6), c.kDikey or 0, vz)
          local yatay = c.hareket and c.hareket.hiz or c.yerelHiz or 80
          local egim = yurur and yatay > 1 and c.kDikey / yatay or 0
          local esik = c.merdiven and p.merdiven.egim * 0.5 or p.merdiven.egim
          c.merdiven = (yurur and math.abs(egim) > esik) and (egim > 0 and 1 or -1) or nil
     else
          c.merdiven = nil
     end

     -- jest ömrü: yürürken jest yok (yürüyüş sırasında gelen söz jesti gecikmeli DUR'a karşı 0.5 sn bekler),
     -- döngülü söz jesti söz bitince biter
     local j = c.anim
     if j then
          if yurur and (not j.bas or RealTime() - j.bas > 0.5) then c.anim = nil
          elseif j.bitis and CurTime() > j.bitis then c.anim = nil
          elseif j.konusBitis and j == c.oynayan and c.dongulu and CurTime() > j.konusBitis then c.anim = nil end
     end

     -- gövde yönü: yürürken yola, dururken hedef yön; bakış omuzdan geriye kaçarsa gövde ona döner,
     -- bakılan öne gelince asıl yöne geri döner (75°/45° histerezis: sınırda titremez, takılı kalmaz)
     local bak = BakisNoktasi(c)
     local hedefYaw = c.hedefYaw or c.yaw
     if not yurur and bak and not sandal then
          local yon = (bak - c.cizPos):Angle().y
          local sapma = math.abs(math.AngleDifference(yon, hedefYaw))
          if sapma > 75 then c.bakDon = true elseif sapma < 45 then c.bakDon = false end
          if c.bakDon then hedefYaw = yon end
     else
          c.bakDon = false
     end
     local fark = math.AngleDifference(hedefYaw, c.yaw)
     if not sandal then
          local tavan = (yurur and 360 or 220) * dt
          c.yaw = c.yaw + math.Clamp(fark * math.min(1, dt * (yurur and 8 or 4)), -tavan, tavan)
     end
     -- yerinde dönüş: ayaklar kaymasın diye küçük adımlar
     if yurur or sandal or c.binis or c.anim then c.donus = false
     elseif math.abs(fark) > 40 then c.donus = true
     elseif math.abs(fark) < 8 then c.donus = false end

     -- profilli modelde jest: kemik jesti (onay / selam) ya da eşlenen sekansın süresi / döngüsü
     local j0 = c.anim
     if p and j0 and not j0.profil then
          j0.profil = true
          local tur = p.kemikJest and p.kemikJest[j0.ad]
          if tur then
               c.kjest = { tur = tur, bas = RealTime() }
               c.anim = nil
          else
               local gercek = p.esle and p.esle[j0.ad] or j0.ad
               if p.dongu and p.dongu[gercek] then j0.dongu = true end
               if p.tut and p.tut[gercek] and not j0.bitis then j0.bitis = CurTime() + p.tut[gercek] end
          end
     end
     -- uzun beklemede çeşit (el ovuşturma, etrafı kollama)
     if p and p.cesit then
          if yurur or c.anim or c.konus or c.binis or c.donus or c.kjest or c.yerel then
               c.bosBas = nil
          else
               c.bosBas = c.bosBas or RealTime()
               c.bosEsik = c.bosEsik or math.Rand(7, 12)
               if RealTime() - c.bosBas > c.bosEsik then
                    c.cesitNo = (c.cesitNo or 0) % #p.cesit + 1
                    local ce = p.cesit[c.cesitNo]
                    c.anim = { ad = ce[1], bas = RealTime(), bitis = CurTime() + ce[2], dongu = true, cesit = true, profil = true }
                    c.bosBas, c.bosEsik = nil, nil
               end
          end
     end

     -- animasyon
     local seq, jest, donus = SekansSec(c, ent, yurur)
     if seq < 0 then
          -- çalınacak animasyon yok (DynaBase yeniden bağlıyor / içerik eksik): T-pozda gösterme, yeniden kur
          c.tpoz = (c.tpozDeneme or 0) < 5
          if not c.yenidenKur and RealTime() - (c.kurZaman or 0) > 2 then
               c.tpozDeneme = (c.tpozDeneme or 0) + 1
               c.yenidenKur = RealTime()
          end
     else
          c.tpoz, c.tpozDeneme = nil, nil
          if c.seq ~= seq or jest ~= c.oynayan then
               local bilgi = ent:GetSequenceInfo(seq)
               Harmanla(c, ent, math.Clamp(bilgi and bilgi.fadeintime or 0.3, 0.2, 0.4))
               c.seq = seq
               c.cycle = 0
               c.oynayan = jest
               c.dongulu = (jest and jest.dongu) or not bilgi or bit.band(bilgi.flags or 1, 1) == 1
          end

          local hedefX = yurur and 1 or (donus and 0.45 or 0)
          c.moveX = math.Approach(c.moveX or hedefX, hedefX, dt * 4)
          ent:SetSequence(seq)
          ent:SetPoseParameter("move_y", 0)
          ent:SetPoseParameter("move_yaw", 0)

          local hiz = 1
          if yurur then
               -- adım hızı tam adımın yer hızına göre (bacaklar açılırken de yol hızı sabit)
               local yer = c.yerHiz[seq]
               if yer == nil then
                    ent:SetPoseParameter("move_x", 1)
                    yer = ent:GetSequenceGroundSpeed(seq) or 0
                    c.yerHiz[seq] = yer
               end
               local gercek = c.hareket and c.hareket.hiz or c.yerelHiz or 80
               if yer > 5 then hiz = math.Clamp(gercek / yer, 0.4, 2.5) end
          elseif donus then
               hiz = 0.8
          end
          ent:SetPoseParameter("move_x", c.moveX)

          local sure = math.max(ent:SequenceDuration(seq), 0.05)
          if c.merdiven and yurur then
               -- merdiven: döngü dikey yola göre ilerler, animasyonun kendi yükselişi geri alınır
               c.cycle = (c.cycle or 0) + dt * math.Clamp(math.abs(c.kDikey or 0) / p.merdiven.yukselis, 0.5, 2.2)
          else
               c.cycle = (c.cycle or 0) + dt * hiz / sure
          end
          if c.dongulu then
               c.cycle = c.cycle % 1
          elseif c.cycle >= 1 then
               c.cycle = 0.999
               if jest and c.anim == jest and not jest.dongu and not jest.bitis then c.anim = nil end
          end
          ent:SetCycle(c.cycle)
     end

     -- baş
     if c.basYaw then
          local hy, hp = 0, 0
          if bak then
               local goz = c.cizPos + Vector(0, 0, 62 * (tonumber(c.veri.boy) or 1))
               local a = (bak - goz):Angle()
               hy = math.Clamp(math.AngleDifference(a.y, c.yaw), -60, 60)
               hp = math.Clamp(math.NormalizeAngle(a.p), -30, 30)
          end
          c.basY = Lerp(math.min(1, dt * 5), c.basY or 0, hy)
          c.basP = Lerp(math.min(1, dt * 5), c.basP or 0, hp)
          ent:SetPoseParameter("head_yaw", c.basY)
          if c.basPitch then ent:SetPoseParameter("head_pitch", c.basP) end
     end

     -- ağız (flex) ya da kemikle söz seviyesi
     if c.flex or c.kemik then
          local w = 0
          if IsValid(c.kanal) and c.kanal:GetState() == GMOD_CHANNEL_PLAYING then
               local l, r = c.kanal:GetLevel()
               w = math.Clamp(math.max(l or 0, r or 0) * 2.2, 0, 1)
          elseif c.konus and RealTime() < c.konus.bitis then
               local t = RealTime() * 11
               w = math.max(0, math.sin(t) * math.sin(t * 0.37 + 1.3)) * 0.6
          end
          c.agiz = Lerp(math.min(1, dt * 18), c.agiz or 0, w)
          if c.flex then ent:SetFlexWeight(c.flex, c.agiz) end
     end
     if c.kemik then
          KemikUygula(c, ent, dt, bak, yurur)
          local b = c.kemik.bas
          local M = b and ent:GetBoneMatrix(b.i)
          if M then c.gozZ = M:GetTranslation().z - ent:GetPos().z - (c.zOfs or 0) + (p.goz or 3) end
     end
     if c.konus and RealTime() > c.konus.bitis + 0.4 then
          c.konus = nil
          c.balon = nil
     end

     -- saydamlık
     if c.giris then
          c.alfa = math.Clamp((RealTime() - c.giris) / 0.7, 0, 1)
          if c.alfa >= 1 then c.giris = nil end
     end
     if c.cikis then
          c.alfa = 1 - math.Clamp((RealTime() - c.cikis) / 0.6, 0, 1)
          if c.alfa <= 0 then
               c.cikis = nil
               G.AktorSil(c)
               return
          end
     end

     -- ses kanalı ağızla gitsin
     if IsValid(c.kanal) then c.kanal:SetPos(c.cizPos + Vector(0, 0, c.gozZ or 60)) end

     -- hare geçişi
     local hedefGuc = (c.hare and c.hare ~= "") and 1 or 0
     c.hareGuc = math.Approach(c.hareGuc or 0, hedefGuc, dt / (c.hareGecis or 1.5))
     if hedefGuc > 0 then c.hareSon = c.hare end

     -- merdiven yükselişinin geri alınması (merdivenden çıkınca yumuşakça sıfırlanır)
     if c.merdiven and yurur and p then
          c.zOfs = -c.merdiven * p.merdiven.yukselis * (c.cycle or 0)
     else
          c.zOfs = Lerp(math.min(1, dt * 8), c.zOfs or 0, 0)
     end
     ent:SetPos(c.cizPos + Vector(0, 0, c.zOfs))
     -- 11-13 opt: Angle(0, yaw, 0) yerine ara Angle (SetAngles kopyalar); üç alan her karede yazılır
     local aci = OPT.aci
     aci.p, aci.y, aci.r = 0, c.yaw + (p and p.yaw or 0), 0
     ent:SetAngles(aci)
     ent:InvalidateBoneCache()
end

-- E ile konuşulacak aktör
local function BakilanBul()
     local lp = LocalPlayer()
     local goz, yon = lp:EyePos(), lp:GetAimVector()
     local enIyi, enYakin = nil, math.huge
     for _, c in pairs(G.Aktorler) do
          if not c.yerel and IsValid(c.ent) and c.cizPos and c.alfa > 0.5 then
               local d = goz:Distance(c.cizPos + Vector(0, 0, c.gozZ and c.gozZ * 0.7 or 40))
               if d < G.Ayar.KonusMesafe + 40 and d < enYakin then
                    local mins, maxs = c.ent:OBBMins(), c.ent:OBBMaxs()
                    mins.x, mins.y, maxs.x, maxs.y = mins.x - 6, mins.y - 6, maxs.x + 6, maxs.y + 6
                    local vur = util.IntersectRayWithOBB(goz, yon * 200, c.ent:GetPos(), c.ent:GetAngles(), mins, maxs)
                    if vur then enIyi, enYakin = c, d end
               end
          end
     end
     return enIyi
end

hook.Add("Think", "SardonGorev.Aktor", function()
     if next(G.Aktorler) == nil then G.Bakilan = nil return end
     local dt = math.min(FrameTime(), 0.1)
     for _, c in pairs(G.Aktorler) do
          local ok, hata = pcall(Guncelle, c, dt)
          if not ok then
               ErrorNoHalt("[Sardon Görev] aktör: " .. tostring(hata) .. "\n")
               G.AktorSil(c)
          end
     end
     G.Bakilan = BakilanBul()
end)

-- DynaBase animasyonları yeniden bağlayınca (r_flushlod) sekans numaraları değişir: modeller yeniden kurulur
hook.Add("PostLoadAnimations", "SardonGorev.Aktor", function()
     for _, c in pairs(G.Aktorler) do c.yenidenKur = RealTime() + 0.4 end
end)

-- canlı yenilemede eski modellerde harman geri çağrısı yok
for _, c in pairs(G.Aktorler) do
     if not IsValid(c.ent) or c.ent.SardonHarman ~= HARMAN_SURUM then c.yenidenKur = RealTime() end
end

local sonE = 0
hook.Add("KeyPress", "SardonGorev.Aktor", function(ply, tus)
     if tus ~= IN_USE or ply ~= LocalPlayer() or not IsFirstTimePredicted() then return end
     local c = G.Bakilan
     if not c or RealTime() < sonE then return end
     sonE = RealTime() + 0.5
     G.Iste(G.ISTEK.KONUS, function() net.WriteUInt(c.no, 16) end)
end)

/*
*   Çizim: saydamlık + hare
*/
local maskeCiziliyor = false

function G.AktorCizim(self, bayrak)
     local c = self.SardonGorevAktor
     if c and c.tpoz then return end
     local a = c and c.alfa or 1
     local saydam = c and G.HareSaydamlik and G.HareSaydamlik(c) or 0
     a = a * (1 - saydam)
     if maskeCiziliyor then a = 1 end
     if a < 0.999 then render.SetBlend(a) end
     self:DrawModel(bayrak)
     if a < 0.999 then render.SetBlend(1) end
end

/*
*   İsim, görev işareti, konuşma balonu
*/
local function BasNoktasi(c)
     local ent = c.ent
     -- 11-13 opt: sabit +12 ofseti OPT'ta. (LookupBone önbelleğe alınmadı: 0,14 us ve ayırmasız; önbellek
     -- anahtarı için gereken GetModel 0,58 us tutuyor.)
     local kemik = ent:LookupBone(c.profil and c.profil.kemik and c.profil.kemik.bas or "ValveBiped.Bip01_Head1")
     if kemik then
          local m = ent:GetBoneMatrix(kemik)
          if m then return m:GetTranslation() + OPT.basUst end
     end
     return c.cizPos + Vector(0, 0, 76 * (tonumber(c.veri.boy) or 1))
end

hook.Add("PostDrawTranslucentRenderables", "SardonGorev.AktorYazi", function(_, gok)
     if gok or next(G.Aktorler) == nil then return end
     -- sinematik çekimde isim / işaret kadrajı bozmasın
     if G.Sinematik and G.Sinematik() then return end
     local lp = LocalPlayer()
     local goz = lp:EyePos()
     -- 11-13 opt: Angle(0, y, 90) yerine tek ara Angle (cam.Start3D2D kopyalar); üç alan her çağrıda yazılır
     local aci = OPT.yaziAci
     aci.p, aci.y, aci.r = 0, EyeAngles().y - 90, 90

     for _, c in pairs(G.Aktorler) do
          if not c.yerel and IsValid(c.ent) and c.cizPos and c.alfa > 0.05 then
               local d = goz:Distance(c.cizPos)
               if d < 1100 then
                    local bas = BasNoktasi(c)
                    local alfa = math.Clamp((1100 - d) / 300, 0, 1) * c.alfa
                    local v = c.veri

                    -- 11-13 opt: tostring(c.no) aktörde önbellekte (c.no değişince yeniden)
                    if c.optNoYazi == nil or c.optNo ~= c.no then c.optNo, c.optNoYazi = c.no, tostring(c.no) end
                    local teklif = G.D.teklif and G.D.teklif[c.optNoYazi]
                    local hedefte = G.AktorHedefte(c.no)

                    cam.Start3D2D(bas, aci, 0.06)
                         local y = 0
                         -- konuşma balonu (görevin sahibi olmayanlar için)
                         if c.balon and c.konus and d < 650 then
                              -- 11-13 opt: kaydırılmış satırlar c.konus üstünde; metin değişmedikçe G.Sar her karede çağrılmaz
                              local kn = c.konus
                              local satirlar = kn.optSatir
                              if not satirlar or kn.optSatirMetin ~= kn.metin then
                                   satirlar = G.Sar(kn.metin, "SardonGorev.D_Balon", 520)
                                   kn.optSatir, kn.optSatirMetin = satirlar, kn.metin
                              end
                              local h = #satirlar * 34 + 24
                              local w = 560
                              local ka = math.Clamp((c.konus.bitis - RealTime()) / 0.4, 0, 1) * alfa
                              surface.SetDrawColor(11, 19, 17, 210 * ka)
                              surface.DrawRect(-w / 2, y - h - 70, w, h)
                              surface.SetDrawColor(190, 162, 104, 160 * ka)
                              surface.DrawOutlinedRect(-w / 2, y - h - 70, w, h, 2)
                              for i, s in ipairs(satirlar) do
                                   -- 11-13 opt: Color(232, 219, 182, 255 * ka) yerine ara renk (SimpleText saklamaz)
                                   draw.SimpleText(s, "SardonGorev.D_Balon", 0, y - h - 70 + 12 + (i - 1) * 34, OPT.Renk(OPT.balonRenk, 232, 219, 182, 255 * ka), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                              end
                         end

                         -- işaret: görev veren "!" / hedefteki aktör "◆"
                         if teklif or hedefte then
                              local t = RealTime()
                              local sal = math.sin(t * 2.4) * 8
                              local renk = teklif and R.altinAcik or G.TurRenk(hedefte and hedefte.tur)
                              surface.SetMaterial(G.Mat.parilti)
                              surface.SetDrawColor(renk.r, renk.g, renk.b, 70 * alfa)
                              surface.DrawTexturedRect(-90, y - 300 + sal, 180, 180)
                              draw.NoTexture()
                              if teklif then
                                   -- 11-13 opt: yazı ve kontur için iki ayrı ara renk (ikisi aynı anda canlı; SimpleTextOutlined saklamaz)
                                   draw.SimpleTextOutlined("!", "SardonGorev.D_Isaret", 0, y - 210 + sal, OPT.Renk(OPT.dolgu, renk.r, renk.g, renk.b, 255 * alfa), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 3, OPT.Renk(OPT.kontur, 0, 0, 0, 200 * alfa))
                              else
                                   G.Baklava(0, y - 210 + sal, 34, renk, 255 * alfa)
                                   G.Baklava(0, y - 210 + sal, 16, R.zemin, 230 * alfa)
                              end
                         end

                         if v.isimGoster ~= false and d < 700 then
                              -- 11-13 opt: nr, yazı ve kontur renkleri ayrı ara renkler (Color() ile aynı alan değerleri)
                              local nr = istable(v.isimRenk) and OPT.Renk(OPT.isimRenk, v.isimRenk[1] or v.isimRenk.r or 232, v.isimRenk[2] or v.isimRenk.g or 219, v.isimRenk[3] or v.isimRenk.b or 182) or R.fildisi
                              draw.SimpleTextOutlined(v.ad or "", "SardonGorev.D_Ad", 0, y, OPT.Renk(OPT.dolgu, nr.r, nr.g, nr.b, 255 * alfa), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, OPT.Renk(OPT.kontur, 0, 0, 0, 170 * alfa))
                              if v.unvan and v.unvan ~= "" then
                                   -- 11-13 opt: G.Buyuk(v.unvan) aktörde önbellekte (OPT.Unvan)
                                   draw.SimpleTextOutlined(OPT.Unvan(c, v.unvan), "SardonGorev.D_Unvan", 0, y + 4, OPT.Renk(OPT.dolgu, 190, 162, 104, 230 * alfa), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, OPT.Renk(OPT.kontur, 0, 0, 0, 150 * alfa))
                              end
                         end
                    cam.End3D2D()
               end
          end
     end
end)

/*
*   Anı haresi (Sinema'daki yöntemin görev aktörlerine uyarlanmışı)
*   Hazır görünümlerin değerleri Sinema ile aynı.
*/
local HARE = {
     ani = { parilti = 0.65, boyut = 0.55, kenar = 0.45, beyaz = 0.2, saydam = 0, zerre = 0.35, renk = { 232, 240, 255 }, nabiz = "nabiz", nabizHiz = 0.3 },
     hayalet = { parilti = 0.5, boyut = 0.45, kenar = 0.6, beyaz = 0.25, saydam = 0.5, zerre = 0.15, renk = { 222, 236, 255 }, nabiz = "titrek", nabizHiz = 0.25 },
     nur = { parilti = 1, boyut = 0.8, kenar = 0.7, beyaz = 0.15, saydam = 0, zerre = 0.5, renk = { 255, 248, 232 }, nabiz = "nabiz", nabizHiz = 0.2 },
     silik = { parilti = 0.5, boyut = 0.6, kenar = 0.4, beyaz = 0.35, saydam = 0.3, zerre = 1, renk = { 240, 240, 240 }, nabiz = "titrek", nabizHiz = 0.7 },
     ince = { parilti = 0.6, boyut = 0.15, kenar = 0.25, beyaz = 0, saydam = 0, zerre = 0, renk = { 255, 255, 255 }, nabiz = "sabit", nabizHiz = 0.5 },
}
G.HareOnAyar = HARE

local titrek = { deger = 1, hedef = 1, sonraki = 0 }
local nabiz = 1

local function NabizHesapla(P, dt)
     local t = RealTime()
     if P.nabiz == "nabiz" then
          local f = Lerp(P.nabizHiz, 0.12, 1.2)
          return 0.72 + 0.28 * (0.5 + 0.5 * math.sin(t * f * math.pi * 2))
     elseif P.nabiz == "titrek" then
          if t > titrek.sonraki then
               titrek.sonraki = t + math.Rand(0.05, 0.2) / Lerp(P.nabizHiz, 0.4, 2)
               titrek.hedef = math.random() < 0.15 and math.Rand(0.25, 0.5) or math.Rand(0.78, 1)
          end
          titrek.deger = Lerp(1 - math.exp(-22 * dt), titrek.deger, titrek.hedef)
          return titrek.deger
     end
     return 1
end

function G.HareSaydamlik(c)
     local P = HARE[c.hareSon or ""]
     if not P or (c.hareGuc or 0) <= 0 then return 0 end
     return math.min(P.saydam * G.Yumusak(c.hareGuc) * (1 + (1 - nabiz) * 0.8), 0.88)
end

local hedefler, baskin = {}, nil
local zerreBirikim = {}
local hareEmitter

local function HareListe(dt)
     hedefler, baskin = {}, nil
     local enGuc = 0
     for _, c in pairs(G.Aktorler) do
          if IsValid(c.ent) and (c.hareGuc or 0) > 0 and HARE[c.hareSon or ""] then
               hedefler[#hedefler + 1] = c
               if c.hareGuc > enGuc then enGuc, baskin = c.hareGuc, c end
          end
     end
     if baskin then nabiz = NabizHesapla(HARE[baskin.hareSon], dt) end
end

local function ZerreUret(dt)
     if not baskin then return end
     local P = HARE[baskin.hareSon]
     local oran = P.zerre * 26 * nabiz
     if oran <= 0.01 then return end
     if not hareEmitter then hareEmitter = ParticleEmitter(EyePos(), false) end
     hareEmitter:SetPos(EyePos())
     for _, c in ipairs(hedefler) do
          local b = (zerreBirikim[c] or math.random()) + oran * G.Yumusak(c.hareGuc) * dt
          local adet = math.min(math.floor(b), 4)
          zerreBirikim[c] = b - math.floor(b)
          for _ = 1, adet do
               local n = c.ent:GetBoneCount()
               local pos = n and n > 0 and c.ent:GetBonePosition(math.random(0, n - 1))
               if not pos or pos:DistToSqr(c.cizPos) > 120 * 120 then pos = c.cizPos + Vector(0, 0, math.Rand(4, 70)) end
               local p = hareEmitter:Add("sprites/light_glow02_add", pos + VectorRand() * 5)
               if p then
                    local iri = math.random() < 0.15
                    p:SetDieTime(math.Rand(1.4, 3.2))
                    p:SetStartSize(iri and math.Rand(4, 7) or math.Rand(0.8, 2.2))
                    p:SetEndSize(0)
                    p:SetStartAlpha(iri and math.Rand(50, 90) or math.Rand(160, 240))
                    p:SetEndAlpha(0)
                    p:SetVelocity(VectorRand() * 4 + Vector(0, 0, math.Rand(6, 18)))
                    p:SetAirResistance(10)
                    p:SetGravity(Vector(0, 0, 4))
                    p:SetColor(P.renk[1], P.renk[2], P.renk[3])
               end
          end
     end
end

hook.Add("Think", "SardonGorev.Hare", function()
     local dt = math.min(FrameTime(), 0.1)
     HareListe(dt)
     if #hedefler > 0 then ZerreUret(dt) end
end)

/*
*   Bağ: oyuncuyu izleyen rehber aktörle oyuncu arasında ince altın zerre şeridi — kimin rehberi
*   olduğu herkese belli olur. Sunucu oyuncunun NW2 "SardonGorevBag"ine aktör no'sunu yazar.
*/
local bagEmitter
local bagBirikim = setmetatable({}, { __mode = "k" })

local function BagUcu(ply)
     local b = ply:LookupBone("ValveBiped.Bip01_Spine2")
     local m = b and ply:GetBoneMatrix(b)
     return m and m:GetTranslation() or ply:GetPos() + Vector(0, 0, 44)
end

hook.Add("Think", "SardonGorev.Bag", function()
     if G.Sinematik and G.Sinematik() then return end
     local dt = math.min(FrameTime(), 0.1)
     -- 11-13 opt: player.GetAll() kopyası yerine paylaşılan önbellekli liste (yalnız okunuyor, değiştirilmiyor);
     -- EyePos ilk bağlı oyuncuda okunur (döngüde değişmez; çoğu karede hiç gerekmiyor)
     local goz
     for _, p in player.Iterator() do
          local no = p:GetNW2Int("SardonGorevBag", 0)
          local c = no ~= 0 and G.Aktorler[no]
          local uygun = c and IsValid(c.ent) and c.cizPos and (c.alfa or 1) > 0.3 and not p:GetNoDraw()
          if uygun then goz = goz or EyePos() end
          if uygun and goz:DistToSqr(c.cizPos) < 1600 * 1600 then
               local a = c.cizPos + Vector(0, 0, (c.gozZ or 50) * 0.7)
               local fark = BagUcu(p) - a
               local uzun = fark:Length()
               if uzun > 24 and uzun < 900 then
                    if not bagEmitter then bagEmitter = ParticleEmitter(goz, false) end
                    bagEmitter:SetPos(goz)
                    local yay = math.min(uzun * 0.2, 28)
                    local yon = fark / uzun
                    local b = (bagBirikim[p] or 0) + dt * (14 + uzun * 0.06)
                    local adet = math.min(math.floor(b), 6)
                    bagBirikim[p] = b - adet
                    for _ = 1, adet do
                         local t = math.random()
                         local pos = a + fark * t
                         pos.z = pos.z + yay * 4 * t * (1 - t)
                         local z = bagEmitter:Add("sprites/light_glow02_add", pos + VectorRand() * 1.2)
                         if z then
                              z:SetDieTime(math.Rand(0.5, 1.0))
                              z:SetStartSize(math.Rand(0.9, 1.9))
                              z:SetEndSize(0)
                              z:SetStartAlpha(math.Rand(150, 230))
                              z:SetEndAlpha(0)
                              z:SetVelocity(yon * math.Rand(12, 28) + VectorRand() * 2)
                              z:SetAirResistance(20)
                              z:SetColor(236, 206, 140)
                         end
                    end
               end
          end
     end
end)

-- Bağlı takipte koşma yok (paylaşılan; sv_5aktor.lua'da aynısı)
hook.Add("StartCommand", "SardonGorev.Bag", function(ply, cmd)
     if ply:GetNW2Int("SardonGorevBag", 0) ~= 0 then cmd:RemoveKey(IN_SPEED) end
end)

local rtSahne, rtMaske, rtDar, rtGenis, matMaske, matDar, matGenis, dokuBoyut

local function RT(ad, w, h)
     return GetRenderTargetEx(ad, w, h, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_NONE, 4 + 8 + 256, 0, IMAGE_FORMAT_RGBA8888)
end

local function DokuMat(ad, rt)
     local m = CreateMaterial(ad, "UnlitGeneric", { ["$basetexture"] = rt:GetName(), ["$ignorez"] = "1", ["$vertexcolor"] = "1" })
     m:SetTexture("$basetexture", rt)
     return m
end

local function Hazirla(W, H)
     local boyut = W .. "x" .. H
     if dokuBoyut == boyut then return end
     dokuBoyut = boyut
     local on = "sardon_gorev_hare_" .. boyut .. "_"
     rtSahne = RT(on .. "sahne", W, H)
     rtMaske = RT(on .. "maske", W, H)
     rtDar = RT(on .. "dar", math.ceil(W / 2), math.ceil(H / 2))
     rtGenis = RT(on .. "genis", math.ceil(W / 4), math.ceil(H / 4))
     matMaske = DokuMat("SardonGorevHare_" .. boyut .. "_maske", rtMaske)
     matDar = DokuMat("SardonGorevHare_" .. boyut .. "_dar", rtDar)
     matGenis = DokuMat("SardonGorevHare_" .. boyut .. "_genis", rtGenis)
end

local function Kucult(rt)
     render.PushRenderTarget(rt)
          cam.Start2D()
               surface.SetMaterial(matMaske)
               surface.SetDrawColor(255, 255, 255, 255)
               surface.DrawTexturedRect(0, 0, rt:Width(), rt:Height())
          cam.End2D()
     render.PopRenderTarget()
end

local function Ekle(mat, renk, guc, W, H)
     surface.SetMaterial(mat)
     while guc > 0.004 do
          local k = math.min(guc, 1)
          surface.SetDrawColor(renk[1] * k, renk[2] * k, renk[3] * k, 255)
          surface.DrawTexturedRect(0, 0, W, H)
          guc = guc - 1
     end
end

local function HareCiz()
     local P = HARE[baskin.hareSon]
     local g = G.Yumusak(baskin.hareGuc)
     local parilti, kenar, beyaz = P.parilti * g * nabiz, P.kenar * g * nabiz, P.beyaz * g * (0.5 + 0.5 * nabiz)
     if parilti + kenar + beyaz < 0.01 then return end

     local W, H = ScrW(), ScrH()
     Hazirla(W, H)
     local renk = P.renk
     local sahne = render.GetRenderTarget()

     render.CopyRenderTargetToTexture(rtSahne)

     render.Clear(0, 0, 0, 255, false, true)
     cam.Start3D()
          render.SetStencilEnable(true)
          render.SetStencilWriteMask(1)
          render.SetStencilTestMask(1)
          render.SetStencilReferenceValue(1)
          render.SetStencilCompareFunction(STENCIL_ALWAYS)
          render.SetStencilPassOperation(STENCIL_REPLACE)
          render.SetStencilFailOperation(STENCIL_KEEP)
          render.SetStencilZFailOperation(STENCIL_KEEP)
          render.SuppressEngineLighting(true)
          maskeCiziliyor = true
          for _, c in ipairs(hedefler) do if IsValid(c.ent) then c.ent:DrawModel() end end
          maskeCiziliyor = false
          render.SetStencilCompareFunction(STENCIL_EQUAL)
          render.SetStencilPassOperation(STENCIL_KEEP)
          cam.Start2D()
               surface.SetDrawColor(255, 255, 255, 255)
               surface.DrawRect(0, 0, W, H)
          cam.End2D()
          render.SuppressEngineLighting(false)
          render.SetStencilEnable(false)
     cam.End3D()
     render.CopyRenderTargetToTexture(rtMaske)

     Kucult(rtDar)
     Kucult(rtGenis)
     local b = P.boyut
     render.BlurRenderTarget(rtDar, 1 + b * 3, 1 + b * 3, 1)
     render.BlurRenderTarget(rtGenis, 3 + b * 14, 3 + b * 14, 2)
     render.SetRenderTarget(sahne)

     if kenar > 0.004 then
          cam.Start2D()
               render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_REVERSE_SUBTRACT)
               surface.SetMaterial(matDar)
               surface.SetDrawColor(192, 192, 192, 255)
               surface.DrawTexturedRect(0, 0, W, H)
               surface.SetMaterial(matGenis)
               surface.SetDrawColor(64, 64, 64, 255)
               surface.DrawTexturedRect(0, 0, W, H)
               render.OverrideBlend(false)
          cam.End2D()
          render.CopyRenderTargetToTexture(rtMaske)
     end

     render.DrawTextureToScreen(rtSahne)

     render.SetStencilEnable(true)
     render.SetStencilWriteMask(0)
     render.SetStencilTestMask(1)
     render.SetStencilReferenceValue(1)
     render.SetStencilPassOperation(STENCIL_KEEP)
     render.SetStencilFailOperation(STENCIL_KEEP)
     render.SetStencilZFailOperation(STENCIL_KEEP)
     cam.Start2D()
          render.SetStencilCompareFunction(STENCIL_EQUAL)
          if beyaz > 0.004 then
               draw.NoTexture()
               surface.SetDrawColor(renk[1], renk[2], renk[3], math.min(beyaz * 0.8, 1) * 255)
               surface.DrawRect(0, 0, W, H)
          end
          render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD)
          if kenar > 0.004 then Ekle(matMaske, renk, kenar * 1.6, W, H) end
          render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
          if parilti > 0.004 then
               Ekle(matDar, renk, parilti * 0.9, W, H)
               Ekle(matGenis, renk, parilti * 1.5, W, H)
          end
          render.OverrideBlend(false)
     cam.End2D()
     render.SetStencilEnable(false)
     render.SetStencilTestMask(0)
     render.SetStencilReferenceValue(0)
end

local hareHata = false

hook.Add("PostDrawEffects", "SardonGorev.Hare", function()
     if hareHata or not baskin or #hedefler == 0 then return end
     local ok, hata = xpcall(HareCiz, debug.traceback)
     if ok then return end
     hareHata = true
     maskeCiziliyor = false
     render.SetStencilEnable(false)
     render.OverrideBlend(false)
     render.SuppressEngineLighting(false)
     render.SetBlend(1)
     ErrorNoHalt("[Sardon Görev] anı haresi çizilemedi: " .. tostring(hata) .. "\n")
end)

-- Karakter değişince / çıkınca hepsi temizlenir (sunucu da SIL gönderir)
hook.Add("ShutDown", "SardonGorev.Aktor", function()
     for _, c in pairs(G.Aktorler) do if IsValid(c.ent) then c.ent:Remove() end end
end)

/*
*   Büyü jestlerinde asa (11-07): adı "Cast_" ile başlayan animasyon (Cast_AccioPull vb.) süresince aktörün
*   sağ eline oyuncu asası takılır; bitince 0,4 sn sonra gizlenir. Asa modelinin kök kemiği
*   ValveBiped.Bip01_R_Hand olduğu için bonemerge oyuncudaki tutuşun aynısını verir; o kemiği olmayan
*   (profilli) modellerde takılmaz. Kitapçı Villanelle'in Accio'su ve Ollivander seremonisi bunu kullanır.
*   Model yeniden kurulursa asa yeni modele bağlanır, aktör silinince asa da silinir.
*/
local ASA_MODEL = "models/hpwrewrite/w_magicwand.mdl"
G.AktorAsalar = G.AktorAsalar or {}
local asalar = G.AktorAsalar

local function AsaCizim(self, bayrak)
     local c = self.SardonAktor
     if not c or not IsValid(c.ent) or c.tpoz then return end
     local a = (c.alfa or 1) * (1 - (G.HareSaydamlik and G.HareSaydamlik(c) or 0))
     if a < 0.999 then render.SetBlend(a) end
     self:DrawModel(bayrak)
     if a < 0.999 then render.SetBlend(1) end
end

hook.Add("Think", "SardonGorev.AktorAsa", function()
     local simdi = RealTime()
     for _, c in pairs(G.Aktorler) do
          local ent = c.ent
          local ad = c.anim and c.anim.ad
          if IsValid(ent) and isstring(ad) and ad:sub(1, 5) == "Cast_" then c.asaSon = simdi end
          local asa = asalar[c]
          if IsValid(ent) and c.asaSon and simdi - c.asaSon < 0.4 then
               if not IsValid(asa) and ent:LookupBone("ValveBiped.Bip01_R_Hand") then
                    asa = ClientsideModel(ASA_MODEL, RENDERGROUP_OPAQUE)
                    if IsValid(asa) then
                         asa.SardonAktor = c
                         asa.RenderOverride = AsaCizim
                         asalar[c] = asa
                    end
               end
               if IsValid(asa) then
                    if asa:GetParent() ~= ent then
                         asa:SetParent(ent)
                         asa:SetLocalPos(vector_origin)
                         asa:SetLocalAngles(angle_zero)
                         asa:AddEffects(EF_BONEMERGE)
                    end
                    if asa:GetNoDraw() then asa:SetNoDraw(false) end
               end
          elseif IsValid(asa) and not asa:GetNoDraw() then
               asa:SetNoDraw(true)
          end
     end
     -- silinen aktörlerin asaları
     for c, asa in pairs(asalar) do
          if G.Aktorler[c.no] ~= c then
               if IsValid(asa) then asa:Remove() end
               asalar[c] = nil
          end
     end
end)
