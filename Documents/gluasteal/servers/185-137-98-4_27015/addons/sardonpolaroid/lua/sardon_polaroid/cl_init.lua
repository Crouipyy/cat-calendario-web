-- "addons\\sardonpolaroid\\lua\\sardon_polaroid\\cl_init.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_8 = Vector(0, 0, 8)
local OPT_V_0_0_4 = Vector(0, 0, 4)
XeninUI:CreateFont("SardonPolaroid.Countdown", ScreenScale(62))
SardonPolaroidPanel = SardonPolaroidPanel or NULL
SardonPolaroidQuery = SardonPolaroidQuery or NULL

local function sendMode(mode)
     net.Start("SardonPolaroid.ChooseMode")
     net.WriteUInt(mode, 2)
     net.SendToServer()
end

net.Receive("SardonPolaroid.ChooseMode", function()
     if IsValid(SardonPolaroidQuery) then
          SardonPolaroidQuery.OnRemove = nil
          SardonPolaroidQuery:Remove()
     end

     local answered = false
     local function choose(mode)
          answered = true
          sendMode(mode)
     end

     SardonPolaroidQuery = Derma_Query("¿Cómo quieres capturar el recuerdo?", "Capere Momentum",
          "Selfi", function() choose(1) end,
          "De frente", function() choose(2) end,
          "Cancelar", function() choose(0) end)

     -- Panel X ile kapatılırsa sunucudaki bekleyen seçim iptal edilir
     SardonPolaroidQuery.OnRemove = function()
          if not answered then sendMode(0) end
     end
end)
net.Receive("SardonPolaroid.StartCapture", function()
     if IsValid(SardonPolaroidPanel) then SardonPolaroidPanel:Remove() end
     SardonPolaroidPanel = vgui.Create("DLabel")
     local t = 3
     SardonPolaroidPanel:SetFont("SardonPolaroid.Countdown")
     SardonPolaroidPanel:SetText(t)
     SardonPolaroidPanel:SizeToContents()
     SardonPolaroidPanel:Center()
     timer.Create("SardonPolaroid.StartCapture", 1, 3, function()
          t = t - 1
          SardonPolaroidPanel:SetText(t)
          SardonPolaroidPanel:SizeToContents()
          SardonPolaroidPanel:Center()
          if t == 0 then
               SardonPolaroidPanel:SetText("")
               ScreenshotRequested = true
          end
     end)
end)

-- Kamera entity'si önbelleğe alınır; her karede FindByClass yerine bulunamadığında 0.1 sn'de bir aranır
local cachedCam = NULL
local nextCamScan = 0
-- 11-14 opt: kameralar olaylarla tutulan kümede; kamera yokken 0.1 sn'de bir ents.FindByClass (bütün varlıkları
-- gezer) yerine bu küme gezilir. Ekleme OnEntityCreated + NetworkEntityCreated (base_ai SENT'te GetClass istemcide
-- ilk anda doğru: [st] pets pet_owl kümesi aynı yolla istemcide doğrulandı), silme EntityRemoved + okurken IsValid.
-- Kaçan olayı 2 sn'de bir tam tarama onarır (eskiden en geç 0.1 sn).
local camSet = {}
local function camResync()
     table.Empty(camSet)
     for _, value in ipairs(ents.FindByClass("ent_polaroid_camera")) do camSet[value] = true end
end
local function camAdd(ent)
     if IsValid(ent) and ent:GetClass() == "ent_polaroid_camera" then camSet[ent] = true end
end
camResync()
timer.Create("SardonOpt.polaroid.CamSet", 2, 0, camResync)
hook.Add("OnEntityCreated", "SardonOpt.polaroid.CamSet", camAdd)
hook.Add("NetworkEntityCreated", "SardonOpt.polaroid.CamSet", camAdd)
hook.Add("EntityRemoved", "SardonOpt.polaroid.CamSet", function(ent, fullUpdate)
     -- 11-14 opt: tam güncellemede varlık geri gelebilir, kümede kalır; gelmezse okurken IsValid düşürür
     if not fullUpdate then camSet[ent] = nil end
end)
hook.Add("CalcView", "!!CameraCalcView", function(ply)
     local ent = cachedCam
     if not IsValid(ent) or ent:GetNWEntity("Owner") != LocalPlayer() then
          ent = NULL
          cachedCam = NULL
          local now = RealTime()
          if now < nextCamScan then return end
          nextCamScan = now + 0.1
          -- 11-14 opt: aynı süzgeç (sahibi LocalPlayer) kümede; birden çok eşleşmede kazananı eski sıra belirlesin
          -- diye o durumda (sunucu kişi başı tek kamera açtırıyor) eski tarama aynen yapılır
          local several = false
          for value in pairs(camSet) do
               if not IsValid(value) then
                    camSet[value] = nil
               elseif value:GetNWEntity("Owner") == LocalPlayer() then
                    if IsValid(ent) then
                         several = true
                         break
                    end
                    ent = value
               end
          end
          if several then
               ent = NULL
               for key, value in ipairs(ents.FindByClass("ent_polaroid_camera")) do
                    if value:GetNWEntity("Owner") == LocalPlayer() then
                         ent = value
                         break
                    end
               end
          end
          cachedCam = ent
     end

     if not IsValid(ent) then return end
     local ang = ent:GetAngles()
     local view = {
          origin = ent:GetPos() + ang:Up() * 8 + ang:Right() * -3,
          angles = ang,
          fov = 60,
          drawviewer = true
     }
     return view
end)

