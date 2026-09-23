-- Generic selected-target reservation. No champion/controller dependencies.
return function(target,clock,grace)
    local previous,hiddenAt
    function target:GetSelectedTarget()
        local selected=self.Selected
        if not selected or selected.dead or (selected.health or 0)<=0 or selected.valid==false then
            if selected then self.Selected=nil end
            previous=nil;hiddenAt=nil;return nil
        end
        if selected~=previous then previous=selected;hiddenAt=nil end
        if self.MenuCheckSelected and not self.MenuCheckSelected:Value() then hiddenAt=nil;return nil end
        if selected.visible~=false then hiddenAt=nil;return selected end
        local now=clock();hiddenAt=hiddenAt or now
        if self.MenuCheckSelectedOnly and self.MenuCheckSelectedOnly:Value() then return selected end
        if now-hiddenAt<math.max(0,grace()) then return selected end
        -- Keep the user's selection so reappearance restores its priority.
        return nil
    end
    local tick=target.OnTick
    function target:OnTick(...)
        self:GetSelectedTarget()
        return tick(self,...)
    end
    local single,multiple=target.GetTarget,target.GetTargets
    function target:GetTarget(...)
        local selected=self:GetSelectedTarget()
        if selected and selected.visible==false then return nil end
        return single(self,...)
    end
    function target:GetTargets(...)
        local selected=self:GetSelectedTarget()
        if selected and selected.visible==false then return {} end
        return multiple(self,...)
    end
end
