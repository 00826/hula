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
	--- number abbreviations
	abbreviations = {"", "K", "M", "B", "T", "Qd", "Qt", "Sx", "Sp", "Oc", "No", "De"};
	--- shorthand 1-byte instructions used by `types.difference()` and `types.reconcile()`
	instructions = {
		"\u{0000}";
		"\u{0001}";
		"\u{0002}";
	};
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
--- key   xp                           level
--- bits  [00000000 00000000 00000000] [00000000]
--- range [0 .. 23]                    [24 .. 31]
--- value [0, 16777215]                [0, 255]
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

	local iter: any = pairs
	if #t > 0 then
		iter = ipairs
	end

	for k, v in iter(t) do
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

--- returns \
--- `string indexer type` of `a` \
--- `string indexer type` of `b` \
--- `boolean canreconcile` if reconciling `a` and `b` will result in a mixed table
function types.canreconcile(a: {[any]: any}, b: {[any]: any})
	local akeytype = type(next(a)::any)
	local bkeytype = type(next(b)::any)
	if bkeytype ~= "nil" and akeytype ~= "nil" then
		if (bkeytype == "number" or akeytype == "number")
		and (bkeytype ~= akeytype)
		then
			return akeytype, bkeytype, false
		end
	end

	return akeytype, bkeytype, true
end

--- returns `c = b ∖ a` \
--- \
--- `[!]` because the raw diff between two arrays *cannot* be reconciled normally, certain strings are used as shorthand instructions to be read by `types.reconcile()`: \
--- `"\u{0000}"` represents `nil` \
--- `"\u{0001}"` represents `b ∖ a` where `b = ø` and `a = ø` (no change) \
--- `"\u{0002}"` represents `b ∖ a` where `b ≠ ø` and `a = ø` (`table.clear()`)
function types.difference(a: any, b: any): any
	local atype = type(a)
	local btype = type(b)

	if btype == atype then
		if btype == "table" then
			local akeytype, bkeytype, canreconcile = types.canreconcile(a, b)
			if not canreconcile then
				error(string.format(
					"cannot resolve difference for non-reconcilable tables: {[%s]: ...} -> {[%s]: ...}",
					akeytype,
					bkeytype
				))
			end

			if bkeytype == "nil" and akeytype == "nil" then
				return "\u{0001}"
			elseif bkeytype == "nil" and akeytype ~= "nil" then
				return "\u{0002}"
			else
				local result = {}

				if #b > 0 or #a > 0 then
					--- read array diff
					local alen = #a
					for j, range in ipairs({
						{alen, 1, -1}; --- iter backwards from oldvalue len to 1
						{alen + 1, #b, 1}; --- iter forwards if newvalue is longer than oldvalue
					}) do
						for i = range[1], range[2], range[3] do
							local c = types.difference(a[i], b[i])
							result[i] = c
						end
					end
				else
					--- read dictionary diff
					for bkey, bvalue in b do
						local c = types.difference(a[bkey], bvalue)
						result[bkey] = c
					end
					for akey in a do
						if b[akey] == nil then
							result[akey] = "\u{0000}"
						end
					end
				end

				--- check if result can be collapsed into a byte instruction
				local len = 0
				local preconcat = {}
				for _, v in result do
					len += 1
					if table.find(types.instructions, v) then
						table.insert(preconcat, v)
					end
				end
				local concat = table.concat(preconcat)
				for _, char in ipairs(types.instructions) do
					if concat == string.rep(char, len) then
						return char
					end
				end

				return result
			end
		elseif btype == "buffer" then
			if compare(b, a) == true then
				return "\u{0001}"
			else
				local copy = buffer.create(buffer.len(b))
				buffer.copy(copy, 0, b)

				return copy
			end
		elseif btype == "nil" then
			return "\u{0000}"
		else
			if b == a then
				return "\u{0001}"
			else
				return b
			end
		end
	else
		if btype == "table" then
			return types.deepcopy(b)
		elseif btype == "buffer" then
			local copy = buffer.create(buffer.len(b))
			buffer.copy(copy, 0, b)
			
			return copy
		elseif btype == "nil" then
			return "\u{0000}"
		else
			return b
		end
	end
end

--- collapses difference table such that key-value pairs with non-numeric indexers with a "no-change" (`\u{0001}`) control character value are set to nil
function types.collapse(difference: {[any]: any})
	for k, v in difference do
		if type(v) == "table" then
			types.collapse(v)
		else
			if type(k) ~= "number" and v == "\u{0001}" then
				difference[k] = nil
			end
		end
	end
end

--- where `c = a ∖ b`, applies union operation `b ∪ c`, such that `a ∖ b == ø` \
--- returns: \
--- `any b` reconciled \
--- `number count` # of differences reconciled
function types.reconcile(b: any, c: any): (any, number)
	local btype = type(b)
	local ctype = type(c)

	--- byte instructions
	if c == "\u{0000}" then
		return nil, b ~= nil and 1 or 0
	elseif c == "\u{0001}" then
		return b, 0
	elseif c == "\u{0002}" then
		if btype == "table" then
			if next(b) ~= nil then
				table.clear(b)
				
				return b, 1
			else
				return b, 0 --- is already empty
			end
		end

		return b, 0 --- ? shouldn't arrive at this case
	end

	if ctype == btype then
		if ctype == "table" then
			local bkeytype, ckeytype, canreconcile = types.canreconcile(b, c)
			if not canreconcile then
				error(string.format(
					"cannot apply reconcile to non-reconcilable tables: {[%s]: ...} <- {[%s]: ...}",
					bkeytype,
					ckeytype
				))
			end

			local count = 0

			if #c > 0 or #b > 0 then
				--- reconcile array
				local blen = #b
				for j, range in ipairs({
					{blen, 1, -1}; --- iter backwards from oldvalue len to 1
					{blen + 1, #c, 1}; --- iter forwards if newvalue is longer than oldvalue
				}) do
					for i = range[1], range[2], range[3] do
						local reentryvalue, reentrycount = types.reconcile(b[i], c[i])
						b[i] = reentryvalue
						count += reentrycount
					end
				end
			else
				--- reconcile dictionary
				for ckey, cvalue in c do
					local reentryvalue, reentrycount = types.reconcile(b[ckey], cvalue)
					b[ckey] = reentryvalue
					count += reentrycount
				end
				for bkey in b do
					if c[bkey] == "\u{0000}" then
						b[bkey] = nil
					end
				end
			end
			
			return b, count
		elseif ctype == "buffer" then
			if compare(b, c) == true then
				return b, 0
			else
				if buffer.len(b) == buffer.len(c) then
					buffer.copy(b, 0, c)
					return b, 1
				else
					return c, 1
				end
			end
			
		elseif ctype == "nil" then
			return nil, 0
		else
			return c, b ~= c and 1 or 0
		end
	else
		if ctype == "table" then
			return c, 1
		elseif ctype == "buffer" then
			local copy = buffer.create(buffer.len(c))
			buffer.copy(copy, 0, c)
			
			return copy, 1
		elseif ctype == "nil" then
			return nil, 1
		else
			return c, 1
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

--- creates a timestamp string from: \
--- `selector` string composed of any combination of: (separated by spaces) \
--- `"dd"`: days \
--- `"hh"`: hours \
--- `"mm"`: minutes \
--- `"ss"`: seconds \
--- `"ms"`: milliseconds
--- 
--- `separator` string: \
--- `"punc"` -> `00:00:00:00.000` \
--- `"abbr"` -> `00d00h00m00s000ms` \
--- `"word"` -> `00 days 00 hours 00 minutes 00 seconds 000 milliseconds` \
--- 
--- ```lua
--- types.timestring(3.141, "ss ms", "punc", 1) --- 3s141ms
--- ```
function types.timestring(x: number, selector: string, separator: "punc" | "abbr" | "word", zeropadding: number)
	local ts = ""

	if string.find(selector, "dd") then
		local y = 0
		if x >= 86400 then
			y = x // 86400
			x -= y * 86400
		end

		if separator == "punc" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d:", y)
		elseif separator == "abbr" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "dd", y)
		elseif separator == "word" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d days ", y)
		end
	end
	if string.find(selector, "hh") then
		local y = 0
		if x >= 3600 then
			y = x // 3600
			x -= y * 3600
		end

		if separator == "punc" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d:", y)
		elseif separator == "abbr" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "dh", y)
		elseif separator == "word" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d hours ", y)
		end
	end
	if string.find(selector, "mm") then
		local y = 0
		if x >= 60 then
			y = x // 60
			x -= y * 60
		end

		if separator == "punc" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d:", y)
		elseif separator == "abbr" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "dm", y)
		elseif separator == "word" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d minutes ", y)
		end
	end
	if string.find(selector, "ss") then
		local y = 0
		if x >= 1 then
			y = x // 1
			x -= y * 1
		end
		
		if separator == "punc" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d", y)
		elseif separator == "abbr" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "ds", y)
		elseif separator == "word" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d seconds ", y)
		end
	end
	if string.find(selector, "ms") then
		local stringx = string.format("%f", x)
		local init = string.find(stringx, "%.")
		if init then
			local append = string.sub(stringx, init + 1, init + 3)
			for i = 1, 3 - string.len(append) do
				append ..= "0"
			end

			if separator == "punc" then
				ts ..= string.format(".%s", append)
			elseif separator == "abbr" then
				ts ..= string.format("%sms", append)
			elseif separator == "word" then
				ts ..= string.format("%s milliseconds", append)
			end
		end
	end

	--- trailing non-alphanumerics (targets trailing zeroes and punctuation)
	local init = string.find(ts, "%W+", string.len(ts))
	if init then
		ts = string.sub(ts, 1, init - 1)
	end

	return ts
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

