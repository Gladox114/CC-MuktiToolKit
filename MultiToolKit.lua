-- create the module
local vector = {}
vector.__index = vector

-- makes a new vector
local function new(x,y,z)
    return setmetatable({x=x or 0, y=y or 0, z=z or 0}, vector)
end  

-- check if an object is a vector
local function isvector(t)
    return getmetatable(t) == vector
end

-- meta function to add vectors together
-- ex: (vector(5,6) + vector(6,5)) is the same as vector(11,11)
function vector.__add(a,b)
    assert(isvector(a) and isvector(b), "add: wrong argument types: (expected <vector> and <vector>)")
    return new(a.x+b.x, a.y+b.y, a.z+b.z)
end

-- meta function to subtract vectors
function vector.__sub(a,b)
    assert(isvector(a) and isvector(b), "sub: wrong argument types: (expected <vector> and <vector>)")
    return new(a.x-b.x, a.y-b.y, a.z-b.z)
end

-- meta function to change how vectors appear as string
-- ex: print(vector(2,8)) - this prints '(2,8)'
function vector:__tostring()
    return "("..self.x..", "..self.y..", "..self.z..")"
end

-- get the distance between two vectors
function vector.dist(a,b)
    assert(isvector(a) and isvector(b), "dist: wrong argument types (expected <vector> and <vector>)")
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end

-- returns a copy of a vector
function vector:clone()
    return new(self.x, self.y, self.z)
end


-- variables
local fuel_critical = 80
local fuel_normal = 400
local fuel_chest = new(0,0,0)
local fuel_chest_facing = 1
local dispose_chest = new(-1,0,0)
local dispose_chest_facing = 1
local coordinates = new(0,0,0)
local direction = 0

local strip_axis = 1 -- main path axis x,y,z for 1,2,3 and -1,-2,-3 for other direction
local strip_direction = 0
local strip_leftLimit = 11
local strip_rightLimit = 11
local strip_maxStrips = 100
local strip_current = 1
local strip_stripDistance = 2

local torch_distance = 7
local torch_startDistance = 0

local excavate_direction = 0
local excavate_forward = 2
local excavate_left = 0
local excavate_right = 1
local excavate_up = 2
local excavate_down = 3
local excavate_current = 1
local excavate_currentLayer = 0

local startPosition = NULL
local savedLocation = NULL
local savedDirection = NULL
local locationStack = {}

-- refuels if its not full. Scans inventory for coal
function refuel() 
    -- is it fully full?
    if (turtle.getFuelLevel() < turtle.getFuelLimit()-80) then
        -- scan inventory for coal
        for i=1,16 do
            -- get current item in inventory
            local data = turtle.getItemDetail(i)
            -- if its an item
            if (data ~= NULL) then
                -- if its coal
                if (data["name"] == "minecraft:charcoal" or data["name"] == "minecraft:coal") then
                    -- select this slot
                    turtle.select(i)
                    -- refuel till no coal is there or its full
                    while ( (turtle.getFuelLevel() < turtle.getFuelLimit()-80) and data["count"] > 0) do
                        turtle.refuel(1)
                        -- update the sucked coal
                        data["count"] = turtle.getItemCount()
                    end
                    -- if its full, stop scanning
                    if (turtle.getFuelLevel() > turtle.getFuelLimit()-80) then
                        turtle.select(1)
                        return true
                    end
                end
            end
        end
        turtle.select(1)
        return false
    end
    return true
end


refuelHome = function () end

emptyHome = function () end

function checkFuel()
    -- if limit is reached
    if (turtle.getFuelLevel() < fuel_critical) then
        -- refuel
        refuel()
        -- if couldn't refuel above limit then return home and refuel coal there
        if (turtle.getFuelLevel() < fuel_critical) then
            refuelHome()
        end
    end
end

-- checks if there is a single empty slot. true if yes
function emptySpace()
    for i=16,1,-1 do
        local count = turtle.getItemCount(i)
        if (count < 1) then
            return true
        end
    end
    return false
end

function checkInventory()
    if (emptySpace() == false) then
        emptyHome()
    end
end

function checkForItem(itemName)
    for i=1,16 do
        local data = turtle.getItemDetail(i)
        if (data ~= NULL and data["name"] == itemName) then
            return i
        end
    end
    return false
end

