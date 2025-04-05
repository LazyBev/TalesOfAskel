-- Ocean Depths - A Love2D Roguelike Game
-- Main Game File

-- Constants
local GAME_WIDTH = 800
local GAME_HEIGHT = 600
local CURRENCY_NAME = "Pearls"
local MAX_OXYGEN = 100
local MAX_INVENTORY = 10
local OXY_DEPL_MULT = nil

-- Game states
local GameState = {
    TITLE = 1,
    EXPLORE = 2,
    COMBAT = 3,
    SHOP = 4,
    GAME_OVER = 5,
    INVENTORY = 6,
    PAUSE = 7
}

-- Combat states
local CombatState = {
    ATTACK = 1,
    COUNTER = 2,
    USE_ITEM = 3,
    REFILL_OXYGEN = 4
}

-- Initialize variables
local currentGameState
local currentCombatState
local player
local enemies
local currentEnemy
local shaders
local gameTime = 0
local depthLevel = 1
local shopItems = {}
local combatLog = {}

local buttons = {}
local shopInventory = {}
local selectedInventoryItem = nil

function love.load()
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Load fonts
    fonts = {
        small = love.graphics.newFont(12),
        medium = love.graphics.newFont(18),
        large = love.graphics.newFont(24),
        title = love.graphics.newFont(70)
    }
    
    -- Initialize shaders
    initializeShaders()
    
    -- Create canvas for CRT effect
    canvas = love.graphics.newCanvas(GAME_WIDTH, GAME_HEIGHT)
    canvas:setFilter("nearest", "nearest") -- Keep pixelated look
    
    -- Initialize game state
    currentGameState = GameState.TITLE
    initializePlayer()
    initializeEnemies()
    initializeShop()
    createButtons()
    
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
        inventory = {}
    }
end

