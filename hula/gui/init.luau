--!strict

local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local function tween(object: Instance, properties: {[string]: any}, time: number, style: Enum.EasingStyle?, ...)
	TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Linear, ...), properties):Play()
end

local function cartesian(p: number, w: number)
	p -= 1
	return p // w, p % w
end

--- returns point along bezier curve `u` at interpolant `a`
local function bezier(u: {UDim2}, a: number)
	local len = #u
	if len > 1 then
		local newpoints = table.create(len) :: {UDim2}
		for i, v in ipairs(u) do
			local w = u[i + 1]
			if not w then break end

			table.insert(newpoints, v:Lerp(w, a))
		end

		return bezier(newpoints, a)
	else
		return u[1]
	end
end

--- ### gui.luau
---
--- UDim, UDim2, Vector2 library extensions \
--- ui helper functions
local gui = {
	UDim = {
		zero = UDim.new(0, 0);

		--- returns `UDim.new(w, w)`
		fromconstant = function(w: number)
			return UDim.new(w, w)
		end;
	};
	UDim2 = {
		zero = UDim2.fromScale(0, 0);
		half = UDim2.fromScale(0.5, 0.5);

		onescale = UDim2.fromScale(1, 1);
		xscale = UDim2.fromScale(1, 0);
		yscale = UDim2.fromScale(0, 1);

		oneoffset = UDim2.fromOffset(1, 1);
		xoffset = UDim2.fromOffset(1, 0);
		yoffset = UDim2.fromOffset(0, 1);

		--- returns `UDim2.fromScale(v, v)`
		fromscale = function(v: number)
			return UDim2.fromScale(v, v)
		end;
		--- returns `UDim2.fromOffset(v, v)`
		fromoffset = function(v: number)
			return UDim2.fromOffset(v, v)
		end;
		--- returns `UDim2.fromOffset(v.X, v.Y)`
		fromvector = function(v: Vector2|Vector3)
			return UDim2.fromOffset(v.X, v.Y)
		end;
		
		bezier = bezier;
	};
	Vector2 = {
		half = Vector2.new(0.5, 0.5);

		--- returns `Vector2.new(w, w)`
		fromconstant = function(w: number)
			return Vector2.new(w, w)
		end;
		--- returns `UDim2.fromOffset(u.X.Offset, u.Y.Offset)`
		fromudim2 = function(u: UDim2)
			return UDim2.fromOffset(u.X.Offset, u.Y.Offset)
		end;
		--- returns square at `vec` with `size` clamped within `bounds`
		clamp = function(vec: Vector2, size: Vector2, bounds: Vector2)
			local delta = (vec + size) - bounds

			if delta.X > 0 then
				vec -= Vector2.xAxis * delta.X
			end
			if delta.Y > 0 then
				vec -= Vector2.yAxis * delta.Y
			end

			return vec
		end;
	};
}

type getcore = 
	((parameter: "PointsNotificationsActive") -> boolean)
&	((parameter: "BadgesNotificationsActive") -> boolean)
&	((parameter: "AvatarContextMenuEnabled") -> boolean)
&	((parameter: "ChatActive") -> boolean)
&	((parameter: "ChatWindowSize") -> UDim2)
&	((parameter: "ChatWindowPosition") -> UDim2)
&	((parameter: "ChatBarDisabled") -> boolean)
&	((parameter: "GetBlockedUserIds") -> {number})
&	((parameter: "PlayerBlockedEvent") -> BindableEvent)
&	((parameter: "PlayerUnblockedEvent") -> BindableEvent)
&	((parameter: "PlayerMutedEvent") -> BindableEvent)
&	((parameter: "PlayerUnmutedEvent") -> BindableEvent)
&	((parameter: "PlayerFriendedEvent") -> BindableEvent)
&	((parameter: "PlayerUnfriendedEvent") -> BindableEvent)
&	((parameter: "DevConsoleVisible") -> boolean)
&	((parameter: "VRRotationIntensity") -> "Low" | "High" | "Smooth")

local getcore: getcore = function(parameter)
	return StarterGui:GetCore(parameter)
end

--- returns `StarterGui:GetCore(parameter)`
gui.getcore = getcore

