-- "addons\\sardonrevir\\lua\\sardon_revir\\cl_1tema.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: istemci çekirdeği (durum, net, tema).
-- 2B yardımcılar ve fontlar [sardon] akran'dan (SardonAkran: SA.Kart, SA.Metin, SA.Isik, SA.Run2D, SA.Parcacik ...).
-- Dokular: oyunla gelen materyaller + asa menüsünün gömülü kitap dokuları (SA.Doku). Dosya dağıtımı gerekmez.

local R = SardonRevir
local SA = setmetatable({}, {__index = function(_, k) local A = SardonAkran return A and A[k] end}) -- akran sonradan yüklenebilir

timer.Simple(15, function()
     if (!SardonAkran) then ErrorNoHalt("[Sardon Revir] SardonAkran (rün motoru ve arayüz yardımcıları) yüklü değil; revir istemcisi çalışmaz.\n") end
end)

R.Benim = R.Benim or nil     -- kendi ilerlemem (sunucudan)
R.Nobet = R.Nobet or nil     -- süren nöbetim
R.Karne = R.Karne or nil

R.C = {
     altin = Color(222, 192, 120),
     altinK = Color(174, 145, 92),
     fildisi = Color(232, 224, 200),
     soluk = Color(171, 169, 147),
     sonuk = Color(127, 137, 120),
     sifa = Color(150, 214, 150),
     sifaK = Color(96, 150, 104),
     kotu = Color(206, 104, 90),
     uyari = Color(220, 168, 96),
     mavi = Color(150, 196, 236),
     murekkep = Color(54, 38, 24),
     murekkepK = Color(96, 74, 52),
     parsomen = Color(226, 210, 172),
     parsomenK = Color(206, 188, 148),
     zemin = Color(12, 18, 16, 238)
}

local fontKur
function R.Fontlar()
     if (SA and SA.Fontlar) then SA.Fontlar() end
     if (fontKur) then return end
     fontKur = true
     local function F(ad, yuz, boy, kalin, italik)
          surface.CreateFont("srv." .. ad, {font = yuz, size = boy, weight = kalin or 400, extended = true, antialias = true, italic = italik})
     end
     F("defterBaslik", "Georgia", 30)
     F("defterAlt", "Georgia", 20)
     F("defter", "Georgia", 18)
     F("defterK", "Georgia", 16)
     F("defterI", "Georgia", 17, 400, true)
     F("etiket", "Montserrat SemiBold", 13, 600)
     F("kucuk", "Montserrat Medium", 14, 500)
     F("orta", "Montserrat Medium", 16, 500)
     F("diyalog", "Georgia", 21)
     F("diyalogI", "Georgia", 20, 400, true)
     F("isim", "Montserrat SemiBold", 15, 600)
     F("balon", "Montserrat Medium", 15, 500)
end

function R.Yazi(str, font, x, y, c, ax, ay, a)
     if (a) then c = ColorAlpha(c, a) end
     return draw.SimpleText(str, "srv." .. font, x, y, c, ax, ay)
end

function R.YaziG(str, font)
     surface.SetFont("srv." .. font)
     return surface.GetTextSize(tostring(str or ""))
end

