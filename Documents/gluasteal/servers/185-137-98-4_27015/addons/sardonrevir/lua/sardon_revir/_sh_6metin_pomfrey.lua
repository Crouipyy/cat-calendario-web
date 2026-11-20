-- "addons\\sardonrevir\\lua\\sardon_revir\\_sh_6metin_pomfrey.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: Madam Pomfrey'in replikleri, bağlam satırları, gönüllünün seçenek metinleri.
-- Jetonlar: {oyuncu} {unvan} {hasta} {no} (yatak numarası) {kalan} (yenilenmeye kalan süre) {sayi}

local R = SardonRevir

R.Pomfrey = {
     karsilama = {
          "Ah, {oyuncu}. Yine mi yaralandın, yoksa bu sefer yardım etmeye mi geldin?",
          "Revirde koşmak yok, bağırmak yok, şeker yok. Ne istiyorsun, {oyuncu}?",
          "Elin boş geldiysen yatakları say: hiçbiri boş kalmıyor bu okulda.",
          "Gönüllü arıyorum, {oyuncu}. Elin titremiyorsa tabii.",
          "İyi ki geldin. Bugün üç merdiven kazası, iki uğursuzluk ve bir de kafası şişmiş bir Ravenclaw var.",
          "Bana bakma öyle; ben iyiyim. Yataktakiler değil."
     },
     nobetBasla = {
          "Pekâlâ. Defter masada, dolap arkamda. {sayi} hasta geliyor; hepsi senin.",
          "Önce dinle, sonra bak, sonra defteri aç. Büyüyü en son yaparsın. Anlaşıldı mı?",
          "{sayi} yatak hazırladım. Teşhis koymadan kimseye asa doğrultmayacaksın.",
          "Eldivenlerini... neyse, büyücüyüz. Asanı hazırla, {oyuncu}. Hastalar geliyor.",
          "Bugün benim yardımcımsın. Hata yaparsan ben buradayım; ama hata yapma.",
          "Defterdeki her sayfa bir hastanın hayatı kadar önemli. Dikkatle oku."
     },
     nobetVar = {"Hastaların seni bekliyor, {oyuncu}. Sohbeti sonra yaparız.", "Nöbetin sürüyor. Bir şeye takıldıysan sor.", "Yataklar dolu, gönüllü. Benimle değil, hastalarla ilgilen."},
     gunlukBitti = {
          "Bugünlük yeter, {oyuncu}. Dinlenmiş bir şifacı iki yorgun şifacıya bedeldir. {kalan} sonra gel.",
          "Bir nöbet bir günde yeter. Yarın sabah yine buradayım.",
          "Elinin titrediğini görüyorum. Git yat. {kalan} sonra yatakların hazır olur.",
          "Bugünkü işini yaptın. Şimdi biraz çikolata ye ve uyu.",
          "Revir yarın da açık olacak, merak etme."
     },
     yatakDolu = {
          "Şu an bütün yataklar başka bir gönüllünün elinde. Biraz bekle.",
          "Aynı anda bu kadar şifacı revire sığmaz. Sıranı bekle, {oyuncu}.",
          "Yataklar dolu. Bir nöbet bitince seni çağıracağım.",
          "Bekle biraz. Revir bir Quidditch tribünü değil."
     },
     kapali = {"Revir şu an gönüllü kabul etmiyor.", "Bugün gönüllüye ihtiyacım yok, teşekkürler."},
     engel = {"Önce kendi derdini çöz, {oyuncu}. Bu hâlde kimseyi iyileştiremezsin.", "Böyle gelme revire. Toparlan, sonra konuşuruz."},
     nasil = {
          "Hastalar yatağa gelince önce yanlarına git ve dinle. Ne olduğunu ve neler hissettiğini anlatırlar.",
          "Sonra muayene et: nabız, deri, gözler. Bazı şeyleri hastalar söylemez, sen bulursun.",
          "Asanı tara: hastanın çevresinde bir kalıntı belirir. Kızıl yara, yeşil zehir, mor lanet, mavi ruh, turuncu ateş.",
          "Masadaki defteri aç, belirtileri işaretle, hastalığı bul ve teşhisi koy. Tedavi sırası defterde yazar.",
          "Büyüyü biliyorsan rününü havada bir kez çizersin. Bilmiyorsan defterdeki rünü izlersin; ilk seferde tutmayabilir.",
          "Dolaptan bir şey gerekiyorsa hastanın yanından Accio ile çağır. Yanlış ilaç da bir yanlış tedavidir.",
          "İki yanlıştan sonra hastayı ben alırım. Ve sevilmeyen tek şey bu değildir: kurt ısırığını kendin çözmeye kalkma."
     },
     ipucu = {
          dinle = {"{hasta} ile konuştun mu? Hastalar en çok kendileri hakkında konuşmayı sever.", "Önce {hasta} ne anlatıyor, onu dinle."},
          muayene = {"{hasta} için muayene yapmadın. Elini kullan, gözlerini kullan.", "{hasta} bir şey saklıyor gibi. Muayene et."},
          tara = {"Asanla {hasta} hastasını taradın mı? Kalıntının rengi çok şey söyler.", "Renk, {oyuncu}. {hasta} hastasının kalıntı rengine bak."},
          defter = {"Belirtileri topladın; şimdi defter. Masada duruyor.", "Teşhis koymadan tedavi olmaz. Defteri aç.", "Defterde kalıntı rengine göre sayfaları süz; işin yarısı biter."},
          ciz = {"Teşhis tamam. Şimdi tedavi, {oyuncu}. Asanı kaldır.", "Rünü çizerken acele etme. Bilek, kol değil."},
          bitti = {"Hepsi tamam görünüyor. İyi iş."}
     },
     hastaGeldi = {"{no}. yatağa bir hasta geliyor, {oyuncu}.", "Kapıda biri var. {no}. yatağı hazırla.", "Yatak {no}: yeni bir hastan var.", "Bir hasta daha. {no}. yatak."},
     dogru = {"Güzel. Doğru büyü, doğru yer.", "Aferin. Elin yerinde.", "İşte böyle. Devam et.", "Hm. Fena değil, {oyuncu}.", "Böyle sakin kal, çok iyi gidiyorsun."},
     yanlis = {
          "Dur! Defteri bir daha oku, {oyuncu}.",
          "Bu büyü bu hastalığa yaramaz. Teşhisi gözden geçir.",
          "Ne yaptığını bilmeden asa sallama!",
          "Durum kötüleşti. Bir yanlış daha olursa hastayı ben alırım.",
          "Sakin. Belirtilere geri dön; bir şeyi atladın.",
          "Hayır, hayır, hayır. Kalıntının rengine baktın mı?"
     },
     devraldi = {
          "Yeter. Bu hastayı ben alıyorum. İzle ve öğren.",
          "Çekil biraz, {oyuncu}. Bunu ben hallederim.",
          "Hastayı devralıyorum. Bir dahakine teşhisini iki kez kontrol et.",
          "Pekâlâ, bu sefer olmadı. Hastalar beklemez, ben de beklemem."
     },
     sevkAldi = {"Doğru karar. Isırıkları ben takip ederim, sen de bunu kimseye söylemezsin.", "İyi. Bunu bana getirmen gerekiyordu. Gerisi bende.", "Akıllıca. Her şeyi bir gönüllü çözemez."},
     sevkGereksiz = {"Bunu sen de halledebilirsin, {oyuncu}. Bana yük yapma.", "Sevk mi? Bu basit bir vaka. Defterine bak.", "Her hastayı bana getirirsen ne işe yararsın?"},
     esyaYanlis = {"O değil! Dolabın yarısını boşaltacaksın.", "Bu ilaç bu hastaya ne yapsın? Defteri oku.", "Yanlış şişe, {oyuncu}."},
     iyilesti = {"Bir hasta daha ayağa kalktı. Güzel.", "{hasta} iyi görünüyor. Aferin.", "İşte şifacılık bu: sessizce iyileştirmek.", "Güzel iş, {oyuncu}. {hasta} gülümsüyor.", "Şunu gördün mü? İyileşen bir hastanın yüzünden güzel ilaç yoktur."},
     nobetIyi = {
          "Mükemmel bir nöbet, {oyuncu}. Senin gibi gönüllülerle revir boş kalır. Keşke.",
          "Hepsini kendin çözdün. Gelecekte Aziz Mungo'da görürüm seni.",
          "Bugün iyiydin. Bunu sık söylemem, biliyorsun.",
          "Bütün hastalar iyileşti. Git, biraz çikolata ye; hak ettin."
     },
     nobetOrta = {"İdare eder, {oyuncu}. Biraz daha dikkat, biraz daha sabır.", "Kötü değil. Defteri daha çok kullan.", "Hastalar iyi, sen de iyisin. Bir dahakine daha iyi olursun."},
     nobetKotu = {"Bugün zor geçti. Herkesin böyle günleri olur, ama defteri bir daha oku.", "Hastaların yarısını ben iyileştirdim, {oyuncu}. Yarın daha iyi olacak.", "Şifacılık acele kaldırmaz. Yarın yine gel."},
     birakti = {"Gidiyor musun? Peki. Hastalarına ben bakarım.", "Yarım bıraktın, {oyuncu}. Bir dahakine sonuna kadar kal.", "Hastaları ben alıyorum. Git, dinlen."},
     uzaklasti = {"{oyuncu} revirden çıktı, hastalarına ben bakıyorum.", "Nöbetini bıraktın, gönüllü. Hastaları devraldım."},
     dolasma = {
          "Bu yatakları kim böyle buruşturdu?",
          "Çikolata stoğu yine azalmış. Kim yiyor bunları?",
          "Bir de Quidditch'i tehlikesiz bir oyun sanıyorlar.",
          "Dolabı kilitlemem lazım; birileri yine Biberli İksir'i karıştırmış.",
          "Hogwarts'ta bir hafta kaza olmasa tatile çıkardım.",
          "Ev cinlerine söyle de çarşaflar yine kokmuyor.",
          "Merdivenleri büyüleyen kişiyle bir konuşmam lazım.",
          "Bu ay kaç kırık burun oldu? Saymayı bıraktım."
     },
     unvanAtladi = {"Bundan sonra sana '{unvan}' diyeceğim. Hak ettin.", "Revir defterine yazdım: {oyuncu}, {unvan}. Tebrikler.", "{unvan}... Kulağa hoş geliyor, değil mi? Şımarma ama."},
     ustalik = {"{buyu} elinde artık başka türlü parlıyor, fark ettin mi?", "{buyu} artık sana yabancı değil.", "{buyu} ile ustalaşıyorsun, {oyuncu}."},
     ogrendi = {"{buyu} artık senin. Defterden değil, kendi elinden çıkacak bundan sonra.", "Tebrikler, {oyuncu}: {buyu} büyüsünü öğrendin. Bir dahakine kılavuza gerek yok.", "{buyu}! Ezberledin, sonunda."},
     kilitli = {"{buyu} elinde tutundu ama henüz o seviyede değilsin. Büyü Ağacı'nda o kademe açılınca senin olacak.", "{buyu} için hazırsın sayılır; yalnız Büyü Ağacı'nda o kademe kapalı."},
     pomfreyOyuncu = {"Madam Pomfrey seni izliyor; dikkatli ol, bonuslu çalışıyorsun.", "Revirde Pomfrey var, deneyim artıyor."}
}

