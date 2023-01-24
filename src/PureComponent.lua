local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PATH = require(ReplicatedStorage:WaitForChild("PATH"))
local Packages = PATH.Packages

local Promise = require(Packages:WaitForChild("Promise"))

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

local Component = {}
Component.__index = Component
Component.__type = "PureComponent"

--[=[
    Creates new component

    @returns Component : table
]=]
function Component.new()
	local self = setmetatable({}, Component)

	self._RawState = {}
	self._InheritedStates = {}

	return self
end

--[=[
Sets raw state to given table

@params Table : table
@returns Promise
]=]
function Component:SetState(Table: table)
	return Promise.new(function(resolve, reject)
		local s, e = pcall(function()
			if not Table then
				error("Expected Table got nil")
			end
		end)

		if not s then
			reject(e)
			return
		end

		self._RawState = Table

		resolve(true)
	end)
end

--[=[
Returns a normal table with full state

@returns table
]=]
function Component:GetState(): table
	local FullState = deepCopy(self._RawState)

	for K, V in self._InheritedStates do
		if FullState[K] then
			local Message = string.format("State object of key: %s already exists", K)
			local Traceback = debug.traceback(2)

			warn(Message, Traceback)

			return
		end

		FullState[K] = V
	end

	return FullState
end

--[=[
Inherits other components and their full state

@returns Promise
]=]
function Component:Inherit(...)
	local PackedInputs = table.pack(...)
	PackedInputs.n = nil

	local function InsertComponent(InheritFrom, reject)
		local s, e = pcall(function()
			if not InheritFrom then
				reject("Expected Component to inherit got nil")

				return false
			end

			if InheritFrom.__type ~= "PureComponent" then
				reject("Expected Component of type PureComponent")

				return false
			end
		end)

		if not s then
			reject(e)

			return false
		end

		-- Inherit here

		local ComponentState = InheritFrom:GetState()

		for K, V in ComponentState do
			if self._InheritedStates[K] or self._RawState[K] then
				reject("Key: " .. K .. " already exists in inherited state or raw state")
				return false
			end

			self._InheritedStates[K] = V
		end

		return true
	end

	return Promise.new(function(resolve, reject)
		for _, _Component in PackedInputs do -- We do this so we can pass in multiple components to inherit, (Comp1, Comp2, Comp3)
			if _Component == self then
				reject("Cannot inherit self")
				return
			end

			local Result = InsertComponent(_Component, reject)

			if not Result then
				return
			end
		end

		resolve(true)
	end)
end

return Component
