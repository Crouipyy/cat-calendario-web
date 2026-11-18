-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_7sinematik.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sinematik: kamera, Sinema sahnesi oynatma, kararma, başlık kartı, ekran efekti, müzik,
*   ses efekti, parçacık.
*
*   Kamera motor olaylarına HOOKS_CACHE vekiliyle girer ([sardon] sinema'daki yöntem: motor
*   hook.Call'u önbelleğe alıyor, Helix her çağrıda HOOKS_CACHE[ad]'ı geziyor). Vekil yalnız
*   kamera açıkken kurulur, kapanınca orijinal tablolar geri konur.
*/
local G = SardonGorev
local R, O, F = G.R, G.O, G.F
local S = G.SAHNE

G.Kam = G.Kam or nil         -- etkin çekim
G.SahneOyna = G.SahneOyna or nil

/*
*   Yardımcılar
*/
local YUMUSATMA = {
     dogrusal = function(s) return s end,
     yumusak = function(s) return s * s * (3 - 2 * s) end,
     yavasBasla = function(s) return s * s end,
     yavasBitir = function(s) return 1 - (1 - s) * (1 - s) end,
}

local function AciLerp(f, a, b)
     return Angle(Lerp(f, a.p, a.p + math.AngleDifference(b.p, a.p)), Lerp(f, a.y, a.y + math.AngleDifference(b.y, a.y)), Lerp(f, a.r, a.r + math.AngleDifference(b.r, a.r)))
end

local saklanan = {}   -- HOOKS_CACHE vekilinin sakladığı asıl kancalar (aşağıda)

-- Oyuncunun normal görüşü: kilitli üçüncü şahıs kamerası varsa onun konumu, yoksa göz
-- (göze dönen geçiş çizilen oyuncunun kafasının içinden geçiyordu)
local function OyuncuGorus()
     local lp = LocalPlayer()
     local pos, ang, fov = lp:EyePos(), lp:EyeAngles(), lp:GetFOV() or 75
     for k, f in pairs(saklanan.CalcView or {}) do
          local ok, v = pcall(f, k, lp, pos, ang, fov, 3, 30000)
          if ok and istable(v) and v.origin then return v.origin, v.angles or ang, v.fov or fov, true end
     end
     return pos, ang, fov, false
end

local function AktorGoz(no)
     local c = G.Aktorler[no or 0]
     if c and c.cizPos then return c.cizPos + Vector(0, 0, c.gozZ or 62 * (tonumber(c.veri.boy) or 1)), c end
end

local function DuvarKontrol(merkez, hedef)
     local tr = util.TraceLine({ start = merkez, endpos = hedef, mask = MASK_SOLID_BRUSHONLY })
     if tr.Hit then return tr.HitPos + tr.HitNormal * 6 end
     return hedef
end

-- Omuz çekimi: konuşana, dinleyenin omzu üstünden
local function OmuzCekimi(konusanGoz, dinleyenGoz)
     local yon = (konusanGoz - dinleyenGoz):GetNormalized()
     local sag = yon:Angle():Right()
     local pos = dinleyenGoz - yon * 58 + sag * 30 + Vector(0, 0, 4)
     pos = DuvarKontrol(dinleyenGoz, pos)
     -- konuşan kadrajın sağ üçte birine yakın dursun, dinleyenin omzu solda kalsın
     local bak = konusanGoz - Vector(0, 0, 5) - sag * 10
     return pos, (bak - pos):Angle(), 44
end

function G.Sinematik()
     return G.Kam ~= nil or G.SahneOyna ~= nil or (G.Diy ~= nil and G.Diy.kip == "sinematik")
end

/*
*   Çekim hesapları
*/
local gecis = nil   -- { bas, sure, pos, ang, fov }

local function CekimHesapla()
     local lp = LocalPlayer()
     local k = G.Kam

     -- sahne oynuyorsa sahnenin kamerası
     if G.SahneOyna and G.SahneOyna.kamera then return G.SahneOyna.kamera() end

     if k then
          local t = k.sure > 0 and math.Clamp((CurTime() - k.bas) / k.sure, 0, 1) or 0
          local e = (YUMUSATMA[k.yumusatma or "yumusak"] or YUMUSATMA.yumusak)(t)
          local pos, ang, fov = k.pos, k.ang, k.fov

          local hedef
          if k.hedefAktor then hedef = AktorGoz(k.hedefAktor) end
          if not hedef and k.hedefOyuncu then hedef = lp:EyePos() end
          if not hedef and isvector(k.hedefPos) then hedef = k.hedefPos end

          if k.tur == "kaydir" and k.pos2 then
               pos = LerpVector(e, k.pos, k.pos2)
               ang = AciLerp(e, k.ang, k.ang2 or k.ang)
               fov = Lerp(e, k.fov, k.fov2 or k.fov)
          elseif k.tur == "yorunge" and hedef then
               local yaricap = k.pos and math.max(80, Vector(k.pos.x, k.pos.y, 0):Distance(Vector(hedef.x, hedef.y, 0))) or 170
               local yukseklik = k.pos and (k.pos.z - hedef.z) or 20
               local baslangic = k.pos and (k.pos - hedef):Angle().y or (lp:EyeAngles().y + 180)
               local aci = math.rad(baslangic + (CurTime() - k.bas) * 14)
               pos = hedef + Vector(math.cos(aci) * yaricap, math.sin(aci) * yaricap, yukseklik)
               pos = DuvarKontrol(hedef, pos)
          elseif k.tur == "konusma" then
               local aGoz = AktorGoz(k.hedefAktor)
               if aGoz then pos, ang, fov = OmuzCekimi(aGoz, lp:EyePos()) end
               hedef = nil
          end
          if hedef and k.tur ~= "konusma" and pos then ang = (hedef - pos):Angle() end
          if pos and ang then return pos, ang, fov end
     end

     -- sinematik diyalog: otomatik omuz çekimi
     local d = G.Diy
     if d and d.kip == "sinematik" and d.kamera and d.aktor and d.aktor > 0 then
          local aGoz = AktorGoz(d.aktor)
          if aGoz then
               if d.satir and d.satir.kim == "oyuncu" then
                    return OmuzCekimi(lp:EyePos(), aGoz)
               end
               return OmuzCekimi(aGoz, lp:EyePos())
          end
     end
