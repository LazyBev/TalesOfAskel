-- Ocean Depths - A Love2D Roguelike Game
-- Main Game File

-- Constants
local GAME_WIDTH = 800
local GAME_HEIGHT = 600
local CURRENCY_NAME = "Pearls"
local MAX_OXYGEN = 100
local MAX_PRESSURE = 100
local OXYGEN_DEPLETION_BASE = 0.05
local PRESSURE_INCREASE = 0.2
local MAX_INVENTORY = 10

-- Game states
local GameState = {
    TITLE = 1,
    EXPLORE = 2,
    COMBAT = 3,
    SHOP = 4,
    GAME_OVER = 5,
    INVENTORY = 6
}

-- Initialize variables
local currentState
local player
local enemies
local currentEnemy
local shaders
local gameTime = 0
local depthLevel = 1
local shopItems = {}
local combatLog = {}
local bubbles = {}
local buttons = {}
local shopInventory = {}
local selectedInventoryItem = nil

-- Load game resources
function love.load()
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Load fonts
    fonts = {
        small = love.graphics.newFont(12),
        medium = love.graphics.newFont(18),
        large = love.graphics.newFont(24),
        title = love.graphics.newFont(48)
    }
    
    -- Initialize shaders
    initializeShaders()
    
    -- Initialize game state
    currentState = GameState.TITLE
    initializePlayer()
    initializeEnemies()
    initializeShop()
    generateBubbles(50)
    createButtons()
    
    -- Set window title
    love.window.setTitle("Ocean Depths")
end

-- Initialize player stats
function initializePlayer()
    player = {
        name = "Diver",
        maxHealth = 100,
        health = 100,
        attack = 10,
        defense = 5,
        luck = 5,
        currency = 50,
        depth = 0,
        maxDepth = 0,
        oxygen = MAX_OXYGEN,
        pressure = 0,
        inventory = {}
    }
end

-- Initialize enemy types
function initializeEnemies()
    enemies = {
        {
            name = "Jellyfish",
            baseHealth = 20,
            baseAttack = 5,
            baseDefense = 2,
            currency = 10,
            baseColor = {0.3, 0.3, 0.9},
            type = 1
        },
        {
            name = "Angler",
            baseHealth = 35,
            baseAttack = 8,
            baseDefense = 3,
            currency = 15,
            baseColor = {0.8, 0.5, 0.2},
            type = 1
        },
        {
            name = "Squid",
            baseHealth = 50,
            baseAttack = 12,
            baseDefense = 5,
            currency = 25,
            baseColor = {0.6, 0.2, 0.6},
            type = 2
        },
        {
            name = "Kraken",
            baseHealth = 100,
            baseAttack = 18,
            baseDefense = 10,
            currency = 50,
            baseColor = {0.7, 0.1, 0.2},
            type = 2
        },
        {
            name = "Leviathan",
            baseHealth = 200,
            baseAttack = 25,
            baseDefense = 15,
            currency = 100,
            baseColor = {0.2, 0.1, 0.8},
            type = 3
        }
    }
end

