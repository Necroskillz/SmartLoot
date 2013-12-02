SmartLoot = {};

SmartLoot.Version = "1.1";

SmartLoot.Roll = {
	Pass = 0;
	Need = 1;
	Greed = 2;
};

SmartLoot_Options = nil;
SmartLoot_Autoroll = {};
SmartLoot.LootFrames = nil;
SmartLoot.Queue = {};

SmartLoot.Res = {
	MinmapTooltip1 = "SmartLoot";
	MinmapTooltip2 = "Left click to open options";
	MinmapTooltip3 = "Right click and drag to move this button";
	ShowAnchor = {
		Label = "Show anchor";
		Tooltip = "";
	};
	HideDefaultFrames = {
		Label = "Hide default loot frames";
		Tooltip = "Wether to hide default blizzard group loot UI. Unchecking this will show any active loot frames. Can be used for debugging.";
	};
	AutoLoot = {
		Label = "Autoloot";
		Tooltip = "Automatically roll on loot using defined loot rules.";
	};
	AutoConfirm = {
		Label = "Autoconfirm rolls";
		Tooltip = "Automatically confim rolling on BoP items.";
	};
	LootFrameCount = {
		Label = "Loot frame count";
		Tooltip = "Number of loot frames that can be visible at a time.";
	};
	TestLoot = {
		Label = "Show test loot";
		Tooltip = "Displays a fake loot item for each loot frame. This option is not saved. Rolling on this loot doesn't work, use this checkbox again to delete it.";
	};
	ShowMinimapButton = {
		Label = "Show minimap button";
		Tooltip = "";
	};
	MinimapButtonPosition = "Minimap button position";
}

function SmartLoot.OnLoad(self)
		
	SLASH_SLOOT1 = "/sloot";
	
	SlashCmdList["SLOOT"] = function(msg)
		SmartLoot.ToggleOptions();
	end
	
	self:RegisterEvent("CONFIRM_LOOT_ROLL");
	self:RegisterEvent("START_LOOT_ROLL");
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("CANCEL_LOOT_ROLL");
end

function SmartLoot.OnEvent(event)
	if(event == "START_LOOT_ROLL") then		
		if(SmartLoot_Options.HideDefaultFrames) then
			SmartLoot.ToggleDefaultFrames(false);
		end
	
		local rollId = arg1;
		local timeout = arg2;
				
		local texture, name, count, quality, bindOnPickup = GetLootRollItemInfo(rollId);
		
		if(SmartLoot_Options.AutoLoot and SmartLoot_Autoroll[name]) then
			RollOnLoot(rollId, SmartLoot_Autoroll[name].roll);
		else
			SmartLoot.QueueLoot(rollId, timeout, texture, name, quality);
		end
	elseif(event == "CANCEL_LOOT_ROLL") then
		-- fires after rolling or passing on an item
		SmartLoot.ClearLoot(arg1);
	elseif(event == "CONFIRM_LOOT_ROLL") then
		if(SmartLoot_Options.AutoConfirm) then
			ConfirmLootRoll(arg1, arg2);
			StaticPopup_Hide("CONFIRM_LOOT_ROLL", arg1);
		end
	elseif(event == "ADDON_LOADED" and arg1 == "SmartLoot") then
		SmartLoot.EnsureOptions();
		SmartLoot.Initialize();
	end
end

function SmartLoot.EnsureOptions()
	if(not SmartLoot_Options) then
		SmartLoot_Options = {};
	end
	
	local set = function(option, value)
		if(SmartLoot_Options[option] == nil) then
			SmartLoot_Options[option] = value;
		end
	end;

	set("ShowAnchor", true);
	set("HideDefaultFrames", true);
	set("AutoLoot", true);
	set("AutoConfirm", true);
	set("LootFrameCount", 4);
	set("MinimapButtonPosition", 281);
	set("ShowMinimapButton", true);
end

function SmartLoot.SetAnchorDisplay()
	if(SmartLoot_Options.ShowAnchor) then
		SmartLoot_LootFrame:Show();
	else
		SmartLoot_LootFrame:Hide();
	end