end

local sonCekim = { pos = Vector(), ang = Angle(), fov = 70 }
local onceki = nil

local function Gorunum()
     local pos, ang, fov = CekimHesapla()
     if not pos then return end

     -- yumuşak geçiş (çekim değişince / diyalog başlayınca)
     local anahtar = G.Kam and ("k" .. tostring(G.Kam.bas)) or (G.Diy and ("d" .. tostring(G.Diy.satir and G.Diy.satir.kim))) or "s"
     if onceki ~= anahtar then
          if onceki ~= nil or not G.SahneOyna then
               gecis = { bas = RealTime(), sure = G.Kam and G.Kam.gecis or 0.55, pos = Vector(sonCekim.pos), ang = Angle(sonCekim.ang), fov = sonCekim.fov }
               if onceki == nil then
                    local p, a, f = OyuncuGorus()
                    gecis.pos, gecis.ang, gecis.fov = p, a, f
               end
          end
          onceki = anahtar
     end
     if gecis then
          local f = (RealTime() - gecis.bas) / math.max(gecis.sure, 0.01)
          if f >= 1 or (G.Kam and G.Kam.kes) then
               gecis = nil
          else
               f = YUMUSATMA.yumusak(f)
               pos = LerpVector(f, gecis.pos, pos)
               ang = AciLerp(f, gecis.ang, ang)
               fov = Lerp(f, gecis.fov, fov)
          end
     end

     sonCekim.pos, sonCekim.ang, sonCekim.fov = pos, ang, fov
     return { origin = pos, angles = ang, fov = fov, drawviewer = true, znear = 3 }
end

/*
*   Çıkış geçişi: kamera kapanınca oyuncunun gözüne yumuşakça döner
*/
local donus = nil

local function DonusGorunum()
     if not donus then return end
     local f = (RealTime() - donus.bas) / math.max(donus.sure, 0.01)
     if f >= 1 then donus = nil return end
     f = YUMUSATMA.yumusak(f)
     local p, a, fv, ucuncu = OyuncuGorus()
     return { origin = LerpVector(f, donus.pos, p), angles = AciLerp(f, donus.ang, a), fov = Lerp(f, donus.fov, fv), drawviewer = ucuncu or f < 0.85 }
end

/*
*   HOOKS_CACHE vekili
*/
local MUDAHALE = {}

MUDAHALE.CalcView = function()
     local v = Gorunum()
     if v then return true, v end
     local d = DonusGorunum()
     if d then return true, d end
end
MUDAHALE.ShouldDrawLocalPlayer = function()
     if G.Sinematik() or donus then return true, true end
end
MUDAHALE.PreDrawViewModel = function() if G.Sinematik() then return true, true end end
MUDAHALE.PreDrawPlayerHands = function() if G.Sinematik() then return true, true end end
MUDAHALE.InputMouseApply = function()
     if G.Kam or G.SahneOyna or (G.Diy and G.Diy.kip == "sinematik" and G.Diy.kamera) then return true, true end
end
MUDAHALE.HUDShouldDraw = function(ad)
     if G.Sinematik() then return true, ad == "CHudGMod" end
end
MUDAHALE.ShouldDisableLegs = function() if G.Sinematik() or donus then return true, true end end

local VEKIL = { ad = "SardonGorev" }
local vekiller = {}

local function Vekil(ad)
     return function(_, ...)
          local f = MUDAHALE[ad]
          if f then
               local yakala, a, b = f(...)
               if yakala then return a, b end
          end
          local eski = saklanan[ad]
          if eski then
               for k, v in pairs(eski) do
                    local a, b, c, d, e, g = v(k, ...)
                    if a ~= nil then return a, b, c, d, e, g end
               end
          end
     end
end

local function VekilKur()
     if not HOOKS_CACHE then return end
     for ad in pairs(MUDAHALE) do
          local mevcut = HOOKS_CACHE[ad]
          if not (mevcut ~= nil and mevcut == vekiller[ad]) then
               saklanan[ad] = mevcut
               local v = { [VEKIL] = Vekil(ad) }
               vekiller[ad] = v
               HOOKS_CACHE[ad] = v
          end
     end
end

local function VekilSok()
     if not HOOKS_CACHE then return end
     for ad in pairs(MUDAHALE) do
          if vekiller[ad] and HOOKS_CACHE[ad] == vekiller[ad] then HOOKS_CACHE[ad] = saklanan[ad] end
          vekiller[ad], saklanan[ad] = nil, nil
     end
end

-- Motor olaylarına hiç HOOKS_CACHE yoksa (Helix dışı) normal kanca da dener
hook.Add("CalcView", "SardonGorev.Kamera", function()
     if HOOKS_CACHE then return end
     local v = Gorunum() or DonusGorunum()
     if v then return v end
end)