-- Initialize enemy types
function initializeEnemies()
    enemies = {
        {
            name = "Jellyfish",
            baseHealth = 20,
            baseAttack = 10,
            baseDefense = 2,
            currency = 10,
            baseColor = {0.3, 0.3, 0.9},
            type = 1
        },
        {
            name = "Angler",
            baseHealth = 35,
            baseAttack = 13,
            baseDefense = 3,
            currency = 15,
            baseColor = {0.8, 0.5, 0.2},
            type = 1
        },
        {
            name = "Squid",
            baseHealth = 50,
            baseAttack = 15,
            baseDefense = 5,
            currency = 25,
            baseColor = {0.6, 0.2, 0.6},
            type = 2
        },
        {
            name = "Kraken",
            baseHealth = 100,
            baseAttack = 20,
            baseDefense = 10,
            currency = 50,
            baseColor = {0.7, 0.1, 0.2},
            type = 2
        },
        {
            name = "Leviathan",
            baseHealth = 200,
            baseAttack = 22,
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
            name = "Health Boost",
            description = "Increase max health by 10 + health by 10",
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
                    currentGameState = GameState.EXPLORE
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
        pause = {
            {
                text = "Resume",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT / 2 - 20,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                action = function()
                    currentGameState = GameState.COMBAT
                end
            },
            {
                text = "Run",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT / 2 + 55,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                action = function()
                    currentGameState = GameState.COMBAT
                    runFromCombat()
                end
            }
        },
        title = {
            {
                text = "Start Game",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT / 2 - 20,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function() 
                    currentGameState = GameState.EXPLORE
                    player.depth = 0
                end
            },
            {
                text = "Quit",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT / 2 + 55,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function() 
                    love.event.quit()
                end
            }
        },
        explore = {
            {
                text = "Continue Deeper",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 400,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function() 
                    player.depth = player.depth + 10
                    if player.depth > player.maxDepth then
                        player.maxDepth = player.depth
                    end
                    generateRandomEncounter()
                end
            },
            {
                text = "Visit Shop",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 320,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function() 
                    currentGameState = GameState.SHOP
                    generateShopItems()
                end
            },
            {
                text = "Inventory",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 240,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function()
                    currentGameState = GameState.INVENTORY
                end
            },
            {
                text = "Quit",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 160,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function()
                    love.event.quit()
                end
            }
        },
        combat = {
            {
                text = "Attack",
                x = GAME_WIDTH - 775,
                y = GAME_HEIGHT - 80,
                baseWidth = 150,
                baseHeight = 50,
                width = 150,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function()
                    currentCombatState = CombatState.ATTACK
                    OXY_DEPL_MULT = 1
                    consumeOxygen()
                    attackEnemy()
                end
            },
            {
                text = "Counter",
                x = GAME_WIDTH - 575,
                y = GAME_HEIGHT - 80,
                baseWidth = 150,
                baseHeight = 50,
                width = 150,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function()
                    currentCombatState = CombatState.COUNTER
                    OXY_DEPL_MULT = 1
                    consumeOxygen()
                    counterEnemy()
                end
            },
            {
                text = "Use Item",
                x = GAME_WIDTH - 375,
                y = GAME_HEIGHT - 80,
                baseWidth = 150,
                baseHeight = 50,
                width = 150,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function()
                    currentCombatState = CombatState.USE_ITEM
                    OXY_DEPL_MULT = 1
                    consumeOxygen()
                    currentGameState = GameState.INVENTORY
                    selectedInventoryItem = nil
                end
            },
            {
                text = "Refill Oxygen",
                x = GAME_WIDTH - 175,
                y = GAME_HEIGHT - 80,
                baseWidth = 150,
                baseHeight = 50,
                width = 150,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function()
                    currentCombatState = CombatState.REFILL_OXYGEN
                    consumeOxygen()
                    enemyAttack()
                end
            }
        },
        shop = {
            {
                text = "Return to Depths",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 80,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function() 
                    currentGameState = GameState.EXPLORE
                end
            },
            {
                text = "Reroll Shop (20 " .. CURRENCY_NAME .. ")",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 440,
                baseWidth = 210,
                baseHeight = 50,
                width = 210,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function()
                    if player.currency >= 20 then
                        player.currency = player.currency - 20
                        generateShopItems()
                        addToCombatLog("Shop items rerolled for 20 " .. CURRENCY_NAME .. "!")
                    else
                        addToCombatLog("Not enough " .. CURRENCY_NAME .. " to reroll shop!")
                    end
                end
            }
        },
        inventory = {
            {
                text = "Return",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT - 60,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function() 
                    if currentGameState == GameState.INVENTORY then
                        -- Return to the previous state
                        if currentEnemy and currentEnemy.health ~= 0 then
                            currentGameState = GameState.COMBAT
                        else
                            currentGameState = GameState.EXPLORE
                        end
                    end
                end
            }
        },
        gameOver = {
            {
                text = "Try Again",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT / 2 + 25,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function() 
                    currentGameState = GameState.TITLE
                    initializePlayer()
                    initializeEnemies()
                    initializeShop()
                    clearCombatLog()
                end
            },
            {
                text = "Quit",
                x = GAME_WIDTH / 2 - 100,
                y = GAME_HEIGHT / 2 + 100,
                baseWidth = 200,
                baseHeight = 50,
                width = 200,
                height = 50,
                hover = false,
                pressed = false,
                animating = false,
                animTimer = 0,
                pulse = 0,
                holdable = true,
                holdDelay = 0.2,
                holdTimer = 0,         
                action = function() 
                    love.event.quit()
                end
            }
        }
    }
end

-- Initialize shaders
function initializeShaders()
    shaders = {
        swirl = love.graphics.newShader[[
            #define PI 3.14159265359
            #define BLUE1 1.0
            #define BLUE2 0.7
            #define BLUE3 0.4
            #define SINE1 1.0
            #define SINE2 1.2
            #define SINE3 0.5
            #define MOD1 0.1
            #define MOD2 0.3
            #define MOD3 0.2

            extern number iTime;
            extern number dayOfWeek;

            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec2 screenSize = love_ScreenSize.xy;
                vec2 uv = (screen_coords - 0.5 * screenSize) / length(screenSize);
                float uv_len = length(uv);
                
                float day = mod(dayOfWeek, 7.0);
                
                if(day < 1.0) {
                    float speed = mod(iTime * 0.4, PI * 2.0);
                    float new_pixel_angle = atan(uv.y, uv.x) + speed - 20.0 * (0.25 * uv_len + 0.75);
                    vec2 mid = (screenSize / length(screenSize)) / 2.0;
                    uv = (vec2(uv_len * cos(new_pixel_angle) + mid.x, uv_len * sin(new_pixel_angle) + mid.y) - mid);
                }
                else if(day < 2.0) {
                    float angle = iTime + uv_len * 5.0;
                    uv = vec2(uv.x * cos(angle) - uv.y * sin(angle),
                            uv.x * sin(angle) + uv.y * cos(angle));
                    uv += 0.1 * vec2(sin(uv.y * 15.0 + iTime),
                                    cos(uv.x * 15.0 + iTime));
                }
                else if(day < 3.0) {
                    uv += 0.05 * vec2(sin(uv.y * 20.0 + iTime),
                                    cos(uv.x * 20.0 + iTime));
                }
                else if(day < 4.0) {
                    vec2 originalUV = uv;
                    for (int i = 0; i < 7; i++) {
                        uv += 0.1 * vec2(sin(uv.y * 10.0 + iTime * 0.5 + float(i)),
                                        cos(uv.x * 10.0 + iTime * 0.5 + float(i)));
                        uv *= 1.1;
                    }
                    uv = mix(uv, originalUV, 0.5);
                }
                else if(day < 5.0) {
                    float jitter = 0.2 * sin(uv_len * 20.0 - iTime); // Fixed line 49
                    float a = atan(uv.y, uv.x);
                    uv += jitter * vec2(cos(a), sin(a));
                }
                else if(day < 6.0) {
                    float n = sin(dot(uv, vec2(12.9898, 78.233)) + iTime * 3.0);
                    uv += 0.03 * vec2(n, cos(dot(uv, vec2(12.9898, 78.233)) + iTime * 3.0));
                }
                else {
                    uv = fract(uv * 2.0 * (sin(iTime * 0.7 + 0.2) + 2.0) + (iTime * 0.25)) - 0.5;
                    uv *= 1.5;
                }
                
                vec2 uv_loop = uv * 30.0; // Fixed variable name casing
                float speed = iTime * 7.0;
                vec2 uv2 = vec2(uv_loop.x + uv_loop.y);

                for (int i = 0; i < 5; i++) {
                    uv2 += sin(max(uv_loop.x, uv_loop.y)) + uv_loop;
                    uv_loop += 0.5 * vec2(
                        cos(5.1123314 + 0.353 * uv2.y + speed * 0.131121),
                        sin(uv2.x - 0.113 * speed)
                    );
                    uv_loop -= cos(uv_loop.x + uv_loop.y) - sin(uv_loop.x * 0.711 - uv_loop.y);
                }

                float paint_res = min(2.0, max(0.0, length(uv_loop) * 0.077));
                float c1p = max(0.0, 1.0 - 2.2 * abs(1.0 - paint_res));
                float c2p = max(0.0, 1.0 - 2.2 * abs(paint_res));
                float c3p = 1.0 - min(1.0, c1p + c2p);
                float light = 0.2 * max(c1p * 5.0 - 4.0, 0.0) + 0.4 * max(c2p * 5.0 - 4.0, 0.0);
                
                vec4 blue1 = vec4(0.0, 0.0, BLUE1 + MOD1 * sin(iTime + SINE1), 1.0);
                vec4 blue2 = vec4(0.0, 0.0, BLUE2 + MOD2 * sin(iTime + SINE2), 1.0);
                vec4 blue3 = vec4(0.0, 0.0, BLUE3 + MOD3 * sin(iTime + SINE3), 1.0);
                
                return (0.3 / 3.5) * blue1
                    + (1.0 - 0.3 / 3.5) * (blue1 * c1p + blue2 * c2p + vec4(0.0, 0.0, c3p * blue3.b, c3p * blue1.a))
                    + vec4(0.0, 0.0, light, 0.0);
            }
        ]],
    
        titleShader = love.graphics.newShader[[
            float random(in vec2 st) {
                return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
            }
    
            float noise(in vec2 st) {
                vec2 i = floor(st);
                vec2 f = fract(st);
    
                float a = random(i);
                float b = random(i + vec2(1.0, 0.0));
                float c = random(i + vec2(0.0, 1.0));
                float d = random(i + vec2(1.0, 1.0));
    
                vec2 u = f * f * (3.0 - 2.0 * f);
    
                return mix(a, b, u.x) +
                    (c - a) * u.y * (1.0 - u.x) +
                    (d - b) * u.x * u.y;
            }
    
            extern float love_Time;
    
            vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
                float t = love_Time / 10.;
                
                vec2 p = 100. * screen_coords / love_ScreenSize.xy;
                float y = p.y / 100.;
                p.y += sin(2. * t);
                p.x += cos(5. * t);
                p *= mat2(sin(t / 2.), -cos(t / 2.), cos(t / 2.), sin(t / 2.)) / 8.;
    
                vec4 fragColor = vec4(0.0);
                for (float i = 0.; i < 8.; i++) {
                    fragColor = cos(p.xxxx * .3) * .5 + .5;
                    float n = noise(p / 5.);
                    fragColor *= n;
                    p.x += sin(p.y + love_Time * .3 + i);
                    p *= mat2(6, -8, 8, 6) / 8.;
                }
    
                fragColor *= 1. - smoothstep(0., .91, y);
                fragColor *= vec4(0.2, 0.23, 0.54, 1.0);
                return fragColor * color;
            }
        ]],
    
        background = love.graphics.newShader[[
            #define SPIN_ROTATION -2.0
            #define SPIN_SPEED 7.0
            #define OFFSET vec2(0.0)
            #define COLOUR_1 vec4(0.2, 0.5, 0.9, 1.0)    // Medium vibrant blue
            #define COLOUR_2 vec4(0.3, 0.7, 1.0, 1.0)    // Lighter cyan-blue
            #define COLOUR_3 vec4(0.1, 0.3, 0.7, 1.0)    // Darker rich blue
            #define CONTRAST 3.5
            #define LIGTHING 0.4
            #define SPIN_AMOUNT 0.25
            #define PIXEL_FILTER 745.0
            #define SPIN_EASE 1.0
            #define PI 3.14159265359
            #define IS_ROTATE false

            extern number iTime;

            vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
                vec2 screenSize = love_ScreenSize.xy;
                float pixel_size = length(screenSize.xy) / PIXEL_FILTER;
                vec2 uv = (floor(screen_coords.xy * (1.0 / pixel_size)) * pixel_size - 0.5 * screenSize.xy) / length(screenSize.xy) - OFFSET;
                float uv_len = length(uv);
                
                float speed = (SPIN_ROTATION * SPIN_EASE * 0.2);
                if (IS_ROTATE) {
                    speed = iTime * speed;
                }
                speed += 302.2;
                float new_pixel_angle = atan(uv.y, uv.x) + speed - SPIN_EASE * 20.0 * (1.0 * SPIN_AMOUNT * uv_len + (1.0 - 1.0 * SPIN_AMOUNT));
                vec2 mid = (screenSize.xy / length(screenSize.xy)) / 2.0;
                uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);
                
                uv *= 30.0;
                speed = iTime * (SPIN_SPEED);
                vec2 uv2 = vec2(uv.x + uv.y);
                
                for (int i = 0; i < 5; i++) {
                    uv2 += sin(max(uv.x, uv.y)) + uv;
                    uv += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + speed * 0.131121), sin(uv2.x - 0.113 * speed));
                    uv -= 1.0 * cos(uv.x + uv.y) - 1.0 * sin(uv.x * 0.711 - uv.y);
                }
                
                float contrast_mod = (0.25 * CONTRAST + 0.5 * SPIN_AMOUNT + 1.2);
                float paint_res = min(2.0, max(0.0, length(uv) * (0.035) * contrast_mod));
                float c1p = max(0.0, 1.0 - contrast_mod * abs(1.0 - paint_res));
                float c2p = max(0.0, 1.0 - contrast_mod * abs(paint_res));
                float c3p = 1.0 - min(1.0, c1p + c2p);
                float light = (LIGTHING - 0.2) * max(c1p * 5.0 - 4.0, 0.0) + LIGTHING * max(c2p * 5.0 - 4.0, 0.0);
                return (0.3 / CONTRAST) * COLOUR_1 + (1.0 - 0.3 / CONTRAST) * (COLOUR_1 * c1p + COLOUR_2 * c2p + vec4(c3p * COLOUR_3.rgb, c3p * COLOUR_1.a)) + light;
            }
        ]],

        fight = love.graphics.newShader[[
            #define SPIN_ROTATION -2.0
            #define SPIN_SPEED 7.0
            #define OFFSET vec2(0.0)
            #define COLOUR_1 vec4(0.05, 0.15, 0.35, 1.0)  // Dark deep ocean blue
            #define COLOUR_2 vec4(0.1, 0.25, 0.5, 1.0)    // Slightly lighter deep blue
            #define COLOUR_3 vec4(0.03, 0.1, 0.25, 1.0)   // Even darker blue for depth
            #define CONTRAST 3.5
            #define LIGHTING 0.4
            #define SPIN_AMOUNT 0.25
            #define PIXEL_FILTER 745.0
            #define SPIN_EASE 1.0
            #define PI 3.14159265359
            #define IS_ROTATE true

            extern float iTime;

            float hash1D(vec2 x)
            {
                vec2 q = floor(x * 65536.0);
                vec2 q_shifted = floor(q / 2.0);
                vec2 q_mixed = mod(q_shifted + q.yx, 65536.0);
                q = mod(1103515245.0 * q_mixed, 65536.0);
                float n = mod(1103515245.0 * (q.x + floor(q.y / 8.0)), 65536.0);
                return n / 65536.0;
            }

            float noise(vec2 uv)
            {
                vec2 i = floor(uv);
                vec2 f = fract(uv);
                float a = hash1D(i);
                float b = hash1D(i + vec2(1.0, 0.0));
                float c = hash1D(i + vec2(0.0, 1.0));
                float d = hash1D(i + vec2(1.0, 1.0));
                vec2 u = f * f * (3.0 - 2.0 * f);
                return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
            }

            vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
            {
                vec2 screenSize = love_ScreenSize.xy;
                float pixel_size = length(screenSize.xy) / PIXEL_FILTER;
                vec2 uv = (floor(screen_coords.xy * (1.0 / pixel_size)) * pixel_size - 0.5 * screenSize.xy) / length(screenSize.xy) - OFFSET;
                float uv_len = length(uv);
                
                float speed = (SPIN_ROTATION * SPIN_EASE * 0.2);
                if (IS_ROTATE) {
                    speed = iTime * speed;
                }
                speed += 302.2;
                float new_pixel_angle = atan(uv.y, uv.x) + speed - SPIN_EASE * 20.0 * (1.0 * SPIN_AMOUNT * uv_len + (1.0 - 1.0 * SPIN_AMOUNT));
                vec2 mid = (screenSize.xy / length(screenSize.xy)) / 2.0;
                uv = vec2(uv_len * cos(new_pixel_angle) + mid.x, uv_len * sin(new_pixel_angle) + mid.y) - mid;
                
                uv *= 30.0;
                speed = iTime * SPIN_SPEED;
                vec2 uv2 = vec2(uv.x + uv.y);
                
                for (int i = 0; i < 5; i++) {
                    uv2 += sin(max(uv.x, uv.y)) + uv;
                    uv += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + speed * 0.131121), sin(uv2.x - 0.113 * speed));
                    uv -= 1.0 * cos(uv.x + uv.y) - 1.0 * sin(uv.x * 0.711 - uv.y);
                }
                
                float contrast_mod = (0.25 * CONTRAST + 0.5 * SPIN_AMOUNT + 1.2);
                float paint_res = min(2.0, max(0.0, length(uv) * 0.035 * contrast_mod));
                float c1p = max(0.0, 1.0 - contrast_mod * abs(1.0 - paint_res));
                float c2p = max(0.0, 1.0 - contrast_mod * abs(paint_res));
                float c3p = 1.0 - min(1.0, c1p + c2p);
                float light = (LIGHTING - 0.2) * max(c1p * 5.0 - 4.0, 0.0) + LIGHTING * max(c2p * 5.0 - 4.0, 0.0);
                
                vec4 fragColor = (0.3 / CONTRAST) * COLOUR_1 + (1.0 - 0.3 / CONTRAST) * (COLOUR_1 * c1p + COLOUR_2 * c2p + vec4(c3p * COLOUR_3.rgb, c3p * COLOUR_1.a)) + light;
                
                // Add subtle noise overlay for texture
                float noise_val = noise(uv * 10.0 + iTime * 0.1);
                fragColor.rgb += vec3(0.02, 0.04, 0.06) * noise_val;
                
                return fragColor * color;
            }
        ]],

        crt = love.graphics.newShader[[
            extern number time; // For flicker and noise animation
            extern vec2 resolution; // Screen resolution

            // Noise function for subtle interference
            float noise(vec2 p) {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }

            vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
                vec2 uv = screen_coords / resolution;

                // Screen curvature (barrel distortion)
                vec2 center = vec2(0.5, 0.5);
                vec2 offset = uv - center;
                float dist = length(offset);
                float curvature = 0.007; // Adjust curvature strength
                uv = center + offset * (1.0 + curvature * dist * dist);

                // Clamp UVs to avoid sampling outside texture
                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
                    return vec4(0.0, 0.0, 0.0, 1.0); // Black outside screen
                }

                // Sample texture with slight RGB separation
                vec4 texColor;
                float offsetAmount = 0.002; // Adjust for phosphor separation
                texColor.r = Texel(texture, uv + vec2(offsetAmount, 0.0)).r;
                texColor.g = Texel(texture, uv).g;
                texColor.b = Texel(texture, uv - vec2(offsetAmount, 0.0)).b;
                texColor.a = 1.0;

                // Scanlines
                float scanline = sin(uv.y * resolution.y * 1.5) * 0.05; // Adjust frequency and intensity
                texColor.rgb -= scanline;

                // Noise/flicker
                float noiseVal = noise(screen_coords + vec2(time * 10.0, 0.0)) * 0.03; // Subtle noise
                texColor.rgb += noiseVal;

                // Vignette effect
                float vignette = smoothstep(0.9, 0.2, dist);
                texColor.rgb *= vignette;

                return texColor * color;
            }
        ]],

        lost = love.graphics.newShader[[
            extern number time;
            extern vec2 resolution;

            float random (in vec2 st) {
                return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
            }

            float noise (in vec2 st) {
                vec2 i = floor(st);
                vec2 f = fract(st);
                float a = random(i);
                float b = random(i + vec2(1.0, 0.0));
                float c = random(i + vec2(0.0, 1.0));
                float d = random(i + vec2(1.0, 1.0));
                vec2 u = f * f * (3.0 - 2.0 * f);
                return mix(a, b, u.x) +
                       (c - a) * u.y * (1.0 - u.x) +
                       (d - b) * u.x * u.y;
            }

            vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
                float t = time / 10.0;
                vec2 p = 100.0 * screen_coords / resolution;
                float y = p.y / 100.0;
                p.y += sin(2.0 * t);
                p.x += cos(5.0 * t);
                p *= mat2(sin(t / 2.0), -cos(t / 2.0), cos(t / 2.0), sin(t / 2.0)) / 8.0;

                vec4 fragColor = vec4(0.0);
                for (float i = 0.0; i < 8.0; i += 1.0) {
                    fragColor = cos(p.xxxx * 0.3) * 0.5 + 0.5;
                    float n = noise(p / 5.0);
                    fragColor *= n;
                    p.x += sin(p.y + time * 0.3 + i);
                    p *= mat2(6.0, -8.0, 8.0, 6.0) / 8.0;
                }

                fragColor *= 1.0 - smoothstep(0.0, 0.91, y);
                fragColor *= vec4(0.2, 0.23, 0.54, 1.0);
                return fragColor * color;
            }
        ]],
        
    }
    shaders.swirl:send("iTime", 0.0)
    shaders.swirl:send("dayOfWeek", 0.0)
    shaders.background:send("iTime", 0.0)
    shaders.fight:send("iTime", 0.0)
    shaders.crt:send("time", 0.0)
    shaders.crt:send("resolution", {GAME_WIDTH, GAME_HEIGHT})
    shaders.lost:send("time", 0.0)
    shaders.lost:send("resolution", {GAME_WIDTH, GAME_HEIGHT})
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
    
    currentGameState = GameState.COMBAT
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
    if (currentGameState == GameState.INVENTORY or currentGameState == GameState.COMBAT) and item.combatUse then
        -- Use the item
        local skipEnemyTurn = item.effect()
        
        -- Remove the item after use
        table.remove(player.inventory, index)
        
        -- Return to combat
        currentGameState = GameState.COMBAT
        
    elseif (currentGameState ~= GameState.INVENTORY or currentGameState ~= GameState.COMBAT) and not item.combatUse then
        -- Use non-combat item outside of combat
        item.effect()
        
        -- Remove the item after use
        table.remove(player.inventory, index)
        
        -- Return to explore mode
        currentGameState = GameState.EXPLORE
    else
        -- Cannot use this item in current context
        if currentGameState == GameState.COMBAT then
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
            currentGameState = GameState.EXPLORE
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
            currentGameState = GameState.EXPLORE
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
    -- Calculate run success chance
    local runChance = calculateRunChance(player.luck)
    if math.random(100) <= runChance then
        -- Successful run
        addToCombatLog("You successfully fled from the " .. currentEnemy.name .. "!")
        currentGameState = GameState.EXPLORE
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
    end
    
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
        currentGameState = GameState.GAME_OVER
    end
    
    if player.oxygen <= 0 then
        addToCombatLog("You ran out of oxygen!")
        currentGameState = GameState.GAME_OVER
    end
