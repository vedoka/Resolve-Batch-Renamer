-- DaVinci Resolve Batch Rename Script (Lua)

local resolve = Resolve()
local fusion = resolve:Fusion()
local ui = fusion.UIManager
local disp = bmd.UIDispatcher(ui)

function get_timeline_items(timeline, track_type, track_index)
    -- track_type: "video" or "audio"
    -- track_index: 1-based index
    local items = timeline:GetItemListInTrack(track_type, track_index)
    return items
end

function rename_sequential(items, base_name, start_num, padding, increment)
    local current_num = start_num
    local count = 0
    
    resolve:OpenPage("edit")
    
    print("Found " .. #items .. " items on the track.")

    for i, item in ipairs(items) do
        -- Format the number with padding
        local num_str = string.format("%0" .. padding .. "d", current_num)
        local new_name = base_name .. "_" .. num_str
        local renamed = false

        -- Try renaming the Timeline Item instance (Display Name)
        if item:SetProperty("Name", new_name) then
            print("Renamed Timeline Item to " .. new_name)
            renamed = true
        end

        -- If that fails or isn't supported, try renaming the underlying Media Pool Item
        -- (This changes the actual clip name in the bin, which updates the timeline)
        if not renamed then
            local mp_item = item:GetMediaPoolItem()
            if mp_item then
                if mp_item:SetClipProperty("Clip Name", new_name) then
                    print("Renamed Media Pool Item execution to " .. new_name)
                    renamed = true
                end
            end
        end

        if not renamed then
            print("Failed to rename item index " .. i)
        end
        
        current_num = current_num + increment
        count = count + 1
    end
    return count
end

function rename_simple(items, find_str, replace_str)
    local count = 0
    print("Found " .. #items .. " items on the track.")
    
     for i, item in ipairs(items) do
        local current_name = item:GetName() -- This gets the Timeline Item name
        if string.find(current_name, find_str) then
            local new_name = string.gsub(current_name, find_str, replace_str)
            local renamed = false

            if item:SetProperty("Name", new_name) then
                 print("Renamed Timeline Item " .. current_name .. " to " .. new_name)
                 renamed = true
            end
            
            if not renamed then
                 local mp_item = item:GetMediaPoolItem()
                 if mp_item then
                     if mp_item:SetClipProperty("Clip Name", new_name) then
                         print("Renamed Media Pool Item " .. current_name .. " to " .. new_name)
                         renamed = true
                     end
                 end
            end

            if renamed then
                count = count + 1
            end
        end
    end
    return count
end

-- UI Setup
local win = disp:AddWindow({
    ID = "MyWin",
    TargetID = "MyWin",
    WindowTitle = "Batch Rename (Lua)",
    Geometry = {800, 600, 400, 500},
}, {
    ui:VGroup{
        -- Mode Selection
        ui:Label{ID = "LabelMode", Text = "Rename Mode", Weight = 0},
        ui:ComboBox{ID = "ModeCombo", Text = "Mode"},
        
        ui:VGap(10),

        -- Track Selection
        ui:HGroup{
            Weight = 0,
            ui:Label{ID = "LabelTrack", Text = "Video Track Index", Weight = 0.5},
            ui:SpinBox{ID = "TrackSpin", Minimum = 1, Maximum = 100, Value = 1, Weight = 0.5},
        },
        
        ui:VGap(10),

        -- Sequential Options Group
        ui:VGroup{
            ID = "SequentialGroup", 
            Weight = 0,
            ui:Label{Text = "Sequential Settings", Font = ui:Font{PixelSize = 14, Bold = true}},
            ui:HGroup{
                Weight = 0,
                ui:Label{Text = "Base Name", Weight = 0.3},
                ui:LineEdit{ID = "BaseNameEdit", Text = "Shot", PlaceholderText = "Base Name", Weight = 0.7},
            },
            ui:HGroup{
                Weight = 0,
                ui:Label{Text = "Start Number", Weight = 0.3},
                ui:SpinBox{ID = "StartNumSpin", Minimum = 0, Maximum = 999999, Value = 10, Weight = 0.7},
            },
            ui:HGroup{
                Weight = 0,
                ui:Label{Text = "Padding", Weight = 0.3},
                ui:SpinBox{ID = "PaddingSpin", Minimum = 1, Maximum = 10, Value = 4, Weight = 0.7},
            },
            ui:HGroup{
                Weight = 0,
                ui:Label{Text = "Increment", Weight = 0.3},
                ui:SpinBox{ID = "IncrementSpin", Minimum = 1, Maximum = 100, Value = 10, Weight = 0.7},
            },
        },

        -- Simple Options Group
        ui:VGroup{
            ID = "SimpleGroup", 
            Visible = false, 
            Weight = 0,
            ui:Label{Text = "Find & Replace Settings", Font = ui:Font{PixelSize = 14, Bold = true}},
            ui:LineEdit{ID = "FindEdit", PlaceholderText = "Find", Weight = 0},
            ui:LineEdit{ID = "ReplaceEdit", PlaceholderText = "Replace", Weight = 0},
        },

        ui:VGap(20),
        
        -- Buttons
        ui:HGroup{
            Weight = 0,
            ui:Button{ID = "ApplyBtn", Text = "Apply Rename", Weight = 1},
        },
        ui:VGap(),
    },
})

local itm = win:GetItems()

-- Add Modes
itm.ModeCombo:AddItems({"Sequential", "Simple Find/Replace"})

-- Event Handlers
function win.On.ModeCombo.CurrentIndexChanged(ev)
    local idx = itm.ModeCombo.CurrentIndex
    if idx == 0 then
        itm.SequentialGroup.Visible = true
        itm.SimpleGroup.Visible = false
    else
        itm.SequentialGroup.Visible = false
        itm.SimpleGroup.Visible = true
    end
end

function win.On.ApplyBtn.Clicked(ev)
    local project = resolve:GetProjectManager():GetCurrentProject()
    if not project then
        print("No project found")
        return
    end

    local timeline = project:GetCurrentTimeline()
    if not timeline then
        print("No timeline found")
        return
    end

    local mode = itm.ModeCombo.CurrentIndex
    local track_idx = itm.TrackSpin.Value
    local items = get_timeline_items(timeline, "video", track_idx)
    
    if not items or #items == 0 then
        print("No items found on track " .. track_idx)
        return
    end

    local count = 0
    if mode == 0 then -- Sequential
        local base = itm.BaseNameEdit.Text
        local start = itm.StartNumSpin.Value
        local pad = itm.PaddingSpin.Value
        local inc = itm.IncrementSpin.Value
        count = rename_sequential(items, base, start, pad, inc)
    else -- Simple
        local find_s = itm.FindEdit.Text
        local rep_s = itm.ReplaceEdit.Text
        count = rename_simple(items, find_s, rep_s)
    end
        
    print("Renamed " .. count .. " items.")
end

function win.On.MyWin.Close(ev)
    disp:ExitLoop()
end

win:Show()
disp:RunLoop()
win:Hide()
