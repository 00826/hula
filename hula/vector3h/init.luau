--!strict
--!native

local random = Random.new()

--- ### vector3h.luau
---
--- Vector3 library extension \
--- vector library wrappers (normalize, magnitude, etc) are `(...::any)::Vector3`-casted
local vector3h = {
	yzaxis = Vector3.one - Vector3.xAxis;
	xzaxis = Vector3.one - Vector3.yAxis;
	xyaxis = Vector3.one - Vector3.zAxis;
}

--- returns `vector.lerp(v, w, t)`
function vector3h.lerp(v: Vector3, w: Vector3, t: number)
	return (vector.lerp(v::any, w::any, t)::any)::Vector3
end

--- returns `vector.slerp(v, w, t)`
function vector3h.slerp(v: Vector3, w: Vector3, t: number)
	local angle = math.acos(vector.dot(v::any, w::any))
	if math.isnan(angle) or angle < 1e-4 then
		return w
	else
		return (math.sin(angle * (1 - t)) * v + math.sin(angle * t) * w ) / math.sin(angle)
	end
end

--- returns `vector.normalize(v)`
function vector3h.normalize(v: Vector3)
	return (vector.normalize(v::any)::any)::Vector3
end

--- returns `vector.magnitude(v)`
function vector3h.magnitude(v: Vector3)
	return vector.magnitude(v::any)
end

--- returns `vector.dot(v, w)`
function vector3h.dot(v: Vector3, w: Vector3)
	return vector.dot(v::any, w::any)
end

--- returns `math.acos(vector.dot(v, w))`
function vector3h.angle(v: Vector3, w: Vector3)
	return math.acos(vector.dot(v::any, w::any)) --- faster than vector.angle(v, w)
end

--- returns `vector.cross(v, w)`
function vector3h.cross(v: Vector3, w: Vector3)
	return (vector.cross(v::any, w::any)::any)::Vector3
end

--- returns true if all components of `v` are finite
function vector3h.isfinite(v: Vector3)
	local x, y, z = v.X, v.Y, v.Z
	return math.isfinite(x)
		and math.isfinite(y)
		and math.isfinite(z)
end

--- returns `vector.normalize(v)`, or, if `NaN`, `Vector3.zero`
function vector3h.unitorzero(v: Vector3)
	if vector.magnitude(v::any) > 0 then
		return (vector.normalize(v::any)::any)::Vector3
	else
		return Vector3.zero
	end
end

--- returns `v` projected onto `w`
function vector3h.project(v: Vector3, w: Vector3)
	w = vector3h.unitorzero(w)

	return vector.dot(v::any, w::any) * w
end

--- returns `v` rejected from `w`
function vector3h.reject(v: Vector3, w: Vector3)
	return v - vector3h.project(v, w)
end

--- returns `point` transformed to objectspace of `position, lookvector, upvector(?=Vector3.yAxis)` \
--- eev is the goat
function vector3h.pointtoobjectspace(point: Vector3, position: Vector3, lookvector: Vector3, upvector: Vector3?)
	local delta = point - position

	--[[
	--- case for non-orthonormal input
	local ub = vector.cross(upvector::any, backvector::any)

	upvector = upvector or Vector3.yAxis
	return Vector3.new(
		vector.dot(delta::any, ub),
		vector.dot(delta::any, vector.cross(backvector::any, rightvector::any)),
		vector.dot(delta::any, vector.cross(rightvector::any, upvector::any))
	) / vector.dot(rightvector::any, ub)
	]]

	--- fast case for orthonormal input
	upvector = upvector or Vector3.yAxis
	return Vector3.new(
		vector.dot(delta::any, vector.cross(lookvector::any, upvector::any)::any),
		vector.dot(delta::any, upvector::any),
		-vector.dot(delta::any, lookvector::any)
	)
end

--- returns `point`, in objectspace of `position, lookvector, upvector(?=Vector3.yAxis)`, transformed to worldspace
function vector3h.pointtoworldspace(point: Vector3, position: Vector3, lookvector: Vector3, upvector: Vector3?)
	upvector = upvector or Vector3.yAxis

	return position
		+ (point.X * (vector.cross(lookvector::any, upvector::any)::any)::Vector3)
		+ (point.Y * upvector)
		+ (point.Z * -lookvector)
end

