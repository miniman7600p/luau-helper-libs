local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local ESP = {}
ESP.__index = ESP

local DEFAULTS = {
	Enabled = true,
	MaxDistance = 2000,
	UseTeamCheck = false,
	Box = true,
	Name = true,
	Distance = true,
	BoxColor = Color3.fromRGB(255, 255, 255),
	OutlineColor = Color3.fromRGB(0, 0, 0),
	TextColor = Color3.fromRGB(255, 255, 255),
	DistanceColor = Color3.fromRGB(200, 200, 200),
	BoxThickness = 1,
	OutlineThickness = 3,
	TextSize = 13,
	Font = 2,
	WidthScale = 0.6,
	YPadding = 0,
}

local function cloneOptions(options)
	local result = {}
	for key, value in pairs(DEFAULTS) do
		result[key] = value
	end
	for key, value in pairs(options or {}) do
		result[key] = value
	end
	return result
end

local function getCamera()
	return workspace.CurrentCamera
end

local function getLocalRootPart()
	local character = LocalPlayer and LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function resolveAdornee(instance)
	if not instance or not instance.Parent then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart
			or instance:FindFirstChild("HumanoidRootPart")
			or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	if instance:IsA("Humanoid") then
		local model = instance.Parent
		if model and model:IsA("Model") then
			return model.PrimaryPart
				or model:FindFirstChild("HumanoidRootPart")
				or model:FindFirstChildWhichIsA("BasePart", true)
		end
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function createDrawing(drawType, props)
	local drawing = Drawing.new(drawType)
	for key, value in pairs(props) do
		drawing[key] = value
	end
	return drawing
end

local function createDrawings()
	return {
		Box = createDrawing("Square", { Visible = false, Filled = false }),
		Outline = createDrawing("Square", { Visible = false, Filled = false }),
		Name = createDrawing("Text", { Visible = false, Center = true, Outline = true }),
		Distance = createDrawing("Text", { Visible = false, Center = true, Outline = true }),
	}
end

local function hideDrawings(drawings)
	if not drawings then
		return
	end

	for _, drawing in pairs(drawings) do
		drawing.Visible = false
	end
end

local function removeDrawings(drawings)
	if not drawings then
		return
	end

	for _, drawing in pairs(drawings) do
		drawing:Remove()
	end
end

function ESP.new(globalOptions)
	local self = setmetatable({}, ESP)
	self.globalOptions = cloneOptions(globalOptions)
	self.entries = {}
	self.connection = nil
	return self
end

function ESP:SetEnabled(enabled)
	self.globalOptions.Enabled = enabled
	if not enabled then
		for _, entry in pairs(self.entries) do
			hideDrawings(entry.drawings)
		end
	end
end

function ESP:SetOptions(options)
	for key, value in pairs(options or {}) do
		self.globalOptions[key] = value
	end
end

function ESP:Add(instance, options)
	if not instance then
		return nil
	end

	if self.entries[instance] then
		return self.entries[instance]
	end

	local entry = {
		instance = instance,
		options = cloneOptions(options),
		drawings = createDrawings(),
	}

	self.entries[instance] = entry
	return entry
end

function ESP:Remove(instance)
	local entry = self.entries[instance]
	if not entry then
		return
	end

	removeDrawings(entry.drawings)
	self.entries[instance] = nil
end

function ESP:Clear()
	for instance in pairs(self.entries) do
		self:Remove(instance)
	end
end

function ESP:_getOption(entry, key)
	local value = entry.options[key]
	if value ~= nil then
		return value
	end
	return self.globalOptions[key]
end

function ESP:_shouldSkip(entry)
	local instance = entry.instance
	if not instance or not instance.Parent then
		return true
	end

	local onlyIfAlive = self:_getOption(entry, "OnlyIfAlive")
	if onlyIfAlive and instance:IsA("Model") then
		local humanoid = instance:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return true
		end
	end

	local trackedPlayer = self:_getOption(entry, "Player")
	if self.globalOptions.UseTeamCheck and trackedPlayer and LocalPlayer and LocalPlayer.Team ~= nil and trackedPlayer.Team == LocalPlayer.Team then
		return true
	end

	return false
end

function ESP:_getAdornee(entry)
	local custom = self:_getOption(entry, "GetAdornee")
	if custom then
		return custom(entry.instance)
	end
	return resolveAdornee(entry.instance)
end

