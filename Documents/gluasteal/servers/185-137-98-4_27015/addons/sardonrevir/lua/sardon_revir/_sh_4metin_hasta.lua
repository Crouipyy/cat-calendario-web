-- "addons\\sardonrevir\\lua\\sardon_revir\\_sh_4metin_hasta.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: hasta kimlikleri ve kişiliklere göre konuşma kalıpları.
-- Kalıp jetonları: {oyuncu} gönüllünün adı · {unvan} gönüllünün revir unvanı · {ad} hastanın adı
-- {hane} hastanın binası · {yil} hastanın yılı · {pomfrey} "Madam Pomfrey"
-- Hikâye ve belirti cümleleri hep cümle başına konur (_sh_7uretici), kalıplar ona göre yazıldı.
-- Her satırın bir anahtarı vardır (kategori.kişilik.sıra); üretici aynı gönüllüye yakın zamanda
-- söylenmiş satırı seçmez.

local R = SardonRevir

R.Adlar = {
     e = {"Tobias", "Cedric", "Rowan", "Elias", "Jasper", "Arthur", "Felix", "Oliver", "Silas", "Edmund",
          "Barnaby", "Ambrose", "Caspian", "Dorian", "Ezra", "Florian", "Gideon", "Hector", "Ignatius", "Julian",
          "Kenneth", "Leopold", "Magnus", "Nathaniel", "Oswin", "Percival", "Quentin", "Rufus", "Sebastian", "Theodore",
          "Ulric", "Victor", "Wilfred", "Alaric", "Benedict", "Cyril", "Desmond", "Emrys", "Fergus", "Galen",
          "Horace", "Isidore", "Lysander", "Mortimer", "Norbert", "Orion", "Phineas", "Reginald", "Septimus", "Tiberius"},
     k = {"Elara", "Hazel", "Ivy", "Luna", "Marigold", "Odette", "Pippa", "Rosalind", "Seraphina", "Thea",
          "Agatha", "Beatrix", "Clementine", "Daphne", "Eloise", "Flora", "Genevieve", "Harriet", "Isolde", "Juniper",
          "Lavinia", "Matilda", "Nerissa", "Ophelia", "Primrose", "Rowena", "Sybil", "Tabitha", "Ursula", "Violet",
          "Winifred", "Arabella", "Briony", "Cordelia", "Delphine", "Esme", "Fenella", "Gwendolyn", "Honora", "Imogen",
          "Juliet", "Lucinda", "Millicent", "Noelle", "Octavia", "Philippa", "Rosamund", "Sabrina", "Temperance", "Wilhelmina"}
}

R.Soyadlar = {"Ashdown", "Blackwood", "Crowley", "Dunstan", "Ellery", "Fawley", "Greengrass", "Hawthorne", "Ingleby", "Jorkins",
     "Kettleburn", "Lestrange", "Macmillan", "Nott", "Ollerton", "Prewett", "Quirke", "Rosier", "Selwyn", "Thistlewood",
     "Umber", "Vance", "Whitlock", "Yaxley", "Abbott", "Bones", "Corner", "Diggory", "Entwhistle", "Finch",
     "Goldstein", "Hopkins", "Jordan", "Kirke", "Midgen", "Perks", "Rivers", "Smethwyck", "Tolliver", "Wren",
     "Bagshot", "Cattermole", "Dawlish", "Fenwick", "Gamp", "Hornby", "Kingsley", "Lovell", "Marchbanks", "Pennifold"}

R.Haneler = {"Gryffindor", "Hufflepuff", "Ravenclaw", "Slytherin"}

-- hane → {erkek, kız} modeli. Asıl görünüm HL öğrenci gövdesi (_sh_7uretici O.Model + cl_2aktor HLGiydir);
-- bu yalnız HL yüklü değilken. 11-04: percival erkek]]kiz* karmamodels'la koleksiyondan çıktı -> giyimli hane modeli
local HS = "models/player/hogwartsrp/hogwarts_students/"
R.HaneModel = {
     Gryffindor = {HS .. "gryffindor/male1.mdl", HS .. "gryffindor/female1.mdl"},
     Hufflepuff = {HS .. "hufflepuff/male1.mdl", HS .. "hufflepuff/female1.mdl"},
     Ravenclaw = {HS .. "ravenclaw/male1.mdl", HS .. "ravenclaw/female1.mdl"},
     Slytherin = {HS .. "slytherin/male1.mdl", HS .. "slytherin/female1.mdl"}
}
R.PomfreyModel = "models/konnie/pomfrey/pomfrey.mdl"

R.Kisilikler = {
     {id = "dramatik", ad = "Dramatik"},
     {id = "korkak", ad = "Ürkek"},
     {id = "alayci", ad = "Alaycı"},
     {id = "kibar", ad = "Kibar"},
     {id = "utangac", ad = "Utangaç"},
     {id = "geveze", ad = "Geveze"},
     {id = "huysuz", ad = "Huysuz"},
     {id = "kitapkurdu", ad = "Kitap Kurdu"}
}

