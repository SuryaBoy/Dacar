-----------------------------------------------------------------------------------------
--
-- level1.lua
--
-----------------------------------------------------------------------------------------

local composer = require( "composer" )
local scene = composer.newScene()

-- include Corona's "physics" library
local physics = require "physics"

-- physics.setDrawMode( "hybrid" )
system.activate( "multitouch" )
--------------------------------------------

-- forward declarations and other locals
local screenW, screenH, halfW = display.actualContentWidth, display.actualContentHeight, display.contentCenterX

local maxScrollSpeed = 15
local scrollSpeed = 0  -- Adjust the scroll speed as needed
local isScrolling = false  -- Flag to control scrolling
local isSlowingDown = false  -- Flag to control the scrollspeed if the user tries to accelerate in the middle of slowing before hitting complete stop

local raiseFrontWheel = false
local raiseRearWheel = false

local gameTimer

local acceleratorButtonRealesed = false
local acceleratorButton
local upButton
local downButton
local jumpButton
local backButton

-- Set up display groups
local backGroup -- Display group for the background image
local mainGroup -- Display group for the players , obstacles,etc
local uiGroup -- Display group for UI objects like the score, buttons

local background1
local background2

local track1
-- local track2

local totalDistance = 1000000
local distanceCovered = 0
local distanceCoveredText

local lives = 10
local livesText
local died = false

local obstacles = {}
local obMap = {0,0,0,5,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,2,0,0,0,0,0,0,2,0,0,0,0,1,1,1,1,1,1,1,1,
		0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,
		0,2,0,0,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,
		0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,5,0,0,0,0,0,5,0,0,0,0,0,5,0,0,0,
		0,0,5,0,0,0,0,0,0,5,0,0,0,0,0,1,0,0,1,0,0,0,0,1,0,0,0,0,0,4,0,0,0,0,0,0,3,0,0,0,0,0,0,2,0,
		0,0,0,0,2,0,0,0,0,0,3,0,0,0,0,0,1,0,0,0,0,0,4,0,0,0,0,0,0,5,0,0,0,0,0,5,0,0,0,0,0,5,0,0,0,
		0,0,0,0,4,0,0,0,0,1,0,0,1,0,0,1,0,0,0,0,0,4,0,0,0,0,4,0,0,0,0,0,2,0,0,0,0,5,0,0,0,0,0,0,3,0,
		0,0,0,0,1,0,0,0,0,5,0,0,0,0,5,0,0,0,0,0,5,0,0,0,0,0,3,0,0,0,0,0,0,0,3,0,0,0,0,2,0,0,0,0,0,0,4,
		0,0,0,2,0,0,0,2,0,0,0,0,3,0,0,0,0,0,5,0,0,0,0,4,0,0,0,0,1,0,0,1,0,0,0,1,0,0,0,0,2,0,0,0,5,0,0,
		0,1,0,0,0,0,2,0,0,0,0,2,0,0,0,0,2,0,0,0,0,0,3,0,0,0,0,0,3,0,0,0,0,0,0,3,0,0,0,0,0,4}
local obMapIndex = 1
local firstObstacleDistanceInPx = screenW/2

local obstacleDisplayIntervalInPx = 50
local previousObstacleDisplayDistanceInPx = 0

-- topSensor senses the if the bike lands upside down 
local topSensor
local playerBike
local totalNumberOfEnemy = 500
local rank = totalNumberOfEnemy
local rankText
local totalNumberOfEnemyRemaining = totalNumberOfEnemy
local enemyBikes = {}
local previousEnemyBikeDisplayDistanceInPx = 0
local sheetOptions =
{
    width = 74,
    height = 48,
    numFrames = 4
}

local sheetCar = graphics.newImageSheet( "spritesheet.png", sheetOptions )