type setcore =
	((parameter: "ChatActive", variant: boolean) -> ())
&	((parameter: "PointsNotificationsActive", variant: boolean) -> ())
&	((parameter: "BadgesNotificationsActive", variant: boolean) -> ())
&	((parameter: "ResetButtonCallback", variant: boolean|BindableEvent) -> ())
&	((parameter: "ChatMakeSystemMessage", variant: {
		Text: string;
		Color: Color3?;
		Font: Enum.Font?;
		TextSize: number?;
	}) -> ())
&	((parameter: "SendNotification", variant: {
		Title: string;
		Text: string;
		Icon: string?;
		Duration: number?;
		Callback: BindableFunction?;
		Button1: string?;
		Button2: string?;
	}) -> ())
&	((parameter: "TopbarEnabled", variant: boolean) -> ())
&	((parameter: "DevConsoleVisible", variant: boolean) -> ())
&	((parameter: "PromptSendFriendRequest", variant: Player) -> ())
&	((parameter: "PromptUnfriend", variant: Player) -> ())
&	((parameter: "PromptBlockPlayer", variant: Player) -> ())
&	((parameter: "PromptUnblockPlayer", variant: Player) -> ())
&	((parameter: "AvatarContextMenuEnabled", variant: boolean) -> ())
&	((parameter: "AvatarContextMenuTarget", variant: Player) -> ())
&	((parameter: "AddAvatarContextMenuOption", variant: Enum.AvatarContextMenuOption | { string | BindableEvent }) -> ()) --- { [1]: string, [2]: BindableEvent }
&	((parameter: "RemoveAvatarContextMenuOption", variant: Enum.AvatarContextMenuOption | { string | BindableEvent }) -> ()) --- should be the same as what was used in `"AddAvatarContextMenuOption"`
&	((parameter: "AvatarContextMenuTheme", variant: {
		BackgroundImage: string;
		BackgroundTransparency: number;
		BackgroundColor: Color3;
		NameTagColor: Color3;
		NameUnderlineColor: Color3;
		ButtonFrameColor: Color3;
		ButtonFrameTransparency: number;
		ButtonUnderlineColor: Color3;
		Font: Enum.Font;
	}) -> ())

local setcore: setcore = function(parameter, value)
	StarterGui:SetCore(parameter)
end

--- returns `StarterGui:SetCore(parameter, value)`
gui.setcore = setcore

type rbxthumb =
	((type: "Asset", id: number, size: "150x150"|"420x420") -> string)
&	((type: "Avatar", id: number, size: "48x48"|"60x60"|"100x100"|"150x150"|"180x180"|"352x352"|"420x420"|"720x720") -> string)
&	((type: "AvatarBust", id: number, size: "50x50"|"60x60"|"75x75"|"100x100"|"150x150"|"180x180"|"352x352"|"420x420") -> string)
&	((type: "AvatarHeadShot", id: number, size: "48x48"|"60x60"|"100x100"|"150x150"|"180x180"|"352x352"|"420x420") -> string)
&	((type: "BadgeIcon", id: number, size: "150x150") -> string)
&	((type: "BundleThumbnail", id: number, size: "150x150"|"420x420") -> string)
&	((type: "FontFamily", id: number, size: "1200x80") -> string)
&	((type: "GameIcon", id: number, size: "50x50"|"150x150") -> string)
&	((type: "GamePass", id: number, size: "150x150") -> string)
&	((type: "GameThumbnail", id: number, size: "256x144"|"384x216"|"480x270"|"576x324"|"768x432") -> string)
&	((type: "GroupIcon", id: number, size: "150x150"|"420x420") -> string)
&	((type: "Outfit", id: number, size: "150x150"|"420x420") -> string)

local rbxthumb: rbxthumb = function(type, id, size)
	if id <= 0 then
		return ""
	else
		return string.format("rbxthumb://type=%s&id=%d&w=%s&h=%s", type, id, unpack(string.split(size, "x")))
	end
end

--- returns `string.format("rbxthumb://type=%s&id=%d&w=%s&h=%s", type, id, unpack(string.split(size, "x")))`
gui.rbxthumb = rbxthumb