--- returns normal of nearest normal on obb formed by `position` with orientation of `lookvector, upvector(?=Vector3.yAxis)`
function vector3h.nearestnormalonbox(point: Vector3, position: Vector3, size: Vector3, lookvector: Vector3, upvector: Vector3?)
	upvector = upvector or Vector3.yAxis

	local objectspace = vector3h.pointtoobjectspace(point, position, lookvector, upvector)
	local unit = vector3h.normalize(objectspace)

	local dot = -math.huge
	local normal = unit

	local s = 1 / size
	local ux = Vector3.xAxis * s
	local uy = Vector3.yAxis * s
	local uz = Vector3.zAxis * s

	for _, v in ipairs({
		ux;
		-ux;
		uy;
		-uy;
		uz;
		-uz;
	}) do
		local d = vector3h.dot(unit, v)
		if d > dot then
			dot = d
			normal = vector3h.normalize(v)
		end
	end

	return vector3h.pointtoworldspace(normal, Vector3.zero, lookvector, upvector)
end

--- writes non-zero components of `w` onto `v`
--- ```luau
--- vector3h.write(vector[1, 2, 3], vector[5, 0, -10]) -> vector[5, 2, -10]
--- ```
function vector3h.write(v: Vector3, w: Vector3)
	local x, y, z = w.X, w.Y, w.Z

	return Vector3.new(
		x == 0 and v.X or x,
		y == 0 and v.Y or y,
		z == 0 and v.Z or z
	)
end

--- returns point on bezier curve at interpolant `t`
function vector3h.bezier(vectors: {Vector3}, t: number)
	local len = #vectors
	if len > 1 then
		local result = table.create(len)::{Vector3}
		for i, v in ipairs(vectors) do
			local w = vectors[i + 1]
			if not w then break end

			table.insert(result, (vector.lerp(v::any, w::any, t)::any)::Vector3)
		end

		return vector3h.bezier(result, t)
	else
		return vectors[1]
	end
end

--- returns vectors between `v` and `w` such that `u` and `w` are split into `u` equal segments \
--- `split[1]` guarantees equivalence to `v` \
--- `split[#split]` guarantees equivalence to `w`
function vector3h.split(v: Vector3, w: Vector3, u: number)
	if u < 3 then
		return {v, w}
	else
		local result = table.create(u)::{Vector3}
		table.insert(result, v)
		
		for i = 1, u - 1 do
			table.insert(result, (vector.lerp(v::any, w::any, i / u)::any)::Vector3)
		end

		table.insert(result, w)

		return result
	end
end

--- returns random unit vector
function vector3h.nextunitvector(R: Random?)
	return (R or random):NextUnitVector()
end

--- returns random unit vector within bounds of cone \
--- quasiduck is the goat
function vector3h.nextunitspread(v: Vector3, radians: number, R: Random?)
	--- create an orthonormal basis (u, w, v)
	--- equivalent of producing the rightvector (u) and upvector (w) of v
	local u
	if math.abs(v.Y) < 0.999 then
		u = vector.normalize(vector.cross(v::any, Vector3.yAxis::any))
	else
		u = vector.normalize(vector.cross(v::any, Vector3.xAxis::any))
	end
	local w = vector.cross(v::any, u)

	--- generate a random point within the spherical cap (from unit sphere)
	--- produces spherical coordinates
	local cos = (R or random):NextNumber(math.cos(radians), 1)
	local sin = (1 - cos * cos)^0.5
	local phi = (R or random):NextNumber(0, math.tau)

	local x = sin * math.cos(phi)
	local y = sin * math.sin(phi)
	local z = cos

	--- construct the random vector in the original coordinate system
	return (((x*u)::any + (y*w)::any + (z*v)::any)::any)::Vector3
end

--- returns random point within bounds of `[v, w]`
function vector3h.nextpointinbounds(v: Vector3, w: Vector3, R: Random?)
	return
		  (Vector3.xAxis * (R or random):NextNumber(v.X, w.X))
		+ (Vector3.yAxis * (R or random):NextNumber(v.Y, w.Y))
		+ (Vector3.zAxis * (R or random):NextNumber(v.Z, w.Z))
end

--- returns random point *in* `x,z` radius
function vector3h.nextpointinradius(radius: number, R: Random?)
	local r = radius * ((R or random):NextNumber()^0.5)
	local theta = (R or random):NextNumber() * math.tau

	return (Vector3.xAxis * r * math.cos(theta)) + (Vector3.zAxis * r * math.sin(theta))
end

