--!strict

local RunService = game:GetService("RunService")
local isserver = RunService:IsServer()

local ContentProvider = game:GetService("ContentProvider")
local InsertService = game:GetService("InsertService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local random = Random.new()

--- ### instanceh.luau
---
--- Instance library extension
local instanceh = {
	accessoryflag = "h_accessory";
	accessoryoriginalsizeflag = "h_accessoryoriginalsize";
	accessorycontainerflag = "h_accessories";
	appearanceflag = "h_appearancedescription";
	appearancemap = {
		bodycolorproperties = {
			"HeadColor";
			"TorsoColor";
			"LeftArmColor";
			"LeftLegColor";
			"RightArmColor";
			"RightLegColor";
		};
		clothingcolorproperties = {
			"ShirtColor";
			"PantsColor"
		};
		bodypartproperties = {
			"Face";
		};
		clothingproperties = {
			"GraphicTShirt";
			"Shirt";
			"Pants";
		};
		girltorsos = {
			86499666; --- r15 torso
			48474356; --- r6 torso
		};
		defaultface = "rbxasset://textures/face.png";
	};

	contentcache = {};

	debounceflagprefix = "h_";
}

--- equivalent to `TweenService:Create(object, TweenInfo.new(time, style(?=Enum.EasingStyle.Linear) ...), properties):Play()` \
--- `...[1]`: `Enum.EasingDirection` \
--- `...[2...]`: (remainder of `TweenInfo.new()` args)
function instanceh.tween(object: Instance, properties: {[string]: any}, time: number, style: Enum.EasingStyle?, ...)
	TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Linear, ...), properties):Play()
end

--- sets `i[primary content-related property] = content` \
--- `propertyscope` overrides `[primary content-related property]` \
--- returns `scope` and `value` in key-value pair form
function instanceh.setassetid(
	i: 
		| Animation
		| Decal
		| ImageButton
		| ImageHandleAdornment
		| ImageLabel
		| MeshPart
		| ParticleEmitter
		| Sound
		| SpecialMesh
		| Texture,
	content: string|number|Content?,
	propertyscope: string?
)
	if type(content) == "number" then
		content = Content.fromAssetId(content)
	elseif type(content) == "string" then
		content = Content.fromUri(content)
	else
		content = content or Content.none
	end
	assert(content)
	assert(typeof(content) == "Content")

	local scope, value = nil, nil::any
	
	if i:IsA("Animation") then
		scope = propertyscope or "AnimationId"
		value = content.Uri or ""
	elseif i:IsA("Decal") then
		scope = propertyscope or "TextureContent"
		value = content
	elseif i:IsA("ImageButton") then
		scope = propertyscope or "ImageContent"
		value = content
	elseif i:IsA("ImageHandleAdornment") then
		scope = propertyscope or "Image"
		value = content.Uri or ""
	elseif i:IsA("ImageLabel") then
		scope = propertyscope or "ImageContent"
		value = content
	elseif i:IsA("MeshPart") then
		scope = propertyscope or "MeshContent"
		value = content
	elseif i:IsA("ParticleEmitter") then
		scope = propertyscope or "Texture"
		value = content.Uri or ""
	elseif i:IsA("Sound") then
		scope = propertyscope or "AudioContent"
		value = content
	elseif i:IsA("SpecialMesh") then
		scope = propertyscope or "MeshId"
		value = content.Uri or ""
	elseif i:IsA("Texture") then
		scope = propertyscope or "TextureContent"
		value = content
	else
		error(string.format("no case for instance %s", i.ClassName))
	end

	assert(type(scope) == "string")
	assert(value ~= nil)

	--- today we're counting down our top 10 semicolons
	;(i::any)[scope] = value

	return scope, value
end

--- applies attribute debounce to instance, returning true if debounce passes \
--- if `time` is nil, the debounce attribute is reset and the function will return true
function instanceh.debounce(thing: Instance, name: string, now: number?, time: number?)
	if time then
		assert(now, "'now' must be passed if time ~= nil")
		local later = thing:GetAttribute(instanceh.debounceflagprefix .. name)
		later = type(later) == "number" and later or 0

		if later < now then
			thing:SetAttribute(instanceh.debounceflagprefix .. name, now + time)

			return true
		else
			return false
		end
	else
		thing:SetAttribute(instanceh.debounceflagprefix .. name, nil)
		return true
	end
end

--- `fov(?=70)` \
--- `name(?="Camera")`
function instanceh.camera(cframe: CFrame, fov: number?, name: string?)
	local camera = Instance.new("Camera")
	camera.CFrame = cframe
	camera.Focus = cframe
	camera.FieldOfView = fov or 70
	camera.Name = name or "Camera"
	camera.Parent = workspace

	return camera
end

--- welds b to a at offset \
--- `a`: "root" part \
--- `b`: "loose" part \
--- `offset: (?=CFrame.identity)`: `b.CFrame = a.CFrame * offset` \
--- `force:` `b.CFrame = force`
function instanceh.weldconstraint(a: BasePart, b: BasePart, offset: CFrame?, force: CFrame?)
	local weld = Instance.new("WeldConstraint")
	if force then
		b.CFrame = force
	else
		b.CFrame = a.CFrame * (offset or CFrame.identity)
	end
	weld.Part0 = b
	weld.Part1 = a
	weld.Parent = b

	return weld
