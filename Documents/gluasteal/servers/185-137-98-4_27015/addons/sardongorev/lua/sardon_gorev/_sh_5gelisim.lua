-- "addons\\sardongorev\\lua\\sardon_gorev\\_sh_5gelisim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Karakter Gelişimi (KG) bağlantısı — paylaşılan kısım
*   - Koşullar: gelisim_dal (dalın ana/yan rolü), gelisim_kademe (daldaki kademe)
*   - Ödül:    dal_puan (yalnız o dalın becerilerine harcanan puan, SardonGelisim.DalPuanEkle)
*   - Eşya:    "Yarım Kalmış Defter" (prolog anlatısının nesnesi; kullanınca Görev Günlüğü açılır)
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
     { id = "sifa", ad = "Şifa" }, { id = "baskalasim", ad = "Başkalaşım" }, { id = "tilsim", ad = "Tılsım" },
     { id = "lanet", ad = "Lanet" }, { id = "syb", ad = "SYB" }, { id = "iksir", ad = "İksir" },
     { id = "ksks", ad = "KSKS" }, { id = "botanik", ad = "Botanik" },
}
local DAL_AD = { ["*"] = "Herhangi bir dal" }
for _, d in ipairs(G.GelisimDallari) do DAL_AD[d.id] = d.ad end

-- koşullarda "*" = herhangi bir dal
local DAL_KOSUL = { { id = "*", ad = "Herhangi bir dal" } }
for _, d in ipairs(G.GelisimDallari) do DAL_KOSUL[#DAL_KOSUL + 1] = d end
function G.GelisimDalAd(id) return DAL_AD[id or ""] or tostring(id or "?") end

local ROLLER = {
     { id = "ikisi", ad = "Ana ya da yan" }, { id = "ana", ad = "Ana dal" },
     { id = "yan", ad = "Yan dal" }, { id = "yok", ad = "Rolsüz (seçilmemiş)" },
}
local ROL_AD = {}
for _, r in ipairs(ROLLER) do ROL_AD[r.id] = r.ad end

-- Ağaç düzeni her dalda aynı: 1 kök, 2-4 ikinci sıra, 5-7 üçüncü sıra, 8 ustalık
G.GelisimBeceriSecim = {
     { id = "1", ad = "1 · kök yetkinlik" },
     { id = "s2", ad = "2. sıra (2-4'ün en yükseği)" },
     { id = "s3", ad = "3. sıra (5-7'nin en yükseği)" },
     { id = "8", ad = "8 · ustalık" },
     { id = "toplam", ad = "Daldaki toplam kademe" },
     { id = "2", ad = "2" }, { id = "3", ad = "3" }, { id = "4", ad = "4" },
     { id = "5", ad = "5" }, { id = "6", ad = "6" }, { id = "7", ad = "7" },
}
local BECERI_AD = {}
for _, b in ipairs(G.GelisimBeceriSecim) do BECERI_AD[b.id] = b.ad end

local KARSILASTIR = { { id = ">=", ad = "≥" }, { id = "==", ad = "=" }, { id = "<", ad = "<" } }

local function Tersi(alanlar)
     alanlar[#alanlar + 1] = { k = "tersi", ad = "Tersi (değilse)", tip = "bool", v = false }
     return alanlar
end

Kaydet("Kosul", "gelisim_dal", {
     ad = "Gelişim dalı (rol)",
     aciklama = "Karakter Gelişimi'nde ilk puan verilen 2 dal ana, 3. dal yan olur. 'Rolsüz' = hiç seçilmemiş ya da 4× maliyetle alınmış dal.",
     alanlar = Tersi({
          { k = "dal", ad = "Dal", tip = "secim", v = "sifa", secenekler = DAL_KOSUL },
          { k = "rol", ad = "Rol", tip = "secim", v = "ikisi", secenekler = ROLLER },
     }),
     ozet = function(e) return G.GelisimDalAd(e.dal) .. ": " .. (ROL_AD[e.rol] or "?") end,
})

Kaydet("Kosul", "gelisim_kademe", {
     ad = "Gelişim kademesi",
     aciklama = "Daldaki bir yetkinliğin (ya da bir sıranın en yükseğinin / toplamın) kademesi.",
     alanlar = Tersi({
          { k = "dal", ad = "Dal", tip = "secim", v = "sifa", secenekler = G.GelisimDallari },
          { k = "beceri", ad = "Yetkinlik", tip = "secim", v = "1", secenekler = G.GelisimBeceriSecim },
          { k = "islem", ad = "Karşılaştırma", tip = "secim", v = ">=", secenekler = KARSILASTIR },
          { k = "deger", ad = "Kademe", tip = "sayi", v = 1, min = 0, max = 40 },
     }),
     ozet = function(e)
          return G.GelisimDalAd(e.dal) .. " " .. (BECERI_AD[e.beceri] or "?") .. " " .. (e.islem == "==" and "=" or e.islem == "<" and "<" or "≥") .. " " .. tostring(e.deger)
     end,
})

Kaydet("Kosul", "hane_icinde", {
     ad = "Kendi hanesinde",
     aciklama = "Oyuncu kendi hanesinin ortak salonunda / yatakhanesinde (rp_sh2 kutuları sv_9b_kopru.lua'da).",
     alanlar = Tersi({}),
     ozet = function() return "kendi hanesinde" end,
})

Kaydet("Odul", "dal_puan", {
     ad = "Puntos de ramo",
     aciklama = "O dala sabit XP (1 puan = 500 XP; Yorgunluk ve İlham uygulanmaz). 2026-11-09'dan beri dal puanı yerine dal XP'si.",
     alanlar = {
          { k = "dal", ad = "Dal", tip = "secim", v = "sifa", secenekler = G.GelisimDallari },
          { k = "miktar", ad = "Puan", tip = "sayi", v = 1, min = 1, max = 20 },
     },
     ozet = function(e) return (e.miktar or 1) .. " " .. G.GelisimDalAd(e.dal) .. " puanı" end,
})

/*
*   Yarım Kalmış Defter
*/
G.DefterEsya = "yarim_defter"

do
     local ITEM = ix.item.Register(G.DefterEsya, nil, false, nil, true)
     ITEM.name = "Yarım Kalmış Defter"
     ITEM.description = "Deri kapaklı, köşeleri yıpranmış eski bir defter. Sayfaların çoğu boş; ama ara sıra, kimse yazmadan mürekkep kendiliğinden beliriyor."
     ITEM.model = "models/staylofft/hogwarts_books/staylofft_ancient_magic_book.mdl"
     ITEM.category = "Görev"
     ITEM.width = 1
     ITEM.height = 1
     ITEM.noBusiness = true
     ITEM.functions = ITEM.functions or {}
     ITEM.functions.Oku = {
          name = "Oku",
          icon = "icon16/book_open.png",
          OnClick = function(item)
               if SardonGorev and SardonGorev.RehberAc then SardonGorev.RehberAc("aktif") end
               return false
          end,
          OnRun = function() return false end,
          OnCanRun = function(item) return not IsValid(item.entity) end,
     }
end