function placeTorchAbove()
    -- get torch slot
    local itemSlot = checkForItem("minecraft:torch")
    if (itemSlot) then
        print("itemSlot: "..itemSlot)
        turtle.select(itemSlot)
        local succeed, info = turtle.placeUp()
        turtle.select(1)
        if (succeed == false) then
            print("failed because: "..info)
            return false
        else
            return true
        end
    else
        return false
    end
end

local lastTorch = torch_startDistance
function torch()
    if (lastTorch < 1) then
        if (placeTorchAbove()) then
            lastTorch = torch_distance
        end
    else
        lastTorch = lastTorch - 1
        print("lastTorch: "..lastTorch)
    end
end

directionWalk = {
    -- 0 for north (+x)
    [0] = function(i) return new(i,0,0) end,
    -- 1 for east (+z)
    [1] = function(i) return new(0,0,i) end,
    -- 2 for south (-x)
    [2] = function(i) return new(-i,0,0) end,
    -- 3 for west (-z)
    [3] = function(i) return new(0,0,-i) end,
    -- 4 for up (+y)
    [4] = function(i) return new(0,i,0) end,
    -- 5 for down (-y)
    [5] = function(i) return new(0,-i,0) end
}

function virtWalk()
    coordinates = coordinates + directionWalk[direction](1)
end

function virtBackward()
    coordinates = coordinates - directionWalk[direction](1)
end


function turnleft()
    turtle.turnLeft()
    direction = (direction-1)%4
end

function turnright()
    turtle.turnRight()
    direction = (direction+1)%4
end

-- turns the turtle to exactly that direction
function turnTo(x)
    local turns = x-direction
    if (turns < 0) then
        for i=1,-turns do
            turnleft()
        end
        return     
    elseif (turns > 0) then
        for i=1,turns do    
            turnright()
        end
        return
    end
end

-- walks forward
-- updates coordinates and cheks fuel
-- digs in front if something blocks it
function walk()
    while (not turtle.forward()) do
        turtle.dig()
    end
    virtWalk()
    checkFuel()
end

function walkNoChecks()
    while (not turtle.forward()) do
        turtle.dig()
    end
    virtWalk()
end

-- digs and walks
function digWalk()
    turtle.dig()
    checkInventory()
    walk()
end

-- digs up and forward and walks
function digTunnelWalk()
    turtle.dig()
    checkInventory()
    walk()
    local _,data = turtle.inspectUp()
    if (data ~= NULL and data["name"] ~= "minecraft:wall_torch") then
        turtle.digUp()
    end
end


function walkX(x,dirPlus,dirNegative,func)
    if (x < 0) then
        -- turn to negative axis
        turnTo(dirNegative)
        for i=1,-x do
            func() -- walk function
        end
    elseif (x > 0) then
        -- turn to positive axis
        turnTo(dirPlus)
        for i=1,x do
            func() -- walk function
        end
    end
end

function walkTo(vecPos, func)
    func = func or walk
    local pos = vecPos-coordinates
    -- if the turtle is facing north or south, x or -x
    if (direction%2 == 0) then
        print("x"..tostring(vecPos))
        walkX(pos.x,0,2,func)
        walkX(pos.z,1,3,func)
    else -- z or -z
        print("z"..tostring(vecPos))
        walkX(pos.z,1,3,func)
        walkX(pos.x,0,2,func)
    end
    if (pos.y < 0) then
        for i=1,-pos.y do
            while (not turtle.down()) do
                turtle.digDown()
            end
            coordinates = coordinates + directionWalk[5](1)
            checkFuel()
        end
    elseif (pos.y > 0) then
        for i=1,pos.y do
            while (not turtle.up()) do
                turtle.digUp()
            end
            coordinates = coordinates + directionWalk[4](1)
            checkFuel()
        end
    end
end

function backwards()
    torch()
    while (not turtle.back()) do
        turtle.turnLeft()
        turtle.turnLeft()
        turtle.dig()
        turtle.turnLeft()
        turtle.turnLeft()
    end
    virtBackward()
    checkFuel()
end

function walkBackwardsTo(vecPos)
    local pos = vecPos-coordinates
    lastTorch = torch_startDistance
    -- if the turtle is facing north or south, x or -x
    if (direction%2 == 0) then
        walkX(pos.x,2,0,backwards)
        walkX(pos.z,3,1,backwards)
    else -- z or -z
        walkX(pos.z,3,1,backwards)
        walkX(pos.x,2,0,backwards)
    end