end

-- Consume oxygen based on depth
function consumeOxygen()
    if currentCombatState == CombatState.REFILL_OXYGEN then
        player.oxygen = math.min(MAX_OXYGEN, player.oxygen + 15)
    end

    if currentCombatState ~= nil and currentCombatState ~= CombatState.REFILL_OXYGEN then
        player.oxygen = math.max(0, player.oxygen - (1.5 * OXY_DEPL_MULT))
    end

    if player.oxygen <= 0 then
        checkPlayerStatus()
    end

    currentCombatState = nil
end

function updateButtons(dt)
    local mx, my = love.mouse.getPosition()
    
    local currentButtons = {}
    if currentGameState == GameState.TITLE then
        currentButtons = buttons.title
    elseif currentGameState == GameState.EXPLORE then
        currentButtons = buttons.explore
    elseif currentGameState == GameState.COMBAT then
        currentButtons = buttons.combat
    elseif currentGameState == GameState.SHOP then
        currentButtons = buttons.shop
    elseif currentGameState == GameState.INVENTORY then
        currentButtons = buttons.inventory
    elseif currentGameState == GameState.GAME_OVER then
        currentButtons = buttons.gameOver
    elseif currentGameState == GameState.PAUSE then
        currentButtons = buttons.pause
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
        
        local targetWidth = button.baseWidth
        local targetHeight = button.baseHeight
        if button.pressed then
            targetWidth = button.baseWidth * 0.9
            targetHeight = button.baseHeight * 0.9
        end
        
        button.width = button.width + (targetWidth - button.width) * dt * 10
        button.height = button.height + (targetHeight - button.height) * dt * 10
        
        if button.animating then
            button.animTimer = button.animTimer + dt
            if button.animTimer >= 0.1 then
                button.animTimer = 0
                button.animating = false -- Reset animation after completion
            end
        end
        
        -- Handle holdable buttons
        if button.holdable and button.pressed then
            button.holdTimer = button.holdTimer + dt
            if button.holdTimer >= button.holdDelay then
                button.holdTimer = 0
            end
        else
            button.holdTimer = 0
        end
    end
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
    --[[love.graphics.setColor(0.5, 0.2, 0.2)
    love.graphics.rectangle("fill", GAME_WIDTH - 220, 50, 200, 20)
    love.graphics.setColor(1.0, 0.4, 0.4)
    love.graphics.rectangle("fill", GAME_WIDTH - 220, 50, (player.pressure / MAX_PRESSURE) * 200, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", GAME_WIDTH - 220, 50, 200, 20)
    love.graphics.print("Pressure: " .. math.floor(player.pressure) .. "%", GAME_WIDTH - 210, 52)
    ]]
end

-- Draw buttons (new function)
function drawButtons()
    local currentButtons = {}
    if currentGameState == GameState.TITLE then
        currentButtons = buttons.title
    elseif currentGameState == GameState.EXPLORE then
        currentButtons = buttons.explore
    elseif currentGameState == GameState.COMBAT then
        currentButtons = buttons.combat
    elseif currentGameState == GameState.SHOP then
        currentButtons = buttons.shop
    elseif currentGameState == GameState.INVENTORY then
        currentButtons = buttons.inventory
    elseif currentGameState == GameState.GAME_OVER then
        currentButtons = buttons.gameOver
    elseif currentGameState == GameState.PAUSE then
        currentButtons = buttons.pause
    end
    
    for _, button in ipairs(currentButtons) do
        -- Button background color
        if button.pressed then
            love.graphics.setColor(0.3, 0.5, 0.8, 0.8)  -- Pressed state
        elseif button.hover then
            love.graphics.setColor(0.2, 0.4, 0.7, 0.8)  -- Hover state
        else
            love.graphics.setColor(0.2, 0.3, 0.6, 0.7)  -- Normal state
        end
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Button border
        love.graphics.setColor(0.5, 0.7, 1.0, button.hover and 1.0 or 0.7)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Button text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts.medium)
        local textWidth = fonts.medium:getWidth(button.text)
        local textHeight = fonts.medium:getHeight()
        love.graphics.print(button.text, 
            button.x + (button.width - textWidth) / 2, 
            button.y + (button.height - textHeight) / 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1)  -- Reset color
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
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Deep Sea Shop", 0, 70, GAME_WIDTH, "center")
    
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(CURRENCY_NAME .. ": " .. player.currency, 0, 120, GAME_WIDTH, "center")
    
    local itemsPerRow = 3
    local itemWidth = 200
    local itemHeight = 120
    local startX = (GAME_WIDTH - (itemWidth * itemsPerRow + 20 * (itemsPerRow - 1))) / 2
    local startY = GAME_HEIGHT - 370
    
    for i, item in ipairs(shopInventory) do
        local row = math.floor((i - 1) / itemsPerRow)
        local col = (i - 1) % itemsPerRow
        
        local x = startX + col * (itemWidth + 20) + 10
        local y = startY + row * (itemHeight + 20) + 5
        
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
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Inventory", 0, 50, GAME_WIDTH, "center")
    
    if #player.inventory == 0 then
        love.graphics.setFont(fonts.medium)
        love.graphics.setColor(1, 1, 1, 1)
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
            if currentGameState == GameState.COMBAT then
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
        local canUse = (currentGameState == GameState.COMBAT and item.combatUse) or
                       (currentGameState ~= GameState.COMBAT and not item.combatUse)
        
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
    -- Title text
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.5, 0.7, 1.0, 1.0)
    love.graphics.printf("Ocean Depths", 0, GAME_HEIGHT / 7, GAME_WIDTH, "center")
    
    -- Subtitle
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.7, 0.8, 1.0, 0.8)
    love.graphics.printf("A Deep Sea Adventure", 0, GAME_HEIGHT / 6 + 70, GAME_WIDTH, "center")
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw game over screen
function drawGameOver()
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 0.3, 0.3, 1)
    love.graphics.printf("Game Over", 0, GAME_HEIGHT / 4, GAME_WIDTH, "center")
    
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("You reached a depth of " .. player.maxDepth .. " meters", 0, GAME_HEIGHT / 4 + 100, GAME_WIDTH, "center")
    
    love.graphics.setColor(1, 1, 1, 1)