--- returns random point *on* `x,z` radius
function vector3h.nextpointonradius(radius: number, R: Random?)
	local theta = (R or random):NextNumber() * math.tau
	
	return Vector3.new(radius * math.cos(theta), 0, radius * math.sin(theta))
end

--- returns unit circle with `v` vertices and initial rotation `r`
function vector3h.unitcircle(v: number, r: number)
	local circle = table.create(v)::{Vector3}

	local step = math.tau / v
	for i = 0, v - 1, 1 do
		local theta = r + (i * step)
		table.insert(circle, Vector3.new(math.cos(theta), 0, math.sin(theta)))
	end

	return circle
end

--- returns true if `v` and `w` are coplanar along unit vector `u`
function vector3h.iscoplanar(v: Vector3, w: Vector3, u: Vector3)
	return math.round(vector.dot((v - w)::any, u::any)) == 0
end

--- returns unit vector `v` reflected against unit vector `w`
function vector3h.reflect(v: Vector3, w: Vector3)
	return v - (2 * vector.dot(v::any, w::any) * w)
end

--- returns rotation of unit vector `v` along `axis`
function vector3h.rotation(v: Vector3, axis: Enum.Axis)
	local y, x = 0, 0

	if axis == Enum.Axis.X then
		y = v.Y
		x = v.Z
	elseif axis == Enum.Axis.Y then
		y = v.X
		x = v.Z
	elseif axis == Enum.Axis.Z then
		y = v.Y
		x = v.X
	end

	if y == 0 and x == 0 then
		return 0
	else
		return -1 * math.atan2(y, x)
	end
end

--- returns unit vector from rotations along the x/y axis
function vector3h.fromrotation(rx: number, ry: number)
	return Vector3.new(math.cos(ry) * math.sin(rx), math.sin(ry), math.cos(ry) * math.cos(rx))
end

--- returns unit vector from input vector `inputvector`, relative to viewport `lookvector, -upvector`
function vector3h.movevector(inputvector: Vector3, lookvector: Vector3, upvector: Vector3)
	local rightvector = (vector.cross(lookvector::any, upvector::any)::any)::Vector3
	local cos, sin

	--[[
	local r00, r01, r02 = rightvector.X, upvector.X, lookvector.X
	local   _,   _, r12 = rightvector.Y, upvector.Y, lookvector.Y
	local   _,   _, r22 = rightvector.Z, upvector.Z, lookvector.Z]]

	local r12 = lookvector.Y

	if r12 < 1 and r12 > -1 then
		cos = lookvector.Z
		sin = lookvector.X
	else
		cos = rightvector.X
		sin = -upvector.X*math.sign(lookvector.Y)
	end

	local length = (cos*cos + sin*sin)^0.5
	return Vector3.new(cos*inputvector.X + sin*inputvector.Z, 0, cos*inputvector.Z - sin*inputvector.X) / length
end

--- returns \
--- `vector3 position of intersection` \
--- `vector3 normal of intersection` \
--- `number distance until intersection` \
--- ... of ray starting at `rayposition` in `raydirection` and axis-aligned bounding box at `boxposition` with size `boxsize`
function vector3h.rayintersectbox(rayposition: Vector3, raydirection: Vector3, boxposition: Vector3, boxsize: Vector3)
	local rx, ry, rz = rayposition.X, rayposition.Y, rayposition.Z
	local unitvector = (vector.normalize(raydirection::any)::any)::Vector3
	local id = 1 / unitvector
	local dxi, dyi, dzi = id.X, id.Y, id.Z
	if math.isinf(dxi) then
		dxi = 0
	end
	if math.isinf(dyi) then
		dxi = 0
	end
	if math.isinf(dzi) then
		dxi = 0
	end

	local halfsize = boxsize * 0.5
	local min = boxposition - halfsize
	local max = boxposition + halfsize

	local t1 = (min.X - rx) * dxi
	local t2 = (max.X - rx) * dxi
	local t3 = (min.Y - ry) * dyi
	local t4 = (max.Y - ry) * dyi
	local t5 = (min.Z - rz) * dzi
	local t6 = (max.Z - rz) * dzi

	local tmin = math.max(math.max(math.min(t1, t2), math.min(t3, t4)), math.min(t5, t6))
	local tmax = math.min(math.min(math.max(t1, t2), math.max(t3, t4)), math.max(t5, t6))

	local point
	local normal
	local distance

	if tmax < 0 then
		--- intersection, but out of box bounds
	elseif tmin > tmax then
		--- no intersection
	else
		--- intersection
		distance = tmin
		normal = Vector3.zero
		point = rayposition + (unitvector * distance)

		--- resolve normal
		local mindistance = math.huge
		local modpoint = point - boxposition
		local delta = (vector.abs((boxsize::any) - vector.abs(modpoint::any))::any)::Vector3
		if delta.X < mindistance then
			mindistance = delta.X
			normal = ((vector.sign(modpoint::any)::any)::Vector3) * Vector3.xAxis
		end
		if delta.Y < mindistance then
			mindistance = delta.Y
			normal = ((vector.sign(modpoint::any)::any)::Vector3) * Vector3.yAxis
		end
		if delta.Z < mindistance then
			mindistance = delta.Z
			normal = ((vector.sign(modpoint::any)::any)::Vector3) * Vector3.zAxis
		end
	end

	return point, normal, distance
