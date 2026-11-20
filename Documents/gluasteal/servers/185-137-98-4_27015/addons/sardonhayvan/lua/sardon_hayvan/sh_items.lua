-- "addons\\sardonhayvan\\lua\\sardon_hayvan\\sh_items.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Hayvanlardan düşen ganimet eşyaları. Hangi hayvandan ne oranla düştüğü
-- sv_ganimet.lua'da. Var olan başka Helix eşyaları da düşürülebilir; bunlar
-- sadece hayvana özgü parçalar.

SardonHayvan.Esyalar = {
     {id = "hayvan_post",         ad = "Hayvan Postu",        aciklama = "Kalın, işlenmemiş bir post.",                          model = "models/props_junk/garbage_bag001a.mdl"},
     {id = "hayvan_dis",          ad = "Keskin Diş",          aciklama = "Bir yırtıcının sivri dişi.",                           model = "models/gibs/antlion_gib_small_1.mdl"},
     {id = "hayvan_pence",        ad = "Pençe",               aciklama = "Kıvrık ve hâlâ keskin bir pençe.",                     model = "models/gibs/antlion_gib_small_2.mdl"},
     {id = "hayvan_kemik",        ad = "Hayvan Kemiği",       aciklama = "Temizlenmiş bir kemik parçası.",                       model = "models/gibs/hgibs_scapula.mdl"},
     {id = "hayvan_kus_tuyu",     ad = "Kuş Tüyü",            aciklama = "Yumuşak, hafif bir tüy.",                              model = "models/gibs/antlion_gib_small_3.mdl"},
     {id = "hayvan_grifon_tuyu",  ad = "Grifon Tüyü",         aciklama = "Altın sarısı, sert bir grifon tüyü.",                  model = "models/gibs/antlion_gib_small_3.mdl"},
     {id = "hayvan_anka_tuyu",    ad = "Anka Tüyü",           aciklama = "Dokununca hafifçe ısınan, nadir bir tüy.",             model = "models/gibs/antlion_gib_small_3.mdl"},
     {id = "hayvan_ejderha_pulu", ad = "Ejderha Pulu",        aciklama = "Ateşe dayanıklı, parlak bir pul.",                     model = "models/props_junk/rock001a.mdl"},
     {id = "hayvan_ejderha_kani", ad = "Ejderha Kanı",        aciklama = "Şişede kaynar gibi duran koyu kan.",                   model = "models/props_lab/jar01b.mdl"},
     {id = "hayvan_wyvern_pulu",  ad = "Wyvern Pulu",         aciklama = "Wyvern sırtından kopmuş kalın bir pul.",               model = "models/props_junk/rock001a.mdl"},
     {id = "hayvan_mantikor_igne",ad = "Mantikor İğnesi",     aciklama = "Ucunda zehir izi olan kuyruk iğnesi.",                 model = "models/gibs/antlion_gib_medium_2.mdl"},
     {id = "hayvan_akrep_zehri",  ad = "Akrep Zehri",         aciklama = "Küçük bir şişede yoğun zehir.",                        model = "models/props_lab/jar01a.mdl"},
     {id = "hayvan_yilan_derisi", ad = "Yılan Derisi",        aciklama = "Pul desenli, esnek bir deri.",                         model = "models/props_junk/garbage_newspaper001a.mdl"},
     {id = "hayvan_kurbaga_salgi",ad = "Kurbağa Salgısı",     aciklama = "Yapışkan, keskin kokulu bir salgı.",                   model = "models/props_junk/glassjug01.mdl"},
     {id = "hayvan_kurtadam_kili",ad = "Kurt Adam Kılı",      aciklama = "Dolunay gecesi toplanmış sert kıllar.",                model = "models/gibs/hgibs_rib.mdl"}
}

for _, e in ipairs(SardonHayvan.Esyalar) do
     local ITEM = ix.item.Register(e.id, nil, false, nil, true)

     ITEM.name = e.ad
     ITEM.description = e.aciklama
     ITEM.model = e.model
     ITEM.category = "Hayvan Ganimeti"
     ITEM.width = 1
     ITEM.height = 1
end
