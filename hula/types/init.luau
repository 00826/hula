--!strict
--!native

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Rand = Random.new()

--- returns `a == b`
local function compare(a: buffer, b: buffer, offset: number?)
	local alen = buffer.len(a)
	local blen = buffer.len(b)

	offset = offset or 0
	assert(offset) --- solver kick rocks

	if alen ~= blen then
		return false
	elseif offset >= alen then
		return true
	else
		local traverse = alen - offset
		if traverse >= 4 then
			if buffer.readu32(a, offset) == buffer.readu32(b, offset) then
				return compare(a, b, offset + 4)
			else
				return false
			end
		elseif traverse >= 2 then
			if buffer.readu16(a, offset) == buffer.readu16(b, offset) then
				return compare(a, b, offset + 2)
			else
				return false
			end
		else
			if buffer.readu8(a, offset) == buffer.readu8(b, offset) then
				return compare(a, b, offset + 1)
			else
				return false
			end
		end
	end
end

--- ### types.luau
---
--- general type functions
local types = {
	abbreviations = {"", "K", "M", "B", "T", "Qd", "Qt", "Sx", "Sp", "Oc", "No", "De"};
}

--- creates a wheel \
--- vectors should be along the x/z plane
function types.createwheel(len: number, initialangle: number?)
	local c = {
		pointer = vector.create(0, 0, 0);
		vectors = table.create(len);
	}

	local step = (2 * math.pi) / len

	for i = 0, len - 1, 1 do
		local theta = (i * step) + (initialangle or 0)
		
		table.insert(c.vectors, vector.create(math.cos(theta), 0, math.sin(theta)))
	end

	return c
end

--- returns index of wheel wrt pointer
function types.wheelresolve(c: typeof(types.createwheel(...)))
	local step = (2 * math.pi) / #c.vectors
	local halfstep = 0.5 * step

	for i, vec in ipairs(c.vectors) do
		local angle = vector.angle(vec, c.pointer)

		if angle > -halfstep and angle < halfstep then
			return i
		end
	end

	return 0
end

--- returns `bit32.replace(0, 1, 0)` intended for todo32 library \
--- multi-step, multi-requisite tasks in 32 bits: \
--- `000000` `[0, 5]` todo step \
--- `00 00000000 00000000 00000000` `[6, 31]` todo progress
function types.createtodo32()
	return bit32.replace(0, 1, 0)
end

--- adds signal progress to todo32 integer with respect to todo map \
--- returns: \
--- `t`: todo32 integer, mutated \
--- `todostep`: todo step against `#map`, where `todostep >= #map` indicates todo completion
function types.todo32add(t: number, signal: { key: string, value: number }, map: { { { key: number, value: {string} } } })
	local todostep = bit32.extract(t, 0, 6)
	todostep = map[todostep] and todostep or 1

	local step = map[todostep] or map[1]
	assert(step, "todo32: cannot progress an empty map")

	local maxstep = #map

	if todostep > maxstep then
		t = bit32.replace(t, maxstep, 0, 6)
		t = bit32.replace(t, 0, 6, 26)

		return t, todostep
	else
		local sum = 0
		local goal = 0

		local offset = 6
		for _, requisite in ipairs(step) do
			local key, value = requisite.key, requisite.value
			local width = types.numbits(key)
			local requisiteprogress = bit32.extract(t, offset, width)
			if table.find(value, signal.key) then
				requisiteprogress = math.clamp(requisiteprogress + signal.value, 0, 2^width - 1)
			end
			t = bit32.replace(t, requisiteprogress, offset, width)

			sum += requisiteprogress
			goal += key
			offset += width
		end

		if sum >= goal then
			todostep += 1

			t = bit32.replace(t, todostep, 0, 6)
			t = bit32.replace(t, 0, 6, 26)
		end

		return t, todostep
	end
end

--- returns todo32 step \
--- equivalent to `bit32.extract(t, 0, 6)`
function types.todo32step(t: number)
	return bit32.extract(t, 0, 6)
end

