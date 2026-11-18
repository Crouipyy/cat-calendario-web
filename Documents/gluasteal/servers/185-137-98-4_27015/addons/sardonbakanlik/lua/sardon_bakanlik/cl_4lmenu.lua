-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_4lmenu.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Bakanlık :: L menüsü (oyuncuya bakıp L) eylemleri. [sardon] report'un SardonLMenu kaydı.
-- Asa incelemesi ve üst arama, defterde en son açılan dosyaya (B.SonDosya) delil olarak yazılır.
--
-- Kimlik (K17): görevli birinin dosyasını yalnız iki yoldan açar: kişi kelepçeliyse gerçek dosyası
-- (Bakanlık sihri), kimliğini gösterdiyse gösterilen kartın dosyası (sunucu kaydı çözer; sahte kartta dosya yok).
-- Sicile Bak / Ceza Kes / Dosya Aç bu şartı taşır; yüzüne bakmak tek başına yetmez.

local B = SardonBakanlik
local K = B.Kimlik

SardonLMenu = SardonLMenu or {}

local function Gorevli(izin)
     local ply = LocalPlayer()
     return B.Gorevde(ply) and B.Yetkili(ply, izin)
end

local function Bagli(hedef)
     return hedef.IsHandcuffed and hedef:IsHandcuffed()
end

local function CharID(hedef)
     local c = hedef:GetCharacter()
     return c and c:GetID()
end

local function DosyaNotu()
     return B.SonDosya and (" · Se escribe en el expediente #" .. B.SonDosya) or ""
end

-- K17: kelepçeli ya da kimliğini göstermiş mi
local function Taninir(hedef)
     return CharID(hedef) ~= nil and (Bagli(hedef) or K.GorulenBilgi(hedef) ~= nil)
end

local function Ad(hedef)
     local g = not Bagli(hedef) and K.GorulenBilgi(hedef)
     return g and g.ad or K.GorunenAd(hedef)
end

-- fn(charid): kelepçeliyse gerçek, değilse gösterilen kartın kaydı (sahte kartta 0)
local function Dosyasi(hedef, fn)
     if Bagli(hedef) then return fn(CharID(hedef)) end
     K.SicilIste(hedef, fn)
end

local function KendiKartim()
     local char = LocalPlayer():GetCharacter()
     for _, it in ipairs(K.Kartlar(char)) do
          if not it:GetData("bos") then return it end
     end
end

SardonLMenu["Mostrar identidad"] = {
     Sira = 3, Aciklama = "Extiende tu documento de identidad; conocerán tu nombre",
     Filter = function() return KendiKartim() ~= nil end,
     Do = function(hedef) B.Iste("kimlik.goster", {ent = hedef:EntIndex()}) end,
}

local ISTE_ACIKLAMA = {
     bakanlik = "Ordenas que muestre su identidad en nombre del Ministerio; negarse es delito",
     snatcher = "Exiges su identidad a la fuerza; la sangre y la recompensa en su cabeza",
     profesor = "Verificas el registro escolar del alumno",
}

SardonLMenu["Solicitar identidad"] = {
     Sira = 38,
     Filter = function(hedef)
          local rol = K.SorguRol(LocalPlayer())
          if not rol or Bagli(hedef) or not K.IsteyebilirMi(rol, hedef) then return false end
          SardonLMenu["Solicitar identidad"].Aciklama = ISTE_ACIKLAMA[rol]
          return true
     end,
     Do = function(hedef) B.Iste("kimlik.iste", {ent = hedef:EntIndex()}) end,
}

SardonLMenu["Revisar identidades"] = {
     Sira = 38, Aciklama = "Todos los documentos de identidad de la persona atada",
     Filter = function(hedef) return K.SorguRol(LocalPlayer()) ~= nil and Bagli(hedef) end,
     Do = function(hedef) B.Iste("kimlik.bak", {ent = hedef:EntIndex()}) end,
}

SardonLMenu["Mostrar credencial"] = {
     Sira = 40, Aciklama = "Muestra tu identidad del Ministerio de Magia",
     Filter = function() return B.Uye(LocalPlayer()) end,
     Do = function(hedef) B.Iste("rozet", {ent = hedef:EntIndex()}) end,
}

SardonLMenu["Consultar expediente"] = {
     Sira = 41,
     Filter = function(hedef)
          if not (Gorevli("sicil") and Taninir(hedef)) then return false end
          SardonLMenu["Consultar expediente"].Aciklama = Bagli(hedef) and "Expediente real de la persona atada" or "Expediente del documento que ha mostrado"
          return true
     end,
     Do = function(hedef)
          Dosyasi(hedef, function(id)
               if id and id > 0 then B.Ac("sicil", {kisi = id}) end
          end)
     end,
}

SardonLMenu["Examinar varita"] = {
     Sira = 42,
     Filter = function(hedef)
          SardonLMenu["Examinar varita"].Aciklama = "Priori Incantatem: últimos hechizos" .. DosyaNotu()
          return Gorevli("priori") and Bagli(hedef)
     end,
     Do = function(hedef) B.Iste("priori", {ent = hedef:EntIndex(), dosya = B.SonDosya}) end,
}

SardonLMenu["Registrar"] = {
     Sira = 43,
     Filter = function(hedef)
          SardonLMenu["Registrar"].Aciklama = "Confiscar objetos robados" .. DosyaNotu()
          return Gorevli("ceza") and Bagli(hedef) and SOYGUN ~= nil
     end,
     Do = function() B.Iste("gozalti.elkoy", {dosya = B.SonDosya}) end,
}

SardonLMenu["Imponer multa"] = {
     Sira = 44, Aciklama = "Multa pecuniaria según el código penal",
     Filter = function(hedef) return Gorevli("ceza") and Taninir(hedef) end,
     Do = function(hedef)
          local idx, ad = hedef:EntIndex(), Ad(hedef)
          Dosyasi(hedef, function(id)
               B.Ac("sicil", (id and id > 0) and {kisi = id} or nil)
               B.KanunSec("Multa · " .. ad, function(kod) B.Iste("ceza.kes", {ent = idx, kod = kod}) end, true)
          end)
     end,
}

SardonLMenu["Abrir expediente"] = {
     Sira = 45, Aciklama = "Registrar a esta persona como sospechoso y abrir investigación",
     Filter = function(hedef) return Gorevli("dosya") and Taninir(hedef) end,
     Do = function(hedef)
          local ad = Ad(hedef)
          Dosyasi(hedef, function(id)
               local supheli = (id and id > 0) and id or nil
               B.Ac("sicil", supheli and {kisi = supheli} or nil)
               B.MetinSor("Nuevo expediente de investigación", "Sospechoso: " .. ad .. (supheli and "" or " (documento sin registro)"), "Título del expediente…",
                    function(metin) B.Iste("dosya.ac", {baslik = metin, supheli = supheli}) end, {maks = 80, enAz = 3, dugme = "Abrir expediente"})
          end)
     end,
}