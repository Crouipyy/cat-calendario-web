-- "addons\\sardonkira\\lua\\sardon_kira\\cl_5sayfa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kira v2 :: Shine Admin "Kiralar" sayfası (yalnız süper yetkili). Asıl inceleme ve onay sitede
-- (shop.shineroleplay.com/yonetim/kira); burası oyundaki ömür: etkin/bekleyen/biten kiralar, elle uzatma,
-- iptal, karakter bağını kaldırma, bekleyeni doğrulama ve derlemeyi "Oyunda dene".
local K = SardonKira
local D = K.D
local OP = K.OP

local function tarih(t) return t and os.date("%d.%m.%Y %H:%M", t) or "—" end

local SEKME = {
     etkin = function(r) return r.durum == D.ETKIN end,
     bekleyen = function(r) return r.durum == D.BEKLIYOR end,
     biten = function(r) return r.durum == D.TOLERANS or r.durum == D.CIKTI or r.durum == D.IPTAL end,
}

local function islem(ad, kod, ek)
     local t = ek or {}
     t.islem, t.kod = ad, kod
     K.Iste(OP.Y_ISLEM, t)
end

local function SayfaKaydet()
     if not ShineAdmin or not ShineAdmin.RegisterPage then return false end

     ShineAdmin:RegisterPage("kira", {
          label = "Alquiler de modelos",
          icon = "user",
          group = "systems",
          order = 60,
          title = "Alquiler de modelos",
          subtitle = "Vida en juego de los alquileres aprobados en la web y subidos al Workshop. Revisión y aprobación en shop.shineroleplay.com/yonetim/kira.",
          access = function(ply) return ply:IsSuperAdmin() end,
          rail = true,
          available = function() return SardonKira and SardonKira.D end,

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local P = ctx.panel
               local W, H = ctx.w, ctx.h
               local sekme = "etkin"
               local sel, list

               local function satirlar()
                    if sekme == "deneme" then
                         local out = {}
                         for _, d in ipairs(K.Yonetim.denemeler or {}) do
                              out[#out + 1] = { deneme = true, kod = d.dosya, ad = d.ad or d.kod, durum = "DENEME", boyut = d.boyut, zaman = d.zaman, modelYolu = d.modelYolu }
                         end
                         return out
                    end
                    local out = {}
                    for _, r in ipairs(K.Yonetim.liste or {}) do
                         if SEKME[sekme](r) then out[#out + 1] = r end
                    end
                    return out
               end
               local function secili()
                    for _, r in ipairs(satirlar()) do if r.kod == sel then return r end end
               end
               local function yenile()
                    if IsValid(list) then list:SetItems(satirlar(), true) end
               end
               hook.Add("SardonKiraYonetim", P, yenile)
               K.Iste(OP.YONETIM)

               N.SubTabs(P, 0, 0, u(W), {
                    { "etkin", "Etkin" }, { "bekleyen", "Yayın bekleyen" }, { "biten", "Biten / iptal" }, { "deneme", "Deneme paketleri" },
               }, function() return sekme end, function(id)
                    sekme = id
                    sel = nil
                    yenile()
               end)

               local head = vgui.Create("DPanel", P)
               head:SetPos(0, u(54))
               head:SetSize(u(W), u(30))
               head.Paint = function(s, w, h)
                    N.TableHead(0, 0, w, { { "Model", u(16) }, { "Sahip / karakter", w * 0.38 }, { "Durum", w * 0.66 }, { "Bitiş", w - u(24), TEXT_ALIGN_RIGHT } })
               end

               list = N.VList(P, 0, u(84), u(W), u(H - 84 - 64), {
                    rowH = u(46), gapY = 0,
                    emptyText = "Bu sekmede kira yok.",
                    onClick = function(r) sel = r.kod end,
                    paintRow = function(r, i, x, y, w, h, hovered)
                         local on = sel == r.kod
                         if on then N.Box(x, y, w, h, N.Clr.selRow) N.Box(x, y, u(2), h, N.Clr.gold)
                         elseif hovered then N.Box(x, y, w, h, N.Clr.hoverRow) end
                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)
                         local ust, alt = y + h / 2 - u(8), y + h / 2 + u(9)
                         N.Text(N.Clip(r.ad or r.kod, "row", w * 0.38 - u(32)), "row", x + u(16), ust, on and N.Clr.text or N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(r.deneme and string.format("%.1f MB", (r.boyut or 0) / 1048576) or (r.kod .. " · " .. (r.paket or "?") .. " MB"), "tiny", x + u(16), alt, N.Clr.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         if not r.deneme then
                              N.Text(N.Clip(r.sid64 or "?", "row", w * 0.27), "row", x + w * 0.38, ust, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                              N.Text(r.karakterAd or "karakter seçilmedi", "tiny", x + w * 0.38, alt, r.karakterAd and N.Clr.tdText or N.Clr.warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                              N.Text(K.DURUM_YAZI[r.durum] or r.durum, "row", x + w * 0.66, ust, r.durum == D.ETKIN and N.Clr.ok or (r.durum == D.BEKLIYOR and N.Clr.mana or N.Clr.warn), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                              N.Text(r.oyunda and "oyunda" or "", "tiny", x + w * 0.66, alt, N.Clr.ok, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         end
                         N.Text(tarih(r.deneme and r.zaman or r.bitis), "tiny", x + w - u(24), y + h / 2, N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end,
               })

               local bar = N.StickyBar(P, 0, u(H - 56), u(W), function()
                    local r = secili()
                    if not r then return "Listeden bir kira seç." end
                    if r.deneme then return "Dene: paket indirilir, model 5 dk senin üstünde olur (başkaları ERROR görür).", N.Clr.mana end
                    if r.durum == D.BEKLIYOR then return "Model sunucuya restartta iner; \"Doğrula\" şimdi bakar." end
                    return K.KalanGun(r.bitis) .. " gün kaldı · bitiş " .. tarih(r.bitis)
               end)

               local function dugme(x, w, metin, fn, stil, kosul)
                    local b = N.Button(bar, x, u(9), w, u(36), metin, fn, stil)
                    b.Think = function(s) local r = secili() s:SetEnabled(r ~= nil and kosul(r)) end
                    return b
               end
               local sag = u(W)
               dugme(sag - u(150), u(150), "Oyunda dene", function()
                    local r = secili()
                    if r then islem("dene", r.kod, { dosya = r.kod }) ctx.Flash("Deneme paketi isteniyor...") end
               end, "primary", function(r) return r.deneme end)
               dugme(sag - u(150) - u(130), u(120), "Doğrula", function()
                    local r = secili() if r then islem("dogrula", r.kod) end
               end, "ghost", function(r) return r.durum == D.BEKLIYOR end)
               dugme(sag - u(150) - u(260), u(120), "+30 gün", function()
                    local r = secili()
                    if not r then return end
                    N.Confirm("Elle uzat", "\"" .. (r.ad or r.kod) .. "\" kirası 30 gün uzatılacak (ücretsiz, kayıt düşülür).", "Uzat", function() islem("uzat", r.kod, { gun = 30 }) end)
               end, "ghost", function(r) return r.durum == D.ETKIN or r.durum == D.TOLERANS end)
               dugme(sag - u(150) - u(390), u(120), "Bağı kaldır", function()
                    local r = secili()
                    if not r then return end
                    N.Confirm("Karakter bağını kaldır", "Model bağlı karakterden çıkarılır; sahibi /Kira'dan yeni karakter seçer.", "Kaldır", function() islem("bag_sifirla", r.kod) end)
               end, "ghost", function(r) return r.karakterId ~= nil and not r.deneme end)
               dugme(sag - u(150) - u(520), u(120), "İptal", function()
                    local r = secili()
                    if not r then return end
                    N.Confirm("Kirayı iptal et", "\"" .. (r.ad or r.kod) .. "\" hemen kullanılamaz olur ve giyen karakter eski görünümüne döner. Para iadesi sitede ayrıca yapılır.", "İptal et", function() islem("iptal", r.kod) end, true)
               end, "danger", function(r) return not r.deneme and r.durum ~= D.IPTAL end)

               ctx.SetRail({
                    hero = "icons/user",
                    badge = { text = "Model kirası", icon = "user", color = N.Clr.gold },
                    title = function() local r = secili() return r and (r.ad or r.kod) or "Kira seç" end,
                    body = function()
                         local r = secili()
                         if not r then return "Kiralar sitede yüklenir, ödenir ve incelenir; onaylanan model gece 04:00'te Workshop'a girer, 05:00 restartında burada ETKİN olur ve 30 gün sürer." end
                         if r.deneme then return "Derlenmiş (LOD'lu) modelin Workshop'suz deneme paketi. Animasyon, boy ve göz yüksekliğini yayından önce burada gör." end
                         return r.modelYolu or ""
                    end,
                    props = function()
                         local r = secili()
                         if not r then
                              local n = { ETKIN = 0, BEKLIYOR = 0, TOLERANS = 0 }
                              for _, x in ipairs(K.Yonetim.liste or {}) do if n[x.durum] then n[x.durum] = n[x.durum] + 1 end end
                              return { { "Etkin", n.ETKIN, N.Clr.ok }, { "Yayın bekleyen", n.BEKLIYOR, N.Clr.mana }, { "Tolerans", n.TOLERANS, N.Clr.warn } }
                         end
                         if r.deneme then return { { "Paket", r.kod }, { "Boyut", string.format("%.1f MB", (r.boyut or 0) / 1048576) }, { "Tarih", tarih(r.zaman) } } end
                         return {
                              { "Kod", r.kod }, { "Paket", (r.paket or "?") .. " MB" }, { "Durum", K.DURUM_YAZI[r.durum] or r.durum },
                              { "SteamID", r.sid64 and util.SteamIDFrom64(r.sid64) or "—" }, { "Discord", r.discordId or "—" },
                              { "Karakter", r.karakterAd or "—" }, { "Başlangıç", tarih(r.baslangic) }, { "Bitiş", tarih(r.bitis) },
                         }
                    end,
               })

               return function() K.Iste(OP.YONETIM) end
          end,
     })
     return true
end

-- sardon_kira, sardon_shineadmin'den önce yükleniyor (alfabetik); ShineAdmin gelene kadar dene
if not SayfaKaydet() then
     timer.Create("SardonKira.Sayfa", 1, 120, function()
          if SayfaKaydet() then timer.Remove("SardonKira.Sayfa") end
     end)
end
