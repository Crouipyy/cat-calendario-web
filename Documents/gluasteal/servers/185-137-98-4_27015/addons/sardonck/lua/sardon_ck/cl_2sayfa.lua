-- "addons\\sardonck\\lua\\sardon_ck\\cl_2sayfa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon CK :: Shine Admin "CK Onayları" sayfası. Taraflardan biri onay
-- vermeyen (ya da süresi dolan) CK istekleri burada yetkili kararını bekler.

SardonCK.Liste = SardonCK.Liste or {}

local function Tarih(t)
     return t and os.date("%d.%m.%Y %H:%M", t) or "—"
end

local function DurumRengi(N, durum)
     if (durum == "yetkili") then return N.Clr.warn end
     if (durum == "soruluyor") then return N.Clr.mana end
     if (durum == "ck") then return N.Clr.bad end
     return N.Clr.ok
end

local function CevapRengi(N, v)
     if (v == true) then return N.Clr.ok end
     if (v == false) then return N.Clr.bad end
     return N.Clr.faint
end

local function SayfaKaydet()
     if (!ShineAdmin or !ShineAdmin.RegisterPage) then return false end

     ShineAdmin:RegisterPage("ck", {
          label = "Aprobaciones CK",
          icon = "lock",
          group = "players",
          order = 33,
          title = "Aprobaciones CK",
          subtitle = "Solicitudes de CK que pasan a staff porque una de las partes no aprobó. El personaje sigue vivo hasta la aprobación.",
          access = "staff",
          rail = true,
          available = function() return SardonCK and SardonCK.Durum end,

          build = function(ctx)
               local N = ShineAdmin.GetN()
               local u = N.u
               local P = ctx.panel
               local W, H = ctx.w, ctx.h

               local sekme = "bekleyen"
               local sel
               local list

               local function satirlar()
                    local out = {}

                    for _, r in ipairs(SardonCK.Liste) do
                         local bekliyor = r.durum == "yetkili" or r.durum == "soruluyor"
                         if ((sekme == "bekleyen") == bekliyor) then out[#out + 1] = r end
                    end

                    return out
               end

               local function secili()
                    for _, r in ipairs(SardonCK.Liste) do
                         if (r.id == sel) then return r end
                    end
               end

               local function yenile()
                    if (IsValid(list)) then list:SetItems(satirlar(), true) end
               end

               N.SubTabs(P, 0, 0, u(W), {
                    {"bekleyen", "Bekleyen"},
                    {"gecmis", "Geçmiş"}
               }, function() return sekme end, function(id)
                    sekme = id
                    sel = nil
                    yenile()
               end)

               local head = vgui.Create("DPanel", P)
               head:SetPos(0, u(54))
               head:SetSize(u(W), u(30))
               head.Paint = function(s, w, h)
                    N.TableHead(0, 0, w, {
                         {"Kurban", u(16)},
                         {"Katil", w * 0.36},
                         {"Büyü", w * 0.62},
                         {"Tarih", w - u(24), TEXT_ALIGN_RIGHT}
                    })
               end

               list = N.VList(P, 0, u(84), u(W), u(H - 84 - 64), {
                    rowH = u(46),
                    gapY = 0,
                    emptyText = "Onay bekleyen CK isteği yok.",
                    onClick = function(r) sel = r.id end,
                    paintRow = function(r, i, x, y, w, h, hovered)
                         local on = sel == r.id

                         if (on) then
                              N.Box(x, y, w, h, N.Clr.selRow)
                              N.Box(x, y, u(2), h, N.Clr.gold)
                         elseif (hovered) then
                              N.Box(x, y, w, h, N.Clr.hoverRow)
                         end

                         N.Box(x, y + h - 1, w, 1, N.Clr.tableLine)

                         local ust, alt = y + h / 2 - u(8), y + h / 2 + u(9)

                         N.Text(N.Clip(r.kurbanAd or "?", "row", w * 0.36 - u(32)), "row", x + u(16), ust, on and N.Clr.text or N.Clr.tdFirst, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(SardonCK.CevapYazi(r.kurbanCevap), "tiny", x + u(16), alt, CevapRengi(N, r.kurbanCevap), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                         N.Text(N.Clip(r.katilAd or "?", "row", w * 0.26 - u(16)), "row", x + w * 0.36, ust, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(SardonCK.CevapYazi(r.katilCevap), "tiny", x + w * 0.36, alt, CevapRengi(N, r.katilCevap), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                         N.Text(N.Clip(r.buyu or "?", "row", w * 0.2), "row", x + w * 0.62, ust, N.Clr.tdText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                         N.Text(SardonCK.Durum[r.durum] or r.durum, "tiny", x + w * 0.62, alt, DurumRengi(N, r.durum), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                         N.Text(Tarih(r.zaman), "tiny", x + w - u(24), y + h / 2, N.Clr.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
               })

               local bar = N.StickyBar(P, 0, u(H - 56), u(W), function()
                    local r = secili()
                    if (!r) then return "Listeden bir istek seç." end
                    if (r.durum == "soruluyor") then return "Taraflara hâlâ soruluyor; süre dolunca ya da biri reddedince karar sana kalır.", N.Clr.mana end
                    if (r.durum != "yetkili") then return "Bu istek karara bağlandı." end
                    return "Onaylarsan " .. (r.kurbanAd or "?") .. " karakteri kalıcı olarak kapanır.", N.Clr.warn
               end)

               local function karar(onay)
                    local r = secili()
                    if (!r or r.durum != "yetkili") then return end

                    net.Start("SardonCK.Karar")
                         net.WriteUInt(r.id, 32)
                         net.WriteBool(onay)
                    net.SendToServer()

                    ctx.Flash((r.kurbanAd or "?") .. (onay and " için CK onayı gönderildi." or " için CK isteği reddedildi."), onay and "bad" or nil)
               end

               local onayla = N.Button(bar, u(W) - u(190), u(9), u(190), u(36), "CK'yı onayla", function()
                    local r = secili()
                    if (!r) then return end

                    N.Confirm("CK'yı onayla", (r.kurbanAd or "?") .. " karakteri kalıcı olarak kapatılır (Helix karakter yasağı). Oyundaysa karakter menüsüne atılır.", "CK uygula", function()
                         karar(true)
                    end, true)
               end, "danger")
               onayla.Think = function(s)
                    local r = secili()
                    s:SetEnabled(r != nil and r.durum == "yetkili")
               end

               local reddet = N.Button(bar, u(W) - u(190) - u(150), u(9), u(140), u(36), "Reddet", function()
                    karar(false)
               end, "ghost")
               reddet.Think = onayla.Think

               ctx.SetRail({
                    hero = "icons/lock",
                    badge = {text = "Kalıcı ölüm", icon = "lock", color = N.Clr.bad},
                    title = function()
                         local r = secili()
                         return r and (r.kurbanAd or "?") or "İstek seç"
                    end,
                    body = function()
                         local r = secili()
                         if (!r) then
                              return "CK büyüsüyle (Avada Kedavra, Fulgur Merlin) ölen karakterin CK'sı iki tarafın onayını ister. Biri onaylamazsa ya da 90 sn içinde cevap gelmezse istek buraya düşer."
                         end

                         return (r.katilAd or "?") .. ", " .. (r.kurbanAd or "?") .. " adlı karakteri " .. (r.buyu or "?") .. " ile öldürdü."
                    end,
                    props = function()
                         local r = secili()
                         if (!r) then
                              local n = 0
                              for _, x in ipairs(SardonCK.Liste) do if (x.durum == "yetkili") then n = n + 1 end end
                              return {{"Onay bekleyen", n, N.Clr.warn}}
                         end

                         local t = {
                              {"Durum", SardonCK.Durum[r.durum] or r.durum, DurumRengi(N, r.durum)},
                              {"Kurban", SardonCK.CevapYazi(r.kurbanCevap), CevapRengi(N, r.kurbanCevap)},
                              {"Katil", SardonCK.CevapYazi(r.katilCevap), CevapRengi(N, r.katilCevap)},
                              {"Kurban SteamID", r.kurbanSid != "" and util.SteamIDFrom64(r.kurbanSid) or "—"},
                              {"Katil SteamID", r.katilSid != "" and util.SteamIDFrom64(r.katilSid) or "—"},
                              {"Karakter no", r.kurbanChar or "—"},
                              {"Tarih", Tarih(r.zaman)}
                         }

                         if (r.yetkili and r.yetkili != "") then
                              t[#t + 1] = {"Karar veren", r.yetkili}
                              t[#t + 1] = {"Karar tarihi", Tarih(r.kararZaman)}
                         end

                         return t
                    end
               })

               ctx.SetHead({count = function()
                    local n = 0
                    for _, x in ipairs(SardonCK.Liste) do if (x.durum == "yetkili") then n = n + 1 end end
                    return n
               end, note = "BEKLEYEN"})

               ctx.Yenile = yenile

               yenile()

               net.Start("SardonCK.ListeIste")
               net.SendToServer()
          end
     })

     return true
end

-- sardon_ck, sardon_shineadmin'den önce yükleniyor (alfabetik); ShineAdmin gelene kadar dene
if (!SayfaKaydet()) then
     timer.Create("SardonCK.Sayfa", 1, 120, function()
          if (SayfaKaydet()) then timer.Remove("SardonCK.Sayfa") end
     end)
end

net.Receive("SardonCK.Liste", function()
     SardonCK.Liste = net.ReadTable() or {}

     local ctx = ShineAdmin and ShineAdmin.ActiveCtx and ShineAdmin:ActiveCtx("ck")
     if (ctx and ctx.Yenile) then ctx.Yenile() end
end)
