# NovaUI — Complete Documentation

A dark-mode Roblox UI library with animated components, tabs, configuration support, keybinds, notifications, and customizable accent colors.

## 1. Installation

Place the NovaUI ModuleScript somewhere accessible to your LocalScript, such as `ReplicatedStorage`.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NovaUI = require(ReplicatedStorage.NovaUI)
```

NovaUI must run on the client, using a `LocalScript`.

## 2. Creating a window

```lua
local window = NovaUI:CreateWindow({
    Title = "My Hub",
    Subtitle = "Welcome back",
    Icon = "house",
    AccentColor = NovaUI.Theme.AccentPresets.Blue,
    Size = Vector2.new(850, 550),
    MinSize = Vector2.new(560, 360),
    ToggleKey = Enum.KeyCode.RightControl,
    Visible = true
})
```

### CreateWindow arguments

| Argument | Type | Default / behavior |
|---|---|---|
| `Title` | string? | Window title |
| `Subtitle` | string? | Optional subtitle |
| `Icon` | string? | Icon name or image asset string |
| `AccentColor` | Color3? | Sets the global accent color |
| `Size` | Vector2? | Initial window size |
| `MinSize` | Vector2? | Minimum window size |
| `ToggleKey` | EnumItem? | Key that opens or closes the window |
| `Parent` | Instance? | Parent for the GUI |
| `Name` | string? | GUI name |
| `DisplayOrder` | number? | ScreenGui display order |
| `Visible` | boolean? | Initial visibility |

`?` means optional. `Vector2` sizes are pixel dimensions.

## 3. Creating tabs

```lua
local mainTab = window:CreateTab({
    Name = "Main",
    Icon = "house",
    Description = "Main settings",
    Badge = "NEW"
})

local settingsTab = window:CreateTab({
    Name = "Settings",
    Icon = "settings"
})
```

You can also pass a tab name directly:

```lua
local tab = window:CreateTab("Main")
```

### CreateTab arguments

| Argument | Type | Description |
|---|---|---|
| `Name` | string — Required | Tab name |
| `Icon` | string? | Tab icon |
| `Description` | string? | Tab description |
| `Badge` | any? | Badge value displayed on the tab |

### Tab methods

```lua
tab:Select()
tab:SetBadge("3")
tab:Destroy()

