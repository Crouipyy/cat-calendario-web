-- "addons\\sardongorev\\lua\\sardon_gorev\\_sh_4sandal.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sandal yolculuğu (paylaşılan): oyuncu ve görev aktörleri bir sandalda, bir "yol" yerinin
*   noktaları boyunca kendiliğinden gider (ör. birinci sınıfların Kara Göl geçişi).
*
*   İki taraf aynı hesabı yapar: kontrol noktaları + hız + başlangıç zamanı → Catmull-Rom eğrisi,
*   yay uzunluğu tablosu, başta ve sonda yumuşak hızlanma. Sunucu yalnız başlangıcı ve bitişi
*   gönderir (sv_3sandal.lua). Oyuncunun konumu Move kancasında eğriden verilir: tahmin iki
*   tarafta aynı olduğu için titremez. Sandal istemcide ClientsideModel (cl_3b_sandal.lua),
*   sandaldaki aktörler cl_3aktor.lua'da koltuğa oturtulur.
*/
local G = SardonGorev

G.Sandallar = G.Sandallar or {}   -- [no] = s

G.SANDAL = {
     model = "models/props_swamp/row_boat_ref.mdl",
     yedekModel = "models/props_canal/boat001a.mdl",
     modelYaw = 0,                   -- modelin burnu +x'e bakmıyorsa düzeltme
     hiz = 105,                      -- birim/sn
     ivme = 3.5,                     -- kalkış ve yanaşma süresi (sn)
     su = 4,                         -- gövde merkezi su yüzeyinin bu kadar üstünde
     koltuk = Vector(-44, 0, -4),    -- oyuncu (sandala göre): kıçta, yüzü pruvaya
     koltukYaw = 0,
     yolcu = Vector(48, 0, -4),      -- aktör: pruvada, yüzü oyuncuya
     yolcuYaw = 180,
     oturAnim = "sit",
}

-- Kontrol noktaları tam sayıya yuvarlanır: net.WriteVector iki tarafta aynı değeri taşısın
function G.SandalNokta(p)
     return Vector(math.Round(p.x), math.Round(p.y), math.Round(p.z))
end

-- s = { noktalar = {Vector...}, hiz, ivme, t0 }  →  s.yol, s.uzun, s.toplam, s.ta, s.sure
function G.SandalHazirla(s)
     local n = s.noktalar
     local yol = {}
     for i = 1, #n - 1 do
          local p0, p1, p2, p3 = n[math.max(1, i - 1)], n[i], n[i + 1], n[math.min(#n, i + 2)]
          local adim = math.max(2, math.ceil(p1:Distance(p2) / 40))
          for k = 0, adim - 1 do
               local t = k / adim
               local t2, t3 = t * t, t * t * t
               yol[#yol + 1] = (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
          end
     end
     yol[#yol + 1] = n[#n]

     local uzun, top = { 0 }, 0
     for i = 2, #yol do
          top = top + yol[i - 1]:Distance(yol[i])
          uzun[i] = top
     end
     s.yol, s.uzun, s.toplam = yol, uzun, top
     s.hiz = math.max(10, tonumber(s.hiz) or G.SANDAL.hiz)
     s.ta = math.min(tonumber(s.ivme) or G.SANDAL.ivme, top / s.hiz)
     -- hızlanma + yavaşlama sabit hızlı yolu ta kadar uzatır
     s.sure = top / s.hiz + s.ta
     return s
end

-- t saniyede alınan yol (yumuşak kalkış / yanaşma)
local function Mesafe(s, t)
     local v, ta, T = s.hiz, s.ta, s.sure
     if t <= 0 then return 0 end
     if t >= T then return s.toplam end
     if ta <= 0 then return math.min(s.toplam, v * t) end
     if t < ta then return v * t * t / (2 * ta) end
     local kalan = T - t
     if kalan < ta then return s.toplam - v * kalan * kalan / (2 * ta) end
     return v * ta / 2 + v * (t - ta)
end

-- Eğri üzerinde d mesafesindeki nokta ve parçanın yönü
local function Nokta(s, d)
     local u, yol = s.uzun, s.yol
     local alt, ust = 1, #yol
     while ust - alt > 1 do
          local m = math.floor((alt + ust) / 2)
          if u[m] <= d then alt = m else ust = m end
     end
     local a, b = yol[alt], yol[ust]
     local parca = u[ust] - u[alt]
     local f = parca > 0 and math.Clamp((d - u[alt]) / parca, 0, 1) or 0
     return LerpVector(f, a, b), (b - a):Angle().y
end

-- t anında sandalın gövde merkezi, yönü ve varıp varmadığı
function G.SandalDurum(s, t)
     local d = Mesafe(s, t - s.t0)
     local pos, yaw = Nokta(s, d)
     -- biraz ileriye bak: dönüşler yumuşasın
     local ileri = Nokta(s, math.min(s.toplam, d + 60))
     if ileri:DistToSqr(pos) > 4 then yaw = (ileri - pos):Angle().y end
     pos = pos + Vector(0, 0, G.SANDAL.su + math.sin(t * 1.6) * 1.2)
     return pos, yaw, t - s.t0 >= s.sure
end

-- Sandaldaki bir koltuğun dünya konumu ve yönü
function G.SandalYeri(s, t, ofs, yawOfs)
     local pos, yaw = G.SandalDurum(s, t)
     local w = LocalToWorld(ofs or G.SANDAL.koltuk, angle_zero, pos, Angle(0, yaw, 0))
     return w, yaw + (yawOfs or 0)
end

function G.SandalAl(ply)
     local no = ply:GetNW2Int("SardonSandal", 0)
     if no == 0 then return end
     local s = G.Sandallar[no]
     if s and s.yol then return s end
end

/*
*   Sandaldaki oyuncu: konum eğriden, hız yok (ayak sesi ve koşu animasyonu çıkmasın), oturur
*/
hook.Add("Move", "SardonGorev.Sandal", function(ply, mv)
     local s = G.SandalAl(ply)
     if not s then return end
     mv:SetOrigin(G.SandalYeri(s, CurTime(), G.SANDAL.koltuk))
     mv:SetVelocity(vector_origin)
     return true
end)

hook.Add("CalcMainActivity", "SardonGorev.Sandal", function(ply)
     if ply:GetNW2Int("SardonSandal", 0) == 0 then return end
     local seq = ply:LookupSequence(G.SANDAL.oturAnim)
     if not seq or seq < 0 then return end
     return ACT_HL2MP_SIT, seq
end)

hook.Add("PlayerFootstep", "SardonGorev.Sandal", function(ply)
     if ply:GetNW2Int("SardonSandal", 0) ~= 0 then return true end
end)