local sequenceCar = {
    -- consecutive frames sequence
    {
        name = "normalRun",
        frames = { 1,3,2,4 },
        time = 500,
        loopCount = 0,
        loopDirection = "forward"
    },

    {
        name = "slowingDown",
        frames = { 1,3,2,4 },
        time = 800,
        loopCount = 0,
        loopDirection = "forward"
    }
}

local function updateText()
    distanceCoveredText.text = "Distance : " .. distanceCovered
end

local function createEnemyBike()
	local enemyBike

	enemyBike = display.newSprite(mainGroup,sheetCar, sequenceCar )
	local bikeOutline = graphics.newOutline( 2, sheetCar, 1 )
	physics.addBody( enemyBike, "dynamic", {outline=bikeOutline, density=0.5, friction=0.5, bounce=0.4 } )

	enemyBike.x = screenW + 200
	enemyBike.y = track1.y - track1.height/2 - enemyBike.height/2
	enemyBike.type = 'enemyBike'
    enemyBike:setSequence( 'normalRun' )
    enemyBike:play()
    enemyBike.isJumping = false
    enemyBike.isBehind = false
	table.insert(enemyBikes, enemyBike)
end

local function scrollBikes()
    for i = #enemyBikes, 1, -1 do
    	if(scrollSpeed >= maxScrollSpeed/2) then 
    		enemyBikes[i].x = enemyBikes[i].x - scrollSpeed/2
    	else
    		-- if scrollspeed is less than max speed make the enemy by go fordward
    		enemyBikes[i].x = enemyBikes[i].x + 10
    		print("shit")
    	end
    	if(math.abs(enemyBikes[i].rotation)>90) then 
    		enemyBikes[i].rotation = 0
    	end
    	-- also remove obstacle if it is out of bound
        if enemyBikes[i].x < - 1000 then
            display.remove(enemyBikes[i])
            table.remove(enemyBikes, i)
            -- print("obstacle removed")
        end

        if ((enemyBikes[i].x < playerBike.x) and enemyBikes[i].isBehind == false) then 
        	enemyBikes[i].isBehind = true
        	rank = rank - 1
        	rankText.text = "Rank: " .. rank
        elseif ((enemyBikes[i].x > playerBike.x) and enemyBikes[i].isBehind == true) then
        	enemyBikes[i].isBehind = false
        	rank = rank + 1
        	rankText.text = "Rank: " .. rank
        end
    end
end

local function spawnEnemyBike()
	if (distanceCovered > 2000) then
		if (distanceCovered - previousEnemyBikeDisplayDistanceInPx) >= totalDistance/totalNumberOfEnemy then 
			if(math.random(1,totalNumberOfEnemy)<=totalNumberOfEnemyRemaining/2) then
				createEnemyBike()
				totalNumberOfEnemyRemaining = totalNumberOfEnemyRemaining - 1
				previousEnemyBikeDisplayDistanceInPx = distanceCovered
			end
		end

	end
end

