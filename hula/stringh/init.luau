--!strict
--!native

local random = Random.new()

--- ### stringh.luau
---
--- string library extension
local stringh = {
	--- base-1000 numeric suffixes
	suffixes = {"K", "M", "B", "T", "Qd", "Qt", "Sx", "Sp", "Oc", "No", "De"};
}

--- returns a randomized alphanumeric string from regex characters `[A-Za-z0-9]`
function stringh.create(len: number)
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

--- formats number as a timestamp string from: \
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
--- `"word"` -> `00 days 00 hours 00 minutes 00 seconds 000 milliseconds`
--- 
--- ```lua
--- stringh.time(3.141, "ss ms", "punc", 1) --- 3s141ms
--- ```
function stringh.time(x: number, selector: string, separator: "punc" | "abbr" | "word", zeropadding: number)
	local ts = ""

	if string.find(selector, "dd") then
		local y = 0
		if x >= 86400 then
			y = x // 86400
			x -= y * 86400
		end

		if separator == "punc" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d:"::any, y)
		elseif separator == "abbr" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "dd"::any, y)
		elseif separator == "word" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d days "::any, y)
		end
	end
	if string.find(selector, "hh") then
		local y = 0
		if x >= 3600 then
			y = x // 3600
			x -= y * 3600
		end

		if separator == "punc" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d:"::any, y)
		elseif separator == "abbr" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "dh"::any, y)
		elseif separator == "word" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d hours "::any, y)
		end
	end
	if string.find(selector, "mm") then
		local y = 0
		if x >= 60 then
			y = x // 60
			x -= y * 60
		end

		if separator == "punc" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d:"::any, y)
		elseif separator == "abbr" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "dm"::any, y)
		elseif separator == "word" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d minutes "::any, y)
		end
	end
	if string.find(selector, "ss") then
		local y = 0
		if x >= 1 then
			y = x // 1
			x -= y * 1
		end
		
		if separator == "punc" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d"::any, y)
		elseif separator == "abbr" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "ds"::any, y)
		elseif separator == "word" then
			ts ..= string.format("%0" .. tostring(zeropadding) .. "d seconds "::any, y)
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

--- strips all leading zeros from string with option to leave 1
function stringh.stripleadingzeros(s: string, allbutone: boolean)
	local gsub, n = string.gsub(s, "^0+", "") --- strip all leading zeros
	if n > 0 and allbutone == true then --- prepend 0 if 1st character is :
		--- if string.sub(gsub, 1, 1) == ":" then
		--- 	gsub = "0" .. gsub
		--- end
		gsub = "0" .. gsub
	end

	return gsub
end

--- appends ordinal suffix (`st, nd, rd, th`) to number
function stringh.ordinal(x: number)
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
function stringh.delta(x: number)
	return x > 0 and "+" .. tostring(x) or tostring(x)
end

--- separates integer with thousands separator
--- 
--- ```lua
--- stringh.separate(31415, ",") --- 31,415
--- stringh.separate(31415, "_") --- 31_415
--- ```
function stringh.separate(x: number, separator: string)
	if math.isinf(x) then
		return "inf"
	elseif math.isnan(x) then
		return "nan"
	elseif math.abs(x) < 1000 then
		return tostring(math.round(x))
	else
		local sign = x < 0 and "-" or ""
		local abs = math.abs(math.round(x))
		
		local reverse = string.reverse(tostring(abs))
		local len = string.len(reverse)
		local result = ""
		
		--- beginning at nearest multiple of 3 to guarantee entire string gets substring-ed
		for i = (len - 1 - (len - 1) % 3 + 3), 1, -3 do
			result ..= string.reverse(string.sub(reverse, i - 2, i)) .. separator
		end
		
		return sign .. string.sub(result, 1, string.len(result) - 1)
	end
end

--- abbreviates number with its associated base-1000 suffix
--- 
--- ```lua
--- stringh.abbreviate(31415, ".", 1) --- 31.4K
--- stringh.abbreviate(31415, ",", 2) --- 31,41K
--- ```
function stringh.abbreviate(x: number, separator: string, precision: number)
	if math.isinf(x) then
		return "inf"
	elseif math.isnan(x) then
		return "nan"
	elseif math.abs(x) < 1000 then
		local int, frac = math.modf(x)

		return string.format(
			"%d%s%s",
			int,
			separator,
			string.sub(string.format(
				"%." .. tostring(precision) .. "f"::any,
				math.abs(frac)
			), 3)
		)
	else
		local log = math.log(math.abs(x), 1000) // 1
		local int, frac = math.modf(x / (1000 ^ log))

		return string.format(
			"%d%s%s%s",
			int,
			separator,
			string.sub(string.format(
				"%." .. tostring(precision) .. "f"::any,
				math.abs(frac)
			), 3),
			stringh.suffixes[log] or "e" .. tostring(math.log(math.abs(x), 10) // 1)
		)
	end
end

--- returns `string.format("<mark color='#000000' transparency='%.3f'>%s</mark>", text)`
function stringh.createmarkstring(text: string, transparency: number)
	return string.format("<mark color='#000000' transparency='%.3f'>%s</mark>", transparency, text)
end

return stringh