-- Initialize shop items
function initializeShop()
    shopItems = {
        -- Permanent upgrades
        {
            name = "Health Potion",
            description = "Restore 20 health",
            price = 15,
            isConsumable = true,
            effect = function() 
                player.health = math.min(player.health + 20, player.maxHealth)
                addToCombatLog("You used a Health Potion and restored 20 health!")
            end
        },
        {
            name = "Attack Up",
            description = "Increase attack by 2",
            price = 25,
            isConsumable = false,
            effect = function() 
                player.attack = player.attack + 2
                addToCombatLog("Your attack increased by 2!")
            end
        },
        {
            name = "Defense Up",
            description = "Increase defense by 2",
            price = 20,
            isConsumable = false,
            effect = function() 
                player.defense = player.defense + 2
                addToCombatLog("Your defense increased by 2!")
            end
        },
        {
            name = "Luck Up",
            description = "Increase luck by 1",
            price = 30,
            isConsumable = false,
            effect = function() 
                player.luck = player.luck + 1
                addToCombatLog("Your luck increased by 1!")
            end
        },
        {
            name = "Max Health Up",
            description = "Increase max health by 10",
            price = 35,
            isConsumable = false,
            effect = function() 
                player.maxHealth = player.maxHealth + 10
                player.health = player.health + 10
                addToCombatLog("Your max health increased by 10!")
            end
        },
        {
            name = "Oxygen Tank",
            description = "Increase max oxygen by 20",
            price = 40,
            isConsumable = false,
            effect = function() 
                MAX_OXYGEN = MAX_OXYGEN + 20
                player.oxygen = player.oxygen + 20
                addToCombatLog("Your oxygen capacity increased by 20!")
            end
        },
        {
            name = "Pressure Suit",
            description = "Reduce pressure buildup by 10%",
            price = 45,
            isConsumable = false,
            effect = function() 
                PRESSURE_INCREASE = PRESSURE_INCREASE * 0.9
                addToCombatLog("Your pressure suit improved! Pressure builds up 10% slower.")
            end
        },
        {
            name = "Oxygen Regulator",
            description = "Reduce oxygen consumption by 10%",
            price = 40,
            isConsumable = false,
            effect = function() 
                OXYGEN_DEPLETION_BASE = OXYGEN_DEPLETION_BASE * 0.9
                addToCombatLog("Your oxygen regulator improved! Oxygen depletes 10% slower.")
            end
        },
        -- Combat items
        {
            name = "Stun Bomb",
            description = "Skip enemy's next attack",
            price = 25,
            isConsumable = true,
            combatUse = true,
            effect = function()
                currentEnemy.stunned = true
                addToCombatLog("You used a Stun Bomb! " .. currentEnemy.name .. " is stunned!")
                return true -- Return true to indicate enemy turn should be skipped
            end
        },
        {
            name = "Strength Serum",
            description = "Double attack for next turn",
            price = 30,
            isConsumable = true,
            combatUse = true,
            effect = function()
                player.tempAttackBoost = player.attack
                addToCombatLog("You used a Strength Serum! Your attack is doubled for your next attack!")
                return false -- Still let the enemy attack
            end
        },
        {
            name = "Bubble Shield",
            description = "Negate next enemy attack",
            price = 35,
            isConsumable = true,
            combatUse = true,
            effect = function()
                player.bubbleShield = true
                addToCombatLog("You deployed a Bubble Shield! The next enemy attack will be negated!")
                return false -- Still let the enemy attack
            end
        },
        {
            name = "Depth Charge",
            description = "Deal 20 damage to enemy",
            price = 30,
            isConsumable = true,
            combatUse = true,
            effect = function()
                local damage = 20
                currentEnemy.health = math.max(0, currentEnemy.health - damage)
                addToCombatLog("You used a Depth Charge and dealt " .. damage .. " damage!")
                
                -- Check if enemy defeated
                if currentEnemy.health <= 0 then
                    addToCombatLog("You defeated the " .. currentEnemy.name .. "!")
                    addToCombatLog("You gained " .. currentEnemy.currency .. " " .. CURRENCY_NAME .. "!")
                    player.currency = player.currency + currentEnemy.currency
                    currentState = GameState.EXPLORE
                    return true -- Skip enemy turn since it's defeated
                end
                
                return false -- Let enemy attack if not defeated
            end
        },
        {
            name = "Mega Health Potion",
            description = "Restore 50 health",
            price = 40,
            isConsumable = true,
            combatUse = true,
            effect = function()
                player.health = math.min(player.health + 50, player.maxHealth)
                addToCombatLog("You used a Mega Health Potion and restored 50 health!")
                return false -- Let enemy attack
            end
        }
    }
end

-- Create UI buttons
function createButtons()
    buttons = {
        title = {
            {
                text = "Start Game",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT / 2 + 50,
                width = 200,
                height = 50,
                hover = false,
                pulse = 0,
                action = function() 
                    currentState = GameState.EXPLORE
                    player.depth = 0
                    generateRandomEncounter()
                end
            }
        },
        explore = {
            {
                text = "Continue Deeper",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 170,
                width = 200,
                height = 50,
                hover = false,
                pulse = 0,
                action = function() 
                    player.depth = player.depth + 10
                    if player.depth > player.maxDepth then
                        player.maxDepth = player.depth
                    end
                    -- Increase pressure as you go deeper
                    player.pressure = math.min(player.pressure + PRESSURE_INCREASE * (player.depth / 100), MAX_PRESSURE)
                    generateRandomEncounter()
                end
            },
            {
                text = "Visit Shop",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 110,
                width = 200,
                height = 50,
                hover = false,
                pulse = 0,
                action = function() 
                    currentState = GameState.SHOP
                    generateShopItems()
                end
            },
            {
                text = "Inventory",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 50,
                width = 200,
                height = 50,
                hover = false,
                pulse = 0,
                action = function()
                    currentState = GameState.INVENTORY
                end
            }
        },
        combat = {
            {
                text = "Attack",
                x = GAME_WIDTH / 4 - 75,
                y = GAME_HEIGHT - 80,
                width = 150,
                height = 50,
                hover = false,
                pulse = 0,
                action = function() 
                    attackEnemy()
                end
            },
            {
                text = "Counter",
                x = GAME_WIDTH / 2 - 75,
                y = GAME_HEIGHT - 80,
                width = 150,
                height = 50,
                hover = false,
                pulse = 0,
                action = function() 
                    counterEnemy()
                end
            },
            {
                text = "Use Item",
                x = 3 * GAME_WIDTH / 4 - 75,
                y = GAME_HEIGHT - 80,
                width = 150,
                height = 50,
                hover = false,
                pulse = 0,
                action = function() 
                    currentState = GameState.INVENTORY
                    selectedInventoryItem = nil
                end
            }
        },
        shop = {
            {
                text = "Return to Depths",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 60,
                width = 200,
                height = 50,
                hover = false,
                pulse = 0,
                action = function() 
                    currentState = GameState.EXPLORE
                end
            }
        },
        inventory = {
            {
                text = "Return",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 60,
                width = 200,
                height = 50,
                hover = false,
                pulse = 0,
                action = function() 
                    if currentState == GameState.INVENTORY then
                        -- Return to the previous state
                        if currentEnemy then
                            currentState = GameState.COMBAT
                        else
                            currentState = GameState.EXPLORE
                        end
                    end
                end
            }
        },
        gameOver = {
            {
                text = "Try Again",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT / 2 + 100,
                width = 200,
                height = 50,
                hover = false,
                pulse = 0,
                action = function() 
                    currentState = GameState.TITLE
                    initializePlayer()
                    initializeEnemies()
                    initializeShop()
                    clearCombatLog()
                end
            }
        }
    }
