-- "addons\\sardonekonomi\\lua\\sardon_ekonomi\\sh_8takas.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] ekonomi: /Takas komutu (karşındaki oyuncuya bakarak). Mantık sv_8takas.lua, pencere cl_4takas.lua.
ix.command.Add("Takas", {
     description = "Baktığın oyuncuya güvenli takas isteği gönderir (ya da onun isteğini kabul eder).",
     OnRun = function(self, client)
          if SardonEkonomi and SardonEkonomi.Takas and SardonEkonomi.Takas.Iste then
               SardonEkonomi.Takas.Iste(client)
          end
     end
})
