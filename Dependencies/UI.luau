--!nonstrict
--[[
	NovaUI – single-file build
	Util, Theme, Icons, Components, Popups, Overlays and Window merged into one ModuleScript.

	Usage (LocalScript):
		local NovaUI = require(path.to.NovaUI)
		local window = NovaUI:CreateWindow({ Title = "My Hub", AccentColor = NovaUI.Theme.AccentPresets.Blue })
		local tab = window:CreateTab({ Name = "Main", Icon = "home" })
		tab:CreateToggle({ Name = "Enabled", Flag = "enabled", Callback = print })
]]

------------------------------------------------------------------------
-- Util
------------------------------------------------------------------------
local UtilModule = (function()
	--[[
		NovaUI.Util
		Shared helpers: Signal, Maid (cleanup), conflict-free tweening, instance creation,
		drag handling, option validation and number/colour utilities.
	]]

	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	local TextService = game:GetService("TextService")
	local GuiService = game:GetService("GuiService")

	local Util = {}

	------------------------------------------------------------------------
	-- Signal (tiny, no BindableEvent instances needed)
	------------------------------------------------------------------------
	local Signal = {}
	Signal.__index = Signal

	function Signal.new()
		return setmetatable({ _handlers = {} }, Signal)
	end

	function Signal:Connect(fn)
		local handlers = self._handlers
		local handler = { fn = fn }
		handlers[handler] = true
		return {
			Disconnect = function()
				handlers[handler] = nil
			end,
		}
	end

	function Signal:Fire(...)
		local snapshot = {}
		for handler in pairs(self._handlers) do
			table.insert(snapshot, handler)
		end
		for _, handler in ipairs(snapshot) do
			if self._handlers[handler] then
				local ok, err = pcall(handler.fn, ...)
				if not ok then
					warn("[NovaUI] listener error: " .. tostring(err))
				end
			end
		end
	end

	function Signal:Destroy()
		table.clear(self._handlers)
	end

	Util.Signal = Signal

	------------------------------------------------------------------------
	-- Maid: collects connections / instances / functions and cleans them together
	------------------------------------------------------------------------
	local Maid = {}
	Maid.__index = Maid

	function Maid.new()
		return setmetatable({ _tasks = {} }, Maid)
	end

	function Maid:Give(item)
		table.insert(self._tasks, item)
		return item
	end

	function Maid:Clean()
		local tasks = self._tasks
		self._tasks = {}
		for i = #tasks, 1, -1 do
			local item = tasks[i]
			local kind = typeof(item)
			if kind == "RBXScriptConnection" then
				item:Disconnect()
			elseif kind == "Instance" then
				item:Destroy()
			elseif kind == "function" then
				local ok, err = pcall(item)
				if not ok then
					warn("[NovaUI] cleanup error: " .. tostring(err))
				end
			elseif kind == "table" then
				if item.Disconnect then
					item:Disconnect()
				elseif item.Destroy then
					item:Destroy()
				end
			end
		end
	end

	Maid.Destroy = Maid.Clean
	Util.Maid = Maid

	------------------------------------------------------------------------
	-- Tweening: one tween per (instance, property). A new tween replaces the
	-- previous one for that property, so rapid interactions never fight.
	------------------------------------------------------------------------
	Util.Info = {
		Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Normal = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Slow = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Drag = TweenInfo.new(0.07, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
	}

	local active = setmetatable({}, { __mode = "k" })

	function Util.Tween(inst, info, props)
		if typeof(info) == "number" then
			info = TweenInfo.new(info, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
		local record = active[inst]
		if not record then
			record = {}
			active[inst] = record
		end
		local last
		for prop, value in pairs(props) do
			local old = record[prop]
			if old then
				old:Cancel()
			end
			local tween = TweenService:Create(inst, info, { [prop] = value })
			record[prop] = tween
			tween.Completed:Once(function()
				if record[prop] == tween then
					record[prop] = nil
				end
			end)
			tween:Play()
			last = tween
		end
		return last
	end

	function Util.Cancel(inst, props)
		local record = active[inst]
		if not record then
			return
		end
		for prop in pairs(props) do
			local tween = record[prop]
			if tween then
				tween:Cancel()
				record[prop] = nil
			end
		end
	end

	-- Set properties either instantly (cancelling running tweens) or with a tween.
	function Util.Apply(inst, props, animate, info)
		if animate then
			return Util.Tween(inst, info or Util.Info.Normal, props)
		end
		Util.Cancel(inst, props)
		for prop, value in pairs(props) do
			inst[prop] = value
		end
		return nil
	end

	------------------------------------------------------------------------
	-- Instance creation with sane defaults
	------------------------------------------------------------------------
	local classDefaults = {
		Frame = { BorderSizePixel = 0 },
		CanvasGroup = { BorderSizePixel = 0 },
		ScrollingFrame = { BorderSizePixel = 0, BackgroundTransparency = 1 },
		TextLabel = { BorderSizePixel = 0, BackgroundTransparency = 1, Text = "" },
		TextButton = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false, Text = "" },
		TextBox = { BorderSizePixel = 0, BackgroundTransparency = 1, ClearTextOnFocus = false, Text = "" },
		ImageLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
	}

	function Util.Create(className, props, children)
		local inst = Instance.new(className)
		local defaults = classDefaults[className]
		if defaults then
			for k, v in pairs(defaults) do
				inst[k] = v
			end
		end
		local parent
		if props then
			for k, v in pairs(props) do
				if k == "Parent" then
					parent = v
				else
					inst[k] = v
				end
			end
		end
		if children then
			for _, child in ipairs(children) do
				child.Parent = inst
			end
		end
		if parent then
			inst.Parent = parent
		end
		return inst
	end

	-- Run a user callback without letting its errors break the UI.
	function Util.Fire(callback, ...)
		if type(callback) ~= "function" then
			return
		end
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[NovaUI] callback error: " .. tostring(err))
		end
	end

	------------------------------------------------------------------------
	-- Validation
	------------------------------------------------------------------------
	function Util.Validate(fname, opts, spec)
		if typeof(opts) ~= "table" then
			error(("NovaUI: %s expects a table of options, got %s"):format(fname, typeof(opts)), 3)
		end
		for key, expected in pairs(spec) do
			local optional = expected:sub(-1) == "?"
			local expectedType = optional and expected:sub(1, -2) or expected
			local value = opts[key]
			if value == nil then
				if not optional then
					error(("NovaUI: %s: option '%s' is required (%s)"):format(fname, key, expectedType), 3)
				end
			elseif expectedType ~= "any" and typeof(value) ~= expectedType then
				error(
					("NovaUI: %s: option '%s' expected %s, got %s"):format(fname, key, expectedType, typeof(value)),
					3
				)
			end
		end
	end

	------------------------------------------------------------------------
	-- Numbers
	------------------------------------------------------------------------
	function Util.Decimals(n)
		local text = string.format("%.10f", n):gsub("0+$", "")
		local frac = text:match("%.(%d*)$")
		return frac and #frac or 0
	end

	function Util.Snap(value, min, max, step)
		local decimals = math.max(Util.Decimals(step), Util.Decimals(min))
		local snapped = min + math.floor((value - min) / step + 0.5) * step
		snapped = math.clamp(snapped, min, max)
		return tonumber(string.format("%." .. decimals .. "f", snapped))
	end

	function Util.FormatNumber(n, decimals)
		return string.format("%." .. (decimals or 0) .. "f", n)
	end

	function Util.Trim(s)
		return (s:gsub("^%s+", ""):gsub("%s+$", ""))
	end

	------------------------------------------------------------------------
	-- Colours
	------------------------------------------------------------------------
	function Util.ToHex(color)
		return string.format(
			"#%02X%02X%02X",
			math.round(color.R * 255),
			math.round(color.G * 255),
			math.round(color.B * 255)
		)
	end

	function Util.FromHex(text)
		text = Util.Trim(text):gsub("^#", "")
		if #text == 3 then
			text = text:gsub(".", function(c)
				return c .. c
			end)
		end
		if #text ~= 6 or text:find("[^%x]") then
			return nil
		end
		return Color3.fromRGB(
			tonumber(text:sub(1, 2), 16),
			tonumber(text:sub(3, 4), 16),
			tonumber(text:sub(5, 6), 16)
		)
	end

	------------------------------------------------------------------------
	-- Text measuring (falls back to an estimate if the font is not loaded yet)
	------------------------------------------------------------------------
	function Util.TextSize(text, font, size, width)
		local ok, bounds = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = text
			params.Font = font
			params.Size = size
			params.Width = width
			return TextService:GetTextBoundsAsync(params)
		end)
		if ok and bounds then
			return bounds
		end
		local perLine = math.max(1, math.floor(width / (size * 0.55)))
		return Vector2.new(width, math.ceil(#text / perLine) * (size + 3))
	end

	-- Input -> GUI coordinates.
	-- Depending on how the ScreenGui is parented (PlayerGui / CoreGui / gethui) and the Roblox
	-- top-bar settings, GuiObject.AbsolutePosition is either in raw screen space or shifted by
	-- the GUI inset. We don't guess: Util.Calibrate learns the right offset from any click whose
	-- target we know the cursor is inside, and until then we assume "shifted by the inset".
	local function rawPoint(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			local inset = GuiService:GetGuiInset()
			return Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y)
		end
		return UserInputService:GetMouseLocation()
	end

	Util.InputOffset = nil -- learned offset (Vector2) or nil while unknown

	function Util.InputPoint(input)
		local offset = Util.InputOffset
		if offset == nil then
			offset = GuiService:GetGuiInset()
		end
		return rawPoint(input) - offset
	end

	-- Call from an InputBegan handler of `guiObject`: the cursor is known to be inside it.
	function Util.Calibrate(input, guiObject)
		local raw = rawPoint(input)
		local inset = GuiService:GetGuiInset()
		local pos, size = guiObject.AbsolutePosition, guiObject.AbsoluteSize
		local function inside(point)
			return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
		end
		local rawInside, shiftedInside = inside(raw), inside(raw - inset)
		if rawInside ~= shiftedInside then
			Util.InputOffset = rawInside and Vector2.zero or inset
		end
	end

	------------------------------------------------------------------------
	-- Dragging: handles mouse + touch, only listens globally while dragging.
	-- callbacks: OnBegin(pos) -> false to cancel, OnChange(pos), OnEnd()
	------------------------------------------------------------------------
	function Util.Drag(handle, maid, callbacks)
		local stop
		maid:Give(handle.InputBegan:Connect(function(input)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end
			Util.Calibrate(input, handle)
			if stop then
				stop()
			end
			if callbacks.OnBegin and callbacks.OnBegin(Util.InputPoint(input)) == false then
				return
			end
			local connections = {}
			local dragging = true
			stop = function()
				if not dragging then
					return
				end
				dragging = false
				for _, c in ipairs(connections) do
					c:Disconnect()
				end
				stop = nil
				if callbacks.OnEnd then
					callbacks.OnEnd()
				end
			end
			table.insert(
				connections,
				UserInputService.InputChanged:Connect(function(changed)
					if not dragging then
						return
					end
					local valid = (inputType == Enum.UserInputType.Touch and changed == input)
						or (inputType == Enum.UserInputType.MouseButton1 and changed.UserInputType == Enum.UserInputType.MouseMovement)
					if valid and callbacks.OnChange then
						callbacks.OnChange(Util.InputPoint(changed))
					end
				end)
			)
			table.insert(
				connections,
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End and stop then
						stop()
					end
				end)
			)
			if callbacks.OnChange then
				callbacks.OnChange(Util.InputPoint(input))
			end
		end))
		maid:Give(function()
			if stop then
				stop()
			end
		end)
	end

	return Util
end)()

------------------------------------------------------------------------
-- Theme
------------------------------------------------------------------------
local ThemeModule = (function()
	--[[
		NovaUI.Theme
		Neutral dark palette + one global, live-updating accent colour.
		Components either call Theme.OnChange(fn) and re-render, or use Theme.Bind()
		for simple "property follows accent" cases.
	]]

	local Util = UtilModule

	local Theme = {}

	Theme.Colors = {
		Background = Color3.fromRGB(11, 11, 14), -- content card
		Chrome = Color3.fromRGB(16, 16, 20), -- window frame / sidebar / title bar
		Panel = Color3.fromRGB(19, 19, 24), -- popups, expandables
		Element = Color3.fromRGB(25, 25, 31),
		ElementHover = Color3.fromRGB(32, 32, 39),
		ElementActive = Color3.fromRGB(40, 40, 48),
		Stroke = Color3.fromRGB(42, 42, 51),
		Text = Color3.fromRGB(224, 224, 231),
		TextMuted = Color3.fromRGB(144, 144, 157),
		TextDim = Color3.fromRGB(98, 98, 110),
		Danger = Color3.fromRGB(232, 88, 88),
		Success = Color3.fromRGB(72, 196, 120),
		Warning = Color3.fromRGB(236, 176, 64),
	}

	local FAMILY = "rbxasset://fonts/families/GothamSSm.json"
	Theme.Fonts = {
		Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
		Medium = Font.new(FAMILY, Enum.FontWeight.Medium),
		SemiBold = Font.new(FAMILY, Enum.FontWeight.SemiBold),
		Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	}

	Theme.AccentPresets = {
		Violet = Color3.fromRGB(130, 90, 255),
		Blue = Color3.fromRGB(64, 140, 255),
		Teal = Color3.fromRGB(32, 196, 180),
		Green = Color3.fromRGB(72, 196, 112),
		Amber = Color3.fromRGB(240, 170, 48),
		Rose = Color3.fromRGB(244, 84, 136),
	}

	local accent = Theme.AccentPresets.Violet
	local changed = Util.Signal.new()

	function Theme.GetAccent()
		return accent
	end

	function Theme.SetAccent(color)
		if typeof(color) ~= "Color3" then
			error("NovaUI: SetAccent expects a Color3, got " .. typeof(color), 2)
		end
		if color == accent then
			return
		end
		accent = color
		changed:Fire(color)
	end

	-- Returns a connection-like object ({ Disconnect }) – give it to a Maid.
	function Theme.OnChange(fn)
		return changed:Connect(fn)
	end

	function Theme.AccentHover()
		local h, s, v = accent:ToHSV()
		return Color3.fromHSV(h, math.max(0, s - 0.08), math.min(1, v * 1.1 + 0.05))
	end

	function Theme.AccentPressed()
		local h, s, v = accent:ToHSV()
		return Color3.fromHSV(h, s, v * 0.82)
	end

	-- Accent mixed into the neutral element colour (selected rows, soft highlights)
	function Theme.AccentMuted()
		return Theme.Colors.Element:Lerp(accent, 0.2)
	end

	-- Readable text colour on top of the accent
	function Theme.OnAccent()
		local luminance = 0.2126 * accent.R + 0.7152 * accent.G + 0.0722 * accent.B
		return luminance > 0.62 and Color3.fromRGB(14, 14, 18) or Color3.new(1, 1, 1)
	end

	-- Keep `inst[prop]` in sync with `resolver()` whenever the accent changes.
	function Theme.Bind(inst, prop, resolver)
		inst[prop] = resolver()
		local connection = changed:Connect(function()
			Util.Tween(inst, Util.Info.Normal, { [prop] = resolver() })
		end)
		local destroying
		destroying = inst.Destroying:Connect(function()
			connection:Disconnect()
			destroying:Disconnect()
		end)
		return connection
	end

	return Theme
end)()

------------------------------------------------------------------------
-- Icons
------------------------------------------------------------------------
local IconsModule = (function()
	--[[
		NovaUI.Icons
		A small, asset-free icon set drawn from rounded frames (no rbxassetid needed, always crisp,
		recolourable). Pass an "rbxassetid://..." string anywhere an icon name is accepted to use an
		image instead; unknown names fall back to the first letter in a circle.
	]]

	local TweenService = game:GetService("TweenService")
	local Util = UtilModule

	local Icons = {}

	-- Shape helpers use a unit square (0..1). Thickness values are in unit space.
	local function bar(cx, cy, len, thickness, rotation)
		return { "bar", cx, cy, len, thickness, rotation or 0 }
	end
	local function ring(cx, cy, diameter)
		return { "ring", cx, cy, diameter }
	end
	local function dot(cx, cy, diameter)
		return { "dot", cx, cy, diameter }
	end
	local function box(cx, cy, w, h)
		return { "box", cx, cy, w, h }
	end
	local function block(cx, cy, w, h)
		return { "block", cx, cy, w, h }
	end

	local defs = {}
	defs.x = { bar(0.5, 0.5, 0.84, 0.12, 45), bar(0.5, 0.5, 0.84, 0.12, -45) }
	defs.minus = { bar(0.5, 0.5, 0.72, 0.12, 0) }
	defs.plus = { bar(0.5, 0.5, 0.72, 0.12, 0), bar(0.5, 0.5, 0.72, 0.12, 90) }
	defs.check = { bar(0.3, 0.65, 0.3, 0.13, 45), bar(0.6, 0.525, 0.62, 0.13, -48) }
	defs["chevron-down"] = { bar(0.35, 0.53, 0.44, 0.12, 45), bar(0.65, 0.53, 0.44, 0.12, -45) }
	defs["chevron-right"] = { bar(0.47, 0.35, 0.44, 0.12, 45), bar(0.47, 0.65, 0.44, 0.12, -45) }
	defs.search = { ring(0.42, 0.42, 0.52), bar(0.76, 0.76, 0.3, 0.12, 45) }
	defs.house = {
		bar(0.325, 0.36, 0.46, 0.12, -41),
		bar(0.675, 0.36, 0.46, 0.12, 41),
		box(0.5, 0.66, 0.5, 0.34),
	}
	defs.info = { ring(0.5, 0.5, 0.84), dot(0.5, 0.3, 0.12), bar(0.5, 0.58, 0.3, 0.11, 90) }
	defs.user = { ring(0.5, 0.32, 0.34), block(0.5, 0.78, 0.66, 0.3) }
	defs.copy = { box(0.4, 0.4, 0.46, 0.46), box(0.6, 0.6, 0.46, 0.46) }
	defs.palette = { ring(0.5, 0.5, 0.84), dot(0.36, 0.4, 0.13), dot(0.6, 0.36, 0.13), dot(0.64, 0.6, 0.13) }
	defs.sliders = {
		bar(0.5, 0.25, 0.8, 0.08, 0),
		bar(0.5, 0.5, 0.8, 0.08, 0),
		bar(0.5, 0.75, 0.8, 0.08, 0),
		dot(0.3, 0.25, 0.22),
		dot(0.7, 0.5, 0.22),
		dot(0.45, 0.75, 0.22),
	}
	defs.keyboard = {
		box(0.5, 0.5, 0.88, 0.58),
		dot(0.28, 0.42, 0.1),
		dot(0.5, 0.42, 0.1),
		dot(0.72, 0.42, 0.1),
		bar(0.5, 0.62, 0.4, 0.09, 0),
	}
	defs.list = {
		bar(0.56, 0.25, 0.6, 0.1, 0),
		bar(0.56, 0.5, 0.6, 0.1, 0),
		bar(0.56, 0.75, 0.6, 0.1, 0),
		dot(0.14, 0.25, 0.12),
		dot(0.14, 0.5, 0.12),
		dot(0.14, 0.75, 0.12),
	}
	defs.settings = { ring(0.5, 0.5, 0.42) }
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		table.insert(
			defs.settings,
			bar(0.5 + math.sin(angle) * 0.36, 0.5 - math.cos(angle) * 0.36, 0.16, 0.12, i * 45 + 90)
		)
	end
	defs.bell = { box(0.5, 0.42, 0.52, 0.5), bar(0.5, 0.8, 0.7, 0.1, 0), dot(0.5, 0.92, 0.12) }
	defs.dot = { dot(0.5, 0.5, 0.5) }

	-- aliases
	defs.home = defs.house
	defs.gear = defs.settings
	defs.close = defs.x
	defs.cog = defs.settings
	defs.sliders_h = defs.sliders

	local function build(container, shapes, color, px)
		local thickness = math.max(1.5, px * 0.1)
		for _, shape in ipairs(shapes) do
			local kind = shape[1]
			local part = Instance.new("Frame")
			part.BorderSizePixel = 0
			part.AnchorPoint = Vector2.new(0.5, 0.5)
			part.Position = UDim2.fromScale(shape[2], shape[3])
			part.BackgroundColor3 = color
			if kind == "bar" then
				part.Size = UDim2.new(shape[4], 0, 0, math.max(1.5, shape[5] * px))
				part.Rotation = shape[6]
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(1, 0)
				c.Parent = part
			elseif kind == "dot" then
				part.Size = UDim2.fromScale(shape[4], shape[4])
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(1, 0)
				c.Parent = part
			elseif kind == "ring" then
				part.BackgroundTransparency = 1
				part.Size = UDim2.fromScale(shape[4], shape[4])
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(1, 0)
				c.Parent = part
				local s = Instance.new("UIStroke")
				s.Thickness = thickness
				s.Color = color
				s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				s.Parent = part
			elseif kind == "box" then
				part.BackgroundTransparency = 1
				part.Size = UDim2.fromScale(shape[4], shape[5])
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, math.max(2, px * 0.12))
				c.Parent = part
				local s = Instance.new("UIStroke")
				s.Thickness = thickness
				s.Color = color
				s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				s.Parent = part
			elseif kind == "block" then
				part.Size = UDim2.fromScale(shape[4], shape[5])
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, math.max(2, px * 0.2))
				c.Parent = part
			end
			part.Parent = container
		end
	end

	-- Icons.Create(name, { Size = 16, Color = Color3, Position, AnchorPoint, LayoutOrder, ZIndex, Parent })
	function Icons.Create(name, props)
		props = props or {}
		local px = props.Size or 16
		local color = props.Color or Color3.new(1, 1, 1)
		local icon

		if type(name) == "string" and name:find("^rbxasset") then
			icon = Instance.new("ImageLabel")
			icon.Image = name
			icon.ImageColor3 = color
		elseif type(name) == "string" and defs[name] then
			icon = Instance.new("Frame")
			build(icon, defs[name], color, px)
		else
			icon = Instance.new("TextLabel")
			icon.Text = type(name) == "string" and name:sub(1, 1):upper() or "?"
			icon.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
			icon.TextSize = math.floor(px * 0.8)
			icon.TextColor3 = color
		end

		icon.Name = "Icon"
		icon.BorderSizePixel = 0
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(px, px)
		if props.AnchorPoint then
			icon.AnchorPoint = props.AnchorPoint
		end
		if props.Position then
			icon.Position = props.Position
		end
		if props.LayoutOrder then
			icon.LayoutOrder = props.LayoutOrder
		end
		if props.ZIndex then
			icon.ZIndex = props.ZIndex
		end
		if props.Parent then
			icon.Parent = props.Parent
		end
		return icon
	end

	function Icons.Has(name)
		return defs[name] ~= nil
	end

	function Icons.SetColor(icon, color, animate)
		local function apply(inst, prop, value)
			if animate then
				Util.Tween(inst, Util.Info.Fast, { [prop] = value })
			else
				Util.Cancel(inst, { [prop] = true })
				inst[prop] = value
			end
		end
		if icon:IsA("ImageLabel") then
			apply(icon, "ImageColor3", color)
		elseif icon:IsA("TextLabel") then
			apply(icon, "TextColor3", color)
		else
			for _, part in ipairs(icon:GetChildren()) do
				if part:IsA("Frame") then
					local stroke = part:FindFirstChildOfClass("UIStroke")
					if stroke then
						apply(stroke, "Color", color)
					else
						apply(part, "BackgroundColor3", color)
					end
				end
			end
		end
	end

	-- Looping spinner: returns (frame, stroke, tween). Recolour via stroke.Color.
	-- The caller owns the tween: Cancel() it when destroying.
	function Icons.Spinner(px)
		px = px or 16
		local frame = Instance.new("Frame")
		frame.Name = "Spinner"
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromOffset(px, px)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = math.max(2, px * 0.14)
		stroke.Color = Color3.new(1, 1, 1)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.78, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = stroke
		local tween = TweenService:Create(
			gradient,
			TweenInfo.new(0.85, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
			{ Rotation = 360 }
		)
		tween:Play()
		return frame, stroke, tween
	end

	return Icons
end)()