end

-- Initialize shaders
function initializeShaders()
    shaders = {
        water = love.graphics.newShader[[
            extern number time;
            extern number depth;
            
            vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
                vec2 uv = texture_coords;
                uv.y = uv.y + sin(uv.x * 10.0 + time * 0.5) * 0.01;
                
                vec4 pixel = Texel(texture, uv);
                
                // Darken based on depth
                float depthFactor = max(0.4, 1.0 - depth * 0.001);
                
                return pixel * color * vec4(depthFactor, depthFactor, depthFactor, 1.0);
            }
        ]]
    }
end

-- Generate random bubbles
function generateBubbles(count)
    bubbles = {}
    for i = 1, count do
        table.insert(bubbles, {
            x = math.random(0, GAME_WIDTH),
            y = math.random(0, GAME_HEIGHT),
            radius = math.random(2, 10),
            speed = math.random(10, 50) / 100,
            alpha = math.random(3, 8) / 10
        })
    end
end

-- Update bubbles
function updateBubbles(dt)
    for i, bubble in ipairs(bubbles) do
        bubble.y = bubble.y - bubble.speed * dt * 60
        if bubble.y + bubble.radius < 0 then
            bubble.y = GAME_HEIGHT + bubble.radius
            bubble.x = math.random(0, GAME_WIDTH)
        end
    end
end

-- Draw bubbles
function drawBubbles()
    love.graphics.setColor(1, 1, 1, 0.5)
    for _, bubble in ipairs(bubbles) do
        love.graphics.setColor(1, 1, 1, bubble.alpha)
        love.graphics.circle("line", bubble.x, bubble.y, bubble.radius)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Add item to combat log
function addToCombatLog(text)
    table.insert(combatLog, 1, text)
    if #combatLog > 5 then
        table.remove(combatLog)
    end
end

-- Clear combat log
function clearCombatLog()
    combatLog = {}
end

