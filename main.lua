-- The Depths: A Balatro-inspired Card Game
-- Theme: Deep ocean depths with mysterious creatures and treasures
-- Framework: LÖVE2D (Love2D)

-- Require necessary libraries
local anim8 = {} -- Animation library (simulated for this example)

-- Constants
local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local CARD_WIDTH = 120
local CARD_HEIGHT = 180
local HAND_SIZE = 5
local MAX_ENERGY = 3

-- Game states
local STATE = {
    TITLE = "title",
    PLAY = "play",
    SHOP = "shop",
    MAP = "map",
    REWARD = "reward",
    GAME_OVER = "game_over"
}

-- Card types
local CARD_TYPE = {
    ATTACK = "attack",
    DEFENSE = "defense",
    UTILITY = "utility",
    CREATURE = "creature",
    TREASURE = "treasure"
}

-- Rarity types with associated colors
local RARITY = {
    COMMON = {name = "Common", color = {1, 1, 1}},
    UNCOMMON = {name = "Uncommon", color = {0.2, 0.8, 0.2}},
    RARE = {name = "Rare", color = {0.2, 0.2, 0.9}},
    EPIC = {name = "Epic", color = {0.8, 0.2, 0.8}},
    LEGENDARY = {name = "Legendary", color = {1, 0.8, 0}},
    ABYSSAL = {name = "Abyssal", color = {0.1, 0.1, 0.3}} -- Special rarity for this theme
}

-- Game state variables
local gameState = STATE.TITLE
local playerHand = {}
local drawPile = {}
local discardPile = {}
local currentEnergy = MAX_ENERGY
local player = {
    health = 50,
    maxHealth = 50,
    gold = 0,
    depth = 0,
    oxygen = 100,
    maxOxygen = 100,
    block = 0,
    pressure = 0,
    treasures = {}
}
local currentEnemy = nil
local enemies = {}
local deck = {}
local effects = {}
local shopItems = {}
local animations = {}
local particles = {}
local shake = {amount = 0, duration = 0}
local uiElements = {}
local tooltipText = nil
local tooltipCard = nil
local cardBeingDragged = nil
local nextEncounter = nil
local treasures = {}
local cardBlueprints = {}
local enemyBlueprints = {}
local bossBlueprints = {}
local treasureBlueprints = {}
local mapNodes = {}
local currentMapNode = nil
local firstAttackPlayed = false
local turnCount = 0

-- Status effects
local STATUS = {
    ILLUMINATED = {name = "Illuminated", color = {1, 1, 0.5}, description = "Takes more damage from certain attacks"},
    INK = {name = "Ink", color = {0.2, 0.2, 0.2}, description = "Reduces accuracy of attacks"},
    PRESSURE = {name = "Pressure", color = {0.5, 0.2, 0.8}, description = "Increases damage taken"},
    POISON = {name = "Poison", color = {0.2, 0.8, 0.2}, description = "Takes damage over time"}
}

-- Assets
local assets = {
    images = {},
    fonts = {},
    sounds = {},
    music = {},
    particles = {}
}

-- Load assets
function loadAssets()
    -- In a real implementation, we would load actual assets
    assets.fonts.title = love.graphics.newFont(48)
    assets.fonts.large = love.graphics.newFont(32)
    assets.fonts.medium = love.graphics.newFont(24)
    assets.fonts.small = love.graphics.newFont(16)
    
    -- Initialize card back "image" with a function to draw it
    assets.images.cardBack = function(x, y, width, height)
        love.graphics.setColor(0.1, 0.2, 0.4)
        love.graphics.rectangle("fill", x, y, width, height, 10, 10)
        love.graphics.setColor(0.05, 0.1, 0.2)
        love.graphics.rectangle("fill", x + 10, y + 10, width - 20, height - 20, 5, 5)
        love.graphics.setColor(0, 0.5, 0.8, 0.3)
        for i = 1, 5 do
            love.graphics.circle("fill", x + math.random(width), y + math.random(height), math.random(1, 5))
        end
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Initialize particle systems
    assets.particles.bubbles = function()
        local system = love.graphics.newParticleSystem(createBubbleCanvas(), 100)
        system:setParticleLifetime(2, 5)
        system:setEmissionRate(10)
        system:setSizeVariation(0.5)
        system:setLinearAcceleration(0, -20, 0, -40)
        system:setColors(1, 1, 1, 0.8, 1, 1, 1, 0)
        return system
    end
    
    -- Initialize sounds (would be loaded from files in a real game)
    assets.sounds.cardPlace = {play = function() end}
    assets.sounds.damage = {play = function() end}
    assets.sounds.heal = {play = function() end}
    assets.sounds.treasure = {play = function() end}
    
    -- Initialize music (would be loaded from files in a real game)
    assets.music.main = {play = function() end}
end

-- Create a canvas for a bubble particle
function createBubbleCanvas()
    local canvas = love.graphics.newCanvas(10, 10)
    love.graphics.setCanvas(canvas)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", 5, 5, 4)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.circle("line", 5, 5, 4)
    love.graphics.setCanvas()
    return canvas
end

-- Card Blueprint (used to create card instances)
local CardBlueprint = {}

function CardBlueprint:new(name, cardType, cost, rarity, description, effects, imageFn)
    local card = {
        name = name,
        cardType = cardType,
        cost = cost,
        rarity = rarity,
        description = description,
        effects = effects or {},
        imageFn = imageFn or function(x, y, w, h) 
            love.graphics.setColor(0.2, 0.4, 0.8)
            love.graphics.rectangle("fill", x, y, w, h, 10, 10)
            love.graphics.setColor(1, 1, 1)
        end,
        -- Card instance properties (set when a card is created)
        x = 0,
        y = 0,
        targetX = 0,
        targetY = 0,
        rotation = 0,
        targetRotation = 0,
        scale = 1,
        targetScale = 1,
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        isHovered = false,
        isSelected = false,
        modifiers = {},
        animations = {},
        id = love.math.random(1000000)
    }
    
    return card
end

