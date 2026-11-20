-- "addons\\sardonrevir\\lua\\sardon_revir\\_sh_5metin_hikaye.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: hastalık hikâyeleri, belirti anlatımları, muayene ve tarama bulguları.
-- Hikâyeler birinci ağızdan, kendi başına cümle (kişilik kalıbının girişinden sonra gelir).

local R = SardonRevir

R.Hikayeler = {
     bludger = {
          "Antrenmanın son dakikasıydı, Bludger tam ön koluma geldi. Çatırtıyı tribünler bile duydu.",
          "Vurucumuz topu bana değil karşı takıma göndermeliydi. Göndermedi.",
          "Snitch'i gördüm sandım, eğildim, Bludger da beni gördü.",
          "Sopayla Bludger'ı karşılamaya çalıştım. Sopa sağlam kaldı, kolum kalmadı.",
          "Bahçede iki Bludger'ı kafesten kaçırdılar, ben de yakalamaya çalıştım. Akıllıca değildi."
     },
     burkulma = {
          "Merdiven tam ben basarken döndü, ayağım boşlukta kaldı.",
          "Kaybolan basamağı unuttum. Herkes unutur, değil mi? Sadece ben düşüyorum.",
          "Büyük Salon'a koşarken ıslak taşlarda kaydım.",
          "Gece kütüphaneden dönerken karanlıkta bir basamağı kaçırdım.",
          "Hareketli merdivenlerden atlamaya çalıştım. Merdiven benden hızlıydı."
     },
     kemiksiz = {
          "Kolum kırılmıştı, bir profesör 'hemen düzeltirim' dedi. Düzeltti. Kemikleri tamamen.",
          "Arkadaşım kitaptan bir onarma büyüsü denedi. Kitap ters çevrilmişti.",
          "Maçta düştüm, biri yardım etmek istedi. Şimdi kolum bir çorap gibi.",
          "Kırık bileğime bir büyü yapıldı, birden içinin boşaldığını hissettim.",
          "Kendi kolumu kendim iyileştirmeye çalıştım. Bir daha yapmayacağım."
     },
     kazan_yanigi = {
          "İksir dersinde kazanım köpürmeye başladı, eğildim ve tam o an patladı.",
          "Yanlış sırayla malzeme ekledim. Kazan bunu kişisel algıladı.",
          "Yan masadaki kazan uçtu, ben de yolundaydım.",
          "Ateşi kısmayı unuttum, karıştırmaya devam ettim. Bu iyi bir fikir değilmiş.",
          "Kazanı soğumadan kaldırmaya çalıştım, elimle."
     },
     diffindo = {
          "Düello taliminde Diffindo sekip koluma geldi.",
          "Tılsım dersinde kâğıt kesecektik. Kâğıdı tutan bendim.",
          "Arkadaşım çantamın kayışını kesmeye çalıştı, şaka olsun diye. Kayış dışında her şeyi kesti.",
          "Asam elimden kaydı, büyü ters yöne gitti.",
          "Bir paketi açmak için Diffindo dedim. Paket hâlâ kapalı."
     },
     sectumsempra = {
          "Koridorda biri arkamdan bağırdı, döndüm, sonra her yer kızıl oldu.",
          "Düello kurallara göre başladı. Sonra biri kuralları unuttu.",
          "Bir kitabın kenarına yazılmış bir büyüyü denediler. Üzerimde.",
          "Ne dediğini duymadım bile, sadece keskin bir ıslık sesi.",
          "Tartışma büyüdü, asalar çıktı. Bunu birinin bilmesini istemedim."
     },
     cisimlenme = {
          "Cisimlenme dersinde çembere ulaştım ama kaşım ulaşamadı. Sonra kolumun bir kısmı.",
          "Hogsmeade'e cisimlenmeye çalıştım. Ben gittim, bir parçam kaldı.",
          "Kararlılık vardı, hedef vardı. Ağırbaşlılık... yoktu galiba.",
          "Eğitmen 'acele etmeyin' dedi. Ettim.",
          "Arkadaşımla birlikte cisimlenmeye çalıştık, elini bıraktım."
     },
     supurge = {
          "Süpürgem otuz metrede birden durdu. Ben durmadım.",
          "Rüzgâr çok sertti, bir dönüşte süpürgeden kaydım.",
          "Yeni süpürgemi denemek istedim. Süpürge de beni denemek istemiş.",
          "Uçuş dersinde süpürgeye 'yukarı' dedim, fazla yukarı gitti.",
          "Takla atmayı deniyordum. Yarısını başardım."
     },
     hipogrif = {
          "Hipogrife selam vermeyi unuttum. O unutmadı.",
          "Göz temasını kestim sandım, kesmemişim.",
          "Hipogrifin tüyünü okşamak istedim, ondan izin almadan.",
          "Arkadaşım 'zararsız, bak' dedi ve beni öne itti.",
          "Hagrid'in dersinde eğilmem gerekiyordu, ben dik durdum."
     },
     canavar_kitap = {
          "Canavarların Canavarca Kitabı'nı açmak istedim. Sırtını okşamadım.",
          "Kitabım çantamdan kaçtı, yakalamaya çalıştım.",
          "Kütüphanede yanlış rafa uzandım, bir kitap parmağımı yedi.",
          "Kitabı kemerle bağlamıştım, kemeri çözdüm. Hata.",
          "Kitap sayfalarını kapatırken ellerimi de kapattı."
     },
     kirik_burun = {
          "Düelloda bir Rictusempra bekliyordum, yumruk geldi.",
          "Kapı tam ben geçerken kendi kendine kapandı.",
          "Bir Gryffindor gol sevincinde bana sarıldı. Fazla güçlü sarıldı.",
          "Merdivende önümdekine çarptım, başı benden sertti.",
          "Kütüphanede tepedeki bir kitap tam yüzüme düştü."
     },
     ejderha_yanigi = {
          "Bir ejderha bakıcısıyla konuşuyordum, ejderha da sohbete katıldı.",
          "Gizlice bir ejderha yumurtasına baktım. Annesi de bana baktı.",
          "Turnuva görüntülerini yakından izlemek istedim, fazla yakından.",
          "Ormanın sınırında bir şey parlıyordu, yaklaştım.",
          "Bir ejderha tırnağını satan adam 'sönmüş' demişti. Sönmemiş."
     },
     kan_kalemi = {
          "Ceza aldım. Bir kalemle aynı cümleyi saatlerce yazdırdılar. Mürekkep yoktu.",
          "Her gece aynı satırı yazıyorum, elimin üstünde kendiliğinden beliriyor.",
          "Bir profesörün odasında ceza yazdım. Kalem garipti.",
          "Kimseye söylemedim ama elim günlerdir böyle.",
          "Yazdığım cümle kâğıtta değil, elimde kalıyor."
     },
     kan_kaybi = {
          "Düellodan sonra bir kesiğim vardı, önemsemedim. Saatler geçti.",
          "Ormandan dönerken bir dal kolumu açtı, fark ettiğimde çok geçti.",
          "Yarayı sardım sandım, sargı kaymış.",
          "Kendimi iyi hissediyordum, sonra koridorda bir anda yere çöktüm.",
          "Kanamayı durdurdum sandım ama içeriden devam etmiş."
     },
     tentacula = {
          "Bitki Bilimi'nde Tentacula'nın saksısını değiştiriyordum, bir sarmaşık bileğime dolandı.",
          "Serada biri Tentacula'yı yanlış yere koymuş, ben de yaslandım.",
          "Eldivenlerimi unuttum. Tentacula unutmadı.",
          "Bitkiyi sulamak istedim, o da beni yakalamak istedi.",
          "Üçüncü serada bir şeyin kıpırdadığını gördüm, yaklaştım."
     },
     kusturan_pastil = {
          "Arkadaşım bir şeker verdi, 'dersten kurtarır' dedi. Kurtardı.",
          "Zonko'nun dükkânından aldığım kutuyu karıştırdım, yanlış ucu yedim.",
          "Bir şekerleme yerdeydi, renkliydi, yedim. Evet, yerden.",
          "Sınav öncesi 'kaytarma kutusu'nu denemek istedim. Mor ucu kaybettim.",
          "Biri çantama şeker koymuş, ben de şeker diye yedim."
     },
     ates_sekerleme = {
          "Bir 'ateş şekerlemesi' yedim ama ateşi geçiren yarısını bulamadım.",
          "Kaytarma şekerlemesi diye aldım, kaytaramadım, ateş kaldı.",
          "Kardeşim Zonko'dan getirmiş, tadına baktım.",
          "Ders kaçırmak için yedim. Şimdi bütün günü kaçırıyorum.",
          "Şekerin kâğıdında 'yarısını yemeyin' yazıyormuş. Okumadım."
     },
     biberli_iksir = {
          "Burnum akıyordu, Biberli İksir içtim. Sonra bir tane daha. Sonra bir tane daha.",
          "Kar topu savaşından sonra üşüdüm, iksiri bir dikişte içtim.",
          "Şişenin üstünde 'bir yudum' yazıyordu, ben şişe sandım.",
          "Soğuk algınlığı olmadan içtim, önlem olsun diye.",
          "Arkadaşım iksire biber eklemiş, ekstra biber."
     },
     benekli_humma = {
          "Ortak salonda biri öksürüyordu, sonra ben öksürmeye başladım.",
          "Kardeşimden geçti sanırım, mektubunda benekler vardı.",
          "Üç gündür yorgunum, bu sabah benekleri fark ettim.",
          "Kütüphanede birinin tüy kalemini ödünç aldım. Yanlış kişinin.",
          "Önce ateş geldi, sonra aynaya baktım."
     },
     ejderha_cicegi = {
          "Önce benekler çıktı, sonra hapşırınca perde tutuştu.",
          "Ailemde biri bu hastalığı atlatmıştı, ondan bulaştı sanırım.",
          "Ateşim çıktı, burnumdan kıvılcım geldi, yastığım yandı.",
          "Hogsmeade'de hasta biriyle aynı masada oturdum.",
          "Benekli humma sanıp beklemiştim. Hapşırdım ve kaşlarım gitti."
     },
     tarantallegra = {
          "Düello kulübünde biri bana Tarantallegra yaptı. Bir saattir dans ediyorum.",
          "Koridorda bir Slytherin 'dans etmek ister misin' dedi. Ben 'hayır' dedim. Asası 'evet' dedi.",
          "Şaka olsun diye yaptılar, ama durmuyor.",
          "Kendime yaptım, Finite'yi unuttum.",
          "Büyük Salon'da masaların arasında dans ederek buraya geldim. Herkes gördü."
     },
     langlock = {
          "(Hasta kâğıda karalıyor: 'Düelloda biri dilimi yapıştırdı.')",
          "(Hasta elleriyle anlatıyor: bir asa, bir ışık, ağzını gösteriyor.)",
          "(Hasta bir kâğıt uzatıyor: 'Kardeşimle kavga ettik. Kazandı.')",
          "(Hasta omuz silkiyor, sonra ağzını işaret ediyor.)",
          "(Hasta kâğıda yazıyor: 'Kütüphanede fazla konuştum galiba.')"
     },
     densaugeo = {
          "Düelloda dişlerimi uzattılar. Hâlâ uzuyorlar.",
          "Bir uğursuzluk sekti, dişlerime geldi.",
          "Arkadaşım 'kunduz gibisin' dedi, sonra öyle oldum.",
          "Aynaya baktım, dişlerim çenemi geçmişti.",
          "Kahvaltıda ekmek ısırırken birden uzamaya başladılar."
     },
     furnunculus = {
          "Biri bana Furnunculus yaptı, şimdi her yerim çıban.",
          "Düelloda bir uğursuzluk yedim, sabah her yerim kaşınıyordu.",
          "Hogsmeade'de birine çarptım, özür dilemedim, sanırım ondan.",
          "Ders arasında bir ışık çarptı, önemsemedim.",
          "Kendime bir uğursuzluk sektirdim. Aynayla düello iyi fikir değil."
     },
     engorgio_el = {
          "Tılsım dersinde bir domatesi büyütecektim. Domatesi tutan bendim.",
          "Engorgio'yu kendi elime yaptım, asa ters dönmüş.",
          "Arkadaşım elimi büyüttü, 'bir eldiven giysene' dedi.",
          "Çantamı büyütmek istedim, elim de çantadaydı.",
          "Kâğıt uçağı büyütmeye çalışırken yanlış şeyi hedefledim."
     },
     kafa_sisirme = {
          "Biri kafamı şişirdi, kapıdan zor geçtim.",
          "Düelloda bir büyü yedim, sonra boynum çok hafif hissetti.",
          "Arkadaşım 'kafan büyüdü' demişti, mecazdı. Artık değil.",
          "Büyük Salon'da biri asasını sallarken bana çarptı.",
          "Kendimi beğenmişliğin cezası dediler, ama bu bir uğursuzluk."
     },
     kara_buyu = {
          "Hogsmeade'den bir kolye aldım. Takmadım, sadece dokundum.",
          "Eski bir kitabın sayfasında parmağım kesildi.",
          "Ormanın derinlerinde bir taşa dokundum, soğuk ve kara.",
          "Biri bana bir hediye paketi uzattı, tanımıyordum.",
          "Yasak bölümdeki bir kitabı açtım, kitap da beni açtı sanki."
     },
     cokozlu = {
          "Çok Özlü İksir için bir kıl buldum. İnsan kılı değilmiş.",
          "Deneme olsun diye iksire bir tutam kıl ekledim, kedinin olduğunu bilmiyordum.",
          "Arkadaşımın yerine geçecektim. Arkadaşımın kedisi yerine geçtim.",
          "Kitapta yazan sırayla yaptım, sadece son malzemeyi tahmin ettim.",
          "Bunu kimse bilmesin, iksir ödevimdi."
     },
     ask_iksiri = {
          "Biri bana bir kutu çikolata gönderdi, isimsiz. Şimdi sadece onu düşünüyorum.",
          "Bir içki içtim, sonra birinin gözleri dünyanın en güzel şeyi oldu.",
          "Kek yedim, kekin üstünde kalp vardı.",
          "Kütüphanede biri bana gülümsedi ve bir şişe uzattı.",
          "Sevgililer günüydü, bir şey içtim, gerisini hatırlıyorum ama keşke hatırlamasam."
     },
     billywig = {
          "Bir Billywig soktu, beş dakika boyunca tavanda dolaştım.",
          "Hagrid kafesteki mavi böceği gösterdi, kafes açıktı.",
          "Billywig sokmasını eğlence için denemek istedim. Eğlenceliydi, sonra değildi.",
          "Bahçede mavi bir vızıltı duydum, sonra yerden kesildim.",
          "Arkadaşım 'kanatlarını kurut, başın döner' dedi. Başım dönüyor."
     },
     salyangoz = {
          "Birine bir uğursuzluk yapmak istedim. Asam kırıktı. Uğursuzluk bana döndü.",
          "Düelloda bir büyüyü geri savurdum, ama tam değil.",
          "Biri arkadaşıma hakaret etti, ben de asamı kaldırdım. Asam da bana hakaret etti.",
          "Bantlı asamla büyü yapmak iyi fikir değilmiş.",
          "Ağzımdan ilk sümüklüböcek çıktığında Büyük Salon'daydım."
     },
     rictusempra = {
          "Düelloda biri beni gıdıkladı, hah! Hâlâ geçmedi, haha!",
          "Arkadaşım şaka yaptı, büyüyle. Hi-hi! Durmuyor!",
          "Rictusempra'yı yanlış hedefe yaptım, hedef aynaydı.",
          "Koridorda biri 'gül biraz' dedi ve asasını salladı.",
          "Kütüphanede gülmemek gerekiyordu. Hiç bu kadar gülmemiştim."
     },
     mandragora = {"(Hasta baygın. Yanındaki arkadaşının bıraktığı not: 'Kulaklığını takmamıştı.')", "(Hasta kendinde değil; elinde hâlâ toprak var.)", "(Cüppesinde saksı toprağı, saçında bir mandragora yaprağı.)", "(Bitki Bilimi'nden getirilmiş; kulaklığı boynunda asılı.)", "(Hasta baygın, dudakları kıpırdıyor: 'Çok... gürültülü...')"},
     sersemletme = {"(Hasta baygın. Göğsünde bir büyü yanığı izi var.)", "(Düello kulübünden getirilmiş; asası hâlâ elinde.)", "(Hasta kendinde değil; yanındakiler 'tam göğsüne' diyor.)", "(Hasta yere düşerken kafasını çarpmamış, şanslı.)", "(Sersemlemiş yatıyor, gözleri yarı açık.)"},
     ruh_emici = {
          "Gölün yanındaydım, birden her yer buz kesti, sesler gitti.",
          "Bir gölge geçti, sonra en kötü anımı tekrar yaşadım.",
          "Hogsmeade yolunda havanın karardığını gördüm, sonra hatırlamıyorum.",
          "Patronus çağırmaya çalıştım, olmadı.",
          "Gece pencereden bakarken camlar buzlandı."
     },
     boggart = {
          "Dolabı açtım, içinden en korktuğum şey çıktı.",
          "Karanlık Sanatlara Karşı Savunma dersinde sıram geldi, Riddikulus'u unuttum.",
          "Eski bir sandığı açtım, içinde bir şey vardı. Ya da yoktu.",
          "Gülmem gerekiyordu, ağladım.",
          "Yatakhanedeki dolaptan bir ses geliyordu, baktım."
     },
     confundus = {
          "Bir şeyler oldu, sonra buradayım. Burası neresi? Ah, revir. Neden?",
          "Biri bana bir şey yaptı sanırım, ama kim? Belki de bendim.",
          "Kütüphaneye gidiyordum, sonra kendimi göl kenarında buldum.",
          "Sınıfa girdim, yanlış sınıfmış, sonra yine yanlış sınıf, sonra...",
          "Düelloda kazandım sanıyorum. Ya da kaybettim. Sen kimsin?"
     },
     glacius = {
          "Gölde buz pateni yaparken buz kırıldı.",
          "Düelloda bir Glacius sekti, tam üstüme.",
          "Kar topu savaşı biraz büyülü hâle geldi.",
          "Astronomi Kulesi'nde bütün gece kaldım, cüppesiz.",
          "İçeceğimi soğutmak istedim, kendimi soğuttum."
     },
     kurt_isirigi = {
          "Dün gece ormana girdim, dolunay vardı. Bir şey beni ısırdı.",
          "Bir köpek sandım. Köpek değildi.",
          "Hogsmeade yolunda bir uluma duydum, sonra koştum ama yetmedi.",
          "Yasak Orman'a bir iddia için girdim. İddiayı kaybettim.",
          "Kimseye söylemeyecektim ama ısırık geçmiyor."
     },
     uykusuzluk = {
          "Dört gündür sınava çalışıyorum. Uyumadım. Uyumayı unuttum.",
          "Her gece ödevlerle sabahlıyorum, artık gözlerimi kapatamıyorum.",
          "Kahve, çay, bir de Biberli İksir. Şimdi uyuyamıyorum.",
          "Gözümü kapatınca sınav kâğıdını görüyorum.",
          "Ortak salonda son ben kalıyorum, ilk ben uyanıyorum."
     },
     geri_tepen = {
          "Asam çatlaktı, bir büyü yaptım, büyü bana döndü.",
          "Çok güçlü bir büyü yapmaya çalıştım. Benden güçlüydü.",
          "Asamı yere düşürdüm, kaldırınca büyü kendiliğinden çıktı.",
          "Başkasının asasıyla büyü yaptım. Asa beni sevmedi.",
          "Büyü elimde patladı, kulaklarım hâlâ çınlıyor."
     }
}

