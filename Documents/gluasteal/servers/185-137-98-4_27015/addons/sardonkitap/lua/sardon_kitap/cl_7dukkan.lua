-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_7dukkan.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: kitapçı ekranı (kitapçıyla konuşunca) — Yeni kitaplar · İkinci el · Kitap sat
-- Yeni kitap satın alınmaz, rafından istenir: "Yeni Kitaplar" her kitabın rafını gösterir (rafa bak, E'ye bas;
-- kitapçı Accio ile indirir). Kayış buradan alınır. Her işlemden sonra sunucu listeyi yeniden gönderir.

local SK = SardonKitap
local R = SK.R

local SEKMELER = {{"yeni", "Yeni Kitaplar"}, {"ikinci", "İkinci El"}, {"sat", "Kitap Sat"}}
local YENI_BILGI = "Yeni kitap için rafına bak ve E'ye bas; kitapçı Accio ile indirip tezgâha koyar, ücreti orada ödersin."

local PANEL = {}

function PANEL:Init()
     SK.Fontlar()
     self:SetSize(ScrW(), ScrH())
     self:MakePopup()
     self.sekme = "yeni"
     self.acilis = CurTime()
     self.kaydir = 0
end

function PANEL:Kur(v)
     self.v = v
end

function PANEL:OnKeyCodePressed(k)
     if k == KEY_ESCAPE or k == KEY_TAB or k == KEY_E then self:Remove() end
end

function PANEL:OnMouseWheeled(d)
     self.kaydir = math.max(0, self.kaydir - d * SK.S(40))
end

