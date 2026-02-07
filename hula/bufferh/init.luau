--!strict
--!native

local random = Random.new()

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

export type unsignedinteger = 
	| "u8"
	| "u16"
	| "u24"
	| "u32"

export type signedinteger = 
	| "i8"
	| "i16"
	| "i24"
	| "i32"

export type float =
	| "f32"
	| "f64"

export type intfloat = unsignedinteger | signedinteger | float | string

export type integer = unsignedinteger | signedinteger

--- ### bufferh.luau
---
--- buffer library extension
local bufferh = {
	intfloatbytesizes = {
		u8 = 1;
		u16 = 2;
		u24 = 3;
		u32 = 4;
		i8 = 1;
		i16 = 2;
		i24 = 3;
		i32 = 4;
		f32 = 4;
		f64 = 8;
	} :: {[intfloat]: number};
	intfloatread = {
		u8 = buffer.readu8;
		u16 = buffer.readu16;
		u24 = readu24;
		u32 = buffer.readu32;
		i8 = buffer.readi8;
		i16 = buffer.readi16;
		i24 = readi24;
		i32 = buffer.readi32;
		f32 = buffer.readf32;
		f64 = buffer.readf64;
	} :: {[intfloat]: (b: buffer, offset: number) -> number};
	intfloatwrite = {
		u8 = buffer.writeu8;
		u16 = buffer.writeu16;
		u24 = writeu24;
		u32 = buffer.writeu32;
		i8 = buffer.writei8;
		i16 = buffer.writei16;
		i24 = writei24;
		i32 = buffer.writei32;
		f32 = buffer.writef32;
		f64 = buffer.writef64;
	} :: {[intfloat]: (b: buffer, offset: number, value: number) -> ()};
}

bufferh.readi24 = readi24
bufferh.writei24 = writei24
bufferh.readu24 = readu24
bufferh.writeu24 = writeu24

--- writes random alphanumeric characters `[A-Za-z0-9]` to buffer
function bufferh.writerandom(b: buffer, offset: number, count: number, R: Random?)
	for i = 0, count - 1, 1 do
		local value = (R or random):NextInteger(1, 62)
		if value <= 26 then --- [a-z] [abcdefghijklmnopqrstuvwxyz] [1-26] -> [97-122] 
			buffer.writeu8(b, i + offset, value + 96)
		elseif value <= 52 then --- [A-Z] [ABCDEFGHIJKLMNOPQRSTUVWXYZ] [27-52] -> [65-90] 
			buffer.writeu8(b, i + offset, value + 38)
		else --- elseif value <= 62 then --- [0-9] [0123456789] [53-62] -> [48-57]
			buffer.writeu8(b, i + offset, value - 5)
		end
	end

	return b
end

--- reads unit vector from buffer
function bufferh.readunitvector(b: buffer, offset: number)
	return Vector3.new(
		math.map(buffer.readu8(b, offset), 0, 255, -1, 1),
		math.map(buffer.readu8(b, offset + 1), 0, 255, -1, 1),
		math.map(buffer.readu8(b, offset + 2), 0, 255, -1, 1)
	)
end

--- writes unit vector to buffer
function bufferh.writeunitvector(b: buffer, offset: number, value: Vector3)
	buffer.writeu8(b, offset, math.map(value.X, -1, 1, 0, 255))
	buffer.writeu8(b, offset + 1, math.map(value.Y, -1, 1, 0, 255))
	buffer.writeu8(b, offset + 2, math.map(value.Z, -1, 1, 0, 255))
end

--- reads Vector3i24 from buffer
function bufferh.readvector3i24(b: buffer, offset: number, precision: number)
	return Vector3.new(
		bufferh.readi24(b, offset),
		bufferh.readi24(b, offset + 3),
		bufferh.readi24(b, offset + 6)
	) * (1 / precision)
end

--- writes Vector3i24 to buffer
function bufferh.writevector3i24(b: buffer, offset: number, value: Vector3, precision: number)
	value *= precision

	bufferh.writei24(b, offset, value.X)
	bufferh.writei24(b, offset + 3, value.Y)
	bufferh.writei24(b, offset + 6, value.Z)
end

--- rotates range of values with fixed variable size to the right
--- ```
--- rrotate(bufferu8[23, 33, 91], 0, 1, 3) -> [91, 23, 33]
--- ```
function bufferh.rrotate(b: buffer, offset: number, size: number, range: number)
	local x = buffer.readstring(b, offset + (size * (range - 1)), size) --- pull last value [91]
	buffer.copy(b, offset + size, b, offset, (size * range) - size) --- push range leading up to last value up by 1 place [23, 23, 33]
	buffer.writestring(b, offset, x) --- write to first value
end

