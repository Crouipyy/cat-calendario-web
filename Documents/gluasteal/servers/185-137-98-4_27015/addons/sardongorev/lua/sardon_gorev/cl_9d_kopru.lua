-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_9d_kopru.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Köprü (istemci): Misión Günlüğü, Karakter Gelişimi ve Büyü Ağacı açılınca sunucuya olay yollar
*   (misiónlerde "Defterini aç", "Karakter Gelişimi'ni aç" pasoları). Sunucu: sv_9b_kopru.lua.
*/
local G = SardonGorev

local sonGonderim = {}
local function Gonder(ad)
     if (sonGonderim[ad] or 0) > RealTime() then return end
     sonGonderim[ad] = RealTime() + 2
     net.Start("SardonGorev.ArayuzOlay")
     net.WriteString(ad)
     net.SendToServer()
end

-- Rehber paneli: açılan örneği hatırla (Helix bütün sekmeleri birden kurar; görünen sekme ayrıca denetlenir)
local rehber = vgui.GetControlTable("SardonGorev.Rehber")
if rehber and not rehber.SardonKopru then
     local eski = rehber.Init
     rehber.Init = function(self, ...)
          G.RehberPanel = self
          if eski then return eski(self, ...) end
     end
     rehber.SardonKopru = true
end

-- Sekme gerçekten önündeyken bir kez
local acik = {}
local function Durum(ad, gorunuyor)
     if gorunuyor then
          if not acik[ad] then acik[ad] = true Gonder(ad) end
     else
          acik[ad] = nil
     end
end

timer.Create("SardonGorev.ArayuzOlay", 0.5, 0, function()
     local menu = ix and ix.gui and ix.gui.menu
     local sub = IsValid(menu) and not menu.bClosing and menu.GetActiveSubpanel and menu:GetActiveSubpanel()
     local rp = G.RehberPanel
     Durum("defter_acildi", IsValid(sub) and IsValid(rp) and rp:GetParent() == sub)
     local ke = SardonGelisim and SardonGelisim.Ekran
     Durum("gelisim_acildi", IsValid(sub) and IsValid(ke) and ke:GetParent() == sub)
end)

-- Büyü Ağacı: asa menüsü sayfası kurulunca (sayfa tablosu yeniden kurulabilir; 10 sn'de bir denetle)
local function BuyuAgaciSar()
     local N = HpwRewrite and HpwRewrite.Nocturne
     local p = N and N.Pages and N.Pages.buyuagaci
     if not p or not isfunction(p.build) or p.SardonKopru then return end
     local eski = p.build
     p.build = function(...)
          Gonder("buyuagaci_acildi")
          return eski(...)
     end
     p.SardonKopru = true
end
BuyuAgaciSar()
timer.Create("SardonGorev.BuyuAgaciSar", 10, 0, BuyuAgaciSar)