local function createObstacle(obstacleData)
	local obstacle
	local obstacleOutline

	obstacleData = obstacleData or 1

	if (obstacleData == 1) then
		obstacle = display.newImage(mainGroup, "ramp1.png", screenW+50, screenH/2 )
		obstacleOutline = graphics.newOutline( 10, "ramp1.png" )
	    obstacle.y = track1.y - track1.height/2 - obstacle.height/5
	    obstacle.type = "ramp"
	elseif(obstacleData ==2) then
		obstacle = display.newImage(mainGroup, "ramp2.png", screenW+50, screenH/2 )
		obstacleOutline = graphics.newOutline( 10, "ramp2.png" )
	    obstacle.y = track1.y - track1.height/2 - obstacle.height/5
	    obstacle.type = "ramp"
	elseif(obstacleData ==3) then
		obstacle = display.newImage(mainGroup, "ramp3.png", screenW+50, screenH/2 )
		obstacleOutline = graphics.newOutline( 10, "ramp3.png" )
	    obstacle.y = track1.y - track1.height/2 - obstacle.height/5
	    obstacle.type = "ramp"
	elseif(obstacleData ==4) then
		obstacle = display.newImage(mainGroup, "ramp4.png", screenW+50, screenH/2 )
		obstacleOutline = graphics.newOutline( 10, "ramp4.png" )
	    obstacle.y = track1.y - track1.height/2 - obstacle.height/5
	    obstacle.type = "ramp"
	elseif(obstacleData ==5) then
		obstacle = display.newImage(mainGroup, "spike.png", screenW+50, screenH/2 )
		obstacleOutline = graphics.newOutline( 10, "spike.png" )
	    obstacle.y = track1.y - track1.height/2 - obstacle.height/7
	    obstacle.type = "spike"
	end
    -- local obstacle = display.newImage( "ramp.png", screenW+50, screenH/2 )
    -- local obstacleOutline = graphics.newOutline( 10, "ramp.png" )
    -- obstacle.y = track.y - obstacle.height/2
    -- obstacle.type = "ramp"
    physics.addBody(obstacle, "static",{outline=obstacleOutline,friction=0.4,density=1})
    table.insert(obstacles, obstacle)
    -- transition.to(obstacle, { x = -50, time = 3000, onComplete = function() display.remove(obstacle) end })
end

-- local function createObstacleMap()
--     for i = 1, #obstacleMap do
--         createObstacle(obstacleMap[i])
--     end
-- end


local function scrollObstacles()
    for i = #obstacles, 1, -1 do
    	obstacles[i].x = obstacles[i].x - scrollSpeed
    	-- also remove obstacle if it is out of bound
        if obstacles[i].x < - 150 then
            display.remove(obstacles[i])
            table.remove(obstacles, i)
            -- print("obstacle removed")
        end
    end
end

local function checkObstacleBasedOnDistance(targetDistance)
	-- here the function looks at the obstacle map then renders the obstacle if it is in the 
	-- valid distance from the bike or player
	if (obMap[obMapIndex] ~= nil) then   
		if (targetDistance >= firstObstacleDistanceInPx) then
			if (targetDistance - previousObstacleDisplayDistanceInPx) >= obstacleDisplayIntervalInPx then
				if(obMap[obMapIndex] ~= 0) then
					createObstacle(obMap[obMapIndex])
				end
				previousObstacleDisplayDistanceInPx = targetDistance
				obMapIndex = obMapIndex + 1
			end
		end
	end
end

local function onAcceleratorPressed( event )
	if (died == false) then

	    if ( event.phase == "began" ) then
	        print( "Touch event began on: " )
	    	if(isSlowingDown == true) then
	    		-- some times the user might press the accelerator before complete stop
	    		-- thats why we have to manually make the acceleratorButtonReleased false in this step
	    		acceleratorButtonRealesed = false
	    	else
	    		scrollSpeed = 1
	    	end
	        isScrolling = true
	        playerBike:setSequence( 'normalRun' )
	        playerBike:play()
	        print("fk")
	    elseif ( event.phase == "ended" ) then
	        print( "Touch event ended on: " )
	        -- isScrolling = false
	        acceleratorButtonRealesed = true
	        playerBike:setSequence('slowingDown')
	        playerBike:play()
	    end

	end
    return true
end

local function restoreBike()
 	
 	-- playerBike:pause()
    playerBike.isBodyActive = false
    topSensor.isBodyActive = false

	playerBike.x = 100 + playerBike.width/2
	playerBike.y = 0
	playerBike:rotate(-playerBike.rotation)
	topSensor.x = playerBike.x + 10
	topSensor.y = playerBike.y - 19
 	print("hello darkness")
    -- Fade in the ship
    transition.to( playerBike, { alpha=1, time=200,
        onComplete = function()

            timer.performWithDelay( 50, function()
					playerBike.isBodyActive = true
            		topSensor.isBodyActive = true
    				acceleratorButton:addEventListener("touch", onAcceleratorPressed)
    				died = false
            	end )
        end
    } )