-- Initialize all card blueprints
function initializeCardBlueprints()
    local allCards = {
        -- Attack cards
        CardBlueprint:new(
            "Trident Strike", 
            CARD_TYPE.ATTACK, 
            1, 
            RARITY.COMMON, 
            "Deal 6 damage.", 
            {
                {type = "damage", value = 6}
            },
            function(x, y, w, h)
                -- Draw a trident-themed card
                love.graphics.setColor(0.2, 0.4, 0.7)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                love.graphics.setColor(0.8, 0.8, 0.9)
                -- Draw trident icon
                love.graphics.rectangle("fill", x + w/2 - 5, y + h/3, 10, h/2)
                love.graphics.rectangle("fill", x + w/2 - 20, y + h/4, 10, h/6)
                love.graphics.rectangle("fill", x + w/2 + 10, y + h/4, 10, h/6)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Pressure Wave", 
            CARD_TYPE.ATTACK, 
            2, 
            RARITY.UNCOMMON, 
            "Deal 10 damage to all enemies.", 
            {
                {type = "aoe_damage", value = 10}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.1, 0.3, 0.6)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                love.graphics.setColor(0.7, 0.8, 1)
                -- Draw wave pattern
                for i = 1, 5 do
                    love.graphics.line(
                        x + 10, y + h/2 + math.sin(i/2) * 20,
                        x + w - 10, y + h/2 + math.sin(i/2 + 2) * 20
                    )
                end
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Abyssal Touch", 
            CARD_TYPE.ATTACK, 
            3, 
            RARITY.RARE, 
            "Deal 18 damage. Apply 2 Pressure.", 
            {
                {type = "damage", value = 18},
                {type = "apply_pressure", value = 2}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.05, 0.1, 0.3)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                love.graphics.setColor(0.4, 0, 0.5)
                love.graphics.circle("fill", x + w/2, y + h/2, w/4)
                love.graphics.setColor(0.6, 0.2, 0.8)
                love.graphics.circle("fill", x + w/2, y + h/2, w/6)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        -- Defense cards
        CardBlueprint:new(
            "Coral Shield", 
            CARD_TYPE.DEFENSE, 
            1, 
            RARITY.COMMON, 
            "Gain 5 Block.", 
            {
                {type = "block", value = 5}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.3, 0.6, 0.5)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                love.graphics.setColor(1, 0.5, 0.3)
                -- Draw coral pattern
                love.graphics.rectangle("fill", x + w/4, y + h/3, w/2, h/3, 5, 5)
                for i = 1, 5 do
                    love.graphics.rectangle("fill", 
                        x + w/4 + math.random(-10, 10), 
                        y + h/3 - math.random(10, 30), 
                        w/8, h/10, 2, 2)
                end
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Air Bubble", 
            CARD_TYPE.DEFENSE, 
            1, 
            RARITY.UNCOMMON, 
            "Gain 4 Block. Restore 3 Oxygen.", 
            {
                {type = "block", value = 4},
                {type = "oxygen", value = 3}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.2, 0.4, 0.6)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                love.graphics.setColor(0.9, 0.9, 1, 0.7)
                love.graphics.circle("fill", x + w/2, y + h/2, w/3)
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle("line", x + w/2, y + h/2, w/3)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Abyssal Refuge", 
            CARD_TYPE.DEFENSE, 
            2, 
            RARITY.RARE, 
            "Gain 12 Block. Reduce Pressure by 1.", 
            {
                {type = "block", value = 12},
                {type = "reduce_pressure", value = 1}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.1, 0.2, 0.4)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                love.graphics.setColor(0.2, 0.5, 0.7, 0.5)
                love.graphics.rectangle("fill", x + 10, y + 10, w - 20, h - 20, 5, 5)
                -- Draw dome/refuge
                love.graphics.setColor(0.3, 0.6, 0.8, 0.7)
                love.graphics.arc("fill", x + w/2, y + h/2 + h/8, w/2.5, math.pi, 0)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        -- Utility cards
        CardBlueprint:new(
            "Deep Exploration", 
            CARD_TYPE.UTILITY, 
            1, 
            RARITY.COMMON, 
            "Draw 2 cards.", 
            {
                {type = "draw", value = 2}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.2, 0.3, 0.5)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                love.graphics.setColor(0.6, 0.7, 0.8)
                -- Draw a map/compass
                love.graphics.circle("line", x + w/2, y + h/2, w/4)
                love.graphics.line(x + w/2, y + h/2, x + w/2, y + h/2 - w/5)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Luminescent Glow", 
            CARD_TYPE.UTILITY, 
            0, 
            RARITY.UNCOMMON, 
            "Apply 2 Illuminated to an enemy. Draw 1 card.", 
            {
                {type = "apply_illuminated", value = 2},
                {type = "draw", value = 1}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.2, 0.4, 0.5)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                -- Draw glowing effect
                for i = 1, 3 do
                    love.graphics.setColor(0.9, 0.9, 0.6, 0.7 - i*0.2)
                    love.graphics.circle("fill", x + w/2, y + h/2, w/3 + i*10)
                end
                love.graphics.setColor(1, 1, 0.8)
                love.graphics.circle("fill", x + w/2, y + h/2, w/5)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Treasure Hunter", 
            CARD_TYPE.UTILITY, 
            1, 
            RARITY.RARE, 
            "Gain 15 Gold. Shuffle a random Treasure into your draw pile.", 
            {
                {type = "gold", value = 15},
                {type = "add_treasure", value = 1}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.3, 0.25, 0.5)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                love.graphics.setColor(0.8, 0.7, 0.2)
                -- Draw treasure chest
                love.graphics.rectangle("fill", x + w/3, y + h/2, w/3, h/4)
                love.graphics.rectangle("fill", x + w/3, y + h/2, w/3, h/8)
                love.graphics.setColor(0.6, 0.5, 0.1)
                love.graphics.rectangle("line", x + w/3, y + h/2, w/3, h/4)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        -- Creature cards
        CardBlueprint:new(
            "Angler Fish", 
            CARD_TYPE.CREATURE, 
            2, 
            RARITY.UNCOMMON, 
            "Deal 8 damage. If the enemy is Illuminated, deal 4 more damage.", 
            {
                {type = "damage", value = 8},
                {type = "conditional_damage", condition = "illuminated", value = 4}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.1, 0.1, 0.2)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                -- Draw angler fish
                love.graphics.setColor(0.3, 0.3, 0.4)
                love.graphics.ellipse("fill", x + w/2, y + h/2, w/3, h/5)
                love.graphics.setColor(1, 1, 0.7)
                love.graphics.circle("fill", x + w/4, y + h/3, w/10)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Giant Squid", 
            CARD_TYPE.CREATURE, 
            3, 
            RARITY.RARE, 
            "Deal 3 damage 5 times. Apply 1 Ink.", 
            {
                {type = "multi_damage", value = 3, hits = 5},
                {type = "apply_ink", value = 1}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.2, 0.1, 0.3)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                -- Draw squid
                love.graphics.setColor(0.8, 0.3, 0.4)
                love.graphics.ellipse("fill", x + w/2, y + h/3, w/4, h/6)
                -- Draw tentacles
                for i = 1, 5 do
                    love.graphics.line(
                        x + w/2, y + h/3 + h/6,
                        x + w/2 + math.cos(i/2.5) * w/2, y + h/3 + h/6 + math.sin(i/2.5) * h/2
                    )
                end
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        -- Treasure cards
        CardBlueprint:new(
            "Sunken Gold", 
            CARD_TYPE.TREASURE, 
            0, 
            RARITY.RARE, 
            "Gain 25 Gold. Exhaust.", 
            {
                {type = "gold", value = 25},
                {type = "exhaust"}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.5, 0.4, 0.1)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                love.graphics.setColor(0.9, 0.8, 0.2)
                -- Draw coins
                for i = 1, 7 do
                    love.graphics.circle("fill", 
                        x + w/4 + math.random(w/2), 
                        y + h/4 + math.random(h/2), 
                        5 + math.random(5))
                end
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Pearl of Power", 
            CARD_TYPE.TREASURE, 
            0, 
            RARITY.EPIC, 
            "Gain 2 Energy. Draw 1 card. Exhaust.", 
            {
                {type = "energy", value = 2},
                {type = "draw", value = 1},
                {type = "exhaust"}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.3, 0.3, 0.4)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                -- Draw pearl
                love.graphics.setColor(0.95, 0.95, 1)
                love.graphics.circle("fill", x + w/2, y + h/2, w/4)
                love.graphics.setColor(0.8, 0.8, 0.9)
                love.graphics.circle("line", x + w/2, y + h/2, w/4)
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.circle("fill", x + w/2 - w/10, y + h/2 - h/10, w/10)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Abyssal Artifact", 
            CARD_TYPE.TREASURE, 
            0, 
            RARITY.LEGENDARY, 
            "Apply a random powerful effect. Exhaust.", 
            {
                {type = "random_powerful_effect"},
                {type = "exhaust"}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.1, 0.05, 0.2)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                -- Draw mysterious artifact
                love.graphics.setColor(0.4, 0.1, 0.6)
                love.graphics.rectangle("fill", x + w/3, y + h/3, w/3, h/3, 5, 5)
                love.graphics.setColor(0.8, 0.4, 1)
                for i = 1, 5 do
                    local angle = i * math.pi * 2 / 5
                    love.graphics.line(
                        x + w/2, y + h/2,
                        x + w/2 + math.cos(angle) * w/3, y + h/2 + math.sin(angle) * h/3
                    )
                end
                love.graphics.setColor(1, 1, 1)
            end
        ),

        -- Abyssal cards (special rarity)
        CardBlueprint:new(
            "Call of the Deep", 
            CARD_TYPE.ATTACK, 
            X, 
            RARITY.ABYSSAL, 
            "Deal X*8 damage. Apply X Pressure to yourself.", 
            {
                {type = "x_damage", multiplier = 8},
                {type = "self_pressure", x_multiplier = 1}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.05, 0.05, 0.15)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                -- Draw deep sea effect
                for i = 1, 20 do
                    love.graphics.setColor(0, 0.3, 0.5, 0.1)
                    love.graphics.circle("fill", 
                        x + math.random(w), 
                        y + math.random(h), 
                        math.random(5, 15))
                end
                love.graphics.setColor(0, 0.5, 0.8, 0.5)
                love.graphics.circle("fill", x + w/2, y + h/2, w/5)
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        CardBlueprint:new(
            "Leviathan's Grasp", 
            CARD_TYPE.ATTACK, 
            3, 
            RARITY.ABYSSAL, 
            "Deal 5 damage to all enemies 3 times. Apply 2 Pressure to yourself.", 
            {
                {type = "multi_aoe_damage", value = 5, hits = 3},
                {type = "self_pressure", value = 2}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.1, 0.1, 0.2)
                love.graphics.rectangle("fill", x, y, w, h, 10, 10)
                -- Draw tentacles
                love.graphics.setColor(0.2, 0.2, 0.4)
                for i = 1, 8 do
                    local cx = x + w/2
                    local cy = y + h
                    local angle = (i / 8) * math.pi - math.pi/2
                    local length = h * 0.6
                    love.graphics.line(
                        cx, cy,
                        cx + math.cos(angle) * length, cy + math.sin(angle) * length
                    )
                end
                love.graphics.setColor(1, 1, 1)
            end
        )
    }
    
    return allCards
end

-- Enemy BluePrint
local EnemyBlueprint = {}

function EnemyBlueprint:new(name, health, moves, imageFn)
    local enemy = {
        name = name,
        maxHealth = health,
        health = health,
        moves = moves,
        currentMove = 1,
        block = 0,
        status = {},
        imageFn = imageFn or function(x, y, w, h) 
            love.graphics.setColor(0.8, 0.2, 0.2)
            love.graphics.rectangle("fill", x, y, w, h)
            love.graphics.setColor(1, 1, 1)
        end,
        -- Instance properties
        x = SCREEN_WIDTH * 0.7,
        y = SCREEN_HEIGHT * 0.4,
        width = 150,
        height = 150,
        animations = {},
        id = love.math.random(1000000)
    }
    
    return enemy
end

-- Initialize enemy blueprints
function initializeEnemyBlueprints()
    local allEnemies = {
        EnemyBlueprint:new(
            "Anglerfish", 
            24, 
            {
                {type = "attack", value = 8, description = "Preparing to bite for 8 damage"},
                {type = "attack", value = 5, description = "Preparing to bite for 5 damage"},
                {type = "skill", effect = "illuminated", value = 2, description = "Glowing its lure to apply 2 Illuminated"}
            },
            function(x, y, w, h)
                love.graphics.setColor(0.3, 0.3, 0.4)
                love.graphics.ellipse("fill", x + w/2, y + h/2, w/2, h/3)
                love.graphics.setColor(0.2, 0.2, 0.3)
                
                -- Draw teeth
                for i = 1, 5 do
                    love.graphics.polygon("fill", 
                        x + w*0.7 + i*5, y + h/2,
                        x + w*0.7 + 5 + i*5, y + h/2,
                        x + w*0.7 + 2.5 + i*5, y + h/2 + 10
                    )
                end
                
                -- Draw lure
                love.graphics.setColor(1, 1, 0.7)
                love.graphics.circle("fill", x + w*0.3, y + h*0.3, w/10)
                love.graphics.setColor(0.3, 0.3, 0.4)
                love.graphics.line(x + w*0.3, y + h*0.3, x + w*0.4, y + h*0.4)
                
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        EnemyBlueprint:new(
            "Jellyfish", 
            18, 
            {
                {type = "attack", value = 6, description = "Preparing to sting for 6 damage"},
                {type = "skill", effect = "poison", value = 3, description = "Releasing toxins to apply 3 Poison"},
                {type = "defend", value = 7, description = "Pulsing its bell to gain 7 Block"}
            },
            function(x, y, w, h)
                -- Draw bell
                love.graphics.setColor(0.8, 0.5, 0.8, 0.7)
                love.graphics.ellipse("fill", x + w/2, y + h/3, w/2, h/4)
                
                -- Draw tentacles
                for i = 1, 8 do
                    local startX = x + w/2 + math.cos(i/4 * math.pi) * w/3
                    local startY = y + h/3 + h/4
                    love.graphics.setColor(0.7, 0.4, 0.7, 0.8)
                    love.graphics.line(
                        startX, startY,
                        startX + math.sin(i*3) * 5, startY + h/3
                    )
                end
                
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        EnemyBlueprint:new(
            "Kraken Spawn", 
            45, 
            {
                {type = "attack", value = 12, description = "Winding up for 12 damage"},
                {type = "multi_attack", value = 4, hits = 3, description = "Preparing multiple strikes for 4x3 damage"},
                {type = "skill", effect = "ink", value = 2, description = "Releasing ink to apply 2 Ink"},
                {type = "defend", value = 10, description = "Hardening skin for 10 Block"}
            },
            function(x, y, w, h)
                -- Draw head
                love.graphics.setColor(0.6, 0.3, 0.4)
                love.graphics.ellipse("fill", x + w/2, y + h/3, w/2, h/4)
                
                -- Draw tentacles
                for i = 1, 6 do
                    local angle = (i / 6) * math.pi - math.pi/2
                    love.graphics.setColor(0.5, 0.2, 0.3)
                    local startX = x + w/2 + math.cos(angle) * w/3
                    local startY = y + h/3 + math.sin(angle) * h/4
                    
                    -- Draw wavy tentacle
                    local points = {}
                    local segments = 8
                    for j = 0, segments do
                        local progress = j / segments
                        local tentacleX = startX + math.cos(angle + math.sin(progress * 5) * 0.3) * progress * h/2
                        local tentacleY = startY + progress * h/2
                        table.insert(points, tentacleX)
                        table.insert(points, tentacleY)
                    end
                    love.graphics.line(points)
                end
                
                -- Draw eye
                love.graphics.setColor(0.9, 0.9, 1)
                love.graphics.circle("fill", x + w/2, y + h/3, w/10)
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle("fill", x + w/2, y + h/3, w/20)
                
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        EnemyBlueprint:new(
            "Abyssal Guardian", 
            70, 
            {
                {type = "attack", value = 16, description = "Preparing a devastating blow for 16 damage"},
                {type = "multi_attack", value = 6, hits = 3, description = "Thrashing wildly for 6x3 damage"},
                {type = "skill", effect = "pressure", value = 3, description = "Creating intense pressure (3 Pressure)"},
                {type = "defend", value = 15, description = "Hardening scales for 15 Block"},
                {type = "special", description = "Preparing something terrible..."},
            },
            function(x, y, w, h)
                -- Draw body
                love.graphics.setColor(0.1, 0.1, 0.2)
                love.graphics.rectangle("fill", x + w/4, y + h/6, w/2, h/2, 10, 10)
                
                -- Draw fins
                love.graphics.setColor(0.15, 0.15, 0.25)
                love.graphics.polygon("fill", 
                    x + w/4, y + h/4,
                    x, y + h/3,
                    x, y + h/2,
                    x + w/4, y + h/2
                )
                love.graphics.polygon("fill", 
                    x + w*3/4, y + h/4,
                    x + w, y + h/3,
                    x + w, y + h/2,
                    x + w*3/4, y + h/2
                )
                
                -- Draw glowing patterns
                love.graphics.setColor(0.3, 0.7, 0.9, 0.8)
                for i = 1, 5 do
                    love.graphics.circle("fill", 
                        x + w/4 + (i-1) * w/10, 
                        y + h*2/3, 
                        w/30)
                end
                
                -- Draw eyes
                love.graphics.setColor(0.9, 0.1, 0.1)
                love.graphics.circle("fill", x + w*2/5, y + h/4, w/15)
                love.graphics.circle("fill", x + w*3/5, y + h/4, w/15)
                
                love.graphics.setColor(1, 1, 1)
            end
        )
    }
    
    return allEnemies
end

-- Initialize boss enemy blueprints
function initializeBossBlueprints()
    local bosses = {
        EnemyBlueprint:new(
            "Leviathan", 
            120, 
            {
                {type = "attack", value = 20, description = "Preparing a massive strike for 20 damage"},
                {type = "multi_attack", value = 8, hits = 4, description = "Unleashing multiple tentacles for 8x4 damage"},
                {type = "skill", effect = "pressure", value = 4, description = "Creating crushing pressure (4 Pressure)"},
                {type = "skill", effect = "ink", value = 3, description = "Releasing thick ink cloud (3 Ink)"},
                {type = "defend", value = 25, description = "Reinforcing thick hide for 25 Block"},
                {type = "special", effect = "summon", description = "Summoning offspring..."}
            },
            function(x, y, w, h)
                -- Draw massive body
                love.graphics.setColor(0.15, 0.1, 0.25)
                love.graphics.ellipse("fill", x + w/2, y + h/3, w*2/3, h/3)
                
                -- Draw tentacles
                for i = 1, 8 do
                    local angle = (i / 8) * math.pi - math.pi/2
                    love.graphics.setColor(0.1, 0.05, 0.2)
                    local startX = x + w/2 + math.cos(angle) * w*2/3
                    local startY = y + h/3 + math.sin(angle) * h/3
                    
                    -- Draw wavy tentacle
                    local points = {}
                    local segments = 10
                    for j = 0, segments do
                        local progress = j / segments
                        local tentacleX = startX + math.cos(angle + math.sin(progress * 5) * 0.3) * progress * h*0.8
                        local tentacleY = startY + progress * h*0.8
                        table.insert(points, tentacleX)
                        table.insert(points, tentacleY)
                    end
                    love.graphics.line(points)
                end
                
                -- Draw eyes
                for i = 1, 3 do
                    love.graphics.setColor(0.9, 0.2, 0.1)
                    love.graphics.circle("fill", x + w/2 + (i-2) * w/6, y + h/4, w/12)
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.circle("fill", x + w/2 + (i-2) * w/6, y + h/4, w/25)
                end
                
                -- Draw bioluminescent spots
                love.graphics.setColor(0.4, 0.8, 1, 0.7)
                for i = 1, 10 do
                    love.graphics.circle("fill", 
                        x + w/4 + math.random() * w/2, 
                        y + h/6 + math.random() * h/3, 
                        w/30)
                end
                
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        EnemyBlueprint:new(
            "Abyssal Colossus", 
            150, 
            {
                {type = "attack", value = 25, description = "Preparing an earth-shattering blow for 25 damage"},
                {type = "aoe_attack", value = 15, description = "Charging a shockwave for 15 damage to all"},
                {type = "skill", effect = "pressure", value = 5, description = "Creating immense pressure (5 Pressure)"},
                {type = "defend", value = 30, description = "Fortifying ancient shell for 30 Block"},
                {type = "special", effect = "regenerate", value = 10, description = "Regenerating 10 health..."}
            },
            function(x, y, w, h)
                -- Draw rocky body
                love.graphics.setColor(0.2, 0.2, 0.3)
                love.graphics.rectangle("fill", x + w/4, y + h/6, w/2, h*2/3, 5, 5)
                
                -- Draw rocky textures
                for i = 1, 20 do
                    love.graphics.setColor(0.15, 0.15, 0.2)
                    love.graphics.rectangle("fill", 
                        x + w/4 + math.random() * w/2, 
                        y + h/6 + math.random() * h*2/3, 
                        w/20, h/20)
                end
                
                -- Draw glowing cracks
                love.graphics.setColor(0.1, 0.6, 0.8, 0.8)
                love.graphics.line(
                    x + w/4, y + h/3,
                    x + w/2, y + h/2,
                    x + w*3/4, y + h/4
                )
                love.graphics.line(
                    x + w/4, y + h*2/3,
                    x + w/2, y + h/2,
                    x + w*3/4, y + h*2/3
                )
                
                -- Draw eye
                love.graphics.setColor(0.1, 0.7, 0.9)
                love.graphics.circle("fill", x + w/2, y + h/3, w/8)
                love.graphics.setColor(0.05, 0.3, 0.4)
                love.graphics.circle("fill", x + w/2, y + h/3, w/15)
                
                love.graphics.setColor(1, 1, 1)
            end
        )
    }
    
    return bosses
end

-- Shop item blueprint
local ShopItem = {}

function ShopItem:new(type, item, cost)
    local shopItem = {
        type = type, -- "card", "relic", "heal", "remove"
        item = item, -- The actual item/card or amount for heal
        cost = cost,
        x = 0,
        y = 0,
        width = type == "card" and CARD_WIDTH or 100,
        height = type == "card" and CARD_HEIGHT or 100,
        isHovered = false
    }
    
    return shopItem
end

-- Treasure blueprint
local Treasure = {}

function Treasure:new(name, description, effect, imageFn)
    local treasure = {
        name = name,
        description = description,
        effect = effect,
        imageFn = imageFn or function(x, y, w, h) 
            love.graphics.setColor(0.8, 0.7, 0.2)
            love.graphics.rectangle("fill", x, y, w, h)
            love.graphics.setColor(1, 1, 1)
        end,
        x = 0,
        y = 0,
        width = 80,
        height = 80,
        isHovered = false
    }
    
    return treasure
end

-- Initialize treasures
function initializeTreasures()
    local allTreasures = {
        Treasure:new(
            "Ancient Compass", 
            "At the start of combat, draw 2 additional cards.",
            {type = "start_draw", value = 2},
            function(x, y, w, h)
                love.graphics.setColor(0.6, 0.5, 0.3)
                love.graphics.circle("fill", x + w/2, y + h/2, w/2)
                love.graphics.setColor(0.3, 0.25, 0.15)
                love.graphics.circle("line", x + w/2, y + h/2, w/2)
                
                -- Draw compass needle
                love.graphics.setColor(0.8, 0.1, 0.1)
                love.graphics.line(x + w/2, y + h/2, x + w/2, y + h/4)
                love.graphics.setColor(0.1, 0.1, 0.8)
                love.graphics.line(x + w/2, y + h/2, x + w/2, y + h*3/4)
                
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        Treasure:new(
            "Pressure Regulator", 
            "Reduce all Pressure effects by 1.",
            {type = "reduce_pressure", value = 1},
            function(x, y, w, h)
                love.graphics.setColor(0.5, 0.5, 0.6)
                love.graphics.rectangle("fill", x + w/4, y + h/4, w/2, h/2, 5, 5)
                
                -- Draw gauge
                love.graphics.setColor(0.2, 0.2, 0.3)
                love.graphics.circle("fill", x + w/2, y + h/2, w/4)
                love.graphics.setColor(0.8, 0.8, 0.9)
                love.graphics.arc("line", x + w/2, y + h/2, w/4, math.pi*0.75, math.pi*2.25)
                
                -- Draw needle
                love.graphics.setColor(0.9, 0.1, 0.1)
                love.graphics.line(x + w/2, y + h/2, x + w/2 + math.cos(math.pi*0.25) * w/4, y + h/2 + math.sin(math.pi*0.25) * w/4)
                
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        Treasure:new(
            "Bubble Maker", 
            "At the start of your turn, gain 3 Oxygen.",
            {type = "start_oxygen", value = 3},
            function(x, y, w, h)
                love.graphics.setColor(0.4, 0.6, 0.7)
                love.graphics.rectangle("fill", x + w/4, y + h/2, w/2, h/3, 5, 5)
                
                -- Draw bubbles
                for i = 1, 3 do
                    love.graphics.setColor(0.8, 0.9, 1, 0.8)
                    love.graphics.circle("fill", x + w/2 + math.sin(i) * w/4, y + h/3 - i * h/8, w/6 - i * w/18)
                end
                
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        Treasure:new(
            "Golden Trident", 
            "Your first Attack each turn deals 5 additional damage.",
            {type = "first_attack_bonus", value = 5},
            function(x, y, w, h)
                love.graphics.setColor(0.9, 0.8, 0.2)
                -- Draw handle
                love.graphics.rectangle("fill", x + w/2 - 3, y + h/4, 6, h*3/4 - 2)
                
                -- Draw prongs
                love.graphics.rectangle("fill", x + w/2 - w/4, y + h/8, 6, h/4)
                love.graphics.rectangle("fill", x + w/2 + w/4 - 6, y + h/8, 6, h/4)
                love.graphics.rectangle("fill", x + w/2 - 3, y + 2, 6, h/4)
                
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        Treasure:new(
            "Luminous Pearl", 
            "At the start of combat, apply 2 Illuminated to all enemies.",
            {type = "start_illuminated", value = 2},
            function(x, y, w, h)
                -- Draw pearl
                love.graphics.setColor(0.95, 0.95, 1)
                love.graphics.circle("fill", x + w/2, y + h/2, w/2 - 2)
                
                -- Draw glow
                for i = 1, 3 do
                    love.graphics.setColor(0.9, 0.9, 1, 0.3 - i*0.1)
                    love.graphics.circle("fill", x + w/2, y + h/2, w/2 + i*5)
                end
                
                -- Draw highlight
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle("fill", x + w/3, y + h/3, w/8)
                
                love.graphics.setColor(1, 1, 1)
            end
        ),
        
        Treasure:new(
            "Abyssal Heart", 
            "When you play a card with Abyssal rarity, gain 1 Energy.",
            {type = "abyssal_energy", value = 1},
            function(x, y, w, h)
                love.graphics.setColor(0.05, 0.05, 0.15)
                love.graphics.rectangle("fill", x + w/4, y + h/4, w/2, h/2, w/4, h/4)
                
                -- Draw pulsing effect
                for i = 1, 3 do
                    love.graphics.setColor(0, 0.3, 0.6, 0.2 - i*0.05)
                    love.graphics.rectangle("fill", 
                        x + w/4 - i*3, 
                        y + h/4 - i*3, 
                        w/2 + i*6, 
                        h/2 + i*6, 
                        w/4 + i*3, h/4 + i*3)
                end
                
                -- Draw vein
                love.graphics.setColor(0.4, 0, 0.8, 0.7)
                love.graphics.line(
                    x + w/4, y + h/2,
                    x + w*3/8, y + h*3/8,
                    x + w*5/8, y + h*5/8,
                    x + w*3/4, y + h/2
                )
                
                love.graphics.setColor(1, 1, 1)
            end
        )
    }
    
    return allTreasures
end

-- Map node blueprint
local MapNode = {}

function MapNode:new(nodeType, x, y)
    local node = {
        nodeType = nodeType, -- "combat", "elite", "boss", "shop", "treasure", "rest"
        x = x,
        y = y,
        visited = false,
        available = false,
        connections = {},
        radius = 20
    }
    
    return node
end

-- UI Element blueprint
local UIElement = {}

function UIElement:new(x, y, width, height, text, action, style)
    local element = {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        action = action,
        style = style or "default",
        isHovered = false,
        isPressed = false
    }
    
    return element
end

-- Initialize game
function love.load()
    -- Initialize random seed
    math.randomseed(os.time())
    
    -- Load assets
    loadAssets()
    
    -- Initialize card blueprints
    cardBlueprints = initializeCardBlueprints()
    
    -- Initialize enemy blueprints
    enemyBlueprints = initializeEnemyBlueprints()
    bossBlueprints = initializeBossBlueprints()
    
    -- Initialize treasures
    treasureBlueprints = initializeTreasures()
    
    -- Add some starting cards to the deck
    deck = {
        cloneCard(findCardByName("Trident Strike")),
        cloneCard(findCardByName("Trident Strike")),
        cloneCard(findCardByName("Coral Shield")),
        cloneCard(findCardByName("Coral Shield")),
        cloneCard(findCardByName("Deep Exploration"))
    }
    
    -- Initialize player treasures
    player.treasures = {}
    
    -- Initialize game state
    startNewGame()
end

-- Clone a card from blueprint
function cloneCard(blueprint)
    if not blueprint then return nil end
    
    local card = {}
    for k, v in pairs(blueprint) do
        if type(v) == "table" then
            card[k] = {}
            for k2, v2 in pairs(v) do
                card[k][k2] = v2
            end
        else
            card[k] = v
        end
    end
    card.id = love.math.random(1000000) -- Give unique ID
    return card
end

-- Find card by name
function findCardByName(name)
    for _, card in ipairs(cardBlueprints) do
        if card.name == name then
            return card
        end
    end
    return nil
end

-- Start a new game
function startNewGame()
    -- Reset game state
    gameState = STATE.TITLE
    playerHand = {}
    drawPile = {}
    discardPile = {}
    currentEnergy = MAX_ENERGY
    
    -- Reset player stats
    player.health = player.maxHealth
    player.gold = 0
    player.depth = 0
    player.oxygen = player.maxOxygen
    player.block = 0
    player.pressure = 0
    player.treasures = {}
    
    -- Initialize UI elements
    initializeUI()
    
    -- Initialize deck with starting cards
    deck = {
        cloneCard(findCardByName("Trident Strike")),
        cloneCard(findCardByName("Trident Strike")),
        cloneCard(findCardByName("Coral Shield")),
        cloneCard(findCardByName("Coral Shield")),
        cloneCard(findCardByName("Deep Exploration"))
    }
    
    -- Play background music
    -- assets.music.main:play()
end

-- Initialize UI elements
function initializeUI()
    uiElements = {
        -- Title screen buttons
        titleStart = UIElement:new(
            SCREEN_WIDTH / 2 - 100, 
            SCREEN_HEIGHT / 2, 
            200, 50, 
            "Dive In", 
            function() startCombat() end, 
            "primary"
        ),
        
        titleQuit = UIElement:new(
            SCREEN_WIDTH / 2 - 100, 
            SCREEN_HEIGHT / 2 + 70, 
            200, 50, 
            "Surface", 
            function() love.event.quit() end
        ),
        
        -- End turn button
        endTurn = UIElement:new(
            SCREEN_WIDTH - 120, 
            SCREEN_HEIGHT - 70, 
            100, 40, 
            "End Turn", 
            function() endPlayerTurn() end
        ),
        
        -- Map screen buttons
        mapContinue = UIElement:new(
            SCREEN_WIDTH / 2 - 100, 
            SCREEN_HEIGHT - 100, 
            200, 50, 
            "Continue", 
            function() 
                if currentMapNode then
                    currentMapNode.visited = true
                    if currentMapNode.nodeType == "combat" then
                        startCombat()
                    elseif currentMapNode.nodeType == "elite" then
                        startEliteCombat()
                    elseif currentMapNode.nodeType == "boss" then
                        startBossCombat()
                    elseif currentMapNode.nodeType == "shop" then
                        startShop()
                    elseif currentMapNode.nodeType == "treasure" then
                        startTreasureRoom()
                    elseif currentMapNode.nodeType == "rest" then
                        startRestSite()
                    end
                end
            end, 
            "primary"
        )
    }
end

-- Start a new combat encounter
function startCombat()
    gameState = STATE.PLAY
    playerHand = {}
    discardPile = {}
    currentEnergy = MAX_ENERGY
    turnCount = 0
    firstAttackPlayed = false
    
    -- Apply start of combat effects from treasures
    for _, treasure in ipairs(player.treasures) do
        if treasure.effect.type == "start_draw" then
            drawCards(treasure.effect.value)
        elseif treasure.effect.type == "start_illuminated" then
            if currentEnemy then
                applyStatus(currentEnemy, "illuminated", treasure.effect.value)
            end
        end
    end
    
    -- Create a random enemy
    local enemyIndex = math.random(1, #enemyBlueprints)
    currentEnemy = cloneEnemy(enemyBlueprints[enemyIndex])
    
    -- Shuffle deck
    shuffleDeck()
    
    -- Draw initial hand
    drawCards(HAND_SIZE)
    
    -- Start enemy intent
    updateEnemyIntent()
end

-- Start an elite combat encounter
function startEliteCombat()
    gameState = STATE.PLAY
    playerHand = {}
    discardPile = {}
    currentEnergy = MAX_ENERGY
    turnCount = 0
    firstAttackPlayed = false
    
    -- Create a random elite enemy (last two in enemy list)
    local enemyIndex = math.random(#enemyBlueprints - 1, #enemyBlueprints)
    currentEnemy = cloneEnemy(enemyBlueprints[enemyIndex])
    
    -- Shuffle deck
    shuffleDeck()
    
    -- Draw initial hand
    drawCards(HAND_SIZE)
    
    -- Start enemy intent
    updateEnemyIntent()
end

-- Start a boss combat encounter
function startBossCombat()
    gameState = STATE.PLAY
    playerHand = {}
    discardPile = {}
    currentEnergy = MAX_ENERGY
    turnCount = 0
    firstAttackPlayed = false
    
    -- Create a random boss
    local bossIndex = math.random(1, #bossBlueprints)
    currentEnemy = cloneEnemy(bossBlueprints[bossIndex])
    
    -- Shuffle deck
    shuffleDeck()
    
    -- Draw initial hand
    drawCards(HAND_SIZE)
    
    -- Start enemy intent
    updateEnemyIntent()
end

-- Clone an enemy from blueprint
function cloneEnemy(blueprint)
    if not blueprint then return nil end
    
    local enemy = {}
    for k, v in pairs(blueprint) do
        if type(v) == "table" then
            enemy[k] = {}
            for k2, v2 in pairs(v) do
                enemy[k][k2] = v2
            end
        else
            enemy[k] = v
        end
    end
    enemy.id = love.math.random(1000000) -- Give unique ID
    enemy.health = enemy.maxHealth
    enemy.block = 0
    enemy.status = {}
    return enemy
end

-- Shuffle the deck
function shuffleDeck()
    -- Combine discard pile back into draw pile if needed
    if #drawPile == 0 then
        for _, card in ipairs(discardPile) do
            table.insert(drawPile, card)
        end
        discardPile = {}
    end
    
    -- Fisher-Yates shuffle
    for i = #drawPile, 2, -1 do
        local j = math.random(i)
        drawPile[i], drawPile[j] = drawPile[j], drawPile[i]
    end
end

-- Draw cards
function drawCards(count)
    for i = 1, count do
        if #drawPile == 0 then
            shuffleDeck()
            if #drawPile == 0 then
                break -- No cards left to draw
            end
        end
        
        local card = table.remove(drawPile, 1)
        card.x = SCREEN_WIDTH / 2
        card.y = SCREEN_HEIGHT + CARD_HEIGHT
        card.targetX = (SCREEN_WIDTH / 2) - (HAND_SIZE * CARD_WIDTH / 2) + (#playerHand * CARD_WIDTH)
        card.targetY = SCREEN_HEIGHT - CARD_HEIGHT - 20
        card.scale = 0
        card.targetScale = 1
        
        table.insert(playerHand, card)
    end
end

-- Update enemy intent (what they plan to do next)
function updateEnemyIntent()
    if not currentEnemy then return end
    
    -- Cycle through enemy moves
    currentEnemy.currentMove = currentEnemy.currentMove + 1
    if currentEnemy.currentMove > #currentEnemy.moves then
        currentEnemy.currentMove = 1
    end
end

-- End player turn
function endPlayerTurn()
    -- Discard hand
    for _, card in ipairs(playerHand) do
        table.insert(discardPile, card)
    end
    playerHand = {}
    
    -- Reset energy
    currentEnergy = MAX_ENERGY
    
    -- Process enemy turn
    enemyTurn()
    
    -- Draw new hand
    drawCards(HAND_SIZE)
    
    -- Reset first attack flag
    firstAttackPlayed = false
    
    -- Increment turn counter
    turnCount = turnCount + 1
    
    -- Apply start of turn effects from treasures
    for _, treasure in ipairs(player.treasures) do
        if treasure.effect.type == "start_oxygen" then
            player.oxygen = math.min(player.oxygen + treasure.effect.value, player.maxOxygen)
        end
    end
    
    -- Apply oxygen loss
    player.oxygen = math.max(player.oxygen - 5, 0)
    
    -- Check for oxygen depletion
    if player.oxygen <= 0 then
        player.health = player.health - 5
        if player.health <= 0 then
            gameOver()
        end
    end
end

-- Process enemy turn
function enemyTurn()
    if not currentEnemy then return end
    
    local move = currentEnemy.moves[currentEnemy.currentMove]
    
    if move.type == "attack" then
        -- Calculate damage with pressure modifier
        local damage = move.value
        if player.pressure > 0 then
            damage = damage * (1 + player.pressure * 0.25)
        end
        
        -- Apply damage through block
        local remainingDamage = math.max(damage - player.block, 0)
        player.block = math.max(player.block - damage, 0)
        player.health = player.health - remainingDamage
        
        -- Create damage animation
        addAnimation({
            type = "damage",
            target = "player",
            amount = remainingDamage,
            x = SCREEN_WIDTH / 4,
            y = SCREEN_HEIGHT / 2,
            duration = 0.5
        })
        
        -- Play damage sound
        assets.sounds.damage:play()
        
    elseif move.type == "multi_attack" then
        for i = 1, move.hits do
            -- Calculate damage with pressure modifier
            local damage = move.value
            if player.pressure > 0 then
                damage = damage * (1 + player.pressure * 0.25)
            end
            
            -- Apply damage through block
            local remainingDamage = math.max(damage - player.block, 0)
            player.block = math.max(player.block - damage, 0)
            player.health = player.health - remainingDamage
            
            -- Create damage animation
            addAnimation({
                type = "damage",
                target = "player",
                amount = remainingDamage,
                x = SCREEN_WIDTH / 4 + math.random(-20, 20),
                y = SCREEN_HEIGHT / 2 + math.random(-20, 20),
                duration = 0.3,
                delay = i * 0.2
            })
            
            -- Play damage sound
            assets.sounds.damage:play()
        end
        
    elseif move.type == "aoe_attack" then
        -- For now just damage player, but could affect multiple enemies in future
        local damage = move.value
        if player.pressure > 0 then
            damage = damage * (1 + player.pressure * 0.25)
        end
        
        local remainingDamage = math.max(damage - player.block, 0)
        player.block = math.max(player.block - damage, 0)
        player.health = player.health - remainingDamage
        
        addAnimation({
            type = "damage",
            target = "player",
            amount = remainingDamage,
            x = SCREEN_WIDTH / 4,
            y = SCREEN_HEIGHT / 2,
            duration = 0.5
        })
        
        assets.sounds.damage:play()
        
    elseif move.type == "defend" then
        currentEnemy.block = currentEnemy.block + move.value
        
        addAnimation({
            type = "block",
            target = "enemy",
            amount = move.value,
            x = currentEnemy.x,
            y = currentEnemy.y,
            duration = 0.5
        })
        
    elseif move.type == "skill" then
        if move.effect == "illuminated" then
            -- In this case, enemy is applying illuminated to itself (for flavor)
            applyStatus(currentEnemy, "illuminated", move.value)
        else
            applyStatus(player, move.effect, move.value)
        end
        
    elseif move.type == "special" then
        -- Boss special ability
        if currentEnemy.name == "Leviathan" then
            -- Summon a weaker enemy
            local minion = cloneEnemy(enemyBlueprints[math.random(1, #enemyBlueprints - 2)])
            minion.health = minion.health * 0.5
            minion.maxHealth = minion.maxHealth * 0.5
            table.insert(enemies, minion)
            
            addAnimation({
                type = "text",
                text = "Summoned " .. minion.name .. "!",
                x = SCREEN_WIDTH / 2,
                y = SCREEN_HEIGHT / 3,
                duration = 1.5
            })
        elseif currentEnemy.name == "Abyssal Colossus" then
            -- Heal itself
            currentEnemy.health = math.min(currentEnemy.health + move.value, currentEnemy.maxHealth)
            
            addAnimation({
                type = "heal",
                target = "enemy",
                amount = move.value,
                x = currentEnemy.x,
                y = currentEnemy.y,
                duration = 0.5
            })
        end
    end
    
    -- Update enemy intent for next turn
    updateEnemyIntent()
    
    -- Check if player died
    if player.health <= 0 then
        gameOver()
    end
end

-- Apply status effect to target
function applyStatus(target, statusType, amount)
    if not target or not statusType then return end
    
    -- Find existing status or create new
    local found = false
    for _, status in ipairs(target.status) do
        if status.type == statusType then
            status.amount = status.amount + amount
            found = true
            break
        end
    end
    
    if not found then
        table.insert(target.status, {
            type = statusType,
            amount = amount
        })
    end
    
    -- Create status animation
    addAnimation({
        type = "status",
        status = statusType,
        amount = amount,
        x = target.x,
        y = target.y - target.height / 2 - 20,
        duration = 0.5
    })
end

-- Add an animation to the queue
function addAnimation(animation)
    table.insert(animations, animation)
end

-- Process animations
function updateAnimations(dt)
    for i = #animations, 1, -1 do
        local anim = animations[i]
        
        if anim.delay and anim.delay > 0 then
            anim.delay = anim.delay - dt
        else
            anim.time = (anim.time or 0) + dt
            
            if anim.time >= anim.duration then
                table.remove(animations, i)
                
                -- Process any on-complete actions
                if anim.onComplete then
                    anim.onComplete()
                end
            end
        end
    end
end

-- Start the shop
function startShop()
    gameState = STATE.SHOP
    shopItems = {}
    
    -- Add random cards for sale
    for i = 1, 3 do
        local card = cloneCard(cardBlueprints[math.random(1, #cardBlueprints)])
        card.x = SCREEN_WIDTH / 4 + (i-1) * (CARD_WIDTH + 20)
        card.y = SCREEN_HEIGHT / 3
        table.insert(shopItems, ShopItem:new("card", card, 50 + math.random(0, 50)))
    end
    
    -- Add a treasure for sale
    local treasure = treasureBlueprints[math.random(1, #treasureBlueprints)]
    table.insert(shopItems, ShopItem:new("treasure", treasure, 150 + math.random(0, 100)))
    
    -- Add heal option
    table.insert(shopItems, ShopItem:new("heal", 15, 75))
    
    -- Add card removal option
    table.insert(shopItems, ShopItem:new("remove", nil, 100))
end

-- Start a treasure room
function startTreasureRoom()
    gameState = STATE.REWARD
    treasures = {}
    
    -- Offer 3 random treasures to choose from
    for i = 1, 3 do
        local treasure = cloneTreasure(treasureBlueprints[math.random(1, #treasureBlueprints)])
        treasure.x = SCREEN_WIDTH / 4 + (i-1) * 120
        treasure.y = SCREEN_HEIGHT / 2
        table.insert(treasures, treasure)
    end
end

-- Clone a treasure
function cloneTreasure(blueprint)
    if not blueprint then return nil end
    
    local treasure = {}
    for k, v in pairs(blueprint) do
        if type(v) == "table" then
            treasure[k] = {}
            for k2, v2 in pairs(v) do
                treasure[k][k2] = v2
            end
        else
            treasure[k] = v
        end
    end
    return treasure
end

-- Start a rest site
function startRestSite()
    gameState = STATE.REWARD
    
    -- Heal player
    player.health = math.min(player.health + 20, player.maxHealth)
    
    -- Offer card removal
    -- (In a full implementation, this would be a UI choice)
end

-- Game over
function gameOver()
    gameState = STATE.GAME_OVER
    
    -- Create game over text animation
    addAnimation({
        type = "text",
        text = "GAME OVER",
        x = SCREEN_WIDTH / 2,
        y = SCREEN_HEIGHT / 2,
        duration = 3,
        onComplete = function()
            -- Return to title screen after delay
            startNewGame()
        end
    })
end

-- Play a card
function playCard(card, target)
    if not card or currentEnergy < card.cost then return end
    
    -- Spend energy
    currentEnergy = currentEnergy - card.cost
    
    -- Mark first attack if applicable
    if card.cardType == CARD_TYPE.ATTACK and not firstAttackPlayed then
        firstAttackPlayed = true
        
        -- Check for first attack bonus from treasures
        for _, treasure in ipairs(player.treasures) do
            if treasure.effect.type == "first_attack_bonus" then
                -- Add bonus damage effect to the card
                table.insert(card.effects, {type = "damage", value = treasure.effect.value})
            end
        end
    end
    
    -- Process card effects
    for _, effect in ipairs(card.effects) do
        if effect.type == "damage" then
            local damage = effect.value
            
            -- Check for illuminated bonus
            if target and target.status then
                for _, status in ipairs(target.status) do
                    if status.type == "illuminated" then
                        damage = damage * 1.5
                        break
                    end
                end
            end
            
            -- Apply damage through block
            if target then
                local remainingDamage = math.max(damage - (target.block or 0), 0)
                target.block = math.max((target.block or 0) - damage, 0)
                target.health = target.health - remainingDamage
                
                -- Create damage animation
                addAnimation({
                    type = "damage",
                    target = "enemy",
                    amount = remainingDamage,
                    x = target.x,
                    y = target.y,
                    duration = 0.5
                })
                
                -- Play damage sound
                assets.sounds.damage:play()
            end
            
        elseif effect.type == "aoe_damage" then
            -- Damage all enemies
            local damage = effect.value
            
            -- Check for illuminated bonus on main target
            if target and target.status then
                for _, status in ipairs(target.status) do
                    if status.type == "illuminated" then
                        damage = damage * 1.5
                        break
                    end
                end
            end
            
            -- Apply to current enemy
            if currentEnemy then
                local remainingDamage = math.max(damage - currentEnemy.block, 0)
                currentEnemy.block = math.max(currentEnemy.block - damage, 0)
                currentEnemy.health = currentEnemy.health - remainingDamage
                
                addAnimation({
                    type = "damage",
                    target = "enemy",
                    amount = remainingDamage,
                    x = currentEnemy.x,
                    y = currentEnemy.y,
                    duration = 0.5
                })
            end
            
            -- Apply to any additional enemies
            for _, enemy in ipairs(enemies) do
                local remainingDamage = math.max(damage - enemy.block, 0)
                enemy.block = math.max(enemy.block - damage, 0)
                enemy.health = enemy.health - remainingDamage
                
                addAnimation({
                    type = "damage",
                    target = "enemy",
                    amount = remainingDamage,
                    x = enemy.x,
                    y = enemy.y,
                    duration = 0.5,
                    delay = 0.1
                })
            end
            
            assets.sounds.damage:play()
            
        elseif effect.type == "multi_damage" then
            -- Multiple hits
            for i = 1, effect.hits do
                local damage = effect.value
                
                -- Check for illuminated bonus
                if target and target.status then
                    for _, status in ipairs(target.status) do
                        if status.type == "illuminated" then
                            damage = damage * 1.5
                            break
                        end
                    end
                end
                
                -- Apply damage through block
                if target then
                    local remainingDamage = math.max(damage - (target.block or 0), 0)
                    target.block = math.max((target.block or 0) - damage, 0)
                    target.health = target.health - remainingDamage
                    
                    addAnimation({
                        type = "damage",
                        target = "enemy",
                        amount = remainingDamage,
                        x = target.x + math.random(-20, 20),
                        y = target.y + math.random(-20, 20),
                        duration = 0.3,
                        delay = i * 0.1
                    })
                end
            end
            
            assets.sounds.damage:play()
            
        elseif effect.type == "block" then
            player.block = player.block + effect.value
            
            addAnimation({
                type = "block",
                target = "player",
                amount = effect.value,
                x = SCREEN_WIDTH / 4,
                y = SCREEN_HEIGHT / 2,
                duration = 0.5
            })
            
        elseif effect.type == "draw" then
            drawCards(effect.value)
            
        elseif effect.type == "oxygen" then
            player.oxygen = math.min(player.oxygen + effect.value, player.maxOxygen)
            
            addAnimation({
                type = "oxygen",
                amount = effect.value,
                x = SCREEN_WIDTH / 4,
                y = SCREEN_HEIGHT / 2 - 50,
                duration = 0.5
            })
            
            assets.sounds.heal:play()
            
        elseif effect.type == "gold" then
            player.gold = player.gold + effect.value
            
            addAnimation({
                type = "gold",
                amount = effect.value,
                x = SCREEN_WIDTH / 4,
                y = SCREEN_HEIGHT / 2 - 50,
                duration = 0.5
            })
            
            assets.sounds.treasure:play()
            
        elseif effect.type == "apply_illuminated" then
            if target then
                applyStatus(target, "illuminated", effect.value)
            end
            
        elseif effect.type == "apply_ink" then
            if target then
                applyStatus(target, "ink", effect.value)
            end
            
        elseif effect.type == "apply_pressure" then
            if target then
                applyStatus(target, "pressure", effect.value)
            end
            
        elseif effect.type == "self_pressure" then
            applyStatus(player, "pressure", effect.value)
            
        elseif effect.type == "reduce_pressure" then
            for i, status in ipairs(player.status) do
                if status.type == "pressure" then
                    status.amount = math.max(status.amount - effect.value, 0)
                    if status.amount <= 0 then
                        table.remove(player.status, i)
                    end
                    break
                end
            end
            
        elseif effect.type == "add_treasure" then
            -- Add a random treasure card to draw pile
            local treasureCard = cloneCard(findCardByName("Sunken Gold"))
            if math.random() < 0.3 then
                treasureCard = cloneCard(findCardByName("Pearl of Power"))
            elseif math.random() < 0.1 then
                treasureCard = cloneCard(findCardByName("Abyssal Artifact"))
            end
            
            table.insert(drawPile, treasureCard)
            
            addAnimation({
                type = "text",
                text = "Treasure added to deck!",
                x = SCREEN_WIDTH / 2,
                y = SCREEN_HEIGHT / 3,
                duration = 1
            })
            
            assets.sounds.treasure:play()
            
        elseif effect.type == "random_powerful_effect" then
            -- Apply a random powerful effect
            local effects = {
                {type = "damage", value = 25},
                {type = "block", value = 20},
                {type = "draw", value = 3},
                {type = "oxygen", value = 15}
            }
            
            local chosen = effects[math.random(1, #effects)]
            table.insert(card.effects, chosen)
            playCard(card, target) -- Recursively play the card with the new effect
            
        elseif effect.type == "exhaust" then
            -- Don't add to discard pile
            return
        end
    end
    
    -- Check for abyssal energy from treasures
    if card.rarity == RARITY.ABYSSAL then
        for _, treasure in ipairs(player.treasures) do
            if treasure.effect.type == "abyssal_energy" then
                currentEnergy = currentEnergy + treasure.effect.value
                
                addAnimation({
                    type = "energy",
                    amount = treasure.effect.value,
                    x = SCREEN_WIDTH - 100,
                    y = SCREEN_HEIGHT - 100,
                    duration = 0.5
                })
            end
        end
    end
    
    -- Move card to discard pile (unless it's exhausted)
    local exhausted = false
    for _, effect in ipairs(card.effects) do
        if effect.type == "exhaust" then
            exhausted = true
            break
        end
    end
    
    if not exhausted then
        table.insert(discardPile, card)
    end
    
    -- Remove card from hand
    for i, handCard in ipairs(playerHand) do
        if handCard.id == card.id then
            table.remove(playerHand, i)
            break
        end
    end
    
    -- Check if enemy died
    if currentEnemy and currentEnemy.health <= 0 then
        -- Reward player
        player.gold = player.gold + 25
        player.depth = player.depth + 1
        
        -- Check for additional enemies
        if #enemies > 0 then
            -- Promote the first additional enemy to main enemy
            currentEnemy = table.remove(enemies, 1)
        else
            -- Combat ended
            endCombat()
        end
    end
end

-- End combat and go to reward screen
function endCombat()
    gameState = STATE.REWARD
    
    -- Clear enemies
    currentEnemy = nil
    enemies = {}
    
    -- Offer card reward
    treasures = {}
    for i = 1, 3 do
        local card = cloneCard(cardBlueprints[math.random(1, #cardBlueprints)])
        card.x = SCREEN_WIDTH / 4 + (i-1) * (CARD_WIDTH + 20)
        card.y = SCREEN_HEIGHT / 3
        table.insert(treasures, card)
    end
end

-- Update game state
function love.update(dt)
    -- Update animations
    updateAnimations(dt)
    
    -- Update screen shake
    if shake.duration > 0 then
        shake.duration = shake.duration - dt
    else
        shake.amount = 0
    end
    
    -- Update particles
    for _, particle in ipairs(particles) do
        particle:update(dt)
    end
    
    -- Update cards in hand
    for _, card in ipairs(playerHand) do
        -- Animate to target position
        card.x = card.x + (card.targetX - card.x) * 10 * dt
        card.y = card.y + (card.targetY - card.y) * 10 * dt
        card.rotation = card.rotation + (card.targetRotation - card.rotation) * 10 * dt
        card.scale = card.scale + (card.targetScale - card.scale) * 10 * dt
        
        -- Update hover state
        local mouseX, mouseY = love.mouse.getPosition()
        local cardCenterX = card.x + card.width/2
        local cardCenterY = card.y + card.height/2
        
        -- Transform mouse coordinates to account for card rotation and scale
        local relX = mouseX - cardCenterX
        local relY = mouseY - cardCenterY
        local distance = math.sqrt(relX*relX + relY*relY)
        
        card.isHovered = distance < card.width/2 * card.scale
        
        if card.isHovered then
            card.targetY = SCREEN_HEIGHT - CARD_HEIGHT - 50
            tooltipCard = card
        else
            card.targetY = SCREEN_HEIGHT - CARD_HEIGHT - 20
        end
    end
    
    -- Update UI elements
    local mouseX, mouseY = love.mouse.getPosition()
    for _, element in pairs(uiElements) do
        element.isHovered = mouseX >= element.x and mouseX <= element.x + element.width and
                           mouseY >= element.y and mouseY <= element.y + element.height
    end
    
    -- Update shop items
    if gameState == STATE.SHOP then
        for _, item in ipairs(shopItems) do
            item.isHovered = mouseX >= item.x and mouseX <= item.x + item.width and
                            mouseY >= item.y and mouseY <= item.y + item.height
        end
    end
    
    -- Update treasure rewards
    if gameState == STATE.REWARD then
        for _, treasure in ipairs(treasures) do
            treasure.isHovered = mouseX >= treasure.x and mouseX <= treasure.x + treasure.width and
                               mouseY >= treasure.y and mouseY <= treasure.y + treasure.height
        end
    end
end

-- Draw game state
function love.draw()
    -- Apply screen shake
    local shakeX = 0
    local shakeY = 0
    if shake.amount > 0 then
        shakeX = math.random(-shake.amount, shake.amount)
        shakeY = math.random(-shake.amount, shake.amount)
    end
    
    love.graphics.translate(shakeX, shakeY)
    
    -- Draw background based on game state
    if gameState == STATE.TITLE then
        drawTitleScreen()
    elseif gameState == STATE.PLAY then
        drawPlayScreen()
    elseif gameState == STATE.SHOP then
        drawShopScreen()
    elseif gameState == STATE.MAP then
        drawMapScreen()
    elseif gameState == STATE.REWARD then
        drawRewardScreen()
    elseif gameState == STATE.GAME_OVER then
        drawGameOverScreen()
    end
    
    -- Draw animations
    drawAnimations()
    
    -- Draw tooltips
    drawTooltips()
    
    -- Reset transform
    love.graphics.origin()
end

-- Draw title screen
function drawTitleScreen()
    -- Dark blue background
    love.graphics.setColor(0.05, 0.1, 0.2)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    
    -- Title text
    love.graphics.setFont(assets.fonts.title)
    love.graphics.setColor(0, 0.8, 1)
    love.graphics.printf("THE DEPTHS", 0, SCREEN_HEIGHT / 4, SCREEN_WIDTH, "center")
    
    -- Subtitle
    love.graphics.setFont(assets.fonts.medium)
    love.graphics.setColor(0.7, 0.8, 1)
    love.graphics.printf("A Deep Sea Card Adventure", 0, SCREEN_HEIGHT / 4 + 70, SCREEN_WIDTH, "center")
    
    -- Draw UI elements
    for _, element in pairs(uiElements) do
        if element.text == "Dive In" or element.text == "Surface" then
            drawUIElement(element)
        end
    end
    
    -- Draw bubbles
    love.graphics.setColor(1, 1, 1, 0.5)
    for i = 1, 20 do
        love.graphics.circle("fill", 
            math.random(SCREEN_WIDTH), 
            math.random(SCREEN_HEIGHT), 
            math.random(5, 15))
    end
end

-- Draw play screen
function drawPlayScreen()
    -- Darker blue background for deeper feel
    love.graphics.setColor(0.02, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    
    -- Draw player info
    drawPlayerInfo()
    
    -- Draw enemy
    if currentEnemy then
        drawEnemy(currentEnemy)
    end
    
    -- Draw additional enemies
    for i, enemy in ipairs(enemies) do
        enemy.x = SCREEN_WIDTH * 0.7 + (i % 2) * 50
        enemy.y = SCREEN_HEIGHT * 0.4 + math.floor(i / 2) * 100
        enemy.width = 100
        enemy.height = 100
        drawEnemy(enemy)
    end
    
    -- Draw hand
    for _, card in ipairs(playerHand) do
        drawCard(card)
    end
    
    -- Draw UI elements
    drawUIElement(uiElements.endTurn)
end

-- Draw player info
function drawPlayerInfo()
    -- Player avatar/icon placeholder
    love.graphics.setColor(0.2, 0.5, 0.8)
    love.graphics.circle("fill", SCREEN_WIDTH / 4, SCREEN_HEIGHT / 2, 40)
    
    -- Health
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.rectangle("fill", SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 60, 100, 10)
    love.graphics.setColor(0.3, 1, 0.3)
    local healthWidth = 100 * (player.health / player.maxHealth)
    love.graphics.rectangle("fill", SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 60, healthWidth, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(assets.fonts.small)
    love.graphics.printf(math.floor(player.health) .. "/" .. player.maxHealth, 
        SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 75, 100, "center")
    
    -- Block
    if player.block > 0 then
        love.graphics.setColor(0.7, 0.7, 1, 0.8)
        love.graphics.rectangle("fill", SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 90, 100, 10)
        love.graphics.setFont(assets.fonts.small)
        love.graphics.printf("Block: " .. player.block, 
            SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 90, 100, "center")
    end
    
    -- Oxygen
    love.graphics.setColor(0.3, 0.7, 1)
    love.graphics.rectangle("fill", SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 110, 100, 10)
    love.graphics.setColor(0, 0.5, 1)
    local oxygenWidth = 100 * (player.oxygen / player.maxOxygen)
    love.graphics.rectangle("fill", SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 110, oxygenWidth, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(math.floor(player.oxygen) .. "/" .. player.maxOxygen, 
        SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 125, 100, "center")
    
    -- Pressure
    if player.pressure > 0 then
        love.graphics.setColor(0.5, 0.2, 0.8, 0.8)
        love.graphics.printf("Pressure: " .. player.pressure, 
            SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 140, 100, "center")
    end
    
    -- Gold
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.printf("Gold: " .. player.gold, 
        SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 160, 100, "center")
    
    -- Depth
    love.graphics.setColor(0.7, 0.7, 1)
    love.graphics.printf("Depth: " .. player.depth, 
        SCREEN_WIDTH / 4 - 50, SCREEN_HEIGHT / 2 + 180, 100, "center")
    
    -- Energy
    love.graphics.setColor(0.9, 0.9, 0.2)
    for i = 1, MAX_ENERGY do
        if i <= currentEnergy then
            love.graphics.circle("fill", SCREEN_WIDTH - 100 + (i-1)*30, SCREEN_HEIGHT - 100, 10)
        else
            love.graphics.circle("line", SCREEN_WIDTH - 100 + (i-1)*30, SCREEN_HEIGHT - 100, 10)
        end
    end
    
    love.graphics.setColor(1, 1, 1)
end

-- Draw enemy
function drawEnemy(enemy)
    if not enemy then return end
    
    -- Draw enemy image
    enemy.imageFn(enemy.x - enemy.width/2, enemy.y - enemy.height/2, enemy.width, enemy.height)
    
    -- Health bar
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.rectangle("fill", enemy.x - 50, enemy.y - enemy.height/2 - 20, 100, 10)
    love.graphics.setColor(0.3, 1, 0.3)
    local healthWidth = 100 * (enemy.health / enemy.maxHealth)
    love.graphics.rectangle("fill", enemy.x - 50, enemy.y - enemy.height/2 - 20, healthWidth, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(assets.fonts.small)
    love.graphics.printf(math.floor(enemy.health) .. "/" .. enemy.maxHealth, 
        enemy.x - 50, enemy.y - enemy.height/2 - 5, 100, "center")
    
    -- Block
    if enemy.block > 0 then
        love.graphics.setColor(0.7, 0.7, 1, 0.8)
        love.graphics.rectangle("fill", enemy.x - 50, enemy.y - enemy.height/2 - 40, 100, 10)
        love.graphics.setFont(assets.fonts.small)
        love.graphics.printf("Block: " .. enemy.block, 
            enemy.x - 50, enemy.y - enemy.height/2 - 40, 100, "center")
    end
    
    -- Name
    love.graphics.setFont(assets.fonts.medium)
    love.graphics.printf(enemy.name, enemy.x - 100, enemy.y - enemy.height/2 - 70, 200, "center")
    
    -- Intent
    if enemy.currentMove and enemy.moves[enemy.currentMove] then
        local move = enemy.moves[enemy.currentMove]
        love.graphics.setFont(assets.fonts.small)
        love.graphics.printf(move.description, enemy.x - 100, enemy.y + enemy.height/2 + 10, 200, "center")
    end
    
    -- Status effects
    for i, status in ipairs(enemy.status) do
        local statusColor = STATUS[status.type:upper()].color
        love.graphics.setColor(statusColor)
        love.graphics.printf(status.type .. ": " .. status.amount, 
            enemy.x - 100, enemy.y + enemy.height/2 + 30 + (i-1)*20, 200, "center")
    end
    
    love.graphics.setColor(1, 1, 1)
end

-- Draw card
function drawCard(card)
    if not card then return end
    
    love.graphics.push()
    love.graphics.translate(card.x + card.width/2, card.y + card.height/2)
    love.graphics.rotate(card.rotation)
    love.graphics.scale(card.scale, card.scale)
    
    -- Draw card background
    card.imageFn(-card.width/2, -card.height/2, card.width, card.height)
    
    -- Highlight if hovered or selected
    if card.isHovered or card.isSelected then
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("fill", -card.width/2, -card.height/2, card.width, card.height, 10, 10)
    end
    
    -- Draw card border based on rarity
    love.graphics.setColor(card.rarity.color)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", -card.width/2, -card.height/2, card.width, card.height, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Draw card name
    love.graphics.setFont(assets.fonts.small)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(card.name, -card.width/2 + 10, -card.height/2 + 10, card.width - 20, "center")
    
    -- Draw card cost
    if card.cost ~= nil then
        love.graphics.setColor(0.9, 0.9, 0.2)
        love.graphics.circle("fill", -card.width/2 + 15, -card.height/2 + 15, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(tostring(card.cost), -card.width/2 + 10, -card.height/2 + 10, 20, "center")
    end
    
    -- Draw card type
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(card.cardType:upper(), -card.width/2 + 10, card.height/2 - 25, card.width - 20, "right")
    
    -- Draw card description
    love.graphics.printf(card.description, -card.width/2 + 10, card.height/2 - 60, card.width - 20, "center")
    
    love.graphics.pop()
end

-- Draw shop screen
function drawShopScreen()
    -- Dark blue background
    love.graphics.setColor(0.1, 0.2, 0.3)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    
    -- Title
    love.graphics.setFont(assets.fonts.large)
    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.printf("SHOP", 0, 50, SCREEN_WIDTH, "center")
    
    -- Player gold
    love.graphics.setFont(assets.fonts.medium)
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.printf("Gold: " .. player.gold, 0, 100, SCREEN_WIDTH - 50, "right")
    
    -- Draw shop items
    for _, item in ipairs(shopItems) do
        if item.type == "card" then
            -- Draw card with price
            drawCard(item.item)
            
            love.graphics.setFont(assets.fonts.small)
            love.graphics.setColor(0.9, 0.8, 0.2)
            love.graphics.printf(item.cost .. "g", item.item.x, item.item.y + CARD_HEIGHT + 5, CARD_WIDTH, "center")
            
            -- Highlight if hovered
            if item.isHovered then
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", item.item.x, item.item.y, CARD_WIDTH, CARD_HEIGHT, 10, 10)
            end
        elseif item.type == "treasure" then
            -- Draw treasure with price
            item.item.x = item.x
            item.item.y = item.y
            item.item.width = 100
            item.item.height = 100
            item.item.imageFn(item.x, item.y, item.width, item.height)
            
            love.graphics.setFont(assets.fonts.small)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(item.item.name, item.x, item.y + item.height + 5, item.width, "center")
            
            love.graphics.setColor(0.9, 0.8, 0.2)
            love.graphics.printf(item.cost .. "g", item.x, item.y + item.height + 25, item.width, "center")
            
            -- Highlight if hovered
            if item.isHovered then
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", item.x, item.y, item.width, item.height, 5, 5)
            end
        elseif item.type == "heal" then
            -- Draw heal option
            love.graphics.setColor(0.3, 0.8, 0.3)
            love.graphics.rectangle("fill", item.x, item.y, item.width, item.height, 10, 10)
            
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(assets.fonts.small)
            love.graphics.printf("Heal 15 HP", item.x + 5, item.y + 10, item.width - 10, "center")
            love.graphics.setColor(0.9, 0.8, 0.2)
            love.graphics.printf(item.cost .. "g", item.x + 5, item.y + 60, item.width - 10, "center")
            
            -- Highlight if hovered
            if item.isHovered then
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", item.x, item.y, item.width, item.height, 10, 10)
            end
        elseif item.type == "remove" then
            -- Draw card removal option
            love.graphics.setColor(0.8, 0.3, 0.3)
            love.graphics.rectangle("fill", item.x, item.y, item.width, item.height, 10, 10)
            
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(assets.fonts.small)
            love.graphics.printf("Remove Card", item.x + 5, item.y + 10, item.width - 10, "center")
            love.graphics.setColor(0.9, 0.8, 0.2)
            love.graphics.printf(item.cost .. "g", item.x + 5, item.y + 60, item.width - 10, "center")
            
            -- Highlight if hovered
            if item.isHovered then
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", item.x, item.y, item.width, item.height, 10, 10)
            end
        end
    end
    
    -- Continue button
    drawUIElement(uiElements.mapContinue)
end

-- Draw map screen
function drawMapScreen()
    -- Dark blue background
    love.graphics.setColor(0.05, 0.1, 0.2)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    
    -- Title
    love.graphics.setFont(assets.fonts.large)
    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.printf("DIVE DEEPER", 0, 50, SCREEN_WIDTH, "center")
    
    -- Depth
    love.graphics.setFont(assets.fonts.medium)
    love.graphics.setColor(0.7, 0.7, 1)
    love.graphics.printf("Current Depth: " .. player.depth, 0, 100, SCREEN_WIDTH - 50, "right")
    
    -- Draw map nodes
    if #mapNodes == 0 then
        generateMap()
    end
    
    for _, node in ipairs(mapNodes) do
        -- Draw connections first
        for _, conn in ipairs(node.connections) do
            love.graphics.setColor(0.3, 0.3, 0.6)
            love.graphics.line(node.x, node.y, conn.x, conn.y)
        end
    end
    
    for _, node in ipairs(mapNodes) do
        -- Draw node
        if node.available then
            if node.nodeType == "combat" then
                love.graphics.setColor(0.8, 0.3, 0.3)
            elseif node.nodeType == "elite" then
                love.graphics.setColor(0.8, 0.8, 0.3)
            elseif node.nodeType == "boss" then
                love.graphics.setColor(0.8, 0.2, 0.2)
            elseif node.nodeType == "shop" then
                love.graphics.setColor(0.3, 0.8, 0.3)
            elseif node.nodeType == "treasure" then
                love.graphics.setColor(0.8, 0.8, 0.2)
            elseif node.nodeType == "rest" then
                love.graphics.setColor(0.3, 0.3, 0.8)
            end
            
            if node == currentMapNode then
                love.graphics.setColor(1, 1, 1)
            end
            
            love.graphics.circle("fill", node.x, node.y, node.radius)
            
            -- Draw node icon
            love.graphics.setColor(0, 0, 0)
            if node.nodeType == "combat" then
                love.graphics.printf("!", node.x - 10, node.y - 10, 20, "center")
            elseif node.nodeType == "elite" then
                love.graphics.printf("E", node.x - 10, node.y - 10, 20, "center")
            elseif node.nodeType == "boss" then
                love.graphics.printf("B", node.x - 10, node.y - 10, 20, "center")
            elseif node.nodeType == "shop" then
                love.graphics.printf("$", node.x - 10, node.y - 10, 20, "center")
            elseif node.nodeType == "treasure" then
                love.graphics.printf("T", node.x - 10, node.y - 10, 20, "center")
            elseif node.nodeType == "rest" then
                love.graphics.printf("R", node.x - 10, node.y - 10, 20, "center")
            end
        else
            love.graphics.setColor(0.2, 0.2, 0.4)
            love.graphics.circle("fill", node.x, node.y, node.radius)
        end
    end
    
    -- Continue button
    if currentMapNode then
        drawUIElement(uiElements.mapContinue)
    end
    
    -- Draw bubbles
    love.graphics.setColor(1, 1, 1, 0.3)
    for i = 1, 20 do
        love.graphics.circle("fill", 
            math.random(SCREEN_WIDTH), 
            math.random(SCREEN_HEIGHT), 
            math.random(5, 15))
    end
end

-- Generate map nodes
function generateMap()
    mapNodes = {}
    
    -- Create starting node
    local startNode = MapNode:new("start", SCREEN_WIDTH / 2, 100)
    startNode.available = true
    startNode.visited = true
    table.insert(mapNodes, startNode)
    
    -- Create layers of nodes
    local layers = 4
    local nodesPerLayer = 3
    local layerHeight = (SCREEN_HEIGHT - 200) / layers
    
    for layer = 1, layers do
        local yPos = 150 + (layer - 1) * layerHeight
        
        for i = 1, nodesPerLayer do
            local xPos = SCREEN_WIDTH / (nodesPerLayer + 1) * i
            
            local nodeType
            if layer == layers then
                nodeType = "boss"
            else
                local rand = math.random()
                if rand < 0.5 then
                    nodeType = "combat"
                elseif rand < 0.7 then
                    nodeType = "elite"
                elseif rand < 0.8 then
                    nodeType = "shop"
                elseif rand < 0.9 then
                    nodeType = "treasure"
                else
                    nodeType = "rest"
                end
            end
            
            local node = MapNode:new(nodeType, xPos, yPos)
            table.insert(mapNodes, node)
            
            -- Connect to previous layer
            if layer == 1 then
                table.insert(node.connections, startNode)
            else
                local prevLayerNodes = {}
                for _, n in ipairs(mapNodes) do
                    if math.abs(n.y - (yPos - layerHeight)) < 10 then
                        table.insert(prevLayerNodes, n)
                    end
                end
                
                if #prevLayerNodes > 0 then
                    local connections = math.random(1, math.min(2, #prevLayerNodes))
                    for _ = 1, connections do
                        local conn = prevLayerNodes[math.random(1, #prevLayerNodes)]
                        if not table.contains(node.connections, conn) then
                            table.insert(node.connections, conn)
                        end
                    end
                end
            end
        end
    end
    
    -- Mark nodes connected to start as available
    for _, node in ipairs(mapNodes) do
        for _, conn in ipairs(node.connections) do
            if conn.visited then
                node.available = true
                break
            end
        end
    end
    
    -- Set current node to start
    currentMapNode = startNode
end

-- Helper function to check if table contains value
function table.contains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then
            return true
        end
    end
    return false
end

-- Draw reward screen
function drawRewardScreen()
    -- Dark blue background
    love.graphics.setColor(0.05, 0.1, 0.2)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    
    -- Title
    love.graphics.setFont(assets.fonts.large)
    love.graphics.setColor(0.8, 0.8, 1)
    
    if currentMapNode and currentMapNode.nodeType == "treasure" then
        love.graphics.printf("TREASURE ROOM", 0, 50, SCREEN_WIDTH, "center")
    elseif currentMapNode and currentMapNode.nodeType == "rest" then
        love.graphics.printf("REST SITE", 0, 50, SCREEN_WIDTH, "center")
        love.graphics.setFont(assets.fonts.medium)
        love.graphics.printf("You recovered 20 health", 0, 100, SCREEN_WIDTH, "center")
    else
        love.graphics.printf("VICTORY", 0, 50, SCREEN_WIDTH, "center")
        love.graphics.setFont(assets.fonts.medium)
        love.graphics.printf("You gained 25 gold", 0, 100, SCREEN_WIDTH, "center")
    end
    
    -- Draw rewards
    for _, treasure in ipairs(treasures) do
        if treasure.imageFn then
            treasure.imageFn(treasure.x, treasure.y, treasure.width, treasure.height)
            
            -- Highlight if hovered
            if treasure.isHovered then
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", treasure.x, treasure.y, treasure.width, treasure.height)
                
                -- Show tooltip
                tooltipText = {
                    title = treasure.name,
                    description = treasure.description
                }
            end
            
            -- Name
            love.graphics.setFont(assets.fonts.small)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(treasure.name, treasure.x, treasure.y + treasure.height + 5, treasure.width, "center")
        else
            -- Assume it's a card reward
            drawCard(treasure)
            
            -- Highlight if hovered
            if treasure.isHovered then
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", treasure.x, treasure.y, CARD_WIDTH, CARD_HEIGHT, 10, 10)
            end
        end
    end
    
    -- Continue button
    drawUIElement(uiElements.mapContinue)
    
    -- Draw bubbles
    love.graphics.setColor(1, 1, 1, 0.3)
    for i = 1, 20 do
        love.graphics.circle("fill", 
            math.random(SCREEN_WIDTH), 
            math.random(SCREEN_HEIGHT), 
            math.random(5, 15))
    end
end

-- Draw game over screen
function drawGameOverScreen()
    -- Dark background
    love.graphics.setColor(0.1, 0, 0)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    
    -- Game over text
    love.graphics.setFont(assets.fonts.title)
    love.graphics.setColor(0.8, 0.1, 0.1)
    love.graphics.printf("GAME OVER", 0, SCREEN_HEIGHT / 3, SCREEN_WIDTH, "center")
    
    -- Stats
    love.graphics.setFont(assets.fonts.large)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("Depth Reached: " .. player.depth, 0, SCREEN_HEIGHT / 2, SCREEN_WIDTH, "center")
    love.graphics.printf("Gold Collected: " .. player.gold, 0, SCREEN_HEIGHT / 2 + 50, SCREEN_WIDTH, "center")
    
    -- Restart prompt
    love.graphics.setFont(assets.fonts.medium)
    love.graphics.setColor(0.7, 0.7, 1)
    love.graphics.printf("Press any key to return to the surface...", 0, SCREEN_HEIGHT * 3/4, SCREEN_WIDTH, "center")
end

-- Draw animations
function drawAnimations()
    for _, anim in ipairs(animations) do
        if not anim.delay or anim.delay <= 0 then
            local progress = anim.time / anim.duration
            local alpha = 1
            
            if progress > 0.8 then
                alpha = 1 - (progress - 0.8) / 0.2
            end
            
            if anim.type == "damage" then
                love.graphics.setFont(assets.fonts.large)
                love.graphics.setColor(1, 0.2, 0.2, alpha)
                love.graphics.printf("-" .. anim.amount, anim.x - 50, anim.y - 50, 100, "center")
                
            elseif anim.type == "heal" then
                love.graphics.setFont(assets.fonts.large)
                love.graphics.setColor(0.2, 1, 0.2, alpha)
                love.graphics.printf("+" .. anim.amount, anim.x - 50, anim.y - 50, 100, "center")
                
            elseif anim.type == "block" then
                love.graphics.setFont(assets.fonts.medium)
                love.graphics.setColor(0.7, 0.7, 1, alpha)
                love.graphics.printf("+" .. anim.amount .. " Block", anim.x - 50, anim.y - 70, 100, "center")
                
            elseif anim.type == "oxygen" then
                love.graphics.setFont(assets.fonts.medium)
                love.graphics.setColor(0.5, 0.8, 1, alpha)
                love.graphics.printf("+" .. anim.amount .. " Oxygen", anim.x - 50, anim.y - 70, 100, "center")
                
            elseif anim.type == "gold" then
                love.graphics.setFont(assets.fonts.medium)
                love.graphics.setColor(0.9, 0.8, 0.2, alpha)
                love.graphics.printf("+" .. anim.amount .. " Gold", anim.x - 50, anim.y - 70, 100, "center")
                
            elseif anim.type == "energy" then
                love.graphics.setFont(assets.fonts.medium)
                love.graphics.setColor(0.9, 0.9, 0.2, alpha)
                love.graphics.printf("+" .. anim.amount .. " Energy", anim.x - 50, anim.y - 70, 100, "center")
                
            elseif anim.type == "status" then
                local status = STATUS[anim.status:upper()]
                if status then
                    love.graphics.setFont(assets.fonts.small)
                    love.graphics.setColor(status.color[1], status.color[2], status.color[3], alpha)
                    love.graphics.printf(anim.status .. " +" .. anim.amount, anim.x - 50, anim.y - 20, 100, "center")
                end
                
            elseif anim.type == "text" then
                love.graphics.setFont(assets.fonts.medium)
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.printf(anim.text, anim.x - 150, anim.y - 20, 300, "center")
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1)
end

-- Draw tooltips
function drawTooltips()
    if tooltipCard then
        drawCardTooltip(tooltipCard)
    elseif tooltipText then
        drawTextTooltip(tooltipText)
    end
end

-- Draw card tooltip
function drawCardTooltip(card)
    if not card then return end
    
    local x, y = love.mouse.getPosition()
    local width = 300
    local height = 200
    
    -- Adjust position if near screen edge
    if x + width > SCREEN_WIDTH then
        x = x - width - 20
    else
        x = x + 20
    end
    
    if y + height > SCREEN_HEIGHT then
        y = y - height
    end
    
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", x, y, width, height, 10, 10)
    
    -- Border
    love.graphics.setColor(card.rarity.color)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Name
    love.graphics.setFont(assets.fonts.medium)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(card.name, x + 10, y + 10, width - 20, "center")
    
    -- Type and cost
    love.graphics.setFont(assets.fonts.small)
    love.graphics.printf(card.cardType:upper(), x + 10, y + 40, width - 20, "left")
    
    if card.cost ~= nil then
        love.graphics.setColor(0.9, 0.9, 0.2)
        love.graphics.printf("Cost: " .. card.cost, x + 10, y + 40, width - 20, "right")
    end
    
    -- Description
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(card.description, x + 10, y + 70, width - 20, "left")
    
    -- Rarity
    love.graphics.setColor(card.rarity.color)
    love.graphics.printf(card.rarity.name, x + 10, y + height - 30, width - 20, "right")
end

-- Draw text tooltip
function drawTextTooltip(text)
    if not text then return end
    
    local x, y = love.mouse.getPosition()
    local width = 300
    local height = 150
    
    -- Adjust position if near screen edge
    if x + width > SCREEN_WIDTH then
        x = x - width - 20
    else
        x = x + 20
    end
    
    if y + height > SCREEN_HEIGHT then
        y = y - height
    end
    
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", x, y, width, height, 10, 10)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Title
    love.graphics.setFont(assets.fonts.medium)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text.title, x + 10, y + 10, width - 20, "center")
    
    -- Description
    love.graphics.setFont(assets.fonts.small)
    love.graphics.printf(text.description, x + 10, y + 40, width - 20, "left")
end

-- Draw UI element
function drawUIElement(element)
    if not element then return end
    
    -- Button background
    if element.style == "primary" then
        love.graphics.setColor(0.2, 0.5, 0.8)
    else
        love.graphics.setColor(0.3, 0.3, 0.4)
    end
    
    if element.isHovered then
        love.graphics.setColor(0.5, 0.5, 0.6)
    end
    
    if element.isPressed then
        love.graphics.setColor(0.2, 0.2, 0.3)
    end
    
    love.graphics.rectangle("fill", element.x, element.y, element.width, element.height, 10, 10)
    
    -- Button border
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", element.x, element.y, element.width, element.height, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Button text
    love.graphics.setFont(assets.fonts.medium)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(element.text, element.x, element.y + element.height/2 - 10, element.width, "center")
end

-- Mouse pressed event
function love.mousepressed(x, y, button)
    if button == 1 then -- Left click
        -- Check UI elements first
        for _, element in pairs(uiElements) do
            if element.isHovered then
                element.isPressed = true
                return
            end
        end
        
        -- Check shop items
        if gameState == STATE.SHOP then
            for _, item in ipairs(shopItems) do
                if item.isHovered and player.gold >= item.cost then
                    if item.type == "card" then
                        -- Buy card
                        table.insert(deck, cloneCard(item.item))
                        player.gold = player.gold - item.cost
                        table.remove(shopItems, _)
                    elseif item.type == "treasure" then
                        -- Buy treasure
                        table.insert(player.treasures, item.item)
                        player.gold = player.gold - item.cost
                        table.remove(shopItems, _)
                    elseif item.type == "heal" then
                        -- Buy heal
                        player.health = math.min(player.health + item.item, player.maxHealth)
                        player.gold = player.gold - item.cost
                        assets.sounds.heal:play()
                    elseif item.type == "remove" then
                        -- Card removal (would open a card selection UI in full implementation)
                        player.gold = player.gold - item.cost
                    end
                    return
                end
            end
        end
        
        -- Check reward selection
        if gameState == STATE.REWARD then
            for _, treasure in ipairs(treasures) do
                if treasure.isHovered then
                    if treasure.imageFn then
                        -- It's a treasure item
                        table.insert(player.treasures, treasure)
                    else
                        -- It's a card reward
                        table.insert(deck, cloneCard(treasure))
                    end
                    
                    -- Go to map screen
                    gameState = STATE.MAP
                    treasures = {}
                    return
                end
            end
        end
        
        -- Check map nodes
        if gameState == STATE.MAP then
            for _, node in ipairs(mapNodes) do
                local distance = math.sqrt((x - node.x)^2 + (y - node.y)^2)
                if distance <= node.radius and node.available and not node.visited then
                    currentMapNode = node
                    return
                end
            end
        end
        
        -- Check cards in hand
        if gameState == STATE.PLAY then
            for _, card in ipairs(playerHand) do
                if card.isHovered and currentEnergy >= (card.cost or 0) then
                    cardBeingDragged = card
                    card.isSelected = true
                    return
                end
            end
        end
    end
end

-- Mouse released event
function love.mousereleased(x, y, button)
    if button == 1 then -- Left click
        -- Check UI elements
        for _, element in pairs(uiElements) do
            if element.isPressed then
                element.isPressed = false
                if element.isHovered and element.action then
                    element.action()
                end
                return
            end
        end
        
        -- Check card being dragged
        if cardBeingDragged then
            cardBeingDragged.isSelected = false
            
            -- Check if released over enemy
            if currentEnemy then
                local enemyX, enemyY = currentEnemy.x, currentEnemy.y
                local enemyWidth, enemyHeight = currentEnemy.width, currentEnemy.height
                
                if x >= enemyX - enemyWidth/2 and x <= enemyX + enemyWidth/2 and
                   y >= enemyY - enemyHeight/2 and y <= enemyY + enemyHeight/2 then
                    playCard(cardBeingDragged, currentEnemy)
                end
            end
            
            -- Check if released over additional enemies
            for _, enemy in ipairs(enemies) do
                local enemyX, enemyY = enemy.x, enemy.y
                local enemyWidth, enemyHeight = enemy.width, enemy.height
                
                if x >= enemyX - enemyWidth/2 and x <= enemyX + enemyWidth/2 and
                   y >= enemyY - enemyHeight/2 and y <= enemyY + enemyHeight/2 then
                    playCard(cardBeingDragged, enemy)
                    break
                end
            end
            
            cardBeingDragged = nil
        end
    end
end

-- Mouse moved event
function love.mousemoved(x, y, dx, dy)
    -- Update card being dragged
    if cardBeingDragged then
        cardBeingDragged.x = x - CARD_WIDTH/2
        cardBeingDragged.y = y - CARD_HEIGHT/2
        cardBeingDragged.targetX = x - CARD_WIDTH/2
        cardBeingDragged.targetY = y - CARD_HEIGHT/2
    end
end

-- Key pressed event
function love.keypressed(key)
    if gameState == STATE.GAME_OVER then
        startNewGame()
    elseif key == "escape" then
        if gameState == STATE.PLAY or gameState == STATE.SHOP or gameState == STATE.REWARD then
            gameState = STATE.MAP
        elseif gameState == STATE.MAP then
            gameState = STATE.TITLE
        end
    end
end

-- Update tooltip text based on hover state
function love.update(dt)
    -- ... (previous update code remains the same)
    
    -- Update tooltips
    tooltipText = nil
    tooltipCard = nil
    
    if gameState == STATE.PLAY then
        for _, card in ipairs(playerHand) do
            if card.isHovered then
                tooltipCard = card
                break
            end
        end
    elseif gameState == STATE.SHOP then
        for _, item in ipairs(shopItems) do
            if item.isHovered then
                if item.type == "card" then
                    tooltipCard = item.item
                elseif item.type == "treasure" then
                    tooltipText = {
                        title = item.item.name,
                        description = item.item.description
                    }
                elseif item.type == "heal" then
                    tooltipText = {
                        title = "Heal",
                        description = "Restore 15 health points"
                    }
                elseif item.type == "remove" then
                    tooltipText = {
                        title = "Remove Card",
                        description = "Permanently remove a card from your deck"
                    }
                end
                break
            end
        end
    elseif gameState == STATE.REWARD then
        for _, treasure in ipairs(treasures) do
            if treasure.isHovered then
                if treasure.imageFn then
                    tooltipText = {
                        title = treasure.name,
                        description = treasure.description
                    }
                else
                    tooltipCard = treasure
                end
                break
            end
        end
    end
end
