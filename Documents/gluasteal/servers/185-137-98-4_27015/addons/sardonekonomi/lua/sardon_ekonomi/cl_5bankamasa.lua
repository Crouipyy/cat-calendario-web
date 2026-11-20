-- "addons\\sardonekonomi\\lua\\sardon_ekonomi\\cl_5bankamasa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
--[[
     Sardon Ekonomi :: Mesa de intercambio Gringotts penceresi + makbuz okuma (istemci). Fontlar cl_3pencere.lua'da.
     Sunucu: SardonEko.MasaDurum (oturan oyuncuya durum) · SardonEko.Makbuz (makbuz "Oku").
]]

SardonEkonomi = SardonEkonomi or {}
local E = SardonEkonomi

local R = {
     zemin = Color(22, 20, 16, 250), kart = Color(36, 32, 26, 255), kartAcik = Color(46, 41, 33, 255), secili = Color(66, 88, 56, 255),
     cizgi = Color(110, 92, 52, 255), altin = Color(228, 196, 112), yazi = Color(234, 226, 210), soluk = Color(168, 156, 136),
     yesil = Color(120, 200, 130), kirmizi = Color(220, 110, 100), dugme = Color(120, 92, 48), dugmeUst = Color(150, 116, 60),
     kapali = Color(58, 52, 46),
}

local function Gonder(islem, arg)
     net.Start("SardonEko.Masa")
          net.WriteString(islem)
          net.WriteTable(arg or {})
     net.SendToServer()
end

local function Dugme(ust, metin, etkin, tikla, w, h)
     local b = vgui.Create("DButton", ust)
     b:SetText("")
     b:SetSize(w or 120, h or 32)
     b.metin, b.etkin = metin, etkin
     b.Paint = function(s, bw, bh)
          draw.RoundedBox(6, 0, 0, bw, bh, not s.etkin and R.kapali or (s:IsHovered() and R.dugmeUst or R.dugme))
          draw.SimpleText(s.metin, "SardonEko.Kucuk", bw / 2, bh / 2, s.etkin and R.yazi or R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
     b.DoClick = function(s) if s.etkin then surface.PlaySound("ui/buttonclick.wav") tikla() end end
     return b
end

local function Giris(ust, deger, sayi, w)
     local g = vgui.Create("DTextEntry", ust)
     g:SetSize(w or 100, 30)
     g:SetFont("SardonEko.Yazi")
     if sayi then g:SetNumeric(true) end
     g:SetValue(tostring(deger or ""))
     return g
end

local function Kaydirma(ust)
     local s = vgui.Create("DScrollPanel", ust)
     local c = s:GetVBar()
     c:SetWide(8)
     c.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, R.kart) end
     c.btnGrip.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, R.cizgi) end
     c.btnUp.Paint, c.btnDown.Paint = function() end, function() end
     return s
end

local function Satir(ust, h, ciz)
     local p = ust:Add("DPanel")
     p:Dock(TOP)
     p:DockMargin(0, 0, 8, 5)
     p:SetTall(h)
     p.Paint = ciz
     return p
end

local function Baslik(ust, metin)
     local l = ust:Add("DLabel")
     l:Dock(TOP)
     l:DockMargin(0, 8, 0, 4)
     l:SetTall(26)
     l:SetFont("SardonEko.Kalin")
     l:SetTextColor(R.altin)
     l:SetText(metin)
end