end

local function nextequalizer(config: {["low"|"mid"|"high"]: {number}})
	local equalizersoundeffect = Instance.new("EqualizerSoundEffect")

	local high, mid, low = config.high, config.mid, config.low
	equalizersoundeffect.HighGain = random:NextNumber(high[1], high[2])
	equalizersoundeffect.MidGain = random:NextNumber(mid[1], mid[2])
	equalizersoundeffect.LowGain = random:NextNumber(low[1], low[2])

	return equalizersoundeffect
end

--- emits sound at optional position or instance
function instanceh.sound(sound: Sound, at: (Vector3|Instance)?, playbackspeed: number?, timeposition: number?, equalizerconfig: {["low"|"mid"|"high"]: {number}}?)
	local attachment = Instance.new("Attachment")
	attachment.Name = sound.Name .. "Attachment"
	attachment.Parent = workspace.Terrain
	
	local newsound = sound:Clone()
	newsound.PlaybackSpeed = playbackspeed or 1
	newsound.TimePosition = timeposition or 0

	if typeof(at) == "Instance" then
		if at:IsA("BasePart") then
			attachment.Parent = at
		elseif at:IsA("Model") then
			attachment.Parent = at.PrimaryPart
		end
		newsound.Parent = attachment
	elseif typeof(at) == "Vector3" then
		newsound.Parent = attachment
		attachment.CFrame = CFrame.new(at)
	else
		newsound.Parent = script
		attachment.Parent = script
	end

	if equalizerconfig then
		nextequalizer(equalizerconfig).Parent = newsound
	end
	
	newsound:Play()

	newsound.Ended:Once(function()
		newsound:Destroy()
		attachment:Destroy()
	end)
	
	return newsound
end

--- type describing handleadornment class
type adornmentsupertype = {
	adornee: PVInstance?;
	adorncullingmode: Enum.AdornCullingMode?;
	sizerelativeoffset: Vector3?;
	zindex: number?;

	color: Color3?;
	transparency: number?;
	shading: Enum.AdornShading?;
	visible: boolean?;

	parent: Instance?;

	size: Vector2|Vector3|number?;
	radius: number?;
	innerradius: number?;
	height: number?;
	hollow: boolean?;
	angle: number?;
	image: string?;
	sides: number?;
}

type adornmenttransformsupertype = {
	adornee: {PVInstance}?;
	adorncullingmode: {Enum.AdornCullingMode}?;
	sizerelativeoffset: {Vector3}?;
	zindex: {number}?;

	color: {Color3}?;
	transparency: {number}?;
	shading: {Enum.AdornShading}?;
	visible: {boolean}?;

	parent: {Instance}?;

	size: {Vector2|Vector3|number}?;
	radius: {number}?;
	innerradius: {number}?;
	height: {number}?;
	hollow: {boolean}?;
	angle: {number}?;
	image: {string}?;
	sides: {number}?;

	time: number;
	destroy: boolean;
}

--- sets adornment base properties
local function setadornmentbaseproperties(adornment: HandleAdornment, a: {at: CFrame|Vector3} & adornmentsupertype)
	if a.adorncullingmode ~= nil then
		adornment.AdornCullingMode = a.adorncullingmode
	end
	if a.sizerelativeoffset ~= nil then
		adornment.SizeRelativeOffset = a.sizerelativeoffset
	end
	if a.zindex ~= nil then
		adornment.ZIndex = a.zindex
	end

	if a.color ~= nil then
		adornment.Color3 = a.color
	end
	if a.transparency ~= nil then
		adornment.Transparency = a.transparency
	end
	if a.shading ~= nil then
		(adornment::any).Shading = a.shading
	end
	if a.visible ~= nil then
		adornment.Visible = a.visible
	end
	
	local at = a.at
	if typeof(at) == "Vector3" then
		adornment.CFrame = CFrame.new(at)
	elseif typeof(at) == "CFrame" then
		adornment.CFrame = at
	else
		warn(string.format("could not place adornment; expected vector3 or cframe, got %s", typeof(at)))
		adornment.CFrame = CFrame.identity
	end

	--- class-specific
	if adornment:IsA("BoxHandleAdornment") then
		if typeof(a.size) == "Vector3" then
			adornment.Size = a.size
		end
	elseif adornment:IsA("ConeHandleAdornment") then
		if a.radius ~= nil then
			adornment.Radius = a.radius
		end
		if a.height ~= nil then
			adornment.Height = a.height
		end
		if a.hollow ~= nil then
			adornment.Hollow = a.hollow
		end
	elseif adornment:IsA("CylinderHandleAdornment") then
		if a.angle ~= nil then
			adornment.Angle = a.angle
		end
		if a.radius ~= nil then
			adornment.Radius = a.radius
		end
		if a.innerradius ~= nil then
			adornment.InnerRadius = a.innerradius
		end
		if a.height ~= nil then
			adornment.Height = a.height
		end
	elseif adornment:IsA("ImageHandleAdornment") then
		if a.image ~= nil then
			adornment.Image = a.image
		end
		if typeof(a.size) == "Vector2" then
			adornment.Size = a.size
		end
	elseif adornment:IsA("PyramidHandleAdornment") then
		if a.height ~= nil then
			adornment.Height = a.height
		end
		if a.sides ~= nil then
			adornment.Sides = a.sides
		end
		if typeof(a.size) == "number" then
			adornment.Size = a.size
		end
	elseif adornment:IsA("SphereHandleAdornment") then
		if a.radius ~= nil then
			adornment.Radius = a.radius
		end
	else
		warn(string.format("unaccounted class '%s'", adornment.ClassName))
	end

	adornment.Adornee = a.adornee or workspace.Terrain
	adornment.Parent = a.parent or workspace.Terrain
