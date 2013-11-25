function SmartLoot.MinimapButtonBeingDragged()
    local xpos,ypos = GetCursorPosition() 
    local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom() 

    xpos = xmin-xpos/UIParent:GetScale()+70 
    ypos = ypos/UIParent:GetScale()-ymin-70 

    SmartLoot.SetMinimapButtonPosition(math.deg(math.atan2(ypos,xpos)));
end

function SmartLoot.SetMinimapButtonPosition(v)
    if(v < 0) then
        v = v + 360;
    end

    SmartLoot_Options.MinimapButtonPosition = v;
    SmartLoot.UpdateMinimapButtonPosition();
end

function SmartLoot.UpdateMinimapButtonPosition()
	if(SmartLoot_Options.ShowMinimapButton) then
		SmartLoot_Minimap:SetPoint(
			"TOPLEFT",
			"Minimap",
			"TOPLEFT",
			54 - (78 * cos(SmartLoot_Options.MinimapButtonPosition)),
			(78 * sin(SmartLoot_Options.MinimapButtonPosition)) - 55
		);
		
		SmartLoot_Minimap:Show();
	else
		SmartLoot_Minimap:Hide();
	end
end

function SmartLoot.OnMinimapButtonClick()
	SmartLoot.ToggleOptions();
end

function SmartLoot.OnMinimapButtonEnter()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT");
    GameTooltip:SetText(SmartLoot.Res.MinmapTooltip1);
    GameTooltip:AddLine(SmartLoot.Res.MinmapTooltip2);
    GameTooltip:AddLine(SmartLoot.Res.MinmapTooltip3);
    GameTooltip:Show();
end