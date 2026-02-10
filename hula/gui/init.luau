--!strict

local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local colorsequencewhite = ColorSequence.new(Color3.fromRGB(255, 255, 255))

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
	--- `?=enabled ~= nil and enabled or true`
	visible: boolean?;
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
	layoutorder: number?;
	--- `?=0`
	rotation: number?;
}

--- type describing uistroke properties
export type strokeparams = {
	--- `?=color3.fromrgb(0, 0, 0)`
	color: Color3?;
	--- `?=0`
	transparency: number?;
	--- `?=1`
	thickness: number?;
	--- `?=miter`
	linejoinmode: Enum.LineJoinMode?;
	--- `?=contextual`
	applystrokemode: Enum.ApplyStrokeMode?;
	--- `?=udim.new(0, 0)`
	borderoffset: UDim?;
	--- `?=1`
	zindex: number?;
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

--- type describing uigradient properties
export type gradientparams = {
	--- `?=colorsequence.new(color3.fromrgb(255, 255, 255))`
	color: ColorSequence?;
	--- `?=enabled ~= nil and enabled or true`
	enabled: boolean?;
	--- `?=vector2.zero`
	offset: Vector2?;
	--- `?=0`
	rotation: number?;
	--- `?=numbersequence.new(0)`
	transparency: NumberSequence?;
}

--- type describing uigridlayout properties
export type gridparams = {
	width: number;
	height: number;
} & layout

--- type describing uilistlayout properties
export type listparams = {

} & layout

--- type describing guibutton properties
export type buttonparams = {
	--- `?=autobuttoncolor ~= nil and autobuttoncolor or false`
	autobuttoncolor: boolean?;
}

--- type describing textlabel properties
export type textparams = {
	--- `?=richtext ~= nil and richtext or true`
	richtext: boolean?;
	--- `?=textscaled ~= nil and textscaled or true`
	textscaled: boolean?;
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

--- type describing viewportframe properties
export type viewportparams = {
	--- `?=color3.fromrgb(255, 255, 255)`
	lightcolor: Color3?;
	--- `?=vector3.new(-0.707, -1, 0.707)`
	lightdirection: Vector3?;
	--- `?=color3.fromrgb(148, 148, 148)`
	ambient: Color3?;
	--- `?=nil`
	currentcamera: Camera?;
	--- `?=color3.fromrgb(255, 255, 255)`
	imagecolor: Color3?;
	--- `?=0`
	imagetransparency: number?;
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
	--- shorthand `gui.setalignment()` alignments
	alignments = {
		topleft = { anchorpoint = Vector2.zero; position = UDim2.fromScale(0, 0); };
		top = { anchorpoint = Vector2.new(0.5, 0); position = UDim2.fromScale(0.5, 0); };
		topright = { anchorpoint = Vector2.xAxis; position = UDim2.fromScale(1, 0); };

		centerleft = { anchorpoint = Vector2.new(0, 0.5); position = UDim2.fromScale(0, 0.5); };
		center = { anchorpoint = Vector2.new(0.5, 0.5); position = UDim2.fromScale(0.5, 0.5); };
		centerright = { anchorpoint = Vector2.new(1, 0.5); position = UDim2.fromScale(1, 0.5); };

		bottomleft = { anchorpoint = Vector2.yAxis; position = UDim2.fromScale(0, 1); };
		bottom = { anchorpoint = Vector2.new(0.5, 1); position = UDim2.fromScale(0.5, 1); };
		bottomright = { anchorpoint = Vector2.one; position = UDim2.fromScale(1, 1); };
	};
	--- shorthand numbersequences
	numbersequences = {
		zero = NumberSequence.new(0.000);
		half = NumberSequence.new(0.500);
		one = NumberSequence.new(1.000);
		stepzeroone = NumberSequence.new({
			NumberSequenceKeypoint.new(0.000, 0),
			NumberSequenceKeypoint.new(0.499, 0),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1.000, 1),
		});
		steponezero = NumberSequence.new({
			NumberSequenceKeypoint.new(0.000, 1),
			NumberSequenceKeypoint.new(0.499, 1),
			NumberSequenceKeypoint.new(0.501, 0),
			NumberSequenceKeypoint.new(1.000, 0),
		});
	};
	--- `gui.resolvetextsize()` textscale udims
	textscaleudims = {
		smallest = UDim.new(0.010, 10);
		small = UDim.new(0.014, 10);
		default = UDim.new(0.018, 10);
		large = UDim.new(0.022, 10);
		largest = UDim.new(0.026, 10);
	};
	--- `gui.resolvetextsize()` preferredtextsize udims
	preferredtextsizes = {
		[Enum.PreferredTextSize.Medium] = UDim.new(0.000, 0);
		[Enum.PreferredTextSize.Large] = UDim.new(0.004, 2);
		[Enum.PreferredTextSize.Larger] = UDim.new(0.008, 4);
		[Enum.PreferredTextSize.Largest] = UDim.new(0.012, 6);
	};
}

--- returns `GuiService.PreferredTextSize`
function gui.readpreferredtextsize()
	return GuiService.PreferredTextSize
end

--- returns `GuiService:GetPropertyChangedSignal("PreferredTextSize")`
function gui.preferredtextsizechanged()
	return GuiService:GetPropertyChangedSignal("PreferredTextSize")
end

--- returns `GuiService.PreferredTransparency`
function gui.readpreferredtransparency()
	return GuiService.PreferredTransparency
end

--- returns `GuiService:GetPropertyChangedSignal("PreferredTransparency")`
function gui.preferredtransparencychanged()
	return GuiService:GetPropertyChangedSignal("PreferredTransparency")
end

--- returns `GuiService.ReducedMotionEnabled`
function gui.readreducedmotionenabled()
	return GuiService.ReducedMotionEnabled
end

--- returns `GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")`
function gui.reducedmotionchanged()
	return GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")
end

--- returns `GuiService:GetGuiInset()`
function gui.readguiinset()
	return GuiService:GetGuiInset()
end

--- returns `(viewportabsolutesize.Y * udim.Scale) + udim.Offset`
function gui.resolvetextsize(viewportabsolutesize: Vector2, udim: UDim)
	return (viewportabsolutesize.Y * udim.Scale) + udim.Offset
end

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

--- applies uigradient to guiobject \
--- searches for preexisting before instantiating a new one
function gui.uigradient(guiobject: GuiObject, params: gradientparams)
	local preexisting = guiobject:FindFirstAncestorWhichIsA("UIGradient")
	if preexisting then
		preexisting.Color = params.color or colorsequencewhite
		preexisting.Enabled = if params.enabled ~= nil then params.enabled else true
		preexisting.Offset = params.offset or Vector2.zero
		preexisting.Rotation = params.rotation or 0
		preexisting.Transparency = params.transparency or gui.numbersequences.zero

		return preexisting
	else
		local uigradient = Instance.new("UIGradient")
		uigradient.Color = params.color or colorsequencewhite
		uigradient.Enabled = if params.enabled ~= nil then params.enabled else true
		uigradient.Offset = params.offset or Vector2.zero
		uigradient.Rotation = params.rotation or 0
		uigradient.Transparency = params.transparency or gui.numbersequences.zero

		uigradient.Parent = guiobject

		return uigradient
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
	uistroke.LineJoinMode = params.linejoinmode or Enum.LineJoinMode.Miter
	uistroke.Thickness = params.thickness or 1
	uistroke.Transparency = params.transparency or 0
	uistroke.BorderOffset = params.borderoffset or UDim.new(0, 0)
	uistroke.ZIndex = params.zindex or 1

	uistroke.Parent = guiobject

	return uistroke
end

function gui.setappearance(guiobject: GuiObject, appearance: appearance)
	guiobject.BackgroundColor3 = appearance.backgroundcolor or Color3.fromRGB(255, 255, 255)
	guiobject.BackgroundTransparency = appearance.backgroundtransparency or 1
	guiobject.BorderSizePixel = appearance.bordersizepixel or 0
	guiobject.Visible = if appearance.visible ~= nil then appearance.visible else true
	guiobject.ZIndex = appearance.zindex or 1
end

function gui.setalignment(guiobject: GuiObject, alignment: alignment)
	guiobject.AnchorPoint = alignment.anchorpoint or Vector2.new(0, 0)
	guiobject.Position = alignment.position or UDim2.fromScale(0, 0)
	guiobject.Size = alignment.size or UDim2.fromOffset(64, 64)
	guiobject.LayoutOrder = alignment.layoutorder or 0
	guiobject.Rotation = alignment.rotation or 0
end

function gui.setimage(guiimageobject: ImageButton|ImageLabel, imageparams: imageparams)
	guiimageobject.ImageContent = imageparams.imagecontent or Content.none
	guiimageobject.ImageColor3 = imageparams.imagecolor or Color3.fromRGB(255, 255, 255)
	guiimageobject.ImageTransparency = imageparams.imagetransparency or 0
	guiimageobject.ResampleMode = imageparams.resamplemode or Enum.ResamplerMode.Default
	guiimageobject.ScaleType = imageparams.scaletype or Enum.ScaleType.Stretch
end

function gui.settextparams(guitextobject: TextButton|TextLabel, textparams: textparams)
	guitextobject.RichText = if textparams.richtext ~= nil then textparams.richtext else true
	guitextobject.TextScaled = if textparams.textscaled ~= nil then textparams.textscaled else false
	guitextobject.Font = textparams.font or Enum.Font.Arimo
	guitextobject.TextColor3 = textparams.textcolor or Color3.fromRGB(255, 255, 255)
	guitextobject.TextStrokeColor3 = textparams.textstrokecolor or Color3.fromRGB(0, 0, 0)
	guitextobject.TextStrokeTransparency = textparams.textstroketransparency or 0
	guitextobject.TextXAlignment = textparams.textxalignment or Enum.TextXAlignment.Center
	guitextobject.TextYAlignment = textparams.textyalignment or Enum.TextYAlignment.Center
end

function gui.setviewportparams(viewportframe: ViewportFrame, viewportparams: viewportparams)
	viewportframe.LightColor = viewportparams.lightcolor or Color3.fromRGB(255, 255, 255)
	viewportframe.LightDirection = viewportparams.lightdirection or Vector3.new(-0.707, -1, 0.707)
	viewportframe.Ambient = viewportparams.ambient or Color3.fromRGB(148, 148, 148)
	viewportframe.CurrentCamera = viewportparams.currentcamera or nil::any
	viewportframe.ImageColor3 = viewportparams.imagecolor or Color3.fromRGB(255, 255, 255)
	viewportframe.ImageTransparency = viewportparams.imagetransparency or 0
end

--- creates a button (textbutton)
function gui.createbutton(params: appearance & alignment)
	local textbutton = Instance.new("TextButton")

	gui.setappearance(textbutton, params)
	gui.setalignment(textbutton, params)
	
	textbutton.Text = ""

	return textbutton
end

--- creates a frame
function gui.createframe(params: appearance & alignment)
	local frame = Instance.new("Frame")

	gui.setappearance(frame, params)
	gui.setalignment(frame, params)

	return frame
end

--- creates an imagelabel
function gui.createimagelabel(params: appearance & alignment & imageparams)
	local imagelabel = Instance.new("ImageLabel")

	gui.setappearance(imagelabel, params)
	gui.setalignment(imagelabel, params)
	gui.setimage(imagelabel, params)

	return imagelabel
end

--- creates a textlabel
function gui.createtextlabel(params: appearance & alignment & textparams)
	local textlabel = Instance.new("TextLabel")

	gui.setappearance(textlabel, params)
	gui.setalignment(textlabel, params)
	gui.settextparams(textlabel, params)
	
	textlabel.Text = ""
	textlabel.RichText = true
	textlabel.TextScaled = false

	return textlabel
end

--- creates a viewportframe
function gui.createviewportframe(params: appearance & alignment & viewportparams)
	local viewportframe = Instance.new("ViewportFrame")

	gui.setappearance(viewportframe, params)
	gui.setalignment(viewportframe, params)
	gui.setviewportparams(viewportframe, params)

	return viewportframe
end

--- populates `target` with `count` clones of `source`
function gui.fill<T>(target: GuiObject, source: GuiObject & T, count: number)
	local result = table.create(count)::{typeof(source)}

	for i = 1, count do
		local clone = source:Clone()
		clone.Name = tostring(i)
		clone.LayoutOrder = i
		clone.Parent = target

		table.insert(result, clone)
	end

	return result
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

--- queries `gui.tree()` return type
function gui.query(r: treeresult, name: string, isa: string)
	local result = {}

	local instance = r.instance
	if instance then
		if instance.Name == name and instance:IsA(isa) then
			table.insert(result, instance)
		end
	end
	local contains = r.contains
	if contains then
		for i, thing in ipairs(contains) do
			local reresult = gui.query(thing, name, isa)
			table.move(reresult, 1, #reresult, #result + 1, result)
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
function gui.sprite(imagelabel: ImageLabel, sprite: { position: Vector2, size: Vector2, sheet: number|string|Content }?)
	if sprite then
		--- set imagecontent
		local sheet = sprite.sheet
		if type(sheet) == "number" then
			imagelabel.ImageContent = Content.fromAssetId(sheet)
		elseif type(sheet) == "string" then
			imagelabel.ImageContent = Content.fromUri(sheet)
		elseif typeof(sheet) == "Content" then
			imagelabel.ImageContent = sheet
		end

		--- set size n offset
		local size = sprite.size
		imagelabel.ImageRectSize = size
		imagelabel.ImageRectOffset = sprite.position * size
	else
		--- reset
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