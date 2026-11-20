-- "addons\\sardonck\\lua\\sardon_ck\\_sh_core.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon CK :: ortak. CK (karakter kalıcı ölümü) artık onayla:
-- CK büyüleri (Avada Kedavra, Fulgur Merlin) kurbanı öldürür ama karakteri hemen kapatmaz.
-- Katile ve kurbana onay penceresi gelir; ikisi de onaylarsa CK uygulanır.
-- Biri onaylamaz ya da süre dolarsa istek Shine Admin "CK Onayları" sayfasına
-- düşer; yetkili onaylayana kadar karakter yaşamaya devam eder.

SardonCK = SardonCK or {}

SardonCK.Sure = 90 -- onay penceresinin açık kalacağı saniye

-- kayıt durumları
SardonCK.Durum = {
     soruluyor = "Taraflara soruluyor",
     yetkili = "Yetkili onayı bekliyor",
     ck = "CK uygulandı",
     reddedildi = "Yetkili reddetti"
}

-- taraf cevabı: nil = cevap yok (süre doldu / çıktı), true / false
function SardonCK.CevapYazi(v)
     if (v == true) then return "onayladı" end
     if (v == false) then return "onaylamadı" end
     return "cevap vermedi"
end

-- Shine Admin "staff" kuralıyla aynı
function SardonCK.Yetkili(ply)
     return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end