--- rotates range of values with fixed variable size to the left
--- ```
--- lrotate(bufferu8[23, 33, 91], 0, 1, 3) -> [33, 91, 23]
--- ```
function bufferh.lrotate(b: buffer, offset: number, size: number, range: number)
	local last = (size * range) - size

	local x = buffer.readstring(b, offset, size) --- pull first value [23]
	buffer.copy(b, offset, b, offset + size, last) --- push range after the first value down by 1 place [33, 91, 91]
	buffer.writestring(b, offset + last, x) --- write to last value
end

--- swaps range of bytes stored at offsets `x` and `y` \
--- `range (?=1)` range of bytes to swap
function bufferh.swap(b: buffer, x: number, y: number, range: number?)
	range = range or 1
	local temp = buffer.create(range::number)
	buffer.copy(temp, x, b, 0, range)
	buffer.copy(b, x, b, y, range)
	buffer.copy(b, y, temp, 0, range)
end

--- returns `a == b`, starting comparison at `offset`
function bufferh.eq(a: buffer, b: buffer, offset: number)
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
			return bufferh.eq(a, b, offset + clamped)
		else
			return false
		end
	end
end

--- returns byte-wide changes made from old buffer `a` and new buffer `b` \
--- `number result[1]` delta offset \
--- `buffer result[2]` delta byte value
function bufferh.delta(a: buffer, b: buffer, offset: number?)
	local alen = buffer.len(a)
	local blen = buffer.len(b)

	assert(alen == blen, "expected buffers to be of same-length when resolving delta")

	offset = offset or 0
	assert(offset) --- solver kick rocks

	local result = {}

	if offset >= alen then
		return result
	else
		local traverse = alen - offset
		if traverse >= 4 then
			if buffer.readu32(a, offset) ~= buffer.readu32(b, offset) then
				local value = buffer.create(4)
				buffer.copy(value, 0, b, offset, 4)
				table.insert(result, {offset, value::any})
			end

			local r = bufferh.delta(a, b, offset + 4)
			table.move(r, 1, #r, #result + 1, result)
		elseif traverse >= 2 then
			if buffer.readu16(a, offset) ~= buffer.readu16(b, offset) then
				local value = buffer.create(2)
				buffer.copy(value, 0, b, offset, 2)
				table.insert(result, {offset, value::any})
			end

			local r = bufferh.delta(a, b, offset + 2)
			table.move(r, 1, #r, #result + 1, result)
		else
			if buffer.readu8(a, offset) ~= buffer.readu8(b, offset) then
				local value = buffer.create(1)
				buffer.copy(value, 0, b, offset, 1)
				table.insert(result, {offset, value::any})
			end

			local r = bufferh.delta(a, b, offset + 1)
			table.move(r, 1, #r, #result + 1, result)
		end
	end

	return result
end

--- returns a `int16`-width matrix-buffer \
--- space complexity of `2 + (2*columns*rows)` \
--- *matrix value placements start at offset `2`, as column/row info is stored in the first 2 bytes. \
--- args passed into mutator functions, however, should be zero-indexed.*
function bufferh.creatematrix(columns: number, rows: number)
	local m = buffer.create( 2 + (2 * columns * rows) )

	buffer.writeu8(m, 0, columns)
	buffer.writeu8(m, 1, rows)

	return m
end

--- writes value to matrix
function bufferh.matrixwrite(m: buffer, column: number, row: number, value: number)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column) + (row * width)

	buffer.writei16(m, offset, value)
end

--- extract value from matrix
function bufferh.matrixextract(m: buffer, column: number, row: number)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column) + (row * width)

	return buffer.readi16(m, offset)
end

--- clears matrix, preserving the first two bits that contain row/column info \
--- equivalent to `buffer.fill(m, 2, 0)`
function bufferh.matrixclear(m: buffer)
	buffer.fill(m, 2, 0)
end

--- reads set of values along row of matrix
function bufferh.matrixreadrow(m: buffer, row: number): {number}
	local columns = buffer.readu8(m, 0)
	local width = 2 * columns
	local offset = 2 + (row * width)

	local r = table.create(columns, 0)

	for i = 1, columns do
		r[i] = buffer.readi16(m, offset)
		offset += 2
	end

	return r
end

--- returns a copy of row of matrix
function bufferh.matrixextractrow(m: buffer, row: number)
	local columns = buffer.readu8(m, 0)
	local width = 2 * columns
	local offset = 2 + (row * width)

	local copy = buffer.create(width)
	buffer.copy(copy, 0, m, offset, width)

	return copy
end

--- returns a string representation of matrix row
function bufferh.matrixtostringrow(m: buffer, row: number)
	local columns = buffer.readu8(m, 0)
	local width = 2 * columns
	local offset = 2 + (row * width)

	local str = ""
	for _ = 1, columns do
		str ..= string.format("%05d ", buffer.readi16(m, offset)) --- format precision is 05d because i16's have at most 5 integers not including the sign
		offset += 2
	end

	return str
end

--- reads sum of values along column of matrix
function bufferh.matrixreadcolumn(m: buffer, column: number)
	local rows = buffer.readu8(m, 1)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column)

	local sum = 0
	for _ = 1, rows do
		sum += buffer.readi16(m, offset)
		offset += width
	end

	return sum
