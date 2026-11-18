-- Sardon Baykuş :: base de datos y persistencia
SardonBaykus = SardonBaykus or {}
local B = SardonBaykus

B.DATA_DIR = "sardon_baykus"
file.CreateDir(B.DATA_DIR)

local function jRead(path, fallback)
	local raw = file.Read(path, "DATA")
	if not raw or raw == "" then return fallback end
	return util.JSONToTable(raw) or fallback
end

local function jWrite(path, tab)
	file.Write(path, util.TableToJSON(tab, false))
end

function B.DbInit()
	sql.Query([[
		CREATE TABLE IF NOT EXISTS sardon_baykus (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			sender TEXT NOT NULL,
			receiver TEXT NOT NULL,
			content TEXT NOT NULL,
			anonim TEXT NOT NULL DEFAULT '0',
			read_flag TEXT NOT NULL DEFAULT '0',
			timestamp INTEGER NOT NULL DEFAULT 0,
			bohca_owner TEXT,
			bohca_data TEXT
		);
	]])

	B.Settings = jRead(B.DATA_DIR .. "/settings.json", {
		enabled = 1,
		maxItems = 5,
		maxMoney = 50000,
		accio = 1,
		accioRange = 1200,
		flightTimeout = 600,
		discord = 0,
		discordMessages = 0,
	})

	B.Whitelist = jRead(B.DATA_DIR .. "/whitelist.json", {})
	B.Logs = jRead(B.DATA_DIR .. "/logs.json", {})
	B.PendingBohca = jRead(B.DATA_DIR .. "/pending_bohca.json", {})
end

function B.DbDefaults()
	return {
		enabled = 1,
		maxItems = B.MaxItemsHard or 5,
		maxMoney = 50000,
		accio = 1,
		accioRange = 1200,
		flightTimeout = 600,
		discord = 0,
		discordMessages = 0,
	}
end

function B.SaveSettings()
	jWrite(B.DATA_DIR .. "/settings.json", B.Settings or B.DbDefaults())
end

function B.SaveWhitelist()
	jWrite(B.DATA_DIR .. "/whitelist.json", B.Whitelist or {})
end

function B.SaveLogs()
	local logs = B.Logs or {}
	while #logs > 500 do
		table.remove(logs, 1)
	end
	jWrite(B.DATA_DIR .. "/logs.json", logs)
end

function B.SavePending()
	jWrite(B.DATA_DIR .. "/pending_bohca.json", B.PendingBohca or {})
end

function B.Log(kind, actor, sender, receiver, details)
	B.Logs = B.Logs or {}
	B.Logs[#B.Logs + 1] = {
		time = os.time(),
		kind = kind,
		actor = actor or "",
		sender = sender or "",
		receiver = receiver or "",
		details = details or "",
	}
	B.SaveLogs()
end

function B.WhitelistCount()
	local n = 0
	for id, on in pairs(B.Whitelist or {}) do
		if on then n = n + 1 end
	end
	return n
end

function B.IsWhitelisted(uniqueID)
	return B.Whitelist and B.Whitelist[uniqueID] == true
end

hook.Add("DatabaseConnected", "SardonBaykus.Db", function()
	B.DbInit()
end)

hook.Add("Initialize", "SardonBaykus.Db", function()
	timer.Simple(0, function()
		if not B._dbReady then
			B.DbInit()
			B._dbReady = true
		end
	end)
end)