R.KisilikMetin = {
     dramatik = {
          selam = {
               "Sonunda biri geldi! Ölüyorum sandım, gerçekten. Hâlâ da sanıyorum.",
               "Sen misin? Tanrılara şükür. Vasiyetimi yazdırmak üzereydim.",
               "{oyuncu}, ne olur yanımdan ayrılma. Sanırım bu benim son gecem.",
               "Ah, bir şifacı! Bana ne kadar zamanım kaldığını dürüstçe söyle.",
               "Kimse beni ciddiye almıyor ama bu sefer gerçekten ciddi, yemin ederim.",
               "Bu revirden canlı çıkarsam bir şiir yazacağım. Sana.",
               "Işıkları kısın. Hayır, açın. Karanlıkta ölmek istemem.",
               "Biri ağlıyor mu? Ah, benmişim."
          },
          hikayeGiris = {"Her şey o kadar güzel başlamıştı ki...", "Sana baştan anlatmam lazım, yoksa anlamazsın.", "Hayatımın en karanlık anıydı.", "Bunu torunlarıma anlatacağım, yaşarsam.", "Kader, o gün bana sırtını döndü."},
          belirtiGiris = {"Anlatması bile acı veriyor.", "Dinle, bunu kimseye söylemedim.", "Hazır mısın? Çünkü korkunç."},
          belirtiAra = {"Ve bu daha başlangıçtı.", "Sanki bu yetmezmiş gibi...", "Ama asıl kötüsü şu."},
          belirtiYok = {"Tarif edemiyorum, kelimeler yetmiyor.", "Her şey acıyor ve hiçbir şey acımıyor, anlıyor musun?"},
          muayene = {"Yavaş ol, kırılgan bir ruhum var!", "Ah! Bunu hissettim. Kesin kötü bir şey bu.", "Yüzünü okuyorum, kötü haber değil mi?", "Elinde bir sihir var, biraz iyi geldi sanki."},
          tarama = {"O ışık ne? Ruhum mu görünüyor?", "Rengi kötü mü? Kötü, değil mi?", "Bir aura! Biliyordum, özel bir vaka olduğumu."},
          bekleme = {"Hâlâ buradayım... sanırım.", "Bu bekleyiş beni öldürecek, hastalıktan önce.", "Annem bunu duysa ilk Baykuş'la gelirdi.", "Son bir isteğim var: kimse günlüğümü okumasın."},
          yanlis = {"Ne yaptın?! Daha kötü oldum, hissediyorum!", "İşte bu son. Hoşça kal dünya.", "Bu kadarını hak etmedim!", "Bir şey ters gitti, değil mi? Gözlerinden anlıyorum."},
          tutmadi = {"Söndü mü? Benim gibi...", "Bir daha dene, ne olur. Yaşamak istiyorum.", "Kıvılcım bile benden kaçıyor."},
          iyilesti = {"Yaşıyorum! Gerçekten yaşıyorum! Seni asla unutmayacağım.", "Mucize! Bu bir mucize! Herkese anlatacağım.", "Bana hayatımı geri verdin, {oyuncu}. Abartmıyorum. Biraz abartıyorum.", "Işık gördüm sandım ama senin asanmış. Teşekkürler.", "Bunu Gelecek Postası'na yazdırmalıyım!"},
          veda = {"Seni ölene kadar hatırlayacağım. Ki bugün değilmiş.", "Hoşça kal, kahramanım.", "Bir dahaki trajedimde yine seni isteyeceğim."},
          rahatlat = {"Gerçekten mi? Söz mü?", "Biraz... biraz daha iyi hissediyorum. Sadece biraz.", "Sesin çok güven verici. Devam et konuşmaya."},
          sohbet = {"{hane}. Ama şu an hiçbir binanın umurunda değilim.", "{yil}. yıl. Mezun olamadan gidecektim neredeyse!", "{hane} ortak salonunda herkes beni merak ediyordur. Etmiyordur aslında."}
     },
     korkak = {
          selam = {
               "Ş-şifacı mısın? Acıtacak mı?",
               "Merhaba... asanı biraz uzak tutar mısın? Sadece şimdilik.",
               "Madam Pomfrey nerede? Sen de iyisin, yani... umarım.",
               "Özür dilerim, ellerim titriyor. Hep titrer zaten.",
               "Lütfen kimseye ağladığımı söyleme.",
               "İğne yok, değil mi? Büyücülerde iğne olmaz, değil mi?",
               "Pomfrey kızgın mı? Bana kızgın mı?",
               "Burası çok sessiz... sessizlik iyi mi kötü mü?"
          },
          hikayeGiris = {"Anlatmaya korkuyorum ama...", "Ö-önce söz ver, kızmayacaksın.", "Bir anda oldu, ne olduğunu anlamadım bile.", "Gözlerimi kapattım, açtığımda her şey olmuştu.", "Korkudan bağırdım, sonra... şey..."},
          belirtiGiris = {"Şey... nasıl söylesem.", "Belki önemli değildir ama...", "Galiba bir şey var."},
          belirtiAra = {"Bir de... bir şey daha var.", "Söylemesem mi? Yok, söyleyeyim.", "Ve, ıı..."},
          belirtiYok = {"Bilmiyorum, sadece kötüyüm.", "Korkudan bir şey hissedemiyorum ki."},
          muayene = {"Soğuk! Ellerin soğuk!", "Acıtma, lütfen acıtma.", "Tamam... tamam, dayanabilirim.", "Ne buldun? Söyleme. Hayır, söyle."},
          tarama = {"O ışık bana bir şey yapmaz, değil mi?", "Gözlerimi kapatabilir miyim?", "Asan çok parlıyor..."},
          bekleme = {"Sen buradasın, değil mi? Gitmedin?", "Kapının orada bir ses duydum sanki.", "Biraz daha yakında durur musun?", "Pomfrey birazdan gelir, değil mi?"},
          yanlis = {"Ne oldu?! Bir şey mi yanlış gitti?", "Daha kötü oldu! Ağlayacağım!", "Lütfen dur, lütfen!", "Biliyordum böyle olacağını..."},
          tutmadi = {"Olmadı mı? Benim yüzümden mi?", "Bir daha mı deneyeceksin? Peki...", "Kıpırdamamaya çalışıyorum, söz."},
          iyilesti = {"Geçti mi? Gerçekten geçti mi?", "Hiç acımadı! Yani biraz acıdı ama... teşekkürler!", "Sana sarılabilir miyim? Sadece bir saniye.", "Bir dahakine korkmayacağım. Belki biraz korkarım.", "Çok naziktin, teşekkür ederim {oyuncu}."},
          veda = {"Bir daha buraya düşmemeye çalışacağım.", "Hoşça kal... ve teşekkürler.", "Koridorda görürsen selam ver, olur mu?"},
          rahatlat = {"Tamam. Sana güveniyorum.", "Nefes alıyorum... nefes alıyorum...", "Söz mü? Gerçekten söz mü?"},
          sohbet = {"{hane}... Şapka uzun süre düşündü.", "{yil}. yıldayım. Hâlâ merdivenlerde kayboluyorum.", "Ortak salonda bir köşem var, orada otururum hep."}
     },
     alayci = {
          selam = {
               "Bak sen, gönüllü şifacı. Sigortan var mı?",
               "Hoş geldin. Kusura bakma, ayağa kalkıp karşılayamadım.",
               "Madam Pomfrey'in bütçesi kesildi galiba, sen geldin.",
               "Durumum harika, gördüğün gibi. Tatildeyim.",
               "Tahmin edeyim: 'Neren ağrıyor?' diye soracaksın.",
               "Revirin yemek servisi var mı? Sormak lazım.",
               "Biri bana çiçek getirir diye bekliyorum. Boşuna.",
               "Merak etme, sana iyi bir yorum yazacağım. Belki."
          },
          hikayeGiris = {"Kısa versiyonu: aptallık. Uzun versiyonu:", "Gurur duyduğum bir an değildi.", "Bunu hikâye diye anlatmak bile ayıp ama dinle.", "Bir planım vardı. Plan kötüymüş.", "Kahramanlık yapmak istedim, gerisini tahmin et."},
          belirtiGiris = {"Belirtiler mi? Bol bol var.", "Seçmeli mi istersin, hepsi mi?", "Sırayla gidelim, not al istersen."},
          belirtiAra = {"Hepsi bu değil tabii.", "Bonus olarak da...", "Ve sürpriz:"},
          belirtiYok = {"Aslında harikayım. Sadece yatmayı seviyorum.", "Bir şey hissetmiyorum. Bu da iyiye işaret değil sanırım."},
          muayene = {"Nazik ol, ben antika sayılırım.", "Ay. Bu da tedavinin parçası mı?", "Doktor oyununu ilk kez mi oynuyorsun?", "Bulursan bana da söyle."},
          tarama = {"Güzel ışık. Odama da lazım.", "Ruhumu mu okuyorsun? İyi şanslar.", "Rengim neymiş? Kibar ol."},
          bekleme = {"Acele etme, nasılsa hiçbir yere gitmiyorum. Gidemiyorum.", "Burada yatmak dersten iyi en azından.", "Tavanı ezberledim. Kırk iki çatlak var.", "Kitap getirseydim keşke. Neyse, kitap da okumuyorum."},
          yanlis = {"Harika. Tam da ihtiyacım olan şey.", "Bunu kasten mi yaptın? Saygı duyarım.", "Bir yıldız veriyorum bu tedaviye.", "Pomfrey'i çağırmanın tam vakti."},
          tutmadi = {"Etkileyici. Hiçbir şey olmadı.", "Bu sefer büyü çekindi galiba.", "Tekrar dene, ben buradayım. Maalesef."},
          iyilesti = {"Vay. İşini biliyormuşsun.", "Pekâlâ, itiraf ediyorum: iyiydin.", "Teşekkürler. Bunu kimseye söyleme, imajım bozulur.", "Bana borçlu kaldın, bu hikâyeyi herkese senin adınla anlatacağım.", "İyileştim. Şimdi dersi kaçırmak için yeni bahane lazım."},
          veda = {"Görüşmek üzere. Umarım burada değil.", "Bir dahaki sefere randevu alırım.", "Hoşça kal, {unvan}."},
          rahatlat = {"Sakinim zaten. Sakin olmayan sensin.", "Peki, sana inanıyorum. Şimdilik.", "Duygusal anlar beni gerer, devam et işine."},
          sohbet = {"{hane}. Tahmin etmen gerekirdi.", "{yil}. yıl. Yaşlılık başlıyor.", "Ortak salonda bensiz partiler sönük geçiyor, öyle diyorlar."}
     },
     kibar = {
          selam = {
               "Merhaba, zahmet ettiniz. Çok teşekkür ederim.",
               "Kusura bakmayın, sizi de meşgul ettim.",
               "İyi günler. Sanırım biraz yardıma ihtiyacım var.",
               "{oyuncu}, değil mi? Hakkınızda güzel şeyler duydum.",
               "Rahatsız ettiğim için özür dilerim, başka çarem kalmadı.",
               "Madam Pomfrey çok yoğun, size emanet etti sanırım.",
               "Nöbetiniz hayırlı olsun. Size yük olmamaya çalışacağım.",
               "Elinizdeki asa çok güzel, bu arada."
          },
          hikayeGiris = {"İzin verirseniz anlatayım.", "Aslında oldukça utanç verici ama dürüst olmalıyım.", "Şöyle oldu efendim.", "Olayları sırasıyla aktarmaya çalışayım.", "Kimseyi suçlamak istemem ama..."},
          belirtiGiris = {"Elimden geldiğince tarif edeyim.", "Size yardımcı olacaksa şunları söyleyebilirim.", "Şöyle hissediyorum."},
          belirtiAra = {"Bir de şunu eklemeliyim.", "Önemli olabilir diye söylüyorum.", "Ayrıca..."},
          belirtiYok = {"Özel bir şey söyleyemeyeceğim, kusura bakmayın.", "Tam tarif edemiyorum, affedin."},
          muayene = {"Tabii, buyurun.", "Hiç sorun değil, rahat olun.", "Biraz acıdı ama önemli değil.", "Çok dikkatlisiniz, teşekkürler."},
          tarama = {"Ne güzel bir ışık.", "Merak ettim, ne görüyorsunuz?", "Buyurun, kıpırdamıyorum."},
          bekleme = {"Acele etmeyin lütfen, ben beklerim.", "Başka hastalarınız varsa önce onlara bakın.", "Revir ne kadar huzurlu bir yer.", "Size bir bardak su getirmelerini isteyeyim mi? Ah, hasta olan benim."},
          yanlis = {"Ah... sanırım bir şey ters gitti, ama sorun değil.", "Biraz kötüleştim galiba, kızmadım ama.", "Endişelenmeyin, herkes hata yapar.", "Belki bir kez daha defteri kontrol etseniz?"},
          tutmadi = {"Acele etmeyin, olur.", "Bir dahaki denemede olacak, eminim.", "Hiç sorun değil."},
          iyilesti = {"Çok teşekkür ederim, gerçekten.", "Size minnettarım. Hanemize bunu anlatacağım.", "Ne kadar iyi geldi, ellerinize sağlık.", "Size nasıl teşekkür etsem bilmiyorum.", "Mükemmel bir iş çıkardınız."},
          veda = {"İyi nöbetler dilerim.", "Hoşça kalın, kendinize iyi bakın.", "Tekrar teşekkürler, iyi günler."},
          rahatlat = {"Çok naziksiniz.", "Sizinle güvendeyim.", "Teşekkür ederim, gerçekten iyi geldi."},
          sohbet = {"{hane} binasındanım.", "{yil}. yıldayım, yakında sınavlar başlıyor.", "Ortak salonumuzun şöminesi çok güzeldir, bir gün görmelisiniz."}
     },
     utangac = {
          selam = {"...merhaba.", "Ah. Sen. Merhaba.", "Ö-özür dilerim, kızarıyorum.", "Bakma lütfen, saçım berbat.", "Ben... şey... buradayım.",
               "Kimse görmedi değil mi beni buraya gelirken?",
               "...sen gönüllüsün, değil mi? Tamam.",
               "Merhaba. Ben sessiz dururum."},
          hikayeGiris = {"Şey... söylemesi zor.", "Kimseye söylemezsin, değil mi?", "Aptalca bir şeydi.", "...anlatsam güler misin?", "Kimse görmüyordu sanmıştım."},
          belirtiGiris = {"Galiba...", "Sanırım şöyle.", "Fark ettiğim kadarıyla..."},
          belirtiAra = {"Bir de...", "Şey... ayrıca...", "Bu da var."},
          belirtiYok = {"Bilmiyorum...", "Sadece... kötüyüm."},
          muayene = {"...tamam.", "Gıdıklanıyorum.", "Ah. Pardon.", "Bitti mi?"},
          tarama = {"...", "Herkes görüyor mu bu ışığı?", "Utanç verici."},
          bekleme = {"...", "Sessiz olmak istedim, rahatsız etmeyeyim diye.", "Sen de bekleyebilirsin, ben acele etmiyorum.", "Burası çok sessiz. Seviyorum."},
          yanlis = {"Ah... kötü oldu.", "Sorun değil... galiba.", "Biraz... daha kötü.", "Ben bir şey mi yaptım?"},
          tutmadi = {"Olmadı mı?", "Tekrar... dene.", "Ben kıpırdamadım, söz."},
          iyilesti = {"Teşekkür ederim... gerçekten.", "Çok iyisin.", "Geçti. Hiç beklemiyordum.", "Bu... çok güzeldi. Teşekkürler.", "Sana bir kurabiye borçluyum. Belki iki."},
          veda = {"Görüşürüz... belki.", "Hoşça kal.", "Ben... gideyim."},
          rahatlat = {"...teşekkürler.", "Tamam.", "Gülümsedin, iyi geldi."},
          sohbet = {"{hane}.", "{yil}. yıl.", "Ortak salonda pek konuşmam."}
     },
     geveze = {
          selam = {
               "Selam! Adım {ad}, ama zaten biliyorsundur, herkes bilir. Bilmiyor musun?",
               "Hey, yeni şifacı! Pomfrey'in yanında çalışmak nasıl? Sert midir? Bana hep sert davranır.",
               "Sen de mi gönüllüsün? Geçen yıl ben de olacaktım ama sonra başka bir şey oldu, uzun hikâye.",
               "Ooo {oyuncu}! Seni Büyük Salon'da gördüm, hep yanlış masada oturuyordun sanki.",
               "Merhaba merhaba! Burası ne kadar beyaz değil mi? Her şey beyaz. Perdeler bile.",
               "Sen nöbetçi şifacı mısın? Kaç hasta baktın bugün? Ben kaçıncıyım? Birinci olmak isterdim!",
               "Biliyor musun, geçen ay da buradaydım, şu yatakta değil, öbüründe, o daha yumuşaktı.",
               "Hey! Anlatacak çok şeyim var, önce hangisinden başlasam?"
          },
          hikayeGiris = {"Dur dur, baştan anlatayım, çünkü bağlantılı.", "Şimdi önce şunu bilmen lazım:", "Komik hikâye aslında, yani bana olmasa komik olurdu.", "Olay şöyle gelişti, dikkatli dinle çünkü çok detay var:", "Hiç inanmayacaksın ama:"},
          belirtiGiris = {"Belirtiler mi, saymakla bitmez!", "Bir dakika, sırayla gideyim.", "Şöyle ki:"},
          belirtiAra = {"Bekle, dahası var!", "Bunu unutuyordum:", "Ha bir de, çok önemli:"},
          belirtiYok = {"Valla tam bilmiyorum ama sana başka bir şey anlatayım mı?", "Bir şey yok gibi ama her şey var gibi, anlatabildim mi?"},
          muayene = {"Ooo profesyonel! Pomfrey de tam böyle yapıyor.", "Bunu nereden öğrendin? Kitaptan mı?", "Dur gülmemeye çalışayım. Olmuyor.", "Bende ne var? Nadir bir şey mi? Nadir olsun lütfen."},
          tarama = {"Vay be, ışık şov! Herkes görsün.", "Bu rengin adı ne? Benim favorim mor.", "Bunu bana da öğretir misin sonra?"},
          bekleme = {"Bu arada geçen gün Büyük Salon'da biri balkabağı suyunu kafasından döktü, gördün mü?", "Pomfrey'in çayı hep soğuk, fark ettin mi?", "Sence bu yatakları kim yapıyor? Ev cinleri mi?", "Kütüphanede yasak bölümde bir kitap var, kapağı ısırıyor, biliyor muydun?"},
          yanlis = {"Ay ay ay! Bu planın bir parçası mıydı?", "Tamam bu kötü oldu ama hikâyesi güzel olacak!", "Bunu kimseye anlatmayacağım. Herkese anlatacağım.", "Daha kötü oldum ama en azından ilginç!"},
          tutmadi = {"Hiç olmadı mı? Ben gördüm ama bir kıvılcım!", "Bir daha bir daha!", "Sanırım büyü utandı."},
          iyilesti = {"Harikasın! Herkese anlatacağım, yemin ederim herkese!", "Oley! Hemen ortak salona gidip anlatmalıyım!", "Bu revir tarihine geçer. Ben geçiririm.", "Biliyor musun, sen gelmeden önce Pomfrey 'iki gün yatarsın' demişti!", "Seni seviyorum! Yani, şifacı olarak. Anladın sen."},
          veda = {"Hadi bay bay! Yarın görüşürüz! Yani hasta olmadan!", "Bu hikâyeyi on kişiye anlatacağım, haberin olsun.", "Görüşürüz {oyuncu}! Ben gidiyorum, gerçekten gidiyorum, şimdi gidiyorum."},
          rahatlat = {"Tamam tamam, sakinim. Hiç bu kadar sakin olmamıştım. Bu da garip.", "Sen iyi birisin, belli.", "Peki ama bitince bana her şeyi anlat!"},
          sohbet = {"{hane}! En iyi bina, tartışmaya kapalı. Tartışalım mı?", "{yil}. yıl, ama ruhen yedinci yıldayım.", "{hane} ortak salonunun şifresini söyleyemem. Söyleyeyim mi?"}
     },
     huysuz = {
          selam = {"Ne var?", "Pomfrey nerede? Sen kimsin?", "Bekletildiğim süreyi not ettim.", "Bir şey yapacaksan yap, beni seyretme.", "Gönüllü mü? Harika. Deneme tahtasıyım yani.",
               "Çabuk ol, dersim var. Yoktu aslında ama olsun.",
               "Bana acıyarak bakma.",
               "İyi bir sebebin olsun da beni uyandırdın."},
          hikayeGiris = {"Kısaca söyleyeyim, uzatmaya niyetim yok.", "Benim suçum değildi, baştan söyleyeyim.", "Sorma da anlatayım.", "Saçma bir kazaydı, uzatmayacağım.", "Kimsenin suçu değil. Herkesin suçu."},
          belirtiGiris = {"Belirti mi istiyorsun? Al.", "Not alacaksan hızlı al.", "Şöyle:"},
          belirtiAra = {"Bir de bu var, maalesef.", "Yetmezmiş gibi...", "Tabii ki bir de şu."},
          belirtiYok = {"Bilmiyorum, şifacı sensin.", "Hiçbir şey. Her şey. Sen bul."},
          muayene = {"Nazik ol!", "Of. Bitti mi?", "Ellerin buz gibi.", "Bunun için mi bekledim?"},
          tarama = {"Gözüme tutma şu ışığı.", "Ne görüyorsan söyle, bilmece istemem.", "Hızlı ol."},
          bekleme = {"Hâlâ bekliyorum.", "Bu revirde zaman durmuş.", "Pomfrey olsa çoktan bitirmişti.", "Ben burada yatıyorum, ortak salonda herkes eğleniyor."},
          yanlis = {"Harika! Şimdi daha da kötüyüm!", "Ne yaptığını biliyor musun sen?", "Pomfrey'i çağır. Hemen.", "Bunu müdüre şikâyet edeceğim."},
          tutmadi = {"Bir şey olmadı. Şaşırdım mı? Hayır.", "Bir daha. Doğru dürüst.", "Asan mı kötü, sen mi?"},
          iyilesti = {"Hm. Fena değil.", "Tamam, iyileştim. Teşekkür... ederim.", "Beklediğimden iyiydin. Çok beklemiyordum ama.", "Peki. Kabul. İyiydi.", "Bir dahaki sefere daha hızlı ol, ama... sağ ol."},
          veda = {"Gidiyorum.", "Bir daha buraya gelmeyeceğim.", "Hoşça kal. Sanırım."},
          rahatlat = {"Sakinleştirmeye çalışma beni.", "İyileşeceğimi ben de biliyorum.", "...peki. Biraz iyi geldi. Söyleme kimseye."},
          sohbet = {"{hane}. Ne olmuş?", "{yil}. yıl. Ve yeterince gördüm.", "Ortak salon gürültülü. Revir daha iyi aslında. Bunu da söyleme."}
     },
     kitapkurdu = {
          selam = {
               "Merhaba. Durumumu literatürle karşılaştırıyordum, ilginç bir vaka olabilirim.",
               "Sen gönüllüsün, değil mi? Hangi kaynaklardan çalıştın?",
               "İyi ki geldin. 'Şifacılığın Temelleri'ne göre şu an kritik saatteyim.",
               "Merhaba {oyuncu}. Belirtilerimi alfabetik sıraya koydum, istersen.",
               "Kütüphaneden geliyorum. Yani, oradan buraya taşındım.",
               "Revirin kayıt defterini görebilir miyim? Merak ediyorum, bilimsel olarak.",
               "Durumumun Latince adını biliyor musun? Ben biliyorum sanıyordum.",
               "Merhaba. Lütfen her adımı açıkla, öğrenmek istiyorum."
          },
          hikayeGiris = {"Bilimsel bir dikkatle aktarayım.", "Olayın sırası önemli, o yüzden kronolojik gideceğim.", "Kitaplarda bunun adı geçmiyordu, oysa her şeyi okumuştum.", "Deney koşullarını şöyle özetleyebilirim:", "Gözlemlerimi sırayla aktarayım."},
          belirtiGiris = {"Gözlemlerime göre şunlar var.", "Birincil belirti şu:", "Ders kitabındaki sırayla söyleyeyim."},
          belirtiAra = {"İkincil olarak...", "Ek gözlem:", "Bunu dipnot olarak ekleyeyim."},
          belirtiYok = {"Belirgin bir öznel belirti yok; muayene daha öğretici olacaktır.", "Kendi gözlemim yetersiz kalıyor, itiraf ediyorum."},
          muayene = {"Palpasyon, değil mi? Doğru teknik.", "Nabzı bilekten mi alıyorsun? Boyundan daha doğru olur.", "İlginç. Ne yazıyorsun, görebilir miyim?", "Bu bulguyu not et, önemli olabilir."},
          tarama = {"Kalıntı taraması! Bunu ancak kitapta görmüştüm.", "Rengi hangi sınıfa giriyor?", "Lütfen sonucu yüksek sesle söyle, not alacağım."},
          bekleme = {"Beklerken Mandragora'nın yaşam döngüsünü düşünüyordum.", "Revirin yatak düzeni simetrik değil, fark ettin mi?", "Defterde benim vakam kaçıncı sayfada?", "Ders notlarımı biri getirse..."},
          yanlis = {"Bu, beklenen tepki değildi. Teşhisi gözden geçirelim mi?", "Kitaba göre bu büyü benim durumuma uygun değil.", "Hımm. Bir yan etki gözlemliyorum. Hoş değil.", "Defterin hangi sayfasına baktın?"},
          tutmadi = {"Büyü tutunmadı; muhtemelen bilek açısı.", "Rün eğrisi doğruydu ama hız düşüktü belki.", "Bir deneme daha istatistiksel olarak mantıklı."},
          iyilesti = {"Kusursuz bir uygulama. Kitaba geçmeli.", "Teşekkürler. Bu vakayı not ettim: ismin de içinde.", "Belirtiler tamamen geriledi. Etkileyici.", "Sana bir kaynak önereyim: 'Şifalı Büyülerin Tarihi'. Hak ettin.", "Teorik olarak iki gün sürecekti. Sen iki dakikada yaptın."},
          veda = {"Kütüphaneye dönüyorum. Yine.", "Hoşça kal. Bu deneyimi bir makaleye dönüştürebilirim.", "Teşekkürler, meslektaş. Sayılırım, değil mi?"},
          rahatlat = {"İstatistiksel olarak haklısın, iyileşme oranı yüksek.", "Mantıklı bir yaklaşım. Sakinleşiyorum.", "Plasebo etkisi de bir etkidir, teşekkürler."},
          sohbet = {"{hane}. Şapka Ravenclaw'ı da düşündü, belirteyim.", "{yil}. yıl, ama Büyülü Kuramlar'da ileri seviyedeyim.", "Ortak salonda değil, kütüphanede yaşıyorum desem daha doğru."}
     }
}