----------------------------------------------------------------------------------------
-- Takas sekmesi
----------------------------------------------------------------------------------------
local function TakasKur(f, v, govde)
     local w, h = govde:GetWide(), govde:GetTall()
     if not v.karsiAd then
          govde.Paint = function(_, pw, ph)
               draw.SimpleText("Esperando a alguien en el otro lado…", "SardonEko.Kalin", pw / 2, ph / 2 - 14, R.yazi, TEXT_ALIGN_CENTER)
               draw.SimpleText("Cuando alguien se siente al otro lado empieza el intercambio. Mientras, puedes dejar un contrato en Depósito.", "SardonEko.Kucuk", pw / 2, ph / 2 + 14, R.soluk, TEXT_ALIGN_CENTER)
          end
          return
     end
     local yarim = (w - 20) / 2
     local kilit = v.inceleme ~= nil
     govde.Paint = function(_, pw, ph)
          draw.SimpleText("Tu oferta", "SardonEko.Kalin", 0, 0, R.yazi)
          draw.SimpleText(v.karsiAd .. " ofrece", "SardonEko.Kalin", yarim + 20, 0, R.yazi)
          draw.SimpleText(v.benOnay and "Confirmaste" or "Sin confirmar", "SardonEko.Kucuk", 0, ph - 26, v.benOnay and R.yesil or R.soluk)
          draw.SimpleText(v.oOnay and (v.karsiAd .. " confirmó") or (v.karsiAd .. " sin confirmar"), "SardonEko.Kucuk", 190, ph - 26, v.oOnay and R.yesil or R.soluk)
     end

     local sol = Kaydirma(govde)
     sol:SetPos(0, 28)
     sol:SetSize(yarim, h - 150)
     for _, es in ipairs(v.envanter) do
          local b = sol:Add("DButton")
          b:Dock(TOP)
          b:DockMargin(0, 0, 8, 4)
          b:SetTall(32)
          b:SetText("")
          b.Paint = function(s, bw, bh)
               draw.RoundedBox(5, 0, 0, bw, bh, es.secili and R.secili or (s:IsHovered() and not kilit and R.cizgi or R.kart))
               draw.SimpleText((es.secili and "• " or "") .. es.ad, "SardonEko.Kucuk", 10, bh / 2, R.yazi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
          b.DoClick = function() if not kilit then Gonder("esya", {id = es.id, ekle = not es.secili}) end end
     end

     local y0 = h - 112
     local etiket = vgui.Create("DLabel", govde)
     etiket:SetPos(0, y0 - 2)
     etiket:SetSize(yarim, 20)
     etiket:SetFont("SardonEko.Kucuk")
     etiket:SetTextColor(R.soluk)
     etiket:SetText(string.format("Bolsillo (%d)        Cuenta (%d)", v.cep, v.hesap))
     local cep = Giris(govde, v.benCep, true, 110)
     cep:SetPos(0, y0 + 20)
     local hesap = Giris(govde, v.benHesap, true, 110)
     hesap:SetPos(150, y0 + 20)
     local ayarla = Dugme(govde, "Ajustar galeones", not kilit, function()
          Gonder("para", {cep = tonumber(cep:GetValue()) or 0, hesap = tonumber(hesap:GetValue()) or 0})
     end, 130, 30)
     ayarla:SetPos(300, y0 + 20)

     local sag = Kaydirma(govde)
     sag:SetPos(yarim + 20, 28)
     sag:SetSize(yarim, h - 150)
     if #v.onunEsya == 0 then
          Satir(sag, 32, function(_, pw, ph) draw.SimpleText("Sin objetos.", "SardonEko.Kucuk", 10, ph / 2, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end)
     end
     for _, ad in ipairs(v.onunEsya) do
          Satir(sag, 32, function(_, pw, ph)
               draw.RoundedBox(5, 0, 0, pw, ph, R.kart)
               draw.SimpleText(ad, "SardonEko.Kucuk", 10, ph / 2, R.yazi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end)
     end
     local onunPara = vgui.Create("DLabel", govde)
     onunPara:SetPos(yarim + 20, y0 + 20)
     onunPara:SetSize(yarim, 30)
     onunPara:SetFont("SardonEko.Kalin")
     onunPara:SetTextColor(R.altin)
     onunPara:SetText("+ " .. v.onunPara .. " Galleon  (al recibir %" .. v.oran .. " tasa notarial)")

     local onay = Dugme(govde, v.benOnay and "Confirmado" or "Confirmar", not v.benOnay and not kilit, function() Gonder("onay") end, 120, 32)
     onay:SetPos(w - 120, h - 34)

     -- inceleme katmanı
     if kilit then
          local bitis = CurTime() + v.inceleme
          local kat = vgui.Create("DPanel", govde)
          kat:SetPos(0, 0)
          kat:SetSize(w, h - 44)
          kat.Paint = function(_, pw, ph)
               draw.RoundedBox(8, pw / 2 - 220, ph / 2 - 70, 440, 140, Color(16, 14, 10, 235))
               draw.SimpleText("El notario goblin revisa", "SardonEko.Baslik", pw / 2, ph / 2 - 56, R.altin, TEXT_ALIGN_CENTER)
               draw.SimpleText(math.max(0, math.ceil(bitis - CurTime())) .. " s · ofertas bloqueadas", "SardonEko.Kalin", pw / 2, ph / 2 - 10, R.yazi, TEXT_ALIGN_CENTER)
          end
          local dur = Dugme(kat, "Detener revisión", true, function() Gonder("iptal") end, 180, 32)
          dur:SetPos(w / 2 - 90, (h - 44) / 2 + 26)
     end
end

----------------------------------------------------------------------------------------
-- Emanet sekmesi
----------------------------------------------------------------------------------------
local function EmanetKur(f, v, govde)
     local s = Kaydirma(govde)
     s:Dock(FILL)
     f.emanetSecim = f.emanetSecim or {}

     Baslik(s, "Contratos que te dejaron")
     if #v.bana == 0 then
          Satir(s, 30, function(_, pw, ph) draw.SimpleText("Ninguno.", "SardonEko.Kucuk", 10, ph / 2, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end)
     end
     for _, so in ipairs(v.bana) do
          local p = Satir(s, 74, function(_, pw, ph)
               draw.RoundedBox(6, 0, 0, pw, ph, R.kartAcik)
               draw.SimpleText(so.a .. " dejó: " .. (#so.esya > 0 and table.concat(so.esya, ", ") or "sin objetos") .. (so.para > 0 and (" + " .. so.para .. " G") or ""), "SardonEko.Kucuk", 12, 8, R.yazi)
               draw.SimpleText("Contraprestación: " .. so.karsilik .. " G" .. (so.notu ~= "" and ("  ·  Nota: " .. so.notu) or ""), "SardonEko.Kucuk", 12, 30, R.soluk)
               draw.SimpleText(math.max(0, math.floor(so.kalan / 3600)) .. " saat restante", "SardonEko.Kucuk", 12, 50, R.soluk)
          end)
          local b = Dugme(p, "Aceptar (" .. so.karsilik .. " G pagar)", true, function() Gonder("emanet_kabul", {id = so.id}) end, 190, 32)
          p.PerformLayout = function(_, pw, ph) b:SetPos(pw - 202, (ph - 32) / 2) end
     end

     Baslik(s, "Contratos que dejaste (" .. #v.benimSozlesme .. "/" .. v.sozlesmeSiniri .. ")")
     for _, so in ipairs(v.benimSozlesme) do
          local p = Satir(s, 54, function(_, pw, ph)
               draw.RoundedBox(6, 0, 0, pw, ph, R.kart)
               draw.SimpleText("→ " .. so.b .. ": " .. (#so.esya > 0 and table.concat(so.esya, ", ") or "sin objetos") .. (so.para > 0 and (" + " .. so.para .. " G") or ""), "SardonEko.Kucuk", 12, 8, R.yazi)
               draw.SimpleText(so.durum == 2 and "Caducado — recuperar" or ("Contraprestación " .. so.karsilik .. " G · " .. math.max(0, math.floor(so.kalan / 3600)) .. " saat restante"),
                    "SardonEko.Kucuk", 12, 30, so.durum == 2 and R.kirmizi or R.soluk)
          end)
          local b = Dugme(p, so.durum == 2 and "Recuperar" or "Retirar", true, function() Gonder("emanet_geri", {id = so.id}) end, 110, 32)
          p.PerformLayout = function(_, pw, ph) b:SetPos(pw - 122, (ph - 32) / 2) end
     end

     Baslik(s, "Nuevo contrato de depósito (tasa " .. v.harc .. " G, al aceptar %" .. v.oran .. " tasa notarial)")
     local form = Satir(s, 120, function(_, pw, ph)
          draw.RoundedBox(6, 0, 0, pw, ph, R.kart)
          draw.SimpleText("Para quién (nombre del personaje)", "SardonEko.Kucuk", 12, 8, R.soluk)
          draw.SimpleText("Bolsillo", "SardonEko.Kucuk", 232, 8, R.soluk)
          draw.SimpleText("Cuenta", "SardonEko.Kucuk", 332, 8, R.soluk)
          draw.SimpleText("Contraprestación (G)", "SardonEko.Kucuk", 432, 8, R.soluk)
          draw.SimpleText("Nota (opcional)", "SardonEko.Kucuk", 12, 64, R.soluk)
     end)
     local hedef = Giris(form, f.emanetHedef or "", false, 210) hedef:SetPos(12, 28)
     local cep = Giris(form, 0, true, 90) cep:SetPos(232, 28)
     local hesap = Giris(form, 0, true, 90) hesap:SetPos(332, 28)
     local karsilik = Giris(form, 0, true, 120) karsilik:SetPos(432, 28)
     local notu = Giris(form, "", false, 410) notu:SetPos(12, 84)
     hedef.OnChange = function(g) f.emanetHedef = g:GetValue() end
     local birak = Dugme(form, "Registrar depósito", #v.benimSozlesme < v.sozlesmeSiniri, function()
          local secim = {}
          for id, ok in pairs(f.emanetSecim) do if ok then secim[#secim + 1] = id end end
          Gonder("emanet_ver", {hedef = hedef:GetValue(), esyalar = secim, cep = tonumber(cep:GetValue()) or 0,
               hesap = tonumber(hesap:GetValue()) or 0, karsilik = tonumber(karsilik:GetValue()) or 0, notu = notu:GetValue()})
          f.emanetSecim = {}
     end, 150, 32)
     form.PerformLayout = function(_, pw, ph) birak:SetPos(pw - 162, ph - 44) end

     Baslik(s, "Objetos para el depósito (máx. 8)")
     for _, es in ipairs(v.envanter) do
          local b = s:Add("DButton")
          b:Dock(TOP)
          b:DockMargin(0, 0, 8, 4)
          b:SetTall(30)
          b:SetText("")
          b.Paint = function(btn, bw, bh)
               local sec = f.emanetSecim[es.id]
               draw.RoundedBox(5, 0, 0, bw, bh, sec and R.secili or (btn:IsHovered() and R.cizgi or R.kart))
               draw.SimpleText((sec and "• " or "") .. es.ad, "SardonEko.Kucuk", 10, bh / 2, R.yazi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
          b.DoClick = function() f.emanetSecim[es.id] = not f.emanetSecim[es.id] or nil end
     end
end

----------------------------------------------------------------------------------------
-- Pencere
----------------------------------------------------------------------------------------
local function Kur(v)
     local f = E.MasaPencere
     if not IsValid(f) then
          f = vgui.Create("DFrame")
          f:SetSize(math.min(880, ScrW() - 40), math.min(620, ScrH() - 40))
          f:Center()
          f:SetTitle("")
          f:ShowCloseButton(false)
          f:SetDraggable(true)
          f:MakePopup()
          f.sekme = "takas"
          f.OnKeyCodePressed = function(s, k) if k == KEY_ESCAPE then s:Remove() end end
          E.MasaPencere = f
     end
     -- DFrame'in kendi iç düğmeleri (btnClose vb.) silinmesin: içerik ayrı kök panelde
     if IsValid(f.kok) then f.kok:Remove() end
     local w, h = f:GetWide(), f:GetTall()
     local kok = vgui.Create("DPanel", f)
     kok:SetPos(0, 0)
     kok:SetSize(w, h)
     kok.Paint = function() end
     -- boş yere tıklanınca çerçeve sürüklenebilsin
     kok.OnMousePressed = function(_, k) f:OnMousePressed(k) end
     kok.OnMouseReleased = function(_, k) f:OnMouseReleased(k) end
     f.kok = kok
     f.Paint = function(_, pw, ph)
          draw.RoundedBox(10, 0, 0, pw, ph, R.zemin)
          surface.SetDrawColor(R.cizgi)
          surface.DrawOutlinedRect(0, 0, pw, ph, 1)
          draw.SimpleText("Mesa de intercambio Gringotts", "SardonEko.Baslik", 24, 14, R.altin)
          draw.SimpleText("Notario goblin · galeones del bolsillo y cuenta · recibidos van al banco · %" .. v.oran .. " tasa notarial (Tesoro)",
               "SardonEko.Kucuk", 26, 54, R.soluk)
     end

     for i, s in ipairs({{"takas", "Intercambio"}, {"emanet", "Depósito (" .. #v.bana .. ")"}}) do
          local b = Dugme(kok, (f.sekme == s[1] and "• " or "") .. s[2], true, function() f.sekme = s[1] Kur(v) end, 150, 32)
          b:SetPos(24 + (i - 1) * 158, 82)
     end
     local kalk = Dugme(kok, "Levantarse", true, function() Gonder("kalk") end, 130, 32)
     kalk:SetPos(w - 154, 20)
     local kapat = Dugme(kok, "Cerrar ventana", true, function() f:Remove() end, 150, 32)
     kapat:SetPos(w - 154 - 158, 20)

     local govde = vgui.Create("DPanel", kok)
     govde:SetPos(24, 126)
     govde:SetSize(w - 48, h - 140)
     govde.Paint = function() end
     if f.sekme == "emanet" then EmanetKur(f, v, govde) else TakasKur(f, v, govde) end
end

net.Receive("SardonEko.MasaDurum", function()
     local v = net.ReadTable()
     if v.kapat then
          if IsValid(E.MasaPencere) then E.MasaPencere:Remove() end
          return
     end
     Kur(v)
end)

net.Receive("SardonEko.Makbuz", function()
     local d = net.ReadTable()
     local satirlar = {
          "Sello: " .. tostring(d.no or "?") .. "   ·   " .. os.date("%d.%m.%Y %H:%M", d.tarih or 0),
          "",
          tostring(d.a or "?") .. " entregó: " .. (istable(d.aKalem) and #d.aKalem > 0 and table.concat(d.aKalem, ", ") or "sin objetos") .. ((d.aPara or 0) > 0 and (" + " .. d.aPara .. " Galleon") or ""),
          tostring(d.b or "?") .. " entregó: " .. (istable(d.bKalem) and #d.bKalem > 0 and table.concat(d.bKalem, ", ") or "sin objetos") .. ((d.bPara or 0) > 0 and (" + " .. d.bPara .. " Galleon") or ""),
          "",
          "Tasa notarial: " .. (d.ucret or 0) .. " Galleon" .. (d.tur == "emanet" and "   (contrato de depósito)" or ""),
     }
     if d.notu and d.notu ~= "" then satirlar[#satirlar + 1] = "Nota: " .. d.notu end
     Derma_Message(table.concat(satirlar, "\n"), "Recibo Gringotts", "Cerrar")
end)