end

--- returns \
--- `a` initial properties \
--- `b` target properties \
--- `time` tween time \
--- `destroy` destroy after tween (?=true)
local function createab(params: {[string]: any})
	local a = {}
	local b = {}
	for k, v in params do
		if type(v) == "table" then
			local avalue = v[1]
			if avalue ~= nil then
				a[k] = avalue::any
			end
			local bvalue = v[2]
			if bvalue ~= nil then
				b[k] = bvalue::any
			end
		end
	end

	return a, b, params.time::number, if params.destroy == nil then true else params.destroy == true
end

--- instantiates and optionally-transforms a `BoxHandleAdornment`
function instanceh.boxhandleadornment(params: adornmenttransformsupertype)
	local adornment = Instance.new("BoxHandleAdornment")
	local a, b, time, destroy = createab(params::any)

	setadornmentbaseproperties(adornment, a)

	if next(b) ~= nil then
		local to = b.at
		instanceh.tween(adornment, {
			Size = b.size;
			---
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Shading = b.shading;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;

			Parent = b.parent;
		}, time)
	end

	if destroy then
		task.delay(time, adornment.Destroy, adornment)
	end

	return adornment
end

--- instantiates and optionally-transforms a `ConeHandleAdornment`
function instanceh.conehandleadornment(params: adornmenttransformsupertype)
	local adornment = Instance.new("ConeHandleAdornment")
	local a, b, time, destroy = createab(params::any)

	setadornmentbaseproperties(adornment, a)

	if next(b) ~= nil then
		local to = b.at
		instanceh.tween(adornment, {
			Radius = b.radius;
			Height = b.height;
			Hollow = b.hollow;
			---
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Shading = b.shading;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;

			Parent = b.parent;
		}, time)
	end

	if destroy then
		task.delay(time, adornment.Destroy, adornment)
	end

	return adornment
end

--- instantiates and optionally-transforms a `CylinderHandleAdornment`
function instanceh.cylinderhandleadornment(params: adornmenttransformsupertype)
	local adornment = Instance.new("CylinderHandleAdornment")
	local a, b, time, destroy = createab(params::any)

	setadornmentbaseproperties(adornment, a)

	if next(b) ~= nil then
		local to = b.at
		instanceh.tween(adornment, {
			Radius = b.radius;
			InnerRadius = b.innerradius;
			Height = b.height;
			Angle = b.angle;
			---
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Shading = b.shading;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;

			Parent = b.parent;
		}, time)
	end

	if destroy then
		task.delay(time, adornment.Destroy, adornment)
	end

	return adornment
end

--- instantiates and optionally-transforms a `ImageHandleAdornment`
function instanceh.imagehandleadornment(params: adornmenttransformsupertype)
	local adornment = Instance.new("ImageHandleAdornment")
	local a, b, time, destroy = createab(params::any)

	setadornmentbaseproperties(adornment, a)

	if next(b) ~= nil then
		local contentscope = instanceh.setassetid(adornment, a.image)

		local to = b.at
		instanceh.tween(adornment, {
			Size = b.size;
			[contentscope] = b.image and Content.fromUri(b.image) or nil;
			---
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Shading = b.shading;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;

			Parent = b.parent;
		}, time)
	end

	if destroy then
		task.delay(time, adornment.Destroy, adornment)
	end

	return adornment
end

--- instantiates and optionally-transforms a `PyramidHandleAdornment`
function instanceh.pyramidhandleadornment(params: adornmenttransformsupertype)
	local adornment = Instance.new("PyramidHandleAdornment")
	local a, b, time, destroy = createab(params::any)

	setadornmentbaseproperties(adornment, a)

	if next(b) ~= nil then
		local to = b.at
		instanceh.tween(adornment, {
			Sides = b.height;
			Size = b.size;
			Height = b.height;
			---
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Shading = b.shading;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;

			Parent = b.parent;
		}, time)
	end

	if destroy then
		task.delay(time, adornment.Destroy, adornment)
	end

	return adornment
end

--- instantiates and optionally-transforms a `SphereHandleAdornment`
function instanceh.spherehandleadornment(params: adornmenttransformsupertype)
	local adornment = Instance.new("SphereHandleAdornment")
	local a, b, time, destroy = createab(params::any)

	setadornmentbaseproperties(adornment, a)

	if next(b) ~= nil then
		local to = b.at
		instanceh.tween(adornment, {
			Radius = b.radius;
			---
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Shading = b.shading;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;

			Parent = b.parent;
		}, time)
	end

	if destroy then
		task.delay(time, adornment.Destroy, adornment)
	end

	return adornment
end