end

local function onUpButtonPressed( event )
    if ( event.phase == "began" ) then
    	raiseFrontWheel = true
    elseif ( event.phase == "ended" ) then
    	raiseFrontWheel = false
    end
    return true
end

local function onDownButtonPressed( event )
    if ( event.phase == "began" ) then
    	raiseRearWheel = true
    elseif ( event.phase == "ended" ) then
    	raiseRearWheel = false
    end
    return true
end

local jumpForce = 300

local function jump(obj)
    if obj.isJumping == false then
        obj:applyForce( 10, -jumpForce, obj.x, obj.y )
        obj.isJumping = true
    end
end

local function onJumpButtonPressed( event )
    if ( event.phase == "began" ) then
    	jump(playerBike)
    elseif ( event.phase == "ended" ) then
    	
    end
    return true
end

local function onBackButtonPressed( event )
    composer.gotoScene( "menu", { time=800, effect="crossFade" } )
    return true
end



-- sprite listener function
local function playerBikeListener( event )
 
    -- local thisSprite = event.target  -- "event.target" references the sprite
 
    if ( event.phase == "ended" ) then 
        -- thisSprite:setSequence( "fastRun" )  -- switch to "fastRun" sequence
        -- thisSprite:play()  -- play the new sequence
        -- isScrolling = false
    end
end

local function onGlobalCollision( event )
 
    if ( event.phase == "began" ) then
        -- print( "began: " .. event.object1.myName .. " and " .. event.object2.myName )
        if((event.object1.type == 'enemyBike' and event.object2.type == 'ramp') or (event.object1.type == 'ramp' and event.object2.type == 'enemyBike')) then
 			if(event.object1.type == 'enemyBike') then 
 				jump(event.object1)
 			else
 				jump(event.object2)
 			end
 		end
 		if((event.object1.type == 'enemyBike' and event.object2.type == 'ground') or (event.object1.type == 'ground' and event.object2.type == 'enemyBike')) then
 			if(event.object1.type == 'enemyBike') then 
 				event.object1.isJumping = false
 			else
 				event.object2.isJumping = false
 			end
    	end
 		if((event.object1.type == 'enemyBike' and event.object2.type == 'spike') or (event.object1.type == 'spike' and event.object2.type == 'enemyBike')) then
 			if(event.object1.type == 'enemyBike') then 
 				event.object1:applyLinearImpulse( math.random(2,8), math.random(-4,-1),event.object1.x,event.object1.y )
 			else
 				event.object2:applyLinearImpulse( math.random(2,8), math.random(-4,-1),event.object2.x,event.object2.y )
 			end
    	end

    elseif ( event.phase == "ended" ) then
        -- print( "ended: " .. event.object1.myName .. " and " .. event.object2.myName )
    end
end

local function onCollision(self, event )
    if event.phase == "began" and event.other.type == "ramp" then
        jump(playerBike)  -- Trigger a jump when hitting a 
        -- event.contact.bounce = 0
        -- event.contact.friction = 1
        -- event.contact.tangentSpeed = 0.5
        -- print(event.contact.tangentSpeed)
    elseif event.phase == "ended" and event.other.type == "ramp" then
    	jumpForce = 70
    	playerBike.isJumping = false
    elseif event.phase == "began" and event.other.type == "ground" then
    	jumpForce = 300
    	playerBike.isJumping = false
    elseif event.phase == "began" and event.other.type == "spike" then
    	-- self:applyAngularImpulse( math.random( -50,50 ) )
    	self:applyLinearImpulse( math.random(2,8), math.random(-4,-1),self.x,self.y )
    end
end