end

function SmartLoot.ToggleDefaultFrames(show)
	local toggle;
	
	if(show) then
		toggle = function(frame)
			local rollId = frame.rollID;
						
			if(rollId ~= nil and GetLootRollTimeLeft(rollId) > 0) then
				frame:Show();
			end
		end
	else
		toggle = function(frame)
			frame:Hide();
		end
	end
	
	for id = 1, 4, 1 do
		local defaultLootFrame = getglobal("GroupLootFrame"..id);
		
		toggle(defaultLootFrame);
	end
end

function SmartLoot.CreateLootFrames()
	SmartLoot.LootFrames = {};
	
	for id = 1, SmartLoot_Options.LootFrameCount, 1 do
		
		local frameName = "SmartLoot_Loot"..id;
		local frame = getglobal(frameName);
				
		if(not frame) then
			local frameName = "SmartLoot_Loot"..id;
			frame = CreateFrame("Frame", frameName, UIParent, "SmartLoot_RollTemplate");
			frame:Hide();
			frame:SetPoint("TOP", SmartLoot_LootFrame, "BOTTOM", 0, (id - 1) * -40 - (id - 1) * 2)
			frame.loot = nil;
			
			local needDropDown = CreateFrame("Frame", frameName.."_AdvancedNeedDropDown", frame);
			needDropDown.initialize = SmartLoot.InitializeNeedDropDown;
			
			local greedDropDown = CreateFrame("Frame", frameName.."_AdvancedGreedDropDown", frame);
			greedDropDown.initialize = SmartLoot.InitializeGreedDropDown;
			
			local passDropDown = CreateFrame("Frame", frameName.."_AdvancedPassDropDown", frame);
			passDropDown.initialize = SmartLoot.InitializePassDropDown;
		end
				
		SmartLoot.LootFrames[id] = frame;
		
	end
end

function SmartLoot.InitializeNeedDropDown()
	local lootFrame = this:GetParent();
	
	SmartLoot.AddAutoLootButton(SmartLoot.Roll.Need, "Need", lootFrame.loot);
end

function SmartLoot.InitializeGreedDropDown()
	local lootFrame = this:GetParent();
	
	SmartLoot.AddAutoLootButton(SmartLoot.Roll.Greed, "Greed", lootFrame.loot);
end

function SmartLoot.InitializePassDropDown()
	local lootFrame = this:GetParent();
	
	SmartLoot.AddAutoLootButton(SmartLoot.Roll.Pass, "Pass", lootFrame.loot);
end

function SmartLoot.AddAutoLootButton(rollId, rollName, loot)
	local color = ITEM_QUALITY_COLORS[loot.quality];
	UIDropDownMenu_AddButton({
		text = "Always "..rollName.." on "..color.hex.."["..loot.name.."]|r";
		func = SmartLoot.AddAutoLoot;
		arg1 = { loot = loot; roll = rollId };
		notCheckable = true;
		justifyH = "CENTER";
	});
end

function SmartLoot.AddAutoLoot()
	local roll = this.arg1.roll;
	local loot = this.arg1.loot;
	
	SmartLoot_Autoroll[loot.name] = {
		quality = loot.quality;
		roll = roll;
	};
	
	local tmp = {};
	
	for i, l in ipairs(SmartLoot.Queue) do
		if(l.name == loot.name) then
			table.insert(tmp, l.rollId);
		end
	end
	
	for i, id in ipairs(tmp) do
		RollOnLoot(id, roll);
	end
end

function SmartLoot.Initialize()

	tinsert(UISpecialFrames, "SmartLoot_OptionsFrame"); -- enables closing the options frame by pressing Esc
		
	SmartLoot.SetAnchorDisplay();
	SmartLoot.UpdateMinimapButtonPosition();
	SmartLoot.CreateLootFrames();
	SmartLoot.Print("loaded. v"..SmartLoot.Version.." by Necroskillz. Use /sloot or minimap button to open options.");
	
end