hook.Add("PostRender", "CapturePhoto", function()
     if not ScreenshotRequested then return end
     ScreenshotRequested = false
     net.Start("SardonPolaroid.Notify")
     net.SendToServer()
     local data = render.Capture({
          format = "png",
          x = 0,
          y = 0,
          w = ScrW(),
          h = ScrH(),
          alpha = false, -- only needed for the png format to prevent the depth buffer leaking in, see BUG,
     })

     if not data then ScreenshotRequested = true end
     local formData = FormData()
     formData:Append("source", util.Base64Encode(data))
     formData:Append("key", "6d207e02198a847aa98d0a2a901485a5")
     if IsValid(SardonPolaroidPanel) then
          local h = ScreenScale(48)
          SardonPolaroidPanel:SetSize(h, h)
          SardonPolaroidPanel:Center()
          SardonPolaroidPanel.Paint = function() XeninUI:DrawLoadingCircle(h / 2, h / 2, h, color_white) end
     end

     HTTP({
          url = "https://freeimage.host/api/1/upload",
          method = "POST",
          headers = table.Merge(formData:GetHeaders(), {
               ["Authorization"] = "Client-ID e4f58fc81daec99"
          }),
          body = formData:Read(),
          success = function(code, body)
               if IsValid(SardonPolaroidPanel) then SardonPolaroidPanel:Remove() end
               if code ~= 200 then
                    LocalPlayer():Notify("Ha ocurrido un error; revisa la consola.")
                    print(code, body)
               end

               body = util.JSONToTable(body)
               if not body.success then
                    LocalPlayer():Notify("Ha ocurrido un error; revisa la consola.")
                    print(code)
                    PrintTable(body)
               end

               net.Start("SardonPolaroid.StartCapture")
               net.WriteString(body.image.id_encoded)
               net.SendToServer()
          end,
          failed = print
     })
end)

-- FORM DATA
local mimeLookup = {
     jpg = "image/jpeg",
     jpeg = "image/jpeg",
     png = "image/png",
     gif = "image/gif",
     tif = "image/tiff",
     tiff = "image/tiff",
     bmp = "image/bmp",
     ico = "image/x-icon",
     txt = "text/plain",
     html = "text/html",
     htm = "text/html",
     css = "text/css",
     js = "application/javascript",
     json = "application/json",
     xml = "application/xml",
     pdf = "application/pdf",
     zip = "application/zip",
     rar = "application/x-rar-compressed",
     gz = "application/x-gzip",
     tar = "application/x-tar",
     mp3 = "audio/mpeg",
     wav = "audio/wav",
     ogg = "audio/ogg",
     mp4 = "video/mp4",
     webm = "video/webm",
     mkv = "video/x-matroska",
     avi = "video/x-msvideo",
     mov = "video/quicktime",
     wmv = "video/x-ms-wmv",
     flv = "video/x-flv",
     swf = "application/x-shockwave-flash",
     svg = "image/svg+xml",
     svgz = "image/svg+xml",
     eot = "application/vnd.ms-fontobject",
     ttf = "application/font-sfnt",
     woff = "application/font-woff",
     woff2 = "application/font-woff2",
     otf = "application/font-sfnt",
}

local function getMimeType(filename)
     local ext = string.GetExtensionFromFilename(filename)
     return mimeLookup[string.lower(ext)] or "application/octet-stream"
end

function FormData()
     return {
          entries = {},
          boundary = tostring(math.Round(os.time())),
          Append = function(self, name, value, mime, filename)
               if mime and not filename then
                    -- Gotta figure out what our params are
                    local isMime = string.find(mime, "/", 1, false) ~= nil
                    if not isMime then
                         -- mime is actually the filename
                         filename = mime
                         mime = getMimeType(filename)
                    end
               end

               if not mime and istable(value) then
                    value = util.TableToJSON(value)
                    mime = "application/json"
               end

               table.insert(self.entries, {
                    name = name,
                    value = value,
                    mime = mime,
                    filename = filename
               })
          end,
          Read = function(self)
               local body = ""
               for _, entry in ipairs(self.entries) do
                    local mime = entry.mime
                    local name = entry.name
                    local value = entry.value
                    local filename = entry.filename
                    body = body .. "--" .. self.boundary
                    body = body .. "\r\nContent-Disposition: form-data; name=\"" .. name .. "\""
                    if filename then body = body .. "; filename=\"" .. filename .. "\"" end
                    body = body .. "\r\nContent-Type: " .. (mime or "text/plain") .. "; charset=utf-8"
                    body = body .. "\r\n\r\n" .. value .. "\r\n"
               end

               body = body .. "--" .. self.boundary .. "--\r\n"
               return body
          end,
          GetHeaders = function(self)
               return {
                    ["Content-Length"] = #self:Read(),
                    ["Content-Type"] = "multipart/form-data; charset=utf-8; boundary=" .. self.boundary
               }
          end
     }