end

--- returns \
--- `vector3 position of intersection` \
--- `vector3 normal of intersection` \
--- `number distance until intersection` \
--- ... of ray starting at `rayposition` in `raydirection` and bounding sphere at `sphereposition` with radius `sphereradius`
function vector3h.rayintersectsphere(rayposition: Vector3, raydirection: Vector3, sphereposition: Vector3, sphereradius: number)
	local ca = rayposition - sphereposition
	local rsquared = sphereradius * sphereradius

	local point
	local normal
	local distance

	if vector.dot(ca::any, ca::any) <= rsquared then
		point = rayposition
	elseif vector.dot(ca::any, raydirection::any) <= 0 then
		local v = ca - vector3h.project(ca, raydirection)
		local vsquared = vector.dot(v::any, v::any)
		
		if vsquared <= rsquared then
			point = sphereposition + v - ((vector.normalize(raydirection::any)::any) * ((rsquared - vsquared) ^ 0.5))
		end
	else
		--- no collision
	end

	if point ~= nil then
		local deltaposition = point - sphereposition

		normal = (vector.normalize(deltaposition)::any)::Vector3
		distance = vector.magnitude(deltaposition)
	end

	return point::Vector3?, normal, distance
end

--- returns \
--- `vector3 position of intersection` \
--- `vector3 normal of intersection` \
--- `number distance until intersection` \
--- ... of two bounding spheres defined by a position and radius
function vector3h.sphereintersectsphere(aposition: Vector3, aradius: number, bposition: Vector3, bradius: number)
	local deltaposition = bposition - aposition

	local point
	local normal
	local distance

	local d = vector.magnitude(deltaposition::any)
	if aradius + bradius > d then
		point = deltaposition
		normal = (vector.normalize(deltaposition::any)::any)::Vector3
		distance = d
	end

	return point, normal, distance
end

--- returns whether axis-aligned bounding box at `boxposition` with size `boxsize` intersects bounding sphere at `sphereposition` with radius `sphereradius`
function vector3h.isboxintersectingsphere(boxposition: Vector3, boxsize: Vector3, sphereposition: Vector3, sphereradius: number)
	local rsquared = sphereradius * sphereradius
	
	local halfsize = boxsize * 0.5
	local minsize = boxposition - halfsize
	local maxsize = boxposition + halfsize

	local spherex, spherey, spherez = sphereposition.X, sphereposition.Y, sphereposition.Z
	local minx, miny, minz = minsize.X, minsize.Y, minsize.Z
	local maxx, maxy, maxz = maxsize.X, maxsize.Y, maxsize.Z

	if spherex < minx then
		local a = spherex - minx
		rsquared -= a * a
	elseif spherex > maxx then
		local a = spherex - maxx
		rsquared -= a * a
	end
	
	if spherey < miny then
		local a = spherey - miny
		rsquared -= a * a
	elseif spherey > maxy then
		local a = spherey - maxy
		rsquared -= a * a
	end
	
	if spherez < minz then
		local a = spherez - minz
		rsquared -= a * a
	elseif spherez > maxz then
		local a = spherez - maxz
		rsquared -= a * a
	end

	return rsquared > 0
end

--- returns whether axis-aligned boxes `a` and `b` intersect
function vector3h.isboxintersectingbox(aposition: Vector3, asize: Vector3, bposition: Vector3, bsize: Vector3)
	local abs = 2 * vector.abs(aposition - bposition::any)
	local sum = asize + bsize

	return	abs.x < sum.x
		and abs.y < sum.y
		and abs.z < sum.z
end

