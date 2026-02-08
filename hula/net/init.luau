--!strict
--!native

local RunService = game:GetService("RunService")
local isserver = RunService:IsServer()

local Players = game:GetService("Players")

local RemoteEvent = script:WaitForChild("RemoteEvent")
local UnreliableRemoteEvent = script:WaitForChild("UnreliableRemoteEvent")
local UnixTimestampRemote = script:WaitForChild("UnixTimestampRemote")

--- writes signed 24-bit integer to buffer
local function writei24(b: buffer, offset: number, value: number)
	local bitoffset = offset * 8
	local sign = math.sign(value) < 0 and 1 or 0
	if sign == 1 then
		value += 1
	end

	buffer.writebits(b, bitoffset, 23, math.abs(value))
	buffer.writebits(b, bitoffset + 23, 1, sign)
end

--- reads signed 24-bit integer from buffer
local function readi24(b: buffer, offset: number)
	local bitoffset = offset * 8
	local value = buffer.readbits(b, bitoffset, 23)
	local sign = buffer.readbits(b, bitoffset + 23, 1)
	
	if sign == 1 then
		value *= -1
		value -= 1
	end
	
	return value
end

--- writes unsigned 24-bit integer to buffer
local function writeu24(b: buffer, offset: number, value: number)
	buffer.writebits(b, offset * 8, 24, value)
end

--- reads unsigned 24-bit integer from buffer
local function readu24(b: buffer, offset: number)
	return buffer.readbits(b, offset * 8, 24)
end

--- returns a data-typed buffer of variable width
local function createtypedbuffer(i: number, size: number)
	local b = buffer.create(1 + size)
	buffer.writeu8(b, 0, i)

	return b
end