end

--[[------------------------------------------------------------------------
     Fotoğraf modu (/Foto, bind: sardon_foto)
     Oyuncunun çevresinde kısa menzilli serbest kamera: karakterini çekmek, açı bulmak için.
     Kötüye kullanım sınırları (hepsi birlikte):
       * kamera gövde merkezinden en çok YARICAP, gözün en çok TAVAN üstünde
       * oyuncu çarpışma maskesiyle kutu izi: duvar, kapı, cam, ızgara, player clip geçilmez
       * kamera oyuncunun gözünden ya da gövde merkezinden görünmeli (köşe ardı / yan oda yok);
         kapı kapanır ya da görüş kesilirse kamera omuza döner
       * oyuncu yürüyemez, saldıramaz; yerinden ayrılır, ölür, yere düşerse kapanır.
         Sunucu oyuncu/NPC hasarında kapatır, hasardan sonra 15 sn açtırmaz (sv_init.lua sonu).
     Helix eklenti kancaları (thirdperson CalcView/CreateMove/InputMouseApply) normal
     kancalardan önce çalıştığı için mod açıkken ilgili olayların HOOKS_CACHE girdisi vekille
     değişir (sinema kamerasıyla aynı yöntem); kapatınca geri konur.
--------------------------------------------------------------------------]]
SardonFoto = SardonFoto or {}
local F = SardonFoto

-- Canlı yenilemede eski sürüm açıksa önce onun vekillerini sök
if F.Aktif and F.Bitir then F.Bitir(true) end

local YARICAP = 160          -- gövde merkezinden en uzak kamera mesafesi
local TAVAN = 56             -- gözün en çok bu kadar üstüne çıkar (duvar üstünden bakmasın)
local KACIS = 48             -- oyuncu bu kadar yer değiştirirse mod kapanır
local HIZ = 90
local FOV_MIN, FOV_MAX = 15, 90
local EGIM_MAX = 40
local KUTU_MIN, KUTU_MAX = Vector(-6, -6, -6), Vector(6, 6, 6)
local ZK_MIN, ZK_MAX = Vector(-12, -12, -12), Vector(12, 12, 12)
local band = bit.band

surface.CreateFont("SardonFoto.Baslik", { font = "Montserrat SemiBold", size = math.max(15, math.Round(ScrH() / 52)), extended = true })
surface.CreateFont("SardonFoto.Tus", { font = "Montserrat SemiBold", size = math.max(12, math.Round(ScrH() / 76)), extended = true })
surface.CreateFont("SardonFoto.Ipucu", { font = "Montserrat Medium", size = math.max(12, math.Round(ScrH() / 76)), extended = true })

function F.Bildir(m)
     if ix and ix.util and ix.util.Notify then ix.util.Notify(m) else notification.AddLegacy(m, NOTIFY_HINT, 4) end
end

local function DurumGonder(acik)
     if util.NetworkStringToID("SardonFoto.Durum") == 0 then return end
     net.Start("SardonFoto.Durum")
     net.WriteBool(acik)
     net.SendToServer()
end

------------------------------------------------------------------------ iz / sınırlar

local function IzFiltre(ent)
     if ent:IsWorld() then return true end
     if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() or ent:IsWeapon() or ent:IsRagdoll() or ent:IsVehicle() then return false end
     local ust = ent:GetParent()
     if IsValid(ust) and ust:IsPlayer() then return false end
     return true
end

-- Çapalar oyuncunun çarpışma kutusunun içinde (göz, gövde merkezi): kemik değil, çünkü bir
-- animasyon kafayı duvarın içine sokabilir; kutu ise hiçbir zaman duvarın içinde olmaz.
local function Gorunur(ply, pos)
     if not util.TraceLine({ start = ply:EyePos(), endpos = pos, mask = MASK_SOLID, filter = IzFiltre }).Hit then return true end
     return not util.TraceLine({ start = ply:WorldSpaceCenter(), endpos = pos, mask = MASK_SOLID, filter = IzFiltre }).Hit
end

local function Kutu(bas, son)
     return util.TraceHull({ start = bas, endpos = son, mins = KUTU_MIN, maxs = KUTU_MAX, mask = MASK_PLAYERSOLID, filter = IzFiltre })
end

local function Sinirla(ply, hedef)
     local sinir = false
     local tavan = ply:EyePos().z + TAVAN
     if hedef.z > tavan then hedef.z = tavan sinir = true end
     local merkez = ply:WorldSpaceCenter()
     local fark = hedef - merkez
     if fark:LengthSqr() > YARICAP * YARICAP then
          hedef = merkez + fark:GetNormalized() * YARICAP
          sinir = true
     end
     return hedef, sinir
end

local function Icinde(ply, pos)
     return pos:DistToSqr(ply:WorldSpaceCenter()) <= (YARICAP + 1) ^ 2 and pos.z <= ply:EyePos().z + TAVAN + 1
end