--- returns todo completion details: \
--- `todostep`: todo step against `#map` \
--- `receipt`: `{ {number requisiteprogress, string requisitekey} }` \
--- \
--- if `bit32.extract(t, 0, 6)` is not an index of `map`, the todo is considered complete: \
--- ... `todostep` will be returned as `#map + 1` for external `if todostep > #map then ... end` case \
--- ... `receipt` will be returned as `table.create(0)`
function types.todo32receipt(t: number, map: { { { key: number, value: {string} } } })
	local todostep = bit32.extract(t, 0, 6)

	local step = map[todostep]
	if not step then
		return #map + 1, table.create(0)
	end

	local maxstep = #map

	if todostep > maxstep then
		return todostep, table.create(0)
	else
		local receipt = table.create(maxstep)

		local offset = 6
		for _, requisite in ipairs(step) do
			local key = requisite.key
			local width = types.numbits(key)
			local requisiteprogress = bit32.extract(t, offset, width)
			table.insert(receipt, {requisiteprogress, key})

			offset += width
		end

		return todostep, receipt
	end
end

--- applies xp `value` to level-xp unsigned integer `p32`
--- ```
---         level                 xp
--- bits  [0000 0000] [00000000 00000000 00000000]
--- range [31 .. 24]           [23 .. 0]
--- limit  [0, 255]          [0, 16777215]
--- ```
--- returns: \
--- `unsigned long p32`: modified `p32` \
--- `number ups`: integer describing # of level-ups
function types.prog32(p32: number, value: number, required: (number) -> number, max: number?)
	assert(value <= 2^24-1, "value exceeds 24-bit integer limit (16777215)")

	local level = bit32.extract(p32, 24, 8)
	local xp = bit32.extract(p32, 0, 24)
	local ups = 0

	if level >= (max or 2^8-1) then
		p32 = bit32.replace(p32, 0, 0, 24)

		return p32, ups
	else
		local reqxp = required(level)
		local newxp = xp + value

		if newxp >= reqxp then
			p32 = bit32.replace(p32, level + 1, 24, 8)
			p32 = bit32.replace(p32, newxp - reqxp, 0, 24)
			ups += 1

			return p32, ups + types.prog32(p32, 0, required, max)
		else
			p32 = bit32.replace(p32, level, 24, 8)
			p32 = bit32.replace(p32, newxp, 0, 24)

			return p32, ups
		end
	end
end

--- returns `xp` (unsigned sword) stored in level-xp unsigned integer \
--- equivalent to `bit32.extract(p32, 0, 24)`
function types.prog32xp(p32: number)
	return bit32.extract(p32, 0, 24)
end

--- returns `level` (unsigned char) stored in level-xp unsigned integer \
--- equivalent to `bit32.extract(p32, 24, 8)`
function types.prog32level(p32: number)
	return bit32.extract(p32, 24, 8)
end