--- type describing light class
type lightsupertype = {
	brightness: number?;
	color: Color3?;
	enabled: boolean?;
	shadows: boolean?;
	
	parent: Instance?;

	range: number?;
	angle: number?;
	face: Enum.NormalId?;
}

type lighttransformsupertype = {
	brightness: {number}?;
	color: {Color3}?;
	enabled: {boolean}?;
	shadows: {boolean}?;
	
	parent: {Instance}?;

	range: {number}?;
	angle: {number}?;
	face: {Enum.NormalId}?;
	
	time: number;
	destroy: boolean;
}

--- sets light base properties
local function setlightbaseproperties(light: Light, a: {at: CFrame|Vector3} & lightsupertype)
	if a.brightness then
		light.Brightness = a.brightness
	end
	if a.color then
		light.Color = a.color
	end
	if a.enabled ~= nil then
		light.Enabled = a.enabled
	end
	if a.shadows ~= nil then
		light.Shadows = a.shadows
	end

	if light:IsA("PointLight") then
		if a.range ~= nil then
			light.Range = a.range
		end
	elseif light:IsA("SpotLight") then
		if a.range ~= nil then
			light.Range = a.range
		end
		if a.angle ~= nil then
			light.Angle = a.angle
		end
		if a.face ~= nil then
			light.Face = a.face
		end
	elseif light:IsA("SurfaceLight") then
		if a.range ~= nil then
			light.Range = a.range
		end
		if a.angle ~= nil then
			light.Angle = a.angle
		end
		if a.face ~= nil then
			light.Face = a.face
		end
	else
		warn(string.format("unaccounted class '%s'", light.ClassName))
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = light.ClassName .. "Attachment"
	attachment.Parent = a.parent or workspace.Terrain
	
	local at = a.at
	if typeof(at) == "Vector3" then
		attachment.CFrame = CFrame.new(at)
	elseif typeof(at) == "CFrame" then
		attachment.CFrame = at
	else
		warn(string.format("could not place light attachment; expected vector3 or cframe, got %s", typeof(at)))
		attachment.CFrame = CFrame.identity
	end

	light.Parent = attachment

	return attachment
end

--- instantiates and optionally-transforms a `PointLight` \
--- `CFrame` and `Parent` properties are applied to an `Attachment`
function instanceh.pointlight(params: lighttransformsupertype)
	local light = Instance.new("PointLight")
	local a, b, time, destroy = createab(params::any)

	local attachment = setlightbaseproperties(light, a)

	if next(b) ~= nil then
		local to = b.at

		instanceh.tween(attachment, {
			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;
			Parent = b.parent;
		}, time)

		instanceh.tween(light, {
			Range = b.range;
			---
			Brightness = b.brightness;
			Color = b.color;
			Enabled = b.enabled;
			Shadows = b.shadows;
		}, time)
	end

	if destroy then
		task.delay(time, light.Destroy, light)
	end

	return light, attachment
end

--- instantiates and optionally-transforms a `SpotLight` \
--- `CFrame` and `Parent` properties are applied to an `Attachment`
function instanceh.spotlight(params: lighttransformsupertype)
	local light = Instance.new("SpotLight")
	local a, b, time, destroy = createab(params::any)

	local attachment = setlightbaseproperties(light, a)

	if next(b) ~= nil then
		local to = b.at

		instanceh.tween(attachment, {
			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;
			Parent = b.parent;
		}, time)

		instanceh.tween(light, {
			Range = b.range;
			Face = b.face;
			Angle = b.angle;
			---
			Brightness = b.brightness;
			Color = b.color;
			Enabled = b.enabled;
			Shadows = b.shadows;
		}, time)
	end

	if destroy then
		task.delay(time, light.Destroy, light)
	end

	return light, attachment
end

--- instantiates and optionally-transforms a `SurfaceLight` \
--- `CFrame` and `Parent` properties are applied to an `Attachment`
function instanceh.surfacelight(params: lighttransformsupertype)
	local light = Instance.new("SurfaceLight")
	local a, b, time, destroy = createab(params::any)

	local attachment = setlightbaseproperties(light, a)

	if next(b) ~= nil then
		local to = b.at

		instanceh.tween(attachment, {
			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;
			Parent = b.parent;
		}, time)

		instanceh.tween(light, {
			Range = b.range;
			Face = b.face;
			Angle = b.angle;
			---
			Brightness = b.brightness;
			Color = b.color;
			Enabled = b.enabled;
			Shadows = b.shadows;
		}, time)
	end

	if destroy then
		task.delay(time, light.Destroy, light)
	end

	return light, attachment
end

--- instantiates a minimal static `Part`
function instanceh.basepart(at: Vector3|CFrame, parent: Instance?)
	local basepart = Instance.new("Part")
	basepart.CastShadow = false
	basepart.Transparency = 1
	basepart.Anchored = true
	basepart.CanCollide = false
	basepart.CanQuery = false
	basepart.CanTouch = false
	basepart.Massless = true
	basepart.Size = Vector3.one

	if typeof(at) == "Vector3" then
		basepart.Position = at
	elseif typeof(at) == "CFrame" then
		basepart.CFrame = at
	end
	
	basepart.Parent = parent or workspace

	return basepart
end