------------------------------------------------------------------------
-- Components
------------------------------------------------------------------------
local ComponentsModule = (function()
	--[[
		NovaUI.Components
		The `Container` class: every Tab and Expandable section mixes these Create* methods in.
		Each element is built from a shared base (name/description row, hover, disabled overlay,
		tooltip, context menu, flag + search registration) so everything looks and behaves alike.
	]]

	local UserInputService = game:GetService("UserInputService")

	local Util = UtilModule
	local Theme = ThemeModule
	local Icons = IconsModule

	local Create, Apply, Fire, Info = Util.Create, Util.Apply, Util.Fire, Util.Info
	local Colors, Fonts = Theme.Colors, Theme.Fonts

	local Container = {}

	------------------------------------------------------------------------
	-- small builders
	------------------------------------------------------------------------
	local function corner(r)
		return Create("UICorner", { CornerRadius = UDim.new(0, r) })
	end

	local function stroke(color, transparency)
		return Create("UIStroke", {
			Color = color or Colors.Stroke,
			Transparency = transparency or 0,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end

	local function padding(top, right, bottom, left)
		return Create("UIPadding", {
			PaddingTop = UDim.new(0, top),
			PaddingRight = UDim.new(0, right or top),
			PaddingBottom = UDim.new(0, bottom or top),
			PaddingLeft = UDim.new(0, left or right or top),
		})
	end

	local function listLayout(direction, gap, hAlign, vAlign)
		return Create("UIListLayout", {
			FillDirection = direction or Enum.FillDirection.Vertical,
			Padding = UDim.new(0, gap or 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
			VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		})
	end

	local function textLabel(props)
		local p = {
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextColor3 = Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}
		for k, v in pairs(props) do
			p[k] = v
		end
		return Create("TextLabel", p)
	end

	local function circle(props)
		local p = props
		return Create("Frame", p, { corner(999) })
	end

	local function bindHover(target, maid, setter)
		maid:Give(target.MouseEnter:Connect(function()
			setter(true)
		end))
		maid:Give(target.MouseLeave:Connect(function()
			setter(false)
		end))
	end

	------------------------------------------------------------------------
	-- Base element: [Icon] [Name / Description .......... [Control]]
	-- Extra rows (sliders, lists…) are appended to el.Body below the header.
	------------------------------------------------------------------------
	local function baseElement(container, kind, opts, cfg)
		cfg = cfg or {}
		local ctx = container.Ctx
		local maid = Util.Maid.new()
		local el = {
			Kind = kind,
			Container = container,
			ElementName = opts.Name,
			_maid = maid,
			_changed = Util.Signal.new(),
			_destroyed = false,
			_disabled = false,
		}

		local frame = Create("Frame", {
			Name = kind .. "_" .. tostring(opts.Name),
			BackgroundColor3 = Colors.Element,
			Size = UDim2.new(1, 0, 0, cfg.MinHeight or 46),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = container:_NextOrder(),
			Parent = container.Content,
		}, { corner(8) })
		el.Frame = frame
		el.Stroke = stroke(Colors.Stroke, 0)
		el.Stroke.Parent = frame
		maid:Give(frame)

		local body = Create("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, cfg.MinHeight or 46),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = frame,
		}, { padding(8, 12), listLayout(Enum.FillDirection.Vertical, 10, nil, Enum.VerticalAlignment.Center) })
		el.Body = body

		local header = Create("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = body,
		}, { listLayout(Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center) })
		el.Header = header

		if opts.Icon then
			el.IconObj = Icons.Create(opts.Icon, { Size = 16, Color = Colors.TextMuted, LayoutOrder = 0, Parent = header })
		end

		local left = Create("Frame", {
			Name = "Left",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = header,
		}, {
			listLayout(Enum.FillDirection.Vertical, 2),
			Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		el.NameLabel = textLabel({
			Name = "Name",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = tostring(opts.Name or ""),
			FontFace = Fonts.Medium,
			TextWrapped = true,
			LayoutOrder = 1,
			Parent = left,
		})
		local description = opts.Description or ""
		el.DescLabel = textLabel({
			Name = "Description",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = description,
			TextSize = 12,
			TextColor3 = Colors.TextMuted,
			TextWrapped = true,
			Visible = description ~= "",
			LayoutOrder = 2,
			Parent = left,
		})

		if cfg.ControlWidth then
			el.Control = Create("Frame", {
				Name = "Control",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(cfg.ControlWidth, cfg.ControlHeight or 24),
				LayoutOrder = 3,
				Parent = header,
			})
		end

		if cfg.Hit then
			el.Hit = Create("TextButton", {
				Name = "Hit",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 3,
				Parent = frame,
			})
		end

		local overlay = Create("TextButton", {
			Name = "DisabledOverlay",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.Background,
			BackgroundTransparency = 1,
			Active = true,
			Visible = false,
			ZIndex = 10,
			Parent = frame,
		}, { corner(8) })

		function el:SetName(text)
			self.NameLabel.Text = tostring(text)
			self.ElementName = tostring(text)
			if self._entry then
				self._entry.Name = tostring(text)
			end
		end

		function el:SetDescription(text)
			text = text or ""
			self.DescLabel.Text = text
			self.DescLabel.Visible = text ~= ""
			if self._entry then
				self._entry.Description = text
			end
		end

		function el:SetVisible(visible)
			self.Frame.Visible = visible
		end

		function el:SetDisabled(disabled)
			disabled = disabled == true
			self._disabled = disabled
			if disabled then
				overlay.Visible = true
				Util.Tween(overlay, Info.Fast, { BackgroundTransparency = 0.45 })
			else
				Util.Tween(overlay, Info.Fast, { BackgroundTransparency = 1 })
				task.delay(0.13, function()
					if not self._disabled and overlay.Parent then
						overlay.Visible = false
					end
				end)
			end
		end

		function el:IsDisabled()
			return self._disabled
		end

		function el:OnChanged(fn)
			return self._changed:Connect(fn)
		end

		function el:Destroy()
			if self._destroyed then
				return
			end
			self._destroyed = true
			container:_Unregister(self)
			if self.Flag and ctx.Flags[self.Flag] == self then
				ctx.Flags[self.Flag] = nil
			end
			self._changed:Destroy()
			self._maid:Clean()
		end

		return el
	end

	-- Called at the end of each Create*: tooltip, context menu, flag, registration.
	local function finish(el, opts, hitTarget)
		local container = el.Container
		local ctx = container.Ctx
		local target = hitTarget or el.Hit or el.Frame

	el._maid:Give(target.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Util.Calibrate(input, target)
		end
	end))

		if opts.Tooltip then
			ctx.Tooltip:Attach(target, opts.Tooltip, el._maid)
		end
		if opts.ContextMenu then
			el._maid:Give(target.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					ctx.Popups:ContextMenu(opts.ContextMenu, Util.InputPoint(input))
				end
			end))
		end
		if opts.Flag then
			if ctx.Flags[opts.Flag] then
				warn(("[NovaUI] flag '%s' is already used; the newest component replaces it"):format(opts.Flag))
			end
			ctx.Flags[opts.Flag] = el
			el.Flag = opts.Flag
		end
		container:_Register(el, opts)
		if opts.Disabled then
			el:SetDisabled(true)
		end
		if opts.Visible == false then
			el:SetVisible(false)
		end
		return el
	end

	local function plainElement(container, kind, instance, noSearch)
		local el = {
			Kind = kind,
			Container = container,
			Frame = instance,
			_maid = Util.Maid.new(),
			_destroyed = false,
		}
		function el:SetVisible(visible)
			instance.Visible = visible
		end
		function el:Destroy()
			if self._destroyed then
				return
			end
			self._destroyed = true
			container:_Unregister(self)
			self._maid:Clean()
			instance:Destroy()
		end
		container:_Register(el, { _noSearch = true })
		return el
	end

	------------------------------------------------------------------------
	-- Container plumbing
	------------------------------------------------------------------------
	function Container.Init(self, ctx, content, scroller, tab)
		self.Ctx = ctx
		self.Content = content
		self.Scroller = scroller
		self.Tab = tab or self
		self.Window = ctx.Window
		self._order = 0
		self._count = 0
		self._elements = {}
	end

	function Container:_NextOrder()
		self._order += 1
		return self._order
	end

	function Container:_Register(el, opts)
		self._elements[el] = true
		self._count += 1
		if self.OnCountChanged then
			self:OnCountChanged()
		end
		if not (opts and opts._noSearch) then
			local entry = {
				Element = el,
				Container = self,
				Tab = self.Tab,
				Name = el.ElementName or "",
				Description = opts.Description or "",
			}
			el._entry = entry
			self.Ctx.Search[entry] = true
		end
	end

	function Container:_Unregister(el)
		if not self._elements[el] then
			return
		end
		self._elements[el] = nil
		self._count -= 1
		if el._entry then
			self.Ctx.Search[el._entry] = nil
			el._entry = nil
		end
		if self.OnCountChanged then
			self:OnCountChanged()
		end
	end

	function Container:Clear()
		local list = {}
		for el in pairs(self._elements) do
			table.insert(list, el)
		end
		for _, el in ipairs(list) do
			el:Destroy()
		end
	end

	local function lockScroll(container, locked)
		local scroller = container.Scroller
		if scroller and scroller.Parent then
			scroller.ScrollingEnabled = not locked
		end
	end

	------------------------------------------------------------------------
	-- Text-only elements
	------------------------------------------------------------------------
	local LABEL_STYLES = {
		Title = { Size = 18, Font = Fonts.SemiBold, Color = Colors.Text },
		Subtitle = { Size = 14, Font = Fonts.Medium, Color = Colors.Text },
		Body = { Size = 13, Font = Fonts.Regular, Color = Colors.Text },
		Muted = { Size = 12, Font = Fonts.Regular, Color = Colors.TextMuted },
	}

	function Container:CreateLabel(opts)
		if type(opts) == "string" then
			opts = { Text = opts }
		end
		Util.Validate("CreateLabel", opts, { Text = "string", Style = "string?" })
		local style = LABEL_STYLES[opts.Style or "Body"]
		if not style then
			error("NovaUI: CreateLabel: Style must be Title, Subtitle, Body or Muted", 2)
		end
		local label = textLabel({
			Name = "Label",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Text,
			FontFace = style.Font,
			TextSize = style.Size,
			TextColor3 = style.Color,
			TextWrapped = true,
			LayoutOrder = self:_NextOrder(),
			Parent = self.Content,
		})
		Create("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), Parent = label })
		local el = plainElement(self, "Label", label)
		function el:SetText(text)
			label.Text = tostring(text)
		end
		function el:Get()
			return label.Text
		end
		return el
	end

	function Container:CreateParagraph(opts)
		Util.Validate("CreateParagraph", opts, { Title = "string?", Content = "string" })
		local frame = Create("Frame", {
			Name = "Paragraph",
			BackgroundColor3 = Colors.Panel,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = self:_NextOrder(),
			Parent = self.Content,
		}, { corner(8), stroke(Colors.Stroke, 0.5), padding(10, 12), listLayout(Enum.FillDirection.Vertical, 4) })
		local title
		if opts.Title then
			title = textLabel({
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = opts.Title,
				FontFace = Fonts.SemiBold,
				TextWrapped = true,
				LayoutOrder = 1,
				Parent = frame,
			})
		end
		local body = textLabel({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Content,
			TextSize = 12,
			TextColor3 = Colors.TextMuted,
			TextWrapped = true,
			LayoutOrder = 2,
			Parent = frame,
		})
		local el = plainElement(self, "Paragraph", frame)
		function el:SetText(text)
			body.Text = tostring(text)
		end
		function el:SetTitle(text)
			if title then
				title.Text = tostring(text)
			end
		end
		return el
	end

	function Container:CreateSection(opts)
		if type(opts) == "string" then
			opts = { Name = opts }
		end
		Util.Validate("CreateSection", opts, { Name = "string" })
		local frame = Create("Frame", {
			Name = "Section",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = self:_NextOrder(),
			Parent = self.Content,
		})
		local label = textLabel({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 1, -2),
			Size = UDim2.new(1, -4, 0, 14),
			Text = string.upper(opts.Name),
			FontFace = Fonts.SemiBold,
			TextSize = 11,
			TextColor3 = Colors.TextDim,
			Parent = frame,
		})
		local el = plainElement(self, "Section", frame)
		function el:SetText(text)
			label.Text = string.upper(tostring(text))
		end
		return el
	end

	function Container:CreateDivider()
		local frame = Create("Frame", {
			Name = "Divider",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 9),
			LayoutOrder = self:_NextOrder(),
			Parent = self.Content,
		}, {})
		Create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Colors.Stroke,
			Parent = frame,
		})
		return plainElement(self, "Divider", frame)
	end

	------------------------------------------------------------------------
	-- Button
	------------------------------------------------------------------------
	function Container:CreateButton(opts)
		Util.Validate("CreateButton", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Style = "string?",
			Callback = "function?",
			Disabled = "boolean?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		local style = opts.Style or "Secondary"
		if style ~= "Primary" and style ~= "Secondary" and style ~= "Subtle" then
			error("NovaUI: CreateButton: Style must be Primary, Secondary or Subtle", 2)
		end

		local el = baseElement(self, "Button", opts, { Hit = true, ControlWidth = 18, ControlHeight = 18 })
		local hit, maid = el.Hit, el._maid
		local callback = opts.Callback
		local hovered, down, loading = false, false, false

		el.Control.Visible = false
		local spinner, spinnerStroke, spinnerTween = Icons.Spinner(16)
		spinner.AnchorPoint = Vector2.new(0.5, 0.5)
		spinner.Position = UDim2.fromScale(0.5, 0.5)
		spinner.Parent = el.Control
		spinnerTween:Pause()
		maid:Give(function()
			spinnerTween:Cancel()
		end)

		local function render(animate)
			local accent = Theme.GetAccent()
			local bg, bgT, nameColor, descColor, strokeColor, strokeT
			if style == "Primary" then
				bg = down and Theme.AccentPressed() or (hovered and Theme.AccentHover() or accent)
				bgT, nameColor = 0, Theme.OnAccent()
				descColor = nameColor:Lerp(bg, 0.35)
				strokeColor, strokeT = bg, 1
			elseif style == "Secondary" then
				bg = down and Colors.ElementActive or (hovered and Colors.ElementHover or Colors.Element)
				bgT, nameColor, descColor = 0, Colors.Text, Colors.TextMuted
				strokeColor, strokeT = hovered and accent or Colors.Stroke, 0
			else
				bg = down and Colors.ElementActive or Colors.ElementHover
				bgT = (hovered or down) and 0 or 1
				nameColor, descColor = Colors.Text, Colors.TextMuted
				strokeColor, strokeT = Colors.Stroke, 1
			end
			Apply(el.Frame, { BackgroundColor3 = bg, BackgroundTransparency = bgT }, animate, Info.Fast)
			Apply(el.Stroke, { Color = strokeColor, Transparency = strokeT }, animate, Info.Fast)
			Apply(el.NameLabel, { TextColor3 = nameColor }, animate, Info.Fast)
			Apply(el.DescLabel, { TextColor3 = descColor }, animate, Info.Fast)
			Apply(spinnerStroke, { Color = style == "Primary" and nameColor or accent }, animate, Info.Fast)
			if el.IconObj then
				Icons.SetColor(el.IconObj, style == "Primary" and nameColor or (hovered and accent or Colors.TextMuted), animate)
			end
		end
		render(false)
		maid:Give(Theme.OnChange(function()
			render(true)
		end))

		bindHover(hit, maid, function(state)
			hovered = state
			if not state then
				down = false
			end
			render(true)
		end)
		maid:Give(hit.MouseButton1Down:Connect(function()
			down = true
			render(true)
		end))
		maid:Give(hit.MouseButton1Up:Connect(function()
			down = false
			render(true)
		end))
		maid:Give(hit.MouseButton1Click:Connect(function()
			if el._disabled or loading then
				return
			end
			Fire(callback)
			el._changed:Fire()
		end))

		function el:SetStyle(newStyle)
			if newStyle ~= "Primary" and newStyle ~= "Secondary" and newStyle ~= "Subtle" then
				error("NovaUI: SetStyle: Style must be Primary, Secondary or Subtle", 2)
			end
			style = newStyle
			render(true)
		end
		function el:SetLoading(state)
			loading = state == true
			el.Control.Visible = loading
			if loading then
				spinnerTween:Play()
			else
				spinnerTween:Pause()
			end
		end
		function el:SetCallback(fn)
			callback = fn
		end
		function el:Click()
			if not (el._disabled or loading) then
				Fire(callback)
			end
		end
		return finish(el, opts)
	end

	------------------------------------------------------------------------
	-- Toggle
	------------------------------------------------------------------------
	function Container:CreateToggle(opts)
		Util.Validate("CreateToggle", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Default = "boolean?",
			Callback = "function?",
			Disabled = "boolean?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		local el = baseElement(self, "Toggle", opts, { Hit = true, ControlWidth = 40, ControlHeight = 22 })
		local maid = el._maid
		local value = opts.Default == true
		local hovered = false

		local track = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.ElementActive,
			Parent = el.Control,
		}, { corner(11) })
		local thumb = Create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Colors.TextMuted,
			Parent = track,
		}, { corner(8) })

		local function render(animate)
			local accent = Theme.GetAccent()
			Apply(track, { BackgroundColor3 = value and accent or Colors.ElementActive }, animate, Info.Normal)
			Apply(thumb, {
				Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
				BackgroundColor3 = value and Theme.OnAccent() or Colors.TextMuted,
			}, animate, Info.Normal)
			Apply(el.Frame, { BackgroundColor3 = hovered and Colors.ElementHover or Colors.Element }, animate, Info.Fast)
			if el.IconObj then
				Icons.SetColor(el.IconObj, value and accent or Colors.TextMuted, animate)
			end
		end
		render(false)
		maid:Give(Theme.OnChange(function()
			render(true)
		end))
		bindHover(el.Hit, maid, function(state)
			hovered = state
			render(true)
		end)

		local callback = opts.Callback
		local function set(newValue, silent)
			newValue = newValue == true
			if newValue == value then
				return
			end
			value = newValue
			render(true)
			if not silent then
				Fire(callback, value)
				el._changed:Fire(value)
			end
		end
		maid:Give(el.Hit.MouseButton1Click:Connect(function()
			set(not value, false)
		end))

		function el:Get()
			return value
		end
		function el:Set(v, silent)
			set(v, silent)
		end
		function el:Toggle()
			set(not value, false)
		end
		function el:_serialize()
			return value
		end
		function el:_deserialize(v)
			set(v, false)
		end
		return finish(el, opts)
	end

	------------------------------------------------------------------------
	-- Checkbox
	------------------------------------------------------------------------
	function Container:CreateCheckbox(opts)
		Util.Validate("CreateCheckbox", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Default = "boolean?",
			Callback = "function?",
			Disabled = "boolean?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		local el = baseElement(self, "Checkbox", opts, { Hit = true, ControlWidth = 20, ControlHeight = 20 })
		local maid = el._maid
		local value = opts.Default == true
		local hovered = false

		local boxFrame = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.ElementActive,
			Parent = el.Control,
		}, { corner(6) })
		local boxStroke = stroke(Colors.Stroke, 0)
		boxStroke.Parent = boxFrame
		local check = Icons.Create("check", {
			Size = 14,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = boxFrame,
		})
		check.Size = UDim2.fromOffset(0, 0)

		local function render(animate)
			local accent = Theme.GetAccent()
			Apply(boxFrame, { BackgroundColor3 = value and accent or Colors.ElementActive }, animate, Info.Fast)
			Apply(boxStroke, { Color = (value or hovered) and accent or Colors.Stroke }, animate, Info.Fast)
			Apply(check, { Size = value and UDim2.fromOffset(14, 14) or UDim2.fromOffset(0, 0) }, animate, Info.Fast)
			Icons.SetColor(check, Theme.OnAccent(), animate)
			Apply(el.Frame, { BackgroundColor3 = hovered and Colors.ElementHover or Colors.Element }, animate, Info.Fast)
		end
		render(false)
		maid:Give(Theme.OnChange(function()
			render(true)
		end))
		bindHover(el.Hit, maid, function(state)
			hovered = state
			render(true)
		end)

		local callback = opts.Callback
		local function set(newValue, silent)
			newValue = newValue == true
			if newValue == value then
				return
			end
			value = newValue
			render(true)
			if not silent then
				Fire(callback, value)
				el._changed:Fire(value)
			end
		end
		maid:Give(el.Hit.MouseButton1Click:Connect(function()
			set(not value, false)
		end))

		function el:Get()
			return value
		end
		function el:Set(v, silent)
			set(v, silent)
		end
		function el:_serialize()
			return value
		end
		function el:_deserialize(v)
			set(v, false)
		end
		return finish(el, opts)
	end

	------------------------------------------------------------------------
	-- Slider
	------------------------------------------------------------------------
	function Container:CreateSlider(opts)
		Util.Validate("CreateSlider", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Min = "number",
			Max = "number",
			Default = "number?",
			Step = "number?",
			Suffix = "string?",
			ShowInput = "boolean?",
			Callback = "function?",
			Disabled = "boolean?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		if opts.Min >= opts.Max then
			error("NovaUI: CreateSlider: 'Min' must be smaller than 'Max'", 2)
		end
		local step = opts.Step or 1
		if step <= 0 then
			error("NovaUI: CreateSlider: 'Step' must be greater than 0", 2)
		end
		local min, max = opts.Min, opts.Max
		local suffix = opts.Suffix or ""
		local decimals = math.max(Util.Decimals(step), Util.Decimals(min))
		local value = Util.Snap(opts.Default or min, min, max, step)
		local callback = opts.Callback

		local el = baseElement(self, "Slider", opts, { ControlWidth = 70, ControlHeight = 24 })
		local maid = el._maid

		local function format(v)
			return Util.FormatNumber(v, decimals) .. suffix
		end

		local box = Create("TextBox", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 0,
			BackgroundColor3 = Colors.ElementActive,
			FontFace = Fonts.Medium,
			TextSize = 12,
			TextColor3 = Colors.Text,
			Text = format(value),
			TextEditable = opts.ShowInput ~= false,
			Parent = el.Control,
		}, { corner(6) })
		local boxStroke = stroke(Colors.Stroke, 0)
		boxStroke.Parent = box

		local hitArea = Create("TextButton", {
			Name = "TrackHit",
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = 2,
			Parent = el.Body,
		})
		local track = Create("Frame", {
			Name = "Track",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = Colors.ElementActive,
			Parent = hitArea,
		}, { corner(3) })
		local fill = Create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.GetAccent(),
			Parent = track,
		}, { corner(3) })
		local thumb = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Theme.GetAccent(),
			ZIndex = 2,
			Parent = track,
		}, { corner(7), stroke(Colors.Element, 0) })
		thumb.UIStroke.Thickness = 2
		Theme.Bind(fill, "BackgroundColor3", Theme.GetAccent)
		Theme.Bind(thumb, "BackgroundColor3", Theme.GetAccent)

		-- mode: "instant" | "drag" | nil (smooth)
		local function visual(mode)
			local alpha = (value - min) / (max - min)
			if mode == "instant" then
				Util.Apply(fill, { Size = UDim2.fromScale(alpha, 1) }, false)
				Util.Apply(thumb, { Position = UDim2.fromScale(alpha, 0.5) }, false)
			else
				local tweenInfo = mode == "drag" and Info.Drag or Info.Normal
				Util.Tween(fill, tweenInfo, { Size = UDim2.fromScale(alpha, 1) })
				Util.Tween(thumb, tweenInfo, { Position = UDim2.fromScale(alpha, 0.5) })
			end
			if not box:IsFocused() then
				box.Text = format(value)
			end
		end
		visual("instant")

		local function set(newValue, fromDrag, silent)
			newValue = Util.Snap(newValue, min, max, step)
			if newValue == value then
				visual(fromDrag and "drag" or nil)
				return
			end
			value = newValue
			visual(fromDrag and "drag" or nil)
			if not silent then
				Fire(callback, value)
				el._changed:Fire(value)
			end
		end

		Util.Drag(hitArea, maid, {
			OnBegin = function()
				if el._disabled then
					return false
				end
				lockScroll(self, true)
				Util.Tween(thumb, Info.Fast, { Size = UDim2.fromOffset(17, 17) })
				return true
			end,
			OnChange = function(pos)
				local width = math.max(track.AbsoluteSize.X, 1)
				local alpha = math.clamp((pos.X - track.AbsolutePosition.X) / width, 0, 1)
				set(min + alpha * (max - min), true, false)
			end,
			OnEnd = function()
				lockScroll(self, false)
				Util.Tween(thumb, Info.Fast, { Size = UDim2.fromOffset(14, 14) })
			end,
		})

		maid:Give(box.Focused:Connect(function()
			box.Text = Util.FormatNumber(value, decimals)
			Util.Tween(boxStroke, Info.Fast, { Color = Theme.GetAccent() })
		end))
		maid:Give(box.FocusLost:Connect(function()
			Util.Tween(boxStroke, Info.Fast, { Color = Colors.Stroke })
			local parsed = tonumber(box.Text:match("^%s*(-?%d*%.?%d+)"))
			if parsed then
				set(parsed, false, false)
			end
			box.Text = format(value)
		end))
		maid:Give(Theme.OnChange(function()
			if box:IsFocused() then
				boxStroke.Color = Theme.GetAccent()
			end
		end))

		function el:Get()
			return value
		end
		function el:Set(v, silent)
			if type(v) ~= "number" then
				error("NovaUI: Slider:Set expects a number, got " .. typeof(v), 2)
			end
			set(v, false, silent)
		end
		function el:SetRange(newMin, newMax)
			if type(newMin) ~= "number" or type(newMax) ~= "number" or newMin >= newMax then
				error("NovaUI: Slider:SetRange expects two numbers with min < max", 2)
			end
			min, max = newMin, newMax
			decimals = math.max(Util.Decimals(step), Util.Decimals(min))
			value = Util.Snap(value, min, max, step)
			visual()
		end
		function el:_serialize()
			return value
		end
		function el:_deserialize(v)
			if type(v) == "number" then
				set(v, false, false)
			end
		end
		return finish(el, opts, hitArea)
	end

	------------------------------------------------------------------------
	-- Option row (shared by Dropdown popups and Lists)
	------------------------------------------------------------------------
	local function optionRow(parent, text, height)
		local button = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, height or 28),
			BackgroundColor3 = Colors.ElementHover,
			BackgroundTransparency = 1,
			Parent = parent,
		}, { corner(6) })
		local label = textLabel({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -34, 1, 0),
			Text = tostring(text),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = button,
		})
		local check = Icons.Create("check", {
			Size = 12,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Color = Theme.GetAccent(),
			Parent = button,
		})
		check.Visible = false

		local row = { Button = button, Label = label, Selected = false }
		local hovered = false
		function row.Render(animate)
			local accent = Theme.GetAccent()
			Apply(button, {
				BackgroundColor3 = row.Selected and Theme.AccentMuted() or Colors.ElementHover,
				BackgroundTransparency = (row.Selected or hovered) and 0 or 1,
			}, animate, Info.Fast)
			Apply(label, { TextColor3 = row.Selected and accent or Colors.Text }, animate, Info.Fast)
			check.Visible = row.Selected
			Icons.SetColor(check, accent)
		end
		button.MouseEnter:Connect(function()
			hovered = true
			row.Render(true)
		end)
		button.MouseLeave:Connect(function()
			hovered = false
			row.Render(true)
		end)
		return row
	end

	local function filterRows(rows, query)
		query = string.lower(query or "")
		local visible = 0
		for _, row in ipairs(rows) do
			local show = query == "" or string.find(string.lower(row.Text), query, 1, true) ~= nil
			row.Button.Visible = show
			if show then
				visible += 1
			end
		end
		return visible
	end

	------------------------------------------------------------------------
	-- Dropdown
	------------------------------------------------------------------------
	function Container:CreateDropdown(opts)
		Util.Validate("CreateDropdown", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Options = "table",
			Default = "any?",
			Placeholder = "string?",
			Searchable = "boolean?",
			Callback = "function?",
			Disabled = "boolean?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		local ctx = self.Ctx
		local options = table.clone(opts.Options)
		local value = nil
		local callback = opts.Callback
		local placeholder = opts.Placeholder or "Select…"
		local opened, hovered = false, false

		local el = baseElement(self, "Dropdown", opts, { Hit = true, ControlWidth = 156, ControlHeight = 28 })
		local maid = el._maid

		local box = Create("Frame", {
			Name = "Box",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.ElementActive,
			Parent = el.Control,
		}, { corner(6) })
		local boxStroke = stroke(Colors.Stroke, 0)
		boxStroke.Parent = box
		local selectedLabel = textLabel({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -34, 1, 0),
			Text = placeholder,
			TextColor3 = Colors.TextMuted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = box,
		})
		local chevron = Icons.Create("chevron-down", {
			Size = 12,
			Color = Colors.TextMuted,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Parent = box,
		})

		local function render(animate)
			local accent = Theme.GetAccent()
			Apply(boxStroke, { Color = (opened or hovered) and accent or Colors.Stroke }, animate, Info.Fast)
			Apply(el.Frame, { BackgroundColor3 = hovered and Colors.ElementHover or Colors.Element }, animate, Info.Fast)
			Apply(chevron, { Rotation = opened and 180 or 0 }, animate, Info.Normal)
			Icons.SetColor(chevron, opened and accent or Colors.TextMuted, animate)
			selectedLabel.TextColor3 = value ~= nil and Colors.Text or Colors.TextMuted
		end
		local function refreshText()
			selectedLabel.Text = value ~= nil and tostring(value) or placeholder
			selectedLabel.TextColor3 = value ~= nil and Colors.Text or Colors.TextMuted
		end

		local function set(newValue, silent)
			if newValue ~= nil and not table.find(options, newValue) then
				warn(("[NovaUI] Dropdown '%s': '%s' is not one of the options"):format(opts.Name, tostring(newValue)))
				return
			end
			if newValue == value then
				return
			end
			value = newValue
			refreshText()
			if not silent then
				Fire(callback, value)
				el._changed:Fire(value)
			end
		end

		local function open()
			if opened or el._disabled or #options == 0 then
				return
			end
			opened = true
			render(true)
			ctx.Popups:Open({
				Anchor = box,
				Width = math.max(box.AbsoluteSize.X, 156),
				MaxHeight = 250,
				OnClose = function()
					opened = false
					if el.Frame.Parent then
						render(true)
					end
				end,
				Build = function(panel, popupMaid, close)
					local searchHeight = opts.Searchable and 36 or 0
					local rows = {}
					local scroller = Create("ScrollingFrame", {
						Position = UDim2.fromOffset(0, searchHeight),
						Size = UDim2.new(1, 0, 1, -searchHeight),
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollBarThickness = 3,
						ScrollBarImageColor3 = Colors.TextDim,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						Parent = panel,
					}, { padding(4), listLayout(Enum.FillDirection.Vertical, 2) })
					for index, option in ipairs(options) do
						local row = optionRow(scroller, option, 28)
						row.Text = tostring(option)
						row.Button.LayoutOrder = index
						row.Selected = option == value
						row.Render(false)
						row.Button.MouseButton1Click:Connect(function()
							set(option, false)
							close()
						end)
						table.insert(rows, row)
					end
					local empty = textLabel({
						Size = UDim2.new(1, 0, 0, 28),
						Text = "No results",
						TextColor3 = Colors.TextDim,
						TextXAlignment = Enum.TextXAlignment.Center,
						Visible = false,
						LayoutOrder = 9999,
						Parent = scroller,
					})
					if opts.Searchable then
						local searchBox = Create("TextBox", {
							Position = UDim2.fromOffset(4, 4),
							Size = UDim2.new(1, -8, 0, 28),
							BackgroundTransparency = 0,
							BackgroundColor3 = Colors.ElementActive,
							PlaceholderText = "Search…",
							PlaceholderColor3 = Colors.TextDim,
							FontFace = Fonts.Regular,
							TextSize = 13,
							TextColor3 = Colors.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							Parent = panel,
						}, { corner(6), padding(0, 8) })
						popupMaid:Give(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
							empty.Visible = filterRows(rows, searchBox.Text) == 0
						end))
						task.defer(function()
							if searchBox.Parent then
								searchBox:CaptureFocus()
							end
						end)
					end
					return searchHeight + #options * 30 + 8
				end,
			})
		end
		maid:Give(el.Hit.MouseButton1Click:Connect(open))
		bindHover(el.Hit, maid, function(state)
			hovered = state
			render(true)
		end)
		maid:Give(Theme.OnChange(function()
			render(true)
		end))
		maid:Give(function()
			if opened then
				ctx.Popups:Close(false)
			end
		end)

		-- initial value
		if opts.Default ~= nil and table.find(options, opts.Default) then
			value = opts.Default
		end
		refreshText()
		render(false)

		function el:Get()
			return value
		end
		function el:Set(v, silent)
			set(v, silent)
		end
		function el:GetOptions()
			return table.clone(options)
		end
		function el:SetOptions(newOptions, keepSelection)
			if type(newOptions) ~= "table" then
				error("NovaUI: Dropdown:SetOptions expects a table", 2)
			end
			options = table.clone(newOptions)
			if not (keepSelection and value ~= nil and table.find(options, value)) then
				value = nil
				refreshText()
			end
		end
		function el:_serialize()
			return value
		end
		function el:_deserialize(v)
			if v == nil or table.find(options, v) then
				set(v, false)
			end
		end
		return finish(el, opts)
	end

	------------------------------------------------------------------------
	-- Colour picker
	------------------------------------------------------------------------
	function Container:CreateColorPicker(opts)
		Util.Validate("CreateColorPicker", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Default = "Color3?",
			Transparency = "boolean?",
			DefaultAlpha = "number?",
			Callback = "function?",
			Disabled = "boolean?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		local ctx = self.Ctx
		local callback = opts.Callback
		local useAlpha = opts.Transparency == true
		local color = opts.Default or Theme.GetAccent()
		local h, s, v = color:ToHSV()
		local alpha = math.clamp(opts.DefaultAlpha or 1, 0, 1)
		local ui -- widget references while the popup is open
		local opened, hovered = false, false

		local el = baseElement(self, "ColorPicker", opts, { Hit = true, ControlWidth = 48, ControlHeight = 24 })
		local maid = el._maid

		local swatch = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			Parent = el.Control,
		}, { corner(6) })
		local swatchStroke = stroke(Colors.Stroke, 0)
		swatchStroke.Parent = swatch

		local function fireChange(silent)
			if not silent then
				Fire(callback, color, alpha)
				el._changed:Fire(color, alpha)
			end
		end

		local function refresh()
			swatch.BackgroundColor3 = color
			if useAlpha then
				swatch.BackgroundTransparency = 1 - alpha
			end
			if not ui then
				return
			end
			ui.sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			ui.cursor.Position = UDim2.fromScale(s, 1 - v)
			ui.hueThumb.Position = UDim2.fromScale(h, 0.5)
			ui.briGradient.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1))
			ui.briThumb.Position = UDim2.fromScale(v, 0.5)
			ui.chip.BackgroundColor3 = color
			if ui.alphaFill then
				ui.alphaFill.BackgroundColor3 = color
				ui.alphaThumb.Position = UDim2.fromScale(alpha, 0.5)
			end
			if not ui.hex:IsFocused() then
				ui.hex.Text = Util.ToHex(color)
			end
			ui.r.Text = tostring(math.round(color.R * 255))
			ui.g.Text = tostring(math.round(color.G * 255))
			ui.b.Text = tostring(math.round(color.B * 255))
		end

		local function setHSV(nh, ns, nv, silent)
			h, s, v = nh, ns, nv
			color = Color3.fromHSV(h, s, v)
			refresh()
			fireChange(silent)
		end

		local function setColor(newColor, silent)
			local nh, ns, nv = newColor:ToHSV()
			if ns < 0.001 or nv < 0.001 then
				nh = h
			end
			if nv < 0.001 then
				ns = s
			end
			setHSV(nh, ns, nv, silent)
		end

		local function render(animate)
			Apply(swatchStroke, { Color = (opened or hovered) and Theme.GetAccent() or Colors.Stroke }, animate, Info.Fast)
			Apply(el.Frame, { BackgroundColor3 = hovered and Colors.ElementHover or Colors.Element }, animate, Info.Fast)
		end
		render(false)
		refresh()
		bindHover(el.Hit, maid, function(state)
			hovered = state
			render(true)
		end)
		maid:Give(Theme.OnChange(function()
			render(true)
		end))

		local function open()
			if opened or el._disabled then
				return
			end
			opened = true
			render(true)
			ctx.Popups:Open({
				Anchor = swatch,
				Width = 232,
				Align = "Right",
				MaxHeight = 350,
				OnClose = function()
					opened = false
					ui = nil
					if el.Frame.Parent then
						render(true)
					end
				end,
				Build = function(panel, popupMaid)
					local widgets = {}
					local y = 12

					-- saturation / value square
					local sv = Create("Frame", {
						Position = UDim2.fromOffset(12, y),
						Size = UDim2.fromOffset(208, 130),
						BackgroundColor3 = Color3.fromHSV(h, 1, 1),
						Parent = panel,
					}, { corner(6) })
					Create("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						Parent = sv,
					}, { corner(6), Create("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
					Create("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.new(0, 0, 0),
						Parent = sv,
					}, { corner(6), Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
					local cursor = circle({
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(12, 12),
						BackgroundTransparency = 1,
						Parent = sv,
					})
					Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = cursor })
					widgets.sv, widgets.cursor = sv, cursor
					y += 140

					-- hue bar
					local hueBar = Create("Frame", {
						Position = UDim2.fromOffset(12, y),
						Size = UDim2.fromOffset(208, 12),
						BackgroundColor3 = Color3.new(1, 1, 1),
						Parent = panel,
					}, { corner(6) })
					local hueKeys = {}
					for i = 0, 6 do
						table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
					end
					Create("UIGradient", { Color = ColorSequence.new(hueKeys), Parent = hueBar })
					local hueThumb = Create("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(6, 18),
						BackgroundColor3 = Color3.new(1, 1, 1),
						Parent = hueBar,
					}, { corner(3), stroke(Color3.new(0, 0, 0), 0.5) })
					widgets.hueThumb = hueThumb
					y += 22

					-- brightness bar (black -> full-brightness colour)
					local briBar = Create("Frame", {
						Position = UDim2.fromOffset(12, y),
						Size = UDim2.fromOffset(208, 12),
						BackgroundColor3 = Color3.new(1, 1, 1),
						Parent = panel,
					}, { corner(6) })
					widgets.briGradient = Create("UIGradient", {
						Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1)),
						Parent = briBar,
					})
					widgets.briThumb = Create("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(v, 0.5),
						Size = UDim2.fromOffset(6, 18),
						BackgroundColor3 = Color3.new(1, 1, 1),
						Parent = briBar,
					}, { corner(3), stroke(Color3.new(0, 0, 0), 0.5) })
					y += 22

					-- hex row: preview chip | hex | copy
					widgets.chip = Create("Frame", {
						Position = UDim2.fromOffset(12, y),
						Size = UDim2.fromOffset(28, 28),
						BackgroundColor3 = color,
						Parent = panel,
					}, { corner(6), stroke() })
					local hexFrame = Create("Frame", {
						Position = UDim2.fromOffset(48, y),
						Size = UDim2.fromOffset(136, 28),
						BackgroundColor3 = Colors.ElementActive,
						Parent = panel,
					}, { corner(6) })
					local hexStroke = stroke(Colors.Stroke, 0)
					hexStroke.Parent = hexFrame
					widgets.hex = Create("TextBox", {
						Size = UDim2.fromScale(1, 1),
						FontFace = Fonts.Medium,
						TextSize = 13,
						TextColor3 = Colors.Text,
						Text = Util.ToHex(color),
						PlaceholderText = "#RRGGBB",
						PlaceholderColor3 = Colors.TextDim,
						TextXAlignment = Enum.TextXAlignment.Left,
						Parent = hexFrame,
					}, { padding(0, 10) })
					local copyButton = Create("TextButton", {
						Position = UDim2.fromOffset(192, y),
						Size = UDim2.fromOffset(28, 28),
						BackgroundTransparency = 0,
						BackgroundColor3 = Colors.ElementActive,
						Parent = panel,
					}, { corner(6) })
					local copyIcon = Icons.Create("copy", {
						Size = 14,
						Color = Colors.TextMuted,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Parent = copyButton,
					})
					y += 36

					-- rgb row
					local function rgbBox(index, letter)
						local frame = Create("Frame", {
							Position = UDim2.fromOffset(12 + (index - 1) * 72, y),
							Size = UDim2.fromOffset(64, 28),
							BackgroundColor3 = Colors.ElementActive,
							Parent = panel,
						}, { corner(6) })
						local frameStroke = stroke(Colors.Stroke, 0)
						frameStroke.Parent = frame
						textLabel({
							Position = UDim2.fromOffset(9, 0),
							Size = UDim2.new(0, 12, 1, 0),
							Text = letter,
							TextColor3 = Colors.TextDim,
							TextSize = 11,
							FontFace = Fonts.SemiBold,
							Parent = frame,
						})
						local input = Create("TextBox", {
							Position = UDim2.fromOffset(22, 0),
							Size = UDim2.new(1, -30, 1, 0),
							FontFace = Fonts.Medium,
							TextSize = 13,
							TextColor3 = Colors.Text,
							TextXAlignment = Enum.TextXAlignment.Right,
							Parent = frame,
						})
						return input, frameStroke
					end
					local rBox, rStroke = rgbBox(1, "R")
					local gBox, gStroke = rgbBox(2, "G")
					local bBox, bStroke = rgbBox(3, "B")
					widgets.r, widgets.g, widgets.b = rBox, gBox, bBox
					y += 40

					ui = widgets
					refresh()

					-- interactions
					Util.Drag(sv, popupMaid, {
						OnChange = function(pos)
							local ns = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
							local nv = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
							setHSV(h, ns, nv, false)
						end,
					})
					Util.Drag(hueBar, popupMaid, {
						OnChange = function(pos)
							local nh = math.clamp((pos.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
							setHSV(nh, s, v, false)
						end,
					})
					Util.Drag(briBar, popupMaid, {
						OnChange = function(pos)
							local nv = math.clamp((pos.X - briBar.AbsolutePosition.X) / math.max(briBar.AbsoluteSize.X, 1), 0, 1)
							setHSV(h, s, nv, false)
						end,
					})

					local function focusStroke(box, boxStrokeInstance)
						popupMaid:Give(box.Focused:Connect(function()
							Util.Tween(boxStrokeInstance, Info.Fast, { Color = Theme.GetAccent() })
						end))
						popupMaid:Give(box.FocusLost:Connect(function()
							Util.Tween(boxStrokeInstance, Info.Fast, { Color = Colors.Stroke })
						end))
					end
					focusStroke(widgets.hex, hexStroke)
					focusStroke(rBox, rStroke)
					focusStroke(gBox, gStroke)
					focusStroke(bBox, bStroke)

					popupMaid:Give(widgets.hex.FocusLost:Connect(function()
						local parsed = Util.FromHex(widgets.hex.Text)
						if parsed then
							setColor(parsed, false)
						end
						widgets.hex.Text = Util.ToHex(color)
					end))
					local function rgbCommit()
						local function channel(box, fallback)
							local n = tonumber(box.Text)
							return n and math.clamp(math.floor(n + 0.5), 0, 255) or fallback
						end
						setColor(
							Color3.fromRGB(
								channel(rBox, math.round(color.R * 255)),
								channel(gBox, math.round(color.G * 255)),
								channel(bBox, math.round(color.B * 255))
							),
							false
						)
					end
					for _, box in ipairs({ rBox, gBox, bBox }) do
						popupMaid:Give(box.FocusLost:Connect(rgbCommit))
					end

					-- Roblox exposes no clipboard API to normal scripts, so "copy" selects the hex
					-- text, ready for Ctrl+C, and tells the user.
					popupMaid:Give(copyButton.MouseButton1Click:Connect(function()
						widgets.hex:CaptureFocus()
						widgets.hex.SelectionStart = 1
						widgets.hex.CursorPosition = #widgets.hex.Text + 1
						if ctx.Window and ctx.Window.Notify then
							ctx.Window:Notify({
								Title = "Hex selected",
								Content = "Press Ctrl+C to copy " .. Util.ToHex(color),
								Duration = 2.5,
							})
						end
					end))
					popupMaid:Give(copyButton.MouseEnter:Connect(function()
						Icons.SetColor(copyIcon, Theme.GetAccent(), true)
					end))
					popupMaid:Give(copyButton.MouseLeave:Connect(function()
						Icons.SetColor(copyIcon, Colors.TextMuted, true)
					end))

					return y + 4
				end,
			})
		end
		maid:Give(el.Hit.MouseButton1Click:Connect(open))
		maid:Give(function()
			if opened then
				ctx.Popups:Close(false)
			end
		end)

		function el:Get()
			return color
		end
		function el:GetAlpha()
			return alpha
		end
		function el:GetHex()
			return Util.ToHex(color)
		end
		function el:Set(newColor, silent)
			if typeof(newColor) ~= "Color3" then
				error("NovaUI: ColorPicker:Set expects a Color3, got " .. typeof(newColor), 2)
			end
			setColor(newColor, silent)
		end
		function el:SetAlpha(a, silent)
			alpha = math.clamp(a, 0, 1)
			refresh()
			fireChange(silent)
		end
		function el:_serialize()
			return { r = math.round(color.R * 255), g = math.round(color.G * 255), b = math.round(color.B * 255), a = alpha }
		end
		function el:_deserialize(data)
			if type(data) == "table" and data.r and data.g and data.b then
				alpha = tonumber(data.a) or 1
				setColor(Color3.fromRGB(data.r, data.g, data.b), false)
			end
		end
		return finish(el, opts)
	end

	------------------------------------------------------------------------
	-- Text input
	------------------------------------------------------------------------
	function Container:CreateTextInput(opts)
		Util.Validate("CreateTextInput", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Default = "string?",
			Placeholder = "string?",
			Password = "boolean?",
			MaxLength = "number?",
			Validate = "function?",
			Callback = "function?",
			OnChange = "function?",
			Disabled = "boolean?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		local el = baseElement(self, "TextInput", opts, { ControlWidth = 170, ControlHeight = 28 })
		local maid = el._maid
		local callback = opts.Callback
		local text = opts.Default or ""
		local invalid = false

		local frame = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.ElementActive,
			Parent = el.Control,
		}, { corner(6) })
		local frameStroke = stroke(Colors.Stroke, 0)
		frameStroke.Parent = frame
		local box = Create("TextBox", {
			Size = UDim2.fromScale(1, 1),
			Text = text,
			PlaceholderText = opts.Placeholder or "",
			PlaceholderColor3 = Colors.TextDim,
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextColor3 = Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClipsDescendants = true,
			Parent = frame,
		}, { padding(0, 10) })
		if opts.Password then
			local ok = pcall(function()
				box.MaskedText = true
			end)
			if not ok then
				warn("[NovaUI] TextBox.MaskedText is not available in this Roblox version; password masking disabled.")
			end
		end

		local function validate(value)
			if not opts.Validate then
				return true
			end
			local ok, result = pcall(opts.Validate, value)
			return ok and result ~= false
		end

		local focused = false
		local function render(animate)
			local color = invalid and Colors.Danger or (focused and Theme.GetAccent() or Colors.Stroke)
			Apply(frameStroke, { Color = color }, animate, Info.Fast)
		end
		render(false)
		maid:Give(Theme.OnChange(function()
			render(true)
		end))

		maid:Give(box.Focused:Connect(function()
			focused = true
			render(true)
		end))
		maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
			if opts.MaxLength and #box.Text > opts.MaxLength then
				box.Text = box.Text:sub(1, opts.MaxLength)
				return
			end
			invalid = not validate(box.Text)
			render(true)
			Fire(opts.OnChange, box.Text)
		end))
		maid:Give(box.FocusLost:Connect(function(enterPressed)
			focused = false
			invalid = not validate(box.Text)
			render(true)
			if not invalid and box.Text ~= text then
				text = box.Text
				Fire(callback, text, enterPressed)
				el._changed:Fire(text)
			end
		end))

		function el:Get()
			return box.Text
		end
		function el:Set(newText, silent)
			newText = tostring(newText)
			box.Text = newText
			invalid = not validate(newText)
			render(true)
			if not invalid and newText ~= text then
				text = newText
				if not silent then
					Fire(callback, text, false)
					el._changed:Fire(text)
				end
			end
		end
		function el:IsValid()
			return not invalid
		end
		function el:Focus()
			box:CaptureFocus()
		end
		function el:_serialize()
			return opts.Password and nil or box.Text
		end
		function el:_deserialize(v)
			if type(v) == "string" then
				el:Set(v, false)
			end
		end
		return finish(el, opts)
	end

	-- Compact full-width search field; Callback fires on every change.
	function Container:CreateSearchBar(opts)
		opts = opts or {}
		Util.Validate("CreateSearchBar", opts, { Placeholder = "string?", Callback = "function?" })
		local frame = Create("Frame", {
			Name = "SearchBar",
			BackgroundColor3 = Colors.Element,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = self:_NextOrder(),
			Parent = self.Content,
		}, { corner(8) })
		local frameStroke = stroke(Colors.Stroke, 0)
		frameStroke.Parent = frame
		local icon = Icons.Create("search", {
			Size = 14,
			Color = Colors.TextMuted,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Parent = frame,
		})
		local box = Create("TextBox", {
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -44, 1, 0),
			PlaceholderText = opts.Placeholder or "Search…",
			PlaceholderColor3 = Colors.TextDim,
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextColor3 = Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local el = plainElement(self, "SearchBar", frame)
		local maid = el._maid
		maid:Give(box.Focused:Connect(function()
			Util.Tween(frameStroke, Info.Fast, { Color = Theme.GetAccent() })
			Icons.SetColor(icon, Theme.GetAccent(), true)
		end))
		maid:Give(box.FocusLost:Connect(function()
			Util.Tween(frameStroke, Info.Fast, { Color = Colors.Stroke })
			Icons.SetColor(icon, Colors.TextMuted, true)
		end))
		maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
			Fire(opts.Callback, box.Text)
		end))
		function el:Get()
			return box.Text
		end
		function el:Set(text)
			box.Text = tostring(text)
		end
		return el
	end

	------------------------------------------------------------------------
	-- Keybind
	------------------------------------------------------------------------
	function Container:CreateKeybind(opts)
		Util.Validate("CreateKeybind", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Default = "EnumItem?",
			Callback = "function?", -- fires when the bound key CHANGES
			OnPress = "function?", -- fires when the bound key is PRESSED
			Disabled = "boolean?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		local ctx = self.Ctx
		local el = baseElement(self, "Keybind", opts, { Hit = true, ControlWidth = 104, ControlHeight = 26 })
		local maid = el._maid
		local key = opts.Default
		local listening, hovered = false, false
		local listenConnection

		local box = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.ElementActive,
			Parent = el.Control,
		}, { corner(6) })
		local boxStroke = stroke(Colors.Stroke, 0)
		boxStroke.Parent = box
		local label = textLabel({
			Size = UDim2.fromScale(1, 1),
			FontFace = Fonts.Medium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = box,
		})

		local function render(animate)
			local accent = Theme.GetAccent()
			label.Text = listening and "Press a key…" or (key and key.Name or "None")
			Apply(label, { TextColor3 = listening and accent or (key and Colors.Text or Colors.TextMuted) }, animate, Info.Fast)
			Apply(boxStroke, { Color = (listening or hovered) and accent or Colors.Stroke }, animate, Info.Fast)
			Apply(el.Frame, { BackgroundColor3 = hovered and Colors.ElementHover or Colors.Element }, animate, Info.Fast)
		end
		render(false)
		maid:Give(Theme.OnChange(function()
			render(true)
		end))
		bindHover(el.Hit, maid, function(state)
			hovered = state
			render(true)
		end)

		local function stopListening()
			listening = false
			ctx.Listening = false
			if listenConnection then
				listenConnection:Disconnect()
				listenConnection = nil
			end
			render(true)
		end

		local function setKey(newKey, silent)
			if newKey == key then
				return
			end
			key = newKey
			render(true)
			if not silent then
				Fire(opts.Callback, key)
				el._changed:Fire(key)
			end
		end

		maid:Give(el.Hit.MouseButton1Click:Connect(function()
			if listening or el._disabled then
				return
			end
			listening = true
			ctx.Listening = true
			render(true)
			listenConnection = UserInputService.InputBegan:Connect(function(input)
				local inputType = input.UserInputType
				if inputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape then
						stopListening()
					elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
						setKey(nil, false)
						stopListening()
					else
						setKey(input.KeyCode, false)
						stopListening()
					end
				elseif inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
					-- click anywhere else cancels (the button's own click re-enters listening only after stop)
					task.defer(stopListening)
				end
			end)
		end))
		maid:Give(function()
			if listening then
				stopListening()
			end
		end)

		maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
			if processed or listening or ctx.Listening or el._disabled then
				return
			end
			if key and input.KeyCode == key and not UserInputService:GetFocusedTextBox() then
				Fire(opts.OnPress)
			end
		end))

		function el:Get()
			return key
		end
		function el:Set(newKey, silent)
			if newKey ~= nil and typeof(newKey) ~= "EnumItem" then
				error("NovaUI: Keybind:Set expects an Enum.KeyCode or nil", 2)
			end
			setKey(newKey, silent)
		end
		function el:_serialize()
			return key and key.Name or false
		end
		function el:_deserialize(v)
			if v == false then
				setKey(nil, false)
			elseif type(v) == "string" and Enum.KeyCode[v] then
				setKey(Enum.KeyCode[v], false)
			end
		end
		return finish(el, opts)
	end

	------------------------------------------------------------------------
	-- Progress bar & loader
	------------------------------------------------------------------------
	function Container:CreateProgressBar(opts)
		Util.Validate("CreateProgressBar", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Min = "number?",
			Max = "number?",
			Default = "number?",
			ShowValue = "boolean?",
			Format = "function?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		local min, max = opts.Min or 0, opts.Max or 100
		if min >= max then
			error("NovaUI: CreateProgressBar: 'Min' must be smaller than 'Max'", 2)
		end
		local value = math.clamp(opts.Default or min, min, max)
		local el = baseElement(self, "ProgressBar", opts, { ControlWidth = 56, ControlHeight = 20 })

		local valueLabel = textLabel({
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Colors.TextMuted,
			FontFace = Fonts.Medium,
			TextSize = 12,
			Visible = opts.ShowValue ~= false,
			Parent = el.Control,
		})
		local track = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = Colors.ElementActive,
			LayoutOrder = 2,
			Parent = el.Body,
		}, { corner(3) })
		local fill = Create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.GetAccent(),
			Parent = track,
		}, { corner(3) })
		Theme.Bind(fill, "BackgroundColor3", Theme.GetAccent)

		local function visual(animate)
			local alpha = (value - min) / (max - min)
			Apply(fill, { Size = UDim2.fromScale(alpha, 1) }, animate, Info.Normal)
			if opts.Format then
				local ok, text = pcall(opts.Format, value, alpha)
				valueLabel.Text = ok and tostring(text) or ""
			else
				valueLabel.Text = string.format("%d%%", math.round(alpha * 100))
			end
		end
		visual(false)

		function el:Get()
			return value
		end
		function el:Set(v, silent)
			if type(v) ~= "number" then
				error("NovaUI: ProgressBar:Set expects a number", 2)
			end
			value = math.clamp(v, min, max)
			visual(true)
			if not silent then
				el._changed:Fire(value)
			end
		end
		return finish(el, opts)
	end

	function Container:CreateLoader(opts)
		if type(opts) == "string" then
			opts = { Name = opts }
		end
		Util.Validate("CreateLoader", opts, { Name = "string", Description = "string?", Active = "boolean?" })
		local el = baseElement(self, "Loader", opts, { ControlWidth = 20, ControlHeight = 20 })
		local spinner, spinnerStroke, tween = Icons.Spinner(18)
		spinner.AnchorPoint = Vector2.new(0.5, 0.5)
		spinner.Position = UDim2.fromScale(0.5, 0.5)
		spinner.Parent = el.Control
		Theme.Bind(spinnerStroke, "Color", Theme.GetAccent)
		el._maid:Give(function()
			tween:Cancel()
		end)
		local function setActive(active)
			spinner.Visible = active
			if active then
				tween:Play()
			else
				tween:Pause()
			end
		end
		setActive(opts.Active ~= false)
		function el:SetActive(active)
			setActive(active == true)
		end
		function el:SetText(text)
			el:SetName(text)
		end
		return finish(el, opts)
	end

	------------------------------------------------------------------------
	-- Scrollable, selectable list
	------------------------------------------------------------------------
	function Container:CreateList(opts)
		Util.Validate("CreateList", opts, {
			Name = "string",
			Description = "string?",
			Icon = "string?",
			Items = "table?",
			Default = "any?",
			Height = "number?",
			Searchable = "boolean?",
			Callback = "function?",
			Disabled = "boolean?",
			Tooltip = "string?",
			ContextMenu = "table?",
			Flag = "string?",
		})
		local el = baseElement(self, "List", opts, opts.Searchable and { ControlWidth = 130, ControlHeight = 26 } or nil)
		local maid = el._maid
		local items = table.clone(opts.Items or {})
		local selected = nil
		local rows = {}
		local query = ""

		local searchBox
		if opts.Searchable then
			local frame = Create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Colors.ElementActive,
				Parent = el.Control,
			}, { corner(6) })
			searchBox = Create("TextBox", {
				Size = UDim2.fromScale(1, 1),
				PlaceholderText = "Filter…",
				PlaceholderColor3 = Colors.TextDim,
				FontFace = Fonts.Regular,
				TextSize = 12,
				TextColor3 = Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = frame,
			}, { padding(0, 8) })
		end

		local scroller = Create("ScrollingFrame", {
			Name = "Items",
			Size = UDim2.new(1, 0, 0, opts.Height or 140),
			BackgroundTransparency = 0,
			BackgroundColor3 = Colors.Background,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Colors.TextDim,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			LayoutOrder = 2,
			Parent = el.Body,
		}, { corner(6), stroke(Colors.Stroke, 0.3), padding(4), listLayout(Enum.FillDirection.Vertical, 2) })
		local empty = textLabel({
			Size = UDim2.new(1, 0, 0, 28),
			Text = "No items",
			TextColor3 = Colors.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 99999,
			Parent = scroller,
		})

		local function renderAll(animate)
			for _, row in ipairs(rows) do
				row.Selected = row.Item == selected
				row.Render(animate)
			end
		end

		local function set(item, silent)
			if item ~= nil and not table.find(items, item) then
				warn(("[NovaUI] List '%s': '%s' is not an item"):format(opts.Name, tostring(item)))
				return
			end
			if item == selected then
				return
			end
			selected = item
			renderAll(true)
			if not silent then
				Fire(opts.Callback, selected)
				el._changed:Fire(selected)
			end
		end

		local function rebuild()
			for _, row in ipairs(rows) do
				row.Button:Destroy()
			end
			table.clear(rows)
			for index, item in ipairs(items) do
				local row = optionRow(scroller, item, 28)
				row.Item = item
				row.Text = tostring(item)
				row.Button.LayoutOrder = index
				row.Button.MouseButton1Click:Connect(function()
					if not el._disabled then
						set(item, false)
					end
				end)
				table.insert(rows, row)
			end
			if selected ~= nil and not table.find(items, selected) then
				selected = nil
			end
			renderAll(false)
			local visible = filterRows(rows, query)
			empty.Visible = visible == 0
		end
		rebuild()
		if opts.Default ~= nil and table.find(items, opts.Default) then
			selected = opts.Default
			renderAll(false)
		end

		if searchBox then
			maid:Give(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
				query = searchBox.Text
				empty.Visible = filterRows(rows, query) == 0
			end))
		end
		maid:Give(Theme.OnChange(function()
			renderAll(true)
		end))

		function el:Get()
			return selected
		end
		function el:Set(item, silent)
			set(item, silent)
		end
		function el:GetItems()
			return table.clone(items)
		end
		function el:SetItems(newItems)
			items = table.clone(newItems)
			rebuild()
		end
		function el:AddItem(item)
			table.insert(items, item)
			rebuild()
		end
		function el:RemoveItem(item)
			local index = table.find(items, item)
			if index then
				table.remove(items, index)
				rebuild()
			end
		end
		function el:_serialize()
			return selected
		end
		function el:_deserialize(v)
			if v == nil or table.find(items, v) then
				set(v, false)
			end
		end
		return finish(el, opts)
	end

	------------------------------------------------------------------------
	-- Expandable section (is itself a container)
	------------------------------------------------------------------------
	function Container:CreateExpandable(opts)
		Util.Validate("CreateExpandable", opts, { Name = "string", Icon = "string?", Open = "boolean?" })
		local maid = Util.Maid.new()
		local isOpen = opts.Open == true
		local token = 0

		local frame = Create("Frame", {
			Name = "Expandable_" .. opts.Name,
			BackgroundColor3 = Colors.Panel,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = self:_NextOrder(),
			Parent = self.Content,
		}, { corner(8), stroke(Colors.Stroke, 0.2), listLayout(Enum.FillDirection.Vertical, 0) })
		maid:Give(frame)

		local headerButton = Create("TextButton", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 1,
			Parent = frame,
		})
		local iconObj
		if opts.Icon then
			iconObj = Icons.Create(opts.Icon, {
				Size = 16,
				Color = Colors.TextMuted,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Parent = headerButton,
			})
		end
		local title = textLabel({
			Position = UDim2.fromOffset(opts.Icon and 36 or 14, 0),
			Size = UDim2.new(1, -60, 1, 0),
			Text = opts.Name,
			FontFace = Fonts.Medium,
			Parent = headerButton,
		})
		local chevron = Icons.Create("chevron-down", {
			Size = 12,
			Color = Colors.TextMuted,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -18, 0.5, 0),
			Parent = headerButton,
		})
		chevron.Rotation = isOpen and 180 or 0

		local wrapper = Create("Frame", {
			Name = "Wrapper",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			Parent = frame,
		})
		local content = Create("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = wrapper,
		}, { padding(2, 8, 10, 8), listLayout(Enum.FillDirection.Vertical, 8) })
		if isOpen then
			wrapper.AutomaticSize = Enum.AutomaticSize.Y
		end

		local el = {
			Kind = "Expandable",
			Container = self,
			Frame = frame,
			_maid = maid,
			_destroyed = false,
		}
		Container.Init(el, self.Ctx, content, self.Scroller, self.Tab)
		setmetatable(el, { __index = Container })

		local hovered = false
		local function renderHeader(animate)
			Apply(title, { TextColor3 = hovered and Colors.Text or Colors.Text }, animate, Info.Fast)
			Icons.SetColor(chevron, hovered and Theme.GetAccent() or Colors.TextMuted, animate)
			if iconObj then
				Icons.SetColor(iconObj, isOpen and Theme.GetAccent() or Colors.TextMuted, animate)
			end
		end
		renderHeader(false)
		bindHover(headerButton, maid, function(state)
			hovered = state
			renderHeader(true)
		end)
		maid:Give(Theme.OnChange(function()
			renderHeader(true)
		end))

		function el:SetOpen(open)
			open = open == true
			if open == isOpen then
				return
			end
			isOpen = open
			token += 1
			local mine = token
			Apply(chevron, { Rotation = open and 180 or 0 }, true, Info.Normal)
			renderHeader(true)
			-- freeze the current height so the tween starts from where we are
			local current = wrapper.AbsoluteSize.Y
			Util.Cancel(wrapper, { Size = true })
			wrapper.Size = UDim2.new(1, 0, 0, current)
			wrapper.AutomaticSize = Enum.AutomaticSize.None
			if open then
				Util.Tween(wrapper, Info.Normal, { Size = UDim2.new(1, 0, 0, content.AbsoluteSize.Y) })
				task.delay(0.24, function()
					if token == mine and isOpen and wrapper.Parent then
						wrapper.AutomaticSize = Enum.AutomaticSize.Y
						wrapper.Size = UDim2.new(1, 0, 0, 0)
					end
				end)
			else
				Util.Tween(wrapper, Info.Normal, { Size = UDim2.new(1, 0, 0, 0) })
			end
		end
		function el:Toggle()
			self:SetOpen(not isOpen)
		end
		function el:IsOpen()
			return isOpen
		end
		function el:SetVisible(visible)
			frame.Visible = visible
		end
		function el:Destroy()
			if self._destroyed then
				return
			end
			self._destroyed = true
			self:Clear()
			self.Container:_Unregister(self)
			maid:Clean()
		end

		maid:Give(headerButton.MouseButton1Click:Connect(function()
			el:SetOpen(not isOpen)
		end))

		self:_Register(el, { _noSearch = true })
		return el
	end

	return Container