end

--- returns a copy of column of matrix
function bufferh.matrixextractcolumn(m: buffer, column: number)
	local rows = buffer.readu8(m, 1)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column)

	local copy = buffer.create(2 * rows)
	for i = 0, rows - 1, 1 do
		buffer.writei16(copy, 2 * i, buffer.readi16(m, offset))
		offset += width
	end

	return copy
end

--- returns a string representation of matrix row
function bufferh.matrixtostringcolumn(m: buffer, column: number)
	local rows = buffer.readu8(m, 1)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column)

	local str = ""
	for _ = 1, rows do
		str ..= string.format("%05d ", buffer.readi16(m, offset)) --- format precision is 05d because i16's have at most 5 integers not including the sign
		offset += width
	end

	return str
end

--- creates a variable-width value-maxvalue bar
function bufferh.createbar(format: unsignedinteger|"f64", value: number, maxvalue: number?)
	local size = bufferh.intfloatbytesizes[format]
	assert(size, string.format("unknown intfloat size for '%s'", format))
	
	local write = bufferh.intfloatwrite[format]
	assert(write, string.format("unknown intfloat write function for '%s'", format))

	local b = buffer.create(2 * size)
	write(b, 0, value)
	write(b, size, maxvalue or value)

	return b
end

--- returns: \
--- `(b: buffer, offset: number) -> number` buffer read function \
--- `number` byte size of each value in bar `b`, equivalent to `0.5 * buffer.len(b)`
function bufferh.barresolvereadfunction(b: buffer)
	local width = buffer.len(b)
	local size = width * 0.5
	
	if size == 1 then
		return bufferh.intfloatread.u8, size
	elseif size == 2 then
		return bufferh.intfloatread.u16, size
	elseif size == 3 then
		return bufferh.intfloatread.u24, size
	elseif size == 4 then
		return bufferh.intfloatread.u32, size
	elseif size == 8 then
		return bufferh.intfloatread.f64, size
	else
		error(string.format("unknown intfloat write function for size '%d'", size))
	end
end

--- returns: \
--- `(b: buffer, offset: number, value: number) -> ()` buffer write function \
--- `number` byte size of each value in bar `b`, equivalent to `0.5 * buffer.len(b)`
function bufferh.barresolvewritefunction(b: buffer)
	local width = buffer.len(b)
	local size = width * 0.5
	
	if size == 1 then
		return bufferh.intfloatwrite.u8, size
	elseif size == 2 then
		return bufferh.intfloatwrite.u16, size
	elseif size == 3 then
		return bufferh.intfloatwrite.u24, size
	elseif size == 4 then
		return bufferh.intfloatwrite.u32, size
	elseif size == 8 then
		return bufferh.intfloatwrite.f64, size
	else
		error(string.format("unknown intfloat write function for size '%d'", size))
	end
end

--- writes value to bar
function bufferh.barwritevalue(b: buffer, value: number)
	local write, size = bufferh.barresolvewritefunction(b)
	assert(write, string.format("unknown write function for size %d", size))

	write(b, 0, value)
end

--- writes maxvalue to bar
function bufferh.barwritemaxvalue(b: buffer, maxvalue: number)
	local write, size = bufferh.barresolvewritefunction(b)
	assert(write, string.format("unknown write function for size %d", size))

	write(b, size, maxvalue)
end

--- returns value of bar
function bufferh.barreadvalue(b: buffer)
	local read, size = bufferh.barresolvereadfunction(b)
	assert(read, string.format("unknown read function for size %d", size))

	return read(b, 0)
end

--- returns maxvalue of bar
function bufferh.barreadmaxvalue(b: buffer)
	local read, size = bufferh.barresolvereadfunction(b)
	assert(read, string.format("unknown read function for size %d", size))

	return read(b, size)
end

--- returns bar `value, maxvalue`
function bufferh.barunpack(b: buffer)
	local read, size = bufferh.barresolvereadfunction(b)
	assert(read, string.format("unknown read function for size %d", size))
	
	return read(b, 0), read(b, size)
end

