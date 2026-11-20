-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_2ag.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: ağ (istemci)

local Y = SardonYaratik

Y.Benim = Y.Benim or {liste = {}, yemlik = {}, kapasite = 0, canli = 0, yumurta = 0}
Y.ZamanFarki = Y.ZamanFarki or 0 -- sunucu os.time - istemci os.time

function Y.SunucuZamani()
     return os.time() + Y.ZamanFarki
end

function Y.Islem(op, id, ek, sayi)
     net.Start(Y.NET.ISLEM)
          net.WriteString(op)
          net.WriteUInt(id or 0, 32)
          net.WriteString(ek or "")
          net.WriteFloat(sayi or 0)
     net.SendToServer()
end

function Y.BenimKayit(id)
     for _, k in ipairs(Y.Benim.liste or {}) do
          if k.id == id then return k end
     end
end

net.Receive(Y.NET.LISTE, function()
     local boy = net.ReadUInt(32)
     local veri = util.JSONToTable(util.Decompress(net.ReadData(boy)) or "")
     if not istable(veri) then return end
     Y.ZamanFarki = (veri.zaman or os.time()) - os.time()
     veri.alindi = os.time()
     Y.Benim = veri
     hook.Run("SardonYaratikListe", veri)
end)

net.Receive(Y.NET.ALAN, function()
     Y.AlanAyarla(net.ReadTable())
end)

net.Receive(Y.NET.BILDIRIM, function()
     local metin = net.ReadString()
     local tur = net.ReadString()
     Y.Bildirim(metin, tur)
end)

net.Receive(Y.NET.EFEKT, function()
     local ad = net.ReadString()
     local ent = net.ReadEntity()
     local deger = net.ReadFloat()
     if Y.EfektOynat then Y.EfektOynat(ad, ent, deger) end
end)

net.Receive(Y.NET.OYUN, function()
     local tur = net.ReadString()
     local id = net.ReadUInt(32)
     local jeton = net.ReadUInt(32)
     local ent = net.ReadEntity()
     if Y.OyunAc then Y.OyunAc(tur, id, jeton, ent) end
end)

-- yönetim verisi
net.Receive(Y.NET.YVERI, function()
     Y.YonetimVeri = net.ReadTable()
     local ctx = ShineAdmin and ShineAdmin.ActiveCtx and ShineAdmin:ActiveCtx("yaratik")
     if ctx and ctx.YaratikYenile then ctx.YaratikYenile() end
end)

function Y.Yonetim(islem, veri)
     net.Start(Y.NET.YONETIM)
          net.WriteString(islem)
          net.WriteTable(veri or {})
     net.SendToServer()
end
