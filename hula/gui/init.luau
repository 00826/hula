--!strict

local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local function tween(object: Instance, properties: {[string]: any}, time: number, style: Enum.EasingStyle?, ...)
	TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Linear, ...), properties):Play()
end

--- type describing guiobject appearance properties
export type appearance = {
	--- `?=color3.fromrgb(255, 255, 255)`
	backgroundcolor: Color3?;
	--- `?=1`
	backgroundtransparency: number?;
	--- `?=0`
	bordersizepixel: number?;
	--- `?=1`
	zindex: number?;
}

--- type describing guiobject position & rotation properties
export type alignment = {
	--- `?=vector2.new(0, 0)`
	anchorpoint: Vector2?;
	--- `?=udim2.fromscale(0, 0)`
	position: UDim2?;
	--- `?=udim2.fromoffset(64, 64)`
	size: UDim2?;
	--- `?=0`
	rotation: number?;
	--- `?=0`
	layoutorder: number?;
}

--- type describing uistroke properties
export type strokeparams = {
	--- `?=color3.fromrgb(0, 0, 0)`
	color: Color3?;
	--- `?=0`
	transparency: number?;
	--- `?=1`
	thickness: number?;
	--- `?=bevel`
	linejoinmode: Enum.LineJoinMode?;
	--- `?=contextual`
	applystrokemode: Enum.ApplyStrokeMode?;
	borderoffset: UDim?;
}

--- type describing uilayoutobject properties
export type layout = {
	--- `?=4`
	padding: number?;
	--- `?=center`
	horizontalalignment: Enum.HorizontalAlignment?;
	--- `?=center`
	verticalalignment: Enum.VerticalAlignment?;
	--- `?=horizontal`
	filldirection: Enum.FillDirection?;
	--- `?=layoutorder`
	sortorder: Enum.SortOrder?;
}

--- type describing uigridlayout properties
export type gridparams = {
	width: number;
	height: number;
} & layout

--- type describing uilistlayout properties
export type listparams = {

} & layout

--- type describing textlabel properties
export type textparams = {
	--- `?=arimo`
	font: Enum.Font?;
	--- `?=color3.fromrgb(255, 255, 255)`
	textcolor: Color3?;
	--- `?=color3.fromrgb(0, 0, 0)`
	textstrokecolor: Color3?;
	--- `?=0`
	textstroketransparency: number?;
	--- `?=center`
	textxalignment: Enum.TextXAlignment?;
	--- `?=center`
	textyalignment: Enum.TextYAlignment?;
}

--- type describing imagelabel properties
export type imageparams = {
	--- `?=content.none`
	imagecontent: Content?;
	--- `?=color3.fromrgb(255, 255, 255)`
	imagecolor: Color3?;
	--- `?=0`
	imagetransparency: number?;
	--- `?=default`
	resamplemode: Enum.ResamplerMode?;
	--- `?=stretch`
	scaletype: Enum.ScaleType?;
}

--- type describing tree constructor
export type tree = {
	parent: Instance?;
	name: string?;
	instance: Instance?;
	contains: { tree }?;
}

--- type describing tree return result
export type treeresult = {
	instance: Instance?;
	name: string?;
	contains: { treeresult }
}

type getcore = 
&	((parameter: "PointsNotificationsActive") -> boolean)
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

type setcore =
&	((parameter: "ChatActive", variant: boolean) -> ())
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

type thumbnailsize_150 = "150x150"
type thumbnailsize_150_420 = "150x150"|"420x420"

--- type assetthumbnailsizes = "150x150"|"420x420"
type avatarthumbnailsizes = "48x48"|"60x60"|"100x100"|"150x150"|"180x180"|"352x352"|"420x420"|"720x720"
type avatarbustthumbnailsizes = "50x50"|"60x60"|"75x75"|"100x100"|"150x150"|"180x180"|"352x352"|"420x420"
type avatarheadshotthumbnailsizes = "48x48"|"60x60"|"100x100"|"150x150"|"180x180"|"352x352"|"420x420"
--- type badgeiconthumbnailsizes = "150x150"
--- type bundlethumbnailthumbnailsizes = "150x150"|"420x420"
type fontfamilythumbnailsizes = "1200x80"
type gameiconthumbnailsizes = "50x50"|"150x150"
--- type gamepassthumbnailsizes = "150x150"
type gamethumbnailthumbnailsizes = "256x144"|"384x216"|"480x270"|"576x324"|"768x432"
--- type groupiconthumbnailsizes = "150x150"|"420x420"
--- type outfitthumbnailsizes = "150x150"|"420x420"