--- returns `GuiService.PreferredTextSize`
function gui.preferredtextsize()
	return GuiService.PreferredTextSize
end

--- returns `GuiService:GetPropertyChangedSignal("PreferredTextSize")`
function gui.preferredtextsizechanged()
	return GuiService:GetPropertyChangedSignal("PreferredTextSize")
end

--- returns `GuiService.PreferredTransparency`
function gui.preferredtransparency()
	return GuiService.PreferredTransparency
end

--- returns `GuiService:GetPropertyChangedSignal("PreferredTransparency")`
function gui.preferredtransparencychanged()
	return GuiService:GetPropertyChangedSignal("PreferredTransparency")
end

--- returns `GuiService.ReducedMotionEnabled`
function gui.reducedmotionenabled()
	return GuiService.ReducedMotionEnabled
end

--- returns `GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")`
function gui.reducedmotionchanged()
	return GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")
end

--- returns `GuiService:GetGuiInset()`
function gui.guiinset()
	return GuiService:GetGuiInset()
end

--- locally emits a TextChatService message in `channel (?="RBXGeneral")`
function gui.textchatmessage(message: string, channel: string?)
	local textchannel = TextChatService:WaitForChild("TextChannels"):WaitForChild(channel or "RBXGeneral")
	if textchannel and textchannel:IsA("TextChannel") then
		return textchannel:DisplaySystemMessage(message)
	end

	error(`"{channel}" is not a text channel of TextChatService.TextChannels`)
end

--- connects button events to `guibutton`
function gui.connectbutton(button: GuiButton, functions: {
	--- `MouseButton1Down`
	clickdown: (x: number, y: number) -> ()?;
	--- `MouseButton1Up`
	clickup: (x: number, y: number) -> ()?;
	--- `MouseButton2Down`
	rclickdown: (x: number, y: number) -> ()?;
	--- `MouseButton2Up`
	rclickup: (x: number, y: number) -> ()?;
	--- `MouseEnter` \
	--- `SelectionGained`
	enter: (x: number, y: number) -> ()?;
	--- `MouseLeave` \
	--- `SelectionLost`
	leave: (x: number, y: number) -> ()?;
	--- `MouseMoved`
	move: (x: number, y: number) -> ()?;
	--- `MouseWheelForward`
	scrollup: (x: number, y: number) -> ()?;
	--- `MouseWheelBackward`
	scrolldown: (x: number, y: number) -> ()?;
})
	local connections = table.create(11)

	if functions.clickdown then
		table.insert(connections, button.MouseButton1Down:Connect(functions.clickdown))
	end
	if functions.clickup then
		table.insert(connections, button.MouseButton1Up:Connect(functions.clickup))
	end

	if functions.rclickdown then
		table.insert(connections, button.MouseButton2Down:Connect(functions.rclickdown))
	end
	if functions.rclickup then
		table.insert(connections, button.MouseButton2Up:Connect(functions.rclickup))
	end

	if functions.enter then
		table.insert(connections, button.MouseEnter:Connect(functions.enter))
		table.insert(connections, button.SelectionGained:Connect(function()
			local vec2 = UserInputService:GetMouseLocation()
			functions.enter(vec2.X, vec2.Y)
		end))
	end
	if functions.leave then
		table.insert(connections, button.MouseLeave:Connect(functions.leave))
		table.insert(connections, button.SelectionLost:Connect(function()
			local vec2 = UserInputService:GetMouseLocation()
			functions.leave(vec2.X, vec2.Y)
		end))
	end
	if functions.move then
		table.insert(connections, button.MouseMoved:Connect(functions.move))
	end
	if functions.scrollup then
		table.insert(connections, button.MouseWheelForward:Connect(functions.scrollup))
	end
	if functions.scrolldown then
		table.insert(connections, button.MouseWheelBackward:Connect(functions.scrolldown))
	end

	return connections
end