end

local lastGameTime = 0

-- Main update function
function love.update(dt)
    day = tonumber(os.date("%w"))
    
    -- Only update if not paused
    if currentGameState ~= GameState.PAUSE then
        gameTime = gameTime + dt
        
        -- Update shaders
        if shaders.water then
            shaders.water:send("time", gameTime)
            shaders.water:send("depth", player.depth / 1000)
        end
        if shaders.swirl then
            shaders.swirl:send("iTime", gameTime)
            shaders.swirl:send("dayOfWeek", day)
        end
        if shaders.titleShader then
            shaders.titleShader:send("love_Time", love.timer.getTime())
        end
        if shaders.background then
            shaders.background:send("iTime", gameTime)
        end
        if shaders.fight then
            shaders.fight:send("iTime", gameTime)
        end
        if shaders.crt then
            shaders.crt:send("time", gameTime)
        end
        if shaders.lost then
            shaders.lost:send("time", gameTime)
        end
        
        updateButtons(dt)
        if currentGameState == GameState.COMBAT then
            consumeOxygen()
        end
        if currentEnemy then
            currentEnemy.animTime = (currentEnemy.animTime or 0) + dt
        end
    else
        -- When paused, use the last game time for shaders to freeze them
        if shaders.water then
            shaders.water:send("time", lastGameTime)
            shaders.water:send("depth", player.depth / 1000)
        end
        if shaders.swirl then
            shaders.swirl:send("iTime", lastGameTime)
            shaders.swirl:send("dayOfWeek", day)
        end
        if shaders.titleShader then
            shaders.titleShader:send("love_Time", lastGameTime)
        end
        if shaders.background then
            shaders.background:send("iTime", lastGameTime)
        end
        if shaders.fight then
            shaders.fight:send("iTime", lastGameTime)
        end
        if shaders.crt then
            shaders.crt:send("time", lastGameTime)
        end
        if shaders.lost then
            shaders.lost:send("time", lastGameTime)
        end
        
        updateButtons(dt)  -- Still update buttons so the pause menu is interactive
    end
    
    -- Store the last game time before pausing
    if currentGameState ~= GameState.PAUSE then
        lastGameTime = gameTime
    end