function PANEL:Alan(x, y, w, h, fn)
     self.alanlar[#self.alanlar + 1] = {x, y, w, h, fn}
     return SK.Ustunde(self, x, y, w, h)
end

function PANEL:OnMousePressed(k)
     if k ~= MOUSE_LEFT then return end
     local mx, my = self:CursorPos()
     for i = #self.alanlar, 1, -1 do
          local a = self.alanlar[i]
          if mx >= a[1] and mx <= a[1] + a[3] and my >= a[2] and my <= a[2] + a[4] then return a[5]() end
     end
     if self.kutu and (mx < self.kutu[1] or mx > self.kutu[1] + self.kutu[3] or my < self.kutu[2] or my > self.kutu[2] + self.kutu[4]) then self:Remove() end
end

local function Islem(ad, yaz)
     net.Start("SardonKitap.DukkanIslem")
     net.WriteString(ad)
     if yaz then yaz() end
     net.SendToServer()
     surface.PlaySound("buttons/button14.wav")
end

function PANEL:Dugme(x, y, w, h, metin, fn, kapali)
     local ust = not kapali and self:Alan(x, y, w, h, fn)
     SK.Kutu(x, y, w, h, Color(R.altin.r, R.altin.g, R.altin.b, kapali and 30 or (ust and 110 or 60)))
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, kapali and 70 or 200)
     surface.DrawOutlinedRect(x, y, w, h, 1)
     SK.Yazi(metin, "etiket", x + w / 2, y + h / 2, kapali and R.soluk or R.murekkep, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- kitap sırtı küçük resmi
local function Sirt(k, x, y, h)
     local w = SK.S(16)
     SK.Kutu(x, y, w, h, k.spine)
     SK.Kutu(x + 2, y + SK.S(6), w - 4, 1, k.harf)
     SK.Kutu(x + 2, y + h - SK.S(7), w - 4, 1, k.harf)
end

function PANEL:Satir(x, y, w, k, alt, sag, dugme, fn, kapali)
     local h = SK.S(54)
     SK.Kutu(x, y, w, h - SK.S(6), Color(R.parsomenK.r, R.parsomenK.g, R.parsomenK.b, 150))
     if k then Sirt(k, x + SK.S(10), y + SK.S(6), h - SK.S(18)) end
     SK.Yazi(k and k.ad or "", "metinK", x + SK.S(36), y + SK.S(6), R.murekkep)
     SK.Yazi(alt or "", "ust", x + SK.S(36), y + SK.S(26), R.murekkepK)
     SK.Yazi(sag or "", "etiket", x + w - SK.S(150), y + (h - SK.S(6)) / 2, R.altin, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     self:Dugme(x + w - SK.S(130), y + SK.S(10), SK.S(118), SK.S(28), dugme, fn, kapali)
     return h
end

function PANEL:Paint(w, h)
     local v = self.v
     self.alanlar = {}
     if not v then return end
     surface.SetAlphaMultiplier(math.Clamp((CurTime() - self.acilis) * 5, 0, 1))
     SK.Kutu(0, 0, w, h, R.zemin)
     local pw, ph = math.min(SK.S(820), w - 40), math.min(SK.S(600), h - 40)
     local x, y = (w - pw) / 2, (h - ph) / 2
     self.kutu = {x, y, pw, ph}
     SK.Deri(x - SK.S(14), y - SK.S(14), pw + SK.S(28), ph + SK.S(28))
     SK.Parsomen(x, y, pw, ph)
     local pad = SK.S(28)

     SK.Yazi("Hogsmeade Kitapçısı", "baslik", x + pad, y + pad, R.murekkep)
     SK.Yazi("Kitapçı Villanelle · ikinci el, satış ve kayış", "italik", x + pad, y + pad + SK.S(34), R.murekkepK)
     SK.Yazi(v.para .. " Galleon", "baslikK", x + pw - pad, y + pad + SK.S(4), R.altin, TEXT_ALIGN_RIGHT)

     -- sekmeler
     local sx = x + pad
     local sy = y + pad + SK.S(50)
     for _, s in ipairs(SEKMELER) do
          local tw = SK.Olc(s[2], "etiket") + SK.S(28)
          local secili = self.sekme == s[1]
          local ust = self:Alan(sx, sy, tw, SK.S(30), function() self.sekme = s[1] self.kaydir = 0 end)
          SK.Kutu(sx, sy, tw, SK.S(30), Color(R.altin.r, R.altin.g, R.altin.b, secili and 120 or (ust and 60 or 25)))
          SK.Yazi(s[2], "etiket", sx + tw / 2, sy + SK.S(15), R.murekkep, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          sx = sx + tw + SK.S(8)
     end

     local lx, ly, lw = x + pad, sy + SK.S(44), pw - pad * 2
     local lalt = y + ph - pad
     render.SetScissorRect(lx, ly, lx + lw, lalt, true)
     local yy = ly - self.kaydir
     -- yalnız tamamen görünen satırlar çizilir ve tıklanır (yarım satır kaydırma alanının dışına taşmasın)
     local function Sinir(hh) return yy >= ly - 1 and yy + hh <= lalt + SK.S(6) end

     if self.sekme == "yeni" then
          -- kitap kayışı en üstte
          local kh = SK.S(54)
          if Sinir(kh) then
               SK.Kutu(lx, yy, lw, kh - SK.S(6), Color(R.parsomenK.r, R.parsomenK.g, R.parsomenK.b, 150))
               SK.Yazi("Kitap Kayışı", "metinK", lx + SK.S(36), yy + SK.S(6), R.murekkep)
               SK.Yazi("SEKİZ KİTABI TEK YUVADA TAŞIR", "ust", lx + SK.S(36), yy + SK.S(26), R.murekkepK)
               SK.Yazi(v.kayisFiyat .. " G", "etiket", lx + lw - SK.S(150), yy + (kh - SK.S(6)) / 2, R.altin, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               self:Dugme(lx + lw - SK.S(130), yy + SK.S(10), SK.S(118), SK.S(28), v.kayisVar and "Sende var" or "Satın al", function() Islem("kayis") end, v.kayisVar)
          end
          yy = yy + kh
          if Sinir(SK.S(30)) then
               SK.Yazi(YENI_BILGI, "italik", lx + SK.S(4), yy + SK.S(4), R.murekkepK)
          end
          yy = yy + SK.S(30)
          for _, r in ipairs(v.yeni) do
               local k = SK.Kitap[r.id]
               if k then
                    if Sinir(SK.S(54)) then
                         local h = SK.S(54)
                         SK.Kutu(lx, yy, lw, h - SK.S(6), Color(R.parsomenK.r, R.parsomenK.g, R.parsomenK.b, 150))
                         SK.Kutu(lx + SK.S(10), yy + SK.S(6), SK.S(16), h - SK.S(18), k.spine)
                         SK.Yazi(k.ad, "metinK", lx + SK.S(36), yy + SK.S(6), R.murekkep)
                         SK.Yazi(SK.Buyuk(r.raf ~= "" and r.raf or "rafı yok") , "ust", lx + SK.S(36), yy + SK.S(26), R.murekkepK)
                         SK.Yazi(r.var and "Sende var" or (r.fiyat .. " G"), "etiket", lx + lw - SK.S(16), yy + (h - SK.S(6)) / 2, r.var and R.iyi or R.altin, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
                    yy = yy + SK.S(54)
               end
          end
     elseif self.sekme == "ikinci" then
          if #v.stok == 0 then
               SK.Yazi("İkinci el rafı şu an boş.", "metin", lx, yy, R.murekkepK)
          end
          for _, r in ipairs(v.stok) do
               local k = SK.Kitap[r.kitap]
               if k then
                    local onceki = util.JSONToTable(r.onceki or "[]") or {}
                    local alt = (#onceki > 0 and ("ÖNCEKİ: " .. SK.Buyuk(table.concat(onceki, ", "))) or "İKİNCİ EL") .. (r.notlar > 0 and (" · " .. r.notlar .. " KENAR NOTU") or "")
                    if Sinir(SK.S(54)) then
                         self:Satir(lx, yy, lw, k, alt, r.fiyat .. " G", "Satın al", function() Islem("ikinci", function() net.WriteUInt(r.no, 32) end) end, false)
                    end
                    yy = yy + SK.S(54)
               end
          end
     else
          if #v.sat == 0 then
               SK.Yazi("Satabileceğin bir kitabın yok.", "metin", lx, yy, R.murekkepK)
          end
          for _, r in ipairs(v.sat) do
               local k = SK.Kitap[r.kitap]
               if k then
                    if Sinir(SK.S(54)) then
                         self:Satir(lx, yy, lw, k, "KENAR NOTLARIN YENİ SAHİBİNE KALIR", r.fiyat .. " G", "Sat", function() Islem("sat", function() net.WriteUInt(r.id, 32) end) end, false)
                    end
                    yy = yy + SK.S(54)
               end
          end
     end
     render.SetScissorRect(0, 0, 0, 0, false)
     local toplam = yy + self.kaydir - ly
     self.kaydir = math.Clamp(self.kaydir, 0, math.max(0, toplam - (lalt - ly)))
     SK.Yazi("Esc · kapat    tekerlek · kaydır", "ust", x + pw / 2, y + ph + SK.S(20), Color(220, 210, 190, 160), TEXT_ALIGN_CENTER)
     surface.SetAlphaMultiplier(1)
end

vgui.Register("SardonKitap.Dukkan", PANEL, "EditablePanel")

net.Receive("SardonKitap.Dukkan", function()
     local v = {para = net.ReadUInt(32), yeni = {}, stok = {}, sat = {}}
     for i = 1, net.ReadUInt(5) do v.yeni[i] = {id = net.ReadString(), fiyat = net.ReadUInt(10), var = net.ReadBool(), raf = net.ReadString()} end
     v.kayisFiyat = net.ReadUInt(10)
     v.kayisVar = net.ReadBool()
     for i = 1, net.ReadUInt(6) do v.stok[i] = {no = net.ReadUInt(32), kitap = net.ReadString(), onceki = net.ReadString(), fiyat = net.ReadUInt(10), notlar = net.ReadUInt(8)} end
     for i = 1, net.ReadUInt(5) do v.sat[i] = {id = net.ReadUInt(32), kitap = net.ReadString(), fiyat = net.ReadUInt(10)} end
     if IsValid(SK.DukkanPanel) then
          SK.DukkanPanel:Kur(v)
          return
     end
     local p = vgui.Create("SardonKitap.Dukkan")
     p:Kur(v)
     SK.DukkanPanel = p
end)