-- pos'tan hedefe kutu iziyle git, duvara değince yüzey boyunca kay. Döner: yeni konum, uyarı
function F.Tasi(ply, pos, hedef)
     local sinir
     hedef, sinir = Sinirla(ply, hedef)

     local tr = Kutu(pos, hedef)
     if tr.StartSolid then return pos end
     local yeni = tr.HitPos

     if tr.Hit then
          local kalan = hedef - yeni
          kalan = kalan - tr.HitNormal * kalan:Dot(tr.HitNormal)
          if kalan:LengthSqr() > 0.01 then
               local tr2 = Kutu(yeni, yeni + kalan)
               if not tr2.StartSolid and Icinde(ply, tr2.HitPos) and Gorunur(ply, tr2.HitPos) then
                    return tr2.HitPos, sinir and "Límite de distancia" or nil
               end
          end
     end

     if not Gorunur(ply, yeni) then return pos, "La cámara debe poder verte" end
     return yeni, sinir and "Límite de distancia" or nil
end

function F.KonumSec(tur)
     local ply = LocalPlayer()
     local goz = ply:EyePos()
     local hedef, aci

     if tur == "karsi" then
          local a = Angle(0, F.gozAci.y, 0)
          hedef = goz + a:Forward() * 72 + OPT_V_0_0_8
     else
          tur = "omuz"
          local ca = ply.camAng or F.gozAci
          aci = Angle(math.Clamp(math.NormalizeAngle(ca.p), -30, 45), ca.y, 0)
          hedef = goz + aci:Up() * 6 + aci:Right() * 14 - aci:Forward() * 80
     end

     local tr = Kutu(goz, hedef)
     local pos = tr.StartSolid and goz or tr.HitPos
     if tur == "karsi" then
          local b = (goz - OPT_V_0_0_4 - pos):Angle()
          aci = Angle(math.NormalizeAngle(b.p), b.y, 0)
     end

     F.pos, F.ang, F.hiz, F.konum = pos, aci, Vector(0, 0, 0), tur
end

-- Dar açıda uzaktaki giysi katmanları derinlikte titreşmesin diye yakın kesmeyi büyüt; geniş
-- açıda 3'te kalır (kenardaki duvar kesilip arkası görünmesin). İz kutusu dar görüş konisini örter.
function F.YakinKesme(ply)
     if F.fov >= 50 then return 3 end
     local tr = util.TraceHull({ start = F.pos, endpos = F.pos + F.ang:Forward() * 48, mins = ZK_MIN, maxs = ZK_MAX, mask = MASK_SOLID, filter = ply })
     local d = tr.StartSolid and 0 or tr.Fraction * 48
     d = math.min(d, F.pos:Distance(ply:WorldSpaceCenter()) - 28, F.pos:Distance(ply:EyePos()) - 12)
     return math.Clamp(d * 0.5, 3, 12)
end

------------------------------------------------------------------------ girdi

local onceki = {}
local IZLE = { KEY_R, KEY_F, KEY_H, KEY_BACKSPACE }

local function Basildi(kod)
     local s = input.IsKeyDown(kod)
     local o = onceki[kod]
     onceki[kod] = s
     return s and not o
end

local function Tus(b, m) return band(b, m) ~= 0 and 1 or 0 end

function F.KomutOku(cmd)
     F.tus = cmd:GetButtons()
end

function F.KomutYaz(cmd)
     cmd:ClearMovement()
     cmd:ClearButtons()
     cmd:SetImpulse(0)
     if F.comel then cmd:SetButtons(IN_DUCK) end
     cmd:SetViewAngles(F.bakis)
end

function F.Fare(x, y)
     local k = 0.02 * (F.fov / 75)
     F.ang.p = math.Clamp(F.ang.p + y * k, -89, 89)
     F.ang.y = math.NormalizeAngle(F.ang.y - x * k)
end

local function AciYaklas(a, b, f)
     return Angle(a.p + math.AngleDifference(b.p, a.p) * f, a.y + math.AngleDifference(b.y, a.y) * f, 0)
end

------------------------------------------------------------------------ Helix kanca önbelleği vekilleri

local ENGEL = {
     HUDPaintBackground = true, HUDDrawTargetID = true, HUDDrawPickupHistory = true,
     DrawDeathNotice = true, HUDDrawScoreBoard = true, PostDrawHUD = true, PostRenderVGUI = true,
     ScoreboardShow = true, HUDWeaponPickedUp = true, HUDItemPickedUp = true, HUDAmmoPickedUp = true,
     ContextMenuOpen = true, SpawnMenuOpen = true,
}

local ENGEL_BIND = {
     ["+attack"] = true, ["+attack2"] = true, ["+attack3"] = true, ["+use"] = true, ["+reload"] = true,
     ["+menu"] = true, ["+menu_context"] = true, ["+zoom"] = true, ["+showscores"] = true,
     ["+grenade1"] = true, ["+grenade2"] = true, noclip = true, kill = true, explode = true,
     lastinv = true, phys_swap = true, undo = true, gmod_undo = true, impulse = true,
}

local MUDAHALE = {}

