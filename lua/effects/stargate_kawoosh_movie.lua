/*
	Stargate Kawoosh for GarrysMod10
	Copyright (C) 2007-2008  Zup & aVoN

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

--################### Init @aVoN
function EFFECT:Init(data)
	local e = data:GetEntity();
	if(not (IsValid(e))) then return end;
	local mdl = e:GetModel();
	if(not (mdl and mdl ~= "" and mdl ~= "models/error.mdl")) then return end; -- Stops crashing ppl
	local pos = e:GetPos();
	self.Entity:SetPos(pos);  
	self.Entity:SetParent(e);
	
	local Universe = util.tobool(math.Round(data:GetRadius()));

	if StarGate.VisualsMisc("cl_kawoosh_material",true) then
		self.Smoke = ("particle/Smoke01_L"..(Universe and "_U" or ""))
	else
		self.Smoke = ("particle/Smoke01_G")
	end

	self.Data = {
		Time=2.4, -- Time to draw the vortex
		Size=4, -- Base or startsize
		GrowCoefficient=3, -- Size multiplier, how much bigger particles at the end of the kawoosh are compaired to the base
		Length=100, --Units long? 385.826 inches/second is gravity
		Density=200, -- Amount of particles
		Radius=55, --Radius of the kawooshes cyclinder... how "fat" the kawoosh is overall.. if that makes any sense
		Roll=0, --Roll, how much roll each particle has at start
		RollS=1.0, --Roll Speed
	}

	local emitter = ParticleEmitter(pos);
	local ang = e:GetAngles(); ang.p = ang.p + 90;
	local startsize = self.Data.Size*((self.Data.GrowCoefficient^1.5 - 1)*self.Data.Density/self.Data.Density + 1);
	local forward = e:GetForward()*(-1);
	local mul = 2/self.Data.Time; -- Multiplies the velocity and gravity of the particles if we change the speed
	--################### Add out particles
	for i=0,self.Data.Density do
		local ParticleDensity = i/self.Data.Density;
		local rad = math.rad(math.Rand(0,360));
		local radius = math.Rand(0,self.Data.Radius);
		local origin = radius*Vector(math.sin(rad),math.cos(rad),0);
		origin:Rotate(ang) --The angle dosn't seem right as it goes flat when the gate is faceing up and tilted to the side.
		--The GetForward bit in here makes the end of the kawoosh come to a cone like point, giveing it a more rounded look instead of a flat end
		local particle = emitter:Add(self.Smoke,origin + pos - i*forward*(radius-self.Data.Radius)/self.Data.Density);
		if(particle) then
			particle:SetDieTime(self.Data.Time-0.05);
			particle:SetStartAlpha(255);
			particle:SetEndAlpha(0);

			particle:SetStartSize(startsize);
			particle:SetEndSize(self.Data.Size*(ParticleDensity*(self.Data.GrowCoefficient^2.2 - 1) + 1));

			particle:SetRoll(math.Rand((-1*self.Data.Roll),self.Data.Roll)); --The starting rolled angle
			particle:SetRollDelta(math.Rand((-1*self.Data.RollS),self.Data.RollS)); --How fast it rolls
			particle:SetGravity(-1*forward*self.Data.Length*ParticleDensity*mul);
			particle:SetVelocity(forward*self.Data.Length*ParticleDensity);
			if (Universe) then
				particle:SetColor(209,218,234);
			else
				particle:SetColor(180,225,255);
			end
			--180,225,255
			--200,235,255 to light
		end
	end
	--emitter:Finish();
	-- Fixes drawing issues
	local offset = Vector(1,1,1)*512;
	self.Entity:SetRenderBounds(-1*offset,offset);
end

function EFFECT:Think() return false end; -- Make it die instantly
function EFFECT:Render() end