local function checkUpsideDownUsingSensor(event)
    if event.phase == "began" then -- Check for initial contact
        if event.other.type == "ground" or event.other.type == "ramp" then
            print("Body landed upside down based on sensor contact")
            -- physics.pause( )
	    	scrollSpeed = 0
	    	isScrolling = false
	    	acceleratorButtonRealesed = false
	    	acceleratorButton:removeEventListener( "touch", onAcceleratorPressed )
	    	-- the obstacle should be made inactive also
	    	-- local ramp = nil
	    	-- if (event.other.type == "ramp") then 
	    	-- 	-- event.other.alpha = 0
			-- 	-- 	timer.performWithDelay( 10, function()
			-- 	-- 		event.other.isBodyActive = false
			-- 	-- 	end )
			-- 	-- ramp = event.other
	    	-- end
	    	
	        if ( died == false ) then
	            died = true

	            -- Update lives
	            lives = lives - 1
	            livesText.text = "Lives: " .. lives

	            if ( lives == 0 ) then
	                display.remove( playerBike )
	                -- timer.performWithDelay( 2000, endGame )
	            else
	                playerBike.alpha = 0
	                topSensor.alpha = 0
 					playerBike:pause()
    -- playerBike.isBodyActive = false
    -- topSensor.isBodyActive = false
	                timer.performWithDelay( 500, restoreBike )
	            end
	        end
            -- Handle upside-down case
        end
    end
end

-- Called when a key event has been received
-- this function is only for testing purpose in pc
local function onKeyEvent( event )
 
    -- Print which key was pressed down/up
    -- local message = "Key '" .. event.keyName .. "' was pressed " .. event.phase
    -- print( message )
 
    if ( event.keyName == "a" and event.phase == "down" ) then
    	raiseFrontWheel = true
    elseif (event.keyName == "a" and event.phase == "up") then
    	raiseFrontWheel = false
    elseif (event.keyName == "z" and event.phase == "down") then
    	raiseRearWheel = true
    elseif (event.keyName == "z" and event.phase == "up") then
    	raiseRearWheel = false
    elseif (event.keyName == "space" and event.phase == "up") then
    	jump(playerBike)
    end

    if (died == false) then
	    if ( event.keyName == "right" and event.phase == "down" ) then
	    	if(isSlowingDown == true) then
	    		-- some times the user might press the accelerator before complete stop
	    		-- thats why we have to manually make the acceleratorButtonReleased false in this step
	    		acceleratorButtonRealesed = false
	    	else
	    		scrollSpeed = 1
	    	end
	        isScrolling = true
	        playerBike:setSequence( 'normalRun' )
	        playerBike:play()
	        -- playerBike:setLinearVelocity( 50, 0 )
	        -- playerBike:applyForce( 100, 0, playerBike.x, playerBike.y )
	        -- print("accelerator button pressed")
	    elseif (event.keyName == "right" and event.phase == "up") then
	        acceleratorButtonRealesed = true
	        playerBike:setSequence('slowingDown')
	        playerBike:play()
	        -- print("accelerator button released")
	    end
 	end
    -- IMPORTANT! Return false to indicate that this app is NOT overriding the received key
    -- This lets the operating system execute its default handling of the key
    return false
end