-- function SmartLoot.HandleLootMsg(msg)
	-- -- You have selected Need|Greed for: |cff1eff00|Hitem:6344:0:0:0|h[....]|h|r
	-- -- You passed on: |itemlink[]
	-- -- You won: |itemlink[]
	-- -- Everyone passed on: |itemlink[]
-- end

function SmartLoot.QueueLoot(rollId, timeout, texture, name, quality)
	table.insert(SmartLoot.Queue, {
		rollId = rollId;
		timeout = timeout;
		texture = texture;
		name = name;
		quality = quality;
		r = false;
	});

	SmartLoot.ProcessQueue();
end

function SmartLoot.ProcessQueue()
	local i = 1;
	for j, frame in ipairs(SmartLoot.LootFrames) do
		local loot = SmartLoot.Queue[i];
		if(loot) then
			SmartLoot.PopulateLootFrame(frame, loot);
		else
			frame:Hide();
			frame.loot = nil;
		end
		
		i = i + 1;
	end
end

function SmartLoot.PopulateLootFrame(frame, loot)
	frame.loot = loot;
	
	local frameName = frame:GetName();
	local icon = getglobal(frameName.."_Icon_Image");
	local itemName = getglobal(frameName.."_Info_ItemName");
	local timeoutBar = getglobal(frameName.."_Timeout");
		
	timeoutBar:SetMinMaxValues(0, loot.timeout);
	timeoutBar:SetValue(loot.timeout);
	icon:SetTexture(loot.texture);
	itemName:SetText(loot.name);
	
	local color = ITEM_QUALITY_COLORS[loot.quality];
	itemName:SetTextColor(color.r, color.g, color.b, 1);
	
	frame:Show();
end

function SmartLoot.ClearLoot(rollId)
	for i, loot in ipairs(SmartLoot.Queue) do
		if(loot.rollId == rollId) then
			table.remove(SmartLoot.Queue, i);
			break;
		end
	end
		
	SmartLoot.ProcessQueue();
	StaticPopup_Hide("CONFIRM_LOOT_ROLL", arg1);
end

function SmartLoot.OnTimeoutBarUpdate(self)
	local timeoutBar = getglobal(self:GetName().."_Timeout");
	local remaining = GetLootRollTimeLeft(self.loot.rollId);
	
	if(remaining > 0) then
		timeoutBar:SetValue(remaining);
	end	
end

function SmartLoot.RollNeed(self)
	local rollId = self.loot.rollId;
	RollOnLoot(rollId, SmartLoot.Roll.Need);
end

function SmartLoot.RollGreed(self)
	local rollId = self.loot.rollId;
	RollOnLoot(rollId, SmartLoot.Roll.Greed);
end

function SmartLoot.Pass(self)
	local rollId = self.loot.rollId;
	RollOnLoot(rollId, SmartLoot.Roll.Pass);
end

function SmartLoot.OnIconEnter(self)
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth()), 0);
	GameTooltip:SetLootRollItem(self.loot.rollId);
	GameTooltip:Show();
end

function SmartLoot.OnIconLeave(self)
	GameTooltip:Hide();
end

function SmartLoot.ToggleTestLoot(show)
	if(show) then
		for i = 1, SmartLoot_Options.LootFrameCount, 1 do
			SmartLoot.QueueLoot(-1, 60000, "Interface\\Icons\\INV_Helmet_51", "Crimson Felt Hat", 3);
		end
	else
		local removeTable = {};
		
		for i, loot in ipairs(SmartLoot.Queue) do
			if(loot.rollId == -1) then
				table.insert(removeTable, i);
			end
		end
		
		for i, id in ipairs(removeTable) do
			table.remove(SmartLoot.Queue, id);
		end
		
		SmartLoot.ProcessQueue();
	end
end

function SmartLoot.ToggleOptions()
	local f = SmartLoot_OptionsFrame;
	if(f:IsVisible()) then
		f:Hide();
	else
		f:Show();
	end
end

function SmartLoot.Print(text)
	if(text == nil) then
		text = "-nil-";
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("SmartLoot: "..(text));
end