end
-- Mouse press handler
function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    local currentButtons = {}
    if currentGameState == GameState.TITLE then
        currentButtons = buttons.title
    elseif currentGameState == GameState.EXPLORE then
        currentButtons = buttons.explore
    elseif currentGameState == GameState.COMBAT then
        currentButtons = buttons.combat
    elseif currentGameState == GameState.SHOP then
        currentButtons = buttons.shop
    elseif currentGameState == GameState.INVENTORY then
        currentButtons = buttons.inventory
    elseif currentGameState == GameState.GAME_OVER then
        currentButtons = buttons.gameOver
    end
    
    -- Check button clicks
    for _, btn in ipairs(currentButtons) do
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            btn.pressed = true
            btn.animating = true
            btn.animTimer = 0
            return
        end
    end
    
    -- Shop item click
    if currentGameState == GameState.SHOP then
        local itemsPerRow = 3
        local itemWidth = 200
        local itemHeight = 120
        local startX = (GAME_WIDTH - (itemWidth * itemsPerRow + 20 * (itemsPerRow - 1))) / 2 + 10 -- Match drawShop()
        local startY = GAME_HEIGHT - 370 -- Match drawShop()
        
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
    if currentGameState == GameState.INVENTORY then
        local itemsPerRow = 4
        local itemWidth = 150
        local itemHeight = 100
        local startX = (GAME_WIDTH - (itemWidth * itemsPerRow + 20 * (itemsPerRow - 1))) / 2
        local startY = 150
        
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