-- Generate random enemy encounter
function generateRandomEncounter()
    local enemyType = 1
    if player.depth > 50 then
        enemyType = math.random(1, 2)
    end
    if player.depth > 100 then
        enemyType = math.random(1, 3)
    end
    
    -- Filter enemies by type
    local possibleEnemies = {}
    for _, enemy in ipairs(enemies) do
        if enemy.type <= enemyType then
            table.insert(possibleEnemies, enemy)
        end
    end
    
    local selectedEnemy = possibleEnemies[math.random(#possibleEnemies)]
    
    -- Scale enemy based on depth
    local depthFactor = 1 + (player.depth / 100)
    currentEnemy = {
        name = selectedEnemy.name,
        health = math.floor(selectedEnemy.baseHealth * depthFactor),
        maxHealth = math.floor(selectedEnemy.baseHealth * depthFactor),
        attack = math.floor(selectedEnemy.baseAttack * depthFactor),
        defense = math.floor(selectedEnemy.baseDefense * depthFactor),
        currency = math.floor(selectedEnemy.currency * depthFactor),
        color = selectedEnemy.baseColor,
        animState = 0, -- Keep this for enemy animations
        stunned = false -- For stun bomb item
    }
    
    currentState = GameState.COMBAT
    addToCombatLog("You encountered a " .. currentEnemy.name .. "!")
end

-- Generate shop items
function generateShopItems()
    -- Randomly select 6 items from the shop item list
    local availableItems = {}
    for i, item in ipairs(shopItems) do
        table.insert(availableItems, i)
    end
    
    local selectedItems = {}
    for i = 1, math.min(6, #availableItems) do
        local index = math.random(#availableItems)
        table.insert(selectedItems, availableItems[index])
        table.remove(availableItems, index)
    end
    
    shopInventory = {}
    for _, itemIndex in ipairs(selectedItems) do
        table.insert(shopInventory, shopItems[itemIndex])
    end
end

-- Buy item from shop
function buyItem(index)
    local item = shopInventory[index]
    if player.currency >= item.price then
        player.currency = player.currency - item.price
        
        if item.isConsumable then
            -- Add to inventory if it's consumable
            if #player.inventory < MAX_INVENTORY then
                table.insert(player.inventory, item)
                addToCombatLog("You bought " .. item.name .. " and added it to your inventory!")
            else
                -- Refund if inventory is full
                player.currency = player.currency + item.price
                addToCombatLog("Inventory full! Cannot buy " .. item.name .. "!")
            end
        else
            -- Apply effect immediately if it's a permanent upgrade
            item.effect()
            addToCombatLog("You bought " .. item.name .. "!")
        end
    else
        addToCombatLog("Not enough " .. CURRENCY_NAME .. " to buy " .. item.name .. "!")
    end
end

-- Use item from inventory
function useItem(index)
    if not player.inventory[index] then return end
    
    local item = player.inventory[index]
    
    -- Check if we're in combat and item is for combat
    if currentState == GameState.COMBAT and item.combatUse then
        -- Use the item
        local skipEnemyTurn = item.effect()
        
        -- Remove the item after use
        table.remove(player.inventory, index)
        
        -- Return to combat
        currentState = GameState.COMBAT
        
        -- If the item doesn't skip the enemy turn, let the enemy attack
        if not skipEnemyTurn and currentEnemy.health > 0 then
            enemyAttack()
        end
    elseif currentState ~= GameState.COMBAT and not item.combatUse then
        -- Use non-combat item outside of combat
        item.effect()
        
        -- Remove the item after use
        table.remove(player.inventory, index)
        
        -- Return to explore mode
        currentState = GameState.EXPLORE
    else
        -- Cannot use this item in current context
        if currentState == GameState.COMBAT then
            addToCombatLog("This item cannot be used in combat!")
        else
            addToCombatLog("This item can only be used in combat!")
        end
    end
end

-- Calculate hit chance based on luck
function calculateHitChance(baseLuck)
    return 75 + (baseLuck * 2)
end

-- Calculate counter chance based on luck
function calculateCounterChance(baseLuck)
    return 50 + (baseLuck * 2)
end

-- Calculate run chance based on luck
function calculateRunChance(baseLuck)
    return 40 + (baseLuck * 3)
end

-- Attack enemy
function attackEnemy()
    -- Oxygen consumption during combat
    consumeOxygen()
    
    -- Apply temporary attack boost if active
    local attackBoost = 0
    if player.tempAttackBoost then
        attackBoost = player.tempAttackBoost
        player.tempAttackBoost = nil
        addToCombatLog("Your Strength Serum wears off after this attack!")
    end
    
    -- Calculate hit chance
    local hitChance = calculateHitChance(player.luck)
    if math.random(100) <= hitChance then
        -- Successful hit
        local damage = math.max(1, (player.attack + attackBoost) - currentEnemy.defense / 2)
        currentEnemy.health = math.max(0, currentEnemy.health - damage)
        currentEnemy.animState = 2
        addToCombatLog("You hit the " .. currentEnemy.name .. " for " .. damage .. " damage!")
        
        -- Check if enemy defeated
        if currentEnemy.health <= 0 then
            addToCombatLog("You defeated the " .. currentEnemy.name .. "!")
            addToCombatLog("You gained " .. currentEnemy.currency .. " " .. CURRENCY_NAME .. "!")
            player.currency = player.currency + currentEnemy.currency
            currentState = GameState.EXPLORE
            return
        end
    else
        -- Miss
        addToCombatLog("You missed the " .. currentEnemy.name .. "!")
    end
    
    -- Enemy attack
    if currentEnemy.stunned then
        addToCombatLog("The " .. currentEnemy.name .. " is stunned and cannot attack!")
        currentEnemy.stunned = false
    else
        enemyAttack()
    end
end

-- Counter enemy attack
function counterEnemy()
    -- Oxygen consumption during combat
    consumeOxygen()
    
    -- Calculate counter success chance
    local counterChance = calculateCounterChance(player.luck)
    local counterSuccess = math.random(100) <= counterChance
    
    if counterSuccess then
        -- Counter succeeds - negate damage and counterattack
        local counterDamage = math.floor(player.attack * 1.5)
        currentEnemy.health = math.max(0, currentEnemy.health - counterDamage)
        currentEnemy.animState = 2
        
        addToCombatLog("Your counter succeeded! You dealt " .. counterDamage .. " damage to the " .. currentEnemy.name .. "!")
        
        -- Check if enemy defeated
        if currentEnemy.health <= 0 then
            addToCombatLog("You defeated the " .. currentEnemy.name .. "!")
            addToCombatLog("You gained " .. currentEnemy.currency .. " " .. CURRENCY_NAME .. "!")
            player.currency = player.currency + currentEnemy.currency
            currentState = GameState.EXPLORE
            return
        end
    else
        -- Counter fails - take increased damage
        local damage = math.floor(currentEnemy.attack * 1.5) - player.defense
        
        -- Apply bubble shield if active
        if player.bubbleShield then
            addToCombatLog("Your Bubble Shield absorbed the attack!")
            player.bubbleShield = nil
            damage = 0
        else
            player.health = math.max(0, player.health - damage)
            addToCombatLog("Your counter failed! You took " .. damage .. " increased damage!")
        end
        
        -- Check if player defeated
        checkPlayerStatus()
    end
end

-- Run from combat
function runFromCombat()
    -- Oxygen consumption during combat
    consumeOxygen()
    
    -- Calculate run success chance
    local runChance = calculateRunChance(player.luck)
    if math.random(100) <= runChance then
        -- Successful run
        addToCombatLog("You successfully fled from the " .. currentEnemy.name .. "!")
        currentState = GameState.EXPLORE
    else
        -- Failed run, enemy attacks
        addToCombatLog("You failed to run away!")
        
        if currentEnemy.stunned then
            addToCombatLog("The " .. currentEnemy.name .. " is stunned and cannot attack!")
            currentEnemy.stunned = false
        else
            enemyAttack()
        end
    end
end

-- Enemy attacks player
function enemyAttack()
    currentEnemy.animState = 1
    
    -- Apply bubble shield if active
    if player.bubbleShield then
        addToCombatLog("Your Bubble Shield absorbed the attack!")
        player.bubbleShield = nil
        return
    }
    
    local damage = math.max(0, currentEnemy.attack - player.defense)
    player.health = math.max(0, player.health - damage)
    
    addToCombatLog("The " .. currentEnemy.name .. " hit you for " .. damage .. " damage!")
    
    -- Check if player defeated
    checkPlayerStatus()
end

-- Check player status
function checkPlayerStatus()
    if player.health <= 0 then
        addToCombatLog("You were defeated!")
        currentState = GameState.GAME_OVER
    end
    
    if player.oxygen <= 0 then
        addToCombatLog("You ran out of oxygen!")
        currentState = GameState.GAME_OVER
    end
end

-- Consume oxygen based on depth and pressure
function consumeOxygen()
    -- More pressure means faster oxygen consumption
    local pressureFactor = 1 + (player.pressure / 50)
    player.oxygen = math.max(0, player.oxygen - OXYGEN_DEPLETION_BASE * pressureFactor)
    
    if player.oxygen <= 0 then
        checkPlayerStatus()
    end
end

-- Update button states
function updateButtons(dt)
    local mx, my = love.mouse.getPosition()
    
    local currentButtons = {}
    if currentState == GameState.TITLE then
        currentButtons = buttons.title
    elseif currentState == GameState.EXPLORE then
        currentButtons = buttons.explore
    elseif currentState == GameState.COMBAT then
        currentButtons = buttons.combat
    elseif currentState == GameState.SHOP then
        currentButtons = buttons.shop
    elseif currentState == GameState.INVENTORY then
        currentButtons = buttons.inventory
    elseif currentState == GameState.GAME_OVER then
        currentButtons = buttons.gameOver
    end
    
    for _, button in ipairs(currentButtons) do
        button.hover = mx >= button.x and mx <= button.x + button.width and
                       my >= button.y and my <= button.y + button.height
                       
        if button.hover then
            button.pulse = button.pulse + dt * 2
            if button.pulse > 1 then
                button.pulse = 0
            end
        else
            button.pulse = 0
        end
    end
end

-- Draw buttons
function drawButtons()
    local currentButtons = {}
    if currentState == GameState.TITLE then
        currentButtons = buttons.title
    elseif currentState == GameState.EXPLORE then
        currentButtons = buttons.explore
    elseif currentState == GameState.COMBAT then
        currentButtons = buttons.combat
    elseif currentState == GameState.SHOP then
        currentButtons = buttons.shop
    elseif currentState == GameState.INVENTORY then
        currentButtons = buttons.inventory
    elseif currentState == GameState.GAME_OVER then
        currentButtons = buttons.gameOver
    end
    
    for _, button in ipairs(currentButtons) do
        -- Button background
        love.graphics.setColor(0.2, 0.3, 0.7, button.hover and 0.9 or 0.7)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Button outline
        love.graphics.setColor(0.5, 0.7, 1.0, 0.8 + button.pulse * 0.2)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Button text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts.medium)
        local textWidth = fonts.medium:getWidth(button.text)
        local textHeight = fonts.medium:getHeight()
        love.graphics.print(button.text, button.x + button.width / 2 - textWidth / 2,
                           button.y + button.height / 2 - textHeight / 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw combat log
function drawCombatLog()
    love.graphics.setFont(fonts.small)
    for i, text in ipairs(combatLog) do
        love.graphics.setColor(1, 1, 1, 1 - (i - 1) * 0.2)
        love.graphics.print(text, 20, GAME_HEIGHT - 140 - ((i - 1) * 20))
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw player stats
function drawPlayerStats()
    love.graphics.setFont(fonts.small)
    love.graphics.print("Health: " .. player.health .. "/" .. player.maxHealth, 20, 20)
    love.graphics.print("Attack: " .. player.attack, 20, 40)
    love.graphics.print("Defense: " .. player.defense, 20, 60)
    love.graphics.print("Luck: " .. player.luck, 20, 80)
    love.graphics.print(CURRENCY_NAME .. ": " .. player.currency, 20, 100)
    love.graphics.print("Depth: " .. player.depth .. "m", 20, 120)
    love.graphics.print("Items: " .. #player.inventory .. "/" .. MAX_INVENTORY, 20, 140)
    
    -- Draw oxygen bar
    love.graphics.setColor(0.2, 0.2, 0.5)
    love.graphics.rectangle("fill", GAME_WIDTH - 220, 20, 200, 20)
    love.graphics.setColor(0.2, 0.6, 1.0)
    love.graphics.rectangle("fill", GAME_WIDTH - 220, 20, (player.oxygen / MAX_OXYGEN) * 200, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", GAME_WIDTH - 220, 20, 200, 20)
    love.graphics.print("Oxygen: " .. math.floor(player.oxygen) .. "%", GAME_WIDTH - 210, 22)
    
    -- Draw pressure bar
    love.graphics.setColor(0.5, 0.2, 0.2)
    love.graphics.rectangle("fill", GAME_WIDTH - 220, 50, 200, 20)
    love.graphics.setColor(1.0, 0.4, 0.4)
    love.graphics.rectangle("fill", GAME_WIDTH - 220, 50, (player.pressure / MAX_PRESSURE) * 200, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", GAME_WIDTH - 220, 50, 200, 20)
    love.graphics.print("Pressure: " .. math.floor(player.pressure) .. "%", GAME_WIDTH - 210, 52)
end

-- Draw current enemy
function drawEnemy()
    if not currentEnemy then return end
    
    -- Calculate position
    local x, y = GAME_WIDTH / 2, GAME_HEIGHT / 2 - 50
    
    -- Animation offsets based on animation state
    if currentEnemy.animState == 1 then
        -- Attack animation
        x = x + math.sin(gameTime * 10) * 10
    elseif currentEnemy.animState == 2 then
        -- Hit animation
        y = y + math.sin(gameTime * 10) * 5
    end
    
    love.graphics.setColor(currentEnemy.color)
    
    -- Draw enemy based on type
    if string.find(currentEnemy.name, "Jellyfish") then
        -- Draw jellyfish
        love.graphics.circle("fill", x, y, 40)
        love.graphics.setColor(currentEnemy.color[1] * 1.2, currentEnemy.color[2] * 1.2, currentEnemy.color[3] * 1.2)
        for i = 1, 8 do
            local angle = (i / 8) * math.pi * 2
            local tentacleX = x + math.cos(angle) * 40
            local tentacleY = y + math.sin(angle) * 40
            love.graphics.line(tentacleX, tentacleY, tentacleX + math.cos(angle) * 30, tentacleY + math.sin(angle) * 30 + math.sin(gameTime * 3) * 10)
        end
    elseif string.find(currentEnemy.name, "Angler") then
        -- Draw angler fish
        love.graphics.setColor(currentEnemy.color)
        love.graphics.polygon("fill", x - 50, y, x + 30, y - 30, x + 30, y + 30)
        love.graphics.setColor(1, 1, 0.5)
        love.graphics.circle("fill", x + 40, y - 40, 10)
    elseif string.find(currentEnemy.name, "Squid") then
        -- Draw squid
        love.graphics.setColor(currentEnemy.color)
        love.graphics.ellipse("fill", x, y, 30, 50)
        for i = 1, 6 do
            local angle = (i / 6) * math.pi + math.pi/2
            local tentacleX = x + math.cos(angle) * 30
            local tentacleY = y + math.sin(angle) * 50
            love.graphics.line(tentacleX, tentacleY, 
                              tentacleX + math.cos(angle) * 40,
                              tentacleY + math.sin(angle) * 40 + math.sin(gameTime * 2 + i) * 10)
        end
    elseif string.find(currentEnemy.name, "Kraken") then
        -- Draw kraken
        love.graphics.setColor(currentEnemy.color)
        love.graphics.ellipse("fill", x, y - 30, 60, 40)
        for i = 1, 8 do
            local angle = (i / 8) * math.pi * 2
            local tentacleX = x + math.cos(angle) * 40
            local tentacleY = y - 30 + math.sin(angle) * 30
            local segments = 3
            local lastX, lastY = tentacleX, tentacleY
            
            for j = 1, segments do
                local nextX = lastX + math.cos(angle + math.sin(gameTime * 2 + i) * 0.2) * 30
                local nextY = lastY + math.sin(angle + math.sin(gameTime * 2 + i) * 0.2) * 30
                love.graphics.line(lastX, lastY, nextX, nextY)
                lastX, lastY = nextX, nextY
            end
        end
    elseif string.find(currentEnemy.name, "Leviathan") then
        -- Draw leviathan
        love.graphics.setColor(currentEnemy.color)
        love.graphics.ellipse("fill", x, y, 80, 50)
        
        -- Draw fins
        love.graphics.polygon("fill", 
            x - 40, y,
            x - 80, y - 40,
            x - 80, y + 40
        )
        
        -- Draw tail
        love.graphics.polygon("fill",
            x + 60, y - 10,
            x + 100, y - 40,
            x + 100, y + 40,
            x + 60, y + 10
        )
        
        -- Draw eye
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", x + 50, y - 20, 10)
    end
    
    -- Reset animation state
    currentEnemy.animState = 0
    
    -- Display enemy stats
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.medium)
    love.graphics.printf(currentEnemy.name, x - 100, y - 100, 200, "center")
    
    -- Health bar
    love.graphics.setColor(0.7, 0.2, 0.2)
    love.graphics.rectangle("fill", x - 50, y + 80, 100, 15)
    love.graphics.setColor(0.2, 0.7, 0.2)
    love.graphics.rectangle("fill", x - 50, y + 80, (currentEnemy.health / currentEnemy.maxHealth) * 100, 15)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x - 50, y + 80, 100, 15)
    love.graphics.setFont(fonts.small)
    love.graphics.printf(math.floor(currentEnemy.health) .. "/" .. currentEnemy.maxHealth, x - 50, y + 82, 100, "center")
end

-- Draw shop items
function drawShop()
    love.graphics.setFont(fonts.large)
    love.graphics.printf("Deep Sea Shop", 0, 50, GAME_WIDTH, "center")
    
    love.graphics.setFont(fonts.medium)
    love.graphics.printf(CURRENCY_NAME .. ": " .. player.currency, 0, 100, GAME_WIDTH, "center")
    
    local itemsPerRow = 3
    local itemWidth = 200
    local itemHeight = 120
    local startX = (GAME_WIDTH - (itemWidth * itemsPerRow + 20 * (itemsPerRow - 1))) / 2
    local startY = 150
    
    for i, item in ipairs(shopInventory) do
        local row = math.floor((i - 1) / itemsPerRow)
        local col = (i - 1) % itemsPerRow
        
        local x = startX + col * (itemWidth + 20)
        local y = startY + row * (itemHeight + 20)
        
        -- Check if mouse is hovering
        local mx, my = love.mouse.getPosition()
        local hover = mx >= x and mx <= x + itemWidth and
                     my >= y and my <= y + itemHeight
                     
        -- Draw item background
        if hover then
            love.graphics.setColor(0.3, 0.5, 0.8, 0.8)
        else
            love.graphics.setColor(0.2, 0.3, 0.6, 0.7)
        end
        love.graphics.rectangle("fill", x, y, itemWidth, itemHeight, 5, 5)
        
        -- Draw item border
        love.graphics.setColor(0.5, 0.7, 1.0, hover and 1.0 or 0.7)
        love.graphics.rectangle("line", x, y, itemWidth, itemHeight, 5, 5)
        
        -- Draw item info
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.medium)
        love.graphics.printf(item.name, x + 10, y + 10, itemWidth - 20, "center")
        
        love.graphics.setFont(fonts.small)
        love.graphics.printf(item.description, x + 10, y + 40, itemWidth - 20, "center")
        
        -- Draw price
        if player.currency >= item.price then
            love.graphics.setColor(0.2, 1.0, 0.2)
        else
            love.graphics.setColor(1.0, 0.2, 0.2)
        end
        love.graphics.printf(item.price .. " " .. CURRENCY_NAME, x + 10, y + itemHeight - 30, itemWidth - 20, "center")
        
        -- Draw consumable indicator
        if item.isConsumable then
            love.graphics.setColor(1, 1, 0.5)
            love.graphics.printf("(Consumable)", x + 10, y + itemHeight - 50, itemWidth - 20, "center")
        end
    end
    
    love.graphics.setColor(1, 1, 1)
end

-- Draw inventory
function drawInventory()
    love.graphics.setFont(fonts.large)
    love.graphics.printf("Inventory", 0, 50, GAME_WIDTH, "center")
    
    if #player.inventory == 0 then
        love.graphics.setFont(fonts.medium)
        love.graphics.printf("Your inventory is empty", 0, GAME_HEIGHT / 2 - 20, GAME_WIDTH, "center")
        return
    end
    
    local itemsPerRow = 4
    local itemWidth = 150
    local itemHeight = 100
    local startX = (GAME_WIDTH - (itemWidth * itemsPerRow + 20 * (itemsPerRow - 1))) / 2
    local startY = 150
    
    for i, item in ipairs(player.inventory) do
        local row = math.floor((i - 1) / itemsPerRow)
        local col = (i - 1) % itemsPerRow
        
        local x = startX + col * (itemWidth + 20)
        local y = startY + row * (itemHeight + 20)
        
        -- Check if mouse is hovering
        local mx, my = love.mouse.getPosition()
        local hover = mx >= x and mx <= x + itemWidth and
                     my >= y and my <= y + itemHeight
                     
        -- Check if selected
        local selected = i == selectedInventoryItem
        
        -- Draw item background
        if selected then
            love.graphics.setColor(0.4, 0.8, 0.4, 0.8)
        elseif hover then
            love.graphics.setColor(0.3, 0.5, 0.8, 0.8)
        else
            love.graphics.setColor(0.2, 0.3, 0.6, 0.7)
        end
        love.graphics.rectangle("fill", x, y, itemWidth, itemHeight, 5, 5)
        
        -- Draw item border
        if selected then
            love.graphics.setColor(0.5, 1.0, 0.5, 1.0)
        else
            love.graphics.setColor(0.5, 0.7, 1.0, hover and 1.0 or 0.7)
        end
        love.graphics.rectangle("line", x, y, itemWidth, itemHeight, 5, 5)
        
        -- Draw item info
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.small)
        love.graphics.printf(item.name, x + 5, y + 10, itemWidth - 10, "center")
        
        love.graphics.setFont(fonts.small)
        love.graphics.printf(item.description, x + 5, y + 40, itemWidth - 10, "center")
        
        -- Draw combat use indicator
        if item.combatUse then
            if currentState == GameState.COMBAT then
                love.graphics.setColor(1, 1, 0.5)
            else
                love.graphics.setColor(0.7, 0.7, 0.3)
            end
            love.graphics.printf("(Combat Use)", x + 5, y + itemHeight - 25, itemWidth - 10, "center")
        end
    end
    
    -- Show use button if an item is selected
    if selectedInventoryItem and player.inventory[selectedInventoryItem] then
        local buttonX = GAME_WIDTH / 2 - 75
        local buttonY = GAME_HEIGHT - 120
        local buttonWidth = 150
        local buttonHeight = 40
        
        local item = player.inventory[selectedInventoryItem]
        local canUse = (currentState == GameState.COMBAT and item.combatUse) or
                       (currentState ~= GameState.COMBAT and not item.combatUse)
        
        -- Draw button background
        if canUse then
            love.graphics.setColor(0.2, 0.7, 0.3, 0.8)
        else
            love.graphics.setColor(0.7, 0.3, 0.2, 0.8)
        end
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
        
        -- Draw button border
        love.graphics.setColor(0.5, 1.0, 0.5, canUse and 1.0 or 0.5)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.medium)
        love.graphics.printf("Use Item", buttonX, buttonY + 10, buttonWidth, "center")
    end
    
    love.graphics.setColor(1, 1, 1)
end

-- Draw title screen
function drawTitle()
    -- Background animation effect
    love.graphics.setColor(0.1, 0.2, 0.5, 1)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
    
    -- Title text
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.5, 0.7, 1.0, 1.0)
    love.graphics.printf("Ocean Depths", 0, GAME_HEIGHT / 4, GAME_WIDTH, "center")
    
    -- Subtitle
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.7, 0.8, 1.0, 0.8)
    love.graphics.printf("A Deep Sea Adventure", 0, GAME_HEIGHT / 4 + 60, GAME_WIDTH, "center")
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw game over screen
function drawGameOver()
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
    
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 0.3, 0.3, 1)
    love.graphics.printf("Game Over", 0, GAME_HEIGHT / 4, GAME_WIDTH, "center")
    
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("You reached a depth of " .. player.maxDepth .. " meters", 0, GAME_HEIGHT / 4 + 100, GAME_WIDTH, "center")
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Main update function
function love.update(dt)
    gameTime = gameTime + dt
    
    -- Update shaders
    if shaders.water then
        shaders.water:send("time", gameTime)
        shaders.water:send("depth", player.depth / 1000)
    end
    
    -- Update bubbles
    updateBubbles(dt)
    
    -- Update buttons
    updateButtons(dt)
    
    -- Consume oxygen when exploring
    if currentState == GameState.EXPLORE then
        consumeOxygen()
    end
    
    -- Update enemy animation
    if currentEnemy then
        -- Add subtle animation movement
        currentEnemy.animTime = (currentEnemy.animTime or 0) + dt
    end
