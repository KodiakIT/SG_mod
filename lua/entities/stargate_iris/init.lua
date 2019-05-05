/*
    Stargate Iris/Shield for GarrysMod10
    Copyright (C) 2007  aVoN

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

-- HEADER
if (StarGate==nil or StarGate.CheckModule==nil or not StarGate.CheckModule("base")) then return end
AddCSLuaFile("cl_init.lua");
AddCSLuaFile("shared.lua");
include("shared.lua");

ENT.NotTeleportable = true;
ENT.NoDissolve = true;
ENT.IsIris = true; -- We are an iris, lol
ENT.CDSIgnore = true; -- CDS Immunity
function ENT:gcbt_breakactions() end; ENT.hasdamagecase = true; -- GCombat invulnarability!

-- SENT CODE
-- Init @aVoN
function ENT:Initialize()
    self.NextAction = 0;
    if(not self:RegisterModules()) then self.Entity:Remove() return end; -- We are not valid!
    self.Entity:PhysicsInit(SOLID_VPHYSICS);
    self.Entity:SetMoveType(MOVETYPE_VPHYSICS);
    self.Entity:SetTrigger(false);
    self.Entity:SetCollisionGroup(COLLISION_GROUP_WORLD);
    self.Entity:SetSolid(SOLID_NONE);
    self.Entity:DrawShadow(false);
    self.Entity:SetNoDraw(true);
    if (self:GetModel()=="models/zup/stargate/sga_shield.mdl") then
        self:SetRenderMode(RENDERMODE_GLOW)
    end
    self:CreateWireInputs("Activate","Toggle");
    self:CreateWireOutputs("Activated");
    self.LastMoveable = true;
    -- Always spawn frozen, except we are welded to something (prevents it from falling into the map's ground)
    self.Phys = self.Entity:GetPhysicsObject();
    self.Phys:SetMass(5000); -- Avoids playing running against it making it snap back so they die
    if(#StarGate.GetConstrainedEnts(self.Entity,1) == 0) then
        self.Phys:EnableMotion(false);
    end
    self.GateLink = NULL;
    timer.Create("StarGateIrisCheck"..self:EntIndex(),10.0,0,function()
        local remove = true;
        if (IsValid(self) and IsValid(self.GateLink) and constraint.HasConstraints(self)) then
            local entities = StarGate.GetConstrainedEnts(self,2);
            if(entities) then
                for k,v in pairs(entities) do
                    if(v.IsStargate and v==self.GateLink) then
                        remove = false;
                    end
                end
            end
        else
            remove = true;
        end
        if (remove) then self:Remove(); end
    end);
    if (pewpew and pewpew.NeverEverList and not table.HasValue(pewpew.NeverEverList,self.Entity:GetClass())) then table.insert(pewpew.NeverEverList,self.Entity:GetClass()); end -- pewpew support
end

function ENT:DeriveOnSetColor(color)
    self.OrigColor = color
end

-- Registers specific models to animations @aVoN
function ENT:RegisterModules()
    -- Valid Model registered to an existing animation sequence?
    local mdl = (self.Entity:GetModel() or ""):gsub("[/\\]+","/"):lower();
    local f = function() end; -- Dummy, so the default tables are set and this script does not fail
    local default = {Open=f,Close=f,Hit=f,Remove=f,Init=f};
    for _,v in pairs(file.Find("entities/stargate_iris/modules/*.lua","LUA")) do
        if (v=="iris_infinity.lua" and not StarGate.CheckModule("extra")) then continue end
        ANIM = table.Copy(default);
        setmetatable(ANIM,{__index=self,__newindex=self});  -- ATTENTION: In your ANIM table, do not use a function which already exists in the Entity, or you will overwrite it! - This is for purpose!
        include("entities/stargate_iris/modules/"..v);
        if(ANIM.Model and ANIM.Model:lower() == mdl) then
            self.Action = ANIM;
            ANIM:Init(); -- Init!
            ANIM = nil;
            return true;
        end
    end
    ANIM = nil;
    return false;
end

function ENT:Think()
    -- have energy check for energy and eat it at same time, shorter code
    if(self.IsActivated) then
        if(self.HasRD and self.Entity:GetModel() == "models/zup/stargate/sga_shield.mdl") then
            local gate = self:FindGate();
            if IsValid(gate) and gate.IsStargate and not gate:HaveEnergy(true,true) then self:TrueActivate(true) end
        end
    end
    self.Entity:NextThink(CurTime()+0.5)
    return true
end

-- Finds a gate @aVoN
function ENT:FindGate()
    local gate;
    local dist = 150;
    local pos = self.Entity:GetPos();
    for _,v in pairs(ents.FindByClass("stargate_*")) do
        if(v.IsStargate and v:GetClass() ~= "stargate_supergate") then
            local sg_dist = (pos - v:GetPos()):Length();
            if(dist >= sg_dist) then
                dist = sg_dist;
                gate = v;
            end
        end
    end
    return gate;
end

-- OnRemove Handler @aVoN
function ENT:OnRemove()
    if(self.Action) then self.Action:Remove() end;
    timer.Remove("StarGateIrisCheck"..self:EntIndex());
    timer.Remove("StarGateIrisProtCheck"..self:EntIndex());
end

-- Set this Busy (in that time, a player cant change the status) @aVoN
function ENT:SetBusy(delay)
    self.NextAction = CurTime() + (delay or 0);
end

-- Iris got hit by something - R.I.P. @aVoN
function ENT:HitIris(e,pos,velo)
    if(self.IsActivated) then
        self.Action:Hit(e,pos,velo);
    end
end

function ENT:IsBusy()
    if(self.NextAction <= CurTime()) then
        return false;
    end
    return true;
end

-- Activate @aVoN
function ENT:Toggle(ignore_energy)
    local gate = self:FindGate();
    local reactivate = false;
    if (IsValid(gate) and gate.NoxDialingType and not gate.NoxIrisReactivated) then gate.NoxIrisReactivated = true; reactivate = true; end
    if(self.NextAction <= CurTime() or reactivate) then
        local deactivate = false
        if(self.HasRD and ignore_energy and self.Entity:GetModel() == "models/zup/stargate/sga_shield.mdl") then
            if IsValid(gate) and gate.IsStargate and not gate:HaveEnergy(true,true) then deactivate = true end
        end
        if(self.IsActivated or deactivate) then
            self.Entity:SetTrigger(false);
            self.Entity:SetCollisionGroup(COLLISION_GROUP_WORLD);
            self.Entity:SetSolid(SOLID_NONE);
            self.LastMoveable = self.Phys:IsMoveable();
            if(#StarGate.GetConstrainedEnts(self.Entity,1) == 0) then
                self.Phys:EnableMotion(false); -- Don't enable motion if it's closed or it may fall into the ground
            end
            self.Action:Open(deactivate);
            self.IsActivated = false
            self:SetWire("Activated",false);
            self:SetNWBool("Activated",false);
        else
            if (not ignore_energy and IsValid(self.GateLink) and self.GateLink.GateSpawnerSpawned and not self:IsComputer()) then return end
            if(self.HasRD and self.Entity:GetModel() == "models/zup/stargate/sga_shield.mdl") then
                local gate = self:FindGate();
                if IsValid(gate) and gate.IsStargate and not gate:HaveEnergy(true,true) then if (self.Action and self.Action.Sounds and self.Action.Sounds.Fail) then self.Entity:EmitSound(self.Action.Sounds.Fail,90,math.random(90,110)); end return end
            end
            self.Entity:SetCollisionGroup(COLLISION_GROUP_NONE);
            self.Entity:SetSolid(SOLID_VPHYSICS);
            --To kill any prop/player which got "stuck in iris/shield" - (Only works if SetTrigger is true, but SetTrigger also makes bullets hit the shield if disabled so we need to "unset" settrigger after a short period of time)
            self.AllowTouch = CurTime();
            self.Entity:SetTrigger(true);
            local e = self.Entity;
            timer.Simple(0.1,
                function()
                    if(IsValid(e)) then e:SetTrigger(false) end;
                end
            );
            self.Phys:EnableMotion(self.LastMoveable);
            self.Phys:Wake();
            self.Action:Close();
            self.IsActivated = true;
            self:SetWire("Activated",true);
            self:SetNWBool("Activated",true);
        end
    end
end

-- Activate @aVoN
function ENT:TrueActivate(deactivate,wire)
    if(self.NextAction <= CurTime()) then
        if(self.IsActivated and deactivate) then
            self.Entity:SetTrigger(false);
            self.Entity:SetCollisionGroup(COLLISION_GROUP_WORLD);
            self.Entity:SetSolid(SOLID_NONE);
            self.LastMoveable = self.Phys:IsMoveable();
            if(#StarGate.GetConstrainedEnts(self.Entity,1) == 0) then
                self.Phys:EnableMotion(false); -- Don't enable motion if it's closed or it may fall into the ground
            end
            self.Action:Open(not wire);
            self.IsActivated = false
            self:SetWire("Activated",false);
            self:SetNWBool("Activated",false);
        elseif (not self.IsActivated and not deactivate) then
            if (not ignore_energy and IsValid(self.GateLink) and self.GateLink.GateSpawnerSpawned and not self:IsComputer()) then
                if (IsValid(self.Owner)) then
                    --p:SendLua("GAMEMODE:AddNotify(SGLanguage.GetMessage(\"iris_protection\"), NOTIFY_GENERIC, 5); surface.PlaySound( \"buttons/button9.wav\" )");
                end
                return
            end
            if(self.HasRD and self.Entity:GetModel() == "models/zup/stargate/sga_shield.mdl") then
                local gate = self:FindGate();
                if IsValid(gate) and gate.IsStargate and not gate:HaveEnergy(true,true) then return end
            end
            self.Entity:SetCollisionGroup(COLLISION_GROUP_NONE);
            self.Entity:SetSolid(SOLID_VPHYSICS);
            --To kill any prop/player which got "stuck in iris/shield" - (Only works if SetTrigger is true, but SetTrigger also makes bullets hit the shield if disabled so we need to "unset" settrigger after a short period of time)
            self.AllowTouch = CurTime();
            self.Entity:SetTrigger(true);
            local e = self.Entity;
            timer.Simple(0.1,
                function()
                    if(IsValid(e)) then e:SetTrigger(false) end;
                end
            );
            self.Phys:EnableMotion(self.LastMoveable);
            self.Phys:Wake();
            self.Action:Close();
            self.IsActivated = true;
            self:SetWire("Activated",true);
            self:SetNWBool("Activated",true);
        end
    end
end

-- Touch @aVoN
function ENT:Touch(e)
    if(self.AllowTouch and self.AllowTouch + 0.1 > CurTime()) then
        if(e:IsPlayer() and not e:HasGodMode() or e:IsNPC()) then
            e:SetHealth(1);
            e:TakeDamage(10,self.Entity);
        end
    else
        self.AllowTouch = nil;
    end
end

function ENT:OnTakeDamage(  dmginfo )
    if (not IsValid(self.Entity) or self.Entity:GetModel() ~= "models/zup/stargate/sga_shield.mdl" or not self.IsActivated or dmginfo:GetAttacker():GetClass() == "point_hurt" or dmginfo:GetAttacker():GetClass() == "kawoosh_hurt") then return end
    self.Entity:EmitSound(self.Sounds.Hit,90,math.random(98,103));
end

-- Wire input @aVoN
function ENT:TriggerInput(k,v)
    if(
        k == "Activate" and
        (
            (not self.IsActivated and v >= 1) or
            (self.IsActivated and v == 0)
        )
    ) then
        self:Toggle();
    elseif (k == "Toggle") then
        self:Toggle();
    end
end

function ENT:PreEntityCopy()
    local dupeInfo = {};
    if (IsValid(self.GateLink)) then
        dupeInfo.Gate = self.GateLink:EntIndex();
    end
    duplicator.StoreEntityModifier(self, "Iris", dupeInfo);
    StarGate.WireRD.PreEntityCopy(self)
end

function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
    if (StarGate.NotSpawnable(Ent:GetClass(),ply)) then self.Entity:Remove(); return end
    if (Ent.EntityMods.Iris) then
        if (Ent.EntityMods.Iris.Gate) then
            self.GateLink = CreatedEntities[Ent.EntityMods.Iris.Gate] or NULL;
        end
    end
    StarGate.WireRD.PostEntityPaste(self,Player,Ent,CreatedEntities)
end

function ENT:IsComputer()
    local dist = 1000
    local pos = self:GetPos()
    local ret = false;
    for _,v in pairs(ents.FindByClass("iris_computer")) do
        if(v.LockedIris==self) then
            ret = true;
            break;
        elseif(v.LockedIris==v) then
            local ir_dist = (pos - v:GetPos()):Length()
            if(dist >= ir_dist) then
                ret = true;
                break;
            end
        end
    end
    return ret;
end

function ENT:IrisProtection()
    local ent = self.Entity;
    timer.Create("StargateIrisProtCheck"..self:EntIndex(),15.0,0,function()
        if (IsValid(ent)) then
            if (ent.IsActivated) then
                local dist = 1000
                local pos = ent:GetPos()
                local open = true;
                if (ent:IsComputer()) then open = false end
                if (open) then
                    ent:Toggle();
                end
            end
        end
    end);
end