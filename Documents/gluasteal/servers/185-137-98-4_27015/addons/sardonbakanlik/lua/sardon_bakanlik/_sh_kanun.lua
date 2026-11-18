-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\_sh_kanun.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Bakanlık :: Código penal (artículos por defecto).
-- para = Galleon, hapis = saniye (Azkaban), agir 1 infracción / 2 delito / 3 delito grave.
-- Bakan defterden para ve hapis değerlerini değiştirebilir; değişiklik sb_ayar "kanun"
-- kaydında tutulur ve B.KanunDegisiklik ile iki tarafa da uygulanır (madde metinleri sabit).

local B = SardonBakanlik

B.KanunBolumleri = {
     {id = "karanlik", ad = "Artes Oscuras"},
     {id = "kisi", ad = "Contra las personas"},
     {id = "mal", ad = "Contra bienes y el orden"},
     {id = "bakanlik", ad = "Contra el Ministerio"},
     {id = "kayit", ad = "Registro y licencias"},
}

B.KanunVarsayilan = {
     {kod = "KS-1", bolum = "karanlik", ad = "Usar una maldición imperdonable", para = 0, hapis = 900, agir = 3,
          aciklama = "Avada Kedavra, Crucio o Imperius contra una persona. Un solo uso exige la pena máxima en Azkaban."},
     {kod = "KS-2", bolum = "karanlik", ad = "Convocar la Marca Tenebrosa", para = 0, hapis = 600, agir = 3,
          aciclama = "Lanzar Morsmordre y elevar la Marca Tenebrosa al cielo."},
     {kod = "KS-3", bolum = "karanlik", ad = "Herir con magia oscura", para = 20, hapis = 300, agir = 2,
          aciclama = "Herir a un mago con una maldición o hechizo de magia oscura."},
     {kod = "KS-4", bolum = "karanlik", ad = "Poseer objetos oscuros prohibidos", para = 25, hapis = 120, agir = 2,
          aciclama = "Tener, vender u ocultar objetos, pociones o libros de Artes Oscuras."},

     {kod = "KK-1", bolum = "kisi", ad = "Asesinar a un mago", para = 0, hapis = 900, agir = 3,
          aciclama = "Causar intencionadamente la muerte de un mago."},
     {kod = "KK-2", bolum = "kisi", ad = "Agresión", para = 10, hapis = 120, agir = 2,
          aciclama = "Atacar con hechizos a un mago sin permiso de duelo."},
     {kod = "KK-3", bolum = "kisi", ad = "Legilimencia sin consentimiento", para = 20, hapis = 120, agir = 2,
          aciclama = "Usar Legilimens contra alguien que no lo ha autorizado."},
     {kod = "KK-4", bolum = "kisi", ad = "Alterar la memoria sin permiso", para = 25, hapis = 180, agir = 2,
          aciclama = "Aplicar Obliviate sin ser Obliviator autorizado."},
     {kod = "KK-5", bolum = "kisi", ad = "Privación de libertad", para = 15, hapis = 180, agir = 2,
          aciclama = "Atar o arrastrar a un mago sin autoridad."},

     {kod = "MD-1", bolum = "mal", ad = "Allanamiento y robo en vivienda", para = 30, hapis = 240, agir = 2,
          aciclama = "Entrar por la fuerza en el hogar de un mago y robar sus pertenencias."},
     {kod = "MD-2", bolum = "mal", ad = "Poseer objetos robados", para = 15, hapis = 60, agir = 1,
          aciclama = "Llevar consigo o vender bienes procedentes de un robo."},
     {kod = "MD-3", bolum = "mal", ad = "Daño mágico", para = 15, hapis = 0, agir = 1,
          aciclama = "Dañar con hechizos bienes públicos o ajenos."},
     {kod = "MD-4", bolum = "mal", ad = "Alteración del orden público", para = 8, hapis = 0, agir = 1,
          aciclama = "Peleas, disturbios o hechizos peligrosos en aglomeraciones."},
     {kod = "MD-5", bolum = "mal", ad = "Maltrato a criaturas mágicas", para = 20, hapis = 60, agir = 1,
          aciclama = "Cazar sin permiso o dañar a una criatura protegida."},

     {kod = "BK-1", bolum = "bakanlik", ad = "Resistencia a agentes", para = 20, hapis = 240, agir = 2,
          aciclama = "Atacar u oponerse a un auror o funcionario del Ministerio en servicio."},
     {kod = "BK-2", bolum = "bakanlik", ad = "Fuga de detención o de Azkaban", para = 0, hapis = 300, agir = 3,
          aciclama = "Escapar de las ataduras o ayudar a un detenido a fugarse."},
     {kod = "BK-3", bolum = "bakanlik", ad = "Daños a bienes del Ministerio", para = 25, hapis = 120, agir = 2,
          aciclama = "Destruir un sinsioscopio, tablón de decretos u otro equipo del Ministerio."},
     {kod = "BK-4", bolum = "bakanlik", ad = "Violar un tabú", para = 15, hapis = 60, agir = 1,
          aciclama = "Pronunciar en voz alta una palabra bajo tabú del Ministerio."},
     {kod = "BK-5", bolum = "bakanlik", ad = "Desacato al Wizengamot", para = 20, hapis = 120, agir = 1,
          aciclama = "No comparecer, alterar una vista o desobedecer la sentencia."},
     {kod = "BK-6", bolum = "bakanlik", ad = "Denuncia falsa y testimonio mendaz", para = 10, hapis = 0, agir = 1,
          aciclama = "Engañar deliberadamente al Ministerio."},
     {kod = "BK-7", bolum = "bakanlik", ad = "Impago de multas", para = 10, hapis = 60, agir = 1,
          aciclama = "No pagar una deuda vencida con el Ministerio."},
     {kod = "BK-8", bolum = "bakanlik", ad = "Negarse a mostrar la identidad", para = 5, hapis = 0, agir = 1,
          aciclama = "No presentar el documento de identidad cuando un agente lo exige en servicio."},

     {kod = "KR-1", bolum = "kayit", ad = "Animagus sin registro", para = 40, hapis = 120, agir = 2,
          aciclama = "Tomar forma animal sin estar inscrito como Animagus."},
     {kod = "KR-2", bolum = "kayit", ad = "No registrarse como hombre lobo", para = 30, hapis = 0, agir = 1,
          aciclama = "Ocultar al Ministerio la condición de licántropo."},
     {kod = "KR-3", bolum = "kayit", ad = "Aparición sin licencia", para = 10, hapis = 0, agir = 1,
          aciclama = "Aparatar sin licencia de aparición."},
     {kod = "KR-4", bolum = "kayit", ad = "Hechizos fuera del colegio siendo menor", para = 5, hapis = 0, agir = 1,
          aciclama = "Infracción del decreto de restricción razonable para magos menores de edad."},
     {kod = "KR-5", bolum = "kayit", ad = "Duelo sin permiso", para = 12, hapis = 0, agir = 1,
          aciclama = "Duelar en público sin licencia de duelo."},
     {kod = "KR-6", bolum = "kayit", ad = "Portar identidad falsa", para = 25, hapis = 120, agir = 2,
          aciclama = "Llevar o mostrar un documento de identidad falso no registrado en el Ministerio."},
     {kod = "KR-7", bolum = "kayit", ad = "Usar la identidad ajena", para = 20, hapis = 60, agir = 2,
          aciclama = "Presentar como propio un documento de otra persona o denunciado como perdido."},
     {kod = "KR-8", bolum = "kayit", ad = "Circular sin identidad", para = 2, hapis = 0, agir = 1,
          aciclama = "No llevar documento de identidad cuando se exige (si la pérdida no fue comunicada en ventanilla)."},
}
}

