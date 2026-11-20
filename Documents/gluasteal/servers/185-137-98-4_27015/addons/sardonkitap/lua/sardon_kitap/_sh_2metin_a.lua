-- "addons\\sardonkitap\\lua\\sardon_kitap\\_sh_2metin_a.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: metinler 1/2 — Goshawk (Standart Büyüler, 1. Sınıf), Switch, Trimble.
-- Bölüm: id, baslik, sayfalar = {...}, buyu (kitaptan Büyü Ağacı fiyatının %20 altına öğrenilir), sure (sn, yoksa ayar),
-- soru = {"soru", {"doğru", "yanlış", "yanlış"}, doğruNo} (sınavda şıklar karıştırılır).
-- Sunucuda olmayan bir büyü bölümü yalnızca okunur (rün istenmez).
-- Shine Admin'den düzenlenen başlık/sayfalar data/sardon_kitap/metin.json'dan bunların üstüne yazılır.

local SK = SardonKitap

SK.Metin.goshawk1 = {
     {id = "onsoz", baslik = "Önsöz: Asanı Tanı", sayfalar = {
          "Bu kitabı eline alan her öğrenci aynı şeyi merak eder: büyü nereden gelir? Sözden mi, asadan mı, yoksa insanın kendisinden mi? Cevap, üçünün buluştuğu yerdedir. Söz büyüye ad verir, asa ona yön verir, sen de ona niyet verirsin.",
          "Asanı kolunla değil bileğinle yönet. Parmakların asayı sıkmasın; bir kuş tutar gibi tut. Asa hareketi ne kadar küçük ve temizse büyü o kadar keskin çıkar. Bu kitaptaki her büyünün bir rünü, yani havada çizilen bir yolu vardır.",
          "Bir büyüyü kitaptan öğrenmek mümkündür ama kolay değildir. Kitaptan öğrenilen büyü ilk zamanlarda tekleyebilir. Kitaptan öğrenmenin bedeli Büyü Ağacı'ndakinden %20 düşüktür. Büyüyü bir derste ya da tecrübeli bir öğrencinin gözü önünde kullanmak, onu gerçekten senin yapar.",
     }, soru = {"Kitaptan öğrenilen bir büyü ilk zamanlarda ne yapabilir?", {"Tekleyebilir", "Hiç çalışmaz", "İki kat güçlü çıkar"}, 1}},

     {id = "lux", baslik = "Lux Bulbus: Asa Ucunda Işık", buyu = "Lux Bulbus", sayfalar = {
          "Karanlık bir koridorda ya da gece gölünde yolunu bulmanın en eski yolu, asanın ucuna küçük bir ışık çağırmaktır. Lux Bulbus, birinci sınıf öğrencilerinin çoğunun ilk başardığı büyüdür; çünkü korku, büyüyü en çok karanlıkta ister.",
          "Büyü asanın ucunda kısa süreli bir ışık kaynağı yaratır. Işık kendiliğinden söner; uzun bir yol için büyüyü tekrarlaman gerekir. Işığı büyük düşünme: avucuna sığan bir ateş böceği hayal et, büyü onu büyütecektir.",
          "Rünü çizerken acele etme. Başlangıç halkasından çık, yolu tek hamlede bitir. Elin titrerse durma; titrek bir çizgi bile yarıda kesilmiş bir çizgiden iyidir.",
     }, soru = {"Lux Bulbus'un ışığı için doğru olan hangisi?", {"Kısa süre sonra kendiliğinden söner", "Sabaha kadar yanar", "Yalnız gündüz çalışır"}, 1}},

     {id = "wingardium", baslik = "Wingardium Leviosa: Süzülme Tılsımı", buyu = "Wingardium Leviosa", sayfalar = {
          "Nesneleri havaya kaldırmak, tılsım sanatının kapısıdır. Wingardium Leviosa büyüsü baktığın nesneyi asana bağlar; asanı oynattıkça nesne de seninle birlikte süzülür.",
          "Bu büyüde en sık yapılan hata sözün vurgusudur: Win-GAR-dium Levi-O-sa. Vurguyu yanlış yere koyan öğrencinin tüyü yerinden kıpırdamaz. Hareket ise basittir: savur ve fiske.",
          "Ünlü bir uyarı: büyücü Baruffio bir keresinde 's' yerine 'f' söylemiş ve kendini göğsünde bir mandayla yerde bulmuştur. Sözlerini dikkatle söyle.",
     }, soru = {"Wingardium Leviosa'nın asa hareketi nasıl tarif edilir?", {"Savur ve fiske", "Daire ve nokta", "Üç kez vur"}, 1}},

     {id = "spongify", baslik = "Spongify: Yumuşatma Tılsımı", buyu = "Spongify", sayfalar = {
          "Spongify, sert bir yüzeyi bir anlığına sünger gibi esnek yapar. Okulda bu büyüyü kullanan öğrenciler onu daha çok kendilerini havaya fırlatmak için severler: büyü baktığın yöne doğru seni yaylandırır.",
          "Yüksek bir yere ulaşmak ya da hızla yol almak için kullanışlıdır; ama nereye düşeceğini düşünmeden kullanılan Spongify, revirde biten bir maceradır. Önce iniş yerini seç, sonra büyüyü söyle.",
     }, soru = {"Spongify'ı kullanmadan önce ne düşünmelisin?", {"Nereye ineceğini", "Kaç kez söyleyeceğini", "Hangi haneden olduğunu"}, 1}},

     {id = "aguamenti", baslik = "Aguamenti: Su Çağırma", buyu = "Aguamenti", sayfalar = {
          "Aguamenti asanın ucundan temiz su akıtır. Saksıdaki bir bitkiyi sulamaktan küçük bir yangını söndürmeye kadar her yerde işe yarar. Botanik öğrencileri bu büyüyü kovadan daha çok kullanır.",
          "Rün iki dalgadan oluşur: önce yukarı, sonra aşağı, suyun akışı gibi. Dalgaları eşit çizmezsen su damla damla gelir; eşit çizersen akar.",
     }, soru = {"Aguamenti'nin rünü neye benzer?", {"Suyun akışı gibi iki dalgaya", "Bir anahtara", "Bir yıldıza"}, 1}},

     {id = "lumos", baslik = "Lumos: Asa Işığı", buyu = "Lumos", sayfalar = {
          "Lumos, asanın ucunu beyaz bir ışıkla yakar; Nox ise o ışığı söndürür. Lux Bulbus'tan farkı, ışığın asaya bağlı kalması ve büyücü istedikçe sürmesidir. Bu yüzden Lumos daha fazla odak ister.",
          "Kuramı şudur: Lux Bulbus ışığı dışarı bırakır, Lumos ise içeride tutar. Işığı tutmak, bırakmaktan zordur. Lux Bulbus'u rahatça yapabilen öğrenci Lumos'a hazırdır.",
     }, soru = {"Lumos'un ışığını söndüren büyü hangisidir?", {"Nox", "Finite", "Alohomora"}, 1}},

     {id = "alohomora", baslik = "Alohomora: Kilit Açma", buyu = "Alohomora", sayfalar = {
          "Alohomora kilitleri açar. Büyüyle korunmayan her kapı, sandık ve kilit bu büyüye boyun eğer; ama iyi bir büyücünün mührü Alohomora'ya gülüp geçer.",
          "Hırsızlar bu büyüyü çok sever, bu yüzden Hogwarts'ın kapıları onu tanır. Kuram açıktır: kilit bir sırdır, Alohomora o sırrı nazikçe sorar. Kaba bir istek kapıyı açmaz.",
     }, soru = {"Alohomora hangi kilitleri açamaz?", {"Büyüyle mühürlenmiş kilitleri", "Ahşap kapıları", "Sandık kilitlerini"}, 1}},

     {id = "finite", baslik = "Finite: Büyüyü Sonlandırma", buyu = "Finite", sayfalar = {
          "Finite, süren bir büyüyü sona erdirir. Havada asılı kalmış bir arkadaş, durmadan dans eden bacaklar, sönmeyen bir ateş... Hepsi için ilk denenecek büyü budur.",
          "Kuramı: her büyü bir ip gibidir ve Finite o ipi keser. Ama güçlü bir büyünün ipi kalındır; Finite onu hemen kesemeyebilir. Bu yüzden Finite'i kullanan büyücü, karşısındaki büyünün gücünü tartmayı öğrenmelidir.",
     }, soru = {"Finite ne işe yarar?", {"Süren bir büyüyü sona erdirir", "Kilit açar", "Işık yakar"}, 1}},

     {id = "hatalar", baslik = "Sık Yapılan Hatalar", sayfalar = {
          "Birinci yılda en sık görülen hatalar şunlardır: rünü çok küçük çizmek, köşeleri yuvarlamak, hareketi yarıda kesmek ve büyüyü bağırarak söylemek. Büyü ses yüksekliğinden değil, kararlılıktan güç alır.",
          "Bir büyü tekleyince asanı suçlama. Ollivander'ın dediği gibi asa büyücüyü seçer; ama büyüyü yapan yine büyücüdür. Tekleyen büyüyü bir derste ya da tecrübeli bir arkadaşının yanında dene.",
     }, soru = {"Büyü gücünü neden alır?", {"Kararlılıktan", "Ses yüksekliğinden", "Asanın uzunluğundan"}, 1}},
}

