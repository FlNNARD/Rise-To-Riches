-- Fin's Custom Data Save Manager
--
--
-- Created by ILoveAvocados002. 6/18/2025 - 11:31 AM

--[[

HOW TO USE:

---== WARNINGS FOR "DefaultTemplate" Values ==---
	! Do not create numeric tables with gaps - attempting to store such tables will result in an error.
		Example: 
		
		[ 2 ] = {Coins = 1000, Gems = 25}
		
	! Do not create mixed tables (some values indexed by number and others by a string key)
		- only numerically indexed  data will be stored.
	! Do not enter unserialized values (i.e, Humanoids, Players, Parts)


---== FUNCTION USES ==---
	DataManager.New()
		Creates new Data with the passed arguments:
			Player - self explanatory
			DataStore - the Datastore in which the values will be saved at
			DefaultTemplate - the default template used for new players who does not have data
				Example:
				
				{
					UserId = 469211672,
					Name = Bob,
					Coins = 15000,
				}
			Properties - optional properties for the DataStore
		
	DataManager.Load()
		Loads in the data of the desired player from a desired DataStore

	DataManager.Load()
		Saves the data of the desired player inside a desired DataStore
		
		
---== HOW TO ADD NEW BUSINESSES ==---

	[OfficeName] = {
		OfficeName = "Whatever",
		Industry = "Manufacturing",
		Level = 6712,
		
		Revenue = IndustryAverage * Level,
		Expenses = IndustryAverage * Level * OtherFactors,
		
		FLOORS = {
			[1] = {
			
				WorkStations = {
					[1] = {
						Purchased = true,
						AssignedToEmployee = 9045027592582,
						Level = 1,
						Bonuses = {
							Income = 2%
						}
					}
					
					[2] = {
						Purchased = false,
						AssignedToEmployee = UniqueID,
						Level = 2,
						Bonuses = {
							Income = 5%
						}
					}
				}
				
				
				Decorations = {
				
					["Plant1"] = {
						Purchased = false
						Bonuses = {
							EmployeeMorale = 5%
						}
					}
				}
			}
		}
	}

]]

local FinsID = 1--4802485728


export type DataManager = {
	New: <KeysTable>(Player: Player, DesiredDataStoreName: string, DefaultTemplate: KeysTable) -> DataManager,
	Load: (self: DataManager) -> (),
	Save: (self: DataManager) -> (),
}

type Leaderstats = {
	Rank: StringValue,
	Cash: IntValue,
	Networth: IntValue
}

type Data = {
	Rank: string,
	Cash: number,
	Gems: number,
	Networth: number,
	
	TotalIncome: number,
	TotalExpenses: number,
	GemIncome: number
}



-- Services
local ServerScriptService = game:GetService('ServerScriptService')
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService('ServerStorage')
local DataStoreService = game:GetService("DataStoreService")

local TweenService = game:GetService('TweenService')
local HttpService = game:GetService("HttpService")
local PlayerService = game:GetService("Players")
local Teams = game:GetService('Teams')


-- Folders
local Modules = ReplicatedStorage.Modules
local ServerModule = ServerScriptService.ServerModules

local Templates = ReplicatedStorage.Templates
local Remotes = ReplicatedStorage.Remotes
local BuildingFloors = ServerStorage.BuildingFloors


-- Modules
local SharedMods = Modules.Shared

local NumberModule = require(SharedMods.Utilities.NumberUtils)
local WalletService = require(ServerModule.WalletService)
local PlayerData = require(ServerModule.PlayerData)

local BasicDataTemplate = require(script.BasicDataTemplate)
local PlayerBusinessHandler = require(script.PlayerBusinessHandler)


-- Templates
local GainedCash = Templates.GUI.GainedCash
local GainedGem = Templates.GUI.GainedGem


-- Remotes
local StatsGuiUpdate = Remotes.StatsGuiUpdate


-- Constants
local PLAYER_INCOME_INTERVALS = 0.25
local AUTOSAVE_INTERVAL = 300 - PLAYER_INCOME_INTERVALS


-- Variables
local Autosave_InUse = false

-- Utilities
local Message = function(msg: string)
	warn(`[DATA MANAGER]: {msg}`)
end


-- Module Table
local DataManager = {} :: DataManager
DataManager.__index = DataManager



-- Static table
local DataStores = {
	PlayerData = DataStoreService:GetDataStore("PlayerData"),
}

local StatsTable = {
	"ExecutivePower",
	"Reputation",
	"Corruption",
	"InvestorTrust",
}



-- Constructor
function DataManager.New<KeysTable>(
	Player: Player,
	DesiredDataStoreName: string,
	DefaultTemplate: KeysTable
): DataManager
	
	local self = setmetatable({}, DataManager)

	self.Username = Player.Name
	self.UserId = Player.UserId
	self.DataStore = DataStores[DesiredDataStoreName]
	self.Businesses = {}

	for Key, Value in pairs(DefaultTemplate) do
		self[Key] = Value
	end

	PlayerData[self.UserId] = self
	CreateLeaderstats(Player, self)
	Message(`Created new data for {self.Username}`)
	return self
end


