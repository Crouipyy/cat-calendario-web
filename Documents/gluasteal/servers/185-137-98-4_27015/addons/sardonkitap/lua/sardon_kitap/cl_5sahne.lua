-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_5sahne.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: kitapçı — istemci (2026-11-03, ikinci sürüm)
--   Haritanın gerçek rafları (SK.Harita.raflar, kutu: pos/yaw/mn/mx): bakış ışını rafın kutusuna düşerse
--   ekranda "E · raf adı"; E → sunucu (SardonKitap.RafSec). Kitap tezgâhta bekliyorsa tezgâha bakınca
--   "E · Kitapları al". Accio: kitap raftan kitapçının sağ eline uçar, bir an elde kalır, tezgâhtaki yerine
--   iner (yakındakiler görür); tezgâhtaki yığın yalnız sahibine görünür. Karşılamada sağ üstte kitap listesi
--   (her kitabın rafıyla). Kalıcı dükkânda rafa E → fiyat onayı penceresi.

-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_48 = Vector(0, 0, 48)
local SK = SardonKitap
local R = SK.R

-- ilk sürümün kancaları (canlı yenilemede adları farklı olduğu için kendiliğinden silinmiyordu;
-- yeni SK.Sahne yapısında olmayan alanlara bakıp her karede hata veriyorlardı)
for _, k in ipairs({"HUDPaint", "Think", "PostDrawTranslucentRenderables", "KeyPress"}) do
     hook.Remove(k, "SardonKitap.Sahne")
end
if SK.Sahne and not SK.Sahne.liste then SK.Sahne = nil end

SK.Sahne = SK.Sahne or nil
SK.TezgahKitap = SK.TezgahKitap or {}
SK.TezgahModeller = SK.TezgahModeller or {}
SK.Ucanlar = SK.Ucanlar or {}

local ELDE = 0.8      -- kitap kitapçının elinde kalma süresi
local UCUS = 0.9
local INIS = 0.45

local function RafMerkez(r) return (LocalToWorld((r.mn + r.mx) * 0.5, Angle(), r.pos, Angle(0, r.yaw, 0))) end
SK.RafMerkezCl = RafMerkez

function SK.KitapRafiCl(kitapId)
     local k = SK.Kitap[kitapId]
     for _, r in ipairs(SK.Harita and SK.Harita.raflar or {}) do
          if r.kitap == kitapId or (k and k.cilt and r.kitap == "cilt") then return r end
     end
end

local function TezgahYuva(i)
     local z = SK.Harita and SK.Harita.tezgah
     if not z then return nil end
     local sira = (i - 1) % 8
     local kat = math.floor((i - 1) / 8)
     return (LocalToWorld(Vector(z.mn.x + 16, -30 + sira * 8.5, z.mx.z + 1 + kat * 3), Angle(), z.pos, Angle(0, z.yaw, 0)))
end