-- hastanın selamından sonra eklenebilen bağlam satırları
R.Baglam = {
     gece = {"Bu saatte yatakhanede olmam gerekiyordu. Kimseye söyleme, olur mu?", "Gece yarısı revirde olmak garip, değil mi? Her şey daha sessiz.", "Filch beni koridorda yakalamadan buraya kaçtım, sayılır.", "Gece bekçisi beni getirdi. Sana da gece nöbeti mi verdiler?"},
     sabah = {"Kahvaltıyı kaçırdım, onu da söyleyeyim.", "Daha güneş yeni doğdu ve ben buradayım. Harika bir gün.", "Sabah ilk dersten önce oldu her şey."},
     aksam = {"Akşam yemeğinden önce iyileşir miyim sence?", "Bütün gün dayanmaya çalıştım, artık dayanamadım."},
     yagmur = {"Dışarısı sırılsıklam; zaten her şey bundan başladı.", "Yağmurda her taş kaygan oluyor, bilirsin.", "Pencereye vuran yağmur sesi bile başımı ağrıtıyor."},
     kar = {"Kar yağıyor, herkes dışarıda eğleniyor, ben buradayım.", "Bu soğukta her şey daha kötü.", "Kardan adam yapmaya çıkmıştım. Kardan adam kazandı."},
     dolunay = {"Bu gece dolunay var, fark ettin mi? Pencereden baktım, bembeyaz.", "Dolunay gecelerinde revir hep doluymuş, öyle diyorlar."},
     quidditch = {"Maçtan geliyorum. Sonucu sorma.", "Tribünlerde bile güvende değilmişim.", "Bu maç sezonunda revir kapanmıyor, değil mi?"},
     ders_iksir = {"İksir dersinden geliyorum, zindan hâlâ dumanlı.", "Bugünkü iksir dersini kimse unutmayacak."},
     ders_bitki = {"Seradan geliyorum, cüppem hâlâ toprak.", "Bitki Bilimi dersi bugün biraz fazla canlıydı."},
     ders_yaratik = {"Hagrid'in dersinden geliyorum. Yeni bir yaratık getirmişti.", "Sihirli Yaratıkların Bakımı dersi her zamanki gibi... heyecanlıydı."},
     ders_ksks = {"Karanlık Sanatlara Karşı Savunma'dan geliyorum.", "Bugün derste pratik vardı. Pratik bana yaradı, görüyorsun."},
     ders_ucus = {"Uçuş dersinden geliyorum. Madam Hooch çok kızdı.", "Bugün uçuş dersiydi, ama sanırım yere iniş dersi lazımmış."},
     ders_tilsim = {"Tılsım dersinden geliyorum. Flitwick hâlâ masanın üstünde zıplıyordur.", "Bugün tılsım dersi biraz karıştı."},
     ayniHane = {"Sen de {hane} binasındansın, değil mi? Rozetini gördüm. İçim rahatladı.", "Aynı binadanız! O zaman bana iyi bakarsın.", "Bir {hane} tarafından iyileştirilmek ne güzel.", "Hey, ortak salonda seni görmüştüm!"},
     rakipHane = {"Rakip binadansın ama şu an umurumda değil. İyileştir beni.", "Bunu maçlarda hatırlatmayacağım, söz.", "Hm, o binadansın. Neyse, asan iyiyse sorun yok."},
     unvanYuksek = {"Sen {unvan} {oyuncu} değil misin? Seni herkes anlatıyor!", "Pomfrey'in en iyi yardımcısı sensin, öyle duydum.", "İyi ki sen geldin. Senin adını ortak salonda duydum."},
     donus = {"Yine ben... Geçen sefer {eski} yüzünden gelmiştim, hatırlarsın.", "Beni hatırladın mı? Geçen sefer {eski} için sen bakmıştın.", "Seni görünce sevindim. Geçen sefer çok iyiydin.", "Tekrar merhaba. Bu sefer başka bir dert."}
}

-- gönüllünün ağzından seçenekler
R.Secenek = {
     hikaye = {"Neler oldu, anlat bakalım.", "Bu hâle nasıl geldin?", "Baştan anlat, ne oldu?"},
     belirti = {"Nasıl hissediyorsun, neren ağrıyor?", "Neler hissediyorsun?", "Belirtilerini anlat."},
     sohbet = {"Hangi binadansın, kaçıncı yıl?", "Seni pek görmedim, kimlerdensin?"},
     rahatlat = {"Korkma, iyileşeceksin.", "Buradayım, merak etme.", "Derin nefes al; geçecek."},
     kapat = {"Şimdilik bu kadar, dinlen.", "Biraz dinlen, birazdan dönerim."},
     gonullu = "Gönüllü olmak istiyorum.",
     nasil = "Revirde nasıl çalışılır?",
     ipucu = "Bir ipucu verir misiniz?",
     birak = "Nöbeti bırakmak istiyorum.",
     tamam = "Tamam, işime dönüyorum.",
     hoscakal = "Sonra görüşürüz."
}
