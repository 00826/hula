--!strict
--!native

local random = Random.new()

--- returns a randomized alphanumeric string from regex characters `[A-Za-z0-9]`
local function stringcreate(len: number)
	local b = buffer.create(len)
	for i = 0, len - 1, 1 do
		local value = random:NextInteger(1, 62)
		if value <= 26 then --- [a-z] [abcdefghijklmnopqrstuvwxyz] [1-26] -> [97-122] 
			buffer.writeu8(b, i, value + 96)
		elseif value <= 52 then --- [A-Z] [ABCDEFGHIJKLMNOPQRSTUVWXYZ] [27-52] -> [65-90] 
			buffer.writeu8(b, i, value + 38)
		else --- elseif value <= 62 then --- [0-9] [0123456789] [53-62] -> [48-57]
			buffer.writeu8(b, i, value - 5)
		end
	end

	return buffer.readstring(b, 0, len)
end

--- returns `a == b`, starting comparison at `offset`
local function buffereq(a: buffer, b: buffer, offset: number)
	local alen = buffer.len(a)
	local blen = buffer.len(b)

	if alen ~= blen then
		return false
	elseif offset >= alen then
		return true
	else
		local traverse = alen - offset
		local clamped = math.clamp(traverse, 0, 4) --- limit comparison range to 4 bytes (u32)
		
		local bitoffset = offset * 8
		local bitcount = clamped * 8
		if buffer.readbits(a, bitoffset, bitcount) == buffer.readbits(b, bitoffset, bitcount) then
			return buffereq(a, b, offset + clamped)
		else
			return false
		end
	end
end

--- ### tableh.luau
---
--- table library extension
local tableh = {
	--- shorthand 1-byte instructions used by `tableh.difference()` and `tableh.reconcile()`
	instructions = {
		"\u{0000}";
		"\u{0001}";
		"\u{0002}";
	};
}

--- `T[string random alphanumeric key (len ?=4)] = value` \
--- returns `random alphanumeric key` for convenience
function tableh.insertkey(t: {[any]: any}, value: any, len: number)
	local key = nil

	repeat key = stringcreate(len)
	until key ~= nil and t[key] == nil

	t[key] = value

	return key
end

--- returns first occurrence of key-value pair in `t` where `v[scope] == value`
function tableh.scope<T>(t: {[T]: any}, scope: T, value: number)
	for k, v in t do
		if v[scope] == value then
			return v
		end
	end

	return nil
end

--- shorthand for `t[a] = (t[a] or 0) + b`
function tableh.incr<T>(t: {[T]: number}, a: T, b: number)
	--- ta
	t[a] = (t[a] or 0) + b
end

--- returns all keys in `t`
function tableh.keys<T>(t: {[T]: any})
	local result = {}
	for k in t do
		table.insert(result, k)
	end

	return result
end

--- returns a reverse iterator function and the table for use in a for loop
function tableh.ipairsr<T>(t: {T}): (({T}, number) -> (number?, T), {T}, number)
	return coroutine.wrap(function()
		for i = #t, 1, -1 do
			coroutine.yield(i, t[i])
		end
	end), t, 0
end