/*
*   tezgâhtaki yığın (yalnız sahibine)
*/
local function TezgahKur()
     for _, e in ipairs(SK.TezgahModeller) do if IsValid(e) then e:Remove() end end
     SK.TezgahModeller = {}
     local z = SK.Harita and SK.Harita.tezgah
     for i, k in ipairs(SK.TezgahKitap) do
          local t = SK.Kitap[k]
          local pos = TezgahYuva(i)
          if t and pos then
               local e = ClientsideModel(t.model, RENDERGROUP_OPAQUE)
               if IsValid(e) then
                    e:SetPos(pos)
                    e:SetAngles(Angle(0, (z and z.yaw or 0) + 90 + (i % 2) * 7, 0))
                    SK.TezgahModeller[#SK.TezgahModeller + 1] = e
               end
          end
     end
end

/*
*   ağ
*/
net.Receive("SardonKitap.Sahne", function()
     local op = net.ReadUInt(2)
     if op == 1 then
          local S = {liste = {}, durum = {}}
          for i = 1, net.ReadUInt(5) do
               local k = net.ReadString()
               S.liste[i] = k
               S.durum[k] = net.ReadUInt(2)
          end
          SK.Sahne = S
          SK.Kart("Kitap listen", "Her kitap kendi rafında. Rafa bak, E'ye bas; kitapçı Accio ile indirip tezgâha koyar. Bitince tezgâha E.", "bilgi")
     elseif op == 2 then
          local k, d = net.ReadString(), net.ReadUInt(2)
          if SK.Sahne then SK.Sahne.durum[k] = d end
     elseif op == 3 then
          SK.Sahne = nil
          surface.PlaySound("buttons/button9.wav")
     end
end)

net.Receive("SardonKitap.Tezgah", function()
     local t = {}
     for i = 1, net.ReadUInt(5) do t[i] = net.ReadString() end
     SK.TezgahKitap = t
     TezgahKur()
end)

net.Receive("SardonKitap.Accio", function()
     local no, k, bas, yuva = net.ReadUInt(16), net.ReadString(), net.ReadVector(), net.ReadVector()
     local t = SK.Kitap[k]
     if not t or bas:DistToSqr(EyePos()) > 2000 * 2000 then return end
     -- HL kitap modeli (SardonKitapAnim): uçarken kapaklarını kanat gibi açıp süzülür
     local KA = SardonKitapAnim
     local e
     if KA and KA.KitapYap and t.hl and KA.Model(t.hl) == t.model then
          KA.Hazirla(t.hl)
          e = KA.KitapYap(t.hl)
          if IsValid(e) then e:SetNoDraw(false) end
     end
     if not IsValid(e) then e = ClientsideModel(t.model, RENDERGROUP_OPAQUE) end
     if not IsValid(e) then return end
     e:SetPos(bas)
     SK.Ucanlar[#SK.Ucanlar + 1] = {e = e, bas = bas, yuva = yuva, no = no, t0 = CurTime(), renk = t.harf or R.altinA, faz = math.Rand(0, 1)}
     sound.Play("weapons/physcannon/superphys_small_zap1.wav", bas, 60, 140, 0.5)
end)

/*
*   uçuş: raf → kitapçının eli → tezgâh
*/
local function El(no)
     local G = SardonGorev
     local c = G and G.Aktorler and G.Aktorler[no]
     local ent = c and c.ent
     if not IsValid(ent) then return nil end
     local b = ent:LookupBone("ValveBiped.Bip01_R_Hand")
     local p = b and ent:GetBonePosition(b)
     if p and p ~= ent:GetPos() then return p end
     return ent:GetPos() + OPT_V_0_0_48
end

-- uçuş yolu (raf → el): yumuşak geçiş + yay
local function UcusYeri(u, el, f)
     local e = f * f * (3 - 2 * f)
     return LerpVector(e, u.bas, el) + Vector(0, 0, math.sin(e * math.pi) * 22)
end

-- HL kitabını Binding_Center çerçevesiyle yerleştir (sh_kitap.lua); olmazsa düz yer/açı
local function KitapYer(u, islev, cyc, pos, ang)
     local KA = SardonKitapAnim
     if KA and u.e.skaId then
          KA.Poz(u.e, islev, cyc)
          if KA.Yerlestir(u.e, pos, ang, 1) then return end
     end
     u.e:SetPos(pos)
     u.e:SetAngles(ang)
end

hook.Add("Think", "SardonKitap.Ucus", function()
     if #SK.Ucanlar == 0 then return end
     local simdi = CurTime()
     for i = #SK.Ucanlar, 1, -1 do
          local u = SK.Ucanlar[i]
          local t = simdi - u.t0
          local el = (u.no > 0 and El(u.no)) or u.yuva
          if not IsValid(u.e) or t > UCUS + ELDE + INIS + 0.1 then
               if IsValid(u.e) then u.e:Remove() end
               table.remove(SK.Ucanlar, i)
          elseif t <= UCUS and not u.e.skaId then
               -- duran kitap (Locksley ciltleri): dönerek uçar
               u.e:SetPos(UcusYeri(u, el, t / UCUS))
               u.e:SetAngles(Angle(math.sin(simdi * 7) * 15, simdi * 260 % 360, math.cos(simdi * 6) * 12))
          elseif t <= UCUS then
               local f = t / UCUS
               local p = UcusYeri(u, el, f)
               local ileri = UcusYeri(u, el, math.min(f + 0.03, 1)) - p
               if ileri:LengthSqr() < 0.01 then ileri = el - u.bas end
               ileri:Normalize()
               -- başı önde (-Z), sayfalar aşağı (+Y), kapaklar iki yana (X = sol); hafif yatış
               local X = Vector(0, 0, 1):Cross(ileri)
               if X:LengthSqr() < 0.01 then X = Vector(0, 1, 0) end
               X:Normalize()
               local Y = Vector(0, 0, -1)
               Y = Y - ileri * Y:Dot(ileri)
               Y:Normalize()
               local yatis = math.rad(math.sin(simdi * 6 + u.faz * 6) * 14)
               X, Y = X * math.cos(yatis) + Y * math.sin(yatis), Y * math.cos(yatis) - X * math.sin(yatis)
               local aile = u.e.skaAile
               local islev = aile == "rehber" and "cirp" or "suzul"
               local hiz = aile == "rehber" and 1.4 or 0.7
               KitapYer(u, islev, (simdi * hiz + u.faz) % 1, p, X:AngleEx(X:Cross(Y)))
          elseif t <= UCUS + ELDE then
               -- kitapçının elinde dik, kapalı (başı yukarı)
               KitapYer(u, "kapali", 0, el, u.e.skaId and Angle(0, simdi * 40 % 360, 180) or Angle(0, simdi * 40 % 360, 0))
               u.elPos = el
          else
               local f = math.Clamp((t - UCUS - ELDE) / INIS, 0, 1)
               u.e:SetPos(LerpVector(f, u.elPos or el, u.yuva) + Vector(0, 0, math.sin(f * math.pi) * 8))
               if u.e.skaId then
                    -- tezgâha düz iner (bağlama pozu kapağı yukarı yatık)
                    SardonKitapAnim.Poz(u.e, "kapali", 0)
                    u.e:SetAngles(LerpAngle(f, u.e:GetAngles(), Angle(0, u.e:GetAngles().y, 0)))
               end
          end
     end
end)

hook.Add("PostDrawTranslucentRenderables", "SardonKitap.Ucus", function(_, gok)
     if gok or #SK.Ucanlar == 0 then return end
     render.SetMaterial(SK.M.isik)
     for _, u in ipairs(SK.Ucanlar) do
          if IsValid(u.e) and CurTime() - u.t0 <= UCUS then
               render.DrawSprite(u.e:GetPos(), 22, 22, Color(u.renk.r, u.renk.g, u.renk.b, 160))
          end
     end
end)

/*
*   bakılan raf / tezgâh
*/
local hedef, hedefTur
local sonTara = 0

local function Tara()
     hedef, hedefTur = nil, nil
     local ply = LocalPlayer()
     if not IsValid(ply) or not ply:Alive() then return end
     local raflar = SK.Harita and SK.Harita.raflar or {}
     local z = SK.Harita and SK.Harita.tezgah
     if #raflar == 0 and not z then return end
     local goz, yon = ply:EyePos(), ply:GetAimVector() * 170
     local enD
     if z and #SK.TezgahKitap > 0 and goz:DistToSqr(z.pos) < 400 * 400 then
          local hit = util.IntersectRayWithOBB(goz, yon, z.pos, Angle(0, z.yaw, 0), z.mn, z.mx)
          if hit then hedef, hedefTur, enD = z, "tezgah", goz:DistToSqr(hit) end
     end
     for _, r in ipairs(raflar) do
          if goz:DistToSqr(r.pos) < 400 * 400 then
               local hit = util.IntersectRayWithOBB(goz, yon, r.pos, Angle(0, r.yaw, 0), r.mn, r.mx)
               if hit then
                    local d = goz:DistToSqr(hit)
                    if not enD or d < enD then hedef, hedefTur, enD = r, "raf", d end
               end
          end
     end
end

hook.Add("Think", "SardonKitap.Raf", function()
     if CurTime() < sonTara then return end
     sonTara = CurTime() + 0.1
     Tara()
end)

local sonE = 0
hook.Add("KeyPress", "SardonKitap.Raf", function(ply, tus)
     if tus ~= IN_USE or ply ~= LocalPlayer() or not hedef or CurTime() < sonE then return end
     if SardonGorev and SardonGorev.Bakilan then return end -- bir aktöre bakıyor: görev konuşması
     if vgui.CursorVisible() then return end
     sonE = CurTime() + 0.4
     if hedefTur == "tezgah" then
          net.Start("SardonKitap.TezgahAl") net.SendToServer()
     else
          net.Start("SardonKitap.RafSec") net.WriteString(hedef.id) net.SendToServer()
     end
end)

/*
*   ekran: istem + karşılama listesi
*/
hook.Add("HUDPaint", "SardonKitap.Raf", function()
     if hedef and not (SardonGorev and SardonGorev.Bakilan) then
          SK.Fontlar()
          local metin = hedefTur == "tezgah" and ("E · Kitapları al (" .. #SK.TezgahKitap .. ")") or ("E · " .. (hedef.ad or "Raf"))
          local tw = SK.Olc(metin, "hud") + SK.S(26)
          local x, y = ScrW() / 2 - tw / 2, ScrH() * 0.62
          SK.Kutu(x, y, tw, SK.S(32), R.hud)
          surface.SetDrawColor(R.hudCizgi) surface.DrawOutlinedRect(x, y, tw, SK.S(32), 1)
          SK.Yazi(metin, "hud", ScrW() / 2, y + SK.S(16), R.hudYazi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     local S = SK.Sahne
     if not S then return end
     SK.Fontlar()
     local w = SK.S(360)
     local x, y = ScrW() - w - SK.S(24), SK.S(160)
     local rh = SK.S(36)
     local h = SK.S(40) + #S.liste * rh
     SK.Kutu(x, y, w, h, R.hud)
     surface.SetDrawColor(R.hudCizgi) surface.DrawOutlinedRect(x, y, w, h, 1)
     local alinan, tezgahta = 0, 0
     for _, k in ipairs(S.liste) do
          if S.durum[k] == 2 then alinan = alinan + 1 elseif S.durum[k] == 1 then tezgahta = tezgahta + 1 end
     end
     SK.Yazi("KİTAP LİSTESİ", "ust", x + SK.S(12), y + SK.S(10), R.altinA)
     SK.Yazi(alinan .. " / " .. #S.liste .. (tezgahta > 0 and (" · tezgâhta " .. tezgahta) or ""), "ust", x + w - SK.S(12), y + SK.S(10), R.hudSoluk, TEXT_ALIGN_RIGHT)
     for i, k in ipairs(S.liste) do
          local t = SK.Kitap[k]
          local d = S.durum[k] or 0
          local ry = y + SK.S(28) + (i - 1) * rh
          local kutu = d == 2 and R.iyi or (d == 1 and R.altin or Color(255, 255, 255, 30))
          SK.Kutu(x + SK.S(12), ry + SK.S(5), SK.S(10), SK.S(10), kutu)
          SK.Yazi(t and t.ad or k, "hudK", x + SK.S(30), ry, d == 2 and R.hudSoluk or R.hudYazi)
          local raf = SK.KitapRafiCl(k)
          local alt = d == 2 and "kayışında" or (d == 1 and "tezgâhta" or (raf and raf.ad or ""))
          SK.Yazi(alt, "ust", x + SK.S(30), ry + SK.S(17), d == 1 and R.altinA or R.hudSoluk)
     end
end)

/*
*   kalıcı dükkân: fiyat onayı
*/
net.Receive("SardonKitap.RafFiyat", function()
     local rafId, para = net.ReadString(), net.ReadUInt(32)
     local secenek = {}
     for i = 1, net.ReadUInt(4) do secenek[i] = {id = net.ReadString(), fiyat = net.ReadUInt(10), var = net.ReadBool()} end
     local raf
     for _, r in ipairs(SK.Harita.raflar or {}) do if r.id == rafId then raf = r end end
     SK.Fontlar()
     if IsValid(SK.FiyatPanel) then SK.FiyatPanel:Remove() end

     local f = vgui.Create("EditablePanel")
     local W = SK.S(460)
     f:SetSize(W, SK.S(96) + #secenek * SK.S(52))
     f:Center()
     f:MakePopup()
     f.Paint = function(s, w, h)
          SK.Kutu(0, 0, w, h, R.hud)
          surface.SetDrawColor(R.hudCizgi) surface.DrawOutlinedRect(0, 0, w, h, 1)
          SK.Yazi(SK.Buyuk(raf and raf.ad or "Raf"), "ust", SK.S(16), SK.S(14), R.altinA)
          SK.Yazi("Hangisini indireyim?", "hud", SK.S(16), SK.S(32), R.hudYazi)
          SK.Yazi(para .. " Galleon", "hudK", w - SK.S(16), SK.S(34), R.hudSoluk, TEXT_ALIGN_RIGHT)
     end
     f.OnKeyCodePressed = function(s, k) if k == KEY_ESCAPE or k == KEY_E then s:Remove() end end
     for i, x in ipairs(secenek) do
          local t = SK.Kitap[x.id]
          local b = vgui.Create("DButton", f)
          b:SetPos(SK.S(16), SK.S(64) + (i - 1) * SK.S(52))
          b:SetSize(W - SK.S(32), SK.S(46))
          b:SetText("")
          local kapali = x.var or para < x.fiyat
          b:SetEnabled(not kapali)
          b.Paint = function(s, w, h)
               SK.Kutu(0, 0, w, h, (s:IsHovered() and not kapali) and Color(196, 156, 74, 50) or Color(255, 255, 255, 8))
               if t then SK.Kutu(0, 0, SK.S(4), h, t.spine) end
               SK.Yazi(t and t.ad or x.id, "hudK", SK.S(14), SK.S(6), kapali and R.hudSoluk or R.hudYazi)
               SK.Yazi(t and t.yazar or "", "ust", SK.S(14), SK.S(26), R.hudSoluk)
               local sag = x.var and "Sende var" or (para < x.fiyat and ("Paran yetmiyor · " .. x.fiyat .. " G") or ("Al · " .. x.fiyat .. " G"))
               SK.Yazi(sag, "hud", w - SK.S(14), h / 2, kapali and R.hudSoluk or R.altinA, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end
          b.DoClick = function()
               net.Start("SardonKitap.RafAl")
               net.WriteString(rafId)
               net.WriteString(x.id)
               net.SendToServer()
               surface.PlaySound("buttons/button14.wav")
               f:Remove()
          end
     end
     SK.FiyatPanel = f
end)
