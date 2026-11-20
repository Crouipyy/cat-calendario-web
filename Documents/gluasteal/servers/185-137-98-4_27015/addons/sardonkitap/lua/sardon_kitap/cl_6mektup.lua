-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_6mektup.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: Hogwarts mektubu (malzeme listesi). Durum: 1 alındı (✓), 0 alınmadı (boş kutu),
-- 2 bilgi satırı, 3 grup başlığı. Esc ya da kâğıdın dışına tıklama kapatır.

local SK = SardonKitap
local R = SK.R

local PANEL = {}

function PANEL:Init()
     SK.Fontlar()
     self:SetSize(ScrW(), ScrH())
     self:MakePopup()
     self.acilis = CurTime()
     surface.PlaySound("physics/cardboard/cardboard_box_impact_soft2.wav")
end

function PANEL:Kur(v)
     self.v = v
     self.kw = math.min(SK.S(660), ScrW() - 40)
     -- yükseklik içeriğe göre
     local h = SK.S(290)
     local sw = self.kw - SK.S(80) - SK.S(190)
     for _, s in ipairs(v.satirlar) do
          if s[3] == 3 then
               h = h + SK.S(32)
          else
               s.satirlar = SK.Sar(s[1], "metinK", s[3] == 2 and s[2] == "" and (self.kw - SK.S(80)) or sw)
               h = h + #s.satirlar * SK.S(21) + SK.S(3)
          end
     end
     self.kh = math.min(h, ScrH() - 40)
end

function PANEL:OnKeyCodePressed(k)
     if k == KEY_ESCAPE or k == KEY_TAB or k == KEY_E then self:Remove() end
end

function PANEL:OnMousePressed()
     local mx, my = self:CursorPos()
     local x, y = (ScrW() - self.kw) / 2, (ScrH() - self.kh) / 2
     if mx < x or mx > x + self.kw or my < y or my > y + self.kh then self:Remove() end
end

function PANEL:Paint(w, h)
     local v = self.v
     if not v then return end
     surface.SetAlphaMultiplier(math.Clamp((CurTime() - self.acilis) * 5, 0, 1))
     SK.Kutu(0, 0, w, h, R.zemin)
     local pw, ph = self.kw, self.kh
     local x, y = (w - pw) / 2, (h - ph) / 2
     SK.Parsomen(x, y, pw, ph)
     local pad = SK.S(40)
     local cx = x + pw / 2
     local yy = y + pad

     SK.Yazi("HOGWARTS", "dev", cx, yy, R.murekkep, TEXT_ALIGN_CENTER)
     yy = yy + SK.S(44)
     SK.Yazi("CADILIK VE BÜYÜCÜLÜK OKULU", "ust", cx, yy, R.altin, TEXT_ALIGN_CENTER)
     yy = yy + SK.S(26)
     local hane = SK.HaneBul(v.hane)
     local hitap = "Sayın " .. v.ad .. (hane and (", " .. hane.ad) or "") .. ","
     SK.Yazi(hitap, "metin", x + pad, yy, R.murekkep)
     yy = yy + SK.S(28)
     local giris = v.yil == 1
          and "Hogwarts Cadılık ve Büyücülük Okulu'na kabul edildiğinizi bildirmekten mutluluk duyarız. Gerekli kitap ve malzemelerin listesi aşağıdadır."
          or (v.yil .. ". yılınız için gerekli kitap ve malzemelerin listesi aşağıdadır. Yeni dönemde başarılar dileriz.")
     for _, s in ipairs(SK.Sar(giris, "metinK", pw - pad * 2)) do
          SK.Yazi(s, "metinK", x + pad, yy, R.murekkepK)
          yy = yy + SK.SatirYuk("metinK")
     end
     yy = yy + SK.S(10)

     for _, s in ipairs(v.satirlar) do
          local ad, alt, durum = s[1], s[2], s[3]
          if yy > y + ph - SK.S(90) then break end
          if durum == 3 then
               yy = yy + SK.S(8)
               SK.Yazi(ad, "ust", x + pad, yy, R.altin)
               if alt ~= "" then SK.Yazi(alt, "italik", x + pad + SK.Olc(ad, "ust") + SK.S(10), yy - SK.S(3), R.murekkepK) end
               yy = yy + SK.S(24)
          else
               local kx = x + pad
               if durum == 0 or durum == 1 then
                    surface.SetDrawColor(R.murekkepK) surface.DrawOutlinedRect(kx, yy + SK.S(4), SK.S(12), SK.S(12), 1)
                    if durum == 1 then
                         surface.SetDrawColor(R.iyi)
                         for o = 0, 1 do
                              surface.DrawLine(kx + 2, yy + SK.S(10) + o, kx + SK.S(5), yy + SK.S(14) + o)
                              surface.DrawLine(kx + SK.S(5), yy + SK.S(14) + o, kx + SK.S(12), yy + SK.S(3) + o)
                         end
                    end
                    kx = kx + SK.S(22)
               end
               if alt ~= "" then SK.Yazi(alt, "italik", x + pw - pad, yy + SK.S(1), R.soluk, TEXT_ALIGN_RIGHT) end
               for _, t in ipairs(s.satirlar or {ad}) do
                    SK.Yazi(t, "metinK", kx, yy, durum == 1 and R.soluk or R.murekkep)
                    yy = yy + SK.S(21)
               end
               yy = yy + SK.S(3)
          end
     end

     SK.Yazi("Saygılarımızla,", "metinK", x + pw - pad, y + ph - SK.S(80), R.murekkepK, TEXT_ALIGN_RIGHT)
     SK.Yazi("M. McGonagall", "el", x + pw - pad, y + ph - SK.S(60), Color(40, 60, 110), TEXT_ALIGN_RIGHT)
     SK.Yazi("MÜDÜR YARDIMCISI", "ust", x + pw - pad, y + ph - SK.S(30), R.soluk, TEXT_ALIGN_RIGHT)
     SK.Yazi("Esc · kapat", "ust", cx, y + ph + SK.S(8), Color(220, 210, 190, 160), TEXT_ALIGN_CENTER)
     surface.SetAlphaMultiplier(1)
end

vgui.Register("SardonKitap.Mektup", PANEL, "EditablePanel")

net.Receive("SardonKitap.Mektup", function()
     local v = {yil = net.ReadUInt(4), ad = net.ReadString(), hane = net.ReadString(), satirlar = {}}
     for i = 1, net.ReadUInt(6) do
          v.satirlar[i] = {net.ReadString(), net.ReadString(), net.ReadUInt(2)}
     end
     if IsValid(SK.MektupPanel) then SK.MektupPanel:Remove() end
     local p = vgui.Create("SardonKitap.Mektup")
     p:Kur(v)
     SK.MektupPanel = p
end)
