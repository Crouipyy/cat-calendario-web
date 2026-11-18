-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_4ses.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Ses önbelleği ve çalma.
*   Dosyalar data/sardon_gorev/onbellek/<crc>.<uzantı>; dosya sunucuda değişince crc değişir,
*   eskisi bir daha kullanılmaz (açılışta 30 günden eskiler silinir).
*/
local G = SardonGorev

local KLASOR = "sardon_gorev/onbellek"
file.CreateDir("sardon_gorev")
file.CreateDir(KLASOR)

G.SesDurum = G.SesDurum or {}      -- [yol] = { crc, uzanti, durum = "var"|"iniyor"|"yok", bekleyen = {fn} }
local inen = {}                     -- [crc] = { yol, uzanti, boyut, n, parcalar, gelen }

local function Dosya(crc, uzanti) return KLASOR .. "/" .. crc .. "." .. (uzanti or "mp3") end

local function Bildir(s, dosya)
     local liste = s.bekleyen or {}
     s.bekleyen = {}
     for _, fn in ipairs(liste) do
          local ok, hata = pcall(fn, dosya)
          if not ok then ErrorNoHalt("[Sardon Görev] ses: " .. tostring(hata) .. "\n") end
     end
end

-- Dosya hazır olunca cb("data/...") ; yoksa cb(nil)
function G.SesHazir(yol, crc, cb, oncelik)
     local s = G.SesDurum[yol]
     if not s or (crc and crc ~= "" and s.crc ~= crc) then
          s = { crc = crc, durum = "yok_bilinmiyor", bekleyen = {} }
          G.SesDurum[yol] = s
     end

     if s.durum == "var" and s.dosya and file.Exists(s.dosya, "DATA") then
          if cb then cb(s.dosya) end
          return true
     end

     -- uzantı bilinmiyorsa üçünü de dene
     if s.crc then
          for _, uz in ipairs({ s.uzanti or string.GetExtensionFromFilename(yol) or "mp3", "mp3", "ogg", "wav" }) do
               local d = Dosya(s.crc, uz)
               if file.Exists(d, "DATA") then
                    s.durum, s.dosya, s.uzanti = "var", d, uz
                    if cb then cb(d) end
                    return true
               end
          end
     end

     -- sunucuda yok dendiyse bir süre yeniden sorma
     if s.durum == "yok" and RealTime() - (s.yokZaman or 0) < 30 then
          if cb then cb(nil) end
          return false
     end

     if cb then table.insert(s.bekleyen, cb) end
     if s.durum ~= "iniyor" or oncelik then
          s.durum = "iniyor"
          s.istek = RealTime()
          G.Iste(G.ISTEK.SES, function()
               net.WriteString(yol)
               net.WriteBool(oncelik and true or false)
          end)
     end
     return false
end

