-- "addons\\sardonbuyuagaci\\lua\\sardon_buyuagaci\\cl_core.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Büyü Ağacı :: istemci çekirdeği
--   * sunucu ayarlarını alır (maliyet, kademe kilitleri, ders puanları)
--   * açma sonucu ve ders ödülü bildirimleri (ekran üstü parşömen şeridi + 2B parçacık)
--   * dünyadaki parçacık efekti (çevredeki oyuncular da görür)

local BA = SardonBuyuAgaci

BA.AyarGeldi = BA.AyarGeldi or false

net.Receive("SardonBuyuAgaci.Ayar", function()
     BA.Ayar = BA.AyarTemizle(net.ReadTable())
     BA.AyarGeldi = true
     hook.Run("SardonBuyuAgaciAyar")
end)

function BA.AyarIste()
     net.Start("SardonBuyuAgaci.AyarIste")
     net.SendToServer()
end

hook.Add("InitPostEntity", "SardonBuyuAgaci.Ayar", function()
     timer.Simple(8, function()
          if (!BA.AyarGeldi) then BA.AyarIste() end
     end)
end)

function BA.AcIstegi(buyu)
     local char = LocalPlayer():GetCharacter()
     if (!char) then return end

     net.Start("SardonBuyuAgaci.Ac")
          net.WriteUInt(char:GetID(), 32)
          net.WriteString(buyu)
     net.SendToServer()
end

/*
*   ekran üstü şerit
*/

local glow = Material("sprites/light_glow02_add")
local hasGlow = !glow:IsError()

local fontKur
local function Fontlar()
     if (fontKur) then return end
     fontKur = true

     local yuz = "Montserrat Medium"
     surface.CreateFont("sba.serit.baslik", {font = "Georgia", size = 22, weight = 400, extended = true, antialias = true})
     surface.CreateFont("sba.serit.alt", {font = yuz, size = 14, weight = 500, extended = true, antialias = true})
     surface.CreateFont("sba.serit.puan", {font = "Georgia", size = 30, weight = 400, extended = true, antialias = true})
end

local seritler = {}
local parcalar = {}

local function Kivilcim(x, y, renk, n, guc)
     for i = 1, n do
          local a = math.Rand(0, math.pi * 2)
          local v = math.Rand(40, 160) * (guc or 1)
          parcalar[#parcalar + 1] = {
               x = x, y = y,
               vx = math.cos(a) * v, vy = math.sin(a) * v - math.Rand(10, 60),
               omur = math.Rand(0.7, 1.6), yas = 0,
               boy = math.Rand(6, 16), renk = renk
          }
     end
end