function DataManager:Load(): ()
	local Success, Results = pcall(function()
		return self.DataStore:GetAsync(self.UserId)
	end)

	if Success and Results then
		for Key, Value in pairs(Results) do
			self[Key] = Value
		end
		
		if Results.LastLogin ~= nil then
			local Income = (self.TotalRevenue - self.TotalExpenses)
			
			if Income <= 0 then return end
			
			local CurrentTime = os.time()
			local TimeElapsed = CurrentTime - Results.LastLogin
			local IncomeTick = math.floor(TimeElapsed / (PLAYER_INCOME_INTERVALS * 5))

			self.Cash += (Income * IncomeTick)
			
			Message(`{self.Username} has been gone for {TimeElapsed} seconds. they have gathered: ${NumberModule.Commanize(self.TotalRevenue * IncomeTick)}`)
		end
					
		Message(`Loaded data for {self.Username}`)
	else
		Message(`No data found or failed to load for {self.Username}`)
	end
end


function DataManager:Save(): ()
	local DataToSave = {}
	for Key, Value in pairs(self) do
		if typeof(Value) ~= "function" and Key ~= "DataStore" then
			DataToSave[Key] = Value
		end
	end

	local Success, Err = pcall(function()
		self.DataStore:UpdateAsync(self.UserId, function()
			return DataToSave
		end)
	end)

	if Success then
		Message(`Successfully saved data for {self.Username}`)
	else
		Message(`Save failed for {self.Username}: {Err}`)
	end
end






-- Player events
local function CreateTeam(Player: Player)
	local NewTeam = Instance.new("Team")
	NewTeam.Name = `{Player.DisplayName}'s Business`
	
	local RandomRed = math.random(120, 255)
	local RandomGreen = math.random(120, 255)
	local RandomBlue = math.random(120, 255)
	
	NewTeam.TeamColor = BrickColor.random()
	NewTeam.Parent = Teams
	
	Player.Team = NewTeam
end

local function OnPlayerAdded(Player: Player)
	
	local UserName = Player.Name
	local UserId = Player.UserId
	
	local DataTemplate = table.clone(BasicDataTemplate)
	
	DataTemplate.UserId = UserId
	DataTemplate.Username = UserName
	DataTemplate.BusinessGroup = `{Player.DisplayName}'s Business`
	
	local Data = DataManager.New(Player, "PlayerData", DataTemplate)
	Data:Load()
	CreateTeam(Player)
	
	
	if UserId ~= FinsID then
		local Character = Player.Character or Player.CharacterAdded:Wait()
		
		for _, V in pairs(Character:GetDescendants()) do
			if V.Name == "FinCompAccessory" then
				V:Destroy()
			end
		end
	end
	
	task.defer(function()
		task.wait(3)
		
		if not Player then return end
		PlayerBusinessHandler.AssignEmptyOffice(Player)


		require(ServerModule.WalletService).EditWallet(game.Players.ILoveAvocados002, 99999999)
	end)
end



local function OnPlayerRemoving(player: Player)
	local data = PlayerData[player.UserId]
	if data then
		data.LastLogin = os.time()
		data:Save()
	end
end


local function OnGameCrash()
	for _, player in ipairs(PlayerService:GetPlayers()) do
		local data = PlayerData[player.UserId]
		if data then
			task.defer(function()
				data:Save()
			end)
		end
	end
end


function CreateLeaderstats(Player: Player, Data:Data)
	
	if Player:FindFirstChild('Leaderstats') then return end
	
	local Leaderstats = Instance.new('Folder')
	local Rank = Instance.new('StringValue')
	local Cash = Instance.new('StringValue')
	local Networth = Instance.new('StringValue')
	
	Leaderstats.Name = "leaderstats"
	Rank.Name = "Rank"
	Cash.Name = "Cash"
	Networth.Name = "Networth"
	
	Rank.Value = tostring(Data.Rank)
	Cash.Value = tostring(Data.Cash)
	Networth.Value = tostring(Data.Networth)
	
	Leaderstats.Parent = Player
	Rank.Parent = Leaderstats
	Cash.Parent = Leaderstats
	Networth.Parent = Leaderstats
end


local function DataIncrement_AutoSave(Player: Player)
	local Data = PlayerData[Player.UserId]
	
	if Data and Player then
		
		local Income = (Data.TotalRevenue - Data.TotalExpenses)
		local GemIncome = Data.GemIncome
		
		WalletService.EditWallet(Player, Income, GemIncome)
		
		
		-- Auto Save
		task.defer(function()
			
			if Autosave_InUse == true then return end
			
			Autosave_InUse = true
			task.wait(AUTOSAVE_INTERVAL + 5)
			
			Autosave_InUse = false
			Data:Save()
			warn(`Autosave complete for {Data.Username}`)
		end)
	end
end


-- Connect events
PlayerService.PlayerAdded:Connect(OnPlayerAdded)
PlayerService.PlayerRemoving:Connect(OnPlayerRemoving)
game:BindToClose(OnGameCrash)


-- Auto save & Data Increment
task.defer(function()
	while true do
		task.wait(PLAYER_INCOME_INTERVALS)
		
		for _, Player:Player in pairs(PlayerService:GetPlayers()) do
			task.defer(function()
				DataIncrement_AutoSave(Player)
			end)
		end
	end
end)

return DataManager