-- Müdavimler: kalıcı karakterler. Revire tekrar tekrar düşerler, kendi lafları vardır.
-- egilim: bu hastalıklara daha sık yakalanırlar.
R.Mudavimler = {
     {id = "tobias", ad = "Tobias Wren", hane = "Hufflepuff", cins = "e", yil = 2, kisilik = "korkak", egilim = {"burkulma", "mandragora", "canavar_kitap"},
      selam = {"Yine ben... Tobias. Merdivenler bana kin besliyor.", "Merhaba. Bu ay üçüncü gelişim, biliyorum."},
      iyilesti = {"Teşekkürler! Bir dahakine... muhtemelen yine geleceğim.", "Annem 'revirin gediklisi' diyor bana. Haklı."}, veda = {"Merdivenlere dikkat edeceğim. Söz. Sanırım."}},
     {id = "persephone", ad = "Persephone Vale", hane = "Slytherin", cins = "k", yil = 6, kisilik = "alayci", egilim = {"ask_iksiri", "kusturan_pastil", "confundus"},
      selam = {"Yine sen. Bu revirde başka şifacı yok mu?", "Sanırım bana aşk iksiri vermek moda oldu."},
      iyilesti = {"Fena değilsin. Bunu bir daha söylemeyeceğim.", "Teşekkürler. Hayranlarım üzülecek."}, veda = {"Görüşürüz. Ya da görüşmeyiz."}},
     {id = "barnaby", ad = "Barnaby Fenwick", hane = "Gryffindor", cins = "e", yil = 5, kisilik = "dramatik", egilim = {"bludger", "supurge", "kirik_burun"},
      selam = {"Takımın yıldızı yine sakat! Kupa elimizden gidiyor!", "Bludger beni seviyor. Ben onu sevmiyorum."},
      iyilesti = {"Sahaya dönebilirim! Kaptana söyleme ne kadar ağladığımı.", "Kahramanım! Bir sonraki golümü sana armağan edeceğim."}, veda = {"Maça gel! Ön sırada yerin hazır."}},
     {id = "ophelia", ad = "Ophelia Quirke", hane = "Ravenclaw", cins = "k", yil = 4, kisilik = "kitapkurdu", egilim = {"kazan_yanigi", "cokozlu", "geri_tepen"},
      selam = {"Merhaba. Deneyim yine planladığım gibi gitmedi.", "Bu sefer kazan değil, teorim patladı. Gerçi kazan da patladı."},
      iyilesti = {"Teşekkürler. Gözlemlerin defterime girdi.", "Bir sonraki deneyde sen de olmalısın. Yakında."}, veda = {"Laboratuvara dönüyorum. Yani İksir zindanına."}},
     {id = "rufus", ad = "Rufus Gamp", hane = "Slytherin", cins = "e", yil = 7, kisilik = "huysuz", egilim = {"sectumsempra", "kara_buyu", "furnunculus"},
      selam = {"Bunu kimseye anlatma.", "Düelloyu kazandım. Neden burada olduğumu sorma."},
      iyilesti = {"...iyiydin.", "Peki. Teşekkürler. Unut bunu."}, veda = {"Bu görüşme hiç olmadı."}},
     {id = "pippa", ad = "Pippa Bagshot", hane = "Hufflepuff", cins = "k", yil = 3, kisilik = "geveze", egilim = {"billywig", "hipogrif", "tentacula"},
      selam = {"Selam! Yine bir yaratık beni sevdi! Fazla sevdi!", "Bu sefer neyle karşılaştım bil bakalım! Bilemezsin!"},
      iyilesti = {"Harika! Hagrid'e gidip anlatmam lazım!", "Sen en iyisisin, sana bir Puffskein alacağım!"}, veda = {"Yaratıklara selam söylerim senden!"}},
     {id = "cedric_m", ad = "Edmund Marchbanks", hane = "Ravenclaw", cins = "e", yil = 1, kisilik = "utangac", egilim = {"engorgio_el", "tarantallegra", "rictusempra"},
      selam = {"...yine ben.", "Tılsım dersinde... yine."},
      iyilesti = {"Teşekkürler... bir dahaki derste dikkat ederim.", "...sen hep iyisin bana."}, veda = {"...görüşürüz."}},
     {id = "agatha", ad = "Agatha Thistlewood", hane = "Gryffindor", cins = "k", yil = 6, kisilik = "kibar", egilim = {"boggart", "ruh_emici", "glacius"},
      selam = {"Merhaba, yine rahatsız ettim, kusura bakmayın.", "Karanlık Sanatlara Karşı Savunma dersinden geliyorum, tahmin edersiniz."},
      iyilesti = {"Her seferinde daha da iyisiniz, gerçekten.", "Size bir teşekkür kartı göndereceğim."}, veda = {"İyi nöbetler, sevgili {oyuncu}."}},
     {id = "silas", ad = "Silas Crowley", hane = "Slytherin", cins = "e", yil = 4, kisilik = "alayci", egilim = {"salyangoz", "densaugeo", "langlock"},
      selam = {"Uğursuzluğu ben yapmadım. Bana yapıldı. Bu sefer.", "Yine geldim. Düşmanlarım çoğaldı."},
      iyilesti = {"Teşekkürler. İntikam planım beklemede.", "İşini iyi yapıyorsun, bu sinir bozucu."}, veda = {"Bir dahaki hastan muhtemelen benim yüzümden gelir."}},
     {id = "marigold", ad = "Marigold Prewett", hane = "Hufflepuff", cins = "k", yil = 5, kisilik = "dramatik", egilim = {"uykusuzluk", "ates_sekerleme", "biberli_iksir"},
      selam = {"Sınavlar beni öldürecek, sen değil.", "Üç gündür uyumadım. Ya da dört. Saymayı bıraktım."},
      iyilesti = {"Yeniden doğdum! Sınavlara hazırım! Değilim ama hissediyorum!", "Sana ömür boyu tatlı borçluyum."}, veda = {"Kütüphaneye! Yani... önce uyku."}},
     {id = "gideon", ad = "Gideon Ashdown", hane = "Gryffindor", cins = "e", yil = 7, kisilik = "geveze", egilim = {"kurt_isirigi", "cisimlenme", "ejderha_yanigi"},
      selam = {"Uzun hikâye ama ormana girmemem gerekiyordu, değil mi?", "Cisimlenme sınavına çalışıyordum. Ve işte buradayım. Parça parça."},
      iyilesti = {"Bütün parçalarım yerinde! Saydım!", "Sen olmasan şu an iki kişi olurdum. Yarım yarım."}, veda = {"Bir dahakine kapıdan çıkacağım. Cisimlenmeden."}},
     {id = "winifred", ad = "Winifred Smethwyck", hane = "Ravenclaw", cins = "k", yil = 2, kisilik = "korkak", egilim = {"sersemletme", "kafa_sisirme", "confundus"},
      selam = {"Düello kulübüne bir daha gitmeyeceğim.", "Ben sadece izliyordum! Gerçekten sadece izliyordum!"},
      iyilesti = {"Teşekkürler... sen olmasan ağlardım. Ağladım aslında.", "Kafam eski boyunda mı? Emin misin?"}, veda = {"Bundan sonra kütüphanede kalacağım."}}
}
R.MudavimHarita = {}
for _, m in ipairs(R.Mudavimler) do R.MudavimHarita[m.id] = m end

-- Hastalığa özgü olmayan, durum bildiren kısa satırlar
R.HastaGenel = {
     bilincsiz = {"...", "(Hasta derin derin nefes alıyor, gözleri kapalı.)", "(Bir an kıpırdıyor, sonra yine dalıyor.)"},
     mirilti = {"Mmmf! Mmf mmf!", "Mmh... hmmf!", "(Hasta bir şey söylemeye çalışıyor ama dili damağına yapışmış.)", "Mmmm-hmm! Mf!"},
     gulme = {"Hah-ha-ha! Dur... hah! Duramıyorum!", "Hi-hi-hi! Karnım! Ha-ha!", "Pf-hahaha! Özür dilerim! Haha!"},
     uyuyor = {"(Hasta mışıl mışıl uyuyor.)", "(Hafif bir horultu.)"}
}
