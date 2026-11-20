-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_4denetim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: profesör denetimi — istemci
--   Öğrenci (11-09): Akran talimi / revir tedavisi gibi havada 3B rün düzlemi (cl_3cizim denetim kipi):
--   ekranın ortası asanın ucu, kılavuz rün + yeşil başlangıç halkası + akan oklar; sol tık basılı tek hamle,
--   süre ve barem üstte. Hamle bitince noktalar SardonKitap.DenetimIz paketleriyle gider, puanı sunucu verir.
--   Diğerleri: iz sunucudan gelir, öğrencinin önünde havada görünür (normal derinlikle), bitince solar.
--   Profesör: sonuç listesi ekranın solunda.

local SK = SardonKitap
local R = SK.R

local OLCEK = 34          -- başkalarının izinde rünün yarı boyu (birim)
local iz = Material("trails/laser")

SK.Izler = SK.Izler or {} -- [ent] = başkalarının izleri
SK.ProfSonuc = SK.ProfSonuc or nil
SK.Denetim = nil

-- eski imleçli pano (11-09 öncesi) kancaları: canlı yenilemede kalmasınlar
hook.Remove("Think", "SardonKitap.Denetim")
hook.Remove("CreateMove", "SardonKitap.Denetim")
hook.Remove("PlayerBindPress", "SardonKitap.Denetim")
hook.Remove("PreDrawTranslucentRenderables", "SardonKitap.Kamera")

local function Duzlem(T, x, y)
     return T.merkez + T.sag * (x * OLCEK) + T.yuk * (y * OLCEK)
end

net.Receive("SardonKitap.Denetim", function()
     local id, buyu, sure, barem, prof = net.ReadUInt(16), net.ReadString(), net.ReadUInt(8), net.ReadUInt(8), net.ReadString()
     if SK.Cizim3BAcik and SK.Cizim3BAcik() then
          local T = SardonKitap.C3 and SardonKitap.C3.T
          if T and T.denetim and not T.kapanis then return end -- süren denetim
     end
     if IsValid(SK.Acik) then SK.Acik:Kapat() end
     SK.Fontlar()
     local ok = SK.Cizim3BBasla and SK.Cizim3BBasla(nil, nil, nil, buyu, {id = id, sure = sure, barem = barem, prof = prof})
     if not ok then
          -- düzlem açılamadı (ölü, araçta, rün tanıma yok): sunucu boş bekletmesin
          net.Start("SardonKitap.DenetimBitir")
          net.WriteUInt(id, 16)
          net.WriteBool(true)
          net.SendToServer()
          return
     end
     surface.PlaySound("buttons/button14.wav") -- bilgi kartı yok: üstteki denetim kutusuyla çakışıyordu
end)

net.Receive("SardonKitap.DenetimSonuc", function()
     local prof = net.ReadBool()
     if prof then
          local grup, buyu, toplam, ad, skor, basari, metin = net.ReadUInt(16), net.ReadString(), net.ReadUInt(8), net.ReadString(), net.ReadFloat(), net.ReadBool(), net.ReadString()
          local s = SK.ProfSonuc
          if not s or s.grup ~= grup then
               s = {grup = grup, buyu = buyu, toplam = toplam, satirlar = {}}
               SK.ProfSonuc = s
          end
          s.satirlar[#s.satirlar + 1] = {ad = ad, skor = skor, basari = basari, metin = metin}
          s.t = CurTime()
          return
     end
     local id, skor, basari, metin = net.ReadUInt(16), net.ReadFloat(), net.ReadBool(), net.ReadString()
     if SK.Cizim3BDenetimSonuc and SK.Cizim3BDenetimSonuc(id, skor, basari, metin) then return end
     SK.Kart(basari and "Denetim: başarılı" or "Denetim: başarısız", "%" .. math.floor(skor * 100) .. " · " .. metin, basari and "iyi" or "uyari")
end)

net.Receive("SardonKitap.DenetimYayin", function()
     local ent, id, tip = net.ReadEntity(), net.ReadUInt(16), net.ReadUInt(2)
     if not IsValid(ent) or ent == LocalPlayer() then return end
     if tip == 1 then
          local merkez, sag, yuk, buyu = net.ReadVector(), net.ReadNormal(), net.ReadNormal(), net.ReadString()
          local z = SK.Izler[ent]
          if not z or z.id ~= id then
               z = {id = id, noktalar = {}, buyu = buyu}
               SK.Izler[ent] = z
          end
          z.merkez, z.sag, z.yuk, z.son = merkez, sag, yuk, CurTime()
          for i = 1, net.ReadUInt(6) do
               z.noktalar[#z.noktalar + 1] = {x = net.ReadInt(16) / 1000, y = net.ReadInt(16) / 1000}
          end
     elseif tip == 2 then
          local z = SK.Izler[ent]
          if z and z.id == id then
               z.bitti = CurTime()
               z.skor, z.basari = net.ReadFloat(), net.ReadBool()
          end
     end
end)

/*
*   başkalarının izleri
*/
local function Iz(T, noktalar, renk, kalin)
     render.SetMaterial(iz)
     for i = 2, #noktalar do
          render.DrawBeam(Duzlem(T, noktalar[i - 1].x, noktalar[i - 1].y), Duzlem(T, noktalar[i].x, noktalar[i].y), kalin, 0, 1, renk)
     end
end

hook.Add("PostDrawTranslucentRenderables", "SardonKitap.Denetim", function(derinlik, gok)
     if gok then return end
     local simdi = CurTime()
     for ent, z in pairs(SK.Izler) do
          if not IsValid(ent) or (z.bitti and simdi - z.bitti > 5) or (not z.bitti and simdi - (z.son or 0) > 30) then
               SK.Izler[ent] = nil
          elseif z.merkez and z.merkez:DistToSqr(EyePos()) < 1200 * 1200 then
               local a = z.bitti and math.Clamp(1 - (simdi - z.bitti) / 5, 0, 1) or 1
               local c = z.bitti and (z.basari and Color(140, 230, 140, 255 * a) or Color(230, 120, 100, 255 * a)) or Color(255, 220, 140, 230)
               Iz(z, z.noktalar, c, 2)
          end
     end
end)

/*
*   ekran
*/
hook.Add("HUDPaint", "SardonKitap.Denetim", function()
     -- profesöre sonuç listesi
     local s = SK.ProfSonuc
     if s and CurTime() - s.t < 40 then
          SK.Fontlar()
          local w = SK.S(300)
          local x, y = SK.S(20), ScrH() * 0.3
          local h = SK.S(44) + #s.satirlar * SK.S(22)
          SK.Kutu(x, y, w, h, R.hud)
          surface.SetDrawColor(R.hudCizgi) surface.DrawOutlinedRect(x, y, w, h, 1)
          SK.Yazi(SK.Buyuk("Denetim · " .. s.buyu), "ust", x + SK.S(12), y + SK.S(10), R.altinA)
          SK.Yazi(#s.satirlar .. " / " .. s.toplam, "ust", x + w - SK.S(12), y + SK.S(10), R.hudSoluk, TEXT_ALIGN_RIGHT)
          for i, r in ipairs(s.satirlar) do
               local ry = y + SK.S(26) + (i - 1) * SK.S(22)
               SK.Yazi(r.ad, "hudK", x + SK.S(12), ry, R.hudYazi)
               local m = r.metin == "iptal" and "iptal" or ("%" .. math.floor(r.skor * 100))
               SK.Yazi(m, "hudK", x + w - SK.S(12), ry, r.basari and Color(140, 220, 140) or Color(230, 140, 120), TEXT_ALIGN_RIGHT)
          end
     end
end)
