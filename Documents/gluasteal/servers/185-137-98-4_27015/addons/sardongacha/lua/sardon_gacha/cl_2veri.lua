-- "addons\\sardongacha\\lua\\sardon_gacha\\cl_2veri.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   İstemci verisi: sunucudan gelen durum (cüzdan, pity, açık afişler, ayar, koleksiyon), istekler,
*   kısa bildirimler (ekranın üst ortasında kayan ileti).
*/
local SG = SardonGacha

SG.Durum = SG.Durum or nil       -- { c, p, a, ay, k, t }
SG.SaatFark = SG.SaatFark or 0   -- sunucu os.time() - istemci os.time()
SG.Surum = SG.Surum or 0

local function Oku()
     local n = net.ReadUInt(32)
     if n <= 0 then return nil end
     return util.JSONToTable(util.Decompress(net.ReadData(n)) or "") or nil
end
SG.Oku = Oku

function SG.Simdi() return os.time() + SG.SaatFark end

net.Receive("SardonGacha.Durum", function()
     local t = Oku()
     if not t then return end
     SG.Durum = t
     SG.SaatFark = (tonumber(t.t) or os.time()) - os.time()
     for k, v in pairs(t.ay or {}) do SG.Ayar[k] = v end
     SG.Surum = SG.Surum + 1
     hook.Run("SardonGachaDurum", t)
end)

net.Receive("SardonGacha.Sonuc", function()
     local t = Oku()
     if t and SG.CekilisAc then SG.CekilisAc(t.sonuc or {}, t.afis) end
end)

net.Receive("SardonGacha.Gecmis", function()
     local t = Oku()
     SG.GecmisListe = t and t.liste or {}
     hook.Run("SardonGachaGecmis", SG.GecmisListe)
end)

function SG.Iste(tur, yaz)
     net.Start("SardonGacha.Istek")
     net.WriteUInt(tur, 4)
     if yaz then yaz() end
     net.SendToServer()
end

function SG.DurumIste() SG.Iste(SG.ISTEK.DURUM) end

function SG.CekIste(afisId, adet, adakla)
     SG.Iste(SG.ISTEK.CEK, function()
          net.WriteString(afisId)
          net.WriteUInt(adet, 4)
          net.WriteBool(adakla and true or false)
     end)
end

function SG.TakasIste(kaynak, adet)
     SG.Iste(SG.ISTEK.TAKAS, function()
          net.WriteString(kaynak)
          net.WriteUInt(math.Clamp(adet, 1, 100), 8)
     end)
end

function SG.GecmisIste() SG.Iste(SG.ISTEK.GECMIS) end

function SG.Cuzdan()
     local c = SG.Durum and SG.Durum.c
     return c and c.adak or 0, c and c.bilet or 0, c and c.toz or 0
end

-- Asa elde mi? (gachadan çıkmış ya da hesapta/oturumda var)
function SG.Elde(skin)
     local k = SG.Durum and SG.Durum.k
     if k and k[skin] then return true end
     return HpwRewrite and HpwRewrite.PlayerHasSpell and HpwRewrite:PlayerHasSpell(LocalPlayer(), skin) or false
end

/*
*   Bildirim (üst orta)
*/
local bildirimler = {}
local TUR_IKON = { adak = "adak", bilet = "bilet", toz = "toz" }

function SG.Bildirim(metin, tur)
     table.insert(bildirimler, 1, { metin = metin, tur = tur or "bilgi", t0 = RealTime() })
     while #bildirimler > 4 do table.remove(bildirimler) end
     if tur == "hata" then surface.PlaySound("buttons/button10.wav")
     elseif TUR_IKON[tur] then surface.PlaySound("garrysmod/content_downloaded.wav") end
end

net.Receive("SardonGacha.Bildirim", function()
     local metin = net.ReadString()
     local tur = net.ReadString()
     SG.Bildirim(metin, tur)
     hook.Run("SardonGachaBildirim", metin, tur)
end)

local OMUR = 4.2
hook.Add("DrawOverlay", "SardonGacha.Bildirim", function()
     if #bildirimler == 0 then return end
     local R = SG.R
     local olc = ScrH() / 1080
     local font = SG.F(17 * olc, "orta")
     local y = ScrH() * 0.2
     for i = #bildirimler, 1, -1 do
          local b = bildirimler[i]
          local g = RealTime() - b.t0
          if g > OMUR then table.remove(bildirimler, i) end
     end
     for i, b in ipairs(bildirimler) do
          local g = RealTime() - b.t0
          local a = math.min(SG.Kolay(g / 0.25), 1 - SG.Yumusak((g - OMUR + 0.5) / 0.5))
          if a > 0 then
               surface.SetFont(font)
               local tw, th = surface.GetTextSize(b.metin)
               local ikon = TUR_IKON[b.tur]
               local iw = ikon and (th + 10 * olc) or 0
               local w, h = tw + iw + 44 * olc, th + 20 * olc
               local x = ScrW() / 2 - w / 2
               local yy = y - (1 - a) * 14 * olc
               draw.RoundedBox(h / 2, x, yy, w, h, Color(8, 13, 11, 236 * a))
               local cz = b.tur == "hata" and R.hata or R.altin
               surface.SetDrawColor(cz.r, cz.g, cz.b, 120 * a)
               surface.DrawRect(x + h / 2, yy + h - 1, w - h, 1)
               local tx = x + 22 * olc
               if ikon then
                    SG.Ikon(ikon, tx, yy + h / 2 - th * 0.6, th * 1.2, a)
                    tx = tx + iw
               end
               draw.SimpleText(b.metin, font, tx, yy + h / 2, ColorAlpha(b.tur == "hata" and R.hata or R.fildisiAcik, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               y = y + h + 8 * olc
          end
     end
end)