-- iyileşince hastalığa özgü ek söz
R.HastalikSon = {
     bludger = {"Bir dahakine Bludger görünce eğileceğim. Belki.", "Kolum! Kıpırdıyor! Kaptana söylemeliyim."},
     burkulma = {"Merdivenlere artık daha saygılı davranacağım.", "Ayağıma basabiliyorum! Hem de acımadan."},
     kemiksiz = {"Kemiklerim geri geldi. Bir daha kimse kolumu düzeltmeye kalkmasın.", "O şurup... dünyanın en kötü tadı. Ama işe yaradı."},
     kazan_yanigi = {"Bir dahakine kazandan iki adım uzakta duracağım.", "Yanık geçti, ama iksirim hâlâ başarısız."},
     diffindo = {"İz bile kalmadı! Hiç olmamış gibi.", "Bir daha kâğıdı başkası tutsun."},
     sectumsempra = {"Yara kapandı. Kim yaptıysa... neyse, sana teşekkürler.", "Bu büyüyü bilen birinin burada olması büyük şans."},
     cisimlenme = {"Bütün parçalarım yerinde mi? Saydım, yerinde.", "Bir dahakine yürüyerek gideceğim."},
     supurge = {"Nefes alabiliyorum! Kaburgalarım şarkı söylemiyor artık.", "Süpürgemi kırmamışımdır umarım."},
     hipogrif = {"Bir dahakine eğileceğim. Derin derin eğileceğim.", "Hipogrif haklıydı, kabalık bendeydi."},
     canavar_kitap = {"O kitabı bir daha kemersiz taşımayacağım.", "Parmaklarım tam! On tane!"},
     kirik_burun = {"Aynaya bakabilir miyim? Eskisinden güzel bile oldu.", "Burnum dümdüz! Teşekkürler!"},
     ejderha_yanigi = {"Ejderhalara uzaktan hayran kalacağım bundan sonra.", "Cildim serin! Ne güzel his."},
     kan_kalemi = {"Elim acımıyor. Yazı da gitti. Teşekkür ederim.", "Bunu kimseye söyleme... ama sana söyledim, teşekkürler."},
     kan_kaybi = {"Rengim geri geldi! Bacaklarım beni taşıyor.", "Bir dahakine en küçük kesiği bile ciddiye alacağım."},
     tentacula = {"O bitkinin yanından bir daha geçmeyeceğim.", "Midem yerine oturdu, rengim de."},
     kusturan_pastil = {"Zonko'ya bir şikâyet mektubu yazacağım. Ya da bir sipariş.", "Midem rahatladı. Ders kaçırmanın bedeli ağırmış."},
     ates_sekerleme = {"Ateşim düştü! Çıbanlar da gitti!", "Bir dahaki kaytarmamda kutunun tamamını okuyacağım."},
     biberli_iksir = {"Kulaklarımdan duman çıkmıyor! Ne büyük rahatlık.", "Bir yudum demek bir yudum demekmiş."},
     benekli_humma = {"Benekler soldu! Ortak salona dönebilirim.", "Kimseye bulaştırmadım umarım."},
     ejderha_cicegi = {"Hapşırdım ve hiçbir şey yanmadı! Harika!", "Kaşlarım geri gelir mi? Gelir, değil mi?"},
     tarantallegra = {"Bacaklarım durdu! Ama biraz da özleyeceğim.", "Bir daha düello kulübüne dans ayakkabısıyla gitmeyeceğim."},
     langlock = {"Konuşabiliyorum! Konuşabiliyorum! Bak, konuşuyorum!", "Dilim çözüldü. Söyleyecek o kadar çok şeyim var ki."},
     densaugeo = {"Dişlerim normal! Belki biraz daha kısa olabilirdi ama olsun.", "Gülümseyebiliyorum! Bak!"},
     furnunculus = {"Kaşıntı geçti! Cildim pürüzsüz!", "Bunu yapan kişiyi bulacağım. Ama önce teşekkür ederim."},
     engorgio_el = {"Elim eski boyunda! Eldivenim yine olacak.", "Tılsım dersinde artık sadece domatese bakacağım."},
     kafa_sisirme = {"Kafam eski boyunda mı? Emin misin? Tamam, emin olalım.", "Boynum rahatladı, sonunda."},
     kara_buyu = {"İçimdeki soğukluk gitti. Gerçekten gitti.", "O kolyeyi gömmek lazım. Derine."},
     cokozlu = {"Tüyler gitti! Miyavlamayı da bıraktım. Bıraktım mı?", "Bir dahakine kılı kimden aldığıma iki kez bakacağım."},
     ask_iksiri = {"Ay. Ay ay ay. Utanıyorum. O kadar mı ileri gittim?", "O kişiyi görmemeliyim. Bir süre. Belki hiç."},
     billywig = {"Yere bastım! Yer ne güzelmiş.", "Billywig'lerden uzak duracağım. Biraz özleyeceğim gerçi."},
     salyangoz = {"Sümüklüböcek yok! Hiç yok! Teşekkürler!", "Asamı Ollivander'a götüreceğim, söz."},
     rictusempra = {"Hah... ah. Geçti. Karnım ağrıyor ama geçti.", "Bir daha kimse beni gıdıklayamaz. Umarım."},
     mandragora = {"Kulaklığım nerede? Bir daha unutmayacağım.", "Ne oldu? Ah. Mandragora. Tabii."},
     sersemletme = {"Ne oldu? Kazandım mı? Kaybettim, değil mi?", "Kafam berrak. Teşekkür ederim."},
     ruh_emici = {"Isındım. İçimde biraz güneş var gibi.", "Çikolata hiç bu kadar iyi gelmemişti."},
     boggart = {"Artık o dolaba gülerek bakabilirim. Belki.", "Riddikulus'u bir daha unutmayacağım."},
     confundus = {"Her şey yerine oturdu. Ben kimim? Tamam, biliyorum. Şaka.", "Aklım başıma geldi. Tam zamanında."},
     glacius = {"Parmaklarımı hissediyorum! Hepsini!", "Bir dahakine gölde paten yapmadan önce buzu kontrol edeceğim."},
     kurt_isirigi = {"Yara kapandı ama Madam Pomfrey'le konuşmam lazım, değil mi?", "Bunu doğru yaptığın için teşekkürler. Korkuyorum ama yalnız değilim."},
     uykusuzluk = {"Gözlerim kapanıyor... ama güzel bir şekilde.", "Bu gece uyuyacağım. Sınavı yarın düşünürüm."},
     geri_tepen = {"Kulaklarım sustu. Asamı tamir ettireceğim.", "Bir dahakine kendi asamı kullanacağım."}
}