SK.Metin.switch = {
     {id = "onsoz", baslik = "Biçim Değiştirme Nedir?", sayfalar = {
          "Biçim değiştirme, Hogwarts'ta öğretilen en karmaşık ve en tehlikeli büyü dalıdır. Bir şeyi başka bir şeye dönüştürmek, onun ne olduğunu tam olarak bilmeyi gerektirir. Bu yüzden biçim değiştirme dersinde şakaya yer yoktur.",
          "İlk derste öğrenciler genellikle bir kibriti iğneye çevirmeye çalışır. Ders sonunda kibriti biraz gümüşleştirip ucunu sivriltebilen öğrenci, sınıfın en başarılısı sayılır.",
     }, soru = {"Biçim değiştirme dersinde ilk denenen dönüşüm genellikle nedir?", {"Kibriti iğneye çevirmek", "Kurbağayı prense çevirmek", "Taşı altına çevirmek"}, 1}},

     {id = "yasalar", baslik = "Üç Temel Kural", sayfalar = {
          "Birinci kural: büyük bir şeyi küçük bir şeye çevirmek, küçüğü büyüğe çevirmekten kolaydır. İkinci kural: cansızı cansıza çevirmek, canlıya dokunmaktan güvenlidir. Üçüncü kural: hiçbir dönüşüm sonsuza dek sürmez; dikkat dağıldıkça biçim eski haline döner.",
          "Gamp'ın Temel Biçim Değiştirme Yasası beş istisna sayar; bunların en bilineni yiyecektir. Yiyecek yoktan var edilemez. Çağrılabilir, çoğaltılabilir, pişirilebilir; ama yoktan yaratılamaz.",
     }, soru = {"Gamp'ın Yasası'na göre yoktan var edilemeyen şeylerin en bilineni nedir?", {"Yiyecek", "Su", "Işık"}, 1}},

     {id = "avis", baslik = "Avis: Kuş Çağırma", buyu = "Avis", sayfalar = {
          "Avis, asanın ucundan bir sürü küçük kuş çıkarır. Çağırma ile biçim değiştirme arasındaki sınırda duran bu büyü, birinci sınıfların en sevdiği gösteridir.",
          "Kuşlar senin niyetini taşır: sakin bir niyet uysal serçeler, telaşlı bir niyet çığlık atan bir sürü getirir. Rün iki kanat çırpışıdır; iki yayı eşit çiz.",
     }, soru = {"Avis büyüsünde kuşların davranışını ne belirler?", {"Büyücünün niyeti", "Havanın sıcaklığı", "Asanın ağacı"}, 1}},

     {id = "colovaria", baslik = "Colovaria: Renk Değiştirme", buyu = "Colovaria", sayfalar = {
          "Colovaria, baktığın nesnenin rengini değiştirir. Biçim değiştirmenin en zararsız ama en öğretici biçimidir: renk, bir nesnenin en yüzeydeki özelliğidir ve onu değiştirmek, öğrenciye dönüşümün ilk adımını hissettirir.",
          "Rengi değiştirmeden önce yeni rengi gözünün önüne getir. 'Kırmızı olsun' demek yetmez; hangi kırmızı? Gün batımı mı, kiraz mı, ejderha kanı mı? Açık bir resim, temiz bir büyü verir.",
     }, soru = {"Colovaria'yı kullanmadan önce ne yapmalısın?", {"Yeni rengi açıkça gözünde canlandırmalısın", "Nesneye dokunmalısın", "Gözlerini kapatmalısın"}, 1}},

     {id = "bookamons", baslik = "Book a mons: Kendini Kitaba Çevirmek", buyu = "Book a mons", sayfalar = {
          "Bu tuhaf büyü, büyücünün kendisini bir kitaba çevirir. Bir kütüphanede saklanmak isteyen öğrencilerin efsanevi büyüsüdür. Kendine uygulanan bir dönüşüm olduğu için, birinci yıl için cesur bir denemedir.",
          "Unutma: kitaba dönüşmüş bir büyücü konuşamaz, yürüyemez ve rafa kaldırılabilir. Büyüyü bir arkadaşının yanında dene.",
     }, soru = {"Book a mons büyüsü neyi dönüştürür?", {"Büyücünün kendisini", "Baktığı kitabı", "Bir kuşu"}, 1}},
}