--- returns: \
--- `if point is within or lies on edge of box`: `0` \
--- `if point is outside of box`: `distance between point and nearest edge on box`
function vector3h.distancefrombox(point: Vector3, size: Vector3, position: Vector3, lookvector: Vector3, upvector: Vector3?)
	local absoluteobjectspace: Vector3 = vector.abs(vector3h.pointtoobjectspace(point, position, lookvector, upvector)::any)::any
	size *= 0.5

	local distx = absoluteobjectspace.X - size.X
	local disty = absoluteobjectspace.Y - size.Y
	local distz = absoluteobjectspace.Z - size.Z

	if distx <= 0 and disty <= 0 and distz <= 0 then
		return 0
	end

	local realx = distx > 0 and vector.magnitude( absoluteobjectspace::any - (absoluteobjectspace + (Vector3.xAxis * distx)) ) or 0
	local realy = disty > 0 and vector.magnitude( absoluteobjectspace::any - (absoluteobjectspace + (Vector3.yAxis * disty)) ) or 0
	local realz = distz > 0 and vector.magnitude( absoluteobjectspace::any - (absoluteobjectspace + (Vector3.zAxis * distz)) ) or 0
	
	return vector.magnitude(Vector3.new(realx, realy, realz)::any)
end

--- returns a number describing unit distance of point relative to sphere: \
--- `if distance < innerradius(?=0)`: `innerradius - distance` \
--- `if distance > radius`: `distance - radius` \
--- `if distance <= radius AND angle ~= nil`: `distance between point and nearest point on edge of cone formed by angle` \
--- `if distance <= radius`: `0`
function vector3h.distancefromsphere(point: Vector3, position: Vector3, radius: number, innerradius: number?, angle: number?, lookvector: Vector3?)
	innerradius = innerradius or 0
	local distance = vector.magnitude(position::any - point)

	if distance < innerradius::any then
		return (innerradius::any - distance)::number
	elseif distance > radius then
		return distance - radius
	elseif distance <= radius then
		if angle then
			assert(lookvector, "angle argument expects a lookvector")
			local unit: Vector3 = vector.normalize(point::any - position)::any
			local unitangle = 2 * vector.angle(lookvector::any, unit::any)
			local diff: number = (unitangle - angle::any)

			if diff > 0 then
				local leftangle: number = (angle::any) * -0.5
				local leftunit = Vector3.new(
					(lookvector.X * math.cos(leftangle)) - (lookvector.Z * math.sin(leftangle)),
					lookvector.Y,
					(lookvector.X * math.sin(leftangle)) + (lookvector.Z * math.cos(leftangle))
				)
				local rightangle: number = (angle::any) * 0.5
				local rightunit = Vector3.new(
					(lookvector.X * math.cos(rightangle)) - (lookvector.Z * math.sin(rightangle)),
					lookvector.Y,
					(lookvector.X * math.sin(rightangle)) + (lookvector.Z * math.cos(rightangle))
				)

				return math.min(
					vector.magnitude((position + (leftunit * distance))::any - point),
					vector.magnitude((position + (rightunit * distance))::any - point)
				)
			end
		end

		return 0
	end
	
	return 0
end

--- returns position of a projectile given its initial `velocity`, elapsed `time`, and `acceleration`
function vector3h.projectilesolveoffset(initialposition: Vector3, velocity: Vector3, time: number, acceleration: Vector3): Vector3
	return initialposition + (vector.normalize(velocity::any)::any * (vector.magnitude(velocity::any) * time)) + ((0.5 * Vector3.yAxis) * acceleration * (time * time))
end

function vector3h.projectilesolvetime(height: number, velocity: Vector3, acceleration: Vector3)
	local vy = velocity.Y
	local gravity = acceleration.Y
	local t = (-vy - (((vy * vy) - 2 * height * gravity) ^ 0.5)) / gravity

	return t
end

--- returns initial velocity and time-to-reach-targetposition of projectile \
--- `sign == 1`: collides while ascending \
--- `sign == -1`: collides while descending \
function vector3h.projectilesolveinitialvelocity(initialposition: Vector3, targetposition: Vector3, acceleration: Vector3, vy: number, sign: number)
	local deltaheight = initialposition.Y - targetposition.Y
	local gravity = acceleration.Y
	local t = (-vy - (sign * (((vy * vy) - 2 * deltaheight * gravity) ^ 0.5))) / gravity

	return Vector3.new(
		(targetposition.X - initialposition.X) / t,
		vy,
		(targetposition.Z - initialposition.Z) / t
	), t
end

return vector3h