MUDAHALE.CalcView = function()
     return true, { origin = F.pos, angles = Angle(F.ang.p, F.ang.y, F.egim), fov = F.fov, drawviewer = true, znear = F.znear }
end
MUDAHALE.InputMouseApply = function(cmd, x, y)
     F.Fare(x, y)
     return true, true
end
MUDAHALE.ShouldDrawLocalPlayer = function() return true, true end
MUDAHALE.ShouldDisableLegs = function() return true, true end
MUDAHALE.PreDrawViewModel = function() return true, true end
MUDAHALE.PreDrawPlayerHands = function() return true, true end
MUDAHALE.HUDShouldDraw = function(ad)
     -- CHudGMod kapanırsa HUDPaint hiç çağrılmaz; ipuçları orada çiziliyor
     return true, ad == "CHudGMod"
end
MUDAHALE.HUDPaint = function()
     F.Ciz()
     return true, true
end
MUDAHALE.PlayerBindPress = function(_, bind, basili)
     local ilk = string.match(string.lower(bind or ""), "^%s*(%S+)") or ""
     if ilk == "invprev" or ilk == "invnext" then
          if basili then
               F.fovHedef = math.Clamp(F.fovHedef * (ilk == "invprev" and 0.88 or 1 / 0.88), FOV_MIN, FOV_MAX)
          end
          return true, true
     end
     if ilk == "jpeg" or ilk == "screenshot" then
          F.ipucuSakla = RealTime() + 0.5   -- ekran görüntüsünde ipuçları çıkmasın
          return
     end
     if ENGEL_BIND[ilk] or string.find(ilk, "^slot%d") then return true, true end
end

local VEKIL_ANAHTAR = { ad = "SardonFoto" }
local vekiller, saklanan = {}, {}

local function Saklanan(ad, ...)
     local eski = saklanan[ad]
     if eski then
          for k, v in pairs(eski) do
               local a, b, c, d, e, g = v(k, ...)
               if a ~= nil then return a, b, c, d, e, g end
          end
     end
end

local function Vekil(ad)
     if ad == "CreateMove" then
          return function(_, cmd)
               if not F.Aktif then return Saklanan(ad, cmd) end
               F.KomutOku(cmd)
               local a, b = Saklanan(ad, cmd)
               F.KomutYaz(cmd)
               return a, b
          end
     end

     return function(_, ...)
          if F.Aktif then
               if ENGEL[ad] then return true end
               local f = MUDAHALE[ad]
               if f then
                    local yakala, a = f(...)
                    if yakala then return a end
               end
          end
          return Saklanan(ad, ...)
     end
end