end)()

------------------------------------------------------------------------
-- Popups
------------------------------------------------------------------------
local PopupsModule = (function()
	--[[
		NovaUI.Popups
		A single top-most layer (outside the window, so nothing can clip it) hosting:
		  * Popups   – dropdown lists, colour picker panels, context menus (one open at a time)
		  * Tooltip  – one shared tooltip instance
	]]

	local UserInputService = game:GetService("UserInputService")

	local Util = UtilModule
	local Theme = ThemeModule

	local Create, Info = Util.Create, Util.Info
	local Colors, Fonts = Theme.Colors, Theme.Fonts

	local function corner(r)
		return Create("UICorner", { CornerRadius = UDim.new(0, r) })
	end

	local function stroke(color, transparency)
		return Create("UIStroke", {
			Color = color or Colors.Stroke,
			Transparency = transparency or 0,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end

	------------------------------------------------------------------------
	-- Popups
	------------------------------------------------------------------------
	local Popups = {}
	Popups.__index = Popups

	function Popups.new(gui)
		local self = setmetatable({}, Popups)
		self.Gui = gui
		self.Layer = Create("Frame", {
			Name = "PopupLayer",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 50,
			Parent = gui,
		})
		-- Full-screen catcher: any click outside the popup closes it (and is swallowed).
		self.Catcher = Create("TextButton", {
			Name = "Catcher",
			Size = UDim2.fromScale(1, 1),
			Active = true,
			Visible = false,
			ZIndex = 1,
			Parent = self.Layer,
		})
		self.Catcher.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if
				t == Enum.UserInputType.MouseButton1
				or t == Enum.UserInputType.MouseButton2
				or t == Enum.UserInputType.Touch
			then
				-- InputBegan also fires for objects *behind* the popup, so a click on the panel
				-- (colour square, sliders, text boxes…) must be filtered out by position.
				local current = self._current
				if current and current.panel.Parent then
					local point = Util.InputPoint(input)
					local pos, size = current.panel.AbsolutePosition, current.panel.AbsoluteSize
					if point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y then
						return
					end
				end
				self:Close()
			end
		end)
		return self
	end

	function Popups:IsOpen()
		return self._current ~= nil
	end

	--[[
		cfg = {
			Anchor   = GuiObject      -- popup is placed below/above it (auto flips near screen edges)
			Position = Vector2        -- alternative to Anchor (context menus)
			Width    = number
			Align    = "Left" | "Right"
			MaxHeight= number
			Build    = function(panel, maid, close) -> desiredHeight
			OnClose  = function()
		}
	]]
	function Popups:Open(cfg)
		self:Close(false)

		local maid = Util.Maid.new()
		local viewport = self.Gui.AbsoluteSize
		local panel = Create("CanvasGroup", {
			Name = "Popup",
			Active = true, -- sink clicks so plain Frames inside (colour picker) don't fall through to the Catcher
			BackgroundColor3 = Colors.Panel,
			GroupTransparency = 1,
			ZIndex = 2,
			Parent = self.Layer,
		}, { corner(8), stroke() })

		local desired = cfg.Build(panel, maid, function()
			self:Close()
		end) or 100
		local width = cfg.Width or 180

		local x, belowStart, aboveEnd
		if cfg.Anchor then
			local pos, size = cfg.Anchor.AbsolutePosition, cfg.Anchor.AbsoluteSize
			x = cfg.Align == "Right" and (pos.X + size.X - width) or pos.X
			belowStart = pos.Y + size.Y + 4
			aboveEnd = pos.Y - 4
		else
			x = cfg.Position.X
			belowStart = cfg.Position.Y
			aboveEnd = cfg.Position.Y
		end
		x = math.clamp(x, 8, math.max(8, viewport.X - width - 8))

		local spaceBelow = viewport.Y - belowStart - 8
		local spaceAbove = aboveEnd - 8
		local height = math.min(desired, cfg.MaxHeight or 260)
		local up = height > spaceBelow and spaceAbove > spaceBelow
		height = math.max(math.min(height, up and spaceAbove or spaceBelow), 32)

		local y = up and aboveEnd or belowStart
		local slide = up and 6 or -6
		panel.AnchorPoint = Vector2.new(0, up and 1 or 0)
		panel.Size = UDim2.fromOffset(width, height)
		panel.Position = UDim2.fromOffset(x, y + slide)
		Util.Tween(panel, Info.Fast, { GroupTransparency = 0 })
		Util.Tween(panel, Info.Normal, { Position = UDim2.fromOffset(x, y) })

		self.Catcher.Visible = true
		self._current = { panel = panel, maid = maid, cfg = cfg }
		return panel
	end

	function Popups:Close(animate)
		local current = self._current
		if not current then
			return
		end
		self._current = nil
		self.Catcher.Visible = false
		if current.cfg.OnClose then
			Util.Fire(current.cfg.OnClose)
		end
		local panel = current.panel
		if animate == false then
			current.maid:Clean()
			panel:Destroy()
			return
		end
		Util.Tween(panel, Info.Fast, { GroupTransparency = 1 })
		task.delay(0.15, function()
			current.maid:Clean()
			panel:Destroy()
		end)
	end

	-- items: { { Name = "Copy", Icon = "copy", Callback = fn, Danger = true }, "-" (separator), ... }
	function Popups:ContextMenu(items, position)
		self:Open({
			Position = position,
			Width = 176,
			MaxHeight = 360,
			Build = function(panel, maid, close)
				local holder = Create("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Parent = panel,
				}, {
					Create("UIPadding", {
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					}),
					Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
				})
				local total = 8
				for i, item in ipairs(items) do
					if item == "-" then
						Create("Frame", {
							BackgroundColor3 = Colors.Stroke,
							Size = UDim2.new(1, -8, 0, 1),
							LayoutOrder = i,
							Parent = holder,
						})
						total += 3
					else
						local button = Create("TextButton", {
							BackgroundColor3 = Colors.ElementHover,
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 0, 28),
							LayoutOrder = i,
							Parent = holder,
						}, { corner(6) })
						Create("TextLabel", {
							Position = UDim2.fromOffset(10, 0),
							Size = UDim2.new(1, -20, 1, 0),
							Text = item.Name or "?",
							FontFace = Fonts.Regular,
							TextSize = 13,
							TextColor3 = item.Danger and Colors.Danger or Colors.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							Parent = button,
						})
						button.MouseEnter:Connect(function()
							Util.Tween(button, Info.Fast, { BackgroundTransparency = 0 })
						end)
						button.MouseLeave:Connect(function()
							Util.Tween(button, Info.Fast, { BackgroundTransparency = 1 })
						end)
						button.MouseButton1Click:Connect(function()
							close()
							Util.Fire(item.Callback)
						end)
						total += 30
					end
				end
				return total
			end,
		})
	end

	------------------------------------------------------------------------
	-- Tooltip
	------------------------------------------------------------------------
	local Tooltip = {}
	Tooltip.__index = Tooltip

	function Tooltip.new(layer)
		local self = setmetatable({}, Tooltip)
		self.Layer = layer
		self._token = 0
		self.Frame = Create("CanvasGroup", {
			Name = "Tooltip",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Colors.Panel,
			GroupTransparency = 1,
			Visible = false,
			ZIndex = 20,
			Parent = layer,
		}, {
			corner(6),
			stroke(),
			Create("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
		})
		self.Label = Create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			FontFace = Fonts.Regular,
			TextSize = 12,
			TextColor3 = Colors.Text,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = self.Frame,
		}, { Create("UISizeConstraint", { MaxSize = Vector2.new(240, math.huge) }) })
		return self
	end

	function Tooltip:Move()
		local mouse = UserInputService:GetMouseLocation()
		local viewport = self.Layer.AbsoluteSize
		local flipX = mouse.X > viewport.X * 0.6
		local flipY = mouse.Y > viewport.Y * 0.85
		self.Frame.AnchorPoint = Vector2.new(flipX and 1 or 0, flipY and 1 or 0)
		self.Frame.Position = UDim2.fromOffset(mouse.X + (flipX and -12 or 14), mouse.Y + (flipY and -14 or 18))
	end

	function Tooltip:Show(text, owner)
		if text == nil or text == "" then
			return
		end
		self._token += 1
		self.Owner = owner
		self.Label.Text = tostring(text)
		self.Frame.Visible = true
		self:Move()
		self.Visible = true
		Util.Tween(self.Frame, Info.Fast, { GroupTransparency = 0 })
	end

	function Tooltip:Hide(owner)
		if owner and self.Owner ~= owner then
			return
		end
		self._token += 1
		local my = self._token
		self.Visible = false
		self.Owner = nil
		Util.Tween(self.Frame, Info.Fast, { GroupTransparency = 1 })
		task.delay(0.14, function()
			if self._token == my then
				self.Frame.Visible = false
			end
		end)
	end

	function Tooltip:Attach(object, text, maid)
		local hoverToken = 0
		maid:Give(object.MouseEnter:Connect(function()
			hoverToken += 1
			local mine = hoverToken
			task.delay(0.45, function()
				if hoverToken == mine and self.Frame.Parent then
					self:Show(type(text) == "function" and text() or text, object)
				end
			end)
		end))
		maid:Give(object.MouseLeave:Connect(function()
			hoverToken += 1
			self:Hide(object)
		end))
		maid:Give(object.MouseMoved:Connect(function()
			if self.Visible and self.Owner == object then
				self:Move()
			end
		end))
		maid:Give(function()
			hoverToken += 1
			self:Hide(object)
		end)
	end

	return { Popups = Popups, Tooltip = Tooltip }
