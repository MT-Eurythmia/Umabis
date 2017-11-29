local sessions = {}

local function unpriv(name)
	sessions[name].old_privs = minetest.get_player_privs(name)
	minetest.set_player_privs(name, minetest.string_to_privs(umabis.settings:get("auth_privs")))

	local player = minetest.get_player_by_name(name)
	sessions[name].old_physics_override = player:get_physics_override()
	player:set_physics_override({
		speed = 0,
		jump = 0
	})
end

local function priv_back(name)
	minetest.set_player_privs(name, sessions[name].old_privs)
	sessions[name].old_privs = nil
	minetest.get_player_by_name(name):set_physics_override(sessions[name].old_physics_override)
	sessions[name].old_physics_override = nil
end

local function create_session(name)
	unpriv(name)
	minetest.show_formspec(name, "umabis:welcome", string.format(umabis.formspecs.welcome, name))
end

local function authenticate(name)
	local ok, token = umabis.serverapi.authenticate(name, minetest.get_auth_handler().get_auth(name).password, sessions[name].ip_address)
	if not ok then
		-- token contains the error string
		return false, token
	end
	sessions[name].token = token
	minetest.log("action", "[umabis] Player "..name.." was successfully authenticated.")
	return true
end

local function register(name)
	local ok, e = umabis.serverapi.register(name, minetest.get_auth_handler().get_auth(name).password, sessions[name].email,
		sessions[name].is_email_public, sessions[name].language_main, sessions[name].language_fallback_1,
		sessions[name].language_fallback_2, sessions[name].ip_address)
	if not ok then
		return false, e
	end
	authenticate(name)
	priv_back(name)
	return true
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()

	if not string.find(formname, ":") then
		formname = "umabis:" .. formname
	end

	if formname == "umabis:welcome" then
		if fields.continue then
			sessions[name].is_email_public = true
			minetest.after(0.1, function()
				minetest.show_formspec(name, "umabis:provide_info", umabis.formspecs.provide_info)
			end)
		elseif fields.exit then
			minetest.kick_player(name, "Exiting.")
			-- Session will be cleared in the on_leaveplayer callback.
		else
			minetest.after(0.2, minetest.show_formspec, name, "umabis:welcome", string.format(umabis.formspecs.welcome, name))
		end
	elseif formname == "umabis:provide_info" then
		if fields.is_email_public then
			sessions[name].is_email_public = fields.is_email_public == "true"
		elseif fields.continue then
			sessions[name].email = fields.email
			sessions[name].language_main = fields.language_main
			sessions[name].language_fallback_1 = fields.language_fallback_1
			sessions[name].language_fallback_2 = fields.language_fallback_2

			local ok, e = register(name)
			if ok then
				minetest.show_formspec(name, "umabis:registration_done", umabis.formspecs.registration_done)
			else
				minetest.kick_player(name, "An error occured while registering your account: " .. e
					.. "\nPlease contact the server administrator.")
			end
		elseif fields.exit then
			minetest.kick_player(name, "Exiting.")
			-- Session will be cleared in the on_leaveplayer callback.
		else
			minetest.after(0.2, minetest.show_formspec, name, "umabis:provide_info", umabis.formspecs.provide_info)
		end
	end
end)

umabis.register_on_reload(function()
	umabis.session = {}
	umabis.session.sessions = sessions

	function umabis.session.prepare_session(name, ip_address)
		sessions[name] = {
			ip_address = ip_address,
			timeout = true
		}

		local is_registered = umabis.serverapi.is_registered(name, ip_address)
		if is_registered ~= 0 then
			local ok, e = authenticate(name)
			if not ok then
				sessions[name] = nil
				return false, e
			end
		else
			sessions[name].to_create = true
		end

		-- Set a timeout (in case another on_prejoinplayer callback kicks the player before on_joinplayer is executed)
		minetest.after(umabis.settings:get_int("joinplayer_timeout"), function()
			if sessions[name].timeout then
				minetest.log("warning", "[umabis] Joinplayer callback timeout for session '" .. name .."'")
				sessions[name] = nil
			end
		end)
		return true
	end

	function umabis.session.new_session(name)
		local session = sessions[name]

		if not session then
			minetest.kick_player(name, "Sorry, it seems that your Umabis session was not prepared."..
				"This is a bug. Use the latest version of Minetest and contact the server administrator"..
				" (their nick is "..minetest.settings:get("name")..").")
			return
		end

		session.timeout = nil

		if session.to_create then
			create_session(name)
			session.to_create = nil
		end
	end

	function umabis.session.clear_session(name)
		if sessions[name].token then
			umabis.serverapi.close_session(name, sessions[name].token)
		end
		sessions[name] = nil
	end

	function umabis.session.clear_all()
		for name, _ in pairs(sessions) do
			umabis.session.clear_session(name)
		end
	end

	function umabis.session.set_password(name, password)
		local ok, err = umabis.serverapi.set_pass(name, sessions[name].token, password)
		if not ok then
			minetest.log("error", "[umabis] Error while setting password: " .. err)
			minetest.chat_send_player(name, minetest.colorize("#FF0000", "There was a problem while setting your password. Your password should have been left unchanged."))
			return false
		end
		return true
	end


	-- Pinging
	function umabis.session.update_last_sign_of_life(name)
		sessions[name].last_sign_of_life = os.time()
	end

	do
		local ping_interval = tonumber(umabis.settings:get("ping_interval"))
		if not ping_interval or ping_interval == 0 then
			ping_interval = math.max(umabis.serverapi.params.session_expiration_delay * 2/3, umabis.serverapi.params.session_expiration_delay - 60)
		end
		umabis.session.ping_interval = ping_interval
	end
end)
