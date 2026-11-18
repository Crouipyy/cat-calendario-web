-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_9a_kit.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Editör kiti: temalı kontroller, şemadan form, açılır form penceresi, seçiciler.
*   Form alanları _sh_2sema.lua'daki tiplerden üretilir; bağlam (ctx) misión tanımını taşır
*   (actor / paso / yer listeleri ve animasyon seçici için model).
*/
local G = SardonGorev
local R, O, F = G.R, G.O, G.F

G.K = G.K or {}
local K = G.K

/*
*   Temel kontroller
*/
function K.Dugme(parent, metin, fn, tur)
     local b = vgui.Create("DButton", parent)
     b:SetText("")
     b.metin = metin
     b.tur = tur
     b.Paint = function(s, w, h)
          local ust = s:IsHovered() and s:IsEnabled()
          local bg = (s.tur == "ana" and Color(64, 54, 32, ust and 255 or 225)) or (s.tur == "tehlike" and Color(70, 26, 24, ust and 250 or 200)) or Color(16, 24, 20, ust and 245 or 210)
          G.Kutu(0, 0, w, h, bg)
          G.Cerceve(0, 0, w, h, (ust or s.tur == "ana") and R.altin or R.cizgi)
          local renk = s:IsEnabled() and ((s.tur == "ana" and R.altinAcik) or (s.tur == "tehlike" and Color(240, 170, 160)) or R.fildisi) or R.soluk
          G.Yaz(isfunction(s.metin) and s.metin() or s.metin, F(13, "kalin"), w / 2, h / 2, renk, 1)
     end
     b.DoClick = function(s) G.Cal("tik") if fn then fn(s) end end
     return b
end

function K.Giris(parent, deger, cok, fn)
     local e = vgui.Create("DTextEntry", parent)
     e:SetMultiline(cok and true or false)
     e:SetAllowNonAsciiCharacters(true)
     e:SetFont(F(14, "govde"))
     e:SetText(tostring(deger or ""))
     e:SetUpdateOnType(true)
     e:SetPaintBackground(false)
     e:SetTextColor(R.fildisi)
     e:SetCursorColor(R.altinAcik)
     e:SetHighlightColor(Color(190, 162, 104, 90))
     e.Paint = function(s, w, h)
          G.Kutu(0, 0, w, h, Color(7, 11, 9, 235))
          G.Cerceve(0, 0, w, h, s:HasFocus() and R.altin or G.Renk(R.cizgi, 160))
          s:DrawTextEntryText(R.fildisi, Color(190, 162, 104, 90), R.altinAcik)
     end
     e.OnChange = function(s) if fn then fn(s:GetValue()) end end
     return e
end

function K.Secim(parent, secenekler, deger, fn)
     local c = vgui.Create("DComboBox", parent)
     c:SetFont(F(14, "govde"))
     c:SetTextColor(R.fildisi)
     c:SetSortItems(false)
     local bulundu = false
     for _, s in ipairs(secenekler) do
          local id, ad = s.id, s.ad
          if id == nil then id, ad = s, s end
          c:AddChoice(ad, id, id == deger)
          if id == deger then bulundu = true end
     end
     if not bulundu and deger ~= nil and deger ~= "" then c:AddChoice(tostring(deger) .. " (?)", deger, true) end
     c.Paint = function(s, w, h)
          G.Kutu(0, 0, w, h, Color(7, 11, 9, 235))
          G.Cerceve(0, 0, w, h, s:IsHovered() and R.altin or G.Renk(R.cizgi, 160))
     end
     c.OnSelect = function(_, _, _, veri) if fn then fn(veri) end end
     local eskiAc = c.OpenMenu
     c.OpenMenu = function(s, ...)
          eskiAc(s, ...)
          if IsValid(s.Menu) then
               s.Menu.Paint = function(_, w, h) G.Kutu(0, 0, w, h, Color(11, 19, 17, 250)) G.Cerceve(0, 0, w, h, R.cizgi) end
               for _, o in ipairs(s.Menu:GetCanvas():GetChildren()) do
                    if o.SetTextColor then o:SetTextColor(R.fildisi) end
                    if o.SetFont then o:SetFont(F(13, "govde")) end
               end
          end
     end
     return c
