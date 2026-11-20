-- "addons\\sardonetiket\\lua\\sardon_etiket\\cl_0rozet.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sardon Etiket — gömülü SHNE rozeti (Discord sunucu etiketi rozeti, 64×64 PNG) ve küçük çizim yardımcıları.
*   Materyaller oyuncuya inmediği için PNG Lua'ya gömülü; data/sardon_etiket/'e yazılıp Material ile açılır.
*   İki materyal: küçük boylar için "smooth mips", büyük kahraman çizimi için noktasal (piksel sanatı keskin kalsın).
*   Discord rozeti değiştirirse (durumdaki rozet karması farklıysa) CDN'den indirilen kullanılır.
*/
SardonEtiket = SardonEtiket or {}
local E = SardonEtiket

E.RozetKarma = "ae1b70ecfddcb4be18c98f24c3691f9a"
local VERI = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAABmJLR0QA/wD/AP+gvaeTAAAB70lEQVR4nO2aPU7EMBCFx6u9yQZOsNvQB5aGG0AJQggauAWIgh9pe25Ag1h6GjgBWq6CKSjIjIO9xnYm0cwnbZXEnjz7vSReAyiKIhmToQ2boY0Uku5hlKuKoaICcBfAzX/8gzxvLW8EGOPcQtQ9iZ8BKgB3Adys4xev5+8ONqI63Nza++3cGKiPrlBXy8VFRGsGJtNtdH01m7sneRA/A8QLMOYugGJGjTGxANZ+Fe2vTQCv55eL86gOmp4PY6A+vESlxGbC6u0ZXV/N5vRFBWWCeAuIF6B3GUApnQljYPV8iPKZIN4C4gXofQZQcCakr+glC5DX8yHcTPh8f0lqUbwFxAuQbAHkyVisSXuuW/vzW/f0lhV8RwD6fb97du9p0sBkWq9dQFtJcc91l4/XR+/xUEaJt4B4ARIzwDoeNmZYmra9SaCkuN2v0MG8mRCfAbGe3zm+pqfoekAT8QJk/hYYXiZE/y+QNxPCGZDb85R+D08HiBeg8HpA/zMheX9AWia4GVDa85R+DQcD4gXoeE2QZALz9hqAAvsE4zIB4OnmxHs8t+cp4i2gAnAXwE2OEEQePH1Y4UwA7PFQJpT2PEX8DFABuAvgJquf/sD7ntC15yniZ4AKwF0AN11kACX0BdRpTeJngArAXYCiKAon3/CSl39Zz74/AAAAAElFTkSuQmCC"

local yumusak, piksel
local function Yukle()
     if yumusak ~= nil then return end
     yumusak, piksel = false, false
     file.CreateDir("sardon_etiket")
     local yol = "sardon_etiket/rozet_" .. E.RozetKarma:sub(1, 8) .. ".png"
     if not file.Exists(yol, "DATA") then
          local ikili = util.Base64Decode(VERI)
          if not ikili then return end
          file.Write(yol, ikili)
     end
     local m1 = Material("../data/" .. yol, "smooth mips")
     local m2 = Material("../data/" .. yol, "noclamp")
     if not m1:IsError() then yumusak = m1 end
     if not m2:IsError() then piksel = m2 end
end

-- sunucunun bildirdiği rozet karması gömülüden farklıysa CDN'den (gacha'nın URL önbelleğiyle)
local function GuncelMat()
     local d = E.Durum
     local karma = d and d.rozet
     if not karma or karma == E.RozetKarma then return end
     local SG = SardonGacha
     if not (SG and SG.UrlMat) then return end
     local m = SG.UrlMat("https://cdn.discordapp.com/guild-tag-badges/" .. (d.sunucu or "945042002326724649") .. "/" .. karma .. ".png?size=64")
     return m
end

-- x, y sol üst; büyükse noktasal örnekleme. Döner: çizildi mi
function E.RozetCiz(x, y, boy, alfa, buyuk)
     Yukle()
     local m = GuncelMat() or (buyuk and piksel or yumusak)
     if not m then return false end
     surface.SetMaterial(m)
     surface.SetDrawColor(255, 255, 255, 255 * (alfa or 1))
     surface.DrawTexturedRect(x, y, boy, boy)
     return true
end

/*
*   Daire (saat yönünde köşeler; DrawPoly ters sırayı çizmez)
*/
local daireler = {}
function E.Daire(cx, cy, r, renk, alfa)
     local n = math.Clamp(math.floor(r * 0.8), 16, 64)
     local anahtar = n
     local birim = daireler[anahtar]
     if not birim then
          birim = {}
          for i = 0, n - 1 do
               local a = i / n * math.pi * 2
               birim[#birim + 1] = { math.cos(a), math.sin(a) }
          end
          daireler[anahtar] = birim
     end
     local t = {}
     for i, b in ipairs(birim) do t[i] = { x = cx + b[1] * r, y = cy + b[2] * r } end
     draw.NoTexture()
     surface.SetDrawColor(renk.r, renk.g, renk.b, (renk.a or 255) * (alfa or 1))
     surface.DrawPoly(t)
end

-- Görseli daireye kırp (şablon tamponuyla)
function E.DaireResim(mat, cx, cy, r, alfa)
     render.ClearStencil()
     render.SetStencilEnable(true)
     render.SetStencilWriteMask(255)
     render.SetStencilTestMask(255)
     render.SetStencilReferenceValue(1)
     render.SetStencilCompareFunction(STENCIL_ALWAYS)
     render.SetStencilPassOperation(STENCIL_REPLACE)
     render.SetStencilFailOperation(STENCIL_KEEP)
     render.SetStencilZFailOperation(STENCIL_KEEP)
     render.OverrideColorWriteEnable(true, false)
     E.Daire(cx, cy, r, color_white)
     render.OverrideColorWriteEnable(false, false)
     render.SetStencilCompareFunction(STENCIL_EQUAL)
     render.SetStencilPassOperation(STENCIL_KEEP)
     surface.SetMaterial(mat)
     surface.SetDrawColor(255, 255, 255, 255 * (alfa or 1))
     surface.DrawTexturedRect(cx - r, cy - r, r * 2, r * 2)
     render.SetStencilEnable(false)
end

-- ShineCoin simgesi: altın sikke, ortada S
function E.SikkeCiz(x, y, boy, alfa)
     alfa = alfa or 1
     local r = boy / 2
     E.Daire(x + r, y + r, r, Color(140, 116, 70), alfa)
     E.Daire(x + r, y + r, r * 0.86, Color(226, 197, 136), alfa)
     E.Daire(x + r, y + r, r * 0.68, Color(190, 162, 104), alfa)
     local SG = SardonGacha
     local font = SG and SG.F and SG.F(boy * 0.62, "kalin") or "DermaLarge"
     draw.SimpleText("S", font, x + r, y + r, Color(84, 70, 48, 255 * alfa), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
