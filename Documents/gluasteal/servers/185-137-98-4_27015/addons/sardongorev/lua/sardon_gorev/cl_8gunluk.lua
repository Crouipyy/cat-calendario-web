-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_8gunluk.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Rehber: TAB menüsünde Helix'in "Rehber" (help) sekmesi ile eski "Görevler" sekmesinin birleşimi.
*   Üstte iki grup alt sekme, ikisi de aynı düzende (solda liste, sağda ayrıntı):
*     Görev Günlüğü : Süren / Günlük / Tamamlanan  (Takip et, Görevi bırak)
*     Rehber        : Komutlar / Bayraklar / Sistemler  (arama; komutta Sohbete yaz, Kopyala; Bayraklar ve Sistemler
*                     yalnız süperadmine görünür)
*   Başka eklentiler kendi grubuyla alt sekme ekler (SardonRehberSekmeleri kancası, aşağıda): içerik onların paneli.
*   M (TAB > Ayarlar > Tuş Atamaları) görevlerde açar; konsol: sardon_rehber [bölüm].
*   Sistemler listesi [sardon] helix cl_rehber_sistemler.lua'da (SardonRehber.Sistemler), yalnız süperadmin.
*   Sekme, [sardon] ui cl_menu.lua'nın SardonMenuSekmeleri kancasıyla Helix'in "help" anahtarına oturur.
*/
local G = SardonGorev
local R, O, F = G.R, G.O, G.F

-- { kimlik, ad, grup [, görünürlük] }
local TEMEL = {
     { "aktif", "En curso", "gorev" },
     { "gunluk", "Diario", "gorev" },
     { "bitti", "Completadas", "gorev" },
     { "komut", "Comandos", "rehber" },
     { "bayrak", "Banderas", "rehber", function() return LocalPlayer():IsSuperAdmin() end },
     { "sistem", "Sistemas", "rehber", function() return LocalPlayer():IsSuperAdmin() and SardonRehber ~= nil and SardonRehber.Sistemler ~= nil end },
}
local SEKMELER, SEKME = {}, {}
local BASLIK = { gorev = "Diario de misiones", rehber = "Guía" }