function love.mousereleased(x, y, button)
    if button ~= 1 then return end
    
    local currentButtons = {}
    if currentGameState == GameState.TITLE then
        currentButtons = buttons.title
    elseif currentGameState == GameState.EXPLORE then
        currentButtons = buttons.explore
    elseif currentGameState == GameState.COMBAT then
        currentButtons = buttons.combat
    elseif currentGameState == GameState.SHOP then
        currentButtons = buttons.shop
    elseif currentGameState == GameState.INVENTORY then
        currentButtons = buttons.inventory
    elseif currentGameState == GameState.GAME_OVER then
        currentButtons = buttons.gameOver
    elseif currentGameState == GameState.PAUSE then
        currentButtons = buttons.pause 
    end
    
    for _, btn in ipairs(currentButtons) do
        if btn.pressed and x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            btn.pressed = false
            btn.animating = false
            btn.action()
        else
            btn.pressed = false
            btn.animating = false
        end
    end
end

function love.keypressed(key)
    if key == "escape" and currentGameState == GameState.COMBAT then
        currentGameState = GameState.PAUSE
    elseif key == "escape" and currentGameState == GameState.PAUSE then
        currentGameState = GameState.COMBAT  -- Allow Escape to unpause too
    end

    if key == "r" and currentGameState == GameState.COMBAT then
        runFromCombat()
    end
