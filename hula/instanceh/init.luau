--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--- ### instanceh.luau
---
--- Instance library extension
local instanceh = {
	accessoryflag = "h_accessory";
	appearanceflag = "h_appearancedescription";
	appearancemap = {
		accessoryproperties = {
			"BackAccessory";
			"FaceAccessory";
			"FrontAccessory";
			"HairAccessory";
			"HatAccessory";
			"NeckAccessory";
			"ShouldersAccessory";
			"WaistAccessory";
		};
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
	if type(content) == "number" or type(content) == "string" then
		content = instanceh.content(content)
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

--- converts uri or assetid into `Content` form \
--- numeric `uriorassetid` is prefixed with `"rbxassetid://"` \
--- `Content` with `uriorassetid` is cached for faster re-access \
--- \
--- `uriorassetid == "" -> Content.none` \
--- `uriorassetid == nil -> nil`
function instanceh.content(uriorassetid: string|number?): Content?
	if type(uriorassetid) == "string" then
		if uriorassetid == "" then
			return Content.none
		else
			local content = instanceh.contentcache[uriorassetid]
			if not content then
				instanceh.contentcache[uriorassetid] = Content.fromUri(uriorassetid)
				content = instanceh.contentcache[uriorassetid]
			end

			return content::Content
		end
	elseif type(uriorassetid) == "number" then
		return instanceh.content("rbxassetid://" .. tostring(uriorassetid))
	elseif type(uriorassetid) == "nil" then
		return nil
	else
		error(string.format("expected uriorassetid to be string or number, got %s", type(uriorassetid)))
	end
end

--- takes variants and caches their `Content` equivalent for faster re-access by `instanceh.content(...)`
function instanceh.contentaddtocache(list: {number|string|Content})
	for _, c in list do
		if typeof(c) ~= "Content" then
			instanceh.content(c)
		else
			local uri = c.Uri
			if uri then
				if not instanceh.contentcache[uri] then
					instanceh.contentcache[uri] = c
				end
			end
		end
	end
end

--- applies attribute debounce to instance, returning true if debounce passes \
--- if `time` is nil, the debounce attribute is reset and the function will return true
function instanceh.debounce(thing: Instance, name: string, now: number?, time: number?)
	if time then
		assert(now, "'now' must be passed if time ~= nil")
		local later = thing:GetAttribute(instanceh.debounceflagprefix .. name) or 0
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

--- emits sound at optional position or instance
function instanceh.sound(sound: Sound, at: (Vector3|Instance)?, playbackspeed: number?, timeposition: number?)
	if typeof(at) == "Instance" then
		local real: BasePart? = nil
		if at:IsA("BasePart") then
			real = at
		elseif at:IsA("Model") then
			real = at.PrimaryPart
		else
			assert(`{at.ClassName} {at}`)
		end
		assert(real)

		local newsound = sound:Clone()
		newsound.Parent = real
		newsound.PlaybackSpeed = playbackspeed or 1
		newsound.TimePosition = timeposition or 0
		newsound.PlayOnRemove = false

		newsound.Stopped:Once(function()
			newsound:Destroy()
		end)
		newsound.Ended:Once(function()
			newsound:Destroy()
		end)

		newsound:Play()

		return newsound
	elseif typeof(at) == "Vector3" then
		local newpart = Instance.new("Part")
		newpart.CastShadow = false
		newpart.Transparency = 1
		newpart.Anchored = true
		newpart.CanCollide = false
		newpart.CanQuery = false
		newpart.CanTouch = false
		newpart.Massless = true
		newpart.Size = Vector3.one
		newpart.Position = at
		newpart.Parent = workspace

		local newsound = sound:Clone()
		newsound.Parent = newpart
		newsound.PlaybackSpeed = playbackspeed or 1
		newsound.TimePosition = timeposition or 0
		newsound.PlayOnRemove = true
		
		newpart:Destroy()

		return newsound
	else
		local newsound = sound:Clone()
		newsound.Parent = script
		newsound.PlaybackSpeed = playbackspeed or 1
		newsound.TimePosition = timeposition or 0
		newsound.PlayOnRemove = true

		newsound:Destroy()

		return newsound
	end
end

--- type describing handleadornment class
type adornmentbase = {
	adornee: PVInstance?;
	adorncullingmode: Enum.AdornCullingMode?;
	sizerelativeoffset: Vector3?;
	alwaysontop: boolean?;
	zindex: number?;

	color: Color3?;
	transparency: number?;
	visible: boolean?;

	parent: Instance?;
}

--- type describing handleadornment transform (tween) args
type adornmenttransform = {
	time: number;
	destroy: boolean;
}

--- sets adornment base properties
local function setadornmentbaseproperties(adornment: HandleAdornment, a: adornmentbase & {at: CFrame|Vector3?})
	if a.adornee ~= nil then
		adornment.Adornee = a.adornee
	end
	if a.adorncullingmode then
		adornment.AdornCullingMode = a.adorncullingmode
	end
	if a.sizerelativeoffset then
		adornment.SizeRelativeOffset = a.sizerelativeoffset
	end
	if a.alwaysontop ~= nil then
		adornment.AlwaysOnTop = a.alwaysontop
	end
	if a.zindex then
		adornment.ZIndex = a.zindex
	end

	if a.color then
		adornment.Color3 = a.color
	end
	if a.transparency then
		adornment.Transparency = a.transparency
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

	adornment.Parent = a.parent or workspace
end

--- instantiates a `BoxHandleAdornment` with initial properties `a` and optionally-transforms it toward goal `b`
function instanceh.boxhandleadornment(
	a: {
		at: CFrame|Vector3;

		size: Vector3;
	} & adornmentbase,
	b: ({
		at: CFrame|Vector3?;

		size: Vector3?;
	} & adornmentbase & adornmenttransform)?
)
	local adornment = Instance.new("BoxHandleAdornment")
	setadornmentbaseproperties(adornment, a)
	
	adornment.Size = a.size

	if b then
		local to = b.at
		local goal = {
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			AlwaysOnTop = b.alwaysontop;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;
			
			Size = b.size;

			Parent = b.parent;
		}

		if next(goal) ~= nil then
			instanceh.tween(adornment, goal, b.time)
		end

		if b.destroy then
			task.delay(b.time, adornment.Destroy, adornment)
		end
	end

	return adornment
end

--- instantiates a `ConeHandleAdornment` with initial properties `a` and optionally-transforms it toward goal `b`
function instanceh.conehandleadornment(
	a: {
		at: CFrame|Vector3;

		radius: number;
		height: number;
	} & adornmentbase,
	b: ({
		at: CFrame|Vector3?;

		radius: number?;
		height: number?;
	} & adornmentbase & adornmenttransform)?
)
	local adornment = Instance.new("ConeHandleAdornment")
	setadornmentbaseproperties(adornment, a)
	
	adornment.Radius = a.radius
	adornment.Height = a.height

	if b then
		local to = b.at
		local goal = {
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			AlwaysOnTop = b.alwaysontop;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;
			
			Radius = b.radius;
			Height = b.height;

			Parent = b.parent;
		}

		if next(goal) ~= nil then
			instanceh.tween(adornment, goal, b.time)
		end

		if b.destroy then
			task.delay(b.time, adornment.Destroy, adornment)
		end
	end

	return adornment
end

--- instantiates a `PyramidHandleAdornment` with initial properties `a` and optionally-transforms it toward goal `b`
function instanceh.pyramidhandleadornment(
	a: {
		at: CFrame|Vector3;

		sides: number;
		size: number;
		height: number;
	} & adornmentbase,
	b: ({
		at: CFrame|Vector3?;

		sides: number?;
		size: number?;
		height: number?;
	} & adornmentbase & adornmenttransform)?
)
	local adornment = Instance.new("PyramidHandleAdornment")
	setadornmentbaseproperties(adornment, a)
	
	adornment.Sides = a.sides
	adornment.Size = a.size
	adornment.Height = a.height

	if b then
		local to = b.at
		local goal = {
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			AlwaysOnTop = b.alwaysontop;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;
			
			Sides = b.height;
			Size = b.size;
			Height = b.height;

			Parent = b.parent;
		}

		if next(goal) ~= nil then
			instanceh.tween(adornment, goal, b.time)
		end

		if b.destroy then
			task.delay(b.time, adornment.Destroy, adornment)
		end
	end

	return adornment
end

--- instantiates a `CylinderHandleAdornment` with initial properties `a` and optionally-transforms it toward goal `b`
function instanceh.cylinderhandleadornment(
	a: {
		at: CFrame|Vector3;

		radius: number;
		innerradius: number;
		height: number;
		angle: number;
	} & adornmentbase,
	b: ({
		at: CFrame|Vector3?;

		radius: number?;
		innerradius: number?;
		height: number?;
		angle: number?;
	} & adornmentbase & adornmenttransform)?
)
	local adornment = Instance.new("CylinderHandleAdornment")
	setadornmentbaseproperties(adornment, a)
	
	adornment.Radius = a.radius
	adornment.InnerRadius = a.innerradius
	adornment.Height = a.height
	adornment.Angle = a.angle

	if b then
		local to = b.at
		local goal = {
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			AlwaysOnTop = b.alwaysontop;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;
			
			Radius = b.radius;
			InnerRadius = b.innerradius;
			Height = b.height;
			Angle = b.angle;

			Parent = b.parent;
		}

		if next(goal) ~= nil then
			instanceh.tween(adornment, goal, b.time)
		end

		if b.destroy then
			task.delay(b.time, adornment.Destroy, adornment)
		end
	end

	return adornment
end

--- instantiates a `ImageHandleAdornment` with initial properties `a` and optionally-transforms it toward goal `b`
function instanceh.imagehandleadornment(
	a: {
		at: CFrame|Vector3;

		size: Vector2;
		image: string;
	} & adornmentbase,
	b: ({
		at: CFrame|Vector3?;

		size: Vector2?;
		image: string?;
	} & adornmentbase & adornmenttransform)?
)
	local adornment = Instance.new("ImageHandleAdornment")
	setadornmentbaseproperties(adornment, a)
	
	adornment.Size = a.size
	local contentscope = instanceh.setassetid(adornment, a.image)

	if b then
		local to = b.at
		local goal = {
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			AlwaysOnTop = b.alwaysontop;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;
			
			Size = b.size;
			[contentscope] = instanceh.content(b.image);

			Parent = b.parent;
		}

		if next(goal) ~= nil then
			instanceh.tween(adornment, goal, b.time)
		end

		if b.destroy then
			task.delay(b.time, adornment.Destroy, adornment)
		end
	end

	return adornment
end

--- instantiates a `SphereHandleAdornment` with initial properties `a` and optionally-transforms it toward goal `b`
function instanceh.spherehandleadornment(
	a: {
		at: CFrame|Vector3;

		radius: number;
	} & adornmentbase,
	b: ({
		at: CFrame|Vector3?;

		radius: number?;
	} & adornmentbase & adornmenttransform)?
)
	local adornment = Instance.new("SphereHandleAdornment")
	setadornmentbaseproperties(adornment, a)
	
	adornment.Radius = a.radius

	if b then
		local to = b.at
		local goal = {
			Adornee = b.adornee;
			AdornCullingMode = b.adorncullingmode;
			SizeRelativeOffset = b.sizerelativeoffset;
			AlwaysOnTop = b.alwaysontop;
			ZIndex = b.zindex;

			Color3 = b.color;
			Transparency = b.transparency;
			Visible = b.visible;

			CFrame = typeof(to) == "Vector3" and CFrame.new(to) or typeof(to) == "CFrame" and to or nil;
			
			Radius = b.radius;

			Parent = b.parent;
		}

		if next(goal) ~= nil then
			instanceh.tween(adornment, goal, b.time)
		end

		if b.destroy then
			task.delay(b.time, adornment.Destroy, adornment)
		end
	end

	return adornment
end

--- type describing light class
type lightbase = {
	brightness: number?;
	color: Color3?;
	enabled: boolean?;
	shadows: boolean?;
	
	parent: Instance?;
}

--- type describing light transform (tween) args
type lighttransform = {
	time: number;
	destroy: boolean;
}

--- sets light base properties
local function setlightbaseproperties(light: Light, a: lightbase)
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

	if a.parent then
		light.Parent = a.parent
	end
end

--- instantiates a `PointLight` with initial properties `a` and optionally-transforms it toward goal `b`
function instanceh.pointlight(
	a: {
		range: number;
	} & lightbase,
	b: ({
		range: number?;
	} & lightbase & lighttransform)?
)
	local light = Instance.new("PointLight")
	setlightbaseproperties(light, a)

	light.Range = a.range

	if b then
		local goal = {
			Brightness = b.brightness;
			Color = b.color;
			Enabled = b.enabled;
			Shadows = b.shadows;

			Range = b.range;

			Parent = b.parent;
		}

		if next(goal) ~= nil then
			instanceh.tween(light, goal, b.time)
		end

		if b.destroy then
			task.delay(b.time, light.Destroy, light)
		end
	end

	return light
end

--- instantiates a `SpotLight` with initial properties `a` and optionally-transforms it toward goal `b`
function instanceh.spotlight(
	a: {
		range: number;
		face: Enum.NormalId;
		angle: number;
	} & lightbase,
	b: ({
		range: number?;
		face: Enum.NormalId?;
		angle: number?;
	} & lightbase & lighttransform)?
)
	local light = Instance.new("SpotLight")
	setlightbaseproperties(light, a)

	light.Range = a.range
	light.Face = a.face
	light.Angle = a.angle

	if b then
		local goal = {
			Brightness = b.brightness;
			Color3 = b.color;
			Enabled = b.enabled;
			Shadows = b.shadows;

			Range = b.range;
			Face = b.face;
			Angle = b.angle;

			Parent = b.parent;
		}

		if next(goal) ~= nil then
			instanceh.tween(light, goal, b.time)
		end

		if b.destroy then
			task.delay(b.time, light.Destroy, light)
		end
	end

	return light
end

--- instantiates a `SurfaceLight` with initial properties `a` and optionally-transforms it toward goal `b`
function instanceh.surfacelight(
	a: {
		range: number;
		face: Enum.NormalId;
		angle: number;
	} & lightbase,
	b: ({
		range: number?;
		face: Enum.NormalId?;
		angle: number?;
	} & lightbase & lighttransform)?
)
	local light = Instance.new("SurfaceLight")
	setlightbaseproperties(light, a)

	light.Range = a.range
	light.Face = a.face
	light.Angle = a.angle

	if b then
		local goal = {
			Brightness = b.brightness;
			Color3 = b.color;
			Enabled = b.enabled;
			Shadows = b.shadows;

			Range = b.range;
			Face = b.face;
			Angle = b.angle;

			Parent = b.parent;
		}

		if next(goal) ~= nil then
			instanceh.tween(light, goal, b.time)
		end

		if b.destroy then
			task.delay(b.time, light.Destroy, light)
		end
	end

	return light
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

--- creates an `Animation` instance with its `AnimationId` property set to `id`
function instanceh.createanimation(id: number|string|Content?)
	local a = Instance.new("Animation")
	instanceh.setassetid(a, id)
	a.Parent = script

	return a
end

--- plays animation \
--- `fadetime?=1/30`
function instanceh.playanimation(animator: Animator, animation: Animation, priority: Enum.AnimationPriority?, speed: number?, fadetime: number?, weight: number?)
	local animtrack = animator:LoadAnimation(animation)
	animtrack:Play(fadetime or 1/30, weight, speed)
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
		cache = table.create(#things);
		descendantadded = nil :: RBXScriptConnection?;
		descendantremoving = nil :: RBXScriptConnection?;
	}

	for _, thisthing in things do
		if instanceh.istransparencymodifiable(thisthing) then
			table.insert(controller.cache, thisthing)
		end
	end

	controller.descendantadded = thing.DescendantAdded:Connect(function(thisthing: any)
		if instanceh.istransparencymodifiable(thisthing) and not table.find(controller.cache, thisthing) then
			table.insert(controller.cache, thisthing)
			if thisthing:IsA("HandleAdornment") then
				thisthing.Visible = controller.realtransparency ~= 1
			else
				thisthing.LocalTransparencyModifier = controller.realtransparency
			end
		end
	end)
	controller.descendantremoving = thing.DescendantRemoving:Connect(function(thisthing: any)
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
		for _, thing: any in tc.cache do
			if thing:IsA("HandleAdornment") then
				thing.Visible = target ~= 1
			else
				thing.LocalTransparencyModifier = target
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
		player = Players:GetPlayerByUserId(player)
	elseif type(player) == "string" then
		player = Players:QueryDescendants(">#" .. player)[1]
	elseif typeof(player) == "Instance" then
		if player:IsA("Player") then
			--- fine
		elseif player:IsA("Instance") then
			player = Players:GetPlayerFromCharacter(player)
		end
	end

	if player ~= nil then
		assert(typeof(player) == "Instance" and player:IsA("Player"), "error resolving player")

		return player
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
				local accessories = table.create(4 * #appearancemap.accessoryproperties)
	
				for _, property in appearancemap.accessoryproperties do
					local value = (t::any)[property] :: string
					if value ~= "" then
						for _, stringid in string.split(value, ",") do
							table.insert(accessories, tonumber(stringid))
						end
					end
				end
	
				result.Accessories = accessories
			end
	
			do --- body colors
				for _, property in appearancemap.bodycolorproperties do
					local value = (t::any)[property] :: Color3
					result[property] = value:ToHex()
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
						warn(`shirt or pants or shirtgraphic not found (classname "{thing.ClassName}")`)
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

			return instanceh.createappearancedescription(Players:GetHumanoidDescriptionFromUserId(t.UserId))
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

		return accessorypart
	end

	assert(IsServer, "instanceh.createaccessory() can only be called on server (InsertService limitation T__T)")
	local asset = InsertService:LoadAsset(assetid)

	local accessory = asset:FindFirstChildOfClass("Accessory")
	assert(accessory)
	assert(accessory:IsA("Accessory"))

	local handle = accessory:FindFirstChild("Handle") or accessory:WaitForChild("Handle")
	assert(handle)
	assert(handle:IsA("BasePart"))

	local attachment = handle:FindFirstChildOfClass("Attachment")
	assert(attachment)
	assert(attachment:IsA("Attachment"))

	handle.Name = tostring(assetid)
	handle.Locked = false
	handle.EnableFluidForces = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Anchored = false
	handle.Position = Vector3.zero
	handle.Size = Vector3.one
	handle.Parent = script

	handle:SetAttribute(instanceh.accessoryflag, true)

	asset:Destroy()

	return handle
end

--- returns an empty appearance description
function instanceh.emptydescription()
	return {
		Accessories = table.create(0);
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

--- creates a zone
function instanceh.createzone(root: Instance)
	local z = {
		Model = root;

		LoadContainer = workspace;
		OffloadContainer = script;

		Queue = table.create(#root:QueryDescendants(">Instance"));

		Instances = root:QueryDescendants(">Instance");
		InstanceAddedConnection = nil :: RBXScriptConnection?;

		ReparentConnection = nil :: RBXScriptConnection?;
		ReparentRate = 2;
	}

	z.InstanceAddedConnection = root.ChildAdded:Connect(function(thing: Instance)
		if not table.find(z.Instances, thing) then
			table.insert(z.Instances, thing)
			table.insert(z.Queue, thing)
		end
	end)

	return z
end

--- loads zone instances into loadcontainer
function instanceh.zoneload(z: typeof(instanceh.createzone(...)), callback: (Instance, number, number) -> ()?)
	instanceh.zonereparent(z, z.LoadContainer, callback)
end

--- offloads zone instances into offloadcontainer
function instanceh.zoneoffload(z: typeof(instanceh.createzone(...)), callback: (Instance, number, number) -> ()?)
	instanceh.zonereparent(z, z.OffloadContainer, callback)
end

--- reparents zone instances into container
function instanceh.zonereparent(z: typeof(instanceh.createzone(...)), container: Instance, callback: (Instance, number, number) -> ()?)
	if z.ReparentConnection then z.ReparentConnection:Disconnect() end
	z.ReparentConnection = nil

	table.clear(z.Queue)
	table.move(z.Instances, 1, #z.Instances, 1, z.Queue)
	local x, y = 0, #z.Queue

	z.ReparentConnection = RunService.Heartbeat:Connect(function(dt)
		for i = 1, z.ReparentRate do
			local thing = table.remove(z.Queue)

			if thing then
				if not thing:IsDescendantOf(container) then
					thing.Parent = container
				end

				x += 1
				if callback then
					task.defer(callback, thing, x, y)
				end
			else
				if z.ReparentConnection then z.ReparentConnection:Disconnect() end
				z.ReparentConnection = nil
			end
		end
	end)
end

--- creates a mixtape
function instanceh.createmixtape(tracklist: {Sound})
	--- original volumes
	local volumes = table.create(#tracklist)
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
	local contentprovider = game:GetService("ContentProvider")

	return pcall(contentprovider.PreloadAsync, contentprovider, assets, f)
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