end

function returnHome(func)
    savedLocation = coordinates:clone()
    savedDirection = direction
    for i=#locationStack,1,-1 do
        walkTo(locationStack[i],func)
    end
end

function returnWork() 
    for i=1,#locationStack do
        walkTo(locationStack[i])
    end
    walkTo(savedLocation)
    turnTo(savedDirection)
end

function refuelFromChest()
    print("RefuelFromChest")
    -- firstly get some coal
    while (not turtle.suck()) do
        print("No coal in the chest. Waiting 30 seconds")
        sleep(30)
    end
    -- then try to refuel till its full or enough
    local enough = false
    while (refuel() or enough) do
        -- if its above the normal limit then stop the loop
        if (turtle.getFuelLevel() > fuel_normal) then
            enough = true
        end
        -- suck to get more coal to refuel above normal
        if (not enough) then 
            while (not turtle.suck()) do
                print("No coal in the chest. Waiting 30 seconds")
                sleep(30)
            end
        end
    end
end

function emptyToChest() 
    print("EmptyToChest")
    local _, data = turtle.inspect()
    if (data["name"] == "minecraft:chest") then
        for i=1,16 do
            local data = turtle.getItemDetail(i)
            if (data ~= NULL and data["name"] ~= "minecraft:torch" and data["name"] ~= "minecraft:coal" and data["name"] ~= "minecraft:charcoal") then
                turtle.select(i)
                while (not turtle.drop()) do
                    print("Can't drop item. Waiting 10 seconds")
                    sleep(10)
                end
            end
        end
        turtle.select(1)
    else
        assert(false,"ASSERT: No chest in front")
    end
end

function printStack() 
    print("locationStack: from last to first")
    for i=#locationStack,1,-1 do
        print(locationStack[i])
    end
end

function fuel_updateCritialLevel()
    -- get the distance between start position and last strip position
    local pathDistance = (strip_stripDistance+1)*(strip_current+2)
    -- get the distance between start position to dispose chest to fuel chest
    local chestsVec = fuel_chest-dispose_chest
    local chestsDistance = math.abs(dispose_chest.x)+math.abs(dispose_chest.z) + math.abs(chestsVec.x)+math.abs(chestsVec.z)
    fuel_critical = pathDistance*2 + chestsDistance*2 + math.max(strip_leftLimit,strip_rightLimit)
end

refuelHome = function()
    print("refuelHome")
    returnHome(walkNoChecks)
    walkTo(dispose_chest,walkNoChecks)
    turnTo(dispose_chest_facing)
    emptyToChest()
    walkTo(fuel_chest,walkNoChecks)
    turnTo(fuel_chest_facing)
    refuelFromChest()
    returnWork() 
end

emptyHome = function() 
    printStack()
    print("emptyHome")
    returnHome()
    walkTo(dispose_chest)
    turnTo(dispose_chest_facing)
    emptyToChest()
    fuel_updateCritialLevel()
    -- if limit is reached
    if (turtle.getFuelLevel() < fuel_critical) then
        -- refuel
        refuel()
        -- if couldn't refuel above limit then return home and refuel coal there
        if (turtle.getFuelLevel() < fuel_critical) then
            walkTo(fuel_chest,walkNoChecks)
            turnTo(fuel_chest_facing)
            refuelFromChest()
        end
    end
    returnWork() 
end


-- caluclates if it makes sense to go back and mine.
function fuel_getCriticalLevelLogical()
    -- get the distance between start position and last strip position
    local pathDistance = (strip_stripDistance+1)*(strip_current+3)
    -- get the distance between start position to dispose chest to fuel chest
    local chestsVec = fuel_chest-dispose_chest
    local chestsDistance = math.abs(dispose_chest.x)+math.abs(dispose_chest.z) + math.abs(chestsVec.x)+math.abs(chestsVec.z)
    return pathDistance*2 + chestsDistance*2 + math.max(strip_leftLimit,strip_rightLimit)
end