-- tur: "iyi" | "kotu" | "bilgi"
function BA.Serit(baslik, alt, puanYazi, tur)
     Fontlar()
     local renk = tur == "kotu" and Color(196, 112, 96) or (tur == "bilgi" and Color(174, 186, 152) or Color(222, 192, 120))

     table.insert(seritler, 1, {baslik = baslik, alt = alt, puan = puanYazi, renk = renk, bas = RealTime(), sure = 6, tur = tur})
     while (#seritler > 3) do table.remove(seritler) end

     if (tur != "kotu") then
          Kivilcim(ScrW() / 2, 92, renk, 46, 1.2)
     end
end

local function Kitap()
     local N = HpwRewrite and HpwRewrite.Nocturne
     return N and N.Kitap
end

hook.Add("HUDPaint", "SardonBuyuAgaci.Serit", function()
     if (#seritler == 0 and #parcalar == 0) then return end

     local now = RealTime()
     local ft = FrameTime()
     local K = Kitap()
     local cx = ScrW() / 2
     local y = 60

     for i = #seritler, 1, -1 do
          if (now - seritler[i].bas > seritler[i].sure) then table.remove(seritler, i) end
     end

     for i, s in ipairs(seritler) do
          local t = now - s.bas
          local a = math.Clamp(math.min(t / 0.25, (s.sure - t) / 0.6), 0, 1)
          local w, h = 520, 64
          local x = cx - w / 2
          local yy = y + (1 - math.Clamp(t / 0.25, 0, 1)) * -20

          -- parşömen şeridi (kitap teması dokusu varsa)
          local drawn = false
          if (K and K.Mat and K.Mat("parchment_band")) then
               surface.SetMaterial(K.Mat("parchment_band"))
               surface.SetDrawColor(255, 255, 255, 235 * a)
               surface.DrawTexturedRect(x - 30, yy, w + 60, h)
               drawn = true
          end
          if (!drawn) then
               surface.SetDrawColor(14, 20, 16, 230 * a)
               surface.DrawRect(x, yy, w, h)
          end

          if (!drawn) then
               surface.SetDrawColor(s.renk.r, s.renk.g, s.renk.b, 160 * a)
               surface.DrawOutlinedRect(x, yy, w, h, 1)
          end

          if (hasGlow and s.tur != "kotu") then
               local p = 0.6 + math.sin(now * 3) * 0.2
               surface.SetMaterial(glow)
               surface.SetDrawColor(s.renk.r, s.renk.g, s.renk.b, 120 * a * p)
               surface.DrawTexturedRect(x - 30, yy + h / 2 - 50, 140, 100)
          end

          local tx = x + 26
          if (s.puan) then
               draw.SimpleText(s.puan, "sba.serit.puan", x + 60, yy + h / 2, drawn and Color(99, 43, 40, 255 * a) or ColorAlpha(s.renk, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               tx = x + 110
          end

          local koyu = drawn and Color(40, 30, 18, 255 * a) or Color(236, 226, 200, 255 * a)
          local acik = drawn and Color(70, 56, 36, 230 * a) or Color(180, 172, 150, 230 * a)
          draw.SimpleText(s.baslik, "sba.serit.baslik", tx, yy + 12, koyu)
          draw.SimpleText(s.alt or "", "sba.serit.alt", tx, yy + 38, acik)

          y = y + h + 8
     end

     -- kıvılcımlar
     for i = #parcalar, 1, -1 do
          local p = parcalar[i]
          p.yas = p.yas + ft
          if (p.yas >= p.omur) then
               table.remove(parcalar, i)
          else
               p.vy = p.vy + 90 * ft
               p.vx = p.vx * (1 - 1.5 * ft)
               p.x = p.x + p.vx * ft
               p.y = p.y + p.vy * ft

               local f = 1 - p.yas / p.omur
               local b = p.boy * (0.4 + f * 0.6)
               if (hasGlow) then
                    surface.SetMaterial(glow)
                    surface.SetDrawColor(p.renk.r, p.renk.g, p.renk.b, 255 * f)
                    surface.DrawTexturedRect(p.x - b, p.y - b, b * 2, b * 2)
               else
                    surface.SetDrawColor(p.renk.r, p.renk.g, p.renk.b, 255 * f)
                    surface.DrawRect(p.x - 1, p.y - 1, 2, 2)
               end
          end
     end
end)

/*
*   sunucu yanıtları
*/

net.Receive("SardonBuyuAgaci.Sonuc", function()
     local ok = net.ReadBool()
     local metin = net.ReadString()
     local buyu = net.ReadString()

     -- açık büyü ağacı sayfası kendi patlamasını çizer; yoksa ekran şeridi
     if (hook.Run("SardonBuyuAgaciSonuc", ok, metin, buyu) == true) then return end

     if (ok) then
          surface.PlaySound("ui/achievement_earned.wav")
          BA.Serit(buyu, metin, nil, "iyi")
     else
          surface.PlaySound("buttons/button10.wav")
          BA.Serit("Büyü açılamadı", metin, nil, "kotu")
     end
end)

net.Receive("SardonBuyuAgaci.Odul", function()
     local verildi = net.ReadBool()
     local ders = net.ReadString()
     local puan = net.ReadUInt(8)
     local oran = net.ReadUInt(7)

     if (verildi) then
          surface.PlaySound("ui/achievement_earned.wav")
          local char = LocalPlayer():GetCharacter()
          local toplam = char and BA.Puan(char) + puan or puan -- veri bir tık sonra gelir
          BA.Serit("Büyü Puanı kazandın", ders .. " dersi  ·  katılım %" .. oran .. "  ·  toplam " .. toplam .. "  ·  asa menüsü › Büyü Ağacı", "+" .. puan, "iyi")
          chat.AddText(Color(222, 192, 120), "[Büyü Ağacı] ", color_white, ders .. " dersinden ", Color(222, 192, 120), "+" .. puan .. " Büyü Puanı", color_white, " kazandın.")
     else
          BA.Serit("Büyü Puanı alamadın", ders .. " dersine yeterince katılmadın (%" .. oran .. ", gereken %" .. (BA.Ayar.katilimOrani or 0) .. ").", nil, "kotu")
     end
end)

/*
*   dünya efekti
*   tur 2: puan kazanıldı (yükselen tozlar). Büyü açılışında dünya efekti yok.
*/

local tozMat = "sprites/light_glow02_add"

net.Receive("SardonBuyuAgaci.Efekt", function()
     local ent = net.ReadEntity()
     local tur = net.ReadUInt(3)
     if (!IsValid(ent)) then return end

     local pos = ent:GetPos()
     local em = ParticleEmitter(pos, false)
     if (!em) then return end

     local n = tur == 1 and 70 or 40
     for i = 1, n do
          local a = math.Rand(0, math.pi * 2)
          local r = math.Rand(8, 34)
          local p = em:Add(tozMat, pos + Vector(math.cos(a) * r, math.sin(a) * r, math.Rand(0, 20)))
          if (p) then
               p:SetVelocity(Vector(math.cos(a) * 12, math.sin(a) * 12, math.Rand(40, 110)))
               p:SetGravity(Vector(0, 0, -8))
               p:SetAirResistance(30)
               p:SetDieTime(math.Rand(1.2, 2.6))
               p:SetStartAlpha(255)
               p:SetEndAlpha(0)
               p:SetStartSize(math.Rand(3, 7))
               p:SetEndSize(0)
               p:SetRoll(math.Rand(0, 360))
               if (tur == 1) then
                    p:SetColor(240, 210, 130)
               else
                    p:SetColor(200, 225, 170)
               end
          end
     end

     em:Finish()

     if (ent == LocalPlayer()) then return end
     ent:EmitSound("ambient/energy/whiteflash.wav", 60, tur == 1 and 130 or 160, 0.35)
end)