type rbxthumb =
&	((thumbnailtype: "Asset", id: number, size: thumbnailsize_150_420) -> string)
&	((thumbnailtype: "Avatar", id: number, size: avatarthumbnailsizes) -> string)
&	((thumbnailtype: "AvatarBust", id: number, size: avatarbustthumbnailsizes) -> string)
&	((thumbnailtype: "AvatarHeadShot", id: number, size: avatarheadshotthumbnailsizes) -> string)
&	((thumbnailtype: "BadgeIcon", id: number, size: thumbnailsize_150) -> string)
&	((thumbnailtype: "BundleThumbnail", id: number, size: thumbnailsize_150_420) -> string)
&	((thumbnailtype: "FontFamily", id: number, size: fontfamilythumbnailsizes) -> string)
&	((thumbnailtype: "GameIcon", id: number, size: gameiconthumbnailsizes) -> string)
&	((thumbnailtype: "GamePass", id: number, size: thumbnailsize_150) -> string)
&	((thumbnailtype: "GameThumbnail", id: number, size: gamethumbnailthumbnailsizes) -> string)
&	((thumbnailtype: "GroupIcon", id: number, size: thumbnailsize_150_420) -> string)
&	((thumbnailtype: "Outfit", id: number, size: thumbnailsize_150_420) -> string)

export type buttonfunctions = {
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
}

--- ### gui.luau
---
--- ui helper functions
local gui = {
	alignments = {
		topleft = { anchorpoint = Vector2.new(0, 0); position = UDim2.fromScale(0, 0); };
		top = { anchorpoint = Vector2.new(0.5, 0); position = UDim2.fromScale(0.5, 0); };
		topright = { anchorpoint = Vector2.new(1, 0); position = UDim2.fromScale(1, 0); };

		centerleft = { anchorpoint = Vector2.new(0, 0.5); position = UDim2.fromScale(0, 0.5); };
		center = { anchorpoint = Vector2.new(0.5, 0.5); position = UDim2.fromScale(0.5, 0.5); };
		centerright = { anchorpoint = Vector2.new(1, 0.5); position = UDim2.fromScale(1, 0.5); };

		bottomleft = { anchorpoint = Vector2.new(0, 1); position = UDim2.fromScale(0, 1); };
		bottom = { anchorpoint = Vector2.new(0.5, 1); position = UDim2.fromScale(0.5, 1); };
		bottomright = { anchorpoint = Vector2.new(1, 1); position = UDim2.fromScale(1, 1); };
	};
}

--- applies uiaspectratioconstraint to guiobject \
--- searches for preexisting before instantiating a new one
function gui.uiaspectratioconstraint(guiobject: GuiObject, aspectratio: number)
	local preexisting = guiobject:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	if preexisting then
		preexisting.AspectRatio = aspectratio

		return preexisting
	else
		local uiaspectratioconstraint = Instance.new("UIAspectRatioConstraint")
		uiaspectratioconstraint.AspectRatio = aspectratio
		uiaspectratioconstraint.Parent = guiobject

		return uiaspectratioconstraint
	end
end

--- applies uicorner to guiobject \
--- searches for preexisting before instantiating a new one
function gui.uicorner(guiobject: GuiObject, cornerradius: UDim)
	local preexisting = guiobject:FindFirstChildWhichIsA("UICorner")
	if preexisting then
		preexisting.CornerRadius = cornerradius

		return preexisting
	else
		local uicorner = Instance.new("UICorner")
		uicorner.CornerRadius = cornerradius
		uicorner.Parent = guiobject

		return uicorner
	end
end

--- applies uigridlayout to guiobject \
--- searches for preexisting before instantiating a new one
function gui.uigridlayout(guiobject: GuiObject, params: gridparams)
	local padding = params.padding or 4
	local cellpadding = UDim2.fromOffset(padding, padding)
	local cellsize = UDim2.fromScale(1/params.width, 1/params.height) - cellpadding

	local preexisting = guiobject:FindFirstChildWhichIsA("UIGridLayout")
	if preexisting then
		preexisting.CellPadding = cellpadding
		preexisting.CellSize = cellsize
		preexisting.FillDirectionMaxCells = params.width
		preexisting.HorizontalAlignment = params.horizontalalignment or Enum.HorizontalAlignment.Center
		preexisting.VerticalAlignment = params.verticalalignment or Enum.VerticalAlignment.Center
		preexisting.FillDirection = params.filldirection or Enum.FillDirection.Horizontal
		preexisting.SortOrder = params.sortorder or Enum.SortOrder.LayoutOrder

		return preexisting
	else
		local uigridlayout = Instance.new("UIGridLayout")
		uigridlayout.CellPadding = cellpadding
		uigridlayout.CellSize = cellsize
		uigridlayout.FillDirectionMaxCells = params.width
		uigridlayout.HorizontalAlignment = params.horizontalalignment or Enum.HorizontalAlignment.Center
		uigridlayout.VerticalAlignment = params.verticalalignment or Enum.VerticalAlignment.Center
		uigridlayout.FillDirection = params.filldirection or Enum.FillDirection.Horizontal
		uigridlayout.SortOrder = params.sortorder or Enum.SortOrder.LayoutOrder

		uigridlayout.Parent = guiobject

		return uigridlayout
	end