net.Receive("SardonGorev.Ses", function()
     local tur = net.ReadString()

     if tur == "liste" then
          for _, x in ipairs(G.OkuTablo()) do
               local s = G.SesDurum[x.yol]
               if not s or s.crc ~= x.crc then
                    s = { crc = x.crc, uzanti = x.uzanti, durum = "bilinmiyor", bekleyen = {} }
                    G.SesDurum[x.yol] = s
               end
               s.uzanti = x.uzanti
               if file.Exists(Dosya(x.crc, x.uzanti), "DATA") then
                    s.durum, s.dosya = "var", Dosya(x.crc, x.uzanti)
               elseif s.durum ~= "iniyor" then
                    G.SesHazir(x.yol, x.crc)
               end
          end
     elseif tur == "bas" then
          local yol, crc, uzanti, boyut, n = net.ReadString(), net.ReadString(), net.ReadString(), net.ReadUInt(32), net.ReadUInt(16)
          local s = G.SesDurum[yol] or { bekleyen = {} }
          s.crc, s.uzanti, s.durum = crc, uzanti, "iniyor"
          G.SesDurum[yol] = s
          inen[crc] = { yol = yol, uzanti = uzanti, boyut = boyut, n = n, parcalar = {}, gelen = 0 }
     elseif tur == "parca" then
          local crc, i = net.ReadString(), net.ReadUInt(16)
          local uz = net.ReadUInt(32)
          local veri = net.ReadData(uz)
          local x = inen[crc]
          if not x or x.parcalar[i] then return end
          x.parcalar[i] = veri
          x.gelen = x.gelen + 1
          if x.gelen >= x.n then
               inen[crc] = nil
               local tam = table.concat(x.parcalar)
               local s = G.SesDurum[x.yol] or { bekleyen = {} }
               G.SesDurum[x.yol] = s
               if #tam ~= x.boyut then
                    s.durum = "yok"
                    Bildir(s, nil)
                    return
               end
               local d = Dosya(crc, x.uzanti)
               file.Write(d, tam)
               s.durum, s.dosya, s.crc, s.uzanti = "var", d, crc, x.uzanti
               Bildir(s, d)
          end
     elseif tur == "yok" then
          local yol = net.ReadString()
          local s = G.SesDurum[yol]
          if s then
               s.durum = "yok"
               s.yokZaman = RealTime()
               Bildir(s, nil)
          end
     end
end)

/*
*   Çalma
*   sec: { aktor = c (3B, ağızdan), pos = Vector (3B), seviye, gec = izin verilen gecikme (sn) }
*/
function G.SesCal(yol, crc, sec)
     sec = sec or {}
     local istendi = RealTime()
     local c = sec.aktor
     local konus = c and c.konus

     G.SesHazir(yol, crc, function(dosya)
          if not dosya then return end
          -- söz bitmişse ya da başkası başlamışsa geç kalmış sesi çalma
          local gec = sec.gec or 1.2
          if c and (c.konus ~= konus or not G.Aktorler[c.no]) then return end
          if RealTime() - istendi > gec and not sec.zorla then return end

          local uc = c or sec.pos
          sound.PlayFile("data/" .. dosya, uc and "3d noplay" or "noplay", function(kanal)
               if not IsValid(kanal) then return end
               if c then
                    if c.konus ~= konus or not G.Aktorler[c.no] then kanal:Stop() return end
                    if IsValid(c.kanal) then c.kanal:Stop() end
                    c.kanal = kanal
                    kanal:SetPos((c.cizPos or c.pos) + Vector(0, 0, 60))
               elseif sec.pos then
                    kanal:SetPos(sec.pos)
               end
               if uc then kanal:Set3DFadeDistance(180, 1600) end
               kanal:SetVolume(sec.seviye or 1)
               kanal:Play()
               if sec.cb then sec.cb(kanal) end
          end)
     end, sec.oncelik or (c ~= nil and sec.yakin))
end

-- Editör önizlemesi (2B)
local onizleme
function G.SesOnizle(yol)
     if IsValid(onizleme) then onizleme:Stop() end
     G.SesHazir(yol, nil, function(dosya)
          if not dosya then
               notification.AddLegacy("Ses dosyası sunucuda yok: " .. yol, NOTIFY_ERROR, 4)
               return
          end
          sound.PlayFile("data/" .. dosya, "noplay", function(k)
               if IsValid(k) then
                    if IsValid(onizleme) then onizleme:Stop() end
                    onizleme = k
                    k:Play()
               end
          end)
     end, true)
end

function G.SesOnizleDur()
     if IsValid(onizleme) then onizleme:Stop() end
     onizleme = nil
end

-- Eski önbellek dosyalarını temizle
timer.Simple(20, function()
     local sinir = os.time() - 30 * 86400
     for _, d in ipairs(file.Find(KLASOR .. "/*", "DATA") or {}) do
          local t = file.Time(KLASOR .. "/" .. d, "DATA")
          if t and t > 0 and t < sinir then file.Delete(KLASOR .. "/" .. d) end
     end
end)