end

function K.Onay(parent, deger, fn)
     local b = vgui.Create("DButton", parent)
     b:SetText("")
     b.deger = deger and true or false
     b.Paint = function(s, w, h)
          local bx = h
          G.Kutu(0, 0, bx, h, Color(7, 11, 9, 235))
          G.Cerceve(0, 0, bx, h, s:IsHovered() and R.altin or G.Renk(R.cizgi, 160))
          if s.deger then G.Baklava(bx / 2, h / 2, h * 0.28, R.altinAcik) end
          G.Yaz(s.deger and "Sí" or "No", F(13, "govde"), bx + O(8), h / 2, s.deger and R.fildisi or R.soluk)
     end
     b.DoClick = function(s)
          s.deger = not s.deger
          G.Cal("tik")
          if fn then fn(s.deger) end
     end
     return b
end

function K.Etiket(parent, metin, renk, font)
     local l = vgui.Create("DLabel", parent)
     l:SetFont(font or F(13, "kalin"))
     l:SetTextColor(renk or R.soluk)
     l:SetText(metin or "")
     return l
end

local function KaydirmaCubugu(s)
     local bar = s:GetVBar()
     bar:SetWide(O(5))
     bar:SetHideButtons(true)
     bar.Paint = function() end
     bar.btnGrip.Paint = function(_, w, h) G.Kutu(0, 0, w, h, G.Renk(R.altin, 110)) end
end

function K.Kaydir(parent)
     local s = vgui.Create("DScrollPanel", parent)
     KaydirmaCubugu(s)
     return s
end

/*
*   Açılır pencere
*/
function K.Pencere(baslik, w, h)
     local p = vgui.Create("EditablePanel")
     p:SetSize(math.min(w, ScrW() - O(40)), math.min(h, ScrH() - O(40)))
     p:Center()
     p:MakePopup()
     p:SetKeyboardInputEnabled(true)
     p.baslik = baslik
     p.Paint = function(s, pw, ph)
          G.Pano(0, 0, pw, ph, 1, Color(11, 19, 17, 250))
          G.Yaz(s.baslik or "", F(18, "baslik"), O(20), O(24), R.fildisiAcik)
          G.AltinCizgi(O(20), O(44), pw - O(40), 140)
     end
     local kapat = K.Dugme(p, "✕", function() p:Remove() end)
     kapat:SetSize(O(30), O(26))
     kapat:SetPos(p:GetWide() - O(42), O(10))
     p.govde = vgui.Create("EditablePanel", p)
     p.govde:SetPos(O(16), O(54))
     p.govde:SetSize(p:GetWide() - O(32), p:GetTall() - O(54) - O(60))
     p.Think = function(s)
          if input.IsKeyDown(KEY_ESCAPE) and s:HasHierarchicalFocus() then s:Remove() end
     end
     -- editör penceresi öne gelince bunlar arkada kalmasın
     timer.Simple(0, function() if IsValid(p) then p:MoveToFront() end end)
     return p
end

-- Arama listesi: ogeler = { { ad, alt, deger } }, sec(deger)
function K.AramaListesi(baslik, ogeler, sec, onizle)
     local p = K.Pencere(baslik, O(560), O(640))
     local ara = K.Giris(p.govde, "", false)
     ara:Dock(TOP)
     ara:SetTall(O(30))
     ara:SetPlaceholderText("Ara…")
     local liste = K.Kaydir(p.govde)
     liste:Dock(FILL)
     liste:DockMargin(0, O(8), 0, 0)

     local function Doldur(filtre)
          liste:Clear()
          filtre = G.Kucuk(filtre or "")
          local n = 0
          for _, o in ipairs(ogeler) do
               if filtre == "" or string.find(G.Kucuk(o.ad .. " " .. (o.alt or "")), filtre, 1, true) then
                    n = n + 1
                    if n > 400 then break end
                    local b = liste:Add("DButton")
                    b:Dock(TOP)
                    b:SetTall(O(36))
                    b:DockMargin(0, 0, O(6), O(3))
                    b:SetText("")
                    b.Paint = function(s, w, h)
                         G.Kutu(0, 0, w, h, Color(16, 24, 20, s:IsHovered() and 250 or 200))
                         G.Yaz(o.ad, F(14, "kalin"), O(10), O(12), R.fildisi)
                         if o.alt then G.Yaz(o.alt, F(11, "govde"), O(10), O(27), R.soluk) end
                    end
                    b.DoClick = function()
                         sec(o.deger)
                         p:Remove()
                    end
                    if onizle then
                         b.DoRightClick = function() onizle(o.deger) end
                    end
               end
          end
     end
     ara.OnChange = function(s) Doldur(s:GetValue()) end
     Doldur("")
     if onizle then
          local ipucu = K.Etiket(p, "Clic der.: vista previa", R.soluk, F(12, "govde"))
          ipucu:SetPos(O(20), p:GetTall() - O(40))
          ipucu:SizeToContents()
     end
     ara:RequestFocus()
     return p