end

-- Mouse press handler
function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    local currentButtons = {}
    if currentState == GameState.TITLE then
        currentButtons = buttons.title
    elseif currentState == GameState.EXPLORE then
        currentButtons = buttons.explore
    elseif currentState == GameState.COMBAT then
        currentButtons = buttons.combat
    elseif currentState == GameState.SHOP then
        currentButtons = buttons.shop
    elseif currentState == GameState.INVENTORY then
        currentButtons = buttons.inventory
    elseif currentState == GameState.GAME_OVER then
        currentButtons = buttons.gameOver
    end
    
    -- Check button clicks
    for _, button in ipairs(currentButtons) do
        if x >= button.x and x <= button.x + button.width and
           y >= button.y and y <= button.y + button.height then
            button.action()
            return
        end
    end
    
    -- Shop item click
    if currentState == GameState.SHOP then
        local itemsPerRow = 3
        local itemWidth = 200
        local itemHeight = 120
        local startX = (GAME_WIDTH - (itemWidth * itemsPerRow + 20 * (itemsPerRow - 1))) / 2
        local startY = 150
        
        for i, _ in ipairs(shopInventory) do
            local row = math.floor((i - 1) / itemsPerRow)
            local col = (i - 1) % itemsPerRow
            
            local ix = startX + col * (itemWidth + 20)
            local iy = startY + row * (itemHeight + 20)
            
            if x >= ix and x <= ix + itemWidth and
               y >= iy and y <= iy + itemHeight then
                buyItem(i)
                return
            end
        end
    end
    
    -- Inventory item click
    if currentState == GameState.INVENTORY then
        local itemsPerRow = 4
        local itemWidth = 150
        local itemHeight = 100
        local startX = (GAME_WIDTH - (itemWidth * itemsPerRow + 20 * (itemsPerRow - 1))) / 2
        local startY = 150
        
        -- Check inventory item clicks
        for i, _ in ipairs(player.inventory) do
            local row = math.floor((i - 1) / itemsPerRow)
            local col = (i - 1) % itemsPerRow
            
            local ix = startX + col * (itemWidth + 20)
            local iy = startY + row * (itemHeight + 20)
            
            if x >= ix and x <= ix + itemWidth and
               y >= iy and y <= iy + itemHeight then
                selectedInventoryItem = i
                return
            end
        end
        
        -- Check use button click
        if selectedInventoryItem and player.inventory[selectedInventoryItem] then
            local buttonX = GAME_WIDTH / 2 - 75
            local buttonY = GAME_HEIGHT - 120
            local buttonWidth = 150
            local buttonHeight = 40
            
            if x >= buttonX and x <= buttonX + buttonWidth and
               y >= buttonY and y <= buttonY + buttonHeight then
                useItem(selectedInventoryItem)
                selectedInventoryItem = nil
                return
            end
        end
    end
