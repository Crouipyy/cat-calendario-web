-- "addons\\sardongorev\\lua\\sardon_gorev\\_sh_5gelisim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Karakter Gelişimi (KG) bağlantısı — paylaşılan kısım
*   - Koşullar: gelisim_dal (dalın ana/yan rolü), gelisim_kademe (daldaki kademe)
*   - Ödül:    dal_puan (yalnız o dalın becerilerine harcanan puan, SardonGelisim.DalPuanEkle)
*   - Eşya:    "Cuaderno a medias" (prolog anlatısının nesnesi; kullanınca Görev Günlüğü açılır)
*   Sunucu mantığı sv_9b_kopru.lua'da. Bu dosya _sh_2sema.lua'dan sonra yüklenir (alfabetik);
*   oradaki Kaydet yerel olduğu için aynı işi burada yapar.
*/
local G = SardonGorev

local function Kaydet(tur, id, t)
     t.id = id
     t.alanlar = t.alanlar or {}
     G.Sema[tur][id] = t
     local sira = G.SemaSira[tur]
     for i, v in ipairs(sira) do
          if v == id then table.remove(sira, i) break end
     end
     sira[#sira + 1] = id
end

G.GelisimDallari = {
     { id = "sifa", ad = "Curación" }, { id = "baskalasim", ad = "Transfiguración" }, { id = "tilsim", ad = "Encantamiento" },
     { id = "lanet", ad = "Maldición" }, { id = "syb", ad = "SYB" }, { id = "iksir", ad = "Poción" },
     { id = "ksks", ad = "KSKS" }, { id = "botanik", ad = "Botánica" },
}
local DAL_AD = { ["*"] = "Cualquier ramo" }
for _, d in ipairs(G.GelisimDallari) do DAL_AD[d.id] = d.ad end

-- koşullarda "*" = herhangi bir dal
local DAL_KOSUL = { { id = "*", ad = "Cualquier ramo" } }
for _, d in ipairs(G.GelisimDallari) do DAL_KOSUL[#DAL_KOSUL + 1] = d end
function G.GelisimDalAd(id) return DAL_AD[id or ""] or tostring(id or "?") end

local ROLLER = {
     { id = "ikisi", ad = "Principal o secundaria" }, { id = "ana", ad = "Ramo principal" },
     { id = "yan", ad = "Ramo secundaria" }, { id = "yok", ad = "Sin rol (no elegido)" },
}
local ROL_AD = {}
for _, r in ipairs(ROLLER) do ROL_AD[r.id] = r.ad end

-- Ağaç düzeni her dalda aynı: 1 kök, 2-4 ikinci sıra, 5-7 üçüncü sıra, 8 ustalık
G.GelisimBeceriSecim = {
     { id = "1", ad = "1 · competencia raíz" },
     { id = "s2", ad = "Fila 2 (máximo de 2-4)" },
     { id = "s3", ad = "Fila 3 (máximo de 5-7)" },
     { id = "8", ad = "8 · maestría" },
     { id = "toplam", ad = "Nivel total del ramo" },
     { id = "2", ad = "2" }, { id = "3", ad = "3" }, { id = "4", ad = "4" },
     { id = "5", ad = "5" }, { id = "6", ad = "6" }, { id = "7", ad = "7" },
}
local BECERI_AD = {}
for _, b in ipairs(G.GelisimBeceriSecim) do BECERI_AD[b.id] = b.ad end

local KARSILASTIR = { { id = ">=", ad = "≥" }, { id = "==", ad = "=" }, { id = "<", ad = "<" } }

local function Tersi(alanlar)
     alanlar[#alanlar + 1] = { k = "tersi", ad = "Inverso (si no)", tip = "bool", v = false }
     return alanlar
end

Kaydet("Kosul", "gelisim_dal", {
     ad = "Ramo de desarrollo (rol)",
     aciklama = "En Desarrollo de Personaje, las 2 primeras ramas con puntos son principales y la 3.ª es secundaria. 'Sin rol' = no elegida o tomada a coste ×4.",
     alanlar = Tersi({
          { k = "dal", ad = "Ramo", tip = "secim", v = "sifa", secenekler = DAL_KOSUL },
          { k = "rol", ad = "Rol", tip = "secim", v = "ikisi", secenekler = ROLLER },
     }),
     ozet = function(e) return G.GelisimDalAd(e.dal) .. ": " .. (ROL_AD[e.rol] or "?") end,
})

Kaydet("Kosul", "gelisim_kademe", {
     ad = "Nivel de desarrollo",
     aciklama = "Nivel de una competencia del ramo (o el más alto de una fila / el total).",
     alanlar = Tersi({
          { k = "dal", ad = "Ramo", tip = "secim", v = "sifa", secenekler = G.GelisimDallari },
          { k = "beceri", ad = "Competencia", tip = "secim", v = "1", secenekler = G.GelisimBeceriSecim },
          { k = "islem", ad = "Comparación", tip = "secim", v = ">=", secenekler = KARSILASTIR },
          { k = "deger", ad = "Nivel", tip = "sayi", v = 1, min = 0, max = 40 },
     }),
     ozet = function(e)
          return G.GelisimDalAd(e.dal) .. " " .. (BECERI_AD[e.beceri] or "?") .. " " .. (e.islem == "==" and "=" or e.islem == "<" and "<" or "≥") .. " " .. tostring(e.deger)
     end,
})

Kaydet("Kosul", "hane_icinde", {
     ad = "En su propia casa",
     aciklama = "El jugador está en el salón / dormitorio común de su propia casa (cajas rp_sh2 en sv_9b_kopru.lua).",
     alanlar = Tersi({}),
     ozet = function() return "en su propia casa" end,
})

Kaydet("Odul", "dal_puan", {
     ad = "Puntos de ramo",
     aciklama = "XP fija a ese ramo (1 punto = 500 XP; no aplican Fatiga ni Inspiración). Desde 2026-11-09 es XP de ramo en lugar de puntos.",
     alanlar = {
          { k = "dal", ad = "Ramo", tip = "secim", v = "sifa", secenekler = G.GelisimDallari },
          { k = "miktar", ad = "Puntos", tip = "sayi", v = 1, min = 1, max = 20 },
     },
     ozet = function(e) return (e.miktar or 1) .. " " .. G.GelisimDalAd(e.dal) .. " pts." end,
})

/*
*   Yarım Kalmış Defter
*/
G.DefterEsya = "yarim_defter"

do
     local ITEM = ix.item.Register(G.DefterEsya, nil, false, nil, true)
     ITEM.name = "Cuaderno a medias"
     ITEM.description = "Un cuaderno viejo de tapa de cuero, con las esquinas gastadas. La mayoría de las páginas están en blanco; pero a veces la tinta aparece sola, sin que nadie escriba."
     ITEM.model = "models/staylofft/hogwarts_books/staylofft_ancient_magic_book.mdl"
     ITEM.category = "Misión"
     ITEM.width = 1
     ITEM.height = 1
     ITEM.noBusiness = true
     ITEM.functions = ITEM.functions or {}
     ITEM.functions.Oku = {
          name = "Leer",
          icon = "icon16/book_open.png",
          OnClick = function(item)
               if SardonGorev and SardonGorev.RehberAc then SardonGorev.RehberAc("aktif") end
               return false
          end,
          OnRun = function() return false end,
          OnCanRun = function(item) return not IsValid(item.entity) end,
     }
end
