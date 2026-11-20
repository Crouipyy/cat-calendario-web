-- "addons\\sardonrevir\\lua\\sardon_revir\\_sh_3runler.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: şifa büyülerinin rünleri.
-- Rün motoru [sardon] akran'ın (SardonAkran.Sablon / Benzerlik): şablonlar [-1, 1] karesinde tek vuruşluk
-- yol, y yukarı, yön ve başlangıç noktası önemli. Episkey, Ferula, Finite, Detoxify, Aguamenti rünleri
-- akran'da zaten var (öğrenciler aynı rünü öğrendi); burada yalnız eksik şifa büyüleri eklenir.
-- Akran yüklenmeden önce kaydedilirse onun "SA.Runler = {...}" ataması silerdi; bu yüzden kayıt
-- Initialize'da ve ilk kullanımda yapılır (SA.Sablon önbelleği o ana dek boştur).

local R = SardonRevir
local pi = math.pi

local function Yay(cx, cy, rx, ry, a0, a1, n)
     n = n or 24
     local out = {}
     for i = 0, n do
          local a = math.rad(a0 + (a1 - a0) * i / n)
          out[#out + 1] = {x = cx + math.cos(a) * rx, y = cy + math.sin(a) * ry}
     end
     return out
end

local function Cizgi(...)
     local out = {}
     for _, p in ipairs({...}) do out[#out + 1] = {x = p[1], y = p[2]} end
     return out
end

local function Param(n, fn)
     local out = {}
     for i = 0, n do
          local x, y = fn(i / n)
          out[#out + 1] = {x = x, y = y}
     end
     return out
end

local function Birlestir(...)
     local out = {}
     for _, parca in ipairs({...}) do
          for i, p in ipairs(parca) do
               local son = out[#out]
               if (!(i == 1 and son and math.abs(son.x - p.x) < 1e-4 and math.abs(son.y - p.y) < 1e-4)) then
                    out[#out + 1] = p
               end
          end
     end
     return out
end

local function Sigdir(pts, w, h)
     local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
     for _, p in ipairs(pts) do
          minx, maxx = math.min(minx, p.x), math.max(maxx, p.x)
          miny, maxy = math.min(miny, p.y), math.max(maxy, p.y)
     end
     local s = math.min(w * 2 / math.max(1e-6, maxx - minx), h * 2 / math.max(1e-6, maxy - miny))
     local cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
     for _, p in ipairs(pts) do
          p.x, p.y = (p.x - cx) * s, (p.y - cy) * s
     end
     return pts
end

R.RUNLER = {
     ["Episkey Duo"] = {
          tarif = "Sol üstten başla, yan yana iki çanak çiz: yaranın dudaklarını iki dikişle birleştirir gibi.",
          yap = function()
               return Sigdir(Birlestir(Yay(-0.45, 0.25, 0.45, 0.75, 180, 360, 20), Yay(0.45, 0.25, 0.45, 0.75, 180, 360, 20)), 0.95, 0.6)
          end
     },
     ["Episkey Maxima"] = {
          tarif = "Sol üstten derin bir çanak çiz; sağ uçtan çanağın içinden sol alta doğru çapraz in.",
          yap = function()
               return Birlestir(Yay(0, 0.25, 0.75, 0.95, 180, 360, 24), Cizgi({0.75, 0.25}, {-0.6, -0.45}))
          end
     },
     ["Episkey Totalum"] = {
          tarif = "Tepeden başla, kalemini kaldırmadan beş köşeli bir yıldız çiz ve tepede kapat.",
          yap = function()
               local pts = {}
               for k = 0, 5 do
                    local a = math.rad(90 - k * 144)
                    pts[#pts + 1] = {math.cos(a) * 0.9, math.sin(a) * 0.9}
               end
               return Cizgi(unpack(pts))
          end
     },
     ["Sanitatem"] = {
          tarif = "Üst yaprağın ucundan başla, tek hamlede üç yapraklı bir şifa çiçeği çiz.",
          yap = function()
               return Param(72, function(t)
                    local th = pi * t
                    local r = math.cos(3 * th) * 0.9
                    local a = th + pi / 2
                    return r * math.cos(a), r * math.sin(a)
               end)
          end
     },
     ["Sanitatem Beneficia"] = {
          tarif = "Üst yapraktan başla, dört yapraklı çiçeği tek hamlede tamamla.",
          yap = function()
               return Param(96, function(t)
                    local th = 2 * pi * t
                    local r = math.cos(2 * th) * 0.9
                    local a = th + pi / 2
                    return r * math.cos(a), r * math.sin(a)
               end)
          end
     },
     ["Sanitatem Maxima"] = {
          tarif = "Alttan dümdüz yukarı çık; tepede sola kıvrılıp bir değnek başı çiz ve ucunu aşağı bırak.",
          yap = function()
               return Sigdir(Birlestir(Cizgi({0.3, -0.95}, {0.3, 0.45}), Yay(-0.1, 0.45, 0.4, 0.45, 0, 180, 18), Cizgi({-0.5, 0.45}, {-0.5, 0.05})), 0.6, 0.95)
          end
     },
     ["Sanitatem Totalum"] = {
          tarif = "Tepeden başla, yılan gibi dört kıvrımla aşağı in: şifacının asasına sarılan yılan.",
          yap = function()
               return Param(64, function(t) return 0.5 * math.sin(2 * pi * 2 * t), 0.95 - 1.9 * t end)
          end
     },
     ["Vulnera Sanentur"] = {
          tarif = "Soldan sağa, gittikçe sönen üç dalga çiz: yara yavaş yavaş kapanıyor, son dalga dümdüz.",
          yap = function()
               return Param(72, function(t) return -0.95 + 1.9 * t, 0.75 * (1 - t) * math.sin(2 * pi * 3 * t) end)
          end
     },
     ["Finite Incantatem"] = {
          tarif = "Finite'nin Z'sini çiz, sonra sağ alt köşeden dümdüz yukarı çıkıp başladığın çizgiye kapat.",
          yap = function()
               return Cizgi({-0.75, 0.75}, {0.75, 0.75}, {-0.75, -0.75}, {0.75, -0.75}, {0.75, 0.75})
          end
     },
     ["Ubi Vulneribus"] = {
          tarif = "Sağ üstten dümdüz in; altta sola kanca gibi kıvrıl ve ucunu yukarı kaldır, kalıntıyı yaradan söker gibi.",
          yap = function()
               return Sigdir(Birlestir(Cizgi({0.5, 0.95}, {0.5, -0.35}), Yay(0, -0.35, 0.5, 0.55, 0, -180, 18), Cizgi({-0.5, -0.35}, {-0.5, 0.15})), 0.6, 0.95)
          end
     },
     ["Rennervate"] = {
          tarif = "Alttan başla, şimşek gibi iki kırılmayla yukarı fırla: uyan!",
          yap = function()
               return Cizgi({-0.15, -0.95}, {0.4, -0.25}, {-0.35, 0.1}, {0.3, 0.95})
          end
     },
     ["Lux Vitae"] = {
          tarif = "Tepeden başla, sola doğru tam bir güneş halkası çiz ve tepeden dümdüz yukarı bir ışın çıkar.",
          yap = function()
               return Sigdir(Birlestir(Yay(0, -0.25, 0.6, 0.6, 90, 450, 36), Cizgi({0, 0.35}, {0, 0.95})), 0.7, 0.95)
          end
     }
}

function R.RunKaydet()
     local SA = SardonAkran
     if (!SA or !istable(SA.Runler)) then return false end
     for ad, t in pairs(R.RUNLER) do
          if (!SA.Runler[ad]) then SA.Runler[ad] = t end
     end
     R.RunlerKayitli = true
     return true
end

-- SardonUtil eklentileri Initialize/InitPostEntity geçtikten sonra (timer.Simple(0)) ve keyfi sırayla yükler:
-- kayıt hemen ve bir sonraki karelerde yeniden denenir (akran o ana dek yüklenmiş olur).
hook.Add("InitPostEntity", "SardonRevir.Runler", function() R.RunKaydet() end)
R.RunKaydet()
timer.Simple(0, function() R.RunKaydet() end)
timer.Simple(3, function() R.RunKaydet() end)

function R.Sablon(buyu)
     if (!R.RunlerKayitli) then R.RunKaydet() end
     local SA = SardonAkran
     return SA and SA.Sablon and SA.Sablon(buyu) or nil
end

-- 0..1
function R.Benzerlik(cizim, buyu)
     if (!R.RunlerKayitli) then R.RunKaydet() end
     local SA = SardonAkran
     return SA and SA.Benzerlik and SA.Benzerlik(cizim, buyu) or 0
end

-- büyünün ışık rengi (çizim izi, uygulama efekti)
local RENK = {
     {"Episkey", Color(255, 150, 170)}, {"Sanitatem", Color(200, 240, 150)}, {"Rennervate", Color(255, 230, 120)},
     {"Detoxify", Color(120, 230, 120)}, {"Finite", Color(200, 220, 255)}, {"Ferula", Color(240, 236, 220)},
     {"Vulnera", Color(255, 120, 90)}, {"Ubi", Color(220, 180, 255)}, {"Lux", Color(255, 240, 180)}, {"Aguamenti", Color(120, 190, 255)}
}
function R.BuyuRenk(buyu)
     buyu = tostring(buyu or "")
     for _, r in ipairs(RENK) do
          if (string.find(buyu, r[1], 1, true)) then return r[2] end
     end
     return Color(255, 220, 160)
end

function R.Kalite(skor, esik)
     local yuzde = skor * 100
     esik = esik or R.Ayar.esik
     if (yuzde >= 92) then return "Kusursuz", Color(240, 214, 140) end
     if (yuzde >= esik + 8) then return "Çok iyi", Color(214, 196, 132) end
     if (yuzde >= esik) then return "Yeterli", Color(174, 196, 140) end
     if (yuzde >= esik - 15) then return "Titrek", Color(214, 160, 96) end
     return "Dağınık", Color(196, 104, 90)
end
