umabis.serverapi = {
	last_sign_of_life = 0
}

local http
if string.sub(umabis.settings:get("api_uri"), 1, 5) == "https" then
	http = require("ssl.https")
else
	http = require("socket.http")
end

local function encode_post_body(params)
	local body = ""
	for k, v in pairs(params) do
		body = body .. k .. "=" .. v .. "&"
	end
	return body
end

local function do_request(post_get, command, params)
	local URI = umabis.settings:get("api_uri") .. command

	if umabis.serverapi.params then
		-- Add the server name and token
		params.server_name = umabis.settings:get("server_name")
		params.server_token = umabis.serverapi.params.token
	end

	local body, code
	if post_get == "GET" then
		body, code = http.request(URI .. "?" .. encode_post_body(params))
	else
	 	body, code = http.request(URI, encode_post_body(params))
	end

	umabis.serverapi.last_sign_of_life = os.time()

	if not body then
		minetest.log("error", "[umabis] "..post_get.." request to server ("..URI..") failed: "..code)
		return false
	end
	if code ~= 200 then
		minetest.log("error", "[umabis] "..post_get.." request to server ("..URI..") returned a non-200 code: "..code)
		return false
	end

	local umabis_code = body:sub(1,3)
	local umabis_body = body:sub(4)

	return umabis_code, umabis_body
end

local error_codes = {
	["001"] = "user is not registered",
	["002"] = "password hash does not match",
	["003"] = "user is already authenticated",
	["004"] = "more than 3 unsuccessful authentication attemps in last 30 minutes",
	["005"] = "user is blacklisted",
	["006"] = "name and token do not match",
	["007"] = "user e-mail is not public",
	["008"] = "unsufficient privileges",
	["009"] = "requested nick does not exist",
	["010"] = "user already (not) blacklisted/whitelisted",
	["011"] = "invalid category",
	["012"] = "missing parameter",
	["013"] = "session expired",
	["014"] = "user is not authenticated",
	["015"] = "name already registered",
	["016"] = "blacklisting a whitelisted user/whitelisting a blacklisted user",
	["017"] = "the server name is not registered",
	["018"] = "the server password does not match",
	["019"] = "the server IP does not match",
	["020"] = "the server session expired",
	["021"] = "the server is not authenticated",
	["022"] = "the server token does not match"
}

local function check_code(code, command)
	if not code then
		umabis.errstr = "no code returned"
		minetest.log("error", "[umabis] No code returned after serverapi command "..command)
		return false, "No code returned. This is a bug. Please contact the server administrator."
	end

	if error_codes[code] then
		umabis.errstr = error_codes[code]
		minetest.log("warning", "[umabis] Command '"..command.."' failed: "..error_codes[code])
		return false, string.gsub(error_codes[code], "^%l", string.upper)
	end

	return true
end

function umabis.serverapi.hello()
	-- Server name will be added by do_request
	local code, body = do_request("POST", "hello", {server_name = umabis.settings:get("server_name"), server_password = umabis.settings:get("server_password")})
	local ret, e = check_code(code, "hello")
	if not ret then
		return ret, e
	end

	local server_params = minetest.parse_json(body)

	if not server_params or type(server_params) ~= "table" then
		return false
	end

	umabis.serverapi.params = {
		session_expiration_delay = server_params.SESSION_EXPIRATION_DELAY,
		server_expiration_delay = server_params.SERVER_EXPIRATION_DELAY,
		version_string = server_params.VERSION,
		name = server_params.NAME,
		available_blacklist_categories = server_params.AVAILABLE_BLACKLIST_CATEGORIES,
		token = server_params.TOKEN
	}

	local major, minor, patch = string.match(server_params.VERSION, "(%d+)%.(%d+)%.(%d+)")
	umabis.serverapi.params.version_major = tonumber(major)
	umabis.serverapi.params.version_minor = tonumber(minor)
	umabis.serverapi.params.version_patch = tonumber(patch)

	if tonumber(major) ~= umabis.version_major then
		minetest.log("error", "[umabis] Server version is "..server_params.VERSION.." while my version is "..umabis.version_string..". "..
			"Different major versions are incompatible.")
		return false
	end

	if tonumber(minor) < umabis.version_minor then
		minetest.log("info", "[umabis] Server version is "..server_params.VERSION.." while my version is "..umabis.version_string..". "..
			"You should update me!")
	end

	if tonumber(minor) > umabis.version_minor then
		minetest.log("info", "[umabis] Server version is "..server_params.VERSION.." while my version is "..umabis.version_string..". "..
			"You should update the server!")
	end

	return true
