-- "addons\\sardongelisim\\lua\\sardon_gelisim\\_sh_xp.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gelişim :: dalların XP kaynakları (ekranda gösterilen metinler) ve dal renkleri.
-- _sh_config.lua ve _sh_config_veri.lua'dan sonra yüklenir (alfabetik). Sayılar sunucuda sv_xp.lua'da.

local G = SardonGelisim

-- Her dalın yüksek (asıl) ve düşük XP kaynağı — 2026-11-09 kullanıcı listesi
G.DalKaynaklari = {
     sifa = {yuksek = "Guardia en enfermería", dusuk = "Curar heridos", is = "guardia"},
     baskalasim = {yuksek = "Camino del Animago · forma animal", dusuk = "Mesa de transformación", is = "transformación"},
     tilsim = {yuksek = "Ritual de encantamientos", dusuk = "Fabricar encantamientos en bruto", is = "ritual"},
     lanet = {yuksek = "Próximamente", dusuk = "Impacto de maldiciones", is = "impacto"},
     syb = {yuksek = "Incubación · apareamiento", dusuk = "Cuidado · cariño · adiestramiento", is = "cuidado"},
     iksir = {yuksek = "Preparar pociones", dusuk = "Recoger ingredientes", is = "poción"},
     ksks = {yuksek = "Armario de los Boggarts", dusuk = "Práctica de contrahechizos", is = "encuentro"},
     botanik = {yuksek = "Cultivo · cosecha", dusuk = "Uso de plantas en combate", is = "cosecha"},
}

-- HUD şeridi ve ekran için dal renkleri
G.DalRenk = {
     sifa = Color(120, 200, 150),
     baskalasim = Color(170, 150, 230),
     tilsim = Color(110, 170, 235),
     lanet = Color(200, 90, 85),
     syb = Color(205, 165, 95),
     iksir = Color(120, 210, 190),
     ksks = Color(225, 190, 110),
     botanik = Color(140, 200, 95),
}