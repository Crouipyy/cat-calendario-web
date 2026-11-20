-- Servidor :: red (Istek → Durum / Sonuc / Gecmis / Bildirim)
if not SERVER then return end

local SG = SardonGacha
if not SG then return end

local ISTEK = SG.ISTEK

function SG.DurumGonder(ply)
	if not IsValid(ply) then return end
	local t = SG.DurumTablosu(ply)
	if not t then
		SG.BildirimGonder(ply, "No se pudo cargar tu cuenta.", "hata")
		return
	end
	net.Start("SardonGacha.Durum")
	SG.Yaz(t)
	net.Send(ply)
end

local function TakasYap(ply, kaynak, adet)
	kaynak = tostring(kaynak or "")
	adet = math.Clamp(math.floor(tonumber(adet) or 0), 1, 100)
	local ay = SG.Ayar
	if kaynak ~= "adak" and kaynak ~= "toz" then
		return SG.BildirimGonder(ply, "Origen de canje no válido.", "hata")
	end

	local fiyat = kaynak == "adak" and math.max(1, math.floor(tonumber(ay.biletFiyat) or 160))
		or math.max(1, math.floor(tonumber(ay.tozBilet) or 75))
	local tutar = adet * fiyat

	local v = SG.OyuncuAl(ply)
	if not v then
		return SG.BildirimGonder(ply, "No se pudo cargar el monedero.", "hata")
	end
	local saldo = v[kaynak] or 0
	if saldo < tutar then
		local n = kaynak == "adak" and (ay.adakAd or "ofrenda") or (ay.tozAd or "polvo")
		return SG.BildirimGonder(ply, "No tienes suficiente " .. n .. ".", "hata")
	end

	v[kaynak] = saldo - tutar
	v.bilet = (v.bilet or 0) + adet
	SG.KayitEkle(SG.Sid64(ply), kaynak, -tutar, v[kaynak], "Canje por " .. adet .. " " .. (ay.biletAd or "boleto"))
	SG.KayitEkle(SG.Sid64(ply), "bilet", adet, v.bilet, "Canje desde " .. kaynak)
	SG.OyuncuKaydet(SG.Sid64(ply))

	local nBoleto = ay.biletAd or "boleto"
	SG.BildirimGonder(ply, "+" .. SG.Sayi(adet) .. " " .. nBoleto, "bilet")
	SG.DurumGonder(ply)
end

local CD = {}

net.Receive("SardonGacha.Istek", function(_, ply)
	if not IsValid(ply) then return end
	local sid = SG.Sid64(ply)
	CD[sid] = CD[sid] or 0
	if CD[sid] > CurTime() then return end

	local tur = net.ReadUInt(4)

	if tur == ISTEK.DURUM then
		CD[sid] = CurTime() + 0.15
		SG.DurumGonder(ply)
		return
	end

	if tur == ISTEK.TAKAS then
		CD[sid] = CurTime() + 0.35
		local kaynak = net.ReadString()
		local adet = net.ReadUInt(8)
		TakasYap(ply, kaynak, adet)
		return
	end

	if tur == ISTEK.GECMIS then
		CD[sid] = CurTime() + 0.25
		local v = SG.OyuncuAl(ply)
		local liste = {}
		if v and v.gecmis then
			for i = 1, math.min(100, #v.gecmis) do
				local r = v.gecmis[i]
				liste[#liste + 1] = {
					y = r.y,
					ad = r.ad,
					afis = r.afis,
					yeni = r.yeni,
					toz = r.toz,
					t = r.t,
				}
			end
		end
		net.Start("SardonGacha.Gecmis")
		SG.Yaz({ liste = liste })
		net.Send(ply)
		return
	end

	if tur == ISTEK.CEK then
		CD[sid] = CurTime() + 2
		local afisId = net.ReadString()
		local adet = net.ReadUInt(4)
		local adakla = net.ReadBool()

		local sonuc, err = SG.TiradaYap(ply, afisId, adet, adakla)
		if not sonuc then
			SG.BildirimGonder(ply, err or "No se pudo completar el deseo.", "hata")
			return
		end

		net.Start("SardonGacha.Sonuc")
		SG.Yaz({ sonuc = sonuc, afis = afisId })
		net.Send(ply)
		SG.DurumGonder(ply)
		return
	end

	SG.BildirimGonder(ply, "Petición desconocida.", "hata")
end)

hook.Add("PlayerInitialSpawn", "SardonGacha.Durum", function(ply)
	timer.Simple(2, function()
		if IsValid(ply) then SG.OyuncuAl(ply) end
	end)
end)