end

function umabis.serverapi.goodbye()
	local code, body = do_request("POST", "goodbye", {})
	return check_code(code, "goodbye")
end

function umabis.serverapi.server_ping()
	local code, body = do_request("POST", "server_ping", {})
	return check_code(code, "server_ping")
end

function umabis.serverapi.ping(name, token)
	local code, body = do_request("POST", "ping", {name = name, token = token})
	local ret, e = check_code(code, "ping")
	if not ret then
		return ret, e
	end

	umabis.session.update_last_sign_of_life(name)

	return true
end

function umabis.serverapi.is_registered(name, ip_address)
	local code, body = do_request("GET", "is_registered", {name = name, ip_address = ip_address})
	local ret, e = check_code(code, "is_registered")
	if not ret then
		return ret, e
	end

	return tonumber(body)
end

function umabis.serverapi.register(name, hash, email, is_email_public, language_main,
	language_fallback_1, language_fallback_2, ip_address)
	local code, body = do_request("POST", "register", {
		name = name,
		hash = hash,
		["e-mail"] = email,
		is_email_public = is_email_public and 1 or 0,
		language_main = language_main,
		language_fallback_1 = language_fallback_1,
		language_fallback_2 = language_fallback_2,
		ip_address = ip_address
	})

	return check_code(code, "register")
end

function umabis.serverapi.authenticate(name, hash, ip_address)
	local code, body = do_request("POST", "authenticate", {
		name = name,
		hash = hash,
		ip_address = ip_address
	})

	local ret, e = check_code(code, "authenticate")
	if not ret then
		return ret, e
	end

	umabis.session.update_last_sign_of_life(name)

	return true, body
end

function umabis.serverapi.close_session(name, token)
	local code, body = do_request("POST", "close_session", {name = name, token = token})

	return check_code(code, "close_session")
end

function umabis.serverapi.blacklist_user(name, token, blacklisted_name, reason, category, time)
	local code, body = do_request("POST", "blacklist_user", {name = name, token = token, blacklisted_name = blacklisted_name, reason = reason, category = category, time = time})

	return check_code(code, "blacklist_user")
end

function umabis.serverapi.unblacklist_user(name, token, blacklisted_name)
	local code, body = do_request("POST", "unblacklist_user", {name = name, token = token, blacklisted_name = blacklisted_name})

	return check_code(code, "unblacklist_user")
end

function umabis.serverapi.whitelist_user(name, token, whitelisted_name)
	local code, body = do_request("POST", "whitelist_user", {name = name, token = token, whitelisted_name = whitelisted_name})

	return check_code(code, "whitelist_user")
end

function umabis.serverapi.unwhitelist_user(name, token, whitelisted_name)
	local code, body = do_request("POST", "unwhitelist_user", {name = name, token = token, whitelisted_name = whitelisted_name})

	return check_code(code, "unwhitelist_user")
end

function umabis.serverapi.is_blacklisted(name, ip_address)
	local code, body = do_request("GET", "is_blacklisted", {ip_address = ip_address, name = name})

	local ret, e = check_code(code, "is_blacklisted")
	if not ret then
		return ret, e
	end

	if body:sub(1, 1) == "0" then
		return true, "not"
	end

	local entry = minetest.parse_json(body:sub(2))
	if not entry then
		-- An error message describing the error should already have been logged by minetest.parse_json
		minetest.log("error", "[umabis] Command 'is_blacklisted' failed (error parsing JSON).")
		return false
	end

	if body:sub(1, 1) == "1" then
		return true, "nick", entry
	else
		return true, "ip", entry
	end
end

function umabis.serverapi.set_pass(name, token, hash)
	local code, body = do_request("POST", "set_pass", {name = name, token = token, hash = hash})

	return check_code(code, "set_pass")
end

function umabis.serverapi.get_user_info(name, token, requested_name)
	local code, body = do_request("GET", "get_user_info", {name = name, token = token, requested_name = requested_name})

	local ret, e = check_code(code, "get_user_info")
	if not ret then
		return ret, e
	end

	local table = minetest.parse_json(body)
	if not table then
		-- An error message describing the error should already have been logged by minetest.parse_json
		minetest.log("error", "[umabis] Command 'get_user_info' failed (error parsing JSON).")
		return false
	end

	return true, table
end