--- returns random value from list
function tableh.nextvaluefromlist<T>(t: {T}, R: Random?): T?
	if #t < 0 then
		return nil
	else
		return t[(R or random):NextInteger(1, #t)]
	end
end

--- returns random value from weighted table
function tableh.nextvaluefromweightedtable<T>(t: { { key: string, weight: number } & T }, R: Random?): T?
	if #t < 0 then
		return nil
	else
		local sum = 0
		for _, entry in ipairs(t) do
			sum += entry.weight
		end

		local roll, passed = (R or random):NextNumber(0, sum), 0
		for _, entry in ipairs(t) do
			passed += entry.weight

			if roll <= passed then
				return entry
			end
		end

		return nil
	end
end

--- rotates array `A` `x` times such that:
--- ```
--- rotate([1, 2, 3, 4, 5], 1) -> [5, 1, 2, 3, 4]
--- rotate([1, 2, 3, 4, 5], -1) -> [2, 3, 4, 5, 1]
--- ```
function tableh.rotate(t: {any}, x: number)
	if x ~= 0 then
		if x > 0 then
			local value = table.remove(t)
			table.insert(t, 1, value)
		elseif x < 0 then
			local value = table.remove(t, 1)
			table.insert(t, value)
		end

		tableh.rotate(t, x - math.sign(x))
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
function tableh.page<T>(t: {T}, size: number, offset: number)
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
function tableh.createbook(size: number, alloc: number?)
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
function tableh.booknext(b: typeof(tableh.createbook(...)), delta: number)
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

--- returns a deep copy of table
function tableh.deepcopy(t: {[any]: any}): {[any]: any}
	local copy = {}

	local iter: any = pairs
	if #t > 0 then
		iter = ipairs
	end

	for k, v in iter(t) do
		if type(v) == "table" then
			copy[k] = tableh.deepcopy(v)
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

--- recursive table.clear() for roblox types: \
--- `typeof(t[k]) == "Instance" -> Destroy()` \
--- `typeof(t[k]) == "RBXScriptConnection" -> Disconnect()` \
--- `typeof(t[k]) == "thread" -> task.cancel(v)`
function tableh.rbxtypeclear(a: any)
	if type(a) == "table" then
		for _, b in a do
			tableh.rbxtypeclear(b)
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

--- returns \
--- `string indexer type` of `a` \
--- `string indexer type` of `b` \
--- `boolean canreconcile` if reconciling `a` and `b` will result in a mixed table
function tableh.canreconcile(a: {[any]: any}, b: {[any]: any})
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
--- `[!]` because the raw diff between two arrays *cannot* be reconciled normally, certain strings are used as shorthand instructions to be read by `tableh.reconcile()`: \
--- `"\u{0000}"` represents `nil` \
--- `"\u{0001}"` represents `b ∖ a` where `b = ø` and `a = ø` (no change) \
--- `"\u{0002}"` represents `b ∖ a` where `b ≠ ø` and `a = ø` (`table.clear()`)
function tableh.difference(a: any, b: any): any
	local atype = type(a)
	local btype = type(b)

	if btype == atype then
		if btype == "table" then
			local akeytype, bkeytype, canreconcile = tableh.canreconcile(a, b)
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
							local c = tableh.difference(a[i], b[i])
							result[i] = c
						end
					end
				else
					--- read dictionary diff
					for bkey, bvalue in b do
						local c = tableh.difference(a[bkey], bvalue)
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
					if table.find(tableh.instructions, v) then
						table.insert(preconcat, v)
					end
				end
				local concat = table.concat(preconcat)
				for _, char in ipairs(tableh.instructions) do
					if concat == string.rep(char, len) then
						return char
					end
				end

				return result
			end
		elseif btype == "buffer" then
			if buffereq(b, a, 0) == true then
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
			return tableh.deepcopy(b)
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
function tableh.collapse(difference: {[any]: any})
	for k, v in difference do
		if type(v) == "table" then
			tableh.collapse(v)
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
function tableh.reconcile(b: any, c: any): (any, number)
	local btype = type(b)
	local ctype = type(c)

	--- byte instructions
	if c == "\u{0000}" then
		if btype == "table" then
			tableh.rbxtypeclear(b)
		end
		return nil, b ~= nil and 1 or 0
	elseif c == "\u{0001}" then
		return b, 0
	elseif c == "\u{0002}" then
		if btype == "table" then
			if next(b) ~= nil then
				tableh.rbxtypeclear(b)
				--- table.clear(b)
				
				return b, 1
			else
				return b, 0 --- is already empty
			end
		end

		return b, 0 --- ? shouldn't arrive at this case
	end

	if ctype == btype then
		if ctype == "table" then
			local bkeytype, ckeytype, canreconcile = tableh.canreconcile(b, c)
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
						local reentryvalue, reentrycount = tableh.reconcile(b[i], c[i])
						b[i] = reentryvalue
						count += reentrycount
					end
				end
			else
				--- reconcile dictionary
				for ckey, cvalue in c do
					local reentryvalue, reentrycount = tableh.reconcile(b[ckey], cvalue)
					b[ckey] = reentryvalue
					count += reentrycount
				end
				for bkey in b do
					if c[bkey] == "\u{0000}" then
						if type(b[bkey]) == "table" then
							tableh.rbxtypeclear(b[bkey])
						end
						b[bkey] = nil
					end
				end
			end
			
			return b, count
		elseif ctype == "buffer" then
			if buffereq(b, c, 0) == true then
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

return tableh