-- Panel olarak çizilen HUD'lar (rcore büyü çubuğu) HUDShouldDraw'a uymaz; sinematikte saydamlaşır
local susturulan = {}
local function PanelHUDSustur(sus)
     if sus then
          local m = rcore and rcore.modules and rcore.modules.spells
          local pnl = istable(m) and m.pnl
          if not istable(pnl) then return end
          for _, p in ipairs({ pnl.root, pnl.cast }) do
               if IsValid(p) and not susturulan[p] then
                    susturulan[p] = true
                    p:SetAlpha(0)
               end
          end
     elseif next(susturulan) then
          for p in pairs(susturulan) do
               if IsValid(p) then p:SetAlpha(255) end
          end
          susturulan = {}
     end
end

local vekilAcik = false
hook.Add("Think", "SardonGorev.Vekil", function()
     local gerek = G.Sinematik() or donus ~= nil
     PanelHUDSustur(G.Sinematik())
     if gerek then
          VekilKur()   -- Helix tabloyu yenilerse tazelenir
          vekilAcik = true
     elseif vekilAcik then
          VekilSok()
          vekilAcik = false
          onceki, gecis = nil, nil
     end
end)

local function KameraKapat(sure)
     if G.Kam or (G.Diy and G.Diy.kip == "sinematik") or G.SahneOyna then
          donus = { bas = RealTime(), sure = sure or 0.7, pos = Vector(sonCekim.pos), ang = Angle(sonCekim.ang), fov = sonCekim.fov }
     end
     G.Kam = nil
end

-- Diyalog kapanınca da geri dön
hook.Add("Think", "SardonGorev.DiyalogKamera", function()
     local acik = G.Diy ~= nil and G.Diy.kip == "sinematik" and G.Diy.kamera
     if G.DiyKameraOnceki and not acik and not G.Kam and not G.SahneOyna then
          donus = { bas = RealTime(), sure = 0.6, pos = Vector(sonCekim.pos), ang = Angle(sonCekim.ang), fov = sonCekim.fov }
     end
     G.DiyKameraOnceki = acik
end)

/*
*   Sinema sahnesi (rota + figüranlar)
*/
local function CR(a, b, c, d, t)
     local t2, t3 = t * t, t * t * t
     return 0.5 * ((2 * b) + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * b - a - 3 * c + d) * t3)
end

local function CRM(p0, p1, p2, p3, t)
     local t0 = 0
     local t1 = t0 + math.max(p0:Distance(p1), 0.01) ^ 0.5
     local t2 = t1 + math.max(p1:Distance(p2), 0.01) ^ 0.5
     local t3 = t2 + math.max(p2:Distance(p3), 0.01) ^ 0.5
     local tt = Lerp(t, t1, t2)
     local a1 = p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
     local a2 = p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
     local a3 = p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
     local b1 = a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
     local b2 = a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
     return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))
end

local function YawAc(h, m) return m + math.AngleDifference(h, m) end

local function RotaKur(anahtarlar, ayar)
     local n = #anahtarlar
     if n < 2 then return nil end
     local P, A = {}, {}
     local onceYaw
     for i, k in ipairs(anahtarlar) do
          P[i] = Vector(k.x or 0, k.y0 or k.yy or 0, k.z or 0)
          local y = onceYaw and YawAc(k.y or 0, onceYaw) or (k.y or 0)
          onceYaw = y
          A[i] = { p = k.p or 0, y = y, r = k.r or 0, fov = k.fov or 70 }
     end
     P[0] = P[1] * 2 - P[2]
     P[n + 1] = P[n] * 2 - P[n - 1]
     local function Uzat(a, b) return { p = 2 * a.p - b.p, y = 2 * a.y - b.y, r = 2 * a.r - b.r, fov = 2 * a.fov - b.fov } end
     A[0] = Uzat(A[1], A[2])
     A[n + 1] = Uzat(A[n], A[n - 1])

     local rc = { P = P, A = A, nseg = n - 1, ayar = ayar or {} }
     function rc.Ornekle(U)
          local seg = math.Clamp(math.floor(U), 0, rc.nseg - 1)
          local t = math.Clamp(U - seg, 0, 1)
          local i = seg + 1
          local pos = CRM(P[i - 1], P[i], P[i + 1], P[i + 2], t)
          local a0, a1, a2, a3 = A[i - 1], A[i], A[i + 1], A[i + 2]
          return pos, Angle(CR(a0.p, a1.p, a2.p, a3.p, t), CR(a0.y, a1.y, a2.y, a3.y, t), CR(a0.r, a1.r, a2.r, a3.r, t)), math.Clamp(CR(a0.fov, a1.fov, a2.fov, a3.fov, t), 5, 140)
     end

     -- yay uzunluğu tablosu (sabit hız)
     local adim = 24
     local M = rc.nseg * adim
     local Ls, Us = { [0] = 0 }, { [0] = 0 }
     local once = rc.Ornekle(0)
     local top = 0
     for i = 1, M do
          local U = i / adim
          local pos = rc.Ornekle(U)
          top = top + pos:Distance(once)
          once = pos
          Ls[i], Us[i] = top, U
     end
     function rc.U(s)
          local e = (YUMUSATMA[rc.ayar.rotaYumusatma or "yumusak"] or YUMUSATMA.yumusak)(math.Clamp(s, 0, 1))
          if rc.ayar.rotaSabitHiz == false or top <= 0.01 then return e * rc.nseg end
          local hedef = e * top
          local lo, hi = 0, M
          while hi - lo > 1 do
               local orta = math.floor((lo + hi) / 2)
               if Ls[orta] <= hedef then lo = orta else hi = orta end
          end
          local l0, l1 = Ls[lo], Ls[hi]
          local f = l1 > l0 and (hedef - l0) / (l1 - l0) or 0
          return Lerp(f, Us[lo], Us[hi])
     end
     return rc
end

