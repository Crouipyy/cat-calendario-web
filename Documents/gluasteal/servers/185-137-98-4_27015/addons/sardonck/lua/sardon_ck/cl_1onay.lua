-- "addons\\sardonck\\lua\\sardon_ck\\cl_1onay.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon CK :: istemci onay penceresi. Katile ve kurbana aynı pencere gelir,
-- metin role göre değişir. Görsel dil Shine Admin / asa menüsü (Nocturne);
-- Nocturne yoksa Derma_Query'ye düşer.

local acik = {} -- id → pencere

local function Gonder(id, evet)
     net.Start("SardonCK.Cevap")
          net.WriteUInt(id, 32)
          net.WriteBool(evet)
     net.SendToServer()
end

local function Metin(rol, karsi, kurbanAd, buyu)
     if (rol == 1) then
          return "CK onayı",
               karsi .. " adlı karakteri " .. buyu .. " ile öldürdün. Bu bir CK büyüsüdür: iki taraf da onaylarsa " ..
               kurbanAd .. " kalıcı olarak ölür ve bir daha oynanamaz. Taraflardan biri onaylamazsa ya da süre dolarsa karar yetkililere gider."
     end

     return "Karakterin ölüyor",
          karsi .. " seni " .. buyu .. " ile öldürdü. Onaylarsan " .. kurbanAd .. " kalıcı olarak ölür (CK) ve bir daha oynanamaz. " ..
          "Onaylamazsan karar yetkililere gider; yetkili onaylayana kadar karakterin yaşamaya devam eder."
end

local function Pencere(id, rol, karsi, kurbanAd, buyu, sure)
     if (IsValid(acik[id])) then acik[id]:Remove() end

     local baslik, govde = Metin(rol, karsi, kurbanAd, buyu)
     local bitis = RealTime() + sure

     local N = HpwRewrite and HpwRewrite.Nocturne
     if (!N or !N.Button or !N.Wrap) then
          acik[id] = Derma_Query(govde, baslik, "Onaylıyorum", function() Gonder(id, true) end, "Onaylamıyorum", function() Gonder(id, false) end)
          return
     end

     N:Prepare()
     local u = N.u

     local w = u(560)
     local pad = u(32)
     local satirlar = N.Wrap(govde, "body", w - pad * 2)
     local h = pad + u(18) + u(34) + #satirlar * u(21) + u(22) + u(6) + u(26) + u(38) + pad

     local f = vgui.Create("DFrame")
     f:SetSize(w, h)
     f:Center()
     f:SetTitle("")
     f:ShowCloseButton(false)
     f:SetDraggable(false)
     f:MakePopup()
     f:SetKeyboardInputEnabled(false) -- oyuncu konuşabilsin / yazabilsin
     f:SetDrawOnTop(true)
     f.Start = RealTime()

     f.Paint = function(s, pw, ph)
          N.Box(0, 0, pw, ph, N.Clr.modalBg or N.Clr.bg)
          N.Outline(0, 0, pw, ph, N.Clr.modalLine or N.Clr.goldSoft, 1)
          N.Corners(0, 0, pw, ph, u(22), N.Clr.goldSoft)

          local cy = pad
          local bx = pad

          if (N.Icon("warning", bx, cy, u(14), N.Clr.bad)) then bx = bx + u(22) end
          N.TextSpaced(rol == 1 and "CK BÜYÜSÜ" or "KALICI ÖLÜM", "micro", bx, cy + u(2), N.Clr.bad, u(2))

          cy = cy + u(18)
          N.Text(N.Clip(baslik, "heading", pw - pad * 2), "heading", pad, cy)
          cy = cy + u(34)

          for i = 1, #satirlar do
               N.Text(satirlar[i], "body", pad, cy + (i - 1) * u(21), N.Clr.infoText)
          end

          cy = cy + #satirlar * u(21) + u(22)

          -- kalan süre çubuğu
          local kalan = math.max(bitis - RealTime(), 0)
          local oran = kalan / sure
          N.Box(pad, cy, pw - pad * 2, u(3), N.Clr.progTrack or N.Clr.lineSoft)
          N.Box(pad, cy, (pw - pad * 2) * oran, u(3), oran < 0.25 and N.Clr.bad or N.Clr.gold)
          N.Text(math.ceil(kalan) .. " sn içinde cevap vermezsen karar yetkililere gider.", "tiny", pad, cy + u(10), N.Clr.faint)
     end

     f.Think = function(s)
          if (RealTime() >= bitis) then s:Remove() end
     end

     local bw, bh = u(170), u(38)

     N.Button(f, w - pad - bw * 2 - u(12), h - pad - bh, bw, bh, "Onaylamıyorum", function()
          f:Remove()
          Gonder(id, false)
     end, "ghost")

     local evet = N.Button(f, w - pad - bw, h - pad - bh, bw, bh, "Onaylıyorum", function()
          f:Remove()
          Gonder(id, true)
     end, "danger")
     evet.NoCaps = true

     acik[id] = f