local function gameLoop()

	if (raiseFrontWheel == true) then
		playerBike:applyAngularImpulse( -26 )
		-- playerBike:applyTorque( -20 )
	elseif (raiseRearWheel == true) then
		playerBike:applyAngularImpulse( 26 )
		-- playerBike:applyTorque( 20 )
	end

	if (died ~= true) then

		if (isScrolling == true) then
	        -- Move both background images to create the scrolling effect
	        -- print("is scrolling")
	        if(acceleratorButtonRealesed == true) then
	    		if(scrollSpeed > 0) then
	    			isSlowingDown = true
	    			scrollSpeed = scrollSpeed - 0.5
	    			-- print("slowing Down")
	    		else
	    			acceleratorButtonRealesed = false
	    			isScrolling = false
	    			playerBike:pause()
	    			isSlowingDown = false
	    			-- print("is not scrolling")
	    		end
	        else
	    		if(scrollSpeed < maxScrollSpeed) then
	    			scrollSpeed = scrollSpeed + 0.5
	    		end
	        end
	        playerBike.x = playerBike.x + scrollSpeed
	        if (playerBike.x > 200) then
	        	playerBike.x = 200
		        background1.x = background1.x - scrollSpeed
	        	background2.x = background2.x - scrollSpeed
		    	-- checkFirstObstacleBasedOnDistance(distanceCovered)
		    	checkObstacleBasedOnDistance(distanceCovered)
	    		scrollObstacles()
	    		-- print(playerBike.rotation)
	        end

	        -- Check if either background image is completely off the screen
	        if background1.x + background1.width < 0 then
	            background1.x = background2.x + background2.width
	        elseif background2.x + background2.contentWidth < 0 then
	            background2.x = background1.x + background1.width
	        end
	    -- Update game logic here

	    	-- checkFirstObstacleBasedOnDistance(distanceCovered)
	    	-- scrollObstacles()
		end

		spawnEnemyBike()
		

		distanceCovered = distanceCovered + scrollSpeed
		distanceCoveredText.text = "Distance : ".. distanceCovered

	end

		scrollBikes()


	if (playerBike.x < 70 ) then 
		-- playerBike.x=70 + playerBike.width/2
		playerBike:applyLinearImpulse( 1, 0, playerBike.x, playerBike.y )
	end
end


function scene:create( event )

	-- Called when the scene's view does not exist.
	-- 
	-- INSERT code here to initialize the scene
	-- e.g. add display objects to 'sceneGroup', add touch listeners, etc.

	local sceneGroup = self.view

	-- We need physics started to add bodies, but we don't want the simulaton
	-- running until the scene is on the screen.
	physics.start()
	physics.pause()

    -- Set up display groups
    backGroup = display.newGroup()  -- Display group for the background image
    sceneGroup:insert( backGroup )  -- Insert into the scene's view group
 
    mainGroup = display.newGroup()  -- Display group for the ship, asteroids, lasers, etc.
    sceneGroup:insert( mainGroup )  -- Insert into the scene's view group
 
    uiGroup = display.newGroup()    -- Display group for UI objects like the score
    sceneGroup:insert( uiGroup )    -- Insert into the scene's view group


	-- Create two background images
	background1 = display.newImage(backGroup,"desert_BG.png", display.contentCenterX, display.contentCenterY)
	background1.width = screenW * 2
	background1.height = screenH

	background2 = display.newImage(backGroup,"desert_BG.png", display.contentCenterX + screenW*2, display.contentCenterY)
	background2.width = screenW * 2
	background2.height = screenH

	-- local player = display.newRect(50, display.contentCenterY, 50, 50)
	-- player:setFillColor(1, 0, 0)
	-- physics.addBody(player, "dynamic")


	track1 = display.newRect(mainGroup,0, 0, screenW*4, 80 )
	-- track.strokeWidth = 0
	track1:setFillColor(1,1,1)
	-- track:setStrokeColor( 0, 0, 0 )
	-- track1.anchorX = 0
	-- track1.anchorY = 1
	track1.x, track1.y = 0, screenH - track1.height/2
	track1.type = "ground"
	physics.addBody( track1, "static", 
		{
		 friction=0.3, 
		 density=5
		 }
	)


	playerBike = display.newSprite(mainGroup,sheetCar, sequenceCar )

	
	-- playerBike:scale(0.5,0.5)
	local letterOutline = graphics.newOutline( 2, sheetCar, 1 )
	physics.addBody( playerBike, "dynamic", {outline=letterOutline, density=0.5, friction=0.5, bounce=0.4 } )
	playerBike.x = 120 + playerBike.width/2
	playerBike.y = track1.y - track1.height/2 - playerBike.height/2
	playerBike.isJumping = false
	topSensor = display.newRect(mainGroup,playerBike.x + 10, playerBike.y - 19, 5, 5)
	topSensor:setFillColor( 0,0,0 )
	physics.addBody(topSensor, "pivot", {isSensor = true,density=0,bounce=0})
	-- local joint = physics.newJoint("pivot", playerBike, sensor, playerBike.x, playerBike.y) -- Adjust joint anchor
	local pivotJoint = physics.newJoint( "weld", playerBike, topSensor, playerBike.x, playerBike.y )
	pivotJoint.isLimitEnabled = true
	topSensor:addEventListener("collision", checkUpsideDownUsingSensor)
	-- add the event listener to the sprite
	-- playerBike:addEventListener( "sprite", playerBikeListener )
	playerBike.collision = onCollision
	playerBike:addEventListener( "collision" )
	playerBike.angularDamping = 0.7

	backButton = display.newImageRect( uiGroup, "backButton.png", 50, 50 )
	backButton.y = backButton.width/2 + 20
	backButton.x = screenW - 200
	backButton:addEventListener("tap", onBackButtonPressed )


	upButton = display.newImageRect( uiGroup, "upButton.png", 60, 60 )
	upButton.y = screenH/2 + upButton.height/2
	upButton.x = 0 + upButton.width/2
	upButton:addEventListener("touch", onUpButtonPressed )

	downButton = display.newImageRect( uiGroup, "downButton.png", 60, 60 )
	downButton.y = upButton.y + upButton.height/2 + 50
	downButton.x = 0 + upButton.width/2
	downButton:addEventListener("touch", onDownButtonPressed )



	distanceCoveredText = display.newText( uiGroup, "Distance : " .. distanceCovered, 20, 30, native.systemFont, 20 )
	livesText = display.newText( uiGroup, "Lives: " .. lives, 20, 50, native.systemFont, 20 )
	rankText = display.newText( uiGroup, "Rank: " .. rank, backButton.x-100, 30, native.systemFont, 20 )
	-- Create a button to accelerate
	acceleratorButton = display.newImageRect(uiGroup,"aButton.png", 60, 60)
	acceleratorButton.x = screenW - 200
	acceleratorButton.y = downButton.y

	acceleratorButton:addEventListener("touch", onAcceleratorPressed)

	jumpButton = display.newImageRect( uiGroup, "jumpButton.png", 60, 60 )
	jumpButton.y = (upButton.y + downButton.y)/2
	jumpButton.x = upButton.x + upButton.width/2 + 40
	jumpButton:addEventListener("touch", onJumpButtonPressed )