-- Sinema aktörü (yerel figüran) sürücüsü
local function FiguranKur(v, hare)
     local bg = {}
     for i, b in pairs(v.bg or {}) do bg[#bg + 1] = tostring(i) .. "=" .. tostring(b) end
     local c = G.AktorYerel({
          id = v.ad, ad = v.ad, model = v.model, skin = v.skin, bg = table.concat(bg, ","),
          pos = Vector(v.x or 0, v.y or 0, v.z or 0), yaw = v.yaw or 0,
          bekleAnim = v.animBekle or "", yuruAnim = v.animYuru or "", kosAnim = v.animYuru or "", isimGoster = false,
     })
     c.f = {
          noktalar = {}, hiz = tonumber(v.hiz) or 72, gecikme = tonumber(v.gecikme) or 0, dongu = v.dongu,
          animDurak = v.animDurak or "", animVaris = v.animVaris or "", kos = v.yuruTip == "kos", idx = 1, durum = "gecikme",
     }
     for _, p in ipairs(v.noktalar or {}) do c.f.noktalar[#c.f.noktalar + 1] = { pos = Vector(p.x, p.y, p.z), bekle = tonumber(p.bekle) or 0 } end
     if hare and hare ~= "" and v.hare ~= false then
          c.hare = hare
          c.hareGecis = 1.2
     end
     c.yerelHiz = c.f.hiz
     return c
end

local function FiguranIlerle(c, t, dt)
     local f = c.f
     if f.durum == "gecikme" then
          if t >= f.gecikme then f.durum = #f.noktalar > 0 and "yuru" or "bitti" end
     elseif f.durum == "durak" then
          if t >= f.zaman then
               f.idx = f.idx + 1
               f.durum = "yuru"
               c.anim = nil
          end
     elseif f.durum == "yuru" then
          local hedef = f.noktalar[f.idx]
          if not hedef then
               if f.dongu and #f.noktalar > 0 then f.idx = 1 hedef = f.noktalar[1]
               else
                    f.durum = "bitti"
                    if f.animVaris ~= "" then c.anim = { ad = f.animVaris, dongu = true } end
               end
          end
          if hedef then
               local fark = hedef.pos - c.pos
               fark.z = 0
               local uzak = fark:Length()
               local adim = f.hiz * dt
               if uzak > 1 then c.hedefYaw = fark:Angle().y end
               if uzak <= adim then
                    c.pos = Vector(hedef.pos.x, hedef.pos.y, c.pos.z)
                    if hedef.bekle > 0 then
                         f.durum, f.zaman = "durak", t + hedef.bekle
                         if f.animDurak ~= "" then c.anim = { ad = f.animDurak, dongu = true } end
                    else
                         f.idx = f.idx + 1
                    end
               else
                    c.pos = c.pos + fark * (adim / uzak)
               end
          end
     end
     c.durum = f.durum == "yuru" and "yuru" or "dur"
     if c.hareket == nil then c.hareket = nil end
end

local function SahneBitir(atlandi)
     local s = G.SahneOyna
     if not s then return end
     for _, c in ipairs(s.figuranlar or {}) do G.AktorSil(c, s.atlandi and "" or nil) end
     G.SahneOyna = nil
     if s.efekt and s.efekt ~= "" then G.EfektBaslat({ tur = "", sure = 0 }) end
     donus = { bas = RealTime(), sure = 0.8, pos = Vector(sonCekim.pos), ang = Angle(sonCekim.ang), fov = sonCekim.fov }
     if atlandi then
          G.Iste(G.ISTEK.ATLA, function() net.WriteUInt(s.gorev or 0, 32) end)
     end
end

local function SahneBaslat(t)
     if G.SahneOyna then SahneBitir() end
     local v = t.veri or {}
     local rc = RotaKur(v.anahtarlar or {}, v.ayar)
     local s = { bas = CurTime(), sure = math.max(tonumber(t.sure) or 10, 0.5), rc = rc, figuranlar = {}, atla = t.atla, gorev = t.gorev, serit = t.serit ~= false, efekt = t.efekt }
     for _, a in ipairs(v.aktorler or {}) do s.figuranlar[#s.figuranlar + 1] = FiguranKur(a, t.hare) end
     if s.efekt and s.efekt ~= "" then G.EfektBaslat({ tur = s.efekt, sure = 0, guc = 1, gorev = t.gorev }) end

     s.kamera = function()
          local oran = (CurTime() - s.bas) / s.sure
          if s.rc then
               local pos, ang, fov = s.rc.Ornekle(s.rc.U(oran))
               return pos, ang, fov
          end
          -- rota yoksa: ilk figürana yörünge
          local c = s.figuranlar[1]
          if c and c.cizPos then
               local a = math.rad((CurTime() - s.bas) * 12)
               local pos = c.cizPos + Vector(math.cos(a) * 180, math.sin(a) * 180, 70)
               return pos, (c.cizPos + Vector(0, 0, 50) - pos):Angle(), 55
          end
          return OyuncuGorus()
     end
     G.SahneOyna = s
     onceki, gecis = "s", nil
end

hook.Add("Think", "SardonGorev.Sahne", function()
     local s = G.SahneOyna
     if not s then return end
     local t = CurTime() - s.bas
     local dt = math.min(FrameTime(), 0.1)
     for _, c in ipairs(s.figuranlar) do
          if G.Aktorler[c.no] then FiguranIlerle(c, t, dt) end
     end
     if t >= s.sure then SahneBitir() return end

     -- atlama: BOŞLUK basılı tut
     if s.atla and input.IsKeyDown(KEY_SPACE) and not gui.IsGameUIVisible() then
          s.atlaBas = s.atlaBas or RealTime()
          if RealTime() - s.atlaBas > 0.9 then
               s.atlandi = true
               SahneBitir(true)
          end
     else
          s.atlaBas = nil
     end
end)

/*
*   Kararma
*/
local karart = nil   -- { yon, sure, renk, bas, deger }
local karartDeger = 0

local function KarartBaslat(t)
     karart = { yon = t.yon, sure = math.max(tonumber(t.sure) or 1, 0.01), beyaz = t.renk == "beyaz", bas = RealTime(), ilk = karartDeger }
end

hook.Add("DrawOverlay", "SardonGorev.Karart", function()
     if karart then
          local f = math.Clamp((RealTime() - karart.bas) / karart.sure, 0, 1)
          karartDeger = Lerp(G.Yumusak(f), karart.ilk, karart.yon == "kapan" and 1 or 0)
          if f >= 1 and karart.yon ~= "kapan" then karart = nil end
     end
     if karartDeger > 0.002 then
          local b = karart and karart.beyaz
          surface.SetDrawColor(b and 255 or 0, b and 250 or 0, b and 240 or 0, 255 * karartDeger)
          surface.DrawRect(0, 0, ScrW(), ScrH())
     end
end)

/*
*   Başlık kartı
*/
local baslik = nil

local function BaslikCiz()
     local t = baslik
     if not t then return end
     local gecen = RealTime() - t.bas
     if gecen > t.sure then baslik = nil return end
     local a = math.min(G.Yumusak(gecen / 1.0), G.Yumusak((t.sure - gecen) / 1.0))
     local W, H = ScrW(), ScrH()

     if t.stil == "yer" then
          local x, y = O(70), H - O(200)
          G.Yaz(G.Buyuk(t.ust or ""), F(13, "kalin"), x, y - O(30), R.altin, 0, O(4), 0.9, a)
          G.Yaz(t.baslik or "", F(44, "baslik"), x, y, R.fildisiAcik, 0, O(2), 1, a)
          local w = G.Genislik(t.baslik or "", F(44, "baslik"), O(2))
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 220 * a)
          surface.DrawRect(x, y + O(28), w * G.Yumusak(gecen / 1.4), 1)
          if t.alt and t.alt ~= "" then G.Yaz(t.alt, F(17, "italik"), x, y + O(50), R.govde, 0, nil, 0.9, a) end
          return
     end

     local cx, cy = W / 2, H * 0.42
     surface.SetDrawColor(0, 0, 0, 110 * a)
     surface.DrawRect(0, cy - O(90), W, O(190))
     G.Parilti(cx, cy, O(700), R.altin, 30 * a)
     if t.ust and t.ust ~= "" then G.Yaz(G.Buyuk(t.ust), F(15, "kalin"), cx, cy - O(52), R.altin, 1, O(6), 0.9, a) end
     G.Yaz(t.baslik or "", F(56, "baslik"), cx, cy, R.fildisiAcik, 1, O(3), 1, a)
     local acil = G.Yumusak(gecen / 1.6)
     G.AltinCizgi(cx - O(260) * acil, cy + O(40), O(520) * acil, 220 * a)
     G.Baklava(cx, cy + O(40), O(5), R.altinAcik, 255 * a)
     if t.alt and t.alt ~= "" then G.Yaz(t.alt, F(19, "italik"), cx, cy + O(70), R.govde, 1, nil, 0.9, a) end
end

/*
*   Şeritler + sahne yazıları
*/
local seritA = 0

hook.Add("HUDPaint", "SardonGorev.Sahne", function()
     local istenen = (G.Kam and G.Kam.serit ~= false) or (G.SahneOyna and G.SahneOyna.serit)
     -- diyalog kendi şeridini çizer
     if not (G.Diy and G.Diy.kip == "sinematik") then
          seritA = math.Approach(seritA, istenen and 1 or 0, FrameTime() * 2.5)
          if seritA > 0.001 then G.SeritCiz(seritA) end
     else
          seritA = 1
     end
     local s = G.SahneOyna
     if s and s.atla then
          local il = s.atlaBas and math.Clamp((RealTime() - s.atlaBas) / 0.9, 0, 1) or 0
          G.Yaz("Mantén ESPACIO · saltar", F(12, "kalin"), ScrW() - O(40), ScrH() - O(22), Color(R.soluk.r, R.soluk.g, R.soluk.b, 160), 2, O(2))
          if il > 0 then
               surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 220)
               surface.DrawRect(ScrW() - O(220), ScrH() - O(10), O(180) * il, O(2))
          end
     end
     BaslikCiz()
end)

/*
*   Ekran efektleri
*/
local efekt = nil   -- { tur, guc, bas, sure, gorev, deger }

function G.EfektBaslat(t)
     if (t.tur or "") == "" then
          if efekt then efekt.kapan = RealTime() end
          return
     end
     efekt = { tur = t.tur, guc = tonumber(t.guc) or 1, bas = RealTime(), sure = tonumber(t.sure) or 0, gorev = t.gorev }
     if t.tur == "titreme" then util.ScreenShake(LocalPlayer():GetPos(), 6 * efekt.guc, 18, math.max(efekt.sure, 1.5), 500) end
end

hook.Add("RenderScreenspaceEffects", "SardonGorev.Efekt", function()
     local e = efekt
     if not e then return end
     local simdi = RealTime()
     local g = G.Yumusak((simdi - e.bas) / 1.0)
     if e.sure > 0 and simdi - e.bas > e.sure then e.kapan = e.kapan or (e.bas + e.sure) end
     if e.kapan then
          g = g * (1 - G.Yumusak((simdi - e.kapan) / 1.0))
          if simdi - e.kapan > 1 then efekt = nil return end
     end
     g = g * e.guc

     if e.tur == "ani" then
          DrawColorModify({ ["$pp_colour_addr"] = 0.02 * g, ["$pp_colour_addg"] = 0.025 * g, ["$pp_colour_addb"] = 0.04 * g, ["$pp_colour_brightness"] = 0.02 * g,
               ["$pp_colour_contrast"] = 1 - 0.08 * g, ["$pp_colour_colour"] = 1 - 0.65 * g, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0 })
          DrawBloom(0.62, 1.4 * g, 9, 9, 2, 1, 1, 1, 1)
          DrawToyTown(2, ScrH() * 0.28 * g)
     elseif e.tur == "sepya" then
          DrawColorModify({ ["$pp_colour_addr"] = 0.09 * g, ["$pp_colour_addg"] = 0.05 * g, ["$pp_colour_addb"] = 0, ["$pp_colour_brightness"] = -0.02 * g,
               ["$pp_colour_contrast"] = 1 + 0.05 * g, ["$pp_colour_colour"] = 1 - 0.8 * g, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0 })
     elseif e.tur == "siyahbeyaz" then
          DrawColorModify({ ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0, ["$pp_colour_brightness"] = 0,
               ["$pp_colour_contrast"] = 1 + 0.1 * g, ["$pp_colour_colour"] = 1 - g, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0 })
     elseif e.tur == "ruya" then
          DrawToyTown(4, ScrH() * 0.42 * g)
          DrawBloom(0.7, 0.9 * g, 6, 6, 1, 1, 1, 1, 1)
          DrawColorModify({ ["$pp_colour_addr"] = 0.02 * g, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0.04 * g, ["$pp_colour_brightness"] = 0.02 * g,
               ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1 - 0.3 * g, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0 })
     elseif e.tur == "flas" then
          local f = math.max(0, 1 - (simdi - e.bas) / math.max(e.sure, 0.6))
          DrawColorModify({ ["$pp_colour_addr"] = f * e.guc, ["$pp_colour_addg"] = f * e.guc, ["$pp_colour_addb"] = f * e.guc, ["$pp_colour_brightness"] = 0,
               ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0 })
          if f <= 0 then efekt = nil end
     end
end)

/*
*   Müzik
*/
local muzik = nil   -- { kanal, hedef, seviye, gecis, gorev, dur }

local function MuzikDur(sure)
     if muzik then
          muzik.dur = RealTime()
          muzik.gecis = sure or 2
     end
end

local function MuzikCal(t)
     MuzikDur(1)
     local yeni = { seviye = 0, hedef = tonumber(t.seviye) or 0.5, gecis = tonumber(t.gecis) or 2, gorev = t.gorev, dongu = t.dongu }
     local function Kur(k)
          if not IsValid(k) then return end
          if t.dongu then k:EnableLooping(true) end
          k:SetVolume(0)
          k:Play()
          yeni.kanal = k
          yeni.bas = RealTime()
          if muzik and muzik ~= yeni and IsValid(muzik.kanal) then
               G.EskiMuzik = muzik
          end
          muzik = yeni
     end
     if t.url then
          sound.PlayURL(t.url, "noplay noblock", Kur)
     elseif t.ses then
          G.SesHazir(t.ses, nil, function(dosya)
               if dosya then sound.PlayFile("data/" .. dosya, "noplay noblock", Kur) end
          end, true)
     end
end

hook.Add("Think", "SardonGorev.Muzik", function()
     local e = G.EskiMuzik
     if e and IsValid(e.kanal) then
          local v = e.kanal:GetVolume() - FrameTime() / 1
          if v <= 0 then e.kanal:Stop() G.EskiMuzik = nil else e.kanal:SetVolume(v) end
     end
     local m = muzik
     if not m or not IsValid(m.kanal) then return end
     if m.dur then
          local f = 1 - math.Clamp((RealTime() - m.dur) / math.max(m.gecis, 0.01), 0, 1)
          m.kanal:SetVolume(m.hedef * f)
          if f <= 0 then m.kanal:Stop() muzik = nil end
     else
          local f = math.Clamp((RealTime() - (m.bas or RealTime())) / math.max(m.gecis, 0.01), 0, 1)
          m.kanal:SetVolume(m.hedef * f)
     end
end)

/*
*   Parçacıklar
*/
local parcaciklar = {}   -- { tur, pos/aktor/oyuncu, bitis, gorev, sistem, birikim }

local function ParcacikKonum(p)
     if p.aktor then
          local c = G.Aktorler[p.aktor]
          return c and c.cizPos and (c.cizPos + Vector(0, 0, 36)) or p.pos
     end
     if p.oyuncu then return LocalPlayer():GetPos() + Vector(0, 0, 36) end
     return p.pos
end

local DAHILI = {
     isik_toz = { mat = "sprites/light_glow02_add", renk = { 255, 236, 200 }, oran = 18, boy = { 1, 3.5 }, hiz = 10, omur = { 1.5, 3 }, yaricap = 70, yukari = 14 },
     kivilcim = { mat = "sprites/light_glow02_add", renk = { 255, 196, 110 }, oran = 30, boy = { 1, 2.5 }, hiz = 60, omur = { 0.5, 1.2 }, yaricap = 24, yukari = 40 },
     buhar = { mat = "particle/smokesprites_0001", renk = { 214, 226, 244 }, oran = 8, boy = { 14, 28 }, hiz = 8, omur = { 2, 4 }, yaricap = 60, yukari = 10, alfa = 50 },
}

local function ParcacikBaslat(t)
     if t.sil then
          for i = #parcaciklar, 1, -1 do
               local p = parcaciklar[i]
               if p.gorev == t.gorev then
                    if p.sistem and p.sistem.StopEmission then p.sistem:StopEmission() end
                    table.remove(parcaciklar, i)
               end
          end
          return
     end
     local p = { tur = t.efekt, pos = t.pos, aktor = t.aktor, oyuncu = t.oyuncu, gorev = t.gorev, bitis = (tonumber(t.sure) or 0) > 0 and (RealTime() + t.sure) or nil, birikim = 0 }
     if not DAHILI[p.tur] then
          local pos = ParcacikKonum(p) or LocalPlayer():GetPos()
          PrecacheParticleSystem(p.tur)
          if CreateParticleSystemNoEntity then
               p.sistem = CreateParticleSystemNoEntity(p.tur, pos, Angle(0, 0, 0))
          else
               ParticleEffect(p.tur, pos, Angle(0, 0, 0))
          end
     end
     parcaciklar[#parcaciklar + 1] = p
end

local emitter
hook.Add("Think", "SardonGorev.Parcacik", function()
     if #parcaciklar == 0 then return end
     local simdi = RealTime()
     local dt = math.min(FrameTime(), 0.1)
     for i = #parcaciklar, 1, -1 do
          local p = parcaciklar[i]
          if p.bitis and simdi > p.bitis then
               if p.sistem and p.sistem.StopEmission then p.sistem:StopEmission() end
               table.remove(parcaciklar, i)
          else
               local d = DAHILI[p.tur]
               local pos = ParcacikKonum(p)
               if d and pos then
                    emitter = emitter or ParticleEmitter(pos, false)
                    emitter:SetPos(pos)
                    p.birikim = p.birikim + d.oran * dt
                    while p.birikim >= 1 do
                         p.birikim = p.birikim - 1
                         local x = emitter:Add(d.mat, pos + VectorRand() * d.yaricap * Vector(1, 1, 0.5))
                         if x then
                              x:SetDieTime(math.Rand(d.omur[1], d.omur[2]))
                              x:SetStartSize(math.Rand(d.boy[1], d.boy[2]))
                              x:SetEndSize(d.alfa and d.boy[2] * 2 or 0)
                              x:SetStartAlpha(d.alfa or 220)
                              x:SetEndAlpha(0)
                              x:SetVelocity(VectorRand() * d.hiz + Vector(0, 0, d.yukari))
                              x:SetAirResistance(20)
                              x:SetColor(d.renk[1], d.renk[2], d.renk[3])
                              if d.alfa then x:SetRoll(math.Rand(0, 360)) x:SetRollDelta(math.Rand(-0.5, 0.5)) end
                         end
                    end
               elseif p.sistem and pos and p.sistem.SetControlPoint then
                    p.sistem:SetControlPoint(0, pos)
               end
          end
     end
end)

/*
*   Ağ
*/
local function Temizle(gorev)
     if G.Kam and G.Kam.gorev == gorev then KameraKapat(0.6) end
     if efekt and efekt.gorev == gorev then efekt.kapan = RealTime() end
     if muzik and muzik.gorev == gorev then MuzikDur(2) end
     if G.SahneOyna and G.SahneOyna.gorev == gorev then SahneBitir() end
     ParcacikBaslat({ sil = true, gorev = gorev })
     G.NesneleriTemizle(gorev)
     if karart and karart.yon == "kapan" then karart = { yon = "acil", sure = 0.8, bas = RealTime(), ilk = karartDeger } end
end

net.Receive("SardonGorev.Sahne", function()
     local kod = net.ReadUInt(8)
     if kod == S.BILDIRIM then
          local tur = net.ReadString()
          if tur == "temizle" then Temizle(net.ReadUInt(32)) end
          return
     end

     local t = G.OkuTablo()
     if kod == S.KAMERA then
          t.bas = CurTime()
          t.sure = tonumber(t.sure) or 0
          t.fov = tonumber(t.fov) or 60
          if not isangle(t.ang) then t.ang = Angle(0, 0, 0) end
          G.Kam = t
          donus = nil
     elseif kod == S.KAMERA_BITIR then
          KameraKapat(tonumber(t.gecis) or 0.8)
     elseif kod == S.SINEMA then
          SahneBaslat(t)
     elseif kod == S.KARART then
          KarartBaslat(t)
     elseif kod == S.BASLIK then
          t.bas = RealTime()
          t.sure = tonumber(t.sure) or 5
          baslik = t
          if t.stil == "yer" then G.SonYerKarti = RealTime() end
     elseif kod == S.EFEKT then
          G.EfektBaslat(t)
     elseif kod == S.MUZIK then
          MuzikCal(t)
     elseif kod == S.MUZIK_DUR then
          MuzikDur(tonumber(t.gecis) or 2)
     elseif kod == S.SES then
          local pos = t.aktor and G.Aktorler[t.aktor] and G.Aktorler[t.aktor].cizPos or (isvector(t.pos) and t.pos) or LocalPlayer():GetPos()
          if t.oyunSesi then
               if t.oyuncu then
                    surface.PlaySound(t.oyunSesi)
               else
                    sound.Play(t.oyunSesi, pos + Vector(0, 0, 40), 75, 100, tonumber(t.seviye) or 0.8)
               end
          elseif t.ses then
               G.SesCal(t.ses, nil, { pos = not t.oyuncu and pos or nil, seviye = tonumber(t.seviye) or 0.8, zorla = true, oncelik = true })
          end
     elseif kod == S.PARCACIK then
          ParcacikBaslat(t)
     elseif kod == S.NESNE then
          for _, n in ipairs(t.nesneler or {}) do G.NesneEkle(t.gorev, n) end
     elseif kod == S.NESNE_SIL then
          G.NesneKaldir(t.gorev, t.no)
     end
end)

-- Kamera süresi dolunca kendiliğinden kapanır (sunucu da kilidi açar)
hook.Add("Think", "SardonGorev.KameraSure", function()
     local k = G.Kam
     if k and k.sure > 0 and CurTime() - k.bas >= k.sure then KameraKapat(0.7) end
end)

-- Öldüyse ya da karakter değiştiyse her şeyi bırak
hook.Add("Think", "SardonGorev.SinematikGuvenlik", function()
     local lp = LocalPlayer()
     if IsValid(lp) and not lp:Alive() and (G.Kam or G.SahneOyna) then
          G.Kam = nil
          if G.SahneOyna then SahneBitir() end
          donus = nil
     end
end)

hook.Add("SardonHUDGizle", "SardonGorev.Sahne", function()
     if G.Kam or G.SahneOyna then return true end
end)

/*
*   Yer kartı: oyuncu ışınlanınca (portkey, harita ışınlayıcısı, cisimlenme, yeniden doğma)
*   vardığı yerin adı görevdeki "Hogsmeade" kartıyla aynı biçimde sol altta belirir.
*   Işınlanma = tek karede ~1200 birimden büyük sıçrama; ardından Helix alanı değişirse kart çıkar.
*   Görev kendi yer kartını gösterdiyse (son 4 sn) ikinci kez çıkmaz; aynı yer 30 sn'de bir.
*/
local YAZIM = {
     { "Hogsmade", "Hogsmeade" }, { "Kütüpane", "Kütüphane" }, { "Ravenclow", "Ravenclaw" }, { "OOrta", "Orta" },
     { "WWiltshere", "Wiltshire" }, { "Mağra", "Mağara" }, { "Kulubesi", "Kulübesi" }, { "Kitapcı", "Kitapçı" },
     { "Kıyafetci", "Kıyafetçi" }, { "Snf ", "Sınıf " }, { "Ksks", "KSKS" },
}

local HOGSMEADE_DIGER = { ["Ollivanders"] = true, ["Üç Süpürge"] = true, ["Domuz Kafası"] = true }
local ARAZI = { "Orman", "Göl", "Mezarlık", "Akromantula", "Mağara", "Hagrid", "Quidditch", "Yerleşke", "Ateş Böceği", "İskele", "SYB", "Tahta Köprü", "Baykuş Kulesi Yolu" }
local UZAK = {
     ["Karanlık Malikane"] = "WILTSHIRE", ["Wiltshire"] = "INGLATERRA", ["Bağıran Baraka"] = "CERCA DE HOGSMEADE",
     ["Snatcher Çadır İçi"] = "UN CAMPAMENTO EN EL BOSQUE", ["Snatcher Çadırı"] = "UN CAMPAMENTO EN EL BOSQUE", ["Azkaban"] = "UNA FORTALEZA EN EL MAR DEL NORTE",
     ["Kilise"] = "",
}

local function Bul(ad, liste)
     for _, k in ipairs(liste) do if string.find(ad, k, 1, true) then return true end end
end

function G.YerKartiBilgi(alan)
     local ad = string.Trim(tostring(alan or ""))
     if ad == "" or ad == "New Area" then return end
     for _, y in ipairs(YAZIM) do ad = string.Replace(ad, y[1], y[2]) end

     if string.StartWith(ad, "Hogsmeade") then
          return "Pueblo de magos", "Hogsmeade", string.Trim(string.sub(ad, 10))
     end
     if HOGSMEADE_DIGER[ad] then return "Pueblo de magos", "Hogsmeade", ad end
     if UZAK[ad] ~= nil then return UZAK[ad], ad, "" end
     if Bul(ad, { "Bakanlık", "Seherbaz", "Mahkeme", "Büyü Bakanı", "Dolares" }) then return "Ministerio de Magia", ad, "" end
     if Bul(ad, ARAZI) then return "Terrenos de Hogwarts", ad, "" end
     return "Colegio Hogwarts de Magia y Hechicería", ad, ""
end

function G.YerKartiGoster(alan)
     local ust, baslikAd, alt = G.YerKartiBilgi(alan)
     if not baslikAd then return end
     baslik = { ust = ust, baslik = baslikAd, alt = alt, stil = "yer", sure = 5, bas = RealTime() }
     G.SonYerKarti = RealTime()
end

local yk = { gosterilen = {} }

hook.Add("OnAreaChanged", "SardonGorev.YerKarti", function(_, yeni)
     if yk.bekle then yk.bekle.alan = yeni end
end)

hook.Add("Think", "SardonGorev.YerKarti", function()
     local lp = LocalPlayer()
     if not IsValid(lp) then return end
     local pos = lp:GetPos()
     local simdi = RealTime()

     if yk.son and lp:Alive() and FrameTime() < 0.5 and pos:DistToSqr(yk.son) > 1200 * 1200 then
          yk.bekle = { bas = simdi }
     end
     yk.son = pos

     local b = yk.bekle
     if not b then return end
     local gecen = simdi - b.bas
     if gecen > 7 or (simdi - (G.SonYerKarti or -99)) < 4 then yk.bekle = nil return end
     if not b.alan or gecen < 1 then return end
     -- sinematik / kararma sürerken bekle
     if G.Sinematik() or karartDeger > 0.3 or not lp:Alive() or hook.Run("SardonHUDGizle") then return end

     yk.bekle = nil
     if (yk.gosterilen[b.alan] or -99) + 30 > simdi then return end
     yk.gosterilen[b.alan] = simdi
     G.YerKartiGoster(b.alan)
end)

concommand.Add("sardon_yer_karti_test", function()
     local lp = LocalPlayer()
     G.SonYerKarti = nil
     G.YerKartiGoster(lp.GetArea and lp:GetArea() or "Hogsmade Meydan")
end)