end

-- Main draw function
function love.draw()
    -- Apply water shader
    if shaders.water then
        love.graphics.setShader(shaders.water)
    end
    
    -- Background color based on depth
    local depthFactor = math.max(0.1, 1 - player.depth / 300)
    love.graphics.setColor(0.1 * depthFactor, 0.2 * depthFactor, 0.5 * depthFactor)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
    
    -- Draw bubbles
    drawBubbles()
    
    -- Reset shader
    love.graphics.setShader()
    
    -- Draw state-specific elements
    if currentState == GameState.TITLE then
        drawTitle()
    elseif currentState == GameState.EXPLORE then
        -- Draw exploration interface
        love.graphics.setFont(fonts.large)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf("Depth: " .. player.depth .. "m", 0, 50, GAME_WIDTH, "center")
        drawPlayerStats()
        drawCombatLog()
    elseif currentState == GameState.COMBAT then
        -- Draw combat interface
        drawEnemy()
        drawPlayerStats()
        drawCombatLog()
    elseif currentState == GameState.SHOP then
        -- Draw shop interface
        drawShop()
        drawPlayerStats()
        drawCombatLog()
    elseif currentState == GameState.INVENTORY then
        -- Draw inventory interface
        drawInventory()
        drawPlayerStats()
    elseif currentState == GameState.GAME_OVER then
        -- Draw game over screen
        drawGameOver()
    end
    
    -- Draw buttons
    drawButtons()
end