--- applies `sprite` to `imagelabel`
function gui.sprite(imagelabel: ImageLabel, sprite: typeof(
	{
		position = 0;
		layout = {
			contentid = (nil::any)::(typeof(Content.none) | string);
			size = Vector2.zero;
			width = 0;
		};
	})?
)
	if not sprite then
		imagelabel.ImageContent = Content.none
		imagelabel.ImageRectSize = Vector2.zero
		imagelabel.ImageRectOffset = Vector2.zero

		return
	end

	local layout = sprite.layout

	if layout then
		local content = layout.contentid
		if type(content) == "number" then
			imagelabel.ImageContent = Content.fromAssetId(content)
		elseif type(content) == "string" then
			imagelabel.ImageContent = Content.fromUri(content)
		elseif typeof(content) == "Content" then
			imagelabel.ImageContent = content
		end

		local x, y = cartesian(sprite.position, layout.width)
		local size = layout.size
		imagelabel.ImageRectSize = size
		imagelabel.ImageRectOffset = Vector2.new(y * size.X, x * size.Y)
	else
		imagelabel.ImageContent = Content.none
		imagelabel.ImageRectSize = Vector2.zero
		imagelabel.ImageRectOffset = Vector2.zero
	end
end

--- scrolls textlabel text with `speed (?=100)` and initially-visible `graphemes (?=0)` \
--- returns scroll time
function gui.scrolltext(textlabel: TextLabel, text: string?, speed: number?, graphemes: number?)
	if text == "" then
		--- nothing
		textlabel.MaxVisibleGraphemes = utf8.len(textlabel.ContentText) or 0
	elseif text then
		textlabel.Text = text
		textlabel.MaxVisibleGraphemes = graphemes or 0
	end

	local len = math.clamp((utf8.len(textlabel.ContentText) or 0) - (graphemes or 0), 0, math.huge)
	local time = len / (speed or 100)

	tween(textlabel, {MaxVisibleGraphemes = text == "" and 0 or len}, time, Enum.EasingStyle.Linear)

	return time
end

--- returns a clone of `template`
function gui.clone<T>(template: T & GuiObject, name: string?, layoutorder: number?, parent: Instance?): T
	local clone = template:Clone()
	clone.Name = name or "_clone"
	clone.Parent = parent or template.Parent
	clone.LayoutOrder = layoutorder or 0
	clone.Visible = true

	return clone
end

--- returns array populated by clones of `template`
function gui.dupes<T>(template: T & GuiObject, count: number, parent: Instance?): {T}
	local result = table.create(count)
	for i = 1, count do
		local clone = template:Clone()
		clone.Name = tostring(i)
		clone.Parent = parent or template.Parent
		clone.LayoutOrder = i
		clone.Visible = true

		table.insert(result, clone)
	end

	return result
end

--- applies column-row-padding layout to optional `uigridlayout(?=nil)` \
--- returns cellpadding, cellsize for convenience
function gui.grid(columns: number, rows: number, padding: number, uigridlayout: UIGridLayout?)
	local cellpadding = UDim2.fromOffset(padding, padding)
	local cellsize = UDim2.new(1/columns, -padding, 1/rows, -padding)

	if uigridlayout then
		uigridlayout.CellPadding = cellpadding
		uigridlayout.CellSize = cellsize
	end

	return cellpadding, cellsize
end

--- creates a textqueue, used for displaying text messages
function gui.createtextqueue(separator: string, messagelifetime: number, alloc: number)
	return {
		queue = table.create(alloc) :: { { text: string, timestamp: number, time: number } };
		
		separator = separator;
		messagelifetime = messagelifetime;
	}
end

--- inserts text into textqueue \
--- `front(?=false)` text is inserted at the top of the queue
function gui.textqueueinsert(tq: typeof(gui.createtextqueue(...)), text: string, timestamp: number, time: number?, front: boolean?)
	if front == true then
		table.insert(tq.queue, 1, {
			text = text;
			timestamp = timestamp;
			time = time or tq.messagelifetime;
		})
	else
		table.insert(tq.queue, {
			text = text;
			timestamp = timestamp;
			time = time or tq.messagelifetime;
		})
	end
end