end


function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase
	
	if phase == "will" then
		-- Called when the scene is still off screen and is about to move on screen
	elseif phase == "did" then
		-- Called when the scene is now on screen
		-- 
		-- INSERT code here to make the scene come alive
		-- e.g. start timers, begin animation, play audio, etc.
		gameTimer = timer.performWithDelay( 50, gameLoop, -1 )
		physics.start()
		physics.setGravity( 0, 10 )
		-- timer.performWithDelay(2000, createObstacle, 0)
		Runtime:addEventListener( "key", onKeyEvent )
		Runtime:addEventListener( "collision", onGlobalCollision )
	end
end

function scene:hide( event )
	local sceneGroup = self.view
	
	local phase = event.phase
	
	if event.phase == "will" then
		-- Called when the scene is on screen and is about to move off screen
		--
		-- INSERT code here to pause the scene
		-- e.g. stop timers, stop animation, unload sounds, etc.)
		timer.cancel( gameTimer )
		physics.stop()
	elseif phase == "did" then
		-- Called when the scene is now off screen
		composer.removeScene( "level1" )
	end	
	
end

function scene:destroy( event )

	-- Called prior to the removal of scene's "view" (sceneGroup)
	-- 
	-- INSERT code here to cleanup the scene
	-- e.g. remove display objects, remove touch listeners, save state, etc.
	local sceneGroup = self.view
	
	package.loaded[physics] = nil
	physics = nil
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------

return scene