local sarOnbellek = {}
function R.Sar(str, font, maxw)
     str = tostring(str or "")
     local anahtar = font .. "|" .. maxw .. "|" .. str
     if (sarOnbellek[anahtar]) then return sarOnbellek[anahtar] end
     surface.SetFont("srv." .. font)
     local satirlar, satir = {}, ""
     for kelime in string.gmatch(str, "%S+") do
          local deneme = satir == "" and kelime or (satir .. " " .. kelime)
          if (surface.GetTextSize(deneme) > maxw and satir != "") then
               satirlar[#satirlar + 1] = satir
               satir = kelime
          else
               satir = deneme
          end
     end
     if (satir != "") then satirlar[#satirlar + 1] = satir end
     if (table.Count(sarOnbellek) > 400) then sarOnbellek = {} end
     sarOnbellek[anahtar] = satirlar
     return satirlar
end

function R.Serit(baslik, alt, tur)
     if (SA and SA.Serit) then return SA.Serit(baslik, alt, tur) end
     chat.AddText(R.C.sifa, "[Revir] ", R.C.fildisi, baslik .. (alt != "" and (" — " .. alt) or ""))
end

function R.Islem(op, id, yaz)
     net.Start("SardonRevir.Islem")
          net.WriteUInt(op, 4)
          net.WriteUInt(id or 0, 16)
          if (yaz) then yaz() end
     net.SendToServer()
end
R.ISLEM = {KONUS = 1, SECIM = 2, MUAYENE = 3, TARA = 4, TESHIS = 5, ESYA = 6, SEVK = 7, BIRAK = 8, BASLA = 9}

function R.BenimHasta(id)
     for _, h in ipairs(R.Nobet and R.Nobet.hastalar or {}) do
          if (h.id == id) then return h end
     end
end

function R.Biliyor(buyu)
     return HpwRewrite and HpwRewrite.PlayerHasSpell and HpwRewrite:PlayerHasSpell(nil, buyu) or false
end

function R.Ustalik(buyu)
     local u = R.Benim and R.Benim.u and tonumber(R.Benim.u[buyu]) or 0
     return R.UstalikKademe(u), u
end

-- teşhise göre sıradaki adım
function R.PlanAdimC(h)
     local t = h and h.teshis != "" and R.Hastalik(h.teshis)
     return t and t.tedavi[h.gAdim + 1] or nil, t
end

--[[
*   net
]]

net.Receive("SardonRevir.Veri", function()
     R.Ayar = R.AyarTemizle(net.ReadTable())
     if (net.ReadBool()) then
          R.Harita = R.HaritaCoz(net.ReadTable()) or R.Harita
     end
     hook.Run("SardonRevirVeri")
end)

net.Receive("SardonRevir.Kayit", function()
     local t = {}
     t.charid = net.ReadUInt(32)
     t.deneyim = net.ReadUInt(32)
     t.birikim = net.ReadUInt(32)
     t.dalpuan = net.ReadUInt(16)
     t.iyilesen = net.ReadUInt(16)
     t.nobet = net.ReadUInt(16)
     t.dogru = net.ReadUInt(16)
     t.kalanHak = net.ReadUInt(8)
     t.sifirlama = CurTime() + net.ReadUInt(32)
     t.u = net.ReadTable()
     t.b = net.ReadTable()
     t.tk = net.ReadTable()
     t.unvan = net.ReadString()
     R.Benim = t
     hook.Run("SardonRevirKayit", t)
end)

net.Receive("SardonRevir.Nobet", function()
     local eski = R.Nobet
     if (!net.ReadBool()) then
          R.Nobet = nil
          if (R.CizimBitir) then R.CizimBitir(true) end
          hook.Run("SardonRevirNobet", nil, eski)
          return
     end
     local N = {bitis = net.ReadFloat(), kazanc = net.ReadUInt(16), test = net.ReadBool(), hastalar = {}}
     for i = 1, net.ReadUInt(3) do
          local h = {}
          h.id = net.ReadUInt(16)
          h.yatak = net.ReadUInt(4)
          h.ad = net.ReadString()
          h.hane = net.ReadString()
          h.yil = net.ReadUInt(3)
          h.kisilik = net.ReadString()
          h.durum = net.ReadString()
          h.acik = {}
          for b in string.gmatch(net.ReadString(), "[^,]+") do h.acik[b] = true end
          h.teshis = net.ReadString()
          h.gAdim = net.ReadUInt(4)
          h.yanlis = net.ReadUInt(4)
          h.hikaye = net.ReadBool()
          h.belirti = net.ReadBool()
          h.muayene = net.ReadBool()
          h.tarama = net.ReadBool()
          h.gercek = net.ReadString()
          h.deneyim = net.ReadUInt(12)
          N.hastalar[i] = h
     end
     R.Nobet = N
     if (!eski) then R.NobetAcilis = RealTime() end
     hook.Run("SardonRevirNobet", N, eski)
end)

net.Receive("SardonRevir.Bildirim", function()
     local b, a, t = net.ReadString(), net.ReadString(), net.ReadString()
     R.Serit(b, a, t != "" and t or nil)
     if (t == "iyi") then surface.PlaySound("buttons/blip1.wav") elseif (t == "kotu") then surface.PlaySound("buttons/button10.wav") end
end)

net.Receive("SardonRevir.Karne", function()
     R.Karne = net.ReadTable()
     R.Karne.acilis = RealTime()
     if (R.KarneAc) then R.KarneAc(R.Karne) end
end)
