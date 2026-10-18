# NovaUI Documentation

NovaUI is a dark-mode Roblox UI library with customizable accent colors, animated components, tabs, popups, and configuration support.

## 1. Installation

1. Create a `ModuleScript` named `NovaUI`.
2. Paste the entire NovaUI library code into it.
3. Put the ModuleScript somewhere your `LocalScript` can access it.
4. Require the module to start using it.

```lua
local NovaUI = require(game.ReplicatedStorage.NovaUI)
```

## 2. Creating a Window

A window is the main interface that holds your tabs and components.

```lua
local Window = NovaUI:CreateWindow({
    Title = "My Hub",
    AccentColor = NovaUI.Theme.AccentPresets.Blue
})
```

### Window options

| Option | Description |
|---|---|
| `Title` | Window title |
| `AccentColor` | Initial accent color |

## 3. Creating Tabs

Tabs separate your UI into different pages.

```lua
local MainTab = Window:CreateTab({
    Name = "Main",
    Icon = "home"
})

local SettingsTab = Window:CreateTab({
    Name = "Settings",
    Icon = "settings"
})
```

You can create components inside any tab.

## 4. Components

### Button

Runs a function when clicked.

```lua
MainTab:CreateButton({
    Name = "Print Message",
    Description = "Prints a message",
    Callback = function()
        print("Hello World!")
    end
})
```

Button styles: `Primary`, `Secondary`, `Subtle`.

### Toggle

Turns a feature on or off.

```lua
MainTab:CreateToggle({
    Name = "Auto Farm",
    Default = false,
    Callback = function(enabled)
        print(enabled)
    end
})
```

### Checkbox

Creates a checkbox that can be checked or unchecked.

```lua
MainTab:CreateCheckbox({
    Name = "Enable Feature",
    Default = false,
    Callback = function(checked)
        print(checked)
    end
})
```

### Slider

Lets the user select a number within a range.

```lua
MainTab:CreateSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 100,
    Default = 16,
    Callback = function(value)
        print(value)
    end
})
```

### Dropdown

Lets the user select an option from a list.

```lua
MainTab:CreateDropdown({
    Name = "Select Mode",
    Options = {"Easy", "Normal", "Hard"},
    Default = "Normal",
    Callback = function(value)
        print(value)
    end
})
```

### Color Picker

Allows the user to choose a color.

```lua
MainTab:CreateColorPicker({
    Name = "Custom Color",
    Default = Color3.fromRGB(130, 90, 255),
    Callback = function(color)
        print(color)
    end
})
```

### Text Input

Allows the user to enter text.

```lua
MainTab:CreateTextInput({
    Name = "Username",
    Placeholder = "Enter username...",
    Default = "",
    Callback = function(text)
        print(text)
    end
})
```

### Label

Displays simple text.

```lua
MainTab:CreateLabel({
    Text = "Welcome to my hub!",
    Style = "Body"
})
```

Available styles: `Title`, `Subtitle`, `Body`, `Muted`.

### Paragraph

Displays a title and a longer description.

```lua
MainTab:CreateParagraph({
    Title = "Information",
    Content = "Welcome to the main page."
})
```

### Section

Creates a heading to organize components.

```lua
MainTab:CreateSection("General")
```

### Divider

Adds a horizontal divider.

```lua
MainTab:CreateDivider()
```

## 5. Changing the Accent Color

You can change the accent color while the UI is running.

```lua
Window:SetAccent(Color3.fromRGB(255, 0, 0))
```

You can also use the built-in presets:

```lua
NovaUI.Theme.AccentPresets.Violet
NovaUI.Theme.AccentPresets.Blue
NovaUI.Theme.AccentPresets.Teal
NovaUI.Theme.AccentPresets.Green
NovaUI.Theme.AccentPresets.Amber
NovaUI.Theme.AccentPresets.Rose
```

## 6. Notifications

Display a notification to the user.

```lua
Window:Notify({
    Title = "Success",
    Content = "Your action completed!",
    Duration = 3,
    Type = "Success"
})
```

## 7. Component Options

Most interactive components support these common options:

| Option | Description |
|---|---|
| `Name` | Component name |
| `Description` | Additional information |
| `Icon` | Icon displayed beside the component |
| `Callback` | Function executed when the value changes or the component is activated |
| `Default` | Initial value, when supported |
| `Flag` | Unique identifier for configuration saving |
| `Disabled` | Disables interaction |
| `Visible` | Controls initial visibility |
| `Tooltip` | Text displayed as a tooltip |

Not every component supports every option.

## 8. Flags and Configurations

Flags identify components so their values can be saved and restored.

```lua
MainTab:CreateToggle({
    Name = "Enabled",
    Flag = "enabled",
    Default = false,
    Callback = function(value)
        print(value)
    end
})
```

NovaUI includes configuration methods for exporting, saving, and loading component values. Only components with flags are included.

By default, configuration storage is in memory, so saved configurations do not persist after the session ends. A persistent storage provider must be configured for that.

## 9. Destroying the UI

Remove a window and clean up its components and connections.

```lua
Window:Destroy()
```

To destroy every window created by the library:

```lua
NovaUI:Destroy()
```

## 10. Complete Example

```lua
local NovaUI = require(game.ReplicatedStorage.NovaUI)

local Window = NovaUI:CreateWindow({
    Title = "Example Hub",
    AccentColor = NovaUI.Theme.AccentPresets.Violet
})

local Main = Window:CreateTab({
    Name = "Main",
    Icon = "home"
})

Main:CreateSection("General")

Main:CreateButton({
    Name = "Say Hello",
    Callback = function()
        print("Hello!")
    end
})

Main:CreateToggle({
    Name = "Enabled",
    Default = false,
    Callback = function(value)
        print("Enabled:", value)
    end
})

Main:CreateSlider({
    Name = "Power",
    Min = 1,
    Max = 100,
    Default = 50,
    Callback = function(value)
        print("Power:", value)
    end
})

Main:CreateDropdown({
    Name = "Mode",
    Options = {"Easy", "Normal", "Hard"},
    Default = "Normal",
    Callback = function(value)
        print("Mode:", value)
    end
})

Window:Notify({
    Title = "NovaUI",
    Content = "Interface loaded!",
    Duration = 3,
    Type = "Success"
})
```

---

**Tip:** Each component's callback lets you connect the UI to your own game logic. Use tabs to organize features, sections to group related settings, and flags when you want component values included in configurations.