--- returns # of bytes required to store given value \
--- equivalent to `1 + (math.log(value, 2) // 8)`
function types.numbytes(value: number)
	return 1 + (math.log(value, 2) // 8)
end

--- returns # of bits required to store given value \
--- equivalent to `1 + math.log(value, 2) // 1`
function types.numbits(value: number)
	return 1 + math.log(value, 2) // 1
end

--- returns `byteoffset * 8`
function types.bitoffset(byteoffset: number)
	return byteoffset * 8 --- yes i unironically need this kthxbai!!
end

--- returns range of bits as a string
function types.stringbits(x: number, field: number, range: number)
	local bitstring = ""
	for i = 1, range do
		bitstring ..= tostring(bit32.extract(x, field + i))
	end

	return bitstring
end

--- returns a deep copy of table
function types.deepcopy(t: {[any]: any}): {[any]: any}
	local copy = {}

	for k, v in t do
		if type(v) == "table" then
			copy[k] = types.deepcopy(v)
		elseif type(v) == "buffer" then
			local b = buffer.create(buffer.len(v))
			buffer.copy(b, 0, v, 0)
			copy[k] = b::any
		else
			copy[k] = v
		end
	end

	return copy
end

--- returns a diff-table describing changes made from `old -> new` \
--- \
--- `[!]` nil-values are of type `string` and equate to `"nil"`
function types.diff(new: {[string]: any}, old: {[string]: any})
	local result: { [any]: any } = {}

	for key, newvalue in new do
		local oldvalue = old[key]

		local newtype = type(newvalue)
		local oldtype = type(oldvalue)

		if newtype == oldtype then
			if newtype == "table" then
				if next(newvalue) == nil then --- empty
					if next(oldvalue) ~= nil then
						result[key] = {}
					end
				else
					local diff = types.diff(newvalue, oldvalue)
					if next(diff) ~= nil then
						result[key] = {}
						for a, b in diff do
							result[key][a] = b
						end
					end
				end
			elseif newtype == "buffer" then
				if not compare(newvalue, oldvalue) then
					local dupe = buffer.create(buffer.len(newvalue))
					buffer.copy(dupe, 0, newvalue)

					result[key] = dupe
				end
			else
				if newvalue ~= oldvalue then
					result[key] = newvalue
				end
			end
		else
			if newvalue ~= oldvalue then
				if newtype == "table" then
					result[key] = types.deepcopy(newvalue)
				elseif newtype == "buffer" then
					local dupe = buffer.create(buffer.len(newvalue))
					buffer.copy(dupe, 0, newvalue)

					result[key] = dupe
				else
					result[key] = newvalue
				end
			end
		end
	end

	for key in old do
		if new[key] == nil then
			result[key] = "nil"
		end
	end

	return result
end

--- reconciles result of `types.diff(...)` into `t` \
--- attempts to convert string-keys of `t` into numeric indices \
--- to account for array diffs being converted from `{any} -> {[string]: any}` when passed over the network
function types.reconcile(t: {}, diff: typeof(types.diff(...)))
	if #diff > 0 then
		for i, v in ipairs(diff) do
			if type(v) == "table" then
				if not t[i] then
					t[i] = {}
				end
				if next(v) == nil then
					types.rbxtypeclear(t[i])
				end

				types.reconcile(t[i], v)
			elseif type(v) == "buffer" then
				local preexisting = t[i]
				local len = buffer.len(v)
				if type(preexisting) == "buffer" and buffer.len(preexisting) == len then
					buffer.copy(preexisting, 0, v, 0)
				else
					local b = buffer.create(len)
					buffer.copy(b, 0, v, 0)
					t[i] = b::any
				end
			elseif v == "nil" then
				if type(t[i]) == "table" then
					types.rbxtypeclear(t[i])
				end
				t[i] = nil
			else
				t[i] = v
			end
		end
	else
		for k, v in diff do
			--- assuming unordered a[2 = "a", 3 = "b"] will not lose order when iterated through
			--- local i = tonumber(k)
			--- if i ~= nil then
			--- 	k = i
			--- end

			if type(v) == "table" then
				if not t[k] then
					t[k] = {}
				end
				if next(v) == nil then
					types.rbxtypeclear(t[k])
				end

				types.reconcile(t[k], v)
			elseif type(v) == "buffer" then
				local preexisting = t[k]
				local len = buffer.len(v)
				if type(preexisting) == "buffer" and buffer.len(preexisting) == len then
					buffer.copy(preexisting, 0, v, 0)
				else
					local b = buffer.create(len)
					buffer.copy(b, 0, v, 0)
					t[k] = b::any
				end
			elseif v == "nil" then
				if type(t[k]) == "table" then
					types.rbxtypeclear(t[k])
				end
				t[k] = nil
			else
				t[k] = v
			end
		end
	end
end

--- returns an item (`{id, ...}`)
function types.createitem(id: string, ...: any)
	return {id, ...}::{string|any}
end

--- inserts item, by its associated `id`, to list \
--- *does not account for duplicates*
function types.iteminsert(list: { typeof(types.createitem(...)) }, id: string, ...: any)
	table.insert(list, types.createitem(id, ...))
end

--- removes all items associated with `id`, from list \
--- *starts at `i = #list`, ends at `i = 1`, accounting for duplicates*
function types.itemremove(list: { typeof(types.createitem(...)) }, id: string)
	for i = #list, 1, -1 do
		if list[i][1] == id then
			table.remove(list, i)
		end
	end
end

--- returns item, from its associated `id`, stored in list
function types.itemfind(list: { typeof(types.createitem(...)) }, id: string): typeof(types.createitem(...))?
	for _, thing in list do
		if thing[1] == id then
			return thing
		end
	end

	return nil
end

--- returns first key-value pair from nested table `t` that satisfies `t[k][scope] == value`
function types.scope<T>(t: {[string]: any}, scope: string, value: any): (any?, {[string]: any}?)
	for k, v in t do
		if v[scope] == value then
			return k, v
		end
	end

	return nil, nil
end

--- rotates array `A` `x` times such that:
--- ```
--- rotate([1, 2, 3, 4, 5], 1) -> [5, 1, 2, 3, 4]
--- rotate([1, 2, 3, 4, 5], -1) -> [2, 3, 4, 5, 1]
--- ```
function types.rotate(t: {any}, x: number?)
	x = x or 1
	assert(x)

	if x ~= 0 then
		if x > 0 then
			local value = table.remove(t)
			table.insert(t, 1, value)
		elseif x < 0 then
			local value = table.remove(t, 1)
			table.insert(t, value)
		end

		types.rotate(t, x - math.sign(x))
	else
		return
	end
end

--- returns elements of array as a page
--- ```
--- t = {} --- [1, ..., 25]
--- page(t, 10, 1) --- [1, ..., 10]
--- page(t, 10, 2) --- [11, ..., 20]
--- page(t, 10, 3) --- [21, ..., 25]
--- page(t, 10, 4) --- []
--- ```
function types.page<T>(t: {T}, size: number, offset: number)
	local len = #t

	return table.move(
		t,
		1 + math.clamp((offset - 1) * size, 0, len),
		math.clamp(offset * size, 0, len),
		1,
		table.create(size)
	)
end

--- creates a book, used for neatly getting chunks (pages) of an array \
--- `size`: book page size \
--- `alloc (?=size)`: `b.Items = table.create(alloc)`
function types.createbook(size: number, alloc: number?)
	return {
		offset = 1;
		size = size;
		items = table.create(alloc or size);
	}
end

--- advances book by `delta` (can be positive, negative, or zero!), returning: \
--- `page`: page of `pc.items` with respect to `pc.offset` and `pc.size` \
--- `oldoffset`: previous `pc.offset` \
--- `newoffset`: current `pc.offset` \
--- `numpages`: max # of pages that can be displayed
function types.booknext(b: typeof(types.createbook(...)), delta: number)
	local len = #b.items
	local size = b.size

	local numpages = math.clamp(-(len // -size), 1, math.huge)

	local oldoffset = b.offset
	local newoffset = math.clamp(b.offset + delta, 1, numpages)

	b.offset = newoffset

	return table.move(
		b.items,
		1 + math.clamp((newoffset - 1) * size, 0, len),
		math.clamp(newoffset * size, 0, len),
		1,
		table.create(size)
	), oldoffset, newoffset, numpages
end

--- `T[random alphanumeric key (len ?=4)] = value` \
--- returns `random alphanumeric key` for convenience \
--- guarantees that `tonumber(key) == nil` to avoid errors when sending such a key over the network boundary
function types.insertkey(t: {[string]: any}, value: any, len: number?)
	len = len or 4
	assert(len)

	local key = nil

	repeat key = types.createstring(len)
	until (key ~= nil) and (tonumber(key) == nil) and (t[key] == nil)

	t[key] = value

	return key
end

--- returns a reverse iterator function and the table for use in a for loop
function types.ipairsr<T>(t: {T}): (({T}, number) -> (number?, T), {T}, number)
	return coroutine.wrap(function()
		for i = #t, 1, -1 do
			coroutine.yield(i, t[i])
		end
	end), t, 0
end

--- returns random value from list
function types.nextvaluefromlist<T>(t: {T}, R: Random?): T?
	if #t < 0 then
		return nil
	else
		return t[(R or Rand):NextInteger(1, #t)]
	end
end

--- returns random value from weighted table
function types.nextvaluefromweightedtable<T>(t: { { key: string, weight: number } & T }, R: Random?): T?
	if #t < 0 then
		return nil
	else
		local sum = 0
		for _, entry in ipairs(t) do
			sum += entry.weight
		end

		local roll, passed = (R or Rand):NextNumber(0, sum), 0
		for _, entry in ipairs(t) do
			passed += entry.weight

			if roll <= passed then
				return entry
			end
		end

		return nil
	end
end

--- returns `t[1] ∪ ... ∪ t[#t]`
function types.union<T>(t: { {T} })
	local result = {}
	for _, list in ipairs(t) do
		table.move(list, 1, #list, #result + 1, result)
	end

	return result
end

--- returns `b ¬ a` such that
--- ```lua
--- c{(a, 1), (b, 1)} = b{(a, 2), (b, 1), (c, 1)} ¬ a{(a, 1), (c, 1)}
--- --- or
--- c{a, b} = b{a, a, b, c} ¬ a{a, c}
--- ``` 
function types.negate<T>(a: {T}, b: {T})
	local block = table.clone(b)
 
	for _, value in ipairs(a) do
		table.remove(block, table.find(block, value) or 0)
	end

	return block
end

--- shorthand for `t[a] = (t[a] or 0) + b`
function types.incr<T>(t: {[T]: number}, a: T, b: number)
	--- ta
	t[a] = (t[a] or 0) + b
end

--- returns array of all keys in `t`
function types.keys<T>(t: {[T]: any})
	local result = {}
	for k in t do
		table.insert(result, k)
	end

	return result
end

--- recursive, roblox-type-friendly table.clear(); handles destruction of: \
--- `typeof(t[k]) == "Instance" -> Destroy()` \
--- `typeof(t[k]) == "RBXScriptConnection" -> Disconnect()` \
--- `typeof(t[k]) == "thread" -> task.cancel(v)`
function types.rbxtypeclear(a: any)
	if type(a) == "table" then
		for _, b in a do
			types.rbxtypeclear(b)
		end
		table.clear(a)

	elseif typeof(a) == "Instance" then
		a:Destroy()

	elseif typeof(a) == "RBXScriptConnection" then
		a:Disconnect()

	elseif typeof(a) == "thread" then
		task.cancel(a)

	end
end

--- returns a randomized alphanumeric string \
--- all characters elements of set `[A-Za-z0-9]`
function types.createstring(len: number)
	local b = buffer.create(len)
	for i = 0, len - 1, 1 do
		local value = Rand:NextInteger(1, 62)
		if value <= 26 then --- [a-z] [abcdefghijklmnopqrstuvwxyz] [1-26] -> [97-122] 
			buffer.writeu8(b, i, value + 96)
		elseif value <= 52 then --- [A-Z] [ABCDEFGHIJKLMNOPQRSTUVWXYZ] [27-52] -> [65-90] 
			buffer.writeu8(b, i, value + 38)
		else --- elseif value <= 62 then --- [0-9] [0123456789] [53-62] -> [48-57]
			buffer.writeu8(b, i, value - 5)
		end
	end

	return buffer.tostring(b)
end

local function subf(x: string)
	return string.len(x) == 1 and "0" .. x or x
end

--- formats time into a hour-minute-second-esque notation
function types.hourminutesecond(time: number, notation: "DD:HH:MM:SS" | "DDdHHhMMmSSs" | "HH:MM:SS" | "MM:SS" | "M:SS", appendms: boolean?): string
	--[[
		os.date("!%X", time) is the fastest for all inputs below 86400, because any input at or above 86400 breaks the formatting
		string.gsub(string.format(), time, subf) is the second fastest for all inputs, never has a formatting break, but is ~10% slower than os.date("!%X", time)
		combining both through comparing time >= 86400 gives a faster average across all possible inputs
	]]
	local hms = ""
	if notation == "DD:HH:MM:SS" then
		if time >= 86400 then
			local days = time // 86400
			time -= days * 86400
			local hours = time // 3600
			time -= hours * 3600
			local minutes = time // 60
			time -= minutes * 60

			hms = string.gsub(string.format("%d:%d:%d:%d", days, hours, minutes, time), "%d+", subf)
		else
			hms = "00:" .. os.date("!%X", time)
		end
	elseif notation == "DDdHHhMMmSSs" then
		local days = time // 86400
		time -= days * 86400
		local hours = time // 3600
		time -= hours * 3600
		local minutes = time // 60
		time -= minutes * 60

		hms = string.gsub(string.format("%dd%dh%dm%ds", days, hours, minutes, time), "%d+", subf)
	elseif notation == "HH:MM:SS" then
		if time >= 86400 then
			local hours = time // 3600
			time -= hours * 3600
			local minutes = time // 60
			time -= minutes * 60

			hms = string.gsub(string.format("%d:%d:%d", hours, minutes, time), "%d+", subf)
		else
			hms = os.date("!%X", time)
		end
	elseif notation == "MM:SS" then
		if time >= 3600 then
			local minutes = time // 60
			time -= minutes * 60
			hms = string.gsub(string.format("%d:%d", minutes, time), "%d+", subf)
		else
			hms = string.sub(os.date("!%X", time), 4, 8)
		end
	elseif notation == "M:SS" then
		if time >= 3600 then
			local minutes = time // 60
			time -= minutes * 60
			hms = string.gsub(string.format("%d:%d", minutes, time), "%d+", subf)
		else
			hms = string.gsub(string.sub(os.date("!%X", time), 4, 8), "^0", "")
		end
	end

	if appendms then
		local stringtime = tostring(time)

		local init = string.find(stringtime, "%.")
		if init then
			local append = string.sub(stringtime, init, init + 3)

			for i = 2, 4, 1 do
				local substring = string.sub(append, i, i)
				if substring == "" then
					append ..= "0"
				end
			end

			hms ..= append
		else
			hms ..= ".000"
		end
	end

	return hms
end

local function monthtoseason(m: number)
	--- m -= 3 --- shift by 3 months
	--- m %= 12 --- rotate around 12 months
	--- m //= 3 --- 12/3 = 4 seasons
	--- m += 1 --- non-zero
	if m > 12 then
		m %= 12
	end

	return 1 + (((m - 3) % 12) // 3)
end

--- returns a timestamp of current utc time with respect to format option or time in minutes
function types.timestamp(format: "hour" | "halfday" | "day" | "week" | "month" | "season" | "biannual" | "year" | number)
	local datetable = os.date("!*t") --- read from this table as a truth state
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
			--- Mar-May: `1` (spring)
			--- Jun-Aug: `2` (summer)
			--- Sep-Nov: `3` (fall)
			--- Dec-Feb: `4` (winter)

			local month = datetable.month
			local thisseason = monthtoseason(month)
			local nextseason = thisseason

			--- rotate around 4 seasons
			if nextseason >= 4 then
				nextseason %= 4
			end
			nextseason += 1

			local nextseasonmonth = monthtoseason(nextseason)
			
			nextdatetable.month = nextseasonmonth

			if nextdatetable.month < nextseasonmonth then
				--- modulo into next year
				nextdatetable.year += 1
			end

			nextdatetable.day = 1
			nextdatetable.hour = 0
			nextdatetable.min = 0
			nextdatetable.sec = 0

			local year = datetable.year
			timestamp.id = string.format("%d_%d", year, thisseason)
			timestamp.seed = tonumber(year .. thisseason) :: number
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

	timestamp.change = os.time(nextdatetable) - os.time(datetable)

	return timestamp
end

--- returns `string.format("%d%s", x, s)` with ordinal suffix `s` (`st, nd, rd, th`)
function types.ordinalnumber(x: number)
	local a = x % 10
	local b = x % 100

	local suffix = "th"

	if a == 1 and b ~= 11 then
		suffix = "st"
	elseif a == 2 and b ~= 12 then
		suffix = "nd"
	elseif a == 3 and b ~= 13 then
		suffix = "rd"
	end
	
	return string.format("%d%s", x, suffix)
end

--- returns: \
--- `x > 0`: `"+x"` \
--- `x == 0`: `"x"` \
--- `x < 0`: `"-x"`
function types.deltanumber(x: number)
	return x > 0 and "+" .. tostring(x) or tostring(x)
end

--- formats number, thousands separated by `tsep (?=",")`
function types.commanumber(x: number, tsep: string?)
	if math.abs(x) < 1000 then
		return tostring(math.floor(x))
	else
		local str = string.reverse(string.gsub(string.reverse(tostring(math.floor(x))), "(%d%d%d)", "%1" .. (tsep or ","))::any)

		return string.sub(str, string.find(str, "%d")::any, -1)
	end
end

--- abbreviates number, decimals separated by `dsep (?=".")`, truncated by `places (?=1)`
function types.abbreviatenumber(x: number, places: number?, dsep: string?)
	local exp = math.floor(math.log(math.max(1, math.abs(x)), 1000))
	local suffix = types.abbreviations[1 + exp] or ("e+" .. exp)

	return string.gsub(tostring(math.floor(x * ((10 ^ (places or 1)) / (1000 ^ exp))) / (10 ^ (places or 1))), "[.]", dsep or ".") .. suffix
end

--- returns `HttpService:JSONEncode(input)`
function types.jsonencode(input: any)
	return HttpService:JSONEncode(input)
end

--- returns `HttpService:JSONDecode(input)`
function types.jsondecode(input: string)
	return HttpService:JSONDecode(input)
end

--- runs function at second interval `x` for `time` seconds \
--- exceptions: \
--- `x == -1`: function is called every heartbeat \
--- `time == -1`: framerule runs indefinitely
function types.framerule(x: number, time: number, f: (dt: number, elapsed: number) -> (), immediate: boolean?): (RBXScriptConnection, thread?)
	if time == -1 then
		local start = os.clock()
		local recent = os.clock()
		if immediate ~= false then
			recent -= x or 1/60 --- doesn't matter
		end

		if x == -1 then
			return RunService.Heartbeat:Connect(function(dt)
				local now = os.clock()
				f(dt, now - start)
			end)
		else
			return RunService.Heartbeat:Connect(function()
				local now = os.clock()
				local dt = now - recent
				if dt > x then
					recent = now - (dt - x)

					f(dt, now - start)
				end
			end)
		end
	else
		local connection = types.framerule(x, -1, f, immediate)

		return connection, task.delay(time, connection.Disconnect, connection)
	end
end

return types