function listPop(array)
    table.remove(array,#array)
end

function stripMain()
    -- start the strip from the current position
    startPosition = startPosition or coordinates:clone()
    table.insert(locationStack,startPosition)
    table.insert(locationStack,startPosition)
    -- loop the strip algorithm
    for currentStrip_i=strip_current,strip_maxStrips do 
        strip_current = currentStrip_i
        -- get the next strip Positions
        local stripPos = startPosition+directionWalk[strip_direction]((strip_stripDistance+1)*currentStrip_i)
        local stripLeftPos = stripPos+directionWalk[(strip_direction-1)%4](strip_leftLimit)
        local stripRightPos = stripPos+directionWalk[(strip_direction+1)%4](strip_rightLimit)
        
        -- remove the last mainPath locationStack entry
        listPop(locationStack)
        -- walk to the main path
        walkTo(stripPos,digTunnelWalk)
        table.insert(locationStack,stripPos)
        fuel_updateCritialLevel()
        -- left
        walkTo(stripLeftPos,digTunnelWalk)
        walkBackwardsTo(stripPos)
        -- right
        walkTo(stripRightPos,digTunnelWalk)
        walkBackwardsTo(stripPos)

        
    end

end

function stripMainPyramid()
    -- start the strip from the current position
    startPosition = coordinates:clone()
    table.insert(locationStack,startPosition)
    table.insert(locationStack,startPosition)
    -- loop the strip algorithm
    for currentStrip_i=strip_current,strip_maxStrips do 
        strip_current = currentStrip_i
        -- get the next strip Positions
        local stripPos = startPosition+directionWalk[strip_direction]((strip_stripDistance+1)*currentStrip_i)
        local stripLeftPos = stripPos+directionWalk[(strip_direction-1)%4](strip_leftLimit+currentStrip_i-1)
        local stripRightPos = stripPos+directionWalk[(strip_direction+1)%4](strip_rightLimit+currentStrip_i-1)
        
        -- remove the last mainPath locationStack entry
        listPop(locationStack)
        -- walk to the main path
        walkTo(stripPos,digTunnelWalk)
        table.insert(locationStack,stripPos)
        fuel_updateCritialLevel()
        -- left
        walkTo(stripLeftPos,digTunnelWalk)
        walkBackwardsTo(stripPos)
        -- right
        walkTo(stripRightPos,digTunnelWalk)
        walkBackwardsTo(stripPos)

        
    end

end

function excavateWalk()
    turtle.dig()
    checkInventory()
    walk()
    turtle.digUp()
    turtle.digDown()
end

function excavateUpWalk()
    turtle.dig()
    checkInventory()
    walk()
    turtle.digUp()
end

function excavateDownWalk()
    turtle.dig()
    checkInventory()
    walk()
    turtle.digDown()
end



-- formular to create zigzag pattern in front or right direction
function excavateLayer(i1,i2,iter,veryLeftPos,length,directionIter,directionToGo,func)
    local zigPos
    local zagPos
    print("going this path: "..tostring(directionWalk[directionToGo](length)))

    for i=i1,i2,iter do
        if (i%2 == 0) then
            zigPos = veryLeftPos + directionWalk[directionIter](i)
            zagPos = veryLeftPos + directionWalk[directionToGo](length) + directionWalk[directionIter](i)
        else
            zigPos = veryLeftPos + directionWalk[directionToGo](length) + directionWalk[directionIter](i)
            zagPos = veryLeftPos + directionWalk[directionIter](i)
        end
        if (iter < 0) then
            walkTo(zagPos,func)
            walkTo(zigPos,func)
        else
            walkTo(zigPos,func)
            walkTo(zagPos,func)
        end
    end
end


-- calculates the veryLeft Position and looks if it excavates Vertically or Horizontally
function excavate(forward,left,right,layer,offset,func)
    -- calculates the fastest zigzag pattern
    local width = left+right+1

    local veryLeftPos = startPosition + directionWalk[excavate_direction](1) + directionWalk[(excavate_direction-1)%4](left) + directionWalk[4](offset)
    if (forward < width) then
        -- if the width is larger then begin from left to right    
        if (layer%2 == 0) then
            excavateLayer(0,forward-1,1,veryLeftPos,width,excavate_direction,(excavate_direction+1)%4,func)
        else
            excavateLayer(forward-1,0,-1,veryLeftPos,width,excavate_direction,(excavate_direction+1)%4,func)
        end
    else
        -- if front is larger then begin left but go forward and back again in zigzag
        print("front")
        if (layer%2 == 0) then
            excavateLayer(0,width-1,1,veryLeftPos,forward,(excavate_direction+1)%4,excavate_direction,func)
        else
            excavateLayer(width-1,0,-1,veryLeftPos,forward,(excavate_direction+1)%4,excavate_direction,func)
        end
    end
end

--[[
function excavate(forward,left,right,layer,func)
    -- calculates the fastest zigzag pattern
    local width = left+right+1

    local veryLeftPos = startPosition+directionWalk[excavate_direction](1)+directionWalk[(excavate_direction-1)%4](left)
    local zigPos
    local zagPos
    if (forward < width) then
        -- if the width is larger then begin from left to right    
        for i=0,front-1 then
            if (i%2 == 0) then
                -- go to the left edge. iterates forward
                zigPos = veryLeftPos+directionWalk[excavate_direction](i)
                -- go to the right edge. iterates forward
                zagPos = veryLeftPos+directionWalk[(excavate_direction-1)%4](width)+directionWalk[excavate_direction](i)
            else
                zigPos = veryLeftPos+directionWalk[(excavate_direction-1)%4](width)+directionWalk[excavate_direction](i)
                zagPos = veryLeftPos+directionWalk[excavate_direction](i)
            end
            walkTo(zigPos,func)
            walkTo(zagPos,func)
        end
    else
        -- if front is larger then begin left but go forward and back again in zigzag
        -- local veryFrontPos = veryLeftPos+directionWalk[excavate_direction](front)
        for i=0,width-1 then
            if (i%2 == 0) then
                -- the begin which  iterates to the right
                zigPos = veryLeftPos + directionWalk[(excavate_direction+1)%4](i)
                -- the forwardFront which  iterates to the right
                zagPos = veryLeftPos + directionWalk[excavate_direction](front) + directionWalk[(excavate_direction+1)%4](i)
            else
                zigPos = veryLeftPos + directionWalk[excavate_direction](front) + directionWalk[(excavate_direction+1)%4](i)
                zagPos = veryLeftPos + directionWalk[(excavate_direction+1)%4](i)
            end
            walkTo(zigPos,func)
            walkTo(zagPos,func)
        end
    end
end]]

-- define direction 
-- define depth forward, left, right, up and down.
-- firstly it tries to do the first down layer. With that it goes slowly up till the top

function excavateEverything()
    local upLength = excavate_up+excavate_down+1
    local offset = -excavate_down

    -- it can dig 3 blocks in one layer. Lets split up these layers in chunks
    local layers = math.ceil(upLength/3)

    -- if it has enough room to go one up then do this
    if (upLength > 1) then
        offset = offset+1
    end

    for i=excavate_currentLayer,layers do
        print("layer: "..i)
        print("upLength: "..upLength)
        print("offset: "..offset)
        -- if it has 3 blocks space
        if (upLength > 2) then
            excavate(excavate_forward,excavate_left,excavate_right,i,offset,excavateWalk)
            upLength = upLength-3
            offset = offset+3
        -- if it has only 2 blocks space up
        elseif (upLength > 1) then
            excavate(excavate_forward,excavate_left,excavate_right,i,offset,excavateDownWalk)
            upLength = upLength-2
        elseif (upLength > 0) then
            excavate(excavate_forward,excavate_left,excavate_right,i,offset,digWalk)
            upLength = upLength-1
        end

    end 

end

function excavateMain()
    startPosition = startPosition or coordinates:clone()
    local excavate_mode = excavateWalk
    table.insert(locationStack,startPosition)
    table.insert(locationStack,startPosition+directionWalk[excavate_direction](1))
    print(tostring(directionWalk[4](-excavate_down)))
    --excavate(excavate_forward,excavate_left,excavate_right,0,-1,excavateWalk)
    excavateEverything()

end



-- MAIN --
while (turtle.getFuelLevel() < 5) do
    print("Refuelling at the begin. Need Coal in Inventory")
    refuel()
end

--stripMain()
excavateMain()


-- debug --


function demo1()
    startPosition = coordinates:clone()
    table.insert(locationStack,startPosition)
    table.insert(locationStack,startPosition)
    walkTo(new(2,0,0))
    table.insert(locationStack,new(2,0,0))
    walkTo(new(2,0,2))
    emptyHome()
    printStack()
end

--demo1()