end)()

------------------------------------------------------------------------
-- Overlays
------------------------------------------------------------------------
local OverlaysModule = (function()
	--[[
		NovaUI.Overlays
		  * Notifications – stacked toasts with slide/fade in & out and a countdown bar
		  * Dialog        – modal confirmation dialog
	]]

	local UserInputService = game:GetService("UserInputService")

	local Util = UtilModule
	local Theme = ThemeModule
	local Icons = IconsModule

	local Create, Info = Util.Create, Util.Info
	local Colors, Fonts = Theme.Colors, Theme.Fonts

	local function corner(r)
		return Create("UICorner", { CornerRadius = UDim.new(0, r) })
	end

	local function stroke(color, transparency)
		return Create("UIStroke", {
			Color = color or Colors.Stroke,
			Transparency = transparency or 0,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end

	------------------------------------------------------------------------
	-- Notifications
	------------------------------------------------------------------------
	local Notifications = {}
	Notifications.__index = Notifications

	local TOAST_W = 320
	local TEXT_W = TOAST_W - 42 - 30
	local MAX_VISIBLE = 5

	local TYPES = {
		Info = { Icon = "info" },
		Success = { Icon = "check", Color = Colors.Success },
		Warning = { Icon = "info", Color = Colors.Warning },
		Error = { Icon = "x", Color = Colors.Danger },
	}

	function Notifications.new(gui)
		local self = setmetatable({}, Notifications)
		self._active = {}
		self._order = 0
		self.Container = Create("Frame", {
			Name = "Notifications",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -16),
			Size = UDim2.new(0, TOAST_W, 1, -32),
			ZIndex = 60,
			Parent = gui,
		}, {
			Create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 8),
			}),
		})
		return self
	end

	-- opts: Title, Content, Duration (seconds, 0 = persistent), Type ("Info"|"Success"|"Warning"|"Error")
	function Notifications:Notify(opts)
		Util.Validate("Notify", opts, {
			Title = "string?",
			Content = "string?",
			Duration = "number?",
			Type = "string?",
		})
		local typeName = opts.Type or "Info"
		local typeInfo = TYPES[typeName]
		if not typeInfo then
			error("NovaUI: Notify: unknown Type '" .. tostring(typeName) .. "' (Info, Success, Warning, Error)", 2)
		end
		local title = opts.Title or typeName
		local content = opts.Content
		local duration = opts.Duration or 4

		-- cap the stack
		while #self._active >= MAX_VISIBLE do
			local oldest = table.remove(self._active, 1)
			oldest.Dismiss()
		end

		local titleHeight = Util.TextSize(title, Fonts.SemiBold, 13, TEXT_W).Y
		local contentHeight = content and Util.TextSize(content, Fonts.Regular, 12, TEXT_W).Y or 0
		local height = math.max(50, 13 + titleHeight + (contentHeight > 0 and (3 + contentHeight) or 0) + 13)

		self._order += 1
		local holder = Create("Frame", {
			Name = "ToastHolder",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = self._order,
			Parent = self.Container,
		})
		local toast = Create("CanvasGroup", {
			Name = "Toast",
			BackgroundColor3 = Colors.Panel,
			Size = UDim2.new(1, 0, 0, height),
			Position = UDim2.fromOffset(TOAST_W + 20, 0),
			GroupTransparency = 1,
			Parent = holder,
		}, { corner(8), stroke() })

		local accentBar = Create("Frame", { Size = UDim2.new(0, 3, 1, 0), Parent = toast })
		local icon = Icons.Create(typeInfo.Icon, {
			Size = 16,
			Position = UDim2.fromOffset(16, 13),
			Parent = toast,
		})
		if typeInfo.Color then
			accentBar.BackgroundColor3 = typeInfo.Color
			Icons.SetColor(icon, typeInfo.Color)
		else
			Theme.Bind(accentBar, "BackgroundColor3", Theme.GetAccent)
			Icons.SetColor(icon, Theme.GetAccent())
		end
		local iconConnection = not typeInfo.Color and Theme.OnChange(function()
			Icons.SetColor(icon, Theme.GetAccent(), true)
		end)

		Create("TextLabel", {
			Position = UDim2.fromOffset(42, 13),
			Size = UDim2.fromOffset(TEXT_W, titleHeight),
			Text = title,
			FontFace = Fonts.SemiBold,
			TextSize = 13,
			TextColor3 = Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Parent = toast,
		})
		if content then
			Create("TextLabel", {
				Position = UDim2.fromOffset(42, 16 + titleHeight),
				Size = UDim2.fromOffset(TEXT_W, contentHeight),
				Text = content,
				FontFace = Fonts.Regular,
				TextSize = 12,
				TextColor3 = Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				Parent = toast,
			})
		end

		local closeButton = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(20, 20),
			Parent = toast,
		})
		local closeIcon = Icons.Create("x", {
			Size = 10,
			Color = Colors.TextDim,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = closeButton,
		})
		closeButton.MouseEnter:Connect(function()
			Icons.SetColor(closeIcon, Colors.Text, true)
		end)
		closeButton.MouseLeave:Connect(function()
			Icons.SetColor(closeIcon, Colors.TextDim, true)
		end)

		local progress
		if duration > 0 then
			progress = Create("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = typeInfo.Color or Theme.GetAccent(),
				BackgroundTransparency = 0.35,
				Parent = toast,
			})
		end

		local handle = {}
		local dismissed = false
		function handle.Dismiss()
			if dismissed then
				return
			end
			dismissed = true
			if iconConnection then
				iconConnection:Disconnect()
			end
			local index = table.find(self._active, handle)
			if index then
				table.remove(self._active, index)
			end
			Util.Tween(toast, Info.Fast, { GroupTransparency = 1 })
			Util.Tween(toast, Info.Normal, { Position = UDim2.fromOffset(TOAST_W + 20, 0) })
			task.delay(0.14, function()
				Util.Tween(holder, Info.Normal, { Size = UDim2.new(1, 0, 0, 0) })
			end)
			task.delay(0.5, function()
				holder:Destroy()
			end)
		end
		table.insert(self._active, handle)

		closeButton.MouseButton1Click:Connect(handle.Dismiss)

		-- enter
		Util.Tween(holder, Info.Normal, { Size = UDim2.new(1, 0, 0, height) })
		Util.Tween(toast, Info.Normal, { Position = UDim2.fromOffset(0, 0) })
		Util.Tween(toast, Info.Normal, { GroupTransparency = 0 })

		if progress then
			Util.Tween(
				progress,
				TweenInfo.new(duration, Enum.EasingStyle.Linear),
				{ Size = UDim2.new(0, 0, 0, 2) }
			)
			task.delay(duration, handle.Dismiss)
		end
		return handle
	end

	function Notifications:DismissAll()
		local copy = table.clone(self._active)
		for _, handle in ipairs(copy) do
			handle.Dismiss()
		end
	end

	------------------------------------------------------------------------
	-- Confirmation dialog
	------------------------------------------------------------------------
	local Dialog = {}

	local function dialogButton(parent, text, primary, danger, order)
		local function resting()
			if primary then
				return danger and Colors.Danger or Theme.GetAccent()
			end
			return Colors.ElementActive
		end
		local button = Create("TextButton", {
			Size = UDim2.fromOffset(0, 32),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = resting(),
			Text = text,
			FontFace = Fonts.SemiBold,
			TextSize = 13,
			TextColor3 = primary and (danger and Color3.new(1, 1, 1) or Theme.OnAccent()) or Colors.Text,
			LayoutOrder = order,
			Parent = parent,
		}, {
			corner(6),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		})
		button.MouseEnter:Connect(function()
			local hover = primary and (danger and Colors.Danger:Lerp(Color3.new(1, 1, 1), 0.12) or Theme.AccentHover())
				or Colors.ElementHover
			Util.Tween(button, Info.Fast, { BackgroundColor3 = hover })
		end)
		button.MouseLeave:Connect(function()
			Util.Tween(button, Info.Fast, { BackgroundColor3 = resting() })
		end)
		return button
	end

	-- opts: Title, Message, ConfirmText, CancelText, Danger, Callback(confirmed:boolean), OnConfirm, OnCancel
	function Dialog.Open(gui, opts)
		Util.Validate("Confirm", opts, {
			Title = "string?",
			Message = "string?",
			ConfirmText = "string?",
			CancelText = "string?",
			Danger = "boolean?",
			Callback = "function?",
			OnConfirm = "function?",
			OnCancel = "function?",
		})
		local maid = Util.Maid.new()
		local closed = false

		local overlay = Create("TextButton", {
			Name = "DialogOverlay",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Active = true,
			ZIndex = 80,
			Parent = gui,
		})
		local card = Create("CanvasGroup", {
			Name = "Dialog",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(360, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Colors.Panel,
			GroupTransparency = 1,
			Parent = overlay,
		}, {
			corner(10),
			stroke(),
			Create("UIScale", { Scale = 0.95 }),
			Create("UIPadding", {
				PaddingTop = UDim.new(0, 18),
				PaddingBottom = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
			}),
			Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Title or "Are you sure?",
			FontFace = Fonts.SemiBold,
			TextSize = 16,
			TextColor3 = Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = 1,
			Parent = card,
		})
		if opts.Message then
			Create("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = opts.Message,
				FontFace = Fonts.Regular,
				TextSize = 13,
				TextColor3 = Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = 2,
				Parent = card,
			})
		end
		local buttons = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = card,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})

		local function close(confirmed)
			if closed then
				return
			end
			closed = true
			maid:Clean()
			Util.Tween(overlay, Info.Fast, { BackgroundTransparency = 1 })
			Util.Tween(card, Info.Fast, { GroupTransparency = 1 })
			task.delay(0.15, function()
				overlay:Destroy()
			end)
			if confirmed then
				Util.Fire(opts.OnConfirm)
			else
				Util.Fire(opts.OnCancel)
			end
			Util.Fire(opts.Callback, confirmed)
		end

		local cancel = dialogButton(buttons, opts.CancelText or "Cancel", false, false, 1)
		local confirm = dialogButton(buttons, opts.ConfirmText or "Confirm", true, opts.Danger == true, 2)
		cancel.MouseButton1Click:Connect(function()
			close(false)
		end)
		confirm.MouseButton1Click:Connect(function()
			close(true)
		end)
		maid:Give(UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape then
				close(false)
			end
		end))
		maid:Give(Theme.OnChange(function()
			if not opts.Danger then
				Util.Tween(confirm, Info.Fast, { BackgroundColor3 = Theme.GetAccent() })
				confirm.TextColor3 = Theme.OnAccent()
			end
		end))

		Util.Tween(overlay, Info.Normal, { BackgroundTransparency = 0.5 })
		Util.Tween(card, Info.Normal, { GroupTransparency = 0 })
		Util.Tween(card.UIScale, Info.Normal, { Scale = 1 })

		return { Close = close }
	end

	return { Notifications = Notifications, Dialog = Dialog }