B.Kanun = B.Kanun or {}
B.KanunIndex = B.KanunIndex or {}

-- degisiklik: {[kod] = {para = n, hapis = n}} (yalnız değişenler)
function B.KanunDegisiklik(degisiklik)
     B.Kanun, B.KanunIndex = {}, {}
     for i, m in ipairs(B.KanunVarsayilan) do
          local k = {kod = m.kod, bolum = m.bolum, ad = m.ad, aciklama = m.aciklama, agir = m.agir, para = m.para, hapis = m.hapis}
          local d = istable(degisiklik) and degisiklik[m.kod]
          if istable(d) then
               if tonumber(d.para) then k.para = math.Clamp(math.floor(tonumber(d.para)), 0, B.Ayar.CezaAzami) end
               if tonumber(d.hapis) then k.hapis = math.Clamp(math.floor(tonumber(d.hapis)), 0, B.Ayar.AzamiHapis) end
               k.degisti = (k.para ~= m.para) or (k.hapis ~= m.hapis)
          end
          B.Kanun[i] = k
          B.KanunIndex[k.kod] = k
     end
end

if #B.Kanun == 0 then B.KanunDegisiklik(nil) end

-- suclamalar: {{kod = "KS-1", adet = 1}, ...} -> toplam para, toplam hapis (tavanlı), en ağır derece
function B.KanunToplam(suclamalar, carpan)
     local para, hapis, agir = 0, 0, 0
     for _, s in ipairs(suclamalar or {}) do
          local m = B.KanunIndex[s.kod or ""]
          if m then
               local adet = math.Clamp(math.floor(tonumber(s.adet) or 1), 1, 9)
               para = para + m.para * adet
               hapis = hapis + m.hapis * adet
               agir = math.max(agir, m.agir)
          end
     end
     para = math.min(math.floor(para * (carpan or 1)), B.Ayar.CezaAzami)
     hapis = math.min(hapis, B.Ayar.AzamiHapis)
     return para, hapis, agir
end