local OLAYLAR = { "CreateMove" }
for ad in pairs(ENGEL) do OLAYLAR[#OLAYLAR + 1] = ad end
for ad in pairs(MUDAHALE) do OLAYLAR[#OLAYLAR + 1] = ad end

function F.VekilleriKur()
     for _, ad in ipairs(OLAYLAR) do
          local mevcut = HOOKS_CACHE[ad]
          if mevcut == nil or mevcut ~= vekiller[ad] then
               -- Helix eklentileri yeniden yüklediyse yeni tabloyu sakla
               saklanan[ad] = mevcut
               local v = { [VEKIL_ANAHTAR] = Vekil(ad) }
               vekiller[ad] = v
               HOOKS_CACHE[ad] = v
          end
     end
end

function F.VekilleriSok()
     if not HOOKS_CACHE then return end
     for _, ad in ipairs(OLAYLAR) do
          if vekiller[ad] and HOOKS_CACHE[ad] == vekiller[ad] then HOOKS_CACHE[ad] = saklanan[ad] end
          vekiller[ad], saklanan[ad] = nil, nil
     end
end

------------------------------------------------------------------------ HUD panelleri

local gizlenen = {}
local MUAF = { DTooltip = true, DMenu = true, DMenuOption = true }

local function PanelGizle(kok)
     if not IsValid(kok) then return end
     local sohbet = ix and ix.gui and ix.gui.chat
     for _, p in ipairs(kok:GetChildren()) do
          if IsValid(p) and p ~= sohbet and p:IsVisible() then
               local sinif = p.ClassName or ""
               if not MUAF[sinif] and not string.find(string.lower(sinif), "chat", 1, true) then
                    p:SetVisible(false)
                    gizlenen[p] = true
               end
          end
     end
end

local function PanelleriGeriGetir()
     for p in pairs(gizlenen) do
          if IsValid(p) then p:SetVisible(true) end
     end
     gizlenen = {}
end

------------------------------------------------------------------------ çizim

local RENK_ZEMIN = Color(10, 12, 16, 175)
local RENK_TUS = Color(255, 255, 255, 26)
local RENK_YAZI = Color(236, 236, 240)
local RENK_SOLUK = Color(186, 189, 198)
local RENK_VURGU = Color(232, 198, 124)
local RENK_UYARI = Color(240, 200, 120)
local TUS_AD = { SPACE = "Espacio", CTRL = "Ctrl", SHIFT = "Mayús", ALT = "Alt", BACKSPACE = "Retroceso" }

local function Bag(b, yedek)
     local k = input.LookupBinding(b, true)
     if not k then return yedek end
     k = string.upper(k)
     return TUS_AD[k] or k
end

-- Aç/kapat tuşu: TAB › Ayarlar › Tuş Atamaları ([sardon] config, seçenek "foto", varsayılan V)
function F.Tusu()
     local o = SardonConfig and SardonConfig.Options and SardonConfig.Options.foto
     return o and SardonConfig:Get("foto") or KEY_V
end

local function TusAdi(kod)
     local ad = kod and kod > 0 and input.GetKeyName(kod)
     return ad and string.upper(language.GetPhrase(ad)) or nil
end

local function Duzenle()
     local w, a, s, d = Bag("+forward", "W"), Bag("+moveleft", "A"), Bag("+back", "S"), Bag("+moveright", "D")
     local hareket = (#w + #a + #s + #d == 4) and (w .. a .. s .. d) or (w .. " " .. a .. " " .. s .. " " .. d)
     local jpeg = input.LookupBinding("jpeg", true)

     local ipuclari = {
          { hareket, "Movimiento" },
          { Bag("+jump", "Espacio") .. " / " .. Bag("+duck", "Ctrl"), "Subir / bajar" },
          { Bag("+speed", "Mayús") .. " / " .. Bag("+walk", "Alt"), "Rápido / lento" },
          { "Rueda", "Zoom" },
          { "Q / E", "Inclinar" },
          { "R", "Hombro / frente" },
          { "F", "Mirar cámara" },
          { "H", "Ocultar interfaz" },
          { jpeg and (string.upper(jpeg) .. " / F12") or "F12", "Captura" },
          { TusAdi(F.Tusu()) and (TusAdi(F.Tusu()) .. " / Retroceso") or "Retroceso", "Salir" },
     }

     local sw = ScrW()
     local pad = math.max(4, math.Round(ScrH() / 135))
     surface.SetFont("SardonFoto.Tus")
     local _, th = surface.GetTextSize("Ağ")
     local satirlar, satir, gen = {}, {}, 0
     for _, ip in ipairs(ipuclari) do
          surface.SetFont("SardonFoto.Tus")
          local tw = surface.GetTextSize(ip[1]) + pad * 2
          surface.SetFont("SardonFoto.Ipucu")
          local ow = tw + pad + surface.GetTextSize(ip[2])
          if #satir > 0 and gen + pad * 3 + ow > sw - 64 then
               satirlar[#satirlar + 1] = { ogeler = satir, w = gen }
               satir, gen = {}, 0
          end
          if #satir > 0 then gen = gen + pad * 3 end
          satir[#satir + 1] = { tus = ip[1], etiket = ip[2], tw = tw, w = ow }
          gen = gen + ow
     end
     satirlar[#satirlar + 1] = { ogeler = satir, w = gen }

     local enGenis = 0
     for _, st in ipairs(satirlar) do enGenis = math.max(enGenis, st.w) end
     F.duzen = { satirlar = satirlar, pad = pad, h = th + pad, enGenis = enGenis, sw = sw }
end

function F.Ciz()
     if F.gizli or (F.ipucuSakla or 0) > RealTime() then return end
     local sw, sh = ScrW(), ScrH()
     if not F.duzen or F.duzen.sw ~= sw then Duzenle() end
     local d = F.duzen
     local pad = d.pad

     -- başlık
     surface.SetFont("SardonFoto.Baslik")
     local baslik = "MODO FOTO"
     local bw, bh = surface.GetTextSize(baslik)
     local nokta = math.Round(bh * 0.42)
     local kutuH = bh + pad * 2
     draw.RoundedBox(6, 16, 16, pad * 5 + nokta + bw, kutuH, RENK_ZEMIN)
     draw.RoundedBox(math.floor(nokta / 2), 16 + pad * 2, 16 + (kutuH - nokta) / 2, nokta, nokta,
          Color(226, 72, 72, 150 + 100 * math.abs(math.sin(RealTime() * 2.2))))
     draw.SimpleText(baslik, "SardonFoto.Baslik", 16 + pad * 3 + nokta, 16 + kutuH / 2, RENK_YAZI, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

     local y = 16 + kutuH + pad
     if F.bak then
          draw.SimpleText("Mirando a la cámara", "SardonFoto.Ipucu", 16 + pad, y, RENK_VURGU, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     end

     -- sınır uyarısı
     local gecen = RealTime() - (F.uyariZaman or 0)
     if F.uyari and gecen < 1.4 then
          local alfa = 255 * math.Clamp((1.4 - gecen) / 0.4, 0, 1)
          surface.SetFont("SardonFoto.Ipucu")
          local uw, uh = surface.GetTextSize(F.uyari)
          draw.RoundedBox(6, (sw - uw) / 2 - pad * 2, 16, uw + pad * 4, uh + pad * 2, Color(10, 12, 16, 175 * alfa / 255))
          draw.SimpleText(F.uyari, "SardonFoto.Ipucu", sw / 2, 16 + pad + uh / 2, Color(RENK_UYARI.r, RENK_UYARI.g, RENK_UYARI.b, alfa), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     -- tuş ipuçları
     local n = #d.satirlar
     local toplamH = n * d.h + (n - 1) * pad + pad * 2
     local y0 = sh - toplamH - 24
     draw.RoundedBox(8, (sw - d.enGenis) / 2 - pad * 2, y0, d.enGenis + pad * 4, toplamH, RENK_ZEMIN)
     y = y0 + pad
     for _, st in ipairs(d.satirlar) do
          local x = (sw - st.w) / 2
          for _, o in ipairs(st.ogeler) do
               draw.RoundedBox(4, x, y, o.tw, d.h, RENK_TUS)
               draw.SimpleText(o.tus, "SardonFoto.Tus", x + o.tw / 2, y + d.h / 2, RENK_VURGU, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               draw.SimpleText(o.etiket, "SardonFoto.Ipucu", x + o.tw + pad, y + d.h / 2, RENK_SOLUK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               x = x + o.w + pad * 3
          end
          y = y + d.h + pad
     end
end

------------------------------------------------------------------------ her kare

local function CikisNedeni(ply)
     if not ply:Alive() or ply:GetViewEntity() ~= ply then return "" end
     local rd = ply.GetLocalVar and ply:GetLocalVar("ragdoll", 0) or 0
     if rd ~= 0 and IsValid(Entity(rd)) then return "" end
     if ply:GetMoveType() == MOVETYPE_NOCLIP then return "" end
     if SardonSinema and SardonSinema.Aktif then return "" end
     if ply:GetPos():DistToSqr(F.basPos) > KACIS * KACIS then return "El modo foto se cerró porque te alejaste." end
end

function F.Dusun()
     local ply = LocalPlayer()
     if not F.Aktif or not IsValid(ply) then return end

     local neden = CikisNedeni(ply)
     if neden then F.Bitir(false, neden) return end

     F.VekilleriKur()   -- Helix eklentileri yeniden yüklerse tazele

     local dt = math.min(RealFrameTime(), 0.1)
     local simdi = RealTime()

     if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or gui.IsConsoleVisible() or ply:IsTyping() then
          for _, k in ipairs(IZLE) do onceki[k] = input.IsKeyDown(k) end
     else
          if Basildi(KEY_BACKSPACE) then F.Bitir() return end
          if Basildi(KEY_R) then
               F.KonumSec(F.konum == "omuz" and "karsi" or "omuz")
               F.egim, F.fovHedef = 0, F.fovVarsayilan
          end
          if Basildi(KEY_F) then F.bak = not F.bak end
          if Basildi(KEY_H) then F.gizli = not F.gizli end
          local e = (input.IsKeyDown(KEY_E) and 1 or 0) - (input.IsKeyDown(KEY_Q) and 1 or 0)
          if e ~= 0 then F.egim = math.Clamp(F.egim + e * 35 * dt, -EGIM_MAX, EGIM_MAX) end
     end

     -- hareket: bind'lerden (CreateMove'da okunan tuşlar), noclip gibi bakış yönünde
     local b = F.tus or 0
     local ileri = Tus(b, IN_FORWARD) - Tus(b, IN_BACK)
     local sag = Tus(b, IN_MOVERIGHT) - Tus(b, IN_MOVELEFT)
     local yon = F.ang:Forward() * ileri + F.ang:Right() * sag
     yon.z = yon.z + Tus(b, IN_JUMP) - Tus(b, IN_DUCK)
     if yon:LengthSqr() > 1 then yon:Normalize() end
     local hiz = HIZ * (Tus(b, IN_SPEED) == 1 and 2.2 or 1) * (Tus(b, IN_WALK) == 1 and 0.35 or 1)
     F.hiz = LerpVector(1 - math.exp(-dt * 10), F.hiz, yon * hiz)

     if F.hiz:LengthSqr() > 0.25 then
          local yeni, uyari = F.Tasi(ply, F.pos, F.pos + F.hiz * dt)
          if uyari then F.uyari, F.uyariZaman = uyari, simdi end
          if yeni == F.pos then F.hiz = Vector(0, 0, 0) end
          F.pos = yeni
     end

     -- kapı kapandı, oyuncu itildi vb.: kamera geçersiz kaldıysa omuza dön
     if simdi > (F.sonDenetim or 0) then
          F.sonDenetim = simdi + 0.2
          if Kutu(F.pos, F.pos).StartSolid or not Icinde(ply, F.pos) or not Gorunur(ply, F.pos) then
               F.KonumSec("omuz")
               F.uyari, F.uyariZaman = "La cámara volvió a ti", simdi
          end
     end

     F.fov = Lerp(1 - math.exp(-dt * 12), F.fov, F.fovHedef)

     local hedefBakis = F.gozAci
     if F.bak then
          local h = (F.pos - ply:EyePos()):Angle()
          -- koltukta (sit eklentisi) bakış açısı araca göre yereldir
          local arac = ply:GetVehicle()
          if IsValid(arac) then h = arac:WorldToLocalAngles(h) end
          hedefBakis = Angle(math.Clamp(math.NormalizeAngle(h.p), -60, 60), h.y, 0)
     end
     F.bakis = AciYaklas(F.bakis, hedefBakis, 1 - math.exp(-dt * 8))
     ply:SetEyeAngles(F.bakis)

     F.znear = F.YakinKesme(ply)

     -- sonradan açılan HUD panelleri
     if simdi > (F.sonPanel or 0) then
          F.sonPanel = simdi + 0.25
          PanelGizle(GetHUDPanel())
     end
end

------------------------------------------------------------------------ aç / kapat

function F.Baslat()
     if F.Aktif then return end
     local ply = LocalPlayer()
     if not IsValid(ply) then return end
     if not HOOKS_CACHE then
          ErrorNoHalt("[Sardon Foto] HOOKS_CACHE ausente; no se pudo abrir el modo foto\n")
          return
     end
     if SardonSinema and SardonSinema.Aktif then
          F.Bildir("No puedes usar el modo foto con la cámara de cine activa.")
          return
     end

     local ea = ply:EyeAngles()
     F.Aktif = true
     F.basPos = ply:GetPos()
     F.gozAci = Angle(math.NormalizeAngle(ea.p), ea.y, 0)
     F.bakis = Angle(F.gozAci.p, F.gozAci.y, 0)
     F.comel = ply:Crouching()
     F.bak, F.gizli, F.egim, F.tus = false, false, 0, 0
     local fd = GetConVar("fov_desired")
     F.fovVarsayilan = math.Clamp(fd and fd:GetFloat() or 75, 60, FOV_MAX)
     F.fov, F.fovHedef, F.znear = F.fovVarsayilan, F.fovVarsayilan, 3
     F.sonDenetim, F.sonPanel, F.uyari, F.uyariZaman, F.ipucuSakla = 0, 0, nil, 0, 0
     F.duzen = nil
     F.KonumSec("omuz")
     for _, k in ipairs(IZLE) do onceki[k] = input.IsKeyDown(k) end

     F.VekilleriKur()
     PanelGizle(vgui.GetWorldPanel())
     PanelGizle(GetHUDPanel())
     hook.Add("Think", "SardonFoto", F.Dusun)
     hook.Add("SardonHUDGizle", "SardonFoto", function() return true end)

     surface.PlaySound("npc/scanner/scanner_photo1.wav")
     DurumGonder(true)
end

function F.Bitir(sessiz, mesaj)
     if not F.Aktif then return end
     F.Aktif = false

     hook.Remove("Think", "SardonFoto")
     hook.Remove("SardonHUDGizle", "SardonFoto")
     F.VekilleriSok()
     PanelleriGeriGetir()

     local ply = LocalPlayer()
     if IsValid(ply) and F.gozAci then ply:SetEyeAngles(F.gozAci) end

     if not sessiz then
          surface.PlaySound("buttons/lightswitch2.wav")
          if mesaj and mesaj ~= "" then F.Bildir(mesaj) end
     end
     DurumGonder(false)
end

net.Receive("SardonFoto.Ac", function()
     if F.Aktif then F.Bitir() else F.Baslat() end
end)

net.Receive("SardonFoto.Kapat", function()
     F.Bitir(false, net.ReadString())
end)

concommand.Add("sardon_foto", function()
     if F.Aktif then F.Bitir() return end
     if ix and ix.command and ix.command.Send then ix.command.Send("Foto") end
end)

-- Ayarlardaki tuş (varsayılan V). Bind'den bağımsız düz tuş yoklaması: mod açıkken cmd
-- temizlendiği için PlayerButtonDown'a güvenilmez. Yetkililerde V aynı zamanda noclip; tuş
-- noclip'e bağlıysa ve noclip yetkisi varsa açmaz (noclip çalışır, ayarlardan başka tuş seçebilir).
-- Mod açıkken noclip bind'i zaten yutuluyor, aynı tuş kapatır.
local tusOnce = false

local function NoclipYetkisi(ply)
     if ply.HasPermission and ply:HasPermission("can_noclip") then return true end
     return ply:IsAdmin()
end

hook.Add("Think", "SardonFoto.Tus", function()
     local tus = F.Tusu()
     if not tus or tus <= 0 then return end
     local basili = input.IsButtonDown(tus)
     local yeni = basili and not tusOnce
     tusOnce = basili
     if not yeni then return end

     local ply = LocalPlayer()
     if not IsValid(ply) or vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or gui.IsConsoleVisible() or ply:IsTyping() then return end

     if F.Aktif then F.Bitir() return end
     if vgui.CursorVisible() then return end

     local bag = input.LookupKeyBinding(tus)
     if bag and string.find(string.lower(bag), "noclip", 1, true) and NoclipYetkisi(ply) then return end

     if (F.istekCD or 0) > RealTime() then return end
     F.istekCD = RealTime() + 0.5
     if ix and ix.command and ix.command.Send then ix.command.Send("Foto") end
end)

-- Sohbet önerileri / yardım için; asıl iş sunucuda (sv_init.lua)
ix.command.Add("Foto", {
     description = "Modo foto: cámara libre de corto alcance alrededor de tu personaje. Escríbelo de nuevo para cerrar.",
     alias = { "FotoModu", "Fotograf" },
     OnRun = function() end
})
