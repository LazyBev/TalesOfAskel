platform = {}
player = {}

function love.load()
    -- Load Background Image
    firstBackground = love.graphics.newImage("assets/Levels/LevelNormal.png")

    -- Platform Setup
    platform.beginTex = love.graphics.newImage("assets/platform_begin.png")
    platform.insideTex = love.graphics.newImage("assets/platform_inside.png")
    platform.midTex = love.graphics.newImage("assets/platform_mid.png")
    platform.endTex = love.graphics.newImage("assets/platform_end.png")
    platform.width = love.graphics.getWidth()
    platform.height = 20  -- Thin ground
    platform.scale = 2
    platform.x = 0
    platform.y = love.graphics.getHeight() / 2 + 100

    -- Player Setup
    player.x = love.graphics.getWidth() / 2
    player.y = platform.y - 32 -- Start above the platform
    player.speed = 200
    player.ground = platform.y - 32
    player.y_velocity = 0
    player.jump_height = -300
    player.gravity = 500
end

function love.update(dt)
    if love.keyboard.isDown('q') then
        love.event.quit();
    end

    -- Movement Left & Right
    if love.keyboard.isDown('d') then
        player.x = math.min(player.x + player.speed * dt, love.graphics.getWidth() - 32)
    elseif love.keyboard.isDown('a') then
        player.x = math.max(player.x - player.speed * dt, 0)
    end

    -- Jumping
    if (love.keyboard.isDown('space') or love.keyboard.isDown('w')) and player.y_velocity == 0 then
        player.y_velocity = player.jump_height
    end

    -- Apply Gravity
    if player.y_velocity ~= 0 then
        player.y = player.y + player.y_velocity * dt
        player.y_velocity = player.y_velocity + player.gravity * dt
    end

    -- Collision with Ground
    if player.y >= player.ground then
        player.y_velocity = 0
        player.y = player.ground
    end
end

function love.draw()
    -- Draw Background Image
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(firstBackground, 0, 0, 0, love.graphics.getWidth() / firstBackground:getWidth(), love.graphics.getHeight() / firstBackground:getHeight())

    -- Draw Platform Using Textures
    local tileWidth = platform.insideTex:getWidth() * platform.scale
    local startX = platform.x
    local endX = platform.x + platform.width

    -- Draw Start of the Platform
    love.graphics.draw(platform.beginTex, startX, platform.y, 0, platform.scale, platform.scale)
    startX = startX + platform.beginTex:getWidth() * platform.scale

    -- Draw Middle Tiles (Repeated)
    while startX + tileWidth < (endX - platform.endTex:getWidth() * platform.scale) + 1 do
        love.graphics.draw(platform.midTex, startX, platform.y, 0, platform.scale, platform.scale)
        startX = startX + tileWidth
    end

    -- Draw End of the Platform
    love.graphics.draw(platform.endTex, endX - platform.endTex:getWidth() * platform.scale, platform.y, 0, platform.scale, platform.scale)

    -- Draw the Inside Texture Below the Platform
    local insideY = platform.y + platform.height * platform.scale - 10
    local screenHeight = love.graphics.getHeight()

    -- Repeat the inside texture until the bottom of the screen
    local insideWidth = platform.insideTex:getWidth() * platform.scale
    local startXInside = platform.x
    local endYInside = screenHeight

    while insideY < endYInside do
        love.graphics.draw(platform.insideTex, startXInside, insideY, 0, platform.scale, platform.scale)
        insideY = insideY + platform.insideTex:getHeight() * platform.scale
    end


    -- Draw Player
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle('fill', player.x, player.y, 32, 32)
end
