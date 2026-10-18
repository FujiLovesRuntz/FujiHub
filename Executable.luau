local ui = loadstring(game:HttpGet("https://raw.githubusercontent.com/FujiLovesRuntz/FujiHub/refs/heads/main/Dependencies/UI.luau"))()

local key = "0000"
local submittedkey

local window = ui:CreateWindow({
	Title = "FujiHub",
	Subtitle = "by Fuji 🐬",
	AccentColor = ui.Theme.AccentPresets.Blue,
	Size = Vector2.new(680, 460),
	ToggleKey = Enum.KeyCode.RightShift,
})

local main = window:CreateTab({ Name = "Key", Icon = "rbxassetid://98077264268272", Description = "Enter the key to access FujiHub" })

main:CreateTextInput({
	Name = "Key",
	Placeholder = "Enter your key here",
	MaxLength = 4,
	Validate = function(text)
		return #text >= 0
	end,
	Flag = "key",
	Callback = function(text)
		submittedkey = text
	end,
})

main:CreateButton({
	Name = "Submit Key",
	Description = "Validates your key.",
	Icon = "rbxassetid://98077264268272",
	Style = "Primary",
	Tooltip = "Checks if your key is correct or incorrect.",
	Callback = function()
		if submittedkey ~= key then
            window:Notify({ Title = "Invalid Key", Content = "Please get a new key, or enter the correct one. Or try again later.", Type = "Error", Duration = 3 })
        else
            window:Notify({ Title = "Correct Key", Content = "FujiHub is executing now.", Type = "Success", Duration = 3 })

            window:Destroy()
        end
	end,
})