end

function drawPause()
    -- Draw a semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
    
    -- Draw pause text
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Paused", 0, GAME_HEIGHT / 2 - 75, GAME_WIDTH, "center")
    
    love.graphics.setColor(1, 1, 1, 1)
end

function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear()

    if currentGameState == GameState.TITLE then
        love.graphics.setShader(shaders.background)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        love.graphics.setShader()
        drawTitle()
    elseif currentGameState == GameState.EXPLORE then
        love.graphics.setShader(shaders.fight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        love.graphics.setShader()
        love.graphics.setFont(fonts.large)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf("Depth: " .. player.depth .. "m", 0, 50, GAME_WIDTH, "center")
        drawPlayerStats()
    elseif currentGameState == GameState.COMBAT then
        love.graphics.setShader(shaders.fight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        love.graphics.setShader()
        drawEnemy()
        drawPlayerStats()
        drawCombatLog()
    elseif currentGameState == GameState.SHOP then
        love.graphics.setShader(shaders.swirl)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        love.graphics.setShader()
        drawShop()
        drawPlayerStats()
    elseif currentGameState == GameState.INVENTORY then
        love.graphics.setShader(shaders.swirl)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        love.graphics.setShader()
        drawInventory()
        drawPlayerStats()
    elseif currentGameState == GameState.GAME_OVER then
        love.graphics.setShader(shaders.lost)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        love.graphics.setShader()
        drawGameOver()
    elseif currentGameState == GameState.PAUSE then
        -- Draw the combat scene frozen
        love.graphics.setShader(shaders.fight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        love.graphics.setShader()
        drawEnemy()
        drawPlayerStats()
        drawCombatLog()
        drawButtons()
        drawPause()
    end

    drawButtons()

    love.graphics.setCanvas()
    love.graphics.setShader(shaders.crt)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setShader()
end