end

--- applies uilistlayout to guiobject \
--- searches for preexisting before instantiating a new one
function gui.uilistlayout(guiobject: GuiObject, params: listparams)
	local preexisting = guiobject:FindFirstChildWhichIsA("UIListLayout")
	if preexisting then
		preexisting.HorizontalAlignment = params.horizontalalignment or Enum.HorizontalAlignment.Center
		preexisting.VerticalAlignment = params.verticalalignment or Enum.VerticalAlignment.Center
		preexisting.FillDirection = params.filldirection or Enum.FillDirection.Horizontal
		preexisting.SortOrder = params.sortorder or Enum.SortOrder.LayoutOrder

		return preexisting
	else
		local uilistlayout = Instance.new("UIListLayout")
		uilistlayout.Padding = UDim.new(0, params.padding or 4)
		uilistlayout.HorizontalAlignment = params.horizontalalignment or Enum.HorizontalAlignment.Center
		uilistlayout.VerticalAlignment = params.verticalalignment or Enum.VerticalAlignment.Center
		uilistlayout.FillDirection = params.filldirection or Enum.FillDirection.Horizontal
		uilistlayout.SortOrder = params.sortorder or Enum.SortOrder.LayoutOrder

		uilistlayout.Parent = guiobject

		return uilistlayout
	end
end

--- applies uipadding to guiobject \
--- searches for preexisting before instantiating a new one
function gui.uipadding(guiobject: GuiObject, params: { ["top"|"bottom"|"left"|"right"]: UDim })
	local preexisting = guiobject:FindFirstChildWhichIsA("UIPadding")
	if preexisting then
		preexisting.PaddingTop = params.top
		preexisting.PaddingBottom = params.bottom
		preexisting.PaddingLeft = params.left
		preexisting.PaddingRight = params.right

		return preexisting
	else
		local uipadding = Instance.new("UIPadding")
		uipadding.PaddingTop = params.top
		uipadding.PaddingBottom = params.bottom
		uipadding.PaddingLeft = params.left
		uipadding.PaddingRight = params.right
		
		uipadding.Parent = guiobject

		return uipadding
	end
end

--- applies uistroke to guiobject
function gui.uistroke(guiobject: GuiObject, params: strokeparams)
	local uistroke = Instance.new("UIStroke")
	uistroke.Color = params.color or Color3.fromRGB(0, 0, 0)
	uistroke.ApplyStrokeMode = params.applystrokemode or Enum.ApplyStrokeMode.Contextual
	uistroke.LineJoinMode = params.linejoinmode or Enum.LineJoinMode.Bevel
	uistroke.Thickness = params.thickness or 1
	uistroke.Transparency = params.transparency or 0
	uistroke.BorderOffset = params.borderoffset or UDim.new(0, 0)

	uistroke.Parent = guiobject

	return uistroke
end

function gui.setappearance(guiobject: GuiObject, appearance: appearance)
	guiobject.BackgroundColor3 = appearance.backgroundcolor or Color3.fromRGB(255, 255, 255)
	guiobject.BackgroundTransparency = appearance.backgroundtransparency or 1
	guiobject.BorderSizePixel = appearance.bordersizepixel or 0
	guiobject.ZIndex = appearance.zindex or 1
end

function gui.setalignment(guiobject: GuiObject, alignment: alignment)
	guiobject.AnchorPoint = alignment.anchorpoint or Vector2.new(0, 0)
	guiobject.Position = alignment.position or UDim2.fromScale(0, 0)
	guiobject.Size = alignment.size or UDim2.fromOffset(64, 64)
	guiobject.Rotation = alignment.rotation or 0
end

function gui.setimage(guiimageobject: ImageButton|ImageLabel, imageparams: imageparams)
	guiimageobject.ImageContent = imageparams.imagecontent or Content.none
	guiimageobject.ImageColor3 = imageparams.imagecolor or Color3.fromRGB(255, 255, 255)
	guiimageobject.ImageTransparency = imageparams.imagetransparency or 0
	guiimageobject.ResampleMode = imageparams.resamplemode or Enum.ResamplerMode.Default
	guiimageobject.ScaleType = imageparams.scaletype or Enum.ScaleType.Stretch
end

--- creates a frame
function gui.createframe(params: appearance & alignment)
	local frame = Instance.new("Frame")

	gui.setappearance(frame, params)
	gui.setalignment(frame, params)

	return frame