SK.Metin.trimble = {
     {id = "onsoz", baslik = "Korkunun Adı", sayfalar = {
          "Karanlık güçlere karşı ilk savunma bir büyü değil, bir alışkanlıktır: sakin kalmak. Korkan büyücü yanlış büyüyü seçer, doğru büyüyü yanlış söyler. Bu kitap sana önce durmayı, sonra korunmayı öğretir.",
          "Hogwarts'ta Karanlık Sanatlara Karşı Savunma öğretmenleri pek uzun kalmaz; ama bu kitap her yıl yerinde durur. İçindekiler değişmez, çünkü korunmanın temeli değişmez.",
     }, soru = {"Bu kitaba göre karanlık güçlere karşı ilk savunma nedir?", {"Sakin kalmak", "İlk saldıran olmak", "Kaçmak"}, 1}},

     {id = "protego", baslik = "Protego: Kalkan Büyüsü", buyu = "Protego", sayfalar = {
          "Protego, önünde bir anlık sihirli bir duvar yükseltir. Çoğu büyüyü geri çevirir; Affedilmez Lanetler ise bu duvarı tanımaz. Bir düelloda Protego'yu doğru anda kullanmak, iki saldırı büyüsünden değerlidir.",
          "Kalkanın ömrü kısadır. Erken açılan kalkan, büyü gelmeden söner. Karşındakinin asasına bak; asa ucunun parladığı an kalkanını kaldır.",
     }, soru = {"Protego hangi büyülere karşı işe yaramaz?", {"Affedilmez Lanetlere", "Gıdıklama büyüsüne", "Silahsızlandırma büyüsüne"}, 1}},

     {id = "fumos", baslik = "Fumos: Duman Perdesi", buyu = "Fumos", sayfalar = {
          "Fumos, çevrene yoğun bir duman perdesi çeker. Saldıranın seni görememesi, çoğu zaman en iyi korunmadır. Duman seni saklar ama korumaz; perdenin arkasında yerini değiştirmeyi unutma.",
     }, soru = {"Fumos'tan sonra ne yapmalısın?", {"Yerini değiştirmelisin", "Dumanın içinde beklemelisin", "Büyüyü tekrarlamalısın"}, 1}},

     {id = "episkey", baslik = "Episkey: İlk Yardım", buyu = "Episkey", sayfalar = {
          "Episkey küçük yaraları kapatır, kırık bir burnu düzeltir, kanayan bir kesiği durdurur. Her büyücünün bilmesi gereken ilk yardım büyüsüdür. Ağır yaralar için Revir'e git; Episkey yalnızca zamanı satın alır.",
          "Büyüyü yaralı birine bakarak uygula. Kendi yarana uygulamak da mümkündür ama dikkat ister. Şifa büyülerinde acele, en büyük düşmandır.",
     }, soru = {"Ağır bir yarada Episkey'den sonra ne yapılmalıdır?", {"Revir'e gidilmelidir", "Büyü üç kez tekrarlanmalıdır", "Yara kendi haline bırakılmalıdır"}, 1}},

     {id = "petrificus", baslik = "Petrificus Totalus: Tam Vücut Bağlama", buyu = "Petrificus Totalus", sayfalar = {
          "Tam Vücut Bağlama Laneti hedefini bir heykel gibi dondurur. Saldırı için değil, kaçmak ya da bir tehlikeyi durdurmak için öğretilir. Donmuş biri görür ve duyar ama kıpırdayamaz.",
          "Kuramı: lanet hedefin hareket iradesini değil, kaslarını bağlar. Bu yüzden Finite onu kolayca çözer. Birini dondurup orada bırakmak, okul kurallarına göre ağır bir suçtur.",
     }, soru = {"Petrificus Totalus'u hangi büyü kolayca çözer?", {"Finite", "Lumos", "Avis"}, 1}},

     {id = "expelliarmus", baslik = "Expelliarmus: Silahsızlandırma", buyu = "Expelliarmus", sayfalar = {
          "Silahsızlandırma Büyüsü karşındakinin asasını elinden uçurur. Yaralamaz, öldürmez; yalnızca kavgayı bitirir. Bu yüzden birçok ünlü büyücünün en güvendiği büyüdür.",
          "Kuramı: Expelliarmus asaya değil, asayla büyücü arasındaki bağa vurur. Asası sahibine çok bağlı olan büyücüyü silahsızlandırmak daha zordur.",
     }, soru = {"Expelliarmus neye vurur?", {"Asayla büyücü arasındaki bağa", "Büyücünün kalbine", "Asanın özüne"}, 1}},

     {id = "yaratiklar", baslik = "Karanlık Yaratıklar Üzerine Kısa Not", sayfalar = {
          "Böcürt korktuğun şeyin biçimine girer; ona gülmek onu yener. Kırmızı başlıklar kan dökülmüş yerlerde, hendeklerde yaşar. Grindylow'lar göllerin dibinde ince parmaklarıyla bekler. Karanlık her zaman bir büyü değildir; bazen bir yaratıktır.",
          "Bu yaratıkların ayrıntısı Newt Scamander'ın kitabındadır. Bu kitap yalnızca şunu söyler: tanıdığın bir korku, tanımadığın bir korkudan yarı yarıya küçüktür.",
     }, soru = {"Böcürt nasıl yenilir?", {"Ona gülerek", "Ondan kaçarak", "Onu kafese kapatarak"}, 1}},
}
