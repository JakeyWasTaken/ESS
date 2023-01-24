local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PATH = require(ReplicatedStorage:WaitForChild("PATH"))
local Packages = PATH.Packages
local Modules = PATH["Shared.Modules"]

local Promise = require(Packages:WaitForChild("Promise"))
local DeepCopy = require(Modules:WaitForChild("DeepCopy"))
local Logger = require(Modules:WaitForChild("Logger"))

local profilebegin, profileend = debug.profilebegin, debug.profileend

local Component = {}
Component.__index = Component
Component.__type = "Component"

--[=[
    Creates new component

    @returns Component : table
]=]
function Component.new(PureComponent)
	local s, e = pcall(function()
		if not PureComponent then
			error("Expected PureComponent got nil")
		end

		if not PureComponent._RawState then
			error("Expected _RawState in pure component")
		end

		if not PureComponent._InheritedStates then
			error("Expected _RawState in pure component")
		end
	end)

	if not s then
		warn(e)

		return
	end

	local self = setmetatable({}, Component)

	self._RawState = PureComponent._RawState
	self._InheritedStates = PureComponent._InheritedStates

	return self
end

function Component:_setstate(key, value)
	if self._RawState[key] and self._InheritedStates[key] then
		return "Both raw and inherited states have a key of the name: " .. key -- We do this so we can work with promises
	end

	if self._RawState[key] then
		self._RawState[key] = value

		return
	elseif self._InheritedStates[key] then
		self._InheritedStates[key] = value

		return
	end

	self._RawState[key] = value -- This is incase we are adding a state value that doesnt already exist
end

--[=[
Sets raw state to given table

@params Table : table
@returns Promise
]=]
function Component:SetRawState(Table: table)
	local DebugName = Logger.GetDebugName("SetRawState", getfenv())
	profilebegin(DebugName)
	return Promise.new(function(resolve, reject)
		local s, e = pcall(function()
			if not Table then
				error("Expected table got nil")
				return
			end

			if type(Table) ~= "table" then
				error(string.format("Expected Table of type table got %s", type(Table)))
				return
			end
		end)

		if not s then
			reject(e)
			profileend()
			return
		end

		self._RawState = Table

		profileend()
		resolve(true)
	end)
end

--[=[
Sets full state to given table

@params Table : table
@returns Promise
]=]
function Component:SetState(Table: table)
	local DebugName = Logger.GetDebugName("SetState", getfenv())
	profilebegin(DebugName)
	return Promise.new(function(resolve, reject)
		local s, e = pcall(function()
			if not Table then
				error("Expected table got nil")
				return
			end

			if type(Table) ~= "table" then
				error(string.format("Expected Table of type table got %s", type(Table)))
				return
			end
		end)

		if not s then
			reject(e)
			profileend()
			return
		end

		for k, v in Table do
			local result = self:_setstate(k, v)

			if result then
				reject(result)
				profileend()
				return
			end
		end

		profileend()
		resolve(true)
	end)
end

--[=[
Reconciles raw state with given table

@params Table
@returns promise
]=]
function Component:ReconcileRawState(Table: table)
	local DebugName = Logger.GetDebugName("ReconcileRawState", getfenv())
	profilebegin(DebugName)
	return Promise.new(function(resolve, reject)
		local s, e = pcall(function()
			if not Table then
				error("Expected Table got nil")
				return
			end
		end)

		if not s then
			reject(e)
			profileend()
			return
		end

		-- local OldRaw, OldInherited = deepCopy(self._RawState), deepCopy(self._InheritedStates)
		local NewRaw = DeepCopy(self._RawState)

		for K, V in Table do
			if NewRaw[K] then
				NewRaw[K] = V
				continue
			end

			NewRaw[K] = V -- This is incase we are trying to add a key that doesnt already exist
		end

		self._RawState = NewRaw

		profileend()
		resolve(true)
	end)
end

--[=[
Reconciles full state with given table

@params Table
@returns promise
]=]
function Component:ReconcileState(Table: table)
	local DebugName = Logger.GetDebugName("ReconcileState", getfenv())
	profilebegin(DebugName)

	return Promise.new(function(resolve, reject)
		local s, e = pcall(function()
			if not Table then
				reject("Expected Table got nil")
				return
			end
		end)

		if not s then
			reject(e)
			profileend()
			return
		end

		-- local OldRaw, OldInherited = deepCopy(self._RawState), deepCopy(self._InheritedStates)
		local NewRaw, NewInherited = DeepCopy(self._RawState), DeepCopy(self._InheritedStates)

		for K, V in Table do
			if NewRaw[K] and NewInherited[K] then
				reject("Key of name: " .. K .. " exists in raw and inherited")
				continue
			end

			if NewRaw[K] then
				NewRaw[K] = V
				continue
			elseif NewInherited[K] then
				NewInherited[K] = V
				continue
			end

			NewRaw[K] = V -- This is incase we are trying to add a key that doesnt already exist
		end

		self._RawState = NewRaw
		self._InheritedStates = NewInherited

		resolve(true)
		profileend()
	end)
end

--[=[
Returns a normal table with full state

@returns table
]=]
function Component:GetState(): table
	local DebugName = Logger.GetDebugName("GetState", getfenv())
	profilebegin(DebugName)
	local FullState = DeepCopy(self._RawState)

	for K, V in self._InheritedStates do
		if FullState[K] then
			local Message = string.format("State object of key: %s already exists", K)
			local Traceback = debug.traceback(2)

			warn(Message, Traceback)
			profileend()
			return
		end

		FullState[K] = V
	end

	profileend()
	return FullState
end

--[=[
Returns the raw state of the component without any inheritence
]=]
function Component:GetRawState()
	return self._RawState
end

--[=[
Inherits other components and their full state

@returns Promise
]=]
function Component:Inherit(...)
	local DebugName = Logger.GetDebugName("Inherit", getfenv())
	profilebegin(DebugName)
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
				profileend()
				return
			end

			local Result = InsertComponent(_Component, reject)

			if not Result then
				profileend()
				return
			end
		end

		profileend()
		resolve(true)
	end)
end

return Component