-- Dışarıdan alt sekme (yükleme sırasından bağımsız; panel her açılışta sorar):
--   hook.Add("SardonRehberSekmeleri", "Ad", function(ekle) ekle({ id = "…", ad = "…", grup = "…", baslik = "…", acik = fn, olustur = fn(ebeveyn) }) end)
-- olustur içerik panelini döndürür (sekme her seçildiğinde yeniden kurulur); grup kendi başlığıyla ayrı bir öbek olur.
local function SekmeleriTopla()
     table.Empty(SEKMELER)
     table.Empty(SEKME)
     for _, s in ipairs(TEMEL) do
          SEKMELER[#SEKMELER + 1] = s
          SEKME[s[1]] = s
     end
     -- kancadaki hata Rehber'i açılmaz yapmasın
     pcall(hook.Run, "SardonRehberSekmeleri", function(t)
          if not istable(t) or not isstring(t.id) or SEKME[t.id] or not isfunction(t.olustur) then return end
          local grup = "ek:" .. tostring(t.grup or t.id)
          local s = { t.id, tostring(t.ad or t.id), grup, isfunction(t.acik) and t.acik or nil, ozel = t }
          BASLIK[grup] = tostring(t.baslik or t.ad or t.id)
          SEKMELER[#SEKMELER + 1] = s
          SEKME[t.id] = s
     end)
end
SekmeleriTopla()
local ARAMALI = { komut = "Buscar comando…", sistem = "Buscar sistema o comando…" }

local ZEMIN = Color(11, 19, 17, 190)
local ZEMIN_UST = Color(11, 19, 17, 230)
local ZEMIN_SEC = Color(34, 46, 36, 235)
local CERCEVE = G.Renk(R.cizgi, 90)
local CERCEVE_SEC = G.Renk(R.altin, 160)
local ARA_ZEMIN = Color(7, 11, 9, 190)
local ARA_ODAK = Color(7, 11, 9, 240)

/*
*   Rehber verisi
*/
local TR = { ["ç"] = "c", ["ğ"] = "g", ["ı"] = "i", ["ö"] = "o", ["ş"] = "s", ["ü"] = "u", ["â"] = "a", ["î"] = "i", ["û"] = "u",
     ["Ç"] = "c", ["Ğ"] = "g", ["İ"] = "i", ["Ö"] = "o", ["Ş"] = "s", ["Ü"] = "u", ["Â"] = "a", ["Î"] = "i", ["Û"] = "u" }

-- Arama için: Türkçe harfler düz, küçük harf
local function Katla(s)
     return string.lower(string.gsub(tostring(s or ""), "[\195\196\197][\128-\191]", TR))
end

local VERI = {}

function VERI.komut()
     local lp = LocalPlayer()
     local out = {}
     for uid, k in SortedPairs(ix.command and ix.command.list or {}) do
          local erisim = not k.OnCheckAccess or k:OnCheckAccess(lp)
          -- takma adlar listede ayrı anahtar olarak da durur; asıl kaydın satırında gösterilir
          local takma, digerAd = false, {}
          if k.alias then
               for _, a in ipairs(istable(k.alias) and k.alias or { k.alias }) do
                    if string.lower(a) == uid then takma = true break end
                    digerAd[#digerAd + 1] = "/" .. a
               end
          end
          if erisim and not takma then
               local soz = k.syntax
               if soz == "" or soz == "[none]" then soz = nil end
               local aciklama = k.GetDescription and k:GetDescription() or k.description or ""
               out[#out + 1] = {
                    id = "komut:" .. uid, ad = "/" .. k.name, komut = k.name, soz = soz, aciklama = aciklama, digerAd = digerAd,
                    yetki = k.superAdminOnly and "superadmin" or (k.adminOnly and "staff" or nil),
                    araAd = Katla(k.name), ara = Katla(k.name .. " " .. table.concat(digerAd, " ") .. " " .. aciklama),
               }
          end
     end
     return out
end

function VERI.bayrak()
     local char = LocalPlayer():GetCharacter()
     local out = {}
     for harf, v in SortedPairs(ix.flag and ix.flag.list or {}) do
          out[#out + 1] = { id = "bayrak:" .. harf, harf = harf, aciklama = v.description or "", var = char and char:HasFlags(harf) or false }
     end
     return out
end

function VERI.sistem()
     local out = {}
     for _, kat in ipairs(SardonRehber and SardonRehber.Sistemler or {}) do
          out[#out + 1] = { baslik = kat[1] }
          for _, s in ipairs(kat[2] or {}) do
               out[#out + 1] = {
                    id = "sistem:" .. kat[1] .. "/" .. s[1], ad = s[1], aciklama = s[2] or "", komutlar = s[3], kategori = kat[1],
                    araAd = Katla(s[1]), ara = Katla(kat[1] .. " " .. s[1] .. " " .. (s[2] or "") .. " " .. table.concat(s[3] or {}, " ")),
               }
          end
     end
     return out
end

-- Her kelime geçmeli; komutlarda adı aramayla başlayanlar öne
local function Suz(liste, arama, sirala)
     local kelimeler = {}
     for k in string.gmatch(Katla(arama), "%S+") do
          k = string.gsub(k, "^/", "")
          if k ~= "" then kelimeler[#kelimeler + 1] = k end
     end
     if #kelimeler == 0 then return liste end

     local out, bas = {}, nil
     for _, o in ipairs(liste) do
          if o.baslik then
               bas = o
          else
               local uyar = true
               for _, k in ipairs(kelimeler) do
                    if not string.find(o.ara, k, 1, true) then uyar = false break end
               end
               if uyar then
                    if bas then out[#out + 1] = bas bas = nil end
                    out[#out + 1] = o
               end
          end
     end

     if sirala then
          local ilk = kelimeler[1]
          for _, o in ipairs(out) do
               local i = string.find(o.araAd, ilk, 1, true)
               o.puan = i == 1 and 0 or (i and 1 or 2)
          end
          table.sort(out, function(a, b)
               if a.puan ~= b.puan then return a.puan < b.puan end
               return a.araAd < b.araAd
          end)
     end
     return out
end

-- TAB menüsünü kapatıp sohbeti metinle açar (otomatik tamamlama önizlemesi de çıkar)
function G.SohbeteYaz(metin)
     if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
     timer.Simple(0.1, function()
          local sohbet = ix.gui.chat
          if not IsValid(sohbet) or not IsValid(sohbet.entry) then return end
          sohbet:SetActive(true)
          sohbet.entry:SetText(metin)
          sohbet.entry:SetCaretPos(utf8.len(metin) or #metin)
          sohbet.entry:RequestFocus()
          if sohbet.OnTextChanged then sohbet:OnTextChanged(metin) end
     end)
end

/*
*   Liste satırları
*/
local function SatirZemin(s, w, h, sec, renk)
     G.Kutu(0, 0, w, h, sec and ZEMIN_SEC or (s:IsHovered() and ZEMIN_UST or ZEMIN))
     if sec then G.Kutu(0, 0, O(3), h, renk) end
     G.Cerceve(0, 0, w, h, sec and CERCEVE_SEC or CERCEVE)
end

local SATIR = {}

function SATIR.gorev(s, w, h, g, sec)
     local renk = G.TurRenk(g.tur)
     SatirZemin(s, w, h, sec, renk)
     G.Baklava(O(18), O(20), O(4), renk, 255, not g.tamamlanan and not g.bittiGunluk)
     local ust = G.Buyuk(G.Tur(g.tur).kisa)
     if g.takip then ust = ust .. "  ·  EN SEGUIMIENTO" end
     if g.tamamlanan and (g.sayi or 0) > 1 then ust = ust .. "  ·  " .. g.sayi .. " VECES" end
     if g.bittiGunluk then ust = ust .. "  ·  HECHA HOY" end
     G.Yaz(ust, F(11, "kalin"), O(30), O(20), renk, 0, O(2))
     G.Yaz(G.Kisalt(g.ad or "", 34), F(17, "baslik"), O(16), O(42), sec and R.fildisiAcik or R.fildisi)
     local alt = g.adim or g.ozet or ""
     if g.tamamlanan and g.son then alt = os.date("%d.%m.%Y", g.son) end
     G.Yaz(G.Kisalt(alt, 46), F(12, "italik"), O(16), O(59), R.soluk)
end

function SATIR.komut(s, w, h, k, sec)
     SatirZemin(s, w, h, sec, R.altin)
     G.Yaz(G.Kisalt(k.ad, 26), F(16, "kalin"), O(16), O(20), sec and R.fildisiAcik or R.fildisi)
     if k.yetki then G.Yaz(G.Buyuk(k.yetki), F(10, "kalin"), w - O(14), O(20), R.pirinc, 2, O(2)) end
     G.Yaz(G.Kisalt(k.aciklama ~= "" and k.aciklama or (k.soz or ""), 46), F(12, "italik"), O(16), O(39), R.soluk)
end

function SATIR.bayrak(s, w, h, b, sec)
     local renk = b.var and R.yesil or R.soluk
     SatirZemin(s, w, h, sec, renk)
     G.Baklava(O(18), O(20), O(4), renk, 255, b.var)
     G.Yaz("[" .. b.harf .. "]", F(16, "kalin"), O(30), O(20), sec and R.fildisiAcik or R.fildisi)
     G.Yaz(b.var and "SÍ" or "NO", F(10, "kalin"), w - O(14), O(20), renk, 2, O(2))
     G.Yaz(G.Kisalt(b.aciklama, 46), F(12, "italik"), O(16), O(39), R.soluk)
end

function SATIR.sistem(s, w, h, o, sec)
     SatirZemin(s, w, h, sec, R.altin)
     G.Yaz(G.Kisalt(o.ad, 30), F(16, "baslik"), O(16), O(20), sec and R.fildisiAcik or R.fildisi)
     G.Yaz(G.Kisalt(o.aciklama, 46), F(12, "italik"), O(16), O(39), R.soluk)
end

/*
*   Rehber ayrıntıları (kaydırılan panelin içine çizilir; dönüş: içerik yüksekliği)
*/
local function Paragraf(metin, font, x, y, dw, renk, satir)
     for _, s in ipairs(G.Sar(metin, font, dw)) do
          G.Yaz(s, font, x, y, renk)
          y = y + satir
     end
     return y
end

local DETAY = {}

function DETAY.komut(k, x, y, dw)
     G.Baklava(x + O(5), y, O(5), R.altin)
     G.Yaz("COMANDO DE CHAT" .. (k.yetki and ("  ·  " .. G.Buyuk(k.yetki)) or ""), F(13, "kalin"), x + O(18), y, R.altin, 0, O(3))
     y = y + O(38)
     G.Yaz(k.ad, F(30, "kalin"), x, y, R.fildisiAcik)
     y = y + O(30)
     G.AltinCizgi(x, y, math.min(dw, O(700)), 180)
     y = y + O(30)

     G.Yaz("USO", F(12, "kalin"), x, y, R.altin, 0, O(3))
     y = Paragraf(k.ad .. (k.soz and (" " .. k.soz) or ""), F(18, "serif"), x, y + O(26), dw, R.fildisi, O(26)) + O(10)

     if k.aciklama ~= "" then
          y = Paragraf(k.aciklama, F(16, "govde"), x, y, dw, R.govde, O(22)) + O(14)
     end
     if #k.digerAd > 0 then
          G.Yaz("OTROS NOMBRES", F(12, "kalin"), x, y, R.altin, 0, O(3))
          y = Paragraf(table.concat(k.digerAd, "   ◆   "), F(15, "kalin"), x, y + O(24), dw, R.fildisi, O(22)) + O(10)
     end
     if k.soz then
          y = Paragraf(L("helpCommands"), F(13, "italik"), x, y + O(6), dw, R.soluk, O(18))
     end
     return y
end

function DETAY.bayrak(b, x, y, dw)
     local renk = b.var and R.yesil or R.altin
     G.Baklava(x + O(5), y, O(5), renk, 255, b.var)
     G.Yaz("BANDERA DE PERMISO", F(13, "kalin"), x + O(18), y, renk, 0, O(3))
     y = y + O(38)
     G.Yaz("[" .. b.harf .. "]", F(30, "kalin"), x, y, R.fildisiAcik)
     y = y + O(30)
     G.AltinCizgi(x, y, math.min(dw, O(700)), 180, renk)
     y = y + O(26)
     y = Paragraf(b.aciklama, F(18, "italik"), x, y, dw, R.fildisi, O(24)) + O(12)
     G.Yaz(b.var and "Este personaje la tiene." or "Este personaje no la tiene.", F(15, "kalin"), x, y, b.var and R.yesil or R.soluk)
     return y + O(10)
end

function DETAY.sistem(o, x, y, dw)
     G.Baklava(x + O(5), y, O(5), R.altin)
     G.Yaz(G.Buyuk(o.kategori), F(13, "kalin"), x + O(18), y, R.altin, 0, O(3))
     y = y + O(38)
     y = Paragraf(o.ad, F(32, "baslik"), x, y, dw, R.fildisiAcik, O(36)) - O(6)
     G.AltinCizgi(x, y, math.min(dw, O(700)), 180)
     y = y + O(26)
     if o.aciklama ~= "" then
          y = Paragraf(o.aciklama, F(16, "govde"), x, y, dw, R.govde, O(22)) + O(8)
     end
     if not o.komutlar or #o.komutlar == 0 then return y end

     y = y + O(12)
     G.Yaz("COMANDOS", F(12, "kalin"), x, y, R.altin, 0, O(3))
     y = y + O(28)
     local ic = dw - O(22)
     for _, satir in ipairs(o.komutlar) do
          local ara = string.match(satir, "^—%s*(.-)%s*—$")
          if ara then
               y = y + O(8)
               G.Yaz(G.Buyuk(ara), F(11, "kalin"), x, y, R.pirinc, 0, O(3))
               y = y + O(24)
          else
               -- "komut  (açıklama)": komut altın, açıklama altında soluk italik
               local komut, aciklama = string.match(satir, "^(.-)%s%s+(%(.+%))$")
               G.Baklava(x + O(6), y, O(3), R.altin, 200)
               y = Paragraf(komut or satir, F(15, "kalin"), x + O(20), y, ic, R.altinAcik, O(21))
               if aciklama then y = Paragraf(aciklama, F(14, "italik"), x + O(20), y - O(2), ic, R.soluk, O(19)) end
               y = y + O(6)
          end
     end
     return y
end

/*
*   Panel
*/
local PANEL = {}

local function KaydirmaCubugu(sp)
     local bar = sp:GetVBar()
     bar:SetWide(O(4))
     bar:SetHideButtons(true)
     bar.Paint = function() end
     bar.btnGrip.Paint = function(_, w, h) G.Kutu(0, 0, w, h, G.Renk(R.altin, 120)) end
end

function PANEL:Init()
     G.RehberPanel = self
     SekmeleriTopla()
     self.sekme = G.SonSekme or "aktif"
     if not self:SekmeAcik(self.sekme) then self.sekme = "aktif" end
     self.secili = nil
     self.acilis = RealTime()
     self.veri = {}
     self.arama = ""
     self.aramalar = {}

     self.liste = vgui.Create("DScrollPanel", self)
     KaydirmaCubugu(self.liste)

     self.detay = vgui.Create("DScrollPanel", self)
     KaydirmaCubugu(self.detay)
     self.detayIc = self.detay:Add("Panel")
     self.detayIc:Dock(TOP)
     self.detayIc:SetTall(O(400)) -- sıfır boylu panel boyanmaz; boyu içerik çizildikçe ayarlanır
     self.detayIc.Paint = function(p, w)
          local yuk = self:RehberDetay(w)
          if math.abs(p:GetTall() - yuk) > 1 then p:SetTall(yuk) end
     end

     self.araKutu = vgui.Create("Panel", self)
     self.araKutu.Paint = function(_, w, h)
          local odak = self.ara:HasFocus()
          G.Kutu(0, 0, w, h, odak and ARA_ODAK or ARA_ZEMIN)
          G.Cerceve(0, 0, w, h, odak and CERCEVE_SEC or CERCEVE)
          G.Baklava(O(14), h / 2, O(3), R.altin, odak and 255 or 150, false)
          if self.ara:GetValue() == "" then
               G.Yaz(ARAMALI[self.sekme] or "Buscar…", F(14, "italik"), O(30), h / 2, R.soluk)
          end
     end
     self.ara = vgui.Create("DTextEntry", self.araKutu)
     self.ara:Dock(FILL)
     self.ara:DockMargin(O(26), 0, O(8), 0)
     self.ara:SetFont(F(14, "govde"))
     self.ara:SetUpdateOnType(true)
     self.ara:SetDrawLanguageID(false)
     self.ara.Paint = function(s) s:DrawTextEntryText(R.fildisi, R.altin, R.fildisi) end
     self.ara.OnValueChange = function(_, deger)
          self.arama = deger
          self.aramaZaman = RealTime() + 0.12
     end
     -- odak aramadayken TAB menüyü kapatsın, Enter odağı bıraksın (M ve TAB yeniden çalışır)
     local temel = vgui.GetControlTable("DTextEntry").OnKeyCodeTyped
     self.ara.OnKeyCodeTyped = function(s, tus)
          if tus == KEY_TAB then
               if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
               return true
          end
          if tus == KEY_ENTER or tus == KEY_PAD_ENTER then
               s:KillFocus()
               return true
          end
          if temel then return temel(s, tus) end
     end

     self.dugmeler = {}
     self.takipDugme = self:Dugme("Seguir", function()
          if self.secili and self.secili.id then
               RunConsoleCommand("sardon_gorev_takip", self.secili.id)
               G.Cal("tik")
          end
     end, true)
     self.birakDugme = self:Dugme("Abandonar misión", function()
          local g = self.secili
          if not g or not g.id then return end
          Derma_Query("¿Quieres abandonar la misión «" .. (g.ad or "") .. "»? Perderás el progreso.", "Abandonar misión",
               "Abandonar", function() G.Iste(G.ISTEK.BIRAK, function() net.WriteString(g.id) end) end, "Cancelar")
     end)
     self.yazDugme = self:Dugme("Escribir en chat", function()
          local k = self.secili
          if not k or not k.komut then return end
          G.Cal("tik")
          G.SohbeteYaz("/" .. k.komut .. " ")
     end, true)
     self.kopyaDugme = self:Dugme(function()
          return self.kopyalandi and RealTime() - self.kopyalandi < 1.5 and "Copiado" or "Copiar"
     end, function()
          local k = self.secili
          if not k or not k.komut then return end
          SetClipboardText("/" .. k.komut)
          self.kopyalandi = RealTime()
          G.Cal("tik")
     end)

     hook.Add("SardonGorevDurum", self, function()
          if SEKME[self.sekme][3] == "gorev" then self:Yenile() end
     end)
     self:Yenile()
     self:OzelKur()
end

-- Dış sekmenin içerik paneli: seçilince kurulur, başka sekmeye geçince kaldırılır
function PANEL:OzelKur()
     if IsValid(self.ozel) then self.ozel:Remove() end
     self.ozel = nil
     local t = SEKME[self.sekme].ozel
     if not t then return end
     local ok, p = pcall(t.olustur, self)
     if ok and ispanel(p) and IsValid(p) then
          p:SetParent(self)
          self.ozel = p
          self:InvalidateLayout(true)
     end
end

function PANEL:Dugme(metin, fn, birincil)
     local b = vgui.Create("DButton", self)
     b:SetText("")
     b.Paint = function(s, w, h)
          local ust = s:IsHovered()
          G.Kutu(0, 0, w, h, birincil and Color(60, 50, 30, ust and 255 or 215) or Color(7, 11, 9, ust and 240 or 190))
          G.Cerceve(0, 0, w, h, (birincil or ust) and R.altin or R.cizgi)
          G.Yaz(G.Buyuk(isfunction(metin) and metin() or metin), F(13, "kalin"), w / 2, h / 2, birincil and R.altinAcik or R.govde, 1, O(2))
     end
     b.OnCursorEntered = function() G.Cal("ustune") end
     b.DoClick = fn
     self.dugmeler[#self.dugmeler + 1] = b
     return b
end

function PANEL:SekmeAcik(id)
     local s = SEKME[id]
     if not s then return false end
     return not s[4] or s[4]() == true
end

function PANEL:SekmeSec(id)
     if self.sekme == id or not self:SekmeAcik(id) then return end
     self.aramalar[self.sekme] = self.arama
     self.sekme = id
     G.SonSekme = id
     self.arama = self.aramalar[id] or ""
     self.aramaZaman = nil
     self.ara:SetText(self.arama)
     self.ara:KillFocus()
     self.secili = nil
     self:OzelKur()
     self:InvalidateLayout(true)
     self:Yenile()
     self.detay:GetVBar():SetScroll(0)
end

function PANEL:Ogeler()
     local D = G.D
     local out = {}
     if self.sekme == "aktif" then
          local liste = {}
          for _, g in ipairs(D.gorevler or {}) do
               if not g.gizli then liste[#liste + 1] = g end
          end
          table.sort(liste, function(a, b)
               if a.takip ~= b.takip then return a.takip end
               local ta, tb = G.Tur(a.tur).sira, G.Tur(b.tur).sira
               if ta ~= tb then return ta < tb end
               return (a.bas or 0) > (b.bas or 0)
          end)
          out = liste
     elseif self.sekme == "gunluk" then
          for _, x in ipairs(D.gunluk or {}) do
               local g = G.GorevBul(x.id)
               out[#out + 1] = g or { id = x.id, ad = x.ad, ozet = x.ozet, tur = "gunluk", bittiGunluk = x.bitti, hedefler = {} }
          end
     elseif self.sekme == "bitti" then
          local liste = table.Copy(D.bitti or {})
          table.sort(liste, function(a, b) return (a.son or 0) > (b.son or 0) end)
          for _, b in ipairs(liste) do b.tamamlanan = true out[#out + 1] = b end
     else
          self.veri[self.sekme] = self.veri[self.sekme] or VERI[self.sekme]()
          out = Suz(self.veri[self.sekme], self.arama, self.sekme == "komut")
     end
     return out
end

function PANEL:Yenile()
     self.liste:Clear()
     if SEKME[self.sekme].ozel then
          self.secili = nil
          return
     end
     local ogeler = self:Ogeler()
     if self.secili then
          local bulundu
          for _, g in ipairs(ogeler) do if not g.baslik and g.id == self.secili.id then bulundu = g end end
          self.secili = bulundu
     end
     if not self.secili then
          for _, g in ipairs(ogeler) do if not g.baslik then self.secili = g break end end
     end

     local tur = SEKME[self.sekme][3] == "gorev" and "gorev" or self.sekme
     local boy = tur == "gorev" and O(70) or O(56)
     for _, g in ipairs(ogeler) do
          if g.baslik then
               local p = self.liste:Add("Panel")
               p:Dock(TOP)
               p:DockMargin(0, O(6), O(6), O(4))
               p:SetTall(O(22))
               p.Paint = function(_, w, h)
                    local tw = G.Yaz(G.Buyuk(g.baslik), F(11, "kalin"), 0, h / 2, R.altin, 0, O(3))
                    G.Kutu(tw + O(10), math.floor(h / 2), w - tw - O(16), 1, CERCEVE)
               end
          else
               local b = self.liste:Add("DButton")
               b:Dock(TOP)
               b:DockMargin(0, 0, O(6), O(6))
               b:SetTall(boy)
               b:SetText("")
               b.Paint = function(s, w, h) SATIR[tur](s, w, h, g, self.secili ~= nil and self.secili.id == g.id) end
               b.DoClick = function()
                    self.secili = g
                    self.detay:GetVBar():SetScroll(0)
                    G.Cal("tik")
               end
          end
     end
end

function PANEL:Think()
     if self.aramaZaman and RealTime() >= self.aramaZaman then
          self.aramaZaman = nil
          self:Yenile()
          self.liste:GetVBar():SetScroll(0)
          self.detay:GetVBar():SetScroll(0)
     end
end

function PANEL:PerformLayout(w, h)
     if not SEKME[self.sekme] then self.sekme = "aktif" end
     local solW = math.Clamp(w * 0.3, O(300), O(440))
     local ust = O(150)
     self.solW, self.ust = solW, ust

     local aramali = ARAMALI[self.sekme] ~= nil
     self.araKutu:SetVisible(aramali)
     self.araKutu:SetPos(O(40), ust)
     self.araKutu:SetSize(solW - O(6), O(38))
     local ly = aramali and ust + O(50) or ust
     local ozel = SEKME[self.sekme].ozel ~= nil
     self.liste:SetVisible(not ozel)
     self.liste:SetPos(O(40), ly)
     self.liste:SetSize(solW, h - ly - O(30))
     if IsValid(self.ozel) then
          self.ozel:SetPos(O(40), ust)
          self.ozel:SetSize(w - O(70), h - ust - O(30))
     end

     local bx = O(40) + solW + O(50)
     local by = h - O(76)
     for _, b in ipairs({ self.takipDugme, self.yazDugme }) do
          b:SetPos(bx, by)
          b:SetSize(O(180), O(42))
     end
     for _, b in ipairs({ self.birakDugme, self.kopyaDugme }) do
          b:SetPos(bx + O(196), by)
          b:SetSize(O(180), O(42))
     end

     self.detay:SetVisible(SEKME[self.sekme][3] == "rehber")
     self.detay:SetPos(bx, ust)
     self.detay:SetSize(w - bx - O(30), (self.sekme == "komut" and by - O(16) or h - O(30)) - ust)
end

-- Alt sekmelerin yerleri; gruplar arasında baklava ayraç
function PANEL:SekmeDizilim()
     local font = F(13, "kalin")
     local out, x, onceki, sonUc = {}, O(40), nil, nil
     for _, s in ipairs(SEKMELER) do
          if self:SekmeAcik(s[1]) then
               if onceki and onceki ~= s[3] then
                    out.ayraclar = out.ayraclar or {}
                    out.ayraclar[#out.ayraclar + 1] = sonUc + O(44)
                    x = sonUc + O(88)
               end
               local ad = G.Buyuk(s[2])
               local sayi = self:SekmeSayi(s[1])
               local etiket = ad .. (sayi and ("  " .. sayi) or "")
               local tw = G.Genislik(etiket, font, O(2))
               out[#out + 1] = { id = s[1], x = x, w = tw, etiket = etiket, cizgi = G.Genislik(ad, font, O(2)) }
               sonUc = x + tw
               x = x + math.max(tw + O(36), O(130))
               onceki = s[3]
          end
     end
     return out
end

function PANEL:SekmeSayi(id)
     local n = 0
     if id == "aktif" then
          for _, g in ipairs(G.D.gorevler or {}) do if not g.gizli then n = n + 1 end end
          return n
     elseif id == "gunluk" then
          for _, x in ipairs(G.D.gunluk or {}) do if not x.bitti then n = n + 1 end end
          return n > 0 and n or nil
     end
end

function PANEL:SekmeAltinda(mx, my)
     if my < O(98) or my > O(130) then return end
     for _, t in ipairs(self.dizilim or {}) do
          if mx >= t.x - O(8) and mx <= t.x + t.w + O(8) then return t.id end
     end
end

function PANEL:OnMousePressed(tus)
     if tus ~= MOUSE_LEFT then return end
     local id = self:SekmeAltinda(self:CursorPos())
     if id and id ~= self.sekme then
          self:SekmeSec(id)
          G.Cal("tik")
     end
end

function PANEL:OnCursorMoved(mx, my)
     self:SetCursor(self:SekmeAltinda(mx, my) and "hand" or "arrow")
end

local function GunDonumuKalan()
     local simdi = os.time()
     local tr = os.date("!*t", simdi + 3 * 3600)
     local gecen = tr.hour * 3600 + tr.min * 60 + tr.sec
     local hedef = G.Ayar.GunDonumSaat * 3600
     local kalan = hedef - gecen
     if kalan <= 0 then kalan = kalan + 86400 end
     return kalan
end

function PANEL:Paint(w, h)
     if not SEKME[self.sekme] then self.sekme = "aktif" end
     local a = G.Yumusak((RealTime() - self.acilis) / 0.3)
     surface.SetDrawColor(7, 11, 9, 200 * a)
     surface.DrawRect(0, 0, w, h)
     G.Parilti(w * 0.6, h * 0.35, h * 1.1, R.altin, 12 * a)

     local grup = SEKME[self.sekme][3]
     G.Yaz("SARDON", F(12, "kalin"), O(40), O(40), R.altin, 0, O(4))
     G.Yaz(BASLIK[grup], F(34, "baslik"), O(40), O(70), R.fildisiAcik, 0, O(1))

     local font = F(13, "kalin")
     local mx, my = self:CursorPos()
     local ustteki = self:SekmeAltinda(mx, my)
     self.dizilim = self:SekmeDizilim()
     for _, t in ipairs(self.dizilim) do
          local sec = self.sekme == t.id
          G.Yaz(t.etiket, font, t.x, O(114), sec and R.altinAcik or (ustteki == t.id and R.fildisi or R.soluk), 0, O(2))
          if sec then G.Kutu(t.x, O(128), t.cizgi, O(2), R.altin) end
     end
     for _, ax in ipairs(self.dizilim.ayraclar or {}) do G.Baklava(ax, O(114), O(3), R.altin, 150) end

     local x = O(40) + (self.solW or O(300)) + O(50)
     if not SEKME[self.sekme].ozel then
          surface.SetDrawColor(R.cizgi.r, R.cizgi.g, R.cizgi.b, 120)
          surface.DrawRect(x - O(25), O(150), 1, h - O(180))
     end

     local g = self.secili
     local gorev = grup == "gorev"
     self.takipDugme:SetVisible(gorev and g ~= nil and not g.tamamlanan and not g.takip and G.GorevBul(g.id or "") ~= nil)
     self.birakDugme:SetVisible(gorev and g ~= nil and not g.tamamlanan and g.iptal ~= false and G.GorevBul(g.id or "") ~= nil)
     self.yazDugme:SetVisible(self.sekme == "komut" and g ~= nil)
     self.kopyaDugme:SetVisible(self.sekme == "komut" and g ~= nil)

     if gorev then self:GorevDetay(x, w, h) end
end

function PANEL:RehberDetay(w)
     local o = self.secili
     local ciz = DETAY[self.sekme]
     if not ciz then return O(60) end
     if not o then
          local bos = self.arama ~= "" and "Nada coincide con tu búsqueda." or "No hay nada que mostrar aquí."
          G.Yaz(bos, F(18, "italik"), 0, O(30), R.soluk)
          return O(60)
     end
     -- uzun açıklamalar çok geniş satıra yayılmasın
     return ciz(o, 0, O(20), math.min(w - O(20), O(1000))) + O(20)
end

function PANEL:GorevDetay(x, w, h)
     local dw = w - x - O(60)
     local g = self.secili

     if not g then
          local bos = self.sekme == "bitti" and "Aún no has completado ninguna misión." or (self.sekme == "gunluk" and "No hay misión diaria para hoy." or "No tienes ninguna misión en curso.")
          G.Yaz(bos, F(18, "italik"), x, O(180), R.soluk)
          if self.sekme == "gunluk" then
               G.Yaz("Nuevas diarias en: " .. string.NiceTime(GunDonumuKalan()), F(14, "govde"), x, O(210), R.soluk)
          end
          return
     end

     local renk = G.TurRenk(g.tur)
     local y = O(170)
     G.Baklava(x + O(5), y, O(5), renk)
     G.Yaz(G.Buyuk(G.Tur(g.tur).ad), F(13, "kalin"), x + O(18), y, renk, 0, O(3))
     y = y + O(38)
     G.Yaz(g.ad or "", F(32, "baslik"), x, y, R.fildisiAcik)
     y = y + O(30)
     G.AltinCizgi(x, y, math.min(dw, O(700)), 180, renk)
     y = y + O(24)

     if g.ozet and g.ozet ~= "" then
          for _, s in ipairs(G.Sar(g.ozet, F(18, "italik"), dw)) do
               G.Yaz(s, F(18, "italik"), x, y, R.fildisi)
               y = y + O(24)
          end
          y = y + O(8)
     end
     if g.aciklama and g.aciklama ~= "" then
          for _, s in ipairs(G.Sar(g.aciklama, F(15, "govde"), dw)) do
               if y > h - O(260) then break end
               G.Yaz(s, F(15, "govde"), x, y, R.govde)
               y = y + O(21)
          end
          y = y + O(14)
     end

     if g.tamamlanan then
          G.Yaz("Completada" .. ((g.sayi or 1) > 1 and (" · " .. g.sayi .. " veces") or "") .. (g.son and ("  ·  última: " .. os.date("%d.%m.%Y %H:%M", g.son)) or ""), F(15, "kalin"), x, y, R.yesil)
          return
     end
     if g.bittiGunluk then
          G.Yaz("La misión de hoy está hecha. La siguiente en " .. string.NiceTime(GunDonumuKalan()) .. ".", F(15, "kalin"), x, y, R.yesil)
          return
     end

     if g.adim and g.adim ~= "" then
          G.Yaz("AHORA", F(12, "kalin"), x, y, R.altin, 0, O(3))
          y = y + O(22)
          G.Yaz(g.adim, F(18, "serif"), x, y, R.fildisi)
          y = y + O(30)
     end

     local lp = LocalPlayer()
     for _, hd in ipairs(g.hedefler or {}) do
          local metin = hd.metin or ""
          if hd.gerek and hd.gerek > 1 then metin = metin .. "  (" .. (hd.sayi or 0) .. "/" .. hd.gerek .. ")" end
          if hd.istege then metin = metin .. "  · opcional" end
          G.Baklava(x + O(7), y, O(5), hd.tamam and R.yesil or renk, 255, hd.tamam)
          G.Yaz(metin, F(16, "govde"), x + O(22), y, hd.tamam and R.soluk or R.govde)
          local n = G.IsaretNoktasi(hd.isaret)
          if n and not hd.tamam then
               G.Yaz(math.Round(lp:GetPos():Distance(n) * 0.01905) .. " m", F(13, "govde"), x + dw, y, R.soluk, 2)
          end
          y = y + O(26)
     end

     if g.oduller and #g.oduller > 0 then
          y = math.max(y + O(16), h - O(150))
          G.Yaz("RECOMPENSAS", F(12, "kalin"), x, y, R.altin, 0, O(3))
          G.Yaz(table.concat(g.oduller, "   ◆   "), F(15, "kalin"), x, y + O(24), R.fildisi)
     end
end

vgui.Register("SardonGorev.Rehber", PANEL, "EditablePanel")

/*
*   TAB menü sekmesi: Helix'in Rehber'inin yerine ([sardon] ui cl_menu.lua PopulateTabs, CreateMenuButtons sonrası)
*/
hook.Remove("CreateMenuButtons", "SardonGorev")
hook.Add("SardonMenuSekmeleri", "SardonGorev", function(tabs)
     tabs["gorevler"] = nil
     tabs["help"] = {
          hoswarsIcon = "icon_quests",
          bHideBackground = true,
          Create = function(info, container)
               local p = container:Add("SardonGorev.Rehber")
               p:SetSize(container:GetSize())
               p:Dock(FILL)
               G.Iste(G.ISTEK.DURUM)
          end
     }
end)

local function DilEkle()
     if not ix or not ix.lang then return end
     for dil in pairs(ix.lang.stored or {}) do
          ix.lang.AddTable(dil, { help = "Guía" })
     end
end
DilEkle()
timer.Simple(5, DilEkle)

-- TAB menüsünü Rehber sekmesinde, istenen bölümde açar
function G.RehberAc(bolum)
     if not ix or not ix.gui then return end
     SekmeleriTopla()
     if bolum and SEKME[bolum] then G.SonSekme = bolum end
     if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
     -- yeni panel bölümü G.SonSekme'den okur ([sardon] karakter SK.Ac gibi: fareyi yakalamadan seç)
     local menu = vgui.Create("ixMenu")
     if not IsValid(menu) or not menu.tabs then return end
     for _, b in ipairs(menu.tabs.buttons or {}) do
          if b.name == "help" then
               for _, diger in ipairs(menu.tabs.buttons) do
                    if diger ~= b then diger:SetSelected(false) end
               end
               b:SetSelected(true)
               break
          end
     end
end

function G.GunlukAc() G.RehberAc("aktif") end

concommand.Add("sardon_gorev_gunluk", G.GunlukAc)
concommand.Add("sardon_rehber", function(_, _, args) G.RehberAc(args[1]) end)

hook.Add("PlayerButtonDown", "SardonGorev.Gunluk", function(ply, tus)
     if ply ~= LocalPlayer() or not IsFirstTimePredicted() then return end
     local hedef = SardonConfig and SardonConfig.Options and SardonConfig.Options.gorev_gunluk and SardonConfig:Get("gorev_gunluk") or KEY_M
     if tus ~= hedef then return end
     if gui.IsGameUIVisible() or IsValid(vgui.GetKeyboardFocus()) then return end
     if IsValid(ix.gui.chat) and ix.gui.chat.GetActive and ix.gui.chat:GetActive() then return end
     if IsValid(ix.gui.menu) then ix.gui.menu:Remove() return end
     G.GunlukAc()
end)