end

/*
*   kurbanın sineması: beden yere yığılır, kamera bedenin gözüne geçer (first
*   person), ekran kararır; yeniden doğunca karanlık açılır ve onay penceresi gelir.
*   Anka Eşiği ölüm ekranı bu ölümde açılmaz.
*/

local SINEMA = {
     goz = 1.8,      -- yalnız gözden bakış
     karar = 1.5,    -- kararma süresi
     enAz = 4.0,     -- karanlık en erken bu saniyede açılabilir
     enCok = 9.0,    -- yeniden doğma gecikse de karanlık bu saniyede açılır
     acil = 1.2      -- karanlığın açılma süresi
}

local sinema -- {basla, acilBasla, bitince}

local function Ragdoll()
     local ply = LocalPlayer()
     local rag = ply:GetRagdollEntity()
     if (IsValid(rag)) then return rag end

     rag = Entity(ply:GetLocalVar("ragdoll", 0))
     if (IsValid(rag) and rag:IsRagdoll()) then return rag end
end

local function SinemaBitir()
     hook.Remove("CalcView", "SardonCK.Sinema")
     hook.Remove("DrawOverlay", "SardonCK.Sinema")
     hook.Remove("Think", "SardonCK.Sinema")
     hook.Remove("HUDShouldDraw", "SardonCK.Sinema")

     local s = sinema
     sinema = nil
     if (s and s.bitince) then s.bitince() end
end

local function SinemaBaslat(bitince)
     if (sinema) then SinemaBitir() end

     sinema = {basla = RealTime(), bitince = bitince}

     if (IsValid(ix.gui.deathScreen)) then ix.gui.deathScreen:Remove() end

     hook.Add("Think", "SardonCK.Sinema", function()
          local s = sinema
          if (!s) then return end

          local t = RealTime() - s.basla

          -- ölüm ekranı sonradan açılırsa kapat
          if (IsValid(ix.gui.deathScreen)) then ix.gui.deathScreen:Remove() end

          if (!s.acilBasla and t >= SINEMA.enAz and (LocalPlayer():Alive() or t >= SINEMA.enCok)) then
               s.acilBasla = RealTime()
          end

          if (s.acilBasla and RealTime() - s.acilBasla >= SINEMA.acil) then
               SinemaBitir()
          end
     end)

     -- ölüyken bedenin gözünden bak; kafa kemiği gizlenir ki içi görünmesin
     hook.Add("CalcView", "SardonCK.Sinema", function(ply, pos, ang, fov)
          if (!sinema or ply:Alive()) then return end

          local rag = Ragdoll()
          if (!rag) then return end

          if (!rag.SardonCKKafa) then
               local kemik = rag:LookupBone("ValveBiped.Bip01_Head1")
               if (kemik) then rag:ManipulateBoneScale(kemik, vector_origin) end
               rag.SardonCKKafa = true
          end

          local ek = rag:LookupAttachment("eyes")
          local veri = ek and ek > 0 and rag:GetAttachment(ek)
          if (!veri) then return end

          return {origin = veri.Pos, angles = veri.Ang, fov = fov, znear = 1, drawviewer = false}
     end)

     hook.Add("HUDShouldDraw", "SardonCK.Sinema", function(ad)
          if (sinema and ad != "CHudGMod") then return false end
     end)

     -- karartma VGUI'nin de üstünde
     hook.Add("DrawOverlay", "SardonCK.Sinema", function()
          local s = sinema
          if (!s) then return end

          local t = RealTime() - s.basla
          local a = math.Clamp((t - SINEMA.goz) / SINEMA.karar, 0, 1)

          if (s.acilBasla) then
               a = a * (1 - math.Clamp((RealTime() - s.acilBasla) / SINEMA.acil, 0, 1))
          end

          if (a <= 0) then return end

          surface.SetDrawColor(0, 0, 0, 255 * a)
          surface.DrawRect(0, 0, ScrW(), ScrH())
     end)
end

net.Receive("SardonCK.Sor", function()
     local id = net.ReadUInt(32)
     local rol = net.ReadUInt(2)

     if (rol == 0) then
          if (IsValid(acik[id])) then acik[id]:Remove() end
          acik[id] = nil
          return
     end

     local karsi = net.ReadString()
     local kurbanAd = net.ReadString()
     local buyu = net.ReadString()
     local sure = net.ReadFloat()

     -- kurban az önce öldüyse önce sinema, pencere karanlık açılınca
     if (rol == 2 and !LocalPlayer():Alive()) then
          local gelis = RealTime()

          SinemaBaslat(function()
               local kalan = sure - (RealTime() - gelis)
               if (kalan > 1) then Pencere(id, rol, karsi, kurbanAd, buyu, kalan) end
          end)

          return
     end

     -- ölüm ekranının üstüne gelsin diye bir kare sonra
     timer.Simple(0, function() Pencere(id, rol, karsi, kurbanAd, buyu, sure) end)
end)
