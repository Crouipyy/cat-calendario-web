-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\_sh_yetki.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Ministerio :: kimlik ve yetki. İki tarafta aynı kod; istemcide yalnızca neyin
-- görüneceğini belirler, her eylem sunucuda B.Yapabilir'den yeniden geçer (_sh_net.lua).

local B = SardonBakanlik

function B.Kategori(ply)
     local char = IsValid(ply) and ply.GetCharacter and ply:GetCharacter()
     if not char then return nil end
     local f = char.GetFactionTable and char:GetFactionTable() or ix.faction.indices[char:GetFaction()]
     return f and f.category or nil
end

-- Karakterin sınıfının eşlemedeki kaydı + sınıf tablosu
function B.SinifBilgi(char)
     local sinif = char and ix.class.list[char:GetClass() or 0]
     if not sinif then return nil, nil end
     return B.Siniflar[sinif.uniqueID], sinif
end

-- Defterdeki kimlik: {uye, daire, kademe, unvan, birim, sira, sinif, sinifId, zincir, avukat, bakan, denetci}
-- Ministerio / Aurorlık üyesi değilse nil (süperadmin "denetçi" olarak görür).
function B.Bilgi(ply)
     if not IsValid(ply) or not ply.GetCharacter then return nil end
     local char = ply:GetCharacter()
     if not char then return nil end

     local kat = B.Kategori(ply)
     if kat and B.Ayar.Kategoriler[kat] then
          local es, sinif = B.SinifBilgi(char)
          if es then
               local b = {
                    uye = true, daire = es.daire, kademe = es.kademe, unvan = es.unvan, birim = es.birim,
                    sira = es.sira or 0, sinif = sinif.name, sinifId = sinif.uniqueID, zincir = es.zincir,
                    avukat = es.avukat, bakan = es.bakan, serbest = es.serbest, kategori = kat,
               }
               if es.serbest then
                    local v = char:GetData("sardonBakanlik")
                    if istable(v) then
                         if B.DaireIndex[v.daire or ""] then b.daire = v.daire end
                         if isstring(v.unvan) and v.unvan ~= "" then b.unvan = v.unvan end
                         if isstring(v.birim) and v.birim ~= "" then b.birim = v.birim end
                    end
               end
               return b
          end

          local k = B.SinifsizKademe[kat]
          if not sinif and k then
               return {uye = true, daire = "yasa", kademe = k, unvan = "Aspirante a auror", birim = "Oficina de Aurores", sira = 15, kategori = kat}
          end
     end

     if ply:IsSuperAdmin() then
          return {uye = true, denetci = true, daire = "makam", kademe = 5, unvan = "Inspector", sira = 200, kategori = kat}
     end

     return nil
end

function B.Uye(ply) return B.Bilgi(ply) ~= nil end

function B.Gorevde(ply)
     return IsValid(ply) and ply:GetNW2Bool(B.NW_GOREV, false)
end

function B.Kademe(ply)
     local b = B.Bilgi(ply)
     return b and b.kademe or 0
end