--- advances textqueue, removing any expired text
function gui.textqueuestep(tq: typeof(gui.createtextqueue(...)), now: number)
	local queue = tq.queue

	--- remove expired
	for i = #queue, 1, -1 do
		local entry = queue[i]

		if entry.timestamp + entry.time < now then
			table.remove(queue, i)
		end
	end

	local len = #queue
	if len > 0 then
		local separator = tq.separator
		local blob = ""

		for i, entry in ipairs(queue) do
			local text = entry.text
			local atlen = i == len

			if atlen then
				blob ..= text
			else
				blob ..= text .. separator
			end
		end

		return blob
	else
		return ""
	end
end

--- returns best-fit-for-selection guiobject wrt `thumbstickvector` and currently-selected guiobject
function gui.nextguiobject(guiobjects: {GuiObject}, thumbstickvector: Vector3, current: GuiObject?): GuiObject?
	current = current or guiobjects[1]
	if not current then
		return nil
	end

	if not (vector.magnitude(thumbstickvector::any) > 0) then
		return current
	end

	local point = current.AbsolutePosition + (current.AbsoluteSize * 0.5)

	local guiobjectswithinangle = table.create(#guiobjects) :: {GuiObject}

	for _, guiobject in guiobjects do
		if guiobject == current then continue end

		local thispoint = guiobject.AbsolutePosition + (guiobject.AbsoluteSize * 0.5)
		thispoint -= point

		local dot = vector.dot(thumbstickvector::any, vector.normalize(-Vector3.new(thispoint.X, thispoint.Y, 0)::any))
		if dot <= 0 then continue end

		table.insert(guiobjectswithinangle, guiobject)
	end

	table.sort(guiobjectswithinangle, function(a: GuiObject, b: GuiObject)
		--- vector lib incompatible w vector2
		--- local dista = vector.magnitude(a.AbsolutePosition::any + (a.AbsoluteSize*0.5) - point)
		--- local distb = vector.magnitude(b.AbsolutePosition::any + (b.AbsoluteSize*0.5) - point)
		local dista = (a.AbsolutePosition + (a.AbsoluteSize*0.5) - point).Magnitude
		local distb = (b.AbsolutePosition + (b.AbsoluteSize*0.5) - point).Magnitude
		--- 
		return dista < distb
	end)

	return guiobjectswithinangle[1] or current
end

--- returns true if guiobject is actually visible on screen
function gui.isvisibleonscreen(guiobject: GuiObject)
	if guiobject.Visible == false then
		return false
	else
		local screengui = guiobject:FindFirstAncestorOfClass("ScreenGui")
		if screengui then
			if screengui.Enabled == false then
				return false
			end
		end

		local ancestor = guiobject:FindFirstAncestorWhichIsA("GuiObject")
		if ancestor then
			return gui.isvisibleonscreen(ancestor)
		else
			return guiobject.Visible
		end
	end
end

--- returns the equivalent of `BasePlayerGui:GetWhitelistedGuiObjectsAtPosition()`
function gui.findhovertarget(list: {GuiObject}, insetmouselocation: Vector2): GuiObject?
	local mousex, mousey = insetmouselocation.X, insetmouselocation.Y

	local inbounds = table.create(#list) :: {GuiObject}

	for _, guiobject in ipairs(list) do
		local topleft = guiobject.AbsolutePosition
		local bottomright = topleft + guiobject.AbsoluteSize

		if mousex >= topleft.X 
		and mousex <= bottomright.X
		and mousey >= topleft.Y
		and mousey <= bottomright.Y
		and gui.isvisibleonscreen(guiobject)
		then
			table.insert(inbounds, guiobject)
		end
	end

	if #inbounds > 1 then
		--- sort by distance from center of guiobject
		table.sort(inbounds, function(a: GuiObject, b: GuiObject)
			--- vector lib incompatible w vector2
			--- local dista = vector.magnitude(a.AbsolutePosition::any + (a.AbsoluteSize*0.5) - insetmouselocation)
			--- local distb = vector.magnitude(b.AbsolutePosition::any + (b.AbsoluteSize*0.5) - insetmouselocation)
			local dista = (a.AbsolutePosition + (a.AbsoluteSize*0.5) - insetmouselocation).Magnitude
			local distb = (b.AbsolutePosition + (b.AbsoluteSize*0.5) - insetmouselocation).Magnitude

			return dista < distb
		end)
	end
	
	return inbounds[1]
end

return gui