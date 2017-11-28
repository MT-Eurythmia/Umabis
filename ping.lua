local time_count = 0
minetest.register_globalstep(function(dtime)
	-- Execute the globalstep every second only.
	time_count = time_count + dtime
	if time_count < 1 then
		return
	end
	time_count = 0

	local current_time = os.time()
	for name, t in pairs(umabis.session.sessions) do
		if t.token and t.last_sign_of_life + umabis.session.ping_interval <= current_time then
			minetest.log("info", "[umabis] Pinging for session "..name)
			umabis.serverapi.ping(name, umabis.session.sessions[name].token)
		end
	end

	-- Server ping
	if umabis.serverapi.last_sign_of_life + umabis.serverapi.params.server_expiration_delay * 2/3 < os.time() then
		minetest.log("info", "[umabis] Server pinging")
		umabis.serverapi.server_ping()
	end
end)
