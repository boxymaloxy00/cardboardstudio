local Http = game:GetService("HttpService")
local ReflectionService = game:GetService("ReflectionService")

local partholdingtable = {}
local otherholdingtable = {}
local propertyclasstable = {}
local PublishPartIgnoreService = false
local outputuniverseid = "0"
local outputplaceid = "0"
local apikey = "0"
local url = "https://boxymaloxyhandler.pythonanywhere.com"
-- cache properties
local function trytogetpropertyNames(classname)
    if not propertyclasstable[classname] then
        -- ohio reflectionservice
        local success, props = pcall(function() 
            return ReflectionService:GetPropertiesOfClass(classname) 
        end)
        
        if not success or not props then 
            return {} 
        end
        
        local names = {}
        for _, p in ipairs(props) do
            -- we skip properties that are marked as 'hidden' or 'deprecated' to keep the XML clean
            if not p.Display.DeprecationMessage then
                table.insert(names, p.Name)
            end
        end
        propertyclasstable[classname] = names
    end
    return propertyclasstable[classname]
end

-- grab instance data
local function getObjectData(instance)
    local data = {
        ClassName = instance.ClassName,
        Name = instance.Name,
        Properties = {}
    }
    
    local propNames = trytogetpropertyNames(instance.ClassName)
    for _, name in ipairs(propNames) do
        
        -- pcall handles properties that might be restricted or throw errors
        pcall(function()
            local val = instance[name]
            if val ~= nil then
                data.Properties[name] = tostring(val) 
            end
        end)
    end
    return data
end

local function getServicefromInstance(instance)
    local current = instance
    while current.Parent and current.Parent ~= game do
        current = current.Parent
    end
    return current.Name
end

local module = {}

function module.GatherIntoHolding(parent, deleteprevious)
    if deleteprevious then 
        partholdingtable = {} 
        otherholdingtable = {} 
    end
    
    for _, instance in ipairs(parent:GetChildren()) do
        local servicename = getServicefromInstance(instance)
        local partbasedmode = (servicename == "Workspace") 
        or (servicename == "StarterPlayer")
        or (servicename == "ReplicatedStorage")
        or (servicename == "ServerStorage")
        or PublishPartIgnoreService

        if instance:IsA("BasePart") then
            if not partbasedmode then
                print("Part caught in weird service. For Optimization, Part will NOT save to published game. Turn on PublishPartIgnoreService in Publisher Settings to grant permission.")
            continue end
            if partbasedmode then
                table.insert(partholdingtable, getObjectData(instance))
            end
        else
            table.insert(otherholdingtable, getObjectData(instance))
        end
        
        -- get the children of the children
        module.GatherIntoHolding(instance, false)
    end
end

function module.ChangeOutputInfo(requesttype, id)
    if requesttype == "place" then
        outputplaceid = tostring(id)
    elseif requesttype == "universe" then
        outputuniverseid = tostring(id)
    elseif requesttype == "apikey" then
        apikey = tostring(id) or id
    elseif requesttype == "url" then
     url = tostring(id) or id 
end

function module.Serialize()
    return Http:JSONEncode({
        APIKey = apikey, -- api key
        UniverseID = outputuniverseid, -- universeid
        PlaceID = outputplaceid, -- placeid
        Parts = partholdingtable, -- basepart holding table
        Others = otherholdingtable -- other holding table
    })
end

function module.PostToServer()
    -- the url
    local url = url or "https://boxymaloxyhandler.pythonanywhere.com" -- default is fallback
    
    local success, response = pcall(function()
        return Http:PostAsync(url, module.Serialize())
    end)
    
    if success then
        print("Publish request sent successfully!")
        print("Server Response:", response)
    else
        warn("Publish request failed:", response)
    end
    
    return success, response
end

return module
