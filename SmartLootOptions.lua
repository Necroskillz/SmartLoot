 function SmartLoot.PopulateOptionsUI()
	local setCheckbox = function(option, value)
		if(not value) then
			value = SmartLoot_Options[option];
		end
		
		getglobal("SmartLoot_OptionsFrame_"..option):SetChecked(value);
	end;
	
	setCheckbox("ShowAnchor");
	setCheckbox("HideDefaultFrames");
	setCheckbox("AutoLoot");
	setCheckbox("AutoConfirm");
	setCheckbox("ShowMinimapButton")
	
	SmartLoot_OptionsFrame_LootFrameCount_CountText:SetText(SmartLoot_Options.LootFrameCount);
	SmartLoot_OptionsFrame_MinimapButtonPosition:SetValue(SmartLoot_Options.MinimapButtonPosition);
	
	SmartLoot.AutorollList = {};
	SmartLoot.AutorollList.Offset = 0;
	SmartLoot.AutorollList.PageSize = 10;
	SmartLoot.AutorollList.QualityFilter = nil;
	SmartLoot.AutorollList.NameFilter = nil;
	
	SmartLoot.RenderAutorollList();
	
	local qualityDropDown = SmartLoot_OptionsFrame_AutorollListHeader_Quality;
	
	UIDropDownMenu_Initialize(qualityDropDown, SmartLoot.LoadQualityDropDown);
	UIDropDownMenu_SetSelectedID(qualityDropDown, 1);
	UIDropDownMenu_SetWidth(100, qualityDropDown);
	
	SmartLoot_OptionsFrame_AutorollListHeader_Name:SetText("");
end

function SmartLoot.LoadQualityDropDown()
	UIDropDownMenu_AddButton({
		text = "All";
		func = SmartLoot.SetAutorollQualityFilter;
		arg1 = nil;
	});
	
	for q = 2, 5, 1 do
		UIDropDownMenu_AddButton({
			text = ITEM_QUALITY_COLORS[q].hex..getglobal("ITEM_QUALITY"..q.."_DESC");
			func = SmartLoot.SetAutorollQualityFilter;
			arg1 = q;
		});
	end
end

function SmartLoot.SetAutorollQualityFilter()
	UIDropDownMenu_SetSelectedID(SmartLoot_OptionsFrame_AutorollListHeader_Quality, this:GetID());
	SmartLoot.AutorollList.QualityFilter = this.arg1;
end

function SmartLoot.ApplyFilter()
	SmartLoot.AutorollList.DataSource = nil;
	
	SmartLoot.AutorollList.NameFilter = SmartLoot_OptionsFrame_AutorollListHeader_Name:GetText();
	SmartLoot_OptionsFrame_AutorollListHeader_Name:ClearFocus();
	
	SmartLoot.RenderAutorollList();
end

function SmartLoot.UpdateAutorollListScrollBar()
	FauxScrollFrame_Update(SmartLoot_OptionsFrame_AutorollList_ScrollBar, SmartLoot.AutorollList.TotalCount, SmartLoot.AutorollList.PageSize, 18);
	SmartLoot.AutorollList.Offset = FauxScrollFrame_GetOffset(SmartLoot_OptionsFrame_AutorollList_ScrollBar);
	
	SmartLoot.RenderAutorollList();
end

function SmartLoot.OnOptionsHide()
	SmartLoot.AutorollList.DataSource = nil;
end

function SmartLoot.RenderAutorollList()
	if(SmartLoot.AutorollList.DataSource == nil) then
		SmartLoot.AutorollList.TotalCount, SmartLoot.AutorollList.DataSource = SmartLoot.GetAutorollListData(SmartLoot.AutorollList.QualityFilter, SmartLoot.AutorollList.NameFilter);
	end
	
	local hide = false;
	local displayedCount = 0;
	
	for i = 1, SmartLoot.AutorollList.PageSize, 1 do
		local frame = getglobal("SmartLoot_OptionsFrame_AutorollList_Item"..i);
		
		if(hide) then
			frame:Hide();
		else
			local index = i + SmartLoot.AutorollList.Offset;
			
			local info = SmartLoot.AutorollList.DataSource[index];
			if(info == nil) then
				hide = true;
				frame:Hide();
			else
				local color = ITEM_QUALITY_COLORS[info.quality];
				
				local text = getglobal(frame:GetName().."_Text");
				local need = getglobal(frame:GetName().."_Need");
				local greed = getglobal(frame:GetName().."_Greed");
				local pass = getglobal(frame:GetName().."_Pass");
				
				frame.itemName = info.name;
				frame.index = index;
				
				text:SetText(info.name);
				text:SetTextColor(color.r, color.g, color.b);
				
				need:SetChecked(info.roll == SmartLoot.Roll.Need);
				greed:SetChecked(info.roll == SmartLoot.Roll.Greed);
				pass:SetChecked(info.roll == SmartLoot.Roll.Pass);
				
				frame:Show();
				displayedCount = displayedCount + 1;
			end
		end
	end
	
	SmartLoot_OptionsFrame_AutorollList_Info:SetText("Showing "..(SmartLoot.AutorollList.Offset + 1).." - "..(SmartLoot.AutorollList.Offset + displayedCount).." of "..SmartLoot.AutorollList.TotalCount);
	FauxScrollFrame_Update(SmartLoot_OptionsFrame_AutorollList_ScrollBar, SmartLoot.AutorollList.TotalCount, SmartLoot.AutorollList.PageSize, 18);
end

function SmartLoot.AutorollListRemove(self)
	SmartLoot_Autoroll[self.itemName] = nil;
	
	SmartLoot.AutorollList.DataSource = nil;
	
	SmartLoot.RenderAutorollList();
end

function SmartLoot.SetAutoroll(self, roll)	
	SmartLoot_Autoroll[self.itemName].roll = roll;
	SmartLoot.AutorollList.DataSource[self.index].roll = roll;
	
	SmartLoot.RenderAutorollList();
end

function SmartLoot.SetOption(option, value)
	value = value or false;
	SmartLoot_Options[option] = value;
		
	if(option == "ShowAnchor") then
		SmartLoot.SetAnchorDisplay();
	elseif(option == "LootFrameCount") then
		SmartLoot_OptionsFrame_LootFrameCount_CountText:SetText(SmartLoot_Options.LootFrameCount);
		SmartLoot.CreateLootFrames();
	elseif(option == "HideDefaultFrames") then
		SmartLoot.ToggleDefaultFrames(not value);
	elseif(option == "ShowMinimapButton" or option == "MinimapButtonPosition") then
		SmartLoot.UpdateMinimapButtonPosition();
	end
end

function SmartLoot.GetAutorollListData(qualityFilter, nameFilter)
	local result = {};
	local count = 0;
	
	if(nameFilter) then
		nameFilter = string.lower(nameFilter);
	end
		
	for name, info in sorted(SmartLoot_Autoroll) do
		local add = true;
		
		if(qualityFilter and info.quality ~= qualityFilter) then
			add = false;
		end
		
		if(nameFilter and string.find(string.lower(name), nameFilter) == nil) then
			add = false;
		end
		
		if(add) then
			table.insert(result, { name = name, quality = info.quality, roll = info.roll });
			count = count + 1;
		end
	end
	
	return count, result;
end

-- taken from lua tutorial, sorts a table by its key
function sorted(t, f)
	local a = {};
	for n in pairs(t) do table.insert(a, n); end
	table.sort(a, f);
	local i = 0;
	local iter = function ()
		i = i + 1;
		if a[i] == nil then return nil;
		else return a[i], t[a[i]];
		end
	end
	return iter;
end