end

/*
*   Seçiciler
*/
function K.EsyaSec(sec)
     local ogeler = {}
     for id, it in pairs(ix and ix.item and ix.item.list or {}) do
          if not it.isBase then ogeler[#ogeler + 1] = { ad = it.name or id, alt = id .. (it.category and ("  ·  " .. it.category) or ""), deger = id } end
     end
     table.sort(ogeler, function(a, b) return a.ad < b.ad end)
     K.AramaListesi("Elegir objeto", ogeler, sec)
end

function K.BuyuSec(sec)
     local ogeler = {}
     local liste = HpwRewrite and HpwRewrite.GetSpells and HpwRewrite:GetSpells() or {}
     for ad in pairs(liste) do ogeler[#ogeler + 1] = { ad = ad, deger = ad } end
     table.sort(ogeler, function(a, b) return a.ad < b.ad end)
     K.AramaListesi("Elegir hechizo / varita", ogeler, sec)
end

function K.ModelSec(sec)
     local ogeler, gorulen = {}, {}
     local function Ekle(m, alt)
          if not m or m == "" or gorulen[m] then return end
          gorulen[m] = true
          ogeler[#ogeler + 1] = { ad = string.GetFileFromFilename(m), alt = m .. (alt and ("  ·  " .. alt) or ""), deger = m }
     end
     for _, p in ipairs(player.GetAll()) do Ekle(p:GetModel(), "jugador: " .. p:Nick()) end
     for _, c in pairs(G.Aktorler or {}) do Ekle(c.veri and c.veri.model, "actor") end
     for ad, m in SortedPairs(player_manager.AllValidModels()) do Ekle(m, ad) end
     K.AramaListesi("Elegir modelo", ogeler, sec)
end

function K.AnimSec(model, sec)
     model = (isstring(model) and file.Exists(model, "GAME")) and model or "models/player/group01/male_07.mdl"
     local ent = ClientsideModel(model, RENDERGROUP_OTHER)
     local ogeler = {}
     if IsValid(ent) then
          for _, ad in pairs(ent:GetSequenceList() or {}) do ogeler[#ogeler + 1] = { ad = ad, deger = ad } end
          ent:Remove()
     end
     table.sort(ogeler, function(a, b) return a.ad < b.ad end)
     K.AramaListesi("Animasyon seç · " .. string.GetFileFromFilename(model), ogeler, sec)
end

G.SesListe = G.SesListe or {}

function K.SesSec(sec)
     local ogeler = {}
     for _, s in ipairs(G.SesListe) do
          ogeler[#ogeler + 1] = { ad = s.yol, alt = string.format("%.1f sn  ·  %d KB", s.sure or 0, math.ceil((s.boyut or 0) / 1024)), deger = s.yol }
     end
     if #ogeler == 0 then
          ogeler[1] = { ad = "(no hay archivo de sonido en el servidor)", alt = "coloca mp3/ogg/wav en garrysmod/data/sardon_gorev/sesler/", deger = "" }
     end
     K.AramaListesi("Elegir archivo de sonido", ogeler, sec, function(yol) if yol ~= "" then G.SesOnizle(yol) end end)
end

/*
*   Form
*   ctx: { def = misión tanımı, model = animasyon seçici modeli, yenile = fn }
*/
local SATIR_H = 30

local function YerSecenekleri(filtre)
     local liste = { { id = "", ad = "— yok —" }, { id = "@jugador", ad = "@jugador (jugadornun yeri)" }, { id = "@jugador_on", ad = "@jugador_on (jugadornun önü)" },
          { id = "@jugador_yakin", ad = "@jugador_yakin (jugadornun görebileceği 4-12 m)" }, { id = "@karsilasma", ad = "@karsilasma (karşılaşma yeri)" } }
     for ad, y in SortedPairs(G.E and G.E.yerler or {}) do
          if not filtre or y.tur == filtre or (filtre == "nokta" and y.tur ~= "kamera") then
               liste[#liste + 1] = { id = ad, ad = ad .. "  ·  " .. (y.tur or "nokta") }
          end
     end
     return liste
end

local function AktorSecenekleri(ctx, ekler)
     local liste = { { id = "", ad = "— yok —" } }
     for _, e in ipairs(ekler or {}) do liste[#liste + 1] = e end
     for _, a in ipairs(ctx.def and ctx.def.aktorler or {}) do liste[#liste + 1] = { id = a.id, ad = a.id .. "  ·  " .. (a.ad or "") } end
     for _, d in ipairs(G.E and G.E.dunya or {}) do
          if d.id and d.id ~= "" then liste[#liste + 1] = { id = d.id, ad = d.id .. "  ·  " .. (d.ad or "") .. "  (dünya)" } end
     end
     return liste
end

local function AdimSecenekleri(ctx)
     local liste = { { id = "", ad = "— (sıradaki paso) —" }, { id = "_bitir", ad = "◆ Misióni bitir (başarılı)" }, { id = "_basarisiz", ad = "◆ Misióni bitir (başarısız)" } }
     for i, a in ipairs(ctx.def and ctx.def.adimlar or {}) do liste[#liste + 1] = { id = a.id, ad = i .. ". " .. a.id .. "  ·  " .. (a.ad or "") } end
     return liste
end

local function GorevSecenekleri()
     local liste = { { id = "", ad = "— yok —" } }
     for _, g in ipairs(G.E and G.E.liste or {}) do liste[#liste + 1] = { id = g.id, ad = g.id .. "  ·  " .. (g.ad or "") } end
     return liste
end

-- Satırın sağına küçük düğme
local function Yan(parent, metin, fn, w)
     local b = K.Dugme(parent, metin, fn)
     b:Dock(RIGHT)
     b:SetWide(w or O(70))
     b:DockMargin(O(4), 0, 0, 0)
     return b
end

function K.Form(parent, alanlar, veri, ctx, degisti)
     ctx = ctx or {}
     local kok = vgui.Create("EditablePanel", parent)
     kok:Dock(TOP)
     kok.Paint = function() end

     local function Kur()
          kok:Clear()
          local toplam = 0
          for _, a in ipairs(alanlar) do
               if not a.goster or a.goster(veri) then
                    local satir = vgui.Create("EditablePanel", kok)
                    satir:Dock(TOP)
                    satir:DockMargin(0, 0, 0, O(6))
                    local h = O(SATIR_H)
                    if a.tip == "yazi" then h = O(78) end

                    local etiket = K.Etiket(satir, a.ad, R.govde, F(13, "kalin"))
                    etiket:Dock(LEFT)
                    etiket:SetWide(O(190))
                    etiket:SetContentAlignment(4)
                    if a.ipucu then etiket:SetTooltip(a.ipucu) end

                    local function Ayarla(v)
                         veri[a.k] = v
                         if degisti then degisti(a.k, v) end
                         -- görünürlüğü bu alana bağlı alan varsa yeniden kur
                         for _, b in ipairs(alanlar) do
                              if b.goster then timer.Simple(0, function() if IsValid(kok) then Kur() end end) break end
                         end
                    end

                    local t = a.tip
                    if t == "metin" or t == "sinif" then
                         local e = K.Giris(satir, veri[a.k], false, function(v) veri[a.k] = v if degisti then degisti(a.k, v) end end)
                         e:Dock(FILL)
                    elseif t == "yazi" then
                         local e = K.Giris(satir, veri[a.k], true, function(v) veri[a.k] = v if degisti then degisti(a.k, v) end end)
                         e:Dock(FILL)
                    elseif t == "sayi" then
                         local e = K.Giris(satir, veri[a.k] ~= nil and veri[a.k] or a.v, false, function(v)
                              local n = tonumber(v)
                              if n then
                                   if a.min then n = math.max(a.min, n) end
                                   if a.max then n = math.min(a.max, n) end
                                   veri[a.k] = n
                                   if degisti then degisti(a.k, n) end
                              end
                         end)
                         e:Dock(LEFT)
                         e:SetWide(O(120))
                         if a.min or a.max then
                              local l = K.Etiket(satir, (a.min or "") .. " … " .. (a.max or ""), R.soluk, F(11, "govde"))
                              l:Dock(LEFT)
                              l:DockMargin(O(8), 0, 0, 0)
                              l:SetWide(O(140))
                         end
                    elseif t == "bool" then
                         local b = K.Onay(satir, veri[a.k], function(v) Ayarla(v) end)
                         b:Dock(LEFT)
                         b:SetWide(O(120))
                    elseif t == "secim" then
                         local c = K.Secim(satir, a.secenekler or {}, veri[a.k], function(v) Ayarla(v) end)
                         c:Dock(FILL)
                    elseif t == "yer" then
                         Yan(satir, "Mostrar", function()
                              local y = G.E and G.E.yerler[veri[a.k] or ""]
                              if y and G.YerVurgula then G.YerVurgula(veri[a.k]) end
                         end)
                         Yan(satir, "Yeni…", function()
                              if G.YerYeniAkisi then
                                   G.YerYeniAkisi(nil, function(ad)
                                        Ayarla(ad)
                                        if IsValid(kok) then Kur() end
                                   end)
                              end
                         end)
                         local c = K.Secim(satir, YerSecenekleri(a.yerTur), veri[a.k], function(v) Ayarla(v) end)
                         c:Dock(FILL)
                    elseif t == "aktor" then
                         local c = K.Secim(satir, AktorSecenekleri(ctx), veri[a.k], function(v) Ayarla(v) end)
                         c:Dock(FILL)
                    elseif t == "konusan" then
                         local c = K.Secim(satir, AktorSecenekleri(ctx, { { id = "oyuncu", ad = "Jugador" }, { id = "anlatici", ad = "Narrador" } }), veri[a.k], function(v) Ayarla(v) end)
                         c:Dock(FILL)
                    elseif t == "adim" then
                         local c = K.Secim(satir, AdimSecenekleri(ctx), veri[a.k], function(v) Ayarla(v) end)
                         c:Dock(FILL)
                    elseif t == "gorev" then
                         local c = K.Secim(satir, GorevSecenekleri(), veri[a.k], function(v) Ayarla(v) end)
                         c:Dock(FILL)
                    elseif t == "esya" or t == "buyu" or t == "model" or t == "anim" or t == "ses" then
                         local e
                         if t == "ses" then
                              Yan(satir, "▶", function() if (veri[a.k] or "") ~= "" then G.SesOnizle(veri[a.k]) end end, O(34))
                         end
                         Yan(satir, "Elegir…", function()
                              local function Sec(v)
                                   veri[a.k] = v
                                   if IsValid(e) then e:SetText(v) end
                                   if degisti then degisti(a.k, v) end
                              end
                              if t == "esya" then K.EsyaSec(Sec)
                              elseif t == "buyu" then K.BuyuSec(Sec)
                              elseif t == "model" then K.ModelSec(Sec)
                              elseif t == "anim" then
                                   local model = ctx.model or veri.model
                                   local aid = veri.aktor ~= "" and veri.aktor or veri.kim
                                   if not model and ctx.def then
                                        for _, ak in ipairs(ctx.def.aktorler or {}) do
                                             if ak.id == aid or (not aid or aid == "") then model = ak.model break end
                                        end
                                   end
                                   K.AnimSec(model, Sec)
                              else
                                   if #G.SesListe == 0 and G.EditorIste then G.EditorIste("sesler") end
                                   K.SesSec(Sec)
                              end
                         end)
                         e = K.Giris(satir, veri[a.k], false, function(v) veri[a.k] = v if degisti then degisti(a.k, v) end end)
                         e:Dock(FILL)
                         if t == "esya" then
                              e.PaintOver = function(s, w, h)
                                   local it = ix and ix.item and ix.item.list[s:GetValue()]
                                   if it then G.Yaz(it.name or "", F(12, "italik"), w - O(8), h / 2, R.soluk, 2) end
                              end
                         end
                    elseif t == "renk" then
                         local b = vgui.Create("DButton", satir)
                         b:SetText("")
                         b:Dock(LEFT)
                         b:SetWide(O(120))
                         b.Paint = function(s, w, h)
                              local r = veri[a.k] or a.v or { 255, 255, 255 }
                              G.Kutu(0, 0, w, h, Color(r[1] or r.r or 255, r[2] or r.g or 255, r[3] or r.b or 255))
                              G.Cerceve(0, 0, w, h, s:IsHovered() and R.altin or R.cizgi)
                         end
                         b.DoClick = function()
                              local p = K.Pencere(a.ad, O(360), O(380))
                              local m = vgui.Create("DColorMixer", p.govde)
                              m:Dock(FILL)
                              m:SetAlphaBar(false)
                              local r = veri[a.k] or a.v or { 255, 255, 255 }
                              m:SetColor(Color(r[1] or 255, r[2] or 255, r[3] or 255))
                              m.ValueChanged = function(_, c) veri[a.k] = { c.r, c.g, c.b } if degisti then degisti(a.k, veri[a.k]) end end
                         end
                    elseif t == "liste" or t == "kosullar" or t == "oduller" then
                         h = K.ListeAlani(satir, a, veri, ctx, degisti)
                         etiket:SetContentAlignment(7)
                    elseif t == "sahne" then
                         Yan(satir, "Temizle", function() Ayarla({}) if IsValid(kok) then Kur() end end)
                         Yan(satir, "Desde ruta de cine…", function()
                              if G.SinemaRotaSec then
                                   G.SinemaRotaSec(function(v)
                                        Ayarla(v)
                                        if IsValid(kok) then Kur() end
                                   end)
                              end
                         end, O(170))
                         local l = K.Etiket(satir, G.SemaOzet("Eylem", { t = "sahne", veri = veri[a.k] or {} }), R.fildisi, F(13, "govde"))
                         l:Dock(FILL)
                         l:DockMargin(O(6), 0, 0, 0)
                    else
                         local e = K.Giris(satir, util.TableToJSON(veri[a.k] or ""), false)
                         e:Dock(FILL)
                    end
                    satir:SetTall(h)
                    toplam = toplam + h + O(6)
               end
          end
          kok:SetTall(toplam)
          if ctx.yenile then ctx.yenile() end
     end

     Kur()
     kok.Kur = Kur
     return kok
end

/*
*   Liste alanı (iç içe guardarlar, koşullar, ödüller)
*/
local function SemaTur(a)
     if a.semaTur then return a.semaTur end
     if a.tip == "kosullar" then return "Kosul" end
     if a.tip == "oduller" then return "Odul" end
end

local function OgeOzet(a, o)
     local tur = SemaTur(a)
     if tur == "Eylem" or tur == "Hedef" then
          local sm = G.Sema[tur][o.t or ""]
          return (sm and sm.ad or tostring(o.t)) .. "  —  " .. G.SemaOzet(tur, o)
     end
     if tur then return G.SemaOzet(tur, o) end
     if a.ozet then
          local ok, r = pcall(a.ozet, o)
          if ok and r then return r end
     end
     return "guardar"
end

function K.OgeDuzenle(baslik, alanlar, o, ctx, bitti)
     local kopya = table.Copy(o)
     local p = K.Pencere(baslik, O(760), O(720))
     local kay = K.Kaydir(p.govde)
     kay:Dock(FILL)
     local form = K.Form(kay, alanlar, kopya, ctx)
     form:DockMargin(0, 0, O(10), 0)
     local tamam = K.Dugme(p, "Tamam", function()
          for k in pairs(o) do o[k] = nil end
          for k, v in pairs(kopya) do o[k] = v end
          p:Remove()
          if bitti then bitti() end
     end, "ana")
     tamam:SetSize(O(150), O(36))
     tamam:SetPos(p:GetWide() - O(166), p:GetTall() - O(50))
     local iptal = K.Dugme(p, "Cancelar", function() p:Remove() end)
     iptal:SetSize(O(120), O(36))
     iptal:SetPos(p:GetWide() - O(296), p:GetTall() - O(50))
     return p
end

-- Tür seçme menüsü (koşul / ödül / eylem / hedef)
function K.TurMenu(tur, sec, kategoriler)
     local m = DermaMenu()
     if kategoriler then
          for _, kat in ipairs(kategoriler) do
               local alt = m:AddSubMenu(kat.ad)
               for _, id in ipairs(G.SemaSira[tur]) do
                    local s = G.Sema[tur][id]
                    if s.kat == kat.id then alt:AddOption(s.ad, function() sec(id) end) end
               end
          end
     else
          for _, id in ipairs(G.SemaSira[tur]) do
               local s = G.Sema[tur][id]
               m:AddOption(s.ad, function() sec(id) end)
          end
     end
     m:Open()
end

function K.ListeAlani(parent, a, veri, ctx, degisti)
     veri[a.k] = istable(veri[a.k]) and veri[a.k] or {}
     local liste = veri[a.k]
     local tur = SemaTur(a)

     local kutu = vgui.Create("EditablePanel", parent)
     kutu:Dock(FILL)
     kutu.Paint = function(_, w, h) G.Kutu(0, 0, w, h, Color(7, 11, 9, 160)) G.Cerceve(0, 0, w, h, G.Renk(R.cizgi, 110)) end

     local function Yeniden()
          if IsValid(parent) and IsValid(parent:GetParent()) and parent:GetParent().Kur then parent:GetParent().Kur() end
          if degisti then degisti(a.k, liste) end
     end

     local y = O(4)
     for i, o in ipairs(liste) do
          local r = vgui.Create("EditablePanel", kutu)
          r:SetPos(O(4), y)
          r:SetSize(O(10), O(26))
          r.Paint = function(_, w, h)
               G.Kutu(0, 0, w, h, Color(16, 24, 20, 220))
               G.Yaz(i .. ".  " .. OgeOzet(a, o), F(13, "govde"), O(8), h / 2, R.fildisi)
          end
          kutu.satirlar = kutu.satirlar or {}
          kutu.satirlar[#kutu.satirlar + 1] = r
          local function D(m, f)
               local b = K.Dugme(r, m, f)
               b:Dock(RIGHT)
               b:SetWide(O(28))
               b:DockMargin(O(2), O(2), 0, O(2))
          end
          D("✕", function() table.remove(liste, i) Yeniden() end)
          D("⧉", function() table.insert(liste, i + 1, table.Copy(o)) Yeniden() end)
          D("↓", function() if i < #liste then liste[i], liste[i + 1] = liste[i + 1], liste[i] Yeniden() end end)
          D("↑", function() if i > 1 then liste[i], liste[i - 1] = liste[i - 1], liste[i] Yeniden() end end)
          D("✎", function()
               local alanlar = tur and G.Sema[tur][o.t] and G.Sema[tur][o.t].alanlar or a.alanlar or {}
               K.OgeDuzenle(a.ad .. " · " .. i, alanlar, o, ctx, Yeniden)
          end)
          y = y + O(30)
     end

     local ekle = K.Dugme(kutu, "+ Ekle", function()
          if tur then
               K.TurMenu(tur, function(id)
                    local yeni = G.SemaYeni(tur, id)
                    liste[#liste + 1] = yeni
                    K.OgeDuzenle(G.Sema[tur][id].ad, G.Sema[tur][id].alanlar, yeni, ctx, Yeniden)
                    Yeniden()
               end, a.kategoriler)
          else
               local yeni = {}
               for _, b in ipairs(a.alanlar or {}) do if b.v ~= nil then yeni[b.k] = istable(b.v) and table.Copy(b.v) or b.v end end
               liste[#liste + 1] = yeni
               K.OgeDuzenle(a.ad .. " · yeni", a.alanlar or {}, yeni, ctx, Yeniden)
               Yeniden()
          end
     end)
     ekle:SetPos(O(4), y)
     ekle:SetSize(O(90), O(24))
     y = y + O(30)

     kutu.PerformLayout = function(s, w)
          for _, r in ipairs(s.satirlar or {}) do r:SetWide(w - O(8)) end
     end
     return y + O(2)
end
