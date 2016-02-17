#!/usr/bin/lua

local juci = require("juci/core"); 

local function shadow_table()
	local result = {}; 
	local shadow = juci.readfile("/etc/shadow"); 
	for line in shadow:gmatch("[^\r\n]+") do 
		local fields = {}; 
		for field in line:gmatch("[^:]+") do
			table.insert(fields, field); 
		end
		table.insert(result, fields); 
	end
	return result; 
end

local function checkpassword(user, pass)
	local shadow = juci.readfile("/etc/shadow"); 
	local shpass = nil; 
	for line in shadow:gmatch("[^\r\n]+") do 
		local fields = {}; 
		for field in line:gmatch("[^:]+") do
			table.insert(fields, field); 
		end
		if(fields[1] == user) then shpass = fields[2]; end
	end
	if shpass == nil then return false; end
	local typ, salt, hash = shpass:match("$([^$]+)$([^$]+)$([^$]+).*"); 
	local epass = juci.shell("echo %s | openssl passwd -1 -salt "..salt.." -stdin", pass);
	epass = epass:match("[^\r\n]+"); 
	if shpass == epass then 
		return true; 
	end
	return false; 
end

local function user_set_password(opts)
	if not opts["password"] then return 5; end
	local session = juci.session.get(opts.sid); 
	if not session then 
		return { error = "Could not find session!" }; 
	end
	if session.data.username ~= opts.username and not juci.session.access(opts.sid, "passwd", "otheruser", { "write" }) then 
		return { error = "Can not change password for another user!" }; 
	end
	if not juci.session.access(opts.sid, "passwd", "self", { "write" }) then 
		return { error = "Permission denied!" };
	end
	if not checkpassword(opts.username, opts.oldpassword) then 
		return { error = "Invalid username/password!"}; 
	end
	local stdout = juci.shell("echo -e \"%s\" | passwd %s", opts["password"].."\\n"..opts["password"], opts["username"]); 
	return {
		["stdout"] = stdout
	}; 
end

local function user_list(opts)
	-- list only users that are configured for rpc logins
	local all_users = juci.shell("uci show rpcd | grep username | awk -F'=' '{print $2;}'");  
	local users = {};
	local listothers = juci.session.access(opts.sid, "passwd", "otheruser", { "write" }); 
	local session = juci.session.get(opts.sid); 
	if(not session) then
		return { users = {}, error = "Session not found! ("..(opts.sid or "")..")"};
	end
	for user in all_users:gmatch("[^\r\n]+") do
		if(not listothers) then 
			if(session.data.username == user) then table.insert(users, user); end
		else
			table.insert(users, user); 
		end
	end
	return { users = users };  
end

return {
	["setpassword"] = user_set_password,
	["listusers"] = user_list
}; 