end

--- creates a textlabel
function gui.createtextlabel(params: appearance & alignment & textparams)
	local textlabel = Instance.new("TextLabel")

	gui.setappearance(textlabel, params)
	gui.setalignment(textlabel, params)
	
	textlabel.Text = ""
	textlabel.RichText = true
	textlabel.TextScaled = false

	textlabel.Font = params.font or Enum.Font.Arimo
	textlabel.TextColor3 = params.textcolor or Color3.fromRGB(255, 255, 255)
	textlabel.TextStrokeColor3 = params.textstrokecolor or Color3.fromRGB(0, 0, 0)
	textlabel.TextStrokeTransparency = params.textstroketransparency or 0
	textlabel.TextXAlignment = params.textxalignment or Enum.TextXAlignment.Center
	textlabel.TextYAlignment = params.textyalignment or Enum.TextYAlignment.Center

	return textlabel
end

--- creates an imagelabel
function gui.createimagelabel(params: appearance & alignment & imageparams)
	local imagelabel = Instance.new("ImageLabel")

	gui.setappearance(imagelabel, params)
	gui.setalignment(imagelabel, params)
	gui.setimage(imagelabel, params)

	return imagelabel
end

--- creates a button (textbutton)
function gui.createbutton(params: appearance & alignment)
	local textbutton = Instance.new("TextButton")

	gui.setappearance(textbutton, params)
	gui.setalignment(textbutton, params)
	
	textbutton.Text = ""
	textbutton.RichText = true
	textbutton.TextScaled = false

	return textbutton
end

--- creates a tree of instanced guiobjects
function gui.tree(t: tree)
	local parent = t.parent
	local instance = t.instance
	local contains = t.contains
	
	local result: treeresult = {
		instance = instance;
		contains = {};
	}

	if parent and instance then
		instance.Name = t.name or instance.Name
		instance.Parent = parent

		result.name = instance.Name

		if contains then
			for _, thing in ipairs(contains) do
				thing.parent = instance

				local reentryresult = gui.tree(thing)
				table.insert(result.contains, reentryresult)
			end
		end
	end

	return result
end

local getcore: getcore = function(parameter)
	return StarterGui:GetCore(parameter)
end

--- returns `StarterGui:GetCore(parameter)`
gui.getcore = getcore

local setcore: setcore = function(parameter, value)
	StarterGui:SetCore(parameter)
end

--- returns `StarterGui:SetCore(parameter, value)`
gui.setcore = setcore

local rbxthumb: rbxthumb = function(thumbnailtype, id, size)
	if id <= 0 then
		return ""
	else
		return string.format("rbxthumb://type=%s&id=%d&w=%s&h=%s", thumbnailtype, id, unpack(string.split(size, "x")))
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
function gui.connectbutton(button: GuiButton, functions: buttonfunctions)
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

--- applies `sprite` to `imagelabel` \
--- sprite coordinates are zero-indexed
function gui.sprite(imagelabel: ImageLabel, sheet: { contentid: number|string|Content; spritesize: Vector2; width: number; offsets: {[string]: Vector2} }?, key: string?)
	if not sheet or not key then
		--- reset
		imagelabel.ImageContent = Content.none
		imagelabel.ImageRectSize = Vector2.zero
		imagelabel.ImageRectOffset = Vector2.zero
	else
		local offset = sheet.offsets[key]
		if offset then
			--- set imagecontent
			local content = sheet.contentid
			if type(content) == "number" then
				imagelabel.ImageContent = Content.fromAssetId(content)
			elseif type(content) == "string" then
				imagelabel.ImageContent = Content.fromUri(content)
			elseif typeof(content) == "Content" then
				imagelabel.ImageContent = content
			end

			--- set size n offset
			local size = sheet.spritesize
			imagelabel.ImageRectSize = size
			imagelabel.ImageRectOffset = offset * size
		else
			--- recurse-reset
			gui.sprite(imagelabel, nil, nil)
		end
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

	--- sort by distance from center of guiobject
	table.sort(inbounds, function(a: GuiObject, b: GuiObject)
		--- vector lib incompatible w vector2
		--- local dista = vector.magnitude(a.AbsolutePosition::any + (a.AbsoluteSize*0.5) - insetmouselocation)
		--- local distb = vector.magnitude(b.AbsolutePosition::any + (b.AbsoluteSize*0.5) - insetmouselocation)
		local dista = (a.AbsolutePosition + (a.AbsoluteSize*0.5) - insetmouselocation).Magnitude
		local distb = (b.AbsolutePosition + (b.AbsoluteSize*0.5) - insetmouselocation).Magnitude

		return dista < distb
	end)
	
	return inbounds[1]
end

return gui