--- runs function at `step` second interval for `time` seconds \
--- exceptions: \
--- `step == -1`: function is called every heartbeat \
--- `time == -1`: bound function runs indefinitely
function types.framerule(step: number, time: number, f: (dt: number, elapsed: number) -> (), immediate: boolean?): (RBXScriptConnection, thread?)
	if time == -1 then
		local start = os.clock()
		local recent = os.clock()
		if immediate ~= false then
			recent -= step or 1/60 --- doesn't matter
		end

		if step == -1 then
			return RunService.Heartbeat:Connect(function(dt)
				f(dt, os.clock() - start)
			end)
		else
			return RunService.Heartbeat:Connect(function()
				local now = os.clock()
				local dt = now - recent
				if dt > step then
					recent = now - (dt - step)

					f(dt, now - start)
				end
			end)
		end
	else
		local connection = types.framerule(step, -1, f, immediate)

		return connection, task.delay(time, connection.Disconnect, connection)
	end
end

--- runs function at `step` stepfrequency for `time` seconds \
--- exceptions: \
--- `time == -1`: bound function runs indefinitely
function types.fixedstep(step: Enum.StepFrequency, time: number, f: (dt: number) -> ()): (RBXScriptConnection, thread?)
	if time == -1 then
		return RunService:BindToSimulation(f, step)
	else
		local connection = types.fixedstep(step, -1, f)

		return connection, task.delay(time, connection.Disconnect, connection)
	end
end

return types