local sameTab = window:GetTab("Main")
window:RemoveTab(sameTab)
```

- `Select()` selects the tab.
- `SetBadge(value)` updates its badge.
- `Destroy()` removes the tab and its components.
- `GetTab(name)` returns a tab or `nil`.
- `RemoveTab(tab)` removes a tab.

Tabs support all component-creation methods described below.

## 4. Shared component arguments

Most interactive components share these arguments.

| Argument | Type | Description |
|---|---|---|
| `Name` | string — Required | Component title |
| `Description` | string? | Secondary text below the title |
| `Icon` | string? | Icon displayed beside the title |
| `Disabled` | boolean? | Disables interaction when `true` |
| `Tooltip` | string? | Tooltip text |
| `ContextMenu` | table? | Right-click menu items |
| `Flag` | string? | Unique identifier for accessing and saving the component |
| `Callback` | function? | Function called when the component changes or is activated |

Not every component supports every shared argument. The individual component definitions below specify the exact supported options.

### Callback example

```lua
tab:CreateToggle({
    Name = "Enabled",
    Callback = function(value)
        print("New value:", value)
    end
})
```

Always use a unique `Flag` for each component you want to access through the window or save in configurations.

---

# 5. All components

## 5.1 Label

Creates a simple text label.

```lua
local label = tab:CreateLabel({
    Text = "Welcome to my hub",
    Style = "Title"
})
```

You can also pass a string directly:

```lua
local label = tab:CreateLabel("Welcome!")
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Text` | string | Yes |
| `Style` | string? | No; defaults to `"Body"` |

Valid styles:

- `Title`
- `Subtitle`
- `Body`
- `Muted`

### Methods

```lua
label:SetText("Updated text")
local text = label:Get()
label:SetVisible(false)
label:Destroy()
```

## 5.2 Paragraph

Creates a text panel with an optional title.

```lua
local paragraph = tab:CreateParagraph({
    Title = "Information",
    Content = "This is a description of the current feature."
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Title` | string? | No |
| `Content` | string | Yes |

### Methods

```lua
paragraph:SetTitle("New title")
paragraph:SetText("New content")
paragraph:Destroy()
```

## 5.3 Section

Creates a section heading to organize components.

```lua
local section = tab:CreateSection("General")
```

You can also use:

```lua
local section = tab:CreateSection({
    Name = "General"
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |

### Methods

```lua
section:SetText("Advanced")
section:SetVisible(false)
section:Destroy()
```

## 5.4 Divider

Creates a small visual separator.

```lua
local divider = tab:CreateDivider()
```

No arguments are required.

## 5.5 Button

Creates a clickable button.

```lua
local button = tab:CreateButton({
    Name = "Execute",
    Description = "Run the selected action",
    Icon = "check",
    Style = "Primary",
    Tooltip = "Click to execute",
    Flag = "executeButton",
    Callback = function()
        print("Executed!")
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Style` | string? | No |
| `Callback` | function? | No |
| `Disabled` | boolean? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

Valid styles: `Primary`, `Secondary`, `Subtle`.

### Methods

```lua
button:SetStyle("Primary")
button:SetLoading(true)
button:SetCallback(function()
    print("New callback")
end)
button:Click()
button:SetDisabled(true)
button:SetVisible(false)
button:Destroy()
```

`SetLoading(true)` displays a loading indicator and prevents button activation until loading is turned off.

## 5.6 Toggle

Creates an on/off switch.

```lua
local toggle = tab:CreateToggle({
    Name = "Enable feature",
    Description = "Turn the feature on or off",
    Icon = "settings",
    Default = false,
    Flag = "enabled",
    Callback = function(enabled)
        print("Enabled:", enabled)
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Default` | boolean? | No; defaults to `false` |
| `Callback` | function? | No |
| `Disabled` | boolean? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

### Methods

```lua
local enabled = toggle:Get()
toggle:Set(true)
toggle:Set(false, true) -- silent
toggle:Toggle()
toggle:SetDisabled(true)
toggle:SetVisible(false)
toggle:OnChanged(function(value)
    print(value)
end)
toggle:Destroy()
```

`Set(value, true)` suppresses the normal change callback. `Toggle()` switches the current value.

## 5.7 Checkbox

Creates a checkbox with a boolean value.

```lua
local checkbox = tab:CreateCheckbox({
    Name = "Show notifications",
    Default = true,
    Flag = "notifications",
    Callback = function(checked)
        print("Checked:", checked)
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Default` | boolean? | No; defaults to `false` |
| `Callback` | function? | No |
| `Disabled` | boolean? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

### Methods

```lua
local checked = checkbox:Get()
checkbox:Set(false)
checkbox:Set(true, true)
checkbox:SetDisabled(true)
checkbox:SetVisible(false)
checkbox:OnChanged(function(value)
    print(value)
end)
checkbox:Destroy()
```

## 5.8 Slider

Creates a numeric slider.

```lua
local slider = tab:CreateSlider({
    Name = "Walk speed",
    Description = "Adjust the speed value",
    Icon = "sliders",
    Min = 0,
    Max = 100,
    Default = 16,
    Step = 1,
    Suffix = " studs/s",
    ShowInput = true,
    Flag = "walkSpeed",
    Callback = function(value)
        print("Speed:", value)
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Min` | number | Yes |
| `Max` | number | Yes |
| `Default` | number? | No |
| `Step` | number? | No; defaults to `1` |
| `Suffix` | string? | No |
| `ShowInput` | boolean? | No |
| `Callback` | function? | No |
| `Disabled` | boolean? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

`Min` must be less than `Max`. `Step` must be greater than zero.

### Methods

```lua
local value = slider:Get()
slider:Set(50)
slider:Set(25, true)
slider:SetRange(0, 200)
slider:SetDisabled(true)
slider:SetVisible(false)
slider:OnChanged(function(value)
    print(value)
end)
slider:Destroy()
```

`SetRange(min, max)` changes the slider's range.

## 5.9 Dropdown

Creates a single-selection dropdown.

```lua
local dropdown = tab:CreateDropdown({
    Name = "Select mode",
    Description = "Choose a mode",
    Icon = "list",
    Options = {"Easy", "Normal", "Hard"},
    Default = "Normal",
    Placeholder = "Choose a mode...",
    Searchable = true,
    Flag = "mode",
    Callback = function(value)
        print("Selected:", value)
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Options` | table | Yes |
| `Default` | any? | No |
| `Placeholder` | string? | No; defaults to `"Select…"` |
| `Searchable` | boolean? | No |
| `Callback` | function? | No |
| `Disabled` | boolean? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

`Options` is an array of selectable values.

### Methods

```lua
local selected = dropdown:Get()
dropdown:Set("Hard")
dropdown:Set("Easy", true)

local options = dropdown:GetOptions()

dropdown:SetOptions(
    {"Beginner", "Expert"},
    false
)

dropdown:SetDisabled(true)
dropdown:SetVisible(false)
dropdown:OnChanged(function(value)
    print(value)
end)
dropdown:Destroy()
```

`SetOptions(options, keepSelection)` replaces the choices. Set `keepSelection` to `true` to preserve the current selection if it remains valid.

## 5.10 Color picker

Creates a color-selection component.

```lua
local colorPicker = tab:CreateColorPicker({
    Name = "Accent color",
    Description = "Choose a custom color",
    Icon = "palette",
    Default = Color3.fromRGB(130, 90, 255),
    Transparency = true,
    DefaultAlpha = 1,
    Flag = "accentColor",
    Callback = function(color, alpha)
        print(color, alpha)
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Default` | Color3? | No; uses current accent color |
| `Transparency` | boolean? | No |
| `DefaultAlpha` | number? | No; defaults to `1` |
| `Callback` | function? | No |
| `Disabled` | boolean? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

`Transparency = true` enables the alpha control.

### Methods

```lua
local color = colorPicker:Get()
local alpha = colorPicker:GetAlpha()
local hex = colorPicker:GetHex()

colorPicker:Set(Color3.fromRGB(255, 0, 0))
colorPicker:SetAlpha(0.5)

colorPicker:SetDisabled(true)
colorPicker:SetVisible(false)
colorPicker:OnChanged(function(color, alpha)
    print(color, alpha)
end)
colorPicker:Destroy()
```

Alpha values are clamped between `0` and `1`. `GetHex()` returns a hexadecimal color string.

## 5.11 Text input

Creates a text field.

```lua
local input = tab:CreateTextInput({
    Name = "Username",
    Description = "Enter a username",
    Icon = "user",
    Default = "",
    Placeholder = "Enter text...",
    Password = false,
    MaxLength = 32,
    Validate = function(text)
        return #text > 0
    end,
    Flag = "username",
    Callback = function(text)
        print("Submitted:", text)
    end,
    OnChange = function(text)
        print("Changed:", text)
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Default` | string? | No |
| `Placeholder` | string? | No |
| `Password` | boolean? | No |
| `MaxLength` | number? | No |
| `Validate` | function? | No |
| `Callback` | function? | No |
| `OnChange` | function? | No |
| `Disabled` | boolean? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

`Validate(text)` should return a truthy value for valid text and a falsey value for invalid text.

### Methods

```lua
local text = input:Get()
input:Set("New text")
input:Set("New text", true)

local valid = input:IsValid()

input:Focus()
input:SetDisabled(true)
input:SetVisible(false)
input:OnChanged(function(value)
    print(value)
end)
input:Destroy()
```

Password inputs are excluded from exported configurations.

## 5.12 Search bar

Creates a search field.

```lua
local search = tab:CreateSearchBar({
    Placeholder = "Search components...",
    Callback = function(query)
        print("Query:", query)
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Placeholder` | string? | No |
| `Callback` | function? | No |

The callback fires when the text changes.

### Methods

```lua
search:Get()
search:Set("Search term")
search:SetVisible(false)
search:Destroy()
```

## 5.13 Keybind

Creates a keybind selector.

```lua
local keybind = tab:CreateKeybind({
    Name = "Toggle feature",
    Description = "Choose a keyboard shortcut",
    Icon = "keyboard",
    Default = Enum.KeyCode.G,
    Flag = "toggleKey",
    Callback = function(newKey)
        print("Bound key changed:", newKey)
    end,
    OnPress = function()
        print("Bound key pressed!")
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Default` | EnumItem? | No |
| `Callback` | function? | No |
| `OnPress` | function? | No |
| `Disabled` | boolean? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

`Default` should be an `Enum.KeyCode` value when provided.

- `Callback` runs when the bound key changes.
- `OnPress` runs when the assigned key is pressed.

### Methods

```lua
local key = keybind:Get()
keybind:Set(Enum.KeyCode.H)
keybind:Set(nil) -- clear the binding

keybind:SetDisabled(true)
keybind:SetVisible(false)
keybind:OnChanged(function(newKey)
    print(newKey)
end)
keybind:Destroy()
```

## 5.14 Progress bar

Creates a progress indicator.

```lua
local progress = tab:CreateProgressBar({
    Name = "Download",
    Description = "Download progress",
    Icon = "list",
    Min = 0,
    Max = 100,
    Default = 45,
    ShowValue = true,
    Format = function(value)
        return tostring(value) .. "%"
    end,
    Flag = "downloadProgress"
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Min` | number? | No; defaults to `0` |
| `Max` | number? | No; defaults to `100` |
| `Default` | number? | No; defaults to `Min` |
| `ShowValue` | boolean? | No |
| `Format` | function? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

`Min` must be less than `Max`. `Format(value)` customizes the displayed value.

### Methods

```lua
local value = progress:Get()
progress:Set(75)
progress:Set(50, true)
progress:SetText("Loading...")
progress:SetVisible(false)
progress:Destroy()
```

## 5.15 Loader

Creates an animated loading spinner.

```lua
local loader = tab:CreateLoader({
    Name = "Loading data",
    Description = "Please wait...",
    Active = true
})
```

You can also pass the name directly:

```lua
local loader = tab:CreateLoader("Loading")
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Active` | boolean? | No; defaults to `true` |

### Methods

```lua
loader:SetActive(true)
loader:SetActive(false)
loader:SetText("Finished")
loader:SetVisible(false)
loader:Destroy()
```

## 5.16 List

Creates a list of selectable items.

```lua
local list = tab:CreateList({
    Name = "Available items",
    Description = "Select an item",
    Icon = "list",
    Items = {"Sword", "Shield", "Potion"},
    Default = "Sword",
    Height = 140,
    Searchable = true,
    Flag = "selectedItem",
    Callback = function(item)
        print("Selected:", item)
    end
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Description` | string? | No |
| `Icon` | string? | No |
| `Items` | table? | No; defaults to an empty list |
| `Default` | any? | No |
| `Height` | number? | No; defaults to `140` |
| `Searchable` | boolean? | No |
| `Callback` | function? | No |
| `Disabled` | boolean? | No |
| `Tooltip` | string? | No |
| `ContextMenu` | table? | No |
| `Flag` | string? | No |

### Methods

```lua
local selected = list:Get()
list:Set("Potion")
list:Set("Shield", true)

list:SetItems({"Bow", "Staff"})
list:SetDisabled(true)
list:SetVisible(false)
list:OnChanged(function(item)
    print(item)
end)
list:Destroy()
```

`SetItems(items)` replaces the list contents. Selection must match an item in the list.

## 5.17 Expandable

Creates a collapsible container that can hold other components.

```lua
local expandable = tab:CreateExpandable({
    Name = "Advanced settings",
    Icon = "settings",
    Open = false
})

expandable:CreateToggle({
    Name = "Advanced mode",
    Flag = "advancedMode",
    Default = false
})

expandable:CreateSlider({
    Name = "Power",
    Flag = "power",
    Min = 1,
    Max = 10,
    Default = 5
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Name` | string | Yes |
| `Icon` | string? | No |
| `Open` | boolean? | No; defaults to `false` |

An expandable inherits the component-creation methods, so you can place supported components inside it, including additional expandable sections.

### Methods

```lua
expandable:SetOpen(true)
expandable:SetOpen(false)
expandable:SetVisible(false)
expandable:Destroy()
```

---

# 6. Shared component methods

Most interactive elements provide the following methods where applicable.

| Method | Purpose |
|---|---|
| `Get()` | Returns the current value |
| `Set(value, silent?)` | Changes the value |
| `SetVisible(boolean)` | Shows or hides the component |
| `SetDisabled(boolean)` | Enables or disables interaction |
| `IsDisabled()` | Returns whether the component is disabled |
| `OnChanged(callback)` | Subscribes to value changes |
| `Destroy()` | Removes the component and cleans up its resources |

Not every component implements every method. Refer to the individual component's method list.

For example:

```lua
local toggle = tab:CreateToggle({
    Name = "Enabled",
    Flag = "enabled"
})

toggle:OnChanged(function(value)
    print("Changed:", value)
end)

toggle:Set(true)
print(toggle:Get())
```

`OnChanged` returns a connection-like object with a `Disconnect()` method.

---

# 7. Context menus

Interactive components that support `ContextMenu` can display a menu when right-clicked.

```lua
tab:CreateButton({
    Name = "My action",
    ContextMenu = {
        {
            Name = "Copy",
            Icon = "copy",
            Callback = function()
                print("Copy clicked")
            end
        },
        "-",
        {
            Name = "Delete",
            Danger = true,
            Callback = function()
                print("Delete clicked")
            end
        }
    },
    Callback = function()
        print("Button clicked")
    end
})
```

Each menu item supports:

| Argument | Type | Description |
|---|---|---|
| `Name` | string? | Item label |
| `Icon` | string? | Icon name |
| `Callback` | function? | Action to run |
| `Danger` | boolean? | Displays the item in the danger color |

Use the string `"-"` to insert a separator.

---

# 8. Window methods

These methods operate on a window returned by `CreateWindow`.

```lua
window:Open()
window:Close()
window:Toggle()

print(window:IsOpen())

window:Minimize()
window:Restore()

print(window:IsMinimized())
```

| Method | Description |
|---|---|
| `Open()` | Opens the window |
| `Close()` | Closes the window |
| `Toggle()` | Opens or closes the window |
| `IsOpen()` | Returns the open state |
| `Minimize()` | Minimizes the window |
| `Restore()` | Restores the window |
| `IsMinimized()` | Returns the minimized state |
| `CreateTab(options)` | Creates a tab |
| `GetTab(name)` | Finds a tab by name |
| `RemoveTab(tab)` | Removes a tab |
| `SelectTab(tab)` | Selects a tab |
| `Notify(options)` | Shows a notification |
| `Confirm(options)` | Opens a confirmation dialog |
| `SetAccent(color)` | Changes the global accent |
| `GetAccent()` | Returns the current accent |
| `SetTitle(title, subtitle?)` | Updates window text |
| `SetToggleKey(key)` | Changes the window toggle key |
| `GetElement(flag)` | Returns a component by flag |
| `GetFlag(flag)` | Returns the value associated with a flag |
| `SetFlag(flag, value, silent?)` | Changes a flagged component |
| `ExportConfig()` | Exports the current configuration to JSON |
| `ImportConfig(json)` | Imports configuration JSON |
| `SaveConfig(name?)` | Saves a configuration |
| `LoadConfig(name?)` | Loads a configuration |
| `Destroy()` | Removes the window and cleans up resources |

### Changing values through flags

```lua
window:SetFlag("enabled", true)

local enabled = window:GetFlag("enabled")
local component = window:GetElement("enabled")
```

`GetFlag` and `SetFlag` throw an error if the flag does not exist.

### Changing the title and key

```lua
window:SetTitle("New title", "New subtitle")
window:SetToggleKey(Enum.KeyCode.RightShift)
```

---

# 9. Notifications

Notifications appear as temporary messages on the screen.

```lua
window:Notify({
    Title = "Success",
    Content = "Your settings have been saved.",
    Duration = 3,
    Type = "Success"
})
```

### Arguments

| Argument | Type | Required |
|---|---|---|
| `Title` | string? | No |
| `Content` | string? | No |
| `Duration` | number? | No; defaults to `4` seconds |
| `Type` | string? | No; defaults to `"Info"` |

Supported types:

- `Info`
- `Success`
- `Warning`
- `Error`

A duration of `0` keeps the notification visible until it is dismissed.

You can also use the library-level method:

```lua
NovaUI:Notify({
    Title = "Hello",
    Content = "Welcome!",
    Type = "Info"
})
```

The library-level method uses the most recently created window, if one exists.

---

# 10. Confirmation dialogs

Use `Confirm()` to ask the user to confirm an action.

```lua
window:Confirm({
    Title = "Delete item?",
    Message = "This action cannot be undone.",
    ConfirmText = "Delete",
    CancelText = "Cancel",
    Danger = true,
    Callback = function(confirmed)
        if confirmed then
            print("Confirmed")
        else
            print("Cancelled")
        end
    end
})
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `Title` | string? | Dialog title |
| `Message` | string? | Dialog message |
| `ConfirmText` | string? | Confirmation button label |
| `CancelText` | string? | Cancellation button label |
| `Danger` | boolean? | Danger styling |
| `Callback` | function? | Receives `confirmed` |
| `OnConfirm` | function? | Called when confirmed |
| `OnCancel` | function? | Called when cancelled |

All arguments are optional. The dialog returns its own cleanup object; consult the implementation if you need to manage it directly.

---

# 11. Configuration API

Configuration data includes the accent color and serializable component values. Components need flags to be accessed by name.

## Export a configuration

```lua
local json = window:ExportConfig()
print(json)
```

Returns a JSON string.

## Import a configuration

```lua
local success, err = window:ImportConfig(json)

if not success then
    warn(err)
end
```

Returns a success boolean and an error message on failure.

## Save a configuration

```lua
local success = window:SaveConfig("Default")
```

Returns a success boolean.

## Load a configuration

```lua
local success, err = window:LoadConfig("Default")

if not success then
    warn(err)
end
```

The name is optional and defaults to `"default"`.

## Custom configuration storage

NovaUI's default configuration provider stores data in memory. The data is not persistent after a script restart.

You can replace it with `SetConfigProvider()`:

```lua
local configs = {}

NovaUI:SetConfigProvider({
    Save = function(name, json)
        configs[name] = json
    end,

    Load = function(name)
        return configs[name]
    end
})
```

The provider must implement:

- `Save(name, json)`
- `Load(name)`

Both functions are required. Use your own appropriate storage implementation if persistence is required.

---

# 12. Theme API

Access the theme module using `NovaUI.Theme`.

```lua
local Theme = NovaUI.Theme
```

## Accent presets

```lua
Theme.AccentPresets.Violet
Theme.AccentPresets.Blue
Theme.AccentPresets.Teal
Theme.AccentPresets.Green
Theme.AccentPresets.Amber
Theme.AccentPresets.Rose
```

Example:

```lua
window:SetAccent(Theme.AccentPresets.Teal)
```

You can also use a custom color:

```lua
window:SetAccent(Color3.fromRGB(255, 80, 120))
```

## Theme methods

```lua
local accent = Theme.GetAccent()

Theme.SetAccent(Color3.fromRGB(255, 0, 0))

local connection = Theme.OnChange(function(color)
    print("Accent changed:", color)
end)

connection:Disconnect()
```

Other exposed helpers:

```lua
Theme.AccentHover()
Theme.AccentPressed()
Theme.AccentMuted()
Theme.OnAccent()
```

These return calculated colors for hover, pressed, muted accent, and readable text on the accent.

## Theme tables

`Theme.Colors` exposes the default palette:

- `Background`
- `Chrome`
- `Panel`
- `Element`
- `ElementHover`
- `ElementActive`
- `Stroke`
- `Text`
- `TextMuted`
- `TextDim`
- `Danger`
- `Success`
- `Warning`

`Theme.Fonts` exposes `Regular`, `Medium`, `SemiBold`, and `Bold`.

---

# 13. Icons API

Access icons through `NovaUI.Icons`.

## Create an icon

```lua
local icon = NovaUI.Icons.Create("settings", {
    Size = 24,
    Color = Color3.new(1, 1, 1),
    Position = UDim2.new(0, 10, 0, 10),
    AnchorPoint = Vector2.new(0, 0),
    LayoutOrder = 1,
    ZIndex = 2,
    Parent = someGuiObject
})
```

### Arguments

The first argument is the icon name or an image asset string. The second argument is an optional table:

| Argument | Type | Description |
|---|---|---|
| `Size` | number? | Icon width and height in pixels |
| `Color` | Color3? | Icon color |
| `Position` | UDim2? | Position |
| `AnchorPoint` | Vector2? | Anchor point |
| `LayoutOrder` | number? | Layout order |
| `ZIndex` | number? | Display order |
| `Parent` | Instance? | Parent instance |

An asset string beginning with `rbxasset` is used as an image. Unknown icon names fall back to a letter.

## Icon methods

```lua
print(NovaUI.Icons.Has("settings"))

NovaUI.Icons.SetColor(
    icon,
    Color3.fromRGB(255, 0, 0),
    true
)
```

- `Has(name)` returns whether the name exists in the built-in icon definitions.
- `SetColor(icon, color, animate?)` changes the icon color.
- `Spinner(size?)` creates a spinner and returns its frame, stroke, and animation tween.

## Built-in icon names

The source defines these names and aliases:

`x`, `minus`, `plus`, `check`, `chevron-down`, `chevron-right`, `search`, `house`, `home`, `info`, `user`, `copy`, `palette`, `sliders`, `keyboard`, `list`, `settings`, `gear`, `close`, `cog`, `sliders_h`, `bell`, `dot`.

You can also supply your own image asset string.

---

# 14. Utility API

Access utilities through `NovaUI.Util`.

## Tweening

```lua
local Util = NovaUI.Util

Util.Tween(
    someInstance,
    Util.Info.Normal,
    { BackgroundTransparency = 0 }
)

Util.Apply(
    someInstance,
    { BackgroundTransparency = 1 },
    true,
    Util.Info.Fast
)
```

Available animation presets:

- `Util.Info.Fast`
- `Util.Info.Normal`
- `Util.Info.Slow`
- `Util.Info.Drag`

`Tween(instance, tweenInfo, properties)` animates properties. A numeric tween duration is also accepted.

`Apply(instance, properties, animate?, tweenInfo?)` applies properties immediately or animates them.

## Color helpers

```lua
local hex = Util.ToHex(Color3.fromRGB(255, 0, 0))
local color = Util.FromHex("#FF0000")
```

- `ToHex(color)` returns a hexadecimal color string.
- `FromHex(text)` converts a valid hexadecimal string to a `Color3`, or returns `nil` if invalid.

## Number helpers

```lua
Util.Decimals(1.25)
Util.Snap(4.7, 0, 10, 0.5)
Util.FormatNumber(12.345, 2)
Util.Trim("  hello  ")
```

- `Decimals(number)` counts decimal places.
- `Snap(value, min, max, step)` snaps a number to a step.
- `FormatNumber(number, decimals?)` formats a number.
- `Trim(string)` removes surrounding whitespace.

## Signals

```lua
local signal = Util.Signal.new()

local connection = signal:Connect(function(value)
    print(value)
end)

signal:Fire("Hello")
connection:Disconnect()
signal:Destroy()
```

## Cleanup

```lua
local maid = Util.Maid.new()

maid:Give(someConnection)
maid:Give(someInstance)
maid:Give(function()
    print("Cleaned up")
end)

maid:Clean()
```

`Maid` can clean up connections, instances, functions, and supported cleanup objects. `Destroy()` is an alias for `Clean()`.

## Instance creation

```lua
local frame = Util.Create("Frame", {
    Size = UDim2.fromOffset(200, 100),
    Parent = someGuiObject
})
```

`Create(className, properties?, children?)` creates an Instance, applies properties, parents children, and then parents the created instance.

## Callback execution

```lua
Util.Fire(function(value)
    print(value)
end, "Hello")
```

`Fire(callback, ...)` invokes a callback safely and warns if it errors.

---

# 15. Library-level methods

The main `NovaUI` object provides:

```lua
NovaUI:CreateWindow(options)
NovaUI:SetConfigProvider(provider)
NovaUI:Notify(options)
NovaUI:Destroy()
```

- `CreateWindow(options)` creates a new window.
- `SetConfigProvider(provider)` replaces configuration storage.
- `Notify(options)` sends a notification through the latest window.
- `Destroy()` destroys all windows created by the library.

Other exposed properties include:

```lua
NovaUI.Version
NovaUI.Theme
NovaUI.Util
NovaUI.Icons
NovaUI.Windows
NovaUI.ConfigProvider
```

---

# 16. Complete example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NovaUI = require(ReplicatedStorage.NovaUI)

local window = NovaUI:CreateWindow({
    Title = "Example Hub",
    Subtitle = "NovaUI demonstration",
    Icon = "house",
    AccentColor = NovaUI.Theme.AccentPresets.Violet,
    Size = Vector2.new(850, 550),
    ToggleKey = Enum.KeyCode.RightControl,
    Visible = true
})

local main = window:CreateTab({
    Name = "Main",
    Icon = "house",
    Badge = "NEW"
})

main:CreateSection("General")

main:CreateToggle({
    Name = "Enabled",
    Description = "Enable the example feature",
    Default = false,
    Flag = "enabled",
    Callback = function(value)
        print("Enabled:", value)
    end
})

main:CreateSlider({
    Name = "Intensity",
    Min = 0,
    Max = 100,
    Default = 50,
    Step = 5,
    Suffix = "%",
    ShowInput = true,
    Flag = "intensity",
    Callback = function(value)
        print("Intensity:", value)
    end
})

main:CreateDropdown({
    Name = "Mode",
    Options = {"Easy", "Normal", "Hard"},
    Default = "Normal",
    Searchable = true,
    Flag = "mode",
    Callback = function(value)
        print("Mode:", value)
    end
})

main:CreateButton({
    Name = "Save configuration",
    Style = "Primary",
    Callback = function()
        local success = window:SaveConfig("Default")

        window:Notify({
            Title = success and "Saved" or "Error",
            Content = success
                and "Configuration saved."
                or "Could not save configuration.",
            Type = success and "Success" or "Error"
        })
    end
})

local settings = window:CreateTab({
    Name = "Settings",
    Icon = "settings"
})

settings:CreateColorPicker({
    Name = "Accent color",
    Default = NovaUI.Theme.AccentPresets.Violet,
    Callback = function(color)
        window:SetAccent(color)
    end
})

settings:CreateButton({
    Name = "Load configuration",
    Callback = function()
        local success, err = window:LoadConfig("Default")

        if not success then
            warn(err)
        end
    end
})

print("Current enabled state:", window:GetFlag("enabled"))
print("Current configuration:", window:ExportConfig())
```

---

# 17. Important notes

1. **Flags:** Use unique flag strings to avoid components overwriting one another in the flag registry.
2. **Callbacks:** A component's `Callback` behavior depends on the component. Buttons invoke callbacks when activated; value components call them when their values change.
3. **Silent changes:** The `silent` argument suppresses normal callbacks for components whose `Set()` method supports it.
4. **Configurations:** Only serializable flagged values are included. Password text is excluded. Some components have specialized serialization formats.
5. **Storage:** The default provider uses memory. It does not automatically save to disk or a Roblox DataStore.
6. **Client-side use:** NovaUI is a client UI library. Server-side gameplay changes should be handled by your own server scripts and remotes.
7. **Validation:** Invalid argument types and unsupported button styles produce errors. Check the argument tables before creating components.
8. **Expandable containers:** Components created inside an expandable belong to that container and can be managed with its lifetime.
9. **Version:** The supplied ModuleScript identifies itself as NovaUI version `1.0.0`.

