-- "addons\\sardonshineadmin\\lua\\sardon_shineadmin\\_sh_core.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Shine Admin :: ortak çekirdek. Dosya adı "_" ile başlıyor ki SardonUtil
-- alfabetik yüklemede cl_/sv_ dosyalarından önce gelsin.
--
-- Buradaki yetki kontrolleri iki tarafta da aynı. İstemcide yalnızca hangi
-- sayfanın görüneceğini belirler; her işlem sunucuda, sayfanın ait olduğu
-- eklentinin kendi kontrolünden yeniden geçer.

ShineAdmin = ShineAdmin or {}

local function IsStaff(ply)
     return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function HasFlag(ply, flag)
     local char = IsValid(ply) and ply.GetCharacter and ply:GetCharacter()
     return char and char:HasFlags(flag) or false
end

-- Her kural, kaynak eklentinin sunucu tarafındaki kontrolünün aynısı
ShineAdmin.Access = {
     staff = IsStaff,
     superadmin = function(ply)
          return IsValid(ply) and ply:IsSuperAdmin()
     end,
     -- [fx] irk sunucu.lua: superadmin veya yonetimlideri
     leader = function(ply)
          return IsValid(ply) and (ply:IsSuperAdmin() or ply:IsUserGroup("yonetimlideri"))
     end,
     -- whitelist_sardon sv_init.lua: admin veya "w" bayrağı
     whitelist = function(ply)
          return IsStaff(ply) or HasFlag(ply, "w")
     end,
     -- [sardon] socials: admin veya "m" bayrağı
     socials = function(ply)
          return IsStaff(ply) or HasFlag(ply, "m")
     end,
     -- [sardon-fx] ders shared.lua: PLAYER:isProfessor()
     professor = function(ply)
          return IsValid(ply) and ply.isProfessor and ply:isProfessor() or false
     end,
     -- [admin] sam menüsü: yetkili ya da SAM'in yönetim izinlerinden birine sahip rütbe.
     -- Yalnızca sayfanın görünürlüğü; işlemleri SAM sunucuda kendi denetler.
     sam = function(ply)
          if (!IsValid(ply)) then return false end
          if (IsStaff(ply)) then return true end
          if (!sam or !ply.HasPermission) then return false end

          for _, perm in ipairs({"manage_players", "manage_bans", "manage_ranks", "manage_config"}) do
               if (ply:HasPermission(perm)) then return true end
          end

          return false
     end,
     -- gamemode item_menu eklentisi
     itemmenu = function(ply)
          return IsValid(ply) and (ply:IsSuperAdmin() or (CAMI and CAMI.PlayerHasAccess(ply, "Helix - Item Menu", nil)) or false)
     end
}

function ShineAdmin.Can(ply, rule)
     local fn = ShineAdmin.Access[rule]
     return fn and fn(ply) and true or false
end

-- Paneli açma hakkı: en az bir sayfayı görebilen herkes
function ShineAdmin.CanOpen(ply)
     for _, fn in pairs(ShineAdmin.Access) do
          if (fn(ply)) then
               return true
          end
     end

     return false
end

ix.command.Add("ShineAdmin", {
     description = "Abre el panel de administración Shine.",
     OnRun = function(self, client)
          if (!ShineAdmin.CanOpen(client)) then
               return "No tienes permiso para abrir este panel."
          end

          client:ConCommand("shine_admin")
     end
})