function ESP:_getSize(entry, adornee)
	local custom = self:_getOption(entry, "GetSize")
	if custom then
		return custom(entry.instance, adornee)
	end
	return adornee.Size
end

function ESP:_getDisplayName(entry)
	local custom = self:_getOption(entry, "GetName")
	if custom then
		return custom(entry.instance)
	end
	return entry.instance.Name
end

function ESP:_updateEntry(entry, camera, localRoot)
	if self:_shouldSkip(entry) then
		hideDrawings(entry.drawings)
		return
	end

	local adornee = self:_getAdornee(entry)
	if not adornee then
		hideDrawings(entry.drawings)
		return
	end

	local size = self:_getSize(entry, adornee)
	if not size then
		hideDrawings(entry.drawings)
		return
	end

	local distance = localRoot and (localRoot.Position - adornee.Position).Magnitude or math.huge
	if distance > self:_getOption(entry, "MaxDistance") then
		hideDrawings(entry.drawings)
		return
	end

	local center, visible = camera:WorldToViewportPoint(adornee.Position)
	if not visible then
		hideDrawings(entry.drawings)
		return
	end

	local yPadding = self:_getOption(entry, "YPadding")
	local heightOffset = (size.Y * 0.5) + yPadding
	local top = camera:WorldToViewportPoint(adornee.Position + Vector3.new(0, heightOffset, 0))
	local bottom = camera:WorldToViewportPoint(adornee.Position - Vector3.new(0, heightOffset, 0))

	local height = math.abs(top.Y - bottom.Y)
	local width = math.max(height * self:_getOption(entry, "WidthScale"), 4)
	local x = center.X - width / 2
	local y = top.Y

		local showBox = self:_getOption(entry, "Box")
	entry.drawings.Box.Visible = showBox and self.globalOptions.Enabled
	entry.drawings.Outline.Visible = showBox and self.globalOptions.Enabled
	if showBox then
		entry.drawings.Box.Color = self:_getOption(entry, "BoxColor")
		entry.drawings.Box.Thickness = self:_getOption(entry, "BoxThickness")
		entry.drawings.Box.Position = Vector2.new(x, y)
		entry.drawings.Box.Size = Vector2.new(width, height)

		entry.drawings.Outline.Color = self:_getOption(entry, "OutlineColor")
		entry.drawings.Outline.Thickness = self:_getOption(entry, "OutlineThickness")
		entry.drawings.Outline.Position = Vector2.new(x - 1, y - 1)
		entry.drawings.Outline.Size = Vector2.new(width + 2, height + 2)
	end

	local showName = self:_getOption(entry, "Name")
	entry.drawings.Name.Visible = showName and self.globalOptions.Enabled
	if showName then
		entry.drawings.Name.Text = self:_getDisplayName(entry)
		entry.drawings.Name.Color = self:_getOption(entry, "TextColor")
		entry.drawings.Name.Size = self:_getOption(entry, "TextSize")
		entry.drawings.Name.Font = self:_getOption(entry, "Font")
		entry.drawings.Name.Position = Vector2.new(center.X, y - 16)
	end

	local showDistance = self:_getOption(entry, "Distance")
	entry.drawings.Distance.Visible = showDistance and self.globalOptions.Enabled
	if showDistance then
		entry.drawings.Distance.Text = string.format("[%dm]", math.floor(distance))
		entry.drawings.Distance.Color = self:_getOption(entry, "DistanceColor")
		entry.drawings.Distance.Size = self:_getOption(entry, "TextSize")
		entry.drawings.Distance.Font = self:_getOption(entry, "Font")
		entry.drawings.Distance.Position = Vector2.new(center.X, y + height + 2)
	end
end

function ESP:Update()
	if not self.globalOptions.Enabled then
		for _, entry in pairs(self.entries) do
			hideDrawings(entry.drawings)
		end
		return
	end

	local camera = getCamera()
	if not camera then
		return
	end

	local localRoot = getLocalRootPart()

	for instance, entry in pairs(self.entries) do
		if not instance or not instance.Parent then
			self:Remove(instance)
		else
			self:_updateEntry(entry, camera, localRoot)
		end
	end
end

function ESP:Start()
	if self.connection then
		return
	end

	self.connection = RunService.RenderStepped:Connect(function()
		self:Update()
	end)
end

function ESP:Stop()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end

	for _, entry in pairs(self.entries) do
		hideDrawings(entry.drawings)
	end
end

return ESP
