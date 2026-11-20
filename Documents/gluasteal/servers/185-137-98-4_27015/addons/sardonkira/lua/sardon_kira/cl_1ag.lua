-- "addons\\sardonkira\\lua\\sardon_kira\\cl_1ag.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kira v2 :: istemci ağı ve veri. Sunucu kendi kiralarını LISTE ile yollar; karakter modeli listesi
-- (GetCharacterModels) buradan beslenir: yalnız bu karaktere bağlı + etkin kiralar.
local K = SardonKira
local OP = K.OP

K.Benim = K.Benim or { liste = {}, sc = nil, simdi = os.time(), site = K.SITE_URL }
K.Yonetim = K.Yonetim or { liste = {}, denemeler = {} }

function K.Iste(op, t)
     net.Start("SardonKira")
          net.WriteUInt(op, 5)
          K.Yaz(t or {})
     net.SendToServer()
end

function K.Bildirim(metin)
     chat.AddText(Color(208, 180, 123), "[Kira] ", Color(225, 228, 232), tostring(metin))
     if ix and ix.util and ix.util.Notify then ix.util.Notify(tostring(metin)) end
end

local saatFarki = 0   -- sunucu saati - istemci saati
function K.Simdi() return os.time() + saatFarki end

net.Receive("SardonKira", function()
     local op = net.ReadUInt(5)
     if op == OP.DENE_PARCA then
          if K.DenemeParca then K.DenemeParca() end
          return
     end
     local t = K.Oku()
     if op == OP.LISTE then
          K.Benim = t
          K.Benim.liste = t.liste or {}
          if t.simdi then saatFarki = t.simdi - os.time() end
          hook.Run("SardonKiraListe")
     elseif op == OP.MENU then
          if K.MenuAc then K.MenuAc() end
     elseif op == OP.BILDIR then
          K.Bildirim(t.metin or "")
     elseif op == OP.ANLIK then
          if K.AnlikIndir then K.AnlikIndir(t.liste) end
     elseif op == OP.YONETIM then
          K.Yonetim = t
          K.Yonetim.liste = t.liste or {}
          K.Yonetim.denemeler = t.denemeler or {}
          if t.simdi then saatFarki = t.simdi - os.time() end
          hook.Run("SardonKiraYonetim")
     end
end)

hook.Add("GetCharacterModels", "GetKiraModels", function(char)
     if char:GetPlayer() ~= LocalPlayer() then return end
     local out = {}
     for _, r in ipairs(K.Benim.liste or {}) do
          if r.durum == K.D.ETKIN and r.karakterId == char:GetID() and (tonumber(r.bitis) or 0) > K.Simdi() then
               out[#out + 1] = r.modelYolu
          end
     end
     return out
end)

hook.Add("InitPostEntity", "SardonKira.Iste", function()
     timer.Simple(3, function() K.Iste(OP.ISTE) end)
end)

-- ------------------------------------------------------------------ anlık yayın (restartsız)
-- Sunucu bu oturumda restartsız bağlanan kiraların Workshop yuvasını yollar; istemci Steam'den indirip bağlar
-- (simple-mount ile aynı yöntem: steamworks.DownloadUGC + game.MountGMA). İndirme Steam sürecinde, FPS'e etkisi yok.
K.AnlikDurum = K.AnlikDurum or {}      -- [yuva] = "iniyor" | "bagli"
K.AnlikDeneme = K.AnlikDeneme or {}
function K.AnlikIndir(liste)
     for _, a in ipairs(liste or {}) do
          local oge = a.oge
          if isstring(oge) and oge:match("^%d+$") and K.KiraModeliMi(a.modelYolu) and not file.Exists(a.modelYolu, "GAME")
               and not K.AnlikDurum[oge] and (K.AnlikDeneme[oge] or 0) < 5 then
               K.AnlikDurum[oge] = "iniyor"
               K.AnlikDeneme[oge] = (K.AnlikDeneme[oge] or 0) + 1
               steamworks.DownloadUGC(oge, function(yol)
                    if yol and game.MountGMA(yol) then
                         K.AnlikDurum[oge] = "bagli"
                         K.ModelVarOnb = {}
                         -- yeni bağlanan modeli giyenleri tazele (taze mount'ta görünürlük kaydı kalabiliyor)
                         timer.Simple(0.5, function()
                              local alt = string.lower(a.modelYolu)
                              for _, p in player.Iterator() do
                                   if string.lower(p:GetModel() or "") == alt then p:SetNoDraw(true) p:SetNoDraw(false) end
                              end
                         end)
                    else
                         K.AnlikDurum[oge] = nil
                         timer.Simple(30, function() K.AnlikIndir({ a }) end)
                    end
               end)
          end
     end
end