--- sets collision group of baseparts under target
function instanceh.setcollisiongroup(target: Instance, collisiongroup: string)
	for _, thing in target:QueryDescendants("BasePart") do
		if thing:IsA("BasePart") then
			thing.CollisionGroup = collisiongroup
		end
	end
end

--- equivalent to `PhysicsService:RegisterCollisionGroup(name)`
function instanceh.registercollisiongroup(name: string)
	PhysicsService:RegisterCollisionGroup(name)
end

--- bulk register-and-set-collidable `PhysicsService` collision groups
function instanceh.collisiongroupbulksetcollidable(t: {[string]: {[string]: boolean}})
	assert(isserver, "instanceh.registercollisiongroups() can only be called on server")

	--- "both collision groups must be registered"
	for name in t do
		if PhysicsService:IsCollisionGroupRegistered(name) then
			--- already registered
		else
			PhysicsService:RegisterCollisionGroup(name)
		end
	end

	for aname, v in t do
		for bname, collidable in v do
			PhysicsService:CollisionGroupSetCollidable(aname, bname, collidable)
		end
	end
end

--- creates an `Animation` instance with its `AnimationId` property set to `id`
function instanceh.createanimation(id: number|string|Content?)
	local a = Instance.new("Animation")
	instanceh.setassetid(a, id)
	a.Parent = script

	return a
end

--- plays animation \
--- `fadetime?=1/24`
function instanceh.playanimation(animator: Animator, animation: Animation, priority: Enum.AnimationPriority?, speed: number?, fadetime: number?, weight: number?)
	local animtrack = animator:LoadAnimation(animation)
	animtrack:Play(fadetime or 1/24, weight, speed)
	animtrack.Priority = priority or Enum.AnimationPriority.Action

	return animtrack
end

--- adjusts animationtrack speed to fit *played* time \
--- `speed = tracklength / time`
function instanceh.animationfitplayed(animtrack: AnimationTrack, time: number)
	animtrack:AdjustSpeed(animtrack.Length / time)
end

--- adjusts animationtrack speed to fit *remaining* time \
--- `speed = (tracklength - tracktime) / time`
function instanceh.animationfitremaining(animtrack: AnimationTrack, time: number)
	animtrack:AdjustSpeed((animtrack.Length - animtrack.TimePosition) / time)
end

--- creates an animation controller
function instanceh.createanimationcontroller(animator: Animator)
	return {
		animator = animator;
		priority = Enum.AnimationPriority.Action;
		fadetime = 1/24;

		animationtrack = nil :: AnimationTrack?;

		keyframereached = nil :: (keyframe: string) -> ()?;
		keyframereachedconnection = nil :: RBXScriptConnection?;
	}
end

--- plays animation wrt animationcontroller
function instanceh.animationcontrollerplay(ac: typeof(instanceh.createanimationcontroller(...)), animation: Animation?, priority: Enum.AnimationPriority?, speed: number?, fadetime: number?, weight: number?)
	if ac.keyframereachedconnection then
		ac.keyframereachedconnection:Disconnect()
		ac.keyframereachedconnection = nil
	end
	if ac.animationtrack then
		ac.animationtrack:Stop(fadetime or ac.fadetime)
		ac.animationtrack = nil
	end

	if animation ~= nil then
		local animtrack = ac.animator:LoadAnimation(animation)
		ac.animationtrack = animtrack
		ac.keyframereachedconnection = animtrack.KeyframeReached:Connect(function(...)
			if ac.keyframereached then
				ac.keyframereached(...)
			end
		end)

		animtrack:Play(fadetime or ac.fadetime, weight, speed)
		animtrack.Priority = priority or ac.priority
	end

	return ac.animationtrack
end

--- returns `true` if animationcontroller's animationtrack can be overridden by a mismatching animation
function instanceh.animationcontrollerevaluate(ac: typeof(instanceh.createanimationcontroller(...)), animation: Animation?)
	local animtrack = ac.animationtrack

	if animtrack == nil then
		return true
	else
		return animtrack.Animation ~= animation
	end
end

--- return `true` if `thing` has a `LocalTransparencyModifier` property
function instanceh.istransparencymodifiable(thing: Instance)
	if thing:IsA("BasePart") then
		return true
	elseif thing:IsA("Beam") then
		return true
	elseif thing:IsA("Decal") then
		return true
	elseif thing:IsA("Explosion") then
		return true
	elseif thing:IsA("Fire") then
		return true
	elseif thing:IsA("ParticleEmitter") then
		return true
	elseif thing:IsA("Smoke") then
		return true
	elseif thing:IsA("Sparkles") then
		return true
	elseif thing:IsA("Trail") then
		return true
		
		--- exceptions
	elseif thing:FindFirstAncestorOfClass("Tool") then
		return false
	elseif thing:IsA("HandleAdornment") then
		return true
	end

	return false
end