end)()

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local WindowModule = (function()
	--[[
		NovaUI.Window
		The main window: draggable/resizable shell, title bar, sidebar with tabs, sticky page header,
		global search, built-in Settings tab, notifications/dialog entry points and config export/import.
	]]

	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local HttpService = game:GetService("HttpService")

	local Util = UtilModule
	local Theme = ThemeModule
	local Icons = IconsModule
	local Components = ComponentsModule
	local PopupModule = PopupsModule
	local Overlays = OverlaysModule

	local Create, Apply, Info = Util.Create, Util.Apply, Util.Info
	local Colors, Fonts = Theme.Colors, Theme.Fonts

	local TITLE_H = 44
	local SIDEBAR_W = 184
	local SIDEBAR_COMPACT = 58
	local COMPACT_BELOW = 540

	local function corner(r)
		return Create("UICorner", { CornerRadius = UDim.new(0, r) })
	end

	local function stroke(color, transparency)
		return Create("UIStroke", {
			Color = color or Colors.Stroke,
			Transparency = transparency or 0,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end

	local function padding(top, right, bottom, left)
		return Create("UIPadding", {
			PaddingTop = UDim.new(0, top),
			PaddingRight = UDim.new(0, right or top),
			PaddingBottom = UDim.new(0, bottom or top),
			PaddingLeft = UDim.new(0, left or right or top),
		})
	end

	local function viewportOf(gui)
		local size = gui.AbsoluteSize
		if size.X < 2 or size.Y < 2 then
			local camera = workspace.CurrentCamera
			return camera and camera.ViewportSize or Vector2.new(1280, 720)
		end
		return size
	end

	------------------------------------------------------------------------
	-- Tab class (inherits every Create* method from Components)
	------------------------------------------------------------------------
	local Tab = {}
	Tab.__index = Tab
	setmetatable(Tab, { __index = Components })

	function Tab:Select()
		self.Window:SelectTab(self)
	end

	function Tab:OnCountChanged()
		if self.Empty then
			self.Empty.Visible = self._count == 0
		end
	end

	function Tab:SetBadge(value)
		self.Badge = value
		if self._RenderBadge then
			self._RenderBadge()
		end
	end

	function Tab:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		local window = self.Window
		self:Clear()
		local index = table.find(window._allTabs, self)
		if index then
			table.remove(window._allTabs, index)
		end
		index = table.find(window.Tabs, self)
		if index then
			table.remove(window.Tabs, index)
		end
		self.Maid:Clean()
		if window.Selected == self then
			window.Selected = nil
			window:SelectTab(window.Tabs[1] or window.SettingsTab)
		end
	end

	------------------------------------------------------------------------
	-- Window class
	------------------------------------------------------------------------
	local Window = {}
	Window.__index = Window

	function Window.new(library, opts)
		opts = opts or {}
		Util.Validate("CreateWindow", opts, {
			Title = "string?",
			Subtitle = "string?",
			Icon = "string?",
			AccentColor = "Color3?",
			Size = "Vector2?",
			MinSize = "Vector2?",
			ToggleKey = "EnumItem?",
			Parent = "Instance?",
			Name = "string?",
			DisplayOrder = "number?",
			Visible = "boolean?",
		})
		if not RunService:IsClient() then
			error("NovaUI must run on the client (use a LocalScript).", 2)
		end
		if opts.AccentColor then
			Theme.SetAccent(opts.AccentColor)
		end

		local parent = opts.Parent
		if not parent then
			local player = Players.LocalPlayer
			if not player then
				error("NovaUI: no LocalPlayer found – run this from a LocalScript or pass `Parent`.", 2)
			end
			parent = player:WaitForChild("PlayerGui")
		end

		local self = setmetatable({}, Window)
		self.Library = library
		self.Maid = Util.Maid.new()
		self.Tabs = {}
		self._allTabs = {}
		self._tabOrder = 0
		self.Flags = {}
		self.Search = {}
		self.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
		self.MinSize = opts.MinSize or Vector2.new(460, 340)
		self.Destroyed = false
		self.NotificationsEnabled = true
		self._open = false
		self._minimized = false
		self._token = 0
		self._compact = false
		self._forceCompact = false
		self.OnOpen = Util.Signal.new()
		self.OnClose = Util.Signal.new()
		self.OnDestroy = Util.Signal.new()

		local gui = Create("ScreenGui", {
			Name = opts.Name or "NovaUI",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			IgnoreGuiInset = true,
			DisplayOrder = opts.DisplayOrder or 100,
			Parent = parent,
		})
		self.Gui = gui
		self.Maid:Give(gui)

		self.Popups = PopupModule.Popups.new(gui)
		self.Tooltip = PopupModule.Tooltip.new(self.Popups.Layer)
		self.Notifications = Overlays.Notifications.new(gui)
		self.Ctx = {
			Window = self,
			Popups = self.Popups,
			Tooltip = self.Tooltip,
			Flags = self.Flags,
			Search = self.Search,
			Listening = false,
		}

		-- size / position -------------------------------------------------
		local viewport = viewportOf(gui)
		local wanted = opts.Size or Vector2.new(680, 460)
		self._size = Vector2.new(
			math.clamp(wanted.X, math.min(self.MinSize.X, viewport.X - 16), math.max(viewport.X - 16, 200)),
			math.clamp(wanted.Y, math.min(self.MinSize.Y, viewport.Y - 16), math.max(viewport.Y - 16, 200))
		)
		self._left = (viewport.X - self._size.X) / 2
		self._top = (viewport.Y - self._size.Y) / 2

		-- holder + shadow + main ----------------------------------------
		local holder = Create("Frame", {
			Name = "Window",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(self._size.X, self._size.Y),
			Visible = false,
			Parent = gui,
		}, { Create("UIScale", { Scale = 0.95 }) })
		self.Holder = holder
		self.Scale = holder.UIScale

		self._shadow = {}
		for i = 1, 4 do
			table.insert(
				self._shadow,
				Create("Frame", {
					Name = "Shadow" .. i,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, 6),
					Size = UDim2.new(1, i * 10, 1, i * 10),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 1,
					ZIndex = 0,
					Parent = holder,
				}, { corner(12 + i * 6) })
			)
		end

		local main = Create("Frame", {
			Name = "Main",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.Chrome,
			ClipsDescendants = true,
			Parent = holder,
		}, { corner(12), stroke(Colors.Stroke, 0) })
		self.Main = main

		-- opaque "curtain" used for the fade in / out (avoids CanvasGroup resolution limits)
		self.Curtain = Create("Frame", {
			Name = "Curtain",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.Chrome,
			ZIndex = 100,
			Parent = main,
		}, { corner(12) })

		-- title bar ---------------------------------------------------------
		local titleBar = Create("Frame", {
			Name = "TitleBar",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, TITLE_H),
			Parent = main,
		})
		self.TitleBar = titleBar

		local title = opts.Title or "NovaUI"
		if opts.Icon then
			local logo = Icons.Create(opts.Icon, {
				Size = 20,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 16, 0.5, 0),
				Parent = titleBar,
			})
			Icons.SetColor(logo, Theme.GetAccent())
			self.Maid:Give(Theme.OnChange(function()
				Icons.SetColor(logo, Theme.GetAccent(), true)
			end))
		else
			local logo = Create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 14, 0.5, 0),
				Size = UDim2.fromOffset(24, 24),
				Parent = titleBar,
			}, { corner(7) })
			Theme.Bind(logo, "BackgroundColor3", Theme.GetAccent)
			local letter = Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Text = string.upper(string.sub(title, 1, 1)),
				FontFace = Fonts.Bold,
				TextSize = 13,
				TextColor3 = Theme.OnAccent(),
				Parent = logo,
			})
			self.Maid:Give(Theme.OnChange(function()
				letter.TextColor3 = Theme.OnAccent()
			end))
		end

		local titleHolder = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(48, 0),
			Size = UDim2.new(1, -150, 1, 0),
			Parent = titleBar,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		self.TitleLabel = Create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			Text = title,
			FontFace = Fonts.SemiBold,
			TextSize = 14,
			TextColor3 = Colors.Text,
			LayoutOrder = 1,
			Parent = titleHolder,
		})
		self.SubtitleLabel = Create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			Text = opts.Subtitle or "",
			FontFace = Fonts.Regular,
			TextSize = 12,
			TextColor3 = Colors.TextDim,
			Visible = (opts.Subtitle or "") ~= "",
			LayoutOrder = 2,
			Parent = titleHolder,
		})

		local controls = Create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(68, 28),
			Parent = titleBar,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local function titleButton(iconName, order, danger)
			local button = Create("TextButton", {
				Size = UDim2.fromOffset(32, 28),
				BackgroundColor3 = danger and Colors.Danger or Colors.ElementHover,
				BackgroundTransparency = 1,
				LayoutOrder = order,
				Parent = controls,
			}, { corner(7) })
			local icon = Icons.Create(iconName, {
				Size = 12,
				Color = Colors.TextMuted,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Parent = button,
			})
			button.MouseEnter:Connect(function()
				Util.Tween(button, Info.Fast, { BackgroundTransparency = danger and 0.15 or 0 })
				Icons.SetColor(icon, danger and Color3.new(1, 1, 1) or Colors.Text, true)
			end)
			button.MouseLeave:Connect(function()
				Util.Tween(button, Info.Fast, { BackgroundTransparency = 1 })
				Icons.SetColor(icon, Colors.TextMuted, true)
			end)
			return button
		end
		local minimizeButton = titleButton("minus", 1, false)
		local closeButton = titleButton("x", 2, true)
		minimizeButton.MouseButton1Click:Connect(function()
			if self._minimized then
				self:Restore()
			else
				self:Minimize()
			end
		end)
		closeButton.MouseButton1Click:Connect(function()
			self:Close()
			if not self._hintShown then
				self._hintShown = true
				self:Notify({
					Title = "Interface hidden",
					Content = "Press " .. self.ToggleKey.Name .. " to open it again.",
					Duration = 4,
				})
			end
		end)

		-- dragging the window by its title bar
		local dragStartPos, dragStartLeft, dragStartTop
		Util.Drag(titleBar, self.Maid, {
			OnBegin = function(pos)
				self.Popups:Close(false)
				dragStartPos, dragStartLeft, dragStartTop = pos, self._left, self._top
				return true
			end,
			OnChange = function(pos)
				self._left = dragStartLeft + (pos.X - dragStartPos.X)
				self._top = dragStartTop + (pos.Y - dragStartPos.Y)
				self:_Clamp()
				self:_Place()
			end,
		})

		-- body: sidebar + content card ----------------------------------------
		local body = Create("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, TITLE_H),
			Size = UDim2.new(1, 0, 1, -TITLE_H),
			Parent = main,
		})
		self.Body = body

		local sidebar = Create("Frame", {
			Name = "Sidebar",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, SIDEBAR_W, 1, 0),
			Parent = body,
		})
		self.Sidebar = sidebar

		self.SearchFrame = Create("Frame", {
			Name = "Search",
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 30),
			BackgroundColor3 = Colors.Element,
			Parent = sidebar,
		}, { corner(8), stroke(Colors.Stroke, 0.2) })
		local searchIcon = Icons.Create("search", {
			Size = 13,
			Color = Colors.TextMuted,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Parent = self.SearchFrame,
		})
		self.SearchBox = Create("TextBox", {
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -38, 1, 0),
			PlaceholderText = "Search…",
			PlaceholderColor3 = Colors.TextDim,
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextColor3 = Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClipsDescendants = true,
			Parent = self.SearchFrame,
		})
		self.Maid:Give(self.SearchBox.Focused:Connect(function()
			Icons.SetColor(searchIcon, Theme.GetAccent(), true)
			Util.Tween(self.SearchFrame.UIStroke, Info.Fast, { Color = Theme.GetAccent(), Transparency = 0 })
		end))
		self.Maid:Give(self.SearchBox.FocusLost:Connect(function()
			Icons.SetColor(searchIcon, Colors.TextMuted, true)
			Util.Tween(self.SearchFrame.UIStroke, Info.Fast, { Color = Colors.Stroke, Transparency = 0.2 })
		end))

		self.TabScroll = Create("ScrollingFrame", {
			Name = "Tabs",
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, 0, 1, -100),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = sidebar,
		}, {
			padding(4, 8, 4, 8),
			Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		})

		local bottom = Create("Frame", {
			Name = "Bottom",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 54),
			Parent = sidebar,
		})
		Create("Frame", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 0, 1),
			BackgroundColor3 = Colors.Stroke,
			Parent = bottom,
		})
		self.BottomHolder = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 10),
			Size = UDim2.new(1, -16, 0, 34),
			Parent = bottom,
		})

		-- content card
		self.Card = Create("Frame", {
			Name = "Card",
			Position = UDim2.new(0, SIDEBAR_W, 0, 0),
			Size = UDim2.new(1, -SIDEBAR_W - 8, 1, -8),
			BackgroundColor3 = Colors.Background,
			ClipsDescendants = true,
			Parent = body,
		}, { corner(10), stroke(Colors.Stroke, 0.35) })

		local header = Create("Frame", {
			Name = "PageHeader",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 46),
			Parent = self.Card,
		}, {
			padding(0, 18),
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		self.PageTitle = Create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			FontFace = Fonts.SemiBold,
			TextSize = 17,
			TextColor3 = Colors.Text,
			LayoutOrder = 1,
			Parent = header,
		})
		self.PageSubtitle = Create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			FontFace = Fonts.Regular,
			TextSize = 12,
			TextColor3 = Colors.TextDim,
			LayoutOrder = 2,
			Parent = header,
		})

		self.Pages = Create("Frame", {
			Name = "Pages",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, 0, 1, -46),
			Parent = self.Card,
		})
		self.PageCurtain = Create("Frame", {
			Name = "PageCurtain",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.Background,
			BackgroundTransparency = 1,
			ZIndex = 50,
			Parent = self.Pages,
		}, { corner(10) })

		-- search results page
		self.SearchPage = Create("Frame", {
			Name = "SearchPage",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Parent = self.Pages,
		})
		self.SearchList = Create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Colors.TextDim,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = self.SearchPage,
		}, {
			padding(2, 14, 16, 16),
			Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		self.SearchEmpty = Create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(260, 40),
			Text = "No matching components",
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextColor3 = Colors.TextDim,
			Visible = false,
			Parent = self.SearchPage,
		})

		-- resize handle
		self.ResizeHandle = Create("TextButton", {
			Name = "Resize",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -3),
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 90,
			Parent = main,
		})
		for i, offset in ipairs({ 0.55, 0.8 }) do
			Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(offset, offset),
				Size = UDim2.new(0, 7 + i * 0, 0, 1),
				Rotation = -45,
				BackgroundColor3 = Colors.TextDim,
				Parent = self.ResizeHandle,
			})
		end
		local resizeStartPos, resizeStartSize
		Util.Drag(self.ResizeHandle, self.Maid, {
			OnBegin = function(pos)
				self.Popups:Close(false)
				resizeStartPos, resizeStartSize = pos, self._size
				return true
			end,
			OnChange = function(pos)
				local vp = viewportOf(gui)
				local maxW = math.max(vp.X - self._left - 8, self.MinSize.X)
				local maxH = math.max(vp.Y - self._top - 8, self.MinSize.Y)
				self._size = Vector2.new(
					math.clamp(resizeStartSize.X + (pos.X - resizeStartPos.X), self.MinSize.X, maxW),
					math.clamp(resizeStartSize.Y + (pos.Y - resizeStartPos.Y), self.MinSize.Y, maxH)
				)
				self:_ApplySize()
				self:_Layout(true)
				self:_Place()
			end,
		})

		-- events ---------------------------------------------------------
		self.Maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_Fit()
		end))
		self.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
			if processed or self.Ctx.Listening then
				return
			end
			if input.KeyCode == self.ToggleKey and not UserInputService:GetFocusedTextBox() then
				self:Toggle()
			end
		end))
		self.Maid:Give(self.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
			local query = Util.Trim(self.SearchBox.Text)
			if query == "" then
				if self._searchActive then
					self._searchActive = false
					self:_ShowCurrent()
				end
			else
				self:_RenderSearch(query)
			end
		end))

		-- tabs ---------------------------------------------------------
		self.SettingsTab = self:_NewTab({ Name = "Settings", Icon = "settings", Description = "Interface & configuration" }, true)
		self:_BuildSettings()
		self:_Layout(false)
		self:_Clamp()
		self:_Place()
		self:SelectTab(self.SettingsTab)

		if opts.Visible ~= false then
			self:Open()
		end
		return self
	end

	------------------------------------------------------------------------
	-- layout helpers
	------------------------------------------------------------------------
	function Window:_Clamp()
		local vp = viewportOf(self.Gui)
		local w = self._size.X
		self._left = math.clamp(self._left, math.min(80 - w, vp.X - 80), math.max(80 - w, vp.X - 80))
		self._top = math.clamp(self._top, 0, math.max(vp.Y - TITLE_H, 0))
	end

	function Window:_Place()
		self.Holder.Position = UDim2.fromOffset(self._left + self._size.X / 2, self._top)
	end

	function Window:_ApplySize()
		local height = self._minimized and TITLE_H or self._size.Y
		Apply(self.Holder, { Size = UDim2.fromOffset(self._size.X, height) }, false)
	end

	function Window:_Fit()
		if self.Destroyed then
			return
		end
		local vp = viewportOf(self.Gui)
		local maxW = math.max(vp.X - 16, 200)
		local maxH = math.max(vp.Y - 16, 200)
		self._size = Vector2.new(
			math.clamp(self._size.X, math.min(self.MinSize.X, maxW), maxW),
			math.clamp(self._size.Y, math.min(self.MinSize.Y, maxH), maxH)
		)
		self:_ApplySize()
		self:_Layout(false)
		self:_Clamp()
		self:_Place()
	end

	function Window:_Layout(animate)
		local compact = self._forceCompact or self._size.X < COMPACT_BELOW
		local changed = compact ~= self._compact
		self._compact = compact
		local sidebarWidth = compact and SIDEBAR_COMPACT or SIDEBAR_W
		Apply(self.Sidebar, { Size = UDim2.new(0, sidebarWidth, 1, 0) }, animate, Info.Normal)
		Apply(self.Card, {
			Position = UDim2.new(0, sidebarWidth, 0, 0),
			Size = UDim2.new(1, -sidebarWidth - 8, 1, -8),
		}, animate, Info.Normal)
		self.SearchFrame.Visible = not compact
		local top = compact and 8 or 46
		self.TabScroll.Position = UDim2.fromOffset(0, top)
		self.TabScroll.Size = UDim2.new(1, 0, 1, -top - 54)
		if changed then
			for _, tab in ipairs(self._allTabs) do
				if tab._ApplyCompact then
					tab._ApplyCompact()
				end
			end
		end
	end

	------------------------------------------------------------------------
	-- open / close / minimise
	------------------------------------------------------------------------
	function Window:Open()
		if self.Destroyed or self._open then
			return
		end
		self._open = true
		self._token += 1
		self.Holder.Visible = true
		Util.Tween(self.Scale, Info.Normal, { Scale = 1 })
		Util.Tween(self.Curtain, Info.Normal, { BackgroundTransparency = 1 })
		for _, layer in ipairs(self._shadow) do
			Util.Tween(layer, Info.Normal, { BackgroundTransparency = 0.955 })
		end
		self.OnOpen:Fire()
	end

	function Window:Close()
		if self.Destroyed or not self._open then
			return
		end
		self._open = false
		self._token += 1
		local mine = self._token
		self.Popups:Close(false)
		self.Tooltip:Hide()
		Util.Tween(self.Scale, Info.Fast, { Scale = 0.96 })
		Util.Tween(self.Curtain, Info.Fast, { BackgroundTransparency = 0 })
		for _, layer in ipairs(self._shadow) do
			Util.Tween(layer, Info.Fast, { BackgroundTransparency = 1 })
		end
		task.delay(0.16, function()
			if self._token == mine and not self.Destroyed then
				self.Holder.Visible = false
			end
		end)
		self.OnClose:Fire()
	end

	function Window:Toggle()
		if self._open then
			self:Close()
		else
			self:Open()
		end
	end

	function Window:IsOpen()
		return self._open
	end

	function Window:Minimize()
		if self._minimized or self.Destroyed then
			return
		end
		self._minimized = true
		self.Popups:Close(false)
		self.ResizeHandle.Visible = false
		Util.Tween(self.Holder, Info.Normal, { Size = UDim2.fromOffset(self._size.X, TITLE_H) })
		task.delay(0.23, function()
			if self._minimized and not self.Destroyed then
				self.Body.Visible = false
			end
		end)
	end

	function Window:Restore()
		if not self._minimized or self.Destroyed then
			return
		end
		self._minimized = false
		self.Body.Visible = true
		self.ResizeHandle.Visible = true
		Util.Tween(self.Holder, Info.Normal, { Size = UDim2.fromOffset(self._size.X, self._size.Y) })
		self:_Clamp()
		self:_Place()
	end

	function Window:IsMinimized()
		return self._minimized
	end

	------------------------------------------------------------------------
	-- tabs
	------------------------------------------------------------------------
	function Window:CreateTab(opts)
		if type(opts) == "string" then
			opts = { Name = opts }
		end
		Util.Validate("CreateTab", opts, {
			Name = "string",
			Icon = "string?",
			Description = "string?",
			Badge = "any?",
		})
		local tab = self:_NewTab(opts, false)
		if #self.Tabs == 1 then
			tab:Select()
		end
		return tab
	end

	function Window:GetTab(name)
		for _, tab in ipairs(self._allTabs) do
			if tab.Name == name then
				return tab
			end
		end
		return nil
	end

	function Window:RemoveTab(tab)
		if tab and not tab.Destroyed then
			tab:Destroy()
		end
	end

	function Window:_NewTab(opts, internal)
		local tab = setmetatable({
			Kind = "Tab",
			Window = self,
			Name = opts.Name,
			Description = opts.Description,
			Internal = internal,
			Destroyed = false,
			Badge = opts.Badge,
			Maid = Util.Maid.new(),
		}, Tab)

		local page = Create("Frame", {
			Name = "Page_" .. opts.Name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Parent = self.Pages,
		})
		local scroll = Create("ScrollingFrame", {
			Name = "Scroll",
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Colors.TextDim,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = page,
		}, {
			padding(2, 14, 16, 16),
			Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local empty = Create("Frame", {
			Name = "Empty",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(260, 70),
			BackgroundTransparency = 1,
			Parent = page,
		}, {
			Create("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			Text = "Nothing here yet",
			FontFace = Fonts.Medium,
			TextSize = 14,
			TextColor3 = Colors.TextMuted,
			LayoutOrder = 1,
			Parent = empty,
		})
		Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 32),
			Text = "Components added to this tab will appear here.",
			FontFace = Fonts.Regular,
			TextSize = 12,
			TextColor3 = Colors.TextDim,
			TextWrapped = true,
			LayoutOrder = 2,
			Parent = empty,
		})
		tab.Page, tab.Scroll, tab.Empty = page, scroll, empty
		tab.Maid:Give(page)

		Components.Init(tab, self.Ctx, scroll, scroll, tab)
		tab:OnCountChanged()

		tab.Maid:Give(scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if self.Popups:IsOpen() then
				self.Popups:Close(false)
			end
		end))

		self:_MakeTabButton(tab, opts, internal and self.BottomHolder or self.TabScroll)
		table.insert(self._allTabs, tab)
		if not internal then
			table.insert(self.Tabs, tab)
		end
		return tab
	end

	function Window:_MakeTabButton(tab, opts, parent)
		self._tabOrder += 1
		local hovered = false
		local button = Create("TextButton", {
			Name = "Tab_" .. tab.Name,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Colors.Element,
			BackgroundTransparency = 1,
			LayoutOrder = self._tabOrder,
			Parent = parent,
		}, { corner(8) })
		tab.Button = button
		tab.Maid:Give(button)

		local indicator = Create("Frame", {
			Name = "Indicator",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 0),
			Parent = button,
		}, { corner(2) })
		Theme.Bind(indicator, "BackgroundColor3", Theme.GetAccent)

		local icon = Icons.Create(opts.Icon or "dot", {
			Size = 16,
			Color = Colors.TextMuted,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Parent = button,
		})
		local label = Create("TextLabel", {
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, -52, 1, 0),
			Text = tab.Name,
			FontFace = Fonts.Medium,
			TextSize = 13,
			TextColor3 = Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = button,
		})

		local badge = Create("Frame", {
			Name = "Badge",
			BackgroundColor3 = Theme.GetAccent(),
			Visible = false,
			Parent = button,
		}, { corner(8) })
		Theme.Bind(badge, "BackgroundColor3", Theme.GetAccent)
		local badgeLabel = Create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			FontFace = Fonts.SemiBold,
			TextSize = 10,
			TextColor3 = Theme.OnAccent(),
			Parent = badge,
		}, { padding(0, 5) })

		function tab._RenderBadge()
			local show = tab.Badge ~= nil
			badge.Visible = show
			badgeLabel.Text = tostring(tab.Badge or "")
			badgeLabel.TextColor3 = Theme.OnAccent()
			if self._compact then
				badge.AutomaticSize = Enum.AutomaticSize.None
				badge.Size = UDim2.fromOffset(8, 8)
				badge.AnchorPoint = Vector2.new(1, 0)
				badge.Position = UDim2.new(1, -8, 0, 7)
				badgeLabel.Visible = false
			else
				badge.AutomaticSize = Enum.AutomaticSize.X
				badge.Size = UDim2.fromOffset(18, 16)
				badge.AnchorPoint = Vector2.new(1, 0.5)
				badge.Position = UDim2.new(1, -8, 0.5, 0)
				badgeLabel.Visible = true
			end
		end

		function tab._ApplyCompact()
			label.Visible = not self._compact
			if self._compact then
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.5)
			else
				icon.AnchorPoint = Vector2.new(0, 0.5)
				icon.Position = UDim2.new(0, 14, 0.5, 0)
			end
			tab._RenderBadge()
		end

		function tab._RenderButton(animate)
			local selected = self.Selected == tab and not self._searchActive
			local accent = Theme.GetAccent()
			Apply(button, {
				BackgroundColor3 = selected and Colors.Element or Colors.ElementHover,
				BackgroundTransparency = (selected or hovered) and 0 or 1,
			}, animate, Info.Fast)
			Apply(indicator, { Size = UDim2.fromOffset(3, selected and 16 or 0) }, animate, Info.Normal)
			Apply(label, { TextColor3 = (selected or hovered) and Colors.Text or Colors.TextMuted }, animate, Info.Fast)
			Icons.SetColor(icon, selected and accent or (hovered and Colors.Text or Colors.TextMuted), animate)
		end

		tab._ApplyCompact()
		tab._RenderButton(false)
		tab.Maid:Give(Theme.OnChange(function()
			tab._RenderButton(true)
			tab._RenderBadge()
		end))
		button.MouseEnter:Connect(function()
			hovered = true
			tab._RenderButton(true)
		end)
		button.MouseLeave:Connect(function()
			hovered = false
			tab._RenderButton(true)
		end)
		button.MouseButton1Click:Connect(function()
			self:SelectTab(tab)
		end)
		self.Tooltip:Attach(button, function()
			return self._compact and tab.Name or nil
		end, tab.Maid)
	end

	function Window:SelectTab(tab)
		if self.Destroyed or not tab or tab.Destroyed then
			return
		end
		self.Popups:Close(false)
		local wasSearching = self._searchActive
		local changed = self.Selected ~= tab
		self.Selected = tab
		for _, t in ipairs(self._allTabs) do
			t._RenderButton(true)
		end
		if wasSearching then
			-- clearing the box triggers _ShowCurrent through the text handler
			self.SearchBox.Text = ""
			if self._searchActive then
				self._searchActive = false
				self:_ShowCurrent()
			end
			return
		end
		if changed then
			self:_ShowCurrent()
		end
	end

	function Window:_ShowCurrent()
		local tab = self.Selected
		if not tab or tab.Destroyed then
			return
		end
		for _, t in ipairs(self._allTabs) do
			if t ~= tab then
				t.Page.Visible = false
			end
			t._RenderButton(true)
		end
		self.SearchPage.Visible = false
		self.PageTitle.Text = tab.Name
		self.PageSubtitle.Text = tab.Description or ""
		self.PageSubtitle.Visible = (tab.Description or "") ~= ""
		tab.Page.Visible = true
		tab.Page.Position = UDim2.fromOffset(0, 10)
		Util.Tween(tab.Page, Info.Normal, { Position = UDim2.fromOffset(0, 0) })
		self.PageCurtain.BackgroundTransparency = 0.5
		Util.Tween(self.PageCurtain, Info.Normal, { BackgroundTransparency = 1 })
	end

	------------------------------------------------------------------------
	-- search
	------------------------------------------------------------------------
	function Window:_RenderSearch(query)
		if not self._searchActive then
			self._searchActive = true
			for _, t in ipairs(self._allTabs) do
				t.Page.Visible = false
				t._RenderButton(true)
			end
			self.SearchPage.Visible = true
			self.PageTitle.Text = "Search results"
			self.PageSubtitle.Visible = false
		end
		for _, child in ipairs(self.SearchList:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local needle = string.lower(query)
		local matches = {}
		for entry in pairs(self.Search) do
			if not entry.Element._destroyed then
				local name = string.lower(entry.Name or "")
				local description = string.lower(entry.Description or "")
				if string.find(name, needle, 1, true) or string.find(description, needle, 1, true) then
					table.insert(matches, entry)
				end
			end
		end
		table.sort(matches, function(a, b)
			if a.Tab ~= b.Tab then
				return a.Tab.Name < b.Tab.Name
			end
			return (a.Name or "") < (b.Name or "")
		end)

		for index, entry in ipairs(matches) do
			if index > 40 then
				break
			end
			local row = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 46),
				BackgroundColor3 = Colors.Element,
				BackgroundTransparency = 0,
				LayoutOrder = index,
				Parent = self.SearchList,
			}, { corner(8), stroke(Colors.Stroke, 0) })
			Create("TextLabel", {
				Position = UDim2.fromOffset(14, 7),
				Size = UDim2.new(1, -44, 0, 18),
				Text = entry.Name,
				FontFace = Fonts.Medium,
				TextSize = 13,
				TextColor3 = Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = row,
			})
			Create("TextLabel", {
				Position = UDim2.fromOffset(14, 25),
				Size = UDim2.new(1, -44, 0, 14),
				Text = entry.Tab.Name .. "  ·  " .. tostring(entry.Element.Kind),
				FontFace = Fonts.Regular,
				TextSize = 11,
				TextColor3 = Colors.TextDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			local chevron = Icons.Create("chevron-right", {
				Size = 12,
				Color = Colors.TextDim,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Parent = row,
			})
			row.MouseEnter:Connect(function()
				Util.Tween(row, Info.Fast, { BackgroundColor3 = Colors.ElementHover })
				Icons.SetColor(chevron, Theme.GetAccent(), true)
			end)
			row.MouseLeave:Connect(function()
				Util.Tween(row, Info.Fast, { BackgroundColor3 = Colors.Element })
				Icons.SetColor(chevron, Colors.TextDim, true)
			end)
			row.MouseButton1Click:Connect(function()
				self:_JumpTo(entry)
			end)
		end
		self.SearchEmpty.Visible = #matches == 0
	end

	function Window:_JumpTo(entry)
		local element = entry.Element
		if element._destroyed then
			return
		end
		local container = entry.Container
		while container and container.Kind == "Expandable" do
			if not container:IsOpen() then
				container:SetOpen(true)
			end
			container = container.Container
		end
		self:SelectTab(entry.Tab)
		task.delay(0.3, function()
			if element._destroyed or self.Destroyed or entry.Tab.Destroyed then
				return
			end
			local scroll = entry.Tab.Scroll
			local target = element.Frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 12
			Util.Tween(scroll, Info.Normal, { CanvasPosition = Vector2.new(0, math.max(0, target)) })
			local elementStroke = element.Stroke
			if elementStroke then
				Util.Tween(elementStroke, Info.Fast, { Color = Theme.GetAccent(), Thickness = 2 })
				task.delay(0.9, function()
					if not element._destroyed and elementStroke.Parent then
						Util.Tween(elementStroke, Info.Slow, { Color = Colors.Stroke, Thickness = 1 })
					end
				end)
			end
		end)
	end

	------------------------------------------------------------------------
	-- public API
	------------------------------------------------------------------------
	function Window:Notify(opts)
		if self.Destroyed or not self.NotificationsEnabled then
			return nil
		end
		return self.Notifications:Notify(opts)
	end

	function Window:Confirm(opts)
		return Overlays.Dialog.Open(self.Gui, opts)
	end

	function Window:SetAccent(color)
		Theme.SetAccent(color)
	end

	function Window:GetAccent()
		return Theme.GetAccent()
	end

	function Window:SetTitle(text, subtitle)
		self.TitleLabel.Text = tostring(text)
		if subtitle ~= nil then
			self.SubtitleLabel.Text = tostring(subtitle)
			self.SubtitleLabel.Visible = subtitle ~= ""
		end
	end

	function Window:SetToggleKey(key)
		if typeof(key) ~= "EnumItem" then
			error("NovaUI: SetToggleKey expects an Enum.KeyCode", 2)
		end
		self.ToggleKey = key
	end

	function Window:GetElement(flag)
		return self.Flags[flag]
	end

	function Window:GetFlag(flag)
		local element = self.Flags[flag]
		if not element then
			error("NovaUI: no component with Flag '" .. tostring(flag) .. "'", 2)
		end
		return element:Get()
	end

	function Window:SetFlag(flag, value, silent)
		local element = self.Flags[flag]
		if not element then
			error("NovaUI: no component with Flag '" .. tostring(flag) .. "'", 2)
		end
		element:Set(value, silent)
	end

	------------------------------------------------------------------------
	-- configuration
	------------------------------------------------------------------------
	function Window:ExportConfig()
		local accent = Theme.GetAccent()
		local data = {
			version = 1,
			accent = { r = math.round(accent.R * 255), g = math.round(accent.G * 255), b = math.round(accent.B * 255) },
			flags = {},
		}
		for name, element in pairs(self.Flags) do
			if element._serialize then
				local ok, value = pcall(element._serialize, element)
				if ok and value ~= nil then
					data.flags[name] = value
				end
			end
		end
		return HttpService:JSONEncode(data)
	end

	function Window:ImportConfig(json)
		local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
		if not ok or type(data) ~= "table" then
			return false, "Config is not valid JSON"
		end
		if type(data.accent) == "table" and data.accent.r and data.accent.g and data.accent.b then
			Theme.SetAccent(Color3.fromRGB(data.accent.r, data.accent.g, data.accent.b))
		end
		for name, value in pairs(data.flags or {}) do
			local element = self.Flags[name]
			if element and element._deserialize then
				pcall(element._deserialize, element, value)
			end
		end
		return true
	end

	function Window:SaveConfig(name)
		local provider = self.Library.ConfigProvider
		local ok, err = pcall(provider.Save, name or "default", self:ExportConfig())
		if not ok then
			warn("[NovaUI] SaveConfig failed: " .. tostring(err))
		end
		return ok
	end

	function Window:LoadConfig(name)
		local provider = self.Library.ConfigProvider
		local ok, json = pcall(provider.Load, name or "default")
		if not ok or type(json) ~= "string" then
			return false, "No saved config named '" .. tostring(name or "default") .. "'"
		end
		return self:ImportConfig(json)
	end

	------------------------------------------------------------------------
	-- built-in settings tab
	------------------------------------------------------------------------
	function Window:_BuildSettings()
		local tab = self.SettingsTab

		tab:CreateSection("Appearance")
		local accentPicker = tab:CreateColorPicker({
			Name = "Accent colour",
			Description = "Updates every component instantly.",
			Icon = "palette",
			Default = Theme.GetAccent(),
			Callback = function(color)
				Theme.SetAccent(color)
			end,
		})
		self.Maid:Give(Theme.OnChange(function(color)
			if accentPicker:Get() ~= color then
				accentPicker:Set(color, true)
			end
		end))
		local presetNames = {}
		for name in pairs(Theme.AccentPresets) do
			table.insert(presetNames, name)
		end
		table.sort(presetNames)
		tab:CreateDropdown({
			Name = "Accent preset",
			Icon = "sliders",
			Options = presetNames,
			Placeholder = "Choose a preset…",
			Callback = function(name)
				accentPicker:Set(Theme.AccentPresets[name])
			end,
		})

		tab:CreateSection("Interface")
		tab:CreateKeybind({
			Name = "Toggle key",
			Description = "Shows or hides the window.",
			Icon = "keyboard",
			Default = self.ToggleKey,
			Callback = function(key)
				if key then
					self.ToggleKey = key
				end
			end,
		})
		tab:CreateToggle({
			Name = "Notifications",
			Description = "Show toast notifications.",
			Icon = "bell",
			Default = true,
			Callback = function(enabled)
				self.NotificationsEnabled = enabled
				if not enabled then
					self.Notifications:DismissAll()
				end
			end,
		})
		tab:CreateToggle({
			Name = "Compact sidebar",
			Description = "Icons only. Also happens automatically in narrow windows.",
			Icon = "list",
			Default = false,
			Callback = function(enabled)
				self._forceCompact = enabled
				self:_Layout(true)
			end,
		})

		tab:CreateSection("Configuration")
		local nameInput = tab:CreateTextInput({
			Name = "Config name",
			Default = "default",
			MaxLength = 32,
			Validate = function(text)
				return #Util.Trim(text) > 0
			end,
		})
		tab:CreateButton({
			Name = "Save config",
			Description = "Stores every component that has a Flag.",
			Style = "Primary",
			Callback = function()
				local ok = self:SaveConfig(Util.Trim(nameInput:Get()))
				self:Notify({
					Title = ok and "Config saved" or "Save failed",
					Content = ok and ("Saved '" .. nameInput:Get() .. "'.") or "See the output window for details.",
					Type = ok and "Success" or "Error",
					Duration = 2.5,
				})
			end,
		})
		tab:CreateButton({
			Name = "Load config",
			Callback = function()
				local ok, err = self:LoadConfig(Util.Trim(nameInput:Get()))
				self:Notify({
					Title = ok and "Config loaded" or "Load failed",
					Content = ok and "Component values restored." or err,
					Type = ok and "Success" or "Warning",
					Duration = 2.5,
				})
			end,
		})
		tab:CreateButton({
			Name = "Print config JSON",
			Description = "Writes the current configuration to the output window.",
			Style = "Subtle",
			Callback = function()
				print("[NovaUI] " .. self:ExportConfig())
			end,
		})

		tab:CreateSection("Danger zone")
		tab:CreateButton({
			Name = "Destroy interface",
			Description = "Removes the window and cleans up every connection.",
			Style = "Subtle",
			Callback = function()
				self:Confirm({
					Title = "Destroy the interface?",
					Message = "The window and all of its components will be removed.",
					ConfirmText = "Destroy",
					Danger = true,
					Callback = function(confirmed)
						if confirmed then
							task.defer(function()
								self:Destroy()
							end)
						end
					end,
				})
			end,
		})
	end

	------------------------------------------------------------------------
	-- teardown
	------------------------------------------------------------------------
	function Window:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		self._open = false
		self.Popups:Close(false)
		for i = #self._allTabs, 1, -1 do
			local tab = self._allTabs[i]
			if tab and not tab.Destroyed then
				tab.Destroyed = true
				tab:Clear()
				tab.Maid:Clean()
			end
		end
		table.clear(self._allTabs)
		table.clear(self.Tabs)
		table.clear(self.Flags)
		table.clear(self.Search)
		self.OnDestroy:Fire()
		self.OnOpen:Destroy()
		self.OnClose:Destroy()
		self.OnDestroy:Destroy()
		self.Maid:Clean()
		if self.Library and self.Library._Remove then
			self.Library:_Remove(self)
		end
	end

	return Window
end)()

------------------------------------------------------------------------
-- Library entry point
------------------------------------------------------------------------
local NovaUI = {}
NovaUI.Version = "1.0.0"
NovaUI.Theme = ThemeModule
NovaUI.Util = UtilModule
NovaUI.Icons = IconsModule
NovaUI.Windows = {}

-- Default config storage is in-memory. Replace it with SetConfigProvider to persist
-- (e.g. executor writefile/readfile or DataStores).
local memoryStore = {}
NovaUI.ConfigProvider = {
	Save = function(name, json)
		memoryStore[name] = json
	end,
	Load = function(name)
		return memoryStore[name]
	end,
}

-- provider = { Save = function(name: string, json: string), Load = function(name: string): string? }
function NovaUI:SetConfigProvider(provider)
	if type(provider) ~= "table" or type(provider.Save) ~= "function" or type(provider.Load) ~= "function" then
		error("NovaUI: SetConfigProvider expects a table with Save(name, json) and Load(name) functions", 2)
	end
	NovaUI.ConfigProvider = provider
end

-- Works as both NovaUI:CreateWindow(opts) and NovaUI.CreateWindow(opts)
function NovaUI:CreateWindow(opts)
	if self ~= NovaUI then
		opts = self
	end
	local window = WindowModule.new(NovaUI, opts)
	table.insert(NovaUI.Windows, window)
	return window
end

function NovaUI:_Remove(window)
	local index = table.find(NovaUI.Windows, window)
	if index then
		table.remove(NovaUI.Windows, index)
	end
end

function NovaUI:Notify(opts)
	local window = NovaUI.Windows[#NovaUI.Windows]
	return window and window:Notify(opts) or nil
end

function NovaUI:Destroy()
	for i = #NovaUI.Windows, 1, -1 do
		local window = NovaUI.Windows[i]
		if window then
			window:Destroy()
		end
	end
end

return NovaUI