--- returns 9-wide state `[f64 expiry (?=0), u8 value (?=1)]`
--- ```
---       expiry      value   
--- bytes [00000000]  [0]  
--- range [0 .. 7]    [8]
--- limit [f64]       [0, 255] 
--- ```
function bufferh.createstate(time: number?, value: number?)
	local s = buffer.create(9)
	buffer.writef64(s, 0, time or 0)
	buffer.writeu8(s, 8, value or 1)

	return s
end

--- returns `f64` state expiry
function bufferh.statereadexpiry(s: buffer)
	return buffer.readf64(s, 0)
end

--- writes to expiry portion of state
function bufferh.statewriteexpiry(s: buffer, expiry: number)
	buffer.writef64(s, 0, expiry)
end

--- returns `u8` state value
function bufferh.statereadvalue(s: buffer)
	return buffer.readu8(s, 8)
end

--- writes to value portion of state
function bufferh.statewritevalue(s: buffer, value: number)
	buffer.writeu8(s, 8, value)
end

--- returns \
--- `f64` state expiry \
--- `u8` state value
function bufferh.stateunpack(s: buffer)
	return buffer.readf64(s, 0), buffer.readu8(s, 8)
end

--- returns numeric stage `base / base` \
--- `base (?=2)`: stage base value
--- ```
--- key   numerator  denominator
--- bits  [0000]     [0000]  
--- range [0 .. 3]   [4 .. 7]
--- value [0, 15]    [0, 15] 
--- ```
function bufferh.createstage(width: number, base: number?)
	local s = buffer.create(width)
	for i = 0, width - 1, 1 do
		local bitoffset = i * 8
		buffer.writebits(s, bitoffset, 4, base or 2)
		buffer.writebits(s, bitoffset + 4, 4, base or 2)
	end

	return s
end

--- writes value to signed portion of numeric stage
--- ```luau
--- createstage(1) --- 2/2
--- stagewrite(s, 0, 5) --- 5/2
--- stagewrite(s, 0, -3) --- 5/3
--- ```
function bufferh.stagewrite(s: buffer, byteoffset: number, value: number)
	local bitoffset = byteoffset * 8
	if math.sign(value) == 1 then
		buffer.writebits(s, bitoffset, 4, math.clamp(value, 0, 15))
	else
		buffer.writebits(s, bitoffset + 4, 4, math.clamp(math.abs(value), 0, 15))
	end
end

--- adds value to signed portion of numeric stage
--- ```luau
--- createstage(1) --- 2/2
--- stagedelta(s, 0, 1) --- 3/2
--- stagedelta(s, 0, -2) --- 3/4
--- ```
function bufferh.stagedelta(s: buffer, byteoffset: number, value: number)
	local bitoffset = byteoffset * 8
	if math.sign(value) == 1 then
		buffer.writebits(s, bitoffset, 4, math.clamp(value + buffer.readbits(s, bitoffset, 4), 0, 15))
	else
		buffer.writebits(s, bitoffset + 4, 4, math.clamp(math.abs(value) + buffer.readbits(s, bitoffset + 4, 4), 0, 15))
	end
end

--- returns numeric stage `x / y`
function bufferh.stageread(s: buffer, byteoffset: number)
	local bitoffset = byteoffset * 8
	return buffer.readbits(s, bitoffset, 4) / buffer.readbits(s, bitoffset + 4, 4)
end

--- creates an atb bar
--- ```
--- key   phase     rotation  turn available
--- bits  [0000]    [0000]    [64 (8 bytes)]
--- range [0 .. 3]  [4 .. 7]  [8 .. 71]
--- value [0, 15]   [0, 15]   [f64]
--- ```
function bufferh.createatb()
	return buffer.create(1+8)
end

--- returns atb action phase
function bufferh.atbreadphase(a: buffer)
	return buffer.readbits(a, 0, 4)
end

--- writes atb action phase
function bufferh.atbwritephase(a: buffer, value: number)
	buffer.writebits(a, 0, 4, value)
end

--- returns atb action phase rotation offset
function bufferh.atbreadrotation(a: buffer)
	return buffer.readbits(a, 4, 4)
end

--- writes atb action phase rotation offset
function bufferh.atbwriterotation(a: buffer, value: number)
	buffer.writebits(a, 4, 4, value)
end

--- returns atb turn available time
function bufferh.atbreadtime(a: buffer)
	return buffer.readf64(a, 1)
end

--- writes atb turn available time
function bufferh.atbwritetime(a: buffer, value: number)
	buffer.writef64(a, 1, value)
end

--- returns # of bytes required to store value \
--- equivalent to `1 + (math.log(value, 2) // 8)`
function bufferh.numbytes(value: number)
	return 1 + (math.log(value, 2) // 8)
end

--- returns # of bits required to store value \
--- equivalent to `1 + math.log(value, 2) // 1`
function bufferh.numbits(value: number)
	return 1 + math.log(value, 2) // 1
end

return bufferh