-- k = en düşük kademe; daire = izinli daireler (nil = hepsi); gorev = false ise mesai şartı yok.
-- Kademe 5 ve Makam'ın 4. kademesi daire kısıtına takılmaz.
B.Izinler = {
     defter = {k = 1, gorev = false},
     mesai = {k = 1, gorev = false},
     personel = {k = 1, gorev = false},
     kumanda = {k = 1, gorev = false},

     sicil = {k = 1},
     sicil_not = {k = 1},
     sicil_bayrak = {k = 2},
     sicil_onur = {k = 3},
     ruhsat = {k = 2},
     tebligat = {k = 2},

     olay = {k = 1},
     dosya = {k = 2, daire = {"yasa", "esrar"}},
     dosya_gizli = {k = 4, daire = {"yasa", "esrar"}},

     ceza = {k = 2, daire = {"yasa"}},
     hapis = {k = 2, daire = {"yasa"}},
     hapis_onay = {k = 4, daire = {"yasa"}},
     tahliye = {k = 4, daire = {"yasa"}},
     af = {k = 5},

     priori = {k = 2, daire = {"yasa"}},
     sinsioskop = {k = 2, daire = {"yasa"}},
     iz = {k = 1, daire = {"yasa"}},
     tabu = {k = 5},

     emir = {k = 1, daire = {"yasa"}},
     emir_iste = {k = 2, daire = {"yasa"}},
     aranan = {k = 3, daire = {"yasa"}},
     emir_onay = {k = 4, daire = {"yasa"}},

     kararname_oku = {k = 1, gorev = false},
     kararname = {k = 5},
     kanun = {k = 5},
     tehdit = {k = 4, daire = {"yasa"}},

     hazine = {k = 4},
     hazine_harca = {k = 5},

     atama = {k = 4},
     takdir = {k = 4},
     ekip = {k = 3},

     mahkeme = {k = 1, daire = {"yasa"}},
     mahkeme_ac = {k = 4, daire = {"yasa"}},

     masa = {k = 1},
     masa_yonet = {k = 4},
     ruhemici = {k = 5},
     esrar = {k = 1, daire = {"esrar"}},
}

function B.DaireUygun(b, daireler)
     if not daireler or b.denetci or b.kademe >= 5 then return true end
     if b.daire == "makam" and b.kademe >= 4 then return true end
     for _, d in ipairs(daireler) do
          if d == b.daire then return true end
     end
     return false
end

-- Dönüş: bool, sebep
function B.Yapabilir(ply, izin)
     local b = B.Bilgi(ply)
     if not b then return false, "Este expediente no está disponible para ti." end

     local i = B.Izinler[izin]
     if not i then return false, "Permiso desconocido: " .. tostring(izin) end

     if b.kademe < i.k then return false, "Se requiere categoría " .. i.k .. " para esto." end
     if not B.DaireUygun(b, i.daire) then return false, "Tu departamento no tiene competencia para esta acción." end
     if i.gorev ~= false and not b.denetci and not B.Gorevde(ply) then return false, "Debes fichar en servicio primero." end

     return true
end

-- İstemcide düğme göstermek için: mesai şartını saymadan yetki var mı?
function B.Yetkili(ply, izin)
     local b = B.Bilgi(ply)
     local i = B.Izinler[izin]
     if not b or not i then return false end
     return b.kademe >= i.k and B.DaireUygun(b, i.daire)
end

-- aktor, hedefSinifId sınıfına atama yapabilir mi? (Karma atama kuralı)
--   * hedef sınıf eşlemede olmalı, "ozel" olmamalı
--   * Ministro de Magia sınıfına defterden atama yok (yetkili whitelist'i)
--   * hedef kademe aktörün kademesinin altında olmalı; Bakan (bakan=true) Subsecretario'ı da atar
--   * kademe 5 değilse yalnız kendi dairesindeki sınıflar
function B.AtayabilirSinif(aktorBilgi, hedefSinifId)
     local es = B.Siniflar[hedefSinifId or ""]
     if not aktorBilgi or not es then return false, "Esta clase no puede asignarse desde el expediente." end
     if es.ozel then return false, "Los roles de personaje con nombre no se asignan desde el expediente." end
     if es.bakan then return false, "Solo la administración nombra al Ministro de Magia." end
     if aktorBilgi.kademe < 4 then return false, "Se requiere categoría 4 para asignar cargos." end

     if aktorBilgi.denetci then return true end

     if es.kademe >= aktorBilgi.kademe and not (aktorBilgi.bakan and es.kademe == 5) then
          return false, "No puedes asignar a tu misma categoría ni superior."
     end

     if aktorBilgi.kademe < 5 and es.daire and es.daire ~= aktorBilgi.daire and not (aktorBilgi.daire == "makam") then
          return false, "Solo puedes asignar personal de tu propio departamento."
     end

     return true
end