--- creates a transparency controller using localtransparencymodifier
function instanceh.createtransparencycontroller(thing: Instance)
	local things = thing:QueryDescendants("Instance")
	local controller = {
		rig = thing;

		targettransparency = 0;
		realtransparency = 0;

		disconnected = false;
		cache = table.create(#things)::{Instance};
		descendantadded = nil :: RBXScriptConnection?;
		descendantremoving = nil :: RBXScriptConnection?;
	}

	for _, thisthing in things do
		if instanceh.istransparencymodifiable(thisthing) then
			table.insert(controller.cache, thisthing)
		end
	end

	controller.descendantadded = thing.DescendantAdded:Connect(function(thisthing)
		if instanceh.istransparencymodifiable(thisthing) and not table.find(controller.cache, thisthing) then
			table.insert(controller.cache, thisthing)
			if thisthing:IsA("HandleAdornment") then
				thisthing.Visible = controller.realtransparency ~= 1
			else
				(thisthing::any).LocalTransparencyModifier = controller.realtransparency
			end
		end
	end)
	controller.descendantremoving = thing.DescendantRemoving:Connect(function(thisthing)
		if instanceh.istransparencymodifiable(thisthing) then
			table.remove(controller.cache, table.find(controller.cache, thisthing) or 0)
		end
	end)

	controller.Disconnect = function()
		controller.disconnected = true
		if controller.descendantadded then
			controller.descendantadded:Disconnect()
		end
		if controller.descendantremoving then
			controller.descendantremoving:Disconnect()
		end

		table.clear(controller)
	end

	return controller
end

--- refreshes `LocalTransparencyModifier` of instances associated with `TransparencyController`
function instanceh.transparencycontrollerstep(tc: typeof(instanceh.createtransparencycontroller(...)))
	if tc.disconnected then return false end

	local target = tc.targettransparency
	if target ~= tc.realtransparency then
		for _, thing in tc.cache do
			if thing:IsA("HandleAdornment") then
				thing.Visible = target ~= 1
			else
				(thing::any).LocalTransparencyModifier = target
			end
		end
		tc.realtransparency = target

		return true
	end

	return false
end

--- returns player from \
--- `Player player` \
--- `Instance player character` \
--- `number player userid` \
--- `string player name`
function instanceh.resolveplayer(player: Player|number|string|Instance): Player?
	if type(player) == "number" then
		return Players:GetPlayerByUserId(player)
	elseif type(player) == "string" then
		return Players:QueryDescendants(">#" .. player)[1]::Player?
	elseif typeof(player) == "Instance" then
		if player:IsA("Player") then
			return player
		elseif player:IsA("Model") then
			return Players:GetPlayerFromCharacter(player)
		end
	end

	return nil
end

--- encodes data type into an appearance description table (datastore-friendly)
function instanceh.createappearancedescription(t: {[string]: any} | HumanoidDescription | Player | number | string)
	local appearancemap = instanceh.appearancemap
	
	local result = {}::{[string]: any}

	if type(t) == "table" then
		for k, v in t do
			if k == "Accessories" then
				local split = string.split(v, ",")
				local array = table.create(#split)
				for _, stringid in split do
					table.insert(array, tonumber(stringid))
				end
	
				result[k] = array
	
				continue
			end
			if typeof(v) == "Color3" then
				v = v:ToHex()
			end
			
			result[k] = v
		end
	elseif type(t) == "string" then
		local userid = Players:GetUserIdFromNameAsync(t)
		if userid < 1 then return instanceh.emptydescription() end

		return instanceh.createappearancedescription(userid)
	elseif type(t) == "number" then
		if t < 1 then return instanceh.emptydescription() end

		return instanceh.createappearancedescription(Players:GetHumanoidDescriptionFromUserIdAsync(t))
	elseif typeof(t) == "Instance" then
		if t:IsA("HumanoidDescription") then
			do --- accessories
				local accessories = {}
	
				for _, accessorydescription in t:QueryDescendants("AccessoryDescription") do
					table.insert(accessories, accessorydescription.AssetId)
				end
	
				result.Accessories = accessories
			end
	
			do --- body colors
				for _, bodypartdescription in t:QueryDescendants("BodyPartDescription") do
					result[bodypartdescription.BodyPart.Name .. "Color"] = bodypartdescription.Color:ToHex()
				end
			end
	
			do --- body parts
				for _, property in appearancemap.bodypartproperties do
					local value = (t::any)[property] :: number
	
					if (property == "Face")
					and (value == 0)
					then
						result[property] = appearancemap.defaultface
						continue
					end

					if property == "Face" then
						local insertmodel = InsertService:LoadAsset(value)
						local thing = insertmodel:FindFirstChildOfClass("Decal")
						if thing then
							result[property] = thing.Texture
							
							insertmodel:Destroy()
						end
						continue
					end
	
					result[property] = "rbxassetid://" .. tostring(value)
				end
			end

			do --- clothing
				for _, property in appearancemap.clothingproperties do
					local value = (t::any)[property] :: number
					if value == 0 then
						result[property] = "rbxassetid://0"
						continue
					end

					local insertmodel = InsertService:LoadAsset(value)
					local thing = insertmodel:FindFirstChildOfClass("Shirt") or insertmodel:FindFirstChildOfClass("Pants") or insertmodel:FindFirstChildOfClass("ShirtGraphic")
					if thing then
						if thing:IsA("Shirt") then
							result[property] = "rbxassetid://" .. (string.match(thing.ShirtTemplate, "%d+") or "0")
						elseif thing:IsA("Pants") then
							result[property] = "rbxassetid://" .. (string.match(thing.PantsTemplate, "%d+") or "0")
						elseif thing:IsA("ShirtGraphic") then
							result[property] = "rbxassetid://" .. (string.match(thing.Graphic, "%d+") or "0")
						end

						insertmodel:Destroy()
					else
						warn("shirt or pants or shirtgraphic not found")
					end
				end
			end
	
			do --- female torso
				result.GirlTorso = table.find(appearancemap.girltorsos, t.Torso) ~= nil
			end
		elseif t:IsA("Player") then
			if t.UserId < 1 then
				return instanceh.emptydescription()
			end

			return instanceh.createappearancedescription(Players:GetHumanoidDescriptionFromUserIdAsync(t.UserId))
		end
	end

	return result
end

--- decodes appearance description table
function instanceh.decodeappearancedescription(a: typeof(instanceh.createappearancedescription(...)))
	local appearancemap = instanceh.appearancemap

	local result = {}::{[string]: any}

	for k, v in a::{[string]: any} do
		if table.find(appearancemap.bodycolorproperties, k) or table.find(appearancemap.clothingcolorproperties, k) then
			local num = tonumber(v, 16)
			if num and num <= 16777215 then
				result[k] = Color3.fromHex(v)

				continue
			end
		end

		result[k] = v
	end

	return result
end

--- attaches basepart to instance \
--- assumes that both basepart and instance have an attachment instance with matching names
function instanceh.attach(instance: Instance, basepart: BasePart, parent: Instance?)
	local accessoryattachment = basepart:FindFirstChildOfClass("Attachment")
	if not accessoryattachment then return false end

	local rigattachment = instanceh.findfirstattachment(instance, accessoryattachment.Name)
	if not rigattachment then return false end

	basepart.Parent = parent or instance

	for _, rigidconstraint in instance:QueryDescendants(">RigidConstraint") do
		rigidconstraint.Attachment0 = nil
		rigidconstraint.Attachment1 = nil
		rigidconstraint:Destroy()
	end

	local constraint = Instance.new("RigidConstraint")
	constraint.Attachment0 = rigattachment
	constraint.Attachment1 = accessoryattachment
	constraint.Parent = basepart

	return true
end

--- returns attachment in instance
function instanceh.findfirstattachment(instance: Instance, name: string)
	return (instance:QueryDescendants(string.format("[ClassName = Attachment][Name = %s]", name))[1]::any)::Attachment?
end

--- returns an `AccessoryPart` from assetid (server-only), or an empty AccessoryPart if no assetid is provided
function instanceh.createaccessory(assetid: number?)
	if not assetid then
		local accessorypart = Instance.new("Part")
		accessorypart.CastShadow = true
		accessorypart.Material = Enum.Material.Plastic
		accessorypart.Transparency = 0
		accessorypart.Size = Vector3.one
		accessorypart.CFrame = CFrame.identity
		accessorypart.EnableFluidForces = false
		accessorypart.Anchored = false
		accessorypart.CanCollide = false
		accessorypart.CanQuery = false
		accessorypart.CanTouch = false
		accessorypart.Massless = true
		accessorypart.Name = "Accessory"
		accessorypart:SetAttribute(instanceh.accessoryflag, true)
		accessorypart.Parent = script

		local attachment = Instance.new("Attachment")
		attachment.Name = "HatAttachment"
		attachment.CFrame = CFrame.identity
		attachment.Parent = accessorypart

		local specialmesh = Instance.new("SpecialMesh")
		specialmesh.MeshType = Enum.MeshType.FileMesh
		specialmesh.Scale = Vector3.one
		specialmesh.Parent = accessorypart

		return accessorypart::BasePart
	end

	assert(isserver, "instanceh.createaccessory() can only be called on server (InsertService limitation T__T)")
	local asset = InsertService:LoadAsset(assetid)

	local accessory = asset:FindFirstChildOfClass("Accessory")
	assert(accessory)
	assert(accessory:IsA("Accessory"))

	--- :/
	local handle: any = accessory:FindFirstChild("Handle") or accessory:WaitForChild("Handle")
	assert(handle)
	assert(handle:IsA("BasePart"))

	local attachment = handle:FindFirstChildOfClass("Attachment")
	assert(attachment)
	assert(attachment:IsA("Attachment"))

	local accessorypart = Instance.new("Part")
	accessorypart.Name = tostring(assetid)
	accessorypart.Locked = false
	accessorypart.EnableFluidForces = false
	accessorypart.CanCollide = false
	accessorypart.CanTouch = false
	accessorypart.CanQuery = false
	accessorypart.Massless = true
	accessorypart.Anchored = false
	accessorypart.Position = Vector3.zero
	accessorypart.Size = Vector3.one
	accessorypart.Parent = script

	attachment.Parent = accessorypart

	if handle:IsA("MeshPart") then
		local specialmesh = Instance.new("SpecialMesh")
		specialmesh.MeshType = Enum.MeshType.FileMesh
		specialmesh.MeshId = handle.MeshContent.Uri
		specialmesh.TextureId = handle.TextureContent.Uri
		specialmesh.Scale = handle.Size / handle.MeshSize
		specialmesh.Parent = accessorypart

		accessorypart:SetAttribute(instanceh.accessoryoriginalsizeflag, handle.Size)
	else
		local specialmesh = handle:FindFirstChildOfClass("SpecialMesh")
		if specialmesh then
			specialmesh.Parent = accessorypart
		end
	end

	accessorypart:SetAttribute(instanceh.accessoryflag, true)

	asset:Destroy()

	return accessorypart
end

--- returns an empty appearance description
function instanceh.emptydescription()
	return {
		Accessories = table.create(0)::{number|string};
		Face = "rbxasset://textures/face.png";

		HeadColor = "a3a2a5";
		TorsoColor = "a3a2a5";
		LeftArmColor = "a3a2a5";
		LeftLegColor = "a3a2a5";
		RightArmColor = "a3a2a5";
		RightLegColor = "a3a2a5";

		Shirt = "rbxassetid://0";
		Pants = "rbxassetid://0";
		GraphicTShirt = "rbxassetid://0";

		GirlTorso = false;
	};
end

--- creates a mixtape
function instanceh.createmixtape(tracklist: {Sound})
	--- original volumes
	local volumes = table.create(#tracklist)::{number}
	for i, track in ipairs(tracklist) do
		table.insert(volumes, track.Volume)
		track.Volume = 0
	end
	
	return {
		track = 1;
		tracklist = tracklist;
		tracklooped = false;

		playbackspeed = 1;

		crossfadespeed = 2;
		fadeoutstart = 1;
		volumes = volumes;
	}
end

--- advances mixtape by `dt`
function instanceh.mixtapestep(m: typeof(instanceh.createmixtape(...)), dt: number)
	m.track = math.clamp(m.track, 1, #m.tracklist)

	for i, track in ipairs(m.tracklist) do
		track.PlaybackSpeed = m.playbackspeed
		local originalvolume = m.volumes[i]
		if i == m.track then
			--- play, fade in
			if track.TimePosition == 0 then
				if not track.IsPlaying then
					track:Play()
				end
			elseif track.TimePosition + m.fadeoutstart >= track.TimeLength then
				if m.tracklooped then
					--- nothing, wait for full finish
				else
					if not m.tracklist[m.track] then
						m.track = 1
					end
				end
			elseif track.TimePosition >= track.TimeLength then
				if m.tracklooped then
					m.track += 1
				else
					--- nothing
				end
			end
			
			if track.Volume ~= originalvolume then
				track.Volume = math.clamp(track.Volume + (dt * m.crossfadespeed), 0, originalvolume)
			end
		else
			--- fade out, eventually stop
			if track.Volume == 0 then
				track:Stop()
			else
				track.Volume = math.clamp(track.Volume - (dt * m.crossfadespeed), 0, originalvolume)
			end
		end
	end
end

--- `return pcall(contentprovider.PreloadAsync, contentprovider, assets, f)`
function instanceh.preloadasync(assets: {any}, f: ((contentstring: string, assetfetchstatus: Enum.AssetFetchStatus) -> ())?)
	return pcall(ContentProvider.PreloadAsync, ContentProvider, assets, f::any)
end

--- filters list of preload-able asset types \
--- *"...however these strings must correspond to image assets. Attempting to load non-image assets through the use of their content ID strings will result in failure."*
function instanceh.preloadable(a: any)
	local list = {} :: {any}

	if type(a) == "table" then
		for k, v in a do
			local r = instanceh.preloadable(v)
			table.move(r, 1, #r, #list + 1, list)
		end
	elseif type(a) == "string" then
		if string.find(a, "rbxassetid://") then
			table.insert(list, a)
		end
	elseif typeof(a) == "Content" then
		table.insert(list, a)
	elseif typeof(a) == "Instance" then
		if a:IsA("Decal") then --- things with an image component
			local id = a.Texture
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("Beam") then
			local id = a.Texture
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("ImageButton") then
			local id = a.Image
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("ImageHandleAdornment") then
			local id = a.Image
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("ImageLabel") then
			local id = a.Image
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("ParticleEmitter") then
			local id = a.Texture
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("Pants") then
			local id = a.PantsTemplate
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("Shirt") then
			local id = a.ShirtTemplate
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("Sky") then
			for _, id in {
				a.SkyboxBk;
				a.SkyboxDn;
				a.SkyboxFt;
				a.SkyboxLf;
				a.SkyboxRt;
				a.SkyboxUp;
			} do
				if id ~= "" then table.insert(list, id) end
			end
		elseif a:IsA("Texture") then
			local id = a.Texture
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("Trail") then
			local id = a.Texture
			if id ~= "" then table.insert(list, id) end
		elseif a:IsA("Animation") then --- as with a non-image component
			table.insert(list, a)
		elseif a:IsA("CharacterMesh") then
			table.insert(list, a)
		elseif a:IsA("MeshPart") then
			table.insert(list, a)
		elseif a:IsA("Sound") then
			table.insert(list, a)
		elseif a:IsA("SpecialMesh") then
			--- table.insert(list, a)
			local meshid = a.MeshId
			local textureid = a.TextureId
			if meshid ~= "" and not table.find(list, meshid) then table.insert(list, meshid) end
			if textureid ~= "" and not table.find(list, textureid) then table.insert(list, textureid) end
		end

		local r = instanceh.preloadable(a:QueryDescendants(">Instance"))
		table.move(r, 1, #r, #list + 1, list)
	end

	return list
end

return instanceh