-- hastanın anlattığı belirti cümleleri
R.BelirtiSoz = {
     aci = {"Zonklayan, keskin bir ağrı var; nabzımla birlikte atıyor.", "Kıpırdatınca bıçak saplanıyor sanki.", "Acı dalga dalga geliyor, sonra durmuyor.", "Dokunmasan bile sızlıyor."},
     uyusma = {"Hissetmiyorum, sanki başkasının kolu.", "Karıncalanıyor, binlerce iğne batıyor gibi.", "Parmaklarımı oynatıyorum ama hissetmiyorum.", "Uyuşukluk yayılıyor, omzuma kadar."},
     bas_donmesi = {"Başım dönüyor, tavan da dönüyor.", "Kalkmaya çalışınca yer ayağımın altından kayıyor.", "Her şey bir yana yatıyor gibi.", "Gözlerimi kapatınca bile dönüyor."},
     bulanti = {"Midem altüst, bir şey yersem geri gelecek.", "Midem kazan gibi fokurduyor.", "Her şey midemi bulandırıyor, kokular bile.", "Kusacak gibiyim, sürekli."},
     kasinti = {"Her yerim kaşınıyor, deli olacağım.", "Kaşımamak için ellerimin üstüne oturdum.", "Kaşındıkça daha çok kaşınıyor.", "Cüppemin altında karıncalar yürüyor sanki."},
     ates = {"Yanıyorum, içim kor gibi.", "Bir terliyorum bir titriyorum.", "Alnıma dokun, yumurta pişer.", "Ateş içimden yükseliyor."},
     usume = {"Üşüyorum, kemiklerime kadar.", "Battaniye işe yaramıyor, soğuk içimde.", "Dişlerim takırdıyor, duymuyor musun?", "Ellerim buz kesti."},
     umutsuzluk = {"Hiçbir şeyin anlamı yok gibi.", "Bir daha hiç mutlu olamayacakmışım gibi.", "İçimde bir boşluk var, soğuk ve büyük.", "Güldüğüm son anı hatırlayamıyorum."},
     kabus = {"Uyuyunca hep aynı karanlık şeyi görüyorum.", "Gece uyanıyorum, bağırarak.", "Rüyamda bir ses fısıldıyor.", "Gözümü kapatmaya korkuyorum."},
     korku = {"Her gölgede onu görüyorum.", "Kalbim durmadan hızlanıyor, sebepsiz.", "Kapı açılınca sıçrıyorum.", "Dolaplara bakamıyorum."},
     agirlik = {"Elim taş gibi ağır, kaldıramıyorum.", "Kolumu sürüklüyorum resmen.", "Sanki bir kazan taşıyorum elimde.", "Ağırlıktan omzum düşüyor."},
     kontrolsuz = {"Bacaklarım kendi kafasına göre gidiyor.", "Durmak istiyorum ama ayaklarım dinlemiyor.", "Kalkarsam dans ederek kalkacağım.", "Ayaklarım bir müzik duyuyor, ben duymuyorum."},
     konusamiyor = {"Mmmf! Mmf-mmf!", "Mmh! Hmmf mmf!", "(Hasta ağzını gösterip başını sallıyor.)", "(Hasta konuşmaya çalışıyor, yalnız mırıltı çıkıyor.)"},
     saskinlik = {"Bugün hangi gün? Salı mı? Salı değil mi?", "Adımı biliyorum... dilimin ucunda.", "Buraya nasıl geldim, sen getirdin mi?", "Seni tanıyor muyum? Annem misin?"},
     saplanti = {"O kişiyi görmem lazım, hemen, şimdi!", "Onun gözleri... bilir misin, yıldız gibi.", "Bütün gün onun adını yazıyorum.", "Bana bir mektup getirdi mi? Sordu mu beni?"},
     tuhaf_istek = {"Canım bir kase süt çekiyor. Sıcak değil, soğuk.", "Çiğ balık olsa yerdim şimdi.", "Bir yün yumağı görsem peşinden koşacağım.", "Güneşli bir pencere kenarı istiyorum."},
     kulak_cinlama = {"Kulaklarımda bir çan çalıyor, durmuyor.", "Uzaktan bir ıslık duyuyorum, hep.", "Sesin uzaktan geliyor gibi.", "Bir vızıltı var, kafamın içinde."},
     gulme_aci = {"Ha-ha! Karnım ağrıyor! Hi-hi!", "Gülmekten nefes alamıyorum! Hah!", "Kaburgalarım ağrıyor! Pfff-ha!", "Durdur şunu, haha, lütfen!"},
     uyuyamama = {"Günlerdir gözümü kırpmadım.", "Yatıyorum, tavana bakıyorum, sabah oluyor.", "Uykum geliyor ama uyuyamıyorum.", "Gece yarısından sonra zihnim susmuyor."},
     guc_yok = {"Dermanım yok, kolumu bile kaldıramıyorum.", "Sanki bütün gücüm akıp gitti.", "Konuşmak bile yoruyor.", "Ayağa kalksam düşerim."}
}

-- muayene bulgusu (gönüllüye anlatıcı ağzından)
R.BelirtiBulgu = {
     kemik_catirti = {"Ön koluna dokununca parmaklarının altında bir çatırtı hissediyorsun.", "Kemik hattı bir yerde kırılmış; hafif bir basınç bile çıtırdatıyor."},
     eklem_sis = {"Bilek eklemi şişmiş ve sıcak, ama kemik düz.", "Eklemi oynattığında kemik sağlam; şişlik yumuşak dokuda."},
     kemik_yok = {"Kolun içinde kemik yok; deri lastik gibi esniyor.", "Kola bastırınca parmakların gömülüyor. Kemik bulamıyorsun."},
     deri_sicak = {"Deri alev gibi; elini çekmek zorunda kalıyorsun.", "Yanığın çevresi hâlâ sıcak, ısı içeriden geliyor."},
     deri_buz = {"Deri buz kesmiş, parmak uçların uyuşuyor.", "Bileği tutunca soğuk elinden yukarı tırmanıyor."},
     duzgun_kesik = {"Kesik dümdüz ve temiz; keskin bir büyünün izi.", "Kenarlar pürüzsüz, sanki makasla kesilmiş."},
     kara_yara = {"Yara kenarları kararmış ve kapanmıyor; dokundukça yeniden açılıyor.", "Kesiğin içi koyu, kenarlarda siyah çizgiler var."},
     eksik_parca = {"Kolun bir parçası yerinde değil; geride bir boşluk var.", "Deri bir yerde kesik değil, eksik."},
     kaburga = {"Göğsüne hafifçe bastırınca kaburgada bir çatlak hissediyorsun.", "Nefes alırken kaburga hattında bir çıtırtı var."},
     pence_izi = {"Üç paralel, derin pençe izi.", "Yara üç eşit çizgi hâlinde, bir kuşun pençesi gibi."},
     isirik = {"Bileğinde diş izleri var, iki sıra.", "Isırık izi; dişler derine girmiş."},
     burun_egri = {"Burun yana eğrilmiş, kemiği yerinden oynamış.", "Burun kemiği çarpık; dokununca hasta inliyor."},
     nabiz_hizli = {"Nabız hızlı, kuş kalbi gibi çarpıyor.", "Bilekteki nabzı saymaya yetişemiyorsun."},
     nabiz_yavas = {"Nabız ağır ve yavaş, her atım uzun bir bekleyiş.", "Nabız zayıf ve seyrek."},
     goz_buyuk = {"Göz bebekleri kocaman, ışığa tepki vermiyor.", "Gözlerine ışık tutuyorsun; bebekler büyük kalıyor."},
     dil_turuncu = {"Dilinde turuncu bir şeker lekesi var.", "Ağzını açtırınca dilin turuncuya boyandığını görüyorsun."},
     dil_yapisik = {"Dil damağa yapışmış, kıpırdamıyor.", "Ağzının içinde dil damağa yapışık; bir büyünün işi."},
     dis_uzun = {"Ön dişler çenenin altına kadar uzamış.", "Dişler uzamaya devam ediyor; gözünün önünde."},
     ciban = {"Cüppenin altında kırmızı, şiş çıbanlar var.", "Sırtında ve kollarında çıbanlar dizilmiş."},
     damar_kara = {"Bileğinden yukarı kararmış damarlar uzanıyor.", "Damarlar mürekkep gibi koyu, yayılıyor."},
     kedi_tuy = {"Yüzünde ince tüyler, gözleri çekik ve sarımsı.", "Kulakların ucu sivrilmiş, yüz tüylerle kaplı."},
     benek_kabuk = {"Beneklerin bazıları kabuk bağlamış.", "Morumsu beneklerin ortası kurumuş, kabuklanmış."},
     goz_kizarik = {"Gözler kıpkırmızı, altları mor halkalı.", "Gözleri yorgun ve kanlı; göz kapakları titriyor."},
     kas_kasilma = {"Kaslar kasılmış, ara ara seğiriyor.", "Kolundaki kaslar kendi kendine geriliyor."},
     asa_yanik = {"Asa elinin avucunda bir yanık izi var, asanın şeklinde.", "Parmaklarında kararmış bir yanık; asa elinde patlamış."},
     el_yazi = {"Elinin üstünde ince harflerle kazınmış bir cümle var.", "Elinde kanlı harfler: 'Yalan söylememeliyim.'"}
}
R.MuayeneBos = {"Dikkatle muayene ediyorsun ama yeni bir bulgu yok.", "Nabız, deri, gözler... hepsine bakıyorsun; dikkat çeken bir şey yok."}

-- hastaya ilk bakışta görünen belirti
R.GorunurAnlati = {
     kol_bukuk = "Kolu garip bir açıyla bükülmüş.",
     kol_sarkik = "Kolu lastik gibi sarkıyor.",
     dumanli_yanik = "Kolundaki yanıktan hâlâ ince bir duman tütüyor.",
     kesik_kan = "Cüppesinde taze kan lekesi var.",
     yesil_ten = "Teni yeşilimsi.",
     soluk_ten = "Teni buz gibi soluk, dudakları mor.",
     mor_benek = "Yüzü ve boynu mor beneklerle kaplı.",
     kivilcim_burun = "Burnundan arada kıvılcım çıkıyor.",
     kulak_duman = "Kulaklarından duman çıkıyor.",
     kopuk = "Ağzının kenarında köpük ve kabarcıklar var.",
     buz_nefes = "Nefesi havada buğulanıyor.",
     el_sisik = "Eli neredeyse başı kadar şişmiş.",
     bas_sisik = "Kafası balon gibi şişmiş.",
     bacak_dans = "Bacakları durmadan tepiniyor.",
     titreme = "Bütün vücudu titriyor.",
     suzulme = "Yatağın birkaç parmak üstünde süzülüyor.",
     pembe_isik = "Gözlerinde pembe bir ışıltı var.",
     bilincsiz = "Kendinde değil.",
     kahkaha = "Durmadan gülüyor."
}

R.KalintiAnlati = {
     kirmizi = {"Asanın ucundan süzülen ışık hastanın çevresinde kızıla dönüyor: bedensel bir yara.", "Kızıl bir hale beliriyor; büyü değil, beden yaralanmış."},
     yesil = {"Hastanın çevresinde yeşil bir sis beliriyor: zehir, bitki ya da iksir.", "Kalıntı yeşil; damarlarında yabancı bir öz var."},
     mor = {"Mor bir kalıntı kıvrılıyor: bir lanet ya da uğursuzluk.", "Hastanın çevresinde mor kıvılcımlar dolanıyor; üzerinde bir büyü var."},
     mavi = {"Soluk mavi bir ışık titreşiyor: bilinç, ruh ya da soğuk.", "Kalıntı mavi; zihni ya da ruhu sarsılmış."},
     turuncu = {"Turuncu bir kor yayılıyor: ateşli, büyülü bir hastalık.", "Hastanın çevresinde turuncu kıvılcımlar; bulaşıcı bir ateş."}
}