--- resolves optimal remote wrt packet size of net send args
local function resolveremote(b: buffer, i: {Instance}): RemoteEvent|UnreliableRemoteEvent
	local len = 1 + buffer.len(b) + (#i * 5)
	
	if isserver then
		if len > 127 then
			len += 13
		else
			len += 12
		end
	else
		if len > 127 then
			len += 18
		else
			len += 17
		end
	end

	if len >= 990 then
		return RemoteEvent
	else
		return UnreliableRemoteEvent
	end
end

--- hard-checks net recv args
local function assertrecvtypes(b: buffer, i: {Instance})
	assert(type(b) == "buffer", string.format("expected buffer, got %s", type(b)))
	assert(type(i) == "table", string.format("expected table, got %s", type(i)))
	for _, instance in i do
		assert(typeof(instance) == "Instance", string.format("expected Instance, got %s", typeof(i)))
	end
end

--- appends u8 net scope to end of buffer
local function writescope(b: buffer, u8: number)
	local size = buffer.len(b) + 1
	local s = buffer.create(size)
	buffer.copy(s, 0, b)
	buffer.writeu8(s, size - 1, u8)

	return s
end

--- reads u8 net scope from end of buffer
local function readscope(s: buffer)
	return buffer.readu8(s, buffer.len(s) - 1)
end

--- removes u8 net scope from end of buffer
local function removescope(s: buffer)
	local size = buffer.len(s) - 1
	local b = buffer.create(size)
	buffer.copy(b, 0, s, 0, size)

	return b
end

--- ### net.luau
---
--- `client<->server` network interface `port <P>` \
--- `vm<->vm` network interface `hook <H>` \
--- server-authoritative `DateTime.now().UnixTimestampMillis`
local net = {
	unixbuffer = buffer.create(8);
	framerate = 1/60;
	
	ports = {};
	ships = table.create(255) :: {string};
	queue = table.create(64) :: { {any} };
	
	hooks = {};
}

--- returns `client<->server` network interface `<P>` \
--- values are queued, compressed into a buffer, then sent via appropriate `unreliable/reliable remoteevent` \
--- `port.serverrecvlimitmillis` defaults to `net.framerate * 1000`
function net.port(key: string)
	if not net.ports[key] then
		local port = {
			serverrecvlimitmillis = net.framerate * 1000;
			players = {};
		}

		--- look for ship
		if not table.find(net.ships, key) then
			if isserver then
				--- make one
				assert(#net.ships <= 2^8-1, "net at max ships (u8 limit)")
				table.insert(net.ships, key)
					
				local ship = table.find(net.ships, key)
				assert(ship, "this should not happen") --- somehow wasnt inserted despite literally being inserted 3 lines earlier
				script:SetAttribute(key, ship)
			else
				--- to bad!
				--- warn(string.format("net unknown ship %s", key))
			end
		end

		--- queues value to be sent through this port \
		--- `force(="reliable"|"unreliable")`: forces remoteevent when this value is sent \
		--- `force(=nil)`: automatically resolves remoteevent wrt value size \
		--- `front(=true)`: value is inserted to front of queue \
		--- `front(=false|nil)`: value is inserted to back of queue
		port.fire = function(value: any, client:
			| nil
			| number
			| Player
			| { number|Player }
			| (Player) -> boolean,
			force: "reliable"|"unreliable"?,
			front: boolean?
		)
			local ship = table.find(net.ships, key)
			assert(ship, string.format("net unknown ship '%s'", key))

			local unscoped, instances = net.pack(value)
			local scoped = writescope(unscoped, ship or 0)

			if front == true then
				table.insert(net.queue, 1, {scoped::any, instances::any, client::any, force::any})
			else
				table.insert(net.queue, {scoped::any, instances::any, client::any, force::any})
			end
		end

		--- connects function to this port \
		--- returns `{ RBXScriptConnection } C`: where \
		--- ... `C[1] = RemoteEvent.On[Client/Server]Event` \
		--- ... `C[2] = UnreliableRemoteEvent.On[Client/Server]Event` 
		port.connect = function(f: ((value: any) -> ()) & (player: Player, value: any) -> ())
			if isserver then
				local function serverrecv(player: Player, s: buffer, i: {Instance})
					--- resolve ship
					local ship = table.find(net.ships, key)
					if not ship then return end --- assert(ship, string.format("net unknown ship '%s'", key))

					--- earliest exit if not associated ship
					if ship ~= readscope(s) then return end

					--- assert types and ship
					assertrecvtypes(s, i)

					--- resolve recv limit wrt player
					local nowmillis = DateTime.now().UnixTimestampMillis
					local lastrecv = port.players[player]
					lastrecv = type(lastrecv) == "number" and lastrecv or 0

					if nowmillis - lastrecv >= port.serverrecvlimitmillis then
						port.players[player] = nowmillis

						local value = net.unpack(removescope(s), 0, i)
						f(player, value)
					else
						--- warn(string.format("net server recv '%s' packet dropped (%dms)", key, nowmillis - lastrecv), player.UserId)
					end
				end

				return {
					RemoteEvent.OnServerEvent:Connect(serverrecv),
					UnreliableRemoteEvent.OnServerEvent:Connect(serverrecv)
				}
			else
				local function clientrecv(s: buffer, i: {Instance})
					local ship = table.find(net.ships, key)
					if not ship then return end  --- assert(ship, string.format("net unknown ship '%s'", key))

					assertrecvtypes(s, i)

					if ship == readscope(s) then
						local value = net.unpack(removescope(s), 0, i)
						f(value)
					end
				end

				return {
					RemoteEvent.OnClientEvent:Connect(clientrecv),
					UnreliableRemoteEvent.OnClientEvent:Connect(clientrecv)
				}
			end
		end

		net.ports[key] = port
	end

	return net.ports[key]
end

--- unsigned integer lookup
local ulookup = {
	{ key = "u8", value = {0, 255}; size = 1; write = buffer.writeu8; read = buffer.readu8; };
	{ key = "u16", value = {0, 65535}; size = 2; write = buffer.writeu16; read = buffer.readu16; };
	{ key = "u24", value = {0, 16777215}; size = 3; write = writeu24; read = readu24; };
	{ key = "u32", value = {0, 4294967295}; size = 4; write = buffer.writeu32; read = buffer.readu32; };
}

--- signed integer lookup
local ilookup = {
	{ key = "i8", value = {-128, 127}; size = 1; write = buffer.writei8; read = buffer.readi8; };
	{ key = "i16", value = {-32768, 32767}; size = 2; write = buffer.writei16; read = buffer.readi16; };
	{ key = "i24", value = {-8388608, 8388607}; size = 3; write = writei24; read = readi24; };
	{ key = "i32", value = {-2147483648, 2147483647}; size = 4; write = buffer.writei32; read = buffer.readi32; };
}

--- type lookup
local typelookup = {
	"nil";
	"Instance";

	"table";
	"buffer";
	"string";

	"boolean";
	"number";

	"u8";
	"u16";
	"u24";
	"u32";

	"i8";
	"i16";
	"i24";
	"i32";

	"f32";
	"f64";

	"Vector2";
	"Vector3";
	"CFrame";
	"Color3";
}

--- returns: \
--- `value` packed into a buffer \
--- `instances` supplementary instance table \
--- \
--- instances are returned as a supplementary table to pass into `unwrap()` when decoding \
--- as there is no way to represent an instance into buffer-only terms \
--- \
--- `strings` must be no longer than 255 characters, as their length is encoded as an unsigned 8-bit integer \
--- `tables & arrays` must contain no more than 65535 key-value/index-value pairs, as their length is encoded as an unsigned 16-bit integer
function net.pack(value: any, instances: {Instance}?)
	local i = table.find(typelookup, typeof(value))
	assert(i, string.format("unsupported type %s", typeof(value)))

	instances = instances or {}
	assert(instances)

	local b = buffer.create(0)

	if typeof(value) == "nil" then
		b = createtypedbuffer(i, 0)

	elseif typeof(value) == "Instance" then
		local offset = table.find(instances, value)
		if not offset then
			table.insert(instances, value)
			offset = #instances
		end
		assert(offset)

		b = createtypedbuffer(i, 1)
		buffer.writeu8(b, 1, offset)

	elseif typeof(value) == "table" then
		local result = {}
		if #value > 0 then
			for idx, val in ipairs(value) do
				local idxb = net.pack(idx, instances)
				local valb = net.pack(val, instances)

				local idxlen, vallen = buffer.len(idxb), buffer.len(valb)
				local pair = buffer.create(idxlen + vallen)
				buffer.copy(pair, 0, idxb)
				buffer.copy(pair, idxlen, valb)

				table.insert(result, pair)
			end
		else
			for key, val in value do
				local keyb = net.pack(key, instances)
				local valb = net.pack(val, instances)

				local idxlen, vallen = buffer.len(keyb), buffer.len(valb)
				local pair = buffer.create(idxlen + vallen)
				buffer.copy(pair, 0, keyb)
				buffer.copy(pair, idxlen, valb)

				table.insert(result, pair)
			end
		end

		local size = 0
		local len = 0
		for _, thisb in result do
			size += buffer.len(thisb)
			len += 1
		end

		local prebuffer = buffer.create(size)
		local offset = 0
		for _, thisb in ipairs(result::any) do
			local thislen = buffer.len(thisb)
			buffer.copy(prebuffer, offset, thisb, 0, thislen)
			offset += thislen
		end

		b = createtypedbuffer(i, buffer.len(prebuffer) + 2)
		buffer.writeu16(b, 1, len)
		buffer.copy(b, 3, prebuffer)

	elseif typeof(value) == "buffer" then
		local len = buffer.len(value)

		b = createtypedbuffer(i, len + 2)
		buffer.writeu16(b, 1, len)
		buffer.copy(b, 3, value)

	elseif typeof(value) == "string" then
		local len = string.len(value)

		b = createtypedbuffer(i, len + 1)
		buffer.writeu8(b, 1, len)
		buffer.writestring(b, 2, value, len)

	elseif typeof(value) == "boolean" then
		b = createtypedbuffer(i, 1)
		buffer.writeu8(b, 1, value and 1 or 0)

	elseif typeof(value) == "number" then
		if value == value and value ~= 1/0 and value ~= -1/0 then
			local integer, fraction = math.modf(value)
			if fraction == 0 then
				--- integer
				for _, a in ipairs(integer < 0 and (ilookup::any) or (ulookup::any)) do
					if integer >= a.value[1] and integer <= a.value[2] then
						local itype = a.key
						b = createtypedbuffer(table.find(typelookup::any, itype)::number, a.size)
						a.write(b, 1, integer)

						break
					end
				end
				
				--- fallback to f64 if integer exceeds i/u32 limit
				b = createtypedbuffer(table.find(typelookup, "f64")::number, 8)
				buffer.writef64(b, 1, value)

			else
				--- float
				if integer < 2^24-1 then --- f32 integer limit
					b = createtypedbuffer(table.find(typelookup, "f32")::number, 4)
					buffer.writef32(b, 1, value)

				else
					b = createtypedbuffer(table.find(typelookup, "f64")::number, 8)
					buffer.writef64(b, 1, value)

				end
			end
		else
			b = createtypedbuffer(table.find(typelookup, "f64")::number, 8)
			buffer.writef64(b, 1, value)

		end

	elseif typeof(value) == "Vector2" then
		local vec = {}
		for _, value in ipairs{value.X, value.Y} do
			local thisb = net.pack(value, instances)
			table.insert(vec, thisb)
		end

		local size = 0
		for _, thisb in vec do
			size += buffer.len(thisb)
		end

		local vecbuffer = buffer.create(size)
		local offset = 0
		for _, thisb in ipairs(vec::any) do
			buffer.copy(vecbuffer, offset, thisb, 0, buffer.len(thisb))
			offset += buffer.len(thisb)
		end

		b = createtypedbuffer(i, buffer.len(vecbuffer))
		buffer.copy(b, 1, vecbuffer)

	elseif typeof(value) == "Vector3" then
		local vec = {}
		for _, value in ipairs{value.X, value.Y, value.Z} do
			local thisb = net.pack(value, instances)
			table.insert(vec, thisb)
		end

		local size = 0
		for _, thisb in vec do
			size += buffer.len(thisb)
		end

		local vecbuffer = buffer.create(size)
		local offset = 0
		for _, thisb in ipairs(vec::any) do
			buffer.copy(vecbuffer, offset, thisb, 0)
			offset += buffer.len(thisb)
		end

		b = createtypedbuffer(i, buffer.len(vecbuffer))
		buffer.copy(b, 1, vecbuffer)

	elseif typeof(value) == "CFrame" then
		local vec = {}
		for _, value in ipairs{value.X, value.Y, value.Z} do
			local thisb = net.pack(value, instances)
			table.insert(vec, thisb)
		end

		local size = 0
		for _, thisb in vec do
			size += buffer.len(thisb)
		end

		local vecbuffer = buffer.create(size)
		local offset = 0
		for _, thisb in ipairs(vec::any) do
			buffer.copy(vecbuffer, offset, thisb)
			offset += buffer.len(thisb)
		end

		local rx, ry, rz = value:ToOrientation()
		local r = buffer.create(3)
		local rlen = buffer.len(r)
		buffer.writeu8(r, 0, math.map(rx, -math.pi, math.pi, 0, 255))
		buffer.writeu8(r, 1, math.map(ry, -math.pi, math.pi, 0, 255))
		buffer.writeu8(r, 2, math.map(rz, -math.pi, math.pi, 0, 255))

		local prebuffer = buffer.create(size + rlen)
		buffer.copy(prebuffer, 0, vecbuffer)
		buffer.copy(prebuffer, size, r)

		b = createtypedbuffer(i, buffer.len(prebuffer))
		buffer.copy(b, 1, prebuffer)

	elseif typeof(value) == "Color3" then
		local red = net.pack(value.R * 255, instances)
		local rlen = buffer.len(red)
		local green = net.pack(value.G * 255, instances)
		local glen = buffer.len(green)
		local blue = net.pack(value.B * 255, instances)
		local blen = buffer.len(blue)

		local prebuffer = buffer.create(rlen + glen + blen)
		buffer.copy(prebuffer, 0, red)
		buffer.copy(prebuffer, rlen, green)
		buffer.copy(prebuffer, rlen + glen, blue)

		b = createtypedbuffer(i, buffer.len(prebuffer))
		buffer.copy(b, 1, prebuffer)

	end

	return b, instances
end

--- returns: \
--- `value`: unpacked value, packed by `decode`, beginning at `offset`, using supplementary instance table `instances` \
--- `offset`: final offset after unpacking the buffer, should equate to `buffer.len(b)`
function net.unpack(pack: buffer, offset: number, instances: {Instance}): (any, number)
	local datatype = typelookup[buffer.readu8(pack, offset)]::any

	if datatype == "nil" then
		return nil, offset

	elseif datatype == "Instance" then
		offset += 1
		return instances[buffer.readu8(pack, offset)], offset + 1

	elseif datatype == "table" then
		offset += 1
		local len = buffer.readu16(pack, offset)

		offset += 2
		local result = {}
		for i = 1, len do
			local key, aoffset = net.unpack(pack, offset, instances)
			offset = aoffset
			local value, boffset = net.unpack(pack, offset, instances)
			offset = boffset 

			result[key] = value
		end

		return result, offset

	elseif datatype == "buffer" then
		offset += 1
		local len = buffer.readu16(pack, offset)
		local thisbuffer = buffer.create(len)

		offset += 2
		buffer.copy(thisbuffer, 0, pack, offset, len)

		return thisbuffer, offset + len

	elseif datatype == "string" then
		offset += 1
		local len = buffer.readu8(pack, offset)

		offset += 1
		return buffer.readstring(pack, offset, len), offset + len

	elseif datatype == "boolean" then
		offset += 1
		return buffer.readu8(pack, offset) == 1, offset + 1

	elseif datatype == "number" then
		--- last case

	elseif datatype == "Vector2" then
		local position = table.create(2)::{number}
		for i = 1, 2 do
			offset += 1
			local value, nextoffset = net.unpack(pack, offset, instances)
			assert(type(value) == "number", string.format("expected number, got %s", type(value)))
			offset = nextoffset - 1
			table.insert(position, value)
		end

		return Vector2.new(position[1], position[2]), offset + 1

	elseif datatype == "Vector3" then
		local position = table.create(3)::{number}
		for i = 1, 3 do
			offset += 1
			local value, nextoffset = net.unpack(pack, offset, instances)
			assert(type(value) == "number", string.format("expected number, got %s", type(value)))
			
			offset = nextoffset - 1
			table.insert(position, value)
		end

		return Vector3.new(position[1], position[2], position[3]), offset + 1

	elseif datatype == "CFrame" then
		local position = table.create(3)::{number}
		for i = 1, 3 do
			offset += 1
			local value, nextoffset = net.unpack(pack, offset, instances)
			assert(type(value) == "number", string.format("expected number, got %s", type(value)))

			offset = nextoffset - 1
			table.insert(position, value)
		end

		local rotation = table.create(3)::{number}
		for i = 1, 3 do
			offset += 1
			table.insert(rotation, math.map(buffer.readu8(pack, offset), 0, 255, -math.pi, math.pi))
		end

		return CFrame.new(position[1], position[2], position[3]) * CFrame.fromOrientation(rotation[1], rotation[2], rotation[3]), offset + 1

	elseif datatype == "Color3" then
		local color = table.create(3)::{number}
		for i = 1, 3 do
			offset += 1
			local value, nextoffset = net.unpack(pack, offset, instances)
			assert(type(value) == "number", string.format("expected number, got %s", type(value)))

			offset = nextoffset - 1
			table.insert(color, value)
		end

		return Color3.fromRGB(color[1], color[2], color[3]), offset + 1

	elseif datatype == "f32" then
		offset += 1
		return buffer.readf32(pack, offset), offset + 4

	elseif datatype == "f64" then
		offset += 1
		return buffer.readf64(pack, offset), offset + 8

	else
		--- true number case
		for _, uentry in ulookup do
			if uentry.key == datatype then

				offset += 1
				return uentry.read(pack, offset), offset + uentry.size
			end
		end
		for _, ientry in ilookup do
			if ientry.key == datatype then

				offset += 1
				return ientry.read(pack, offset), offset + ientry.size
			end
		end
	end

	return nil, offset
end

--- returns `vm<->vm` network interface `<H>` \
--- functions are deferred
function net.hook(key: string)
	if not net.hooks[key] then
		local hook = {
			functions = {} :: { () -> () };
			onces = {} :: { () -> () };
			yields = {} :: { thread };
		}

		--- recursively resumes yielded threads
		local function resume(...: any)
			local co = table.remove(hook.yields)
			if co then
				task.defer(co, ...)
				resume(...)
			else
				return
			end
		end

		--- recursively removes-then-defers functions bound by hook.once()
		local function onces(...: any)
			local f = table.remove(hook.onces)
			if f then
				task.defer(f, ...)
				onces(...)
			else
				return
			end
		end

		--- connects function to this hook
		hook.connect = function(f: (...any) -> ())
			table.insert(hook.functions, f)

			return function()
				table.remove(hook.functions, table.find(hook.functions, f) or 0)
			end
		end
		--- connects function to this hook to be fired once
		hook.once = function(f: (...any) -> ())
			table.insert(hook.onces, f)

			return function()
				table.remove(hook.onces, table.find(hook.onces, f) or 0)
			end
		end
		--- yields thread until this hook is fired
		hook.wait = function()
			table.insert(hook.yields, coroutine.running())

			return coroutine.yield()
		end
		--- calls functions bound to this hook along with any arguments passed
		hook.fire = function(...: any)
			for _, f in hook.functions do
				task.defer(f, ...)
			end
			
			onces(...)
			resume(...)
		end
		--- disconnects all functions bound to this hook
		hook.disconnectall = function()
			table.clear(hook.functions)
			table.clear(hook.onces)
		end
		--- destroys this hook, resuming any yielded threads prior to destruction
		hook.destroy = function(...: any)
			resume(...)

			table.clear(hook.functions)
			table.clear(hook.onces)
			
			table.clear(hook)
			;(net.hooks::any)[key] = nil
		end

		net.hooks[key] = hook
	end

	return net.hooks[key]
end

--- returns server-authoritative `DateTime.now().UnixTimestamp`
function net.s()
	return buffer.readf64(net.unixbuffer, 0) / 1000
end

--- returns server-authoritative `DateTime.now().UnixTimestampMillis`
function net.ms()
	return buffer.readf64(net.unixbuffer, 0)
end

--- runs function at `step` second interval for `time` seconds \
--- exceptions: \
--- `step == -1`: function is called every heartbeat \
--- `time == -1`: bound function runs indefinitely
function net.framerule(step: number, time: number, f: (dt: number, elapsed: number) -> (), immediate: boolean?): (RBXScriptConnection, thread?)
	if time == -1 then
		local start = os.clock()
		local recent = os.clock()
		if immediate ~= false then
			recent -= step or 1/60 --- doesn't matter
		end

		if step == -1 then
			return RunService.Heartbeat:Connect(function(dt)
				f(dt, os.clock() - start)
			end), nil
		else
			return RunService.Heartbeat:Connect(function()
				local now = os.clock()
				local dt = now - recent
				if dt > step then
					recent = now - (dt - step)

					f(dt, now - start)
				end
			end), nil
		end
	else
		local connection = net.framerule(step, -1, f, immediate)

		return connection, task.delay(time, connection.Disconnect, connection)
	end
end

--- runs function at `step` stepfrequency for `time` seconds \
--- exceptions: \
--- `time == -1`: bound function runs indefinitely
function net.fixedstep(step: Enum.StepFrequency, time: number, f: (dt: number) -> ()): (RBXScriptConnection, thread?)
	if time == -1 then
		return RunService:BindToSimulation(f, step), nil
	else
		local connection = net.fixedstep(step, -1, f)

		return connection, task.delay(time, connection.Disconnect, connection)
	end
end

--- returns a timestamp describing time wrt format option or time in minutes
function net.timestamp(time: number, format: "hour" | "halfday" | "day" | "week" | "month" | "season" | "biannual" | "year" | number)
	local datetable = os.date("!*t", time) --- read from this table as a truth state
	local nextdatetable = table.clone(datetable) --- write to this table, keys inherited from datetable

	local timestamp = {
		--- unique, non-recurring string describing format time
		id = "";
		--- unique, non-recurring number describing format time
		seed = 0;
		--- time until format changes
		change = 0;
	}

	if type(format) == "number" then
		--- `Format: 5`
		--- `February 14, 2024, 06:44` --> `"2024_45_6_8"`
		--- `Format: 10`
		--- `February 14, 2024, 06:44` --> `"2024_45_6_4"`
		--- `Format: 15`
		--- `February 14, 2024, 06:44` --> `"2024_45_6_2"`
		nextdatetable.min = format * -((nextdatetable.min + 1) // -format)
		nextdatetable.sec = 0

		local year, yday, hour, qtrhour = datetable.year, datetable.yday, datetable.hour, -((nextdatetable.min + 1) // -format) - 1
		timestamp.id = string.format("%d_%d_%d_%d", year, yday, hour, qtrhour)
		timestamp.seed = tonumber(year .. yday .. hour .. qtrhour) :: number
	else
		if format == "hour" then
			--- `February 14, 2024, 06:44` --> `"2024_45_6"`
			nextdatetable.hour = math.floor(nextdatetable.hour + 1)
			nextdatetable.min = 0
			nextdatetable.sec = 0

			local year, yday, hour = datetable.year, datetable.yday, datetable.hour
			timestamp.id = string.format("%d_%d_%d", year, yday, hour)
			timestamp.seed = tonumber(year .. yday .. hour) :: number
		elseif format == "halfday" then
			--- `February 14, 2024, 06:44` --> `"2024_45_AM"`
			--- `February 14, 2024, 16:44` --> `"2024_45_PM"`
			nextdatetable.hour = 12 * -((nextdatetable.hour + 1) // -12)
			nextdatetable.min = 0
			nextdatetable.sec = 0

			local year, yday, phase = datetable.year, datetable.yday, os.date("!%p")
			timestamp.id = string.format("%d_%d_%s", year, yday, phase)
			timestamp.seed = tonumber(year .. yday .. string.byte(phase)) :: number
		elseif format == "day" then
			--- `February 14, 2024` --> `"2024_45"`
			nextdatetable.day += 1
			nextdatetable.hour = 0
			nextdatetable.min = 0
			nextdatetable.sec = 0

			local year, yday = datetable.year, datetable.yday
			timestamp.id = string.format("%d_%d", year, yday)
			timestamp.seed = tonumber(year .. yday) :: number
		elseif format == "week" then
			--- `February 14, 2024` --> `"2024_7_06"` (06th week of 2024)
			nextdatetable.day += 8 - datetable.wday
			nextdatetable.hour = 0
			nextdatetable.min = 0
			nextdatetable.sec = 0

			local year, week, yweek = datetable.year, datetable.wday, os.date("!%U")
			timestamp.id = string.format("%d_%d_%s", year, week, yweek)
			timestamp.seed = tonumber(year .. week .. yweek) :: number
		elseif format == "month" then
			--- `February 14, 2024` --> `"2024_02"` (2nd month of 2024)
			nextdatetable.month = 1 + (nextdatetable.month % 12)

			if nextdatetable.month < datetable.month then
				--- modulo into next year
				nextdatetable.year += 1
			end

			nextdatetable.day = 0
			nextdatetable.hour = 0
			nextdatetable.min = 0
			nextdatetable.sec = 0

			local year, month = datetable.year, os.date("!%m")
			timestamp.id = string.format("%d_%s", year, month)
			timestamp.seed = tonumber(year .. month) :: number
		elseif format == "season" then
			--- `February 14, 2024` --> `"2024_1"`
			--- Jan-Mar: `1` (spring)
			--- Apr-Jun: `2` (summer)
			--- Jul-Sep: `3` (autumn)
			--- Oct-Dec: `4` (winter)

			local month = datetable.month
			local season = 1 + ((month-1) // 3)

			local nextyear = 0
			local nextseasonmonth = 1 + (season * 3)
			if nextseasonmonth > 12 then
				nextyear += 1
				nextseasonmonth %= 12
			end

			nextdatetable.month = nextseasonmonth
			nextdatetable.year += nextyear

			nextdatetable.day = 1
			nextdatetable.hour = 0
			nextdatetable.min = 0
			nextdatetable.sec = 0

			local year = datetable.year
			timestamp.id = string.format("%d_%d", year, season)
			timestamp.seed = tonumber(year .. season) :: number
		elseif format == "biannual" then
			--- `February 14, 2024` --> `"2024_1"`
			--- Jan-Jun: `1` (SS)
			--- Jul-Dec: `2` (FW)
			nextdatetable.month = -(nextdatetable.month // -6)
			nextdatetable.day = 1
			nextdatetable.hour = 0
			nextdatetable.min = 0
			nextdatetable.sec = 0

			local year, month = datetable.year, -(datetable.month // -6)
			timestamp.id = string.format("%d_%d", year, month)
			timestamp.seed = tonumber(year .. month) :: number
		elseif format == "year" then
			--- `February 14, 2024` --> `"2024"`
			nextdatetable.year += 1
			nextdatetable.month = 1
			nextdatetable.day = 1
			nextdatetable.hour = 0
			nextdatetable.min = 0
			nextdatetable.sec = 0

			timestamp.id = tostring(datetable.year)
			timestamp.seed = tonumber(datetable.year) :: number
		end
	end

	timestamp.change = os.time(nextdatetable::any) - os.time(datetable::any)

	return timestamp
end

if isserver then
	do --- flush queue
		local function flush(queue: {any})
			local entry = table.remove(queue, 1)
			if entry then
				local scoped = entry[1]
				local instances = entry[2]
				local client = entry[3]
				local force = entry[4]

				local remote
				if force == "reliable" then
					remote = RemoteEvent
				elseif force == "unreliable" then
					remote = UnreliableRemoteEvent
				else
					remote = resolveremote(scoped, instances)	
				end
				
				if type(client) == "nil" then --- fire all
					(remote::any):FireAllClients(scoped, instances)
				elseif type(client) == "number" then --- fire by userid
					local player = Players:GetPlayerByUserId(client)
					if player then
						(remote::any):FireClient(player, scoped, instances)
					end
				elseif typeof(client) == "Instance" then --- fire by player
					assert(client:IsA("Player"), string.format("expected instance player, got %s %s", client.ClassName, client.Name))

					;(remote::any):FireClient(client, scoped, instances)
				elseif type(client) == "table" then --- fire by list of userids or players
					for _, a in client do
						if typeof(a) == "Instance" then
							(remote::any):FireClient(a, scoped, instances)
						elseif typeof(a) == "number" then
							local player = Players:GetPlayerByUserId(a)
							if player then
								(remote::any):FireClient(player, scoped, instances)
							end
						else
							warn("value dropped for client", typeof(a), a, "expected instance player or number userid")
						end
					end
				elseif type(client) == "function" then --- fire by case
					for _, a in Players:GetPlayers() do
						if client(a) == true then
							(remote::any):FireClient(a, scoped, instances)
						end
					end
				else
					warn(string.format("(value dropped) error solving client: type(%s) typeof(%s)", type(client), typeof(client)), client, client)
				end

				flush(queue)
			else
				return
			end
		end

		local recent = os.clock() - net.framerate
		RunService.Heartbeat:Connect(function()
			local now = os.clock()
			local dt = now - recent
			if dt > net.framerate then
				recent = now - (dt - net.framerate)

				flush(net.queue)
			end
		end)
	end

	do --- unix timestamp
		local unixbuffer = net.unixbuffer
		buffer.writef64(unixbuffer, 0, DateTime.now().UnixTimestampMillis)

		local function unixtimestamp()
			buffer.writef64(unixbuffer, 0, DateTime.now().UnixTimestampMillis)
			UnixTimestampRemote:FireAllClients(unixbuffer)
		end

		local recent = os.clock() - net.framerate
		RunService.Heartbeat:Connect(function()
			local now = os.clock()
			local dt = now - recent
			if dt > net.framerate then
				recent = now - (dt - net.framerate)

				unixtimestamp()
			end
		end)
	end

	do --- cleanup port serverrecvlimits
		Players.PlayerRemoving:Connect(function(player: Player)
			--[[for _, p in net.ports do
				p.players[player] = nil
			end]]
		end)
	end
else
	do --- flush queue
		local function flush(queue: {any})
			local entry = table.remove(net.queue, 1)
			if entry then
				local scoped = entry[1]
				local instances = entry[2]
				local force = entry[4]

				local remote
				if force == "reliable" then
					remote = RemoteEvent
				elseif force == "unreliable" then
					remote = UnreliableRemoteEvent
				else
					remote = resolveremote(scoped, instances)	
				end

				(remote::any):FireServer(scoped, instances)

				flush(queue)
			else
				return
			end
		end

		local recent = os.clock() - net.framerate
		RunService.Heartbeat:Connect(function()
			local now = os.clock()
			local dt = now - recent
			if dt > net.framerate then
				recent = now - (dt - net.framerate)

				flush(net.queue)
			end
		end)
	end

	do --- ships
		script.AttributeChanged:Connect(function(key: string)
			local i = script:GetAttribute(key)
			assert(type(i) == "number")
			net.ships[i] = key
		end)
		for key, i in script:GetAttributes() do
			assert(type(i) == "number")
			net.ships[i] = key
		end
	end

	do --- unix timestamp
		local unixbuffer = net.unixbuffer
		UnixTimestampRemote.OnClientEvent:Connect(function(u: buffer)
			buffer.copy(unixbuffer, 0, u)
		end)
	end
end

return net