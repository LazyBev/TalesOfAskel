function love.load()
    -- Initialize game with seed
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Load fonts
    smallFont = love.graphics.newFont(12)
    mediumFont = love.graphics.newFont(18)
    largeFont = love.graphics.newFont(32)
    titleFont = love.graphics.newFont(48)
    
    -- Main shaders
    shaders = {
        exploreBackground = love.graphics.newShader[[
            #define halfsqrt3 0.86602540
            #define invsqrt3 0.57735026
            #define tau 6.28318530
            #define pi 3.14159265358979323846264338327950

            extern float iTime;
            extern vec2 iResolution;

            // Integer hash function replacement that doesn't use unsigned integers
            float hash1D(vec2 x)
            {
                // Alternative hash function without uvec types
                vec2 p = fract(x * vec2(123.4, 234.5));
                p += dot(p, p + 23.45);
                return fract(p.x * p.y);
            }

            vec2 hash2D(vec2 x)
            {
                // Alternative hash function without uvec types
                vec2 p = fract(vec2(x.x * 123.4, x.y * 234.5));
                p += dot(p, p + 23.45);
                return fract(vec2(p.x * p.y * 123.4, p.x * p.y * 345.6));
            }

            float hash(vec2 x, float time)
            {
                return 0.5+0.5*sin(tau*hash1D(x)+time);
            }

            //value noise on a triangular lattice
            float tri_noise(vec2 p, float time)
            {
                vec2 q = vec2(p.x-p.y*invsqrt3, p.y*2.0*invsqrt3);
                vec2 iq = floor(q);
                vec2 fq = fract(q);
                float v = 0.0;
                
                float h = step(1.0, fq.x+fq.y); //which half of the unit cell does this triangle lie in
                vec2 c = iq+h;
                vec2 r = p-vec2(c.x+0.5*c.y, halfsqrt3*c.y);
                float s = 1.0-2.0*h;
                r *= s;
                
                //compute barycentric coordinates
                vec3 lambda = vec3(1.0-r.x-invsqrt3*r.y, r.x-invsqrt3*r.y, 2.0*invsqrt3*r.y);
                //quintic////////////////////
                vec3 lambda2 = lambda*lambda;
                vec3 a = 15.0*lambda2*lambda2.zxy*lambda.yzx;
                
                //weights set to be quintic smoothstep along edges, with extra terms to set gradients in the normal direction to 0
                //these magically add up to 1 without correction
                vec3 w = lambda*lambda2*(10.0-15.0*lambda+6.0*lambda2)+a+a.yzx;
                    
                v += w.x*hash(abs(c), time);
                v += w.y*hash(abs(iq+vec2(1.0-h,h)), time);
                v += w.z*hash(abs(iq+vec2(h,1.0-h)), time);
                
                return v;
            }

            float fbm(vec2 p, int octaves, float decay, float time)
            {
                vec2 fwp = fwidth(p);
                float w = dot(step(fwp.xy, fwp.yx), fwp);
                vec2 v = vec2(0.0);
                float weight = 1.0;
                for(int i = 0; i < octaves; i++)
                {
                    v += weight*vec2(tri_noise(p, time)*smoothstep(1.0,0.5,w), 1.0);
                    p *= 2.0*mat2(4.0/5.0, -3.0/5.0, 3.0/5.0, 4.0/5.0);
                    w *= 2.0;
                    weight *= decay;        
                    time *= 1.6;
                }
                return v.x/v.y;
            }

            float fcos(float x)
            {
                float w = fwidth(x);
                return cos(x)*sin(0.5*w)/(0.5*w);
            }

            float get_val(vec2 p)
            {
                float l = length(p);
                float wavf = 0.02;
                float w = fbm(5.0*p+vec2(7.0), 3, 0.6, 0.01*iTime);
                
                float angle = 0.12*iTime-1.0/wavf*0.005*fcos(100.0*l+wavf*iTime)-2.5*log(l+0.01)-0.5*w;
                vec2 cs = vec2(cos(angle), sin(angle));
                p = vec2(p.x*cs.x-p.y*cs.y, p.x*cs.y+p.y*cs.x);
                
                vec2 up = 5.0*p+vec2(7.0);
                float u = fbm(up, 6, 0.6, 0.01*iTime)-0.5;
                u = fcos(10.0*u);
                vec2 vp = 2.0*u+vec2(1.0);
                float v = fbm(vp, 3, 0.3, 10.0+0.1*iTime);
                
                v += 20.0*l*smoothstep(0.0, 0.02, l);
                return v;
            }

            // This is the required function for LÖVE2D shaders
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
            {
                // Normalized pixel coordinates (from 0 to 1)
                vec2 uv = (screen_coords-0.5*iResolution.xy)/iResolution.y;

                vec2 p = 0.1*uv;
                float l = length(p);
                float v = get_val(p);
                
                vec4 fragColor = mix(vec4(0.3,0.55,1.0,1.0), 
                                vec4(0.8,0.22,0.3,1.0),
                                smoothstep(1.0, 1.3, v));
                
                vec2 e = vec2(2.0*dFdx(p.x),0.0);
                vec3 grad = normalize(0.5*vec3((get_val(p+e.xy)-get_val(p-e.xy)), 0.5*(get_val(p+e.yx)-get_val(p-e.yx)), 10.0*e.x));
                
                fragColor.rgb += vec3(0.5)*pow(clamp(dot(grad, normalize(vec3(1.0, 1.0, 1.0))), 0.0, 1.0), 10.0);
                fragColor.rgb += vec3(0.25,0.0,0.0)*pow(clamp(dot(grad, normalize(vec3(-1.0, 1.0, 1.0))), 0.0, 1.0), 10.0);
                fragColor.rgb *= smoothstep(-1.0,0.0, 1.0-v+13.0*l-0.7);
                fragColor.rgb *= smoothstep(-0.1,0.4, abs(v-1.0));
                
                return fragColor * color;
            }
        ]],

        fightBackground = love.graphics.newShader[[
            #define PIXEL_SIZE_FAC 700.0
            #define SPIN_EASE 0.5
            #define colour_2 vec4(0.0,156./255.,1.,1.0)
            #define colour_1 vec4(0.85,0.2,0.2,1.0)
            #define colour_3 vec4(0.0,0.0,0.0,1.0)
            #define spin_amount 0.7
            #define contrast 1.5
            
            // LÖVE uniform variables
            uniform vec2 iResolution;
            uniform float iTime;
            
            // Main shader effect function required by LÖVE
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec4 fragColor;
                // Convert screen coordinates to the format expected by your code
                vec2 fragCoord = screen_coords;
                
                //Convert to UV coords (0-1) and floor for pixel effect
                float pixel_size = length(iResolution.xy)/PIXEL_SIZE_FAC;
                vec2 uv = (floor(fragCoord.xy*(1.0/pixel_size))*pixel_size - 0.5*iResolution.xy)/length(iResolution.xy) - vec2(0.0, 0.0);
                float uv_len = length(uv);
                //Adding in a center swirl, changes with iTime. Only applies meaningfully if the 'spin amount' is a non-zero number
                float speed = (iTime*SPIN_EASE*0.1) + 302.2;
                float new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE*20.*(1.*spin_amount*uv_len + (1. - 1.*spin_amount));
                vec2 mid = (iResolution.xy/length(iResolution.xy))/2.;
                uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);
                //Now add the paint effect to the swirled UV
                uv *= 30.;
                speed = iTime*(1.);
                vec2 uv2 = vec2(uv.x+uv.y);
                for(int i=0; i < 5; i++) {
                    uv2 += uv + cos(length(uv));
                    uv += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),sin(uv2.x - 0.113*speed));
                    uv -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
                }
                //Make the paint amount range from 0 - 2
                float contrast_mod = (0.25*contrast + 0.5*spin_amount + 1.2);
                float paint_res = min(2., max(0.,length(uv)*(0.035)*contrast_mod));
                float c1p = max(0.,1. - contrast_mod*abs(1.-paint_res));
                float c2p = max(0.,1. - contrast_mod*abs(paint_res));
                float c3p = 1. - min(1., c1p + c2p);
                vec4 ret_col = (0.3/contrast)*colour_1 + (1. - 0.3/contrast)*(colour_1*c1p + colour_2*c2p + vec4(c3p*colour_3.rgb, c3p*colour_1.a)) + 0.3*max(c1p*5. - 4., 0.) + 0.4*max(c2p*5. - 4., 0.);
                
                return ret_col;
            }
        ]],

        water = love.graphics.newShader[[
            extern number time;
            extern number depth;
            
            vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc) {
                // Base water distortion
                float distortionScale = 0.005 * min(depth / 200.0, 0.05);
                vec2 tc2 = tc;
                tc2.x += distortionScale * sin(tc.y * 10.0 + time);
                tc2.y += distortionScale * sin(tc.x * 10.0 + time * 0.5);
                
                // Depth-based color
                vec4 pixel = Texel(tex, tc2);
                float depth_factor = min(depth / 500.0, 0.5);
                vec3 deep_color = vec3(0.05, 0.05, 0.1);
                pixel.rgb = mix(pixel.rgb, deep_color, depth_factor);
                
                return pixel * color;
            }
        ]],
        
        cardShader = love.graphics.newShader[[
            extern number time;
            extern vec3 cardColor;
            extern number rarity;
            extern number hover;
            extern number selected;
            
            vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc) {
                vec2 uv = tc;
                float edge = 0.05;
                
                // Card shape with rounded corners
                vec2 center = vec2(0.5, 0.5);
                float radius = 0.45;
                float dist = distance(uv, center);
                
                // Alpha calculation (fixed)
                float alpha = 1.0 - smoothstep(radius - 0.01, radius, dist);
                
                // Border calculation (added missing declaration)
                float border = smoothstep(radius - 0.01, radius, dist) * 
                            (1.0 - smoothstep(radius, radius + 0.02, dist));
                
                // Border colors
                vec3 borderColor = vec3(0.5);
                if (rarity > 2.5) borderColor = vec3(0.8, 0.6, 0.2);
                else if (rarity > 1.5) borderColor = vec3(0.5, 0.3, 0.8);
                
                // Hover/selection effects
                float glow = hover * (0.3 + 0.2 * sin(time * 3.0));
                float pulse = selected * (0.1 + 0.05 * sin(time * 5.0));
                
                // Final color composition
                vec3 baseColor = cardColor * (1.0 - border);
                vec3 finalColor = mix(baseColor, borderColor, border);
                finalColor = mix(finalColor, vec3(1.0), glow);
                finalColor = mix(finalColor, vec3(1.0, 0.9, 0.5), pulse);
                
                return vec4(finalColor, alpha * color.a);
            }
        ]],
        
        enemyShader = love.graphics.newShader[[
            extern number time;
            extern number health;
            extern number maxHealth;
            extern number animState;
            extern vec3 baseColor;
            extern number enemyType;
            
            float random(vec2 st) {
                return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
            }
            
            vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc) {
                vec2 uv = tc;
                vec2 center = vec2(0.5, 0.5);
                float dist = distance(uv, center);
                
                // Creature shape
                float radius = 0.4 + 0.1 * sin(time * 0.5 + uv.x * 5.0);
                float body = smoothstep(radius, radius-0.01, dist);
                
                // Health effect
                float healthRatio = health / maxHealth;
                vec3 healthColor = mix(vec3(0.8, 0.2, 0.2), baseColor, healthRatio);
                
                // Animation state (0-1)
                float pulse = 0.05 * sin(time * 3.0) * (1.0 - animState);
                
                // Tentacles/appendages
                float tentacles = 0.0;
                float tentacleCount = 5.0 + floor(enemyType * 2.0);
                
                for (float i = 0.0; i < tentacleCount; i++) {
                    float angle = time * 0.5 + i * (6.283 / tentacleCount);
                    vec2 dir = vec2(cos(angle), sin(angle));
                    float tentacleDist = distance(uv, center + dir * 0.3);
                    float tentacleWidth = 0.05 + 0.03 * sin(time * 2.0 + i);
                    tentacles += smoothstep(tentacleWidth, tentacleWidth-0.01, tentacleDist) * 
                                 (1.0 - smoothstep(tentacleWidth-0.01, tentacleWidth-0.02, tentacleDist));
                }
                
                // Eyes
                float eyes = 0.0;
                if (enemyType < 1.5) {
                    eyes += smoothstep(0.1, 0.09, distance(uv, center + vec2(-0.15, -0.1)));
                    eyes += smoothstep(0.1, 0.09, distance(uv, center + vec2(0.15, -0.1)));
                } else {
                    eyes += smoothstep(0.15, 0.14, distance(uv, center));
                }
                
                // Combine elements
                vec3 finalColor = healthColor;
                finalColor = mix(finalColor, vec3(0.9), tentacles);
                finalColor = mix(finalColor, vec3(0.1), eyes);
                finalColor = mix(finalColor, vec3(1.0), pulse);
                
                return vec4(finalColor, max(body, max(tentacles, eyes)) * color.a);
            }
        ]],
        
        bubbleShader = love.graphics.newShader[[
            extern number time;
            
            vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc) {
                vec2 uv = tc;
                vec2 center = vec2(0.5, 0.5);
                float dist = distance(uv, center);
                
                // Bubble shape
                float radius = 0.4;
                float alpha = smoothstep(radius, radius-0.01, dist);
                
                // Bubble highlights
                float highlight = 0.0;
                highlight += smoothstep(0.3, 0.0, distance(uv, center + vec2(0.1, 0.1)));
                highlight *= 0.5 + 0.5 * sin(time * 2.0);
                
                // Refraction effect
                vec2 refractedUV = uv + vec2(
                    sin(time + uv.y * 10.0) * 0.02,
                    cos(time + uv.x * 8.0) * 0.02
                );
                
                // Final color
                vec3 bubbleColor = vec3(0.7, 0.8, 0.9);
                bubbleColor = mix(bubbleColor, vec3(1.0), highlight);
                
                return vec4(bubbleColor, alpha * color.a);
            }
        ]],
        
        buttonShader = love.graphics.newShader[[
            extern number time;
            extern number hover;
            extern number pulse;
            
            vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc) {
                vec2 uv = tc;
                
                // Button shape with rounded corners
                float edge = 0.1;
                float rounded = smoothstep(edge, 0.0, min(min(uv.x, uv.y), min(1.0-uv.x, 1.0-uv.y)));
                
                // Base color
                vec3 baseColor = vec3(0.2, 0.3, 0.5);
                
                // Hover effect
                float glow = hover * (0.2 + 0.1 * sin(time * 3.0));
                
                // Pulse effect
                float pulseEffect = pulse * (0.1 + 0.05 * sin(time * 5.0));
                
                // Combine effects
                vec3 finalColor = mix(baseColor, vec3(0.3, 0.5, 0.7), glow);
                finalColor = mix(finalColor, vec3(1.0), pulseEffect);
                
                return vec4(finalColor, rounded * color.a);
            }
        ]]
    }
    
    -- Initialize particle systems with shaders
    effectsSettings = {
        bubbles = love.graphics.newParticleSystem(love.graphics.newCanvas(32, 32), 100),
        dustParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(16, 16), 100)
    }

    -- Configure particles
    effectsSettings.bubbles:setParticleLifetime(3, 8)
    effectsSettings.bubbles:setEmissionRate(5)
    effectsSettings.bubbles:setSizes(0.2, 0.5)
    effectsSettings.bubbles:setLinearAcceleration(0, -20, 0, -10)
    effectsSettings.bubbles:setColors(1, 1, 1, 1, 1, 1, 1, 0)
    effectsSettings.bubbles:setSpeed(10, 30)

    effectsSettings.dustParticles:setParticleLifetime(5, 10)
    effectsSettings.dustParticles:setEmissionRate(10)
    effectsSettings.dustParticles:setSizes(0.1, 0.3)
    effectsSettings.dustParticles:setLinearAcceleration(-5, -5, 5, 5)
    effectsSettings.dustParticles:setColors(0.8, 0.8, 1, 0.1, 0.8, 0.8, 1, 0)
    effectsSettings.dustParticles:setSpeed(2, 5)
    effectsSettings.dustParticles:setSpin(0.1, 0.5)
    
    -- Initialize game states and data
    initGameStates()
    initGameData()
    newGame()
end

function initGameStates()
    GAME_STATE = {
        MENU = 1,
        EXPLORE = 2,
        COMBAT = 3,
        GAME_OVER = 4
    }
    currentState = GAME_STATE.MENU
    
    -- UI elements with animation properties
    buttons = {
        startButton = {x = 300, y = 300, w = 200, h = 50, text = "Dive In", hover = false, scale = 1, pulse = 0},
        restartButton = {x = 300, y = 350, w = 200, h = 50, text = "Try Again", hover = false, scale = 1, pulse = 0},
        endTurnButton = {x = 650, y = 400, w = 100, h = 50, text = "End Turn", hover = false, scale = 1, pulse = 0},
        diveButton = {x = 100, y = 350, w = 150, h = 40, text = "Dive Deeper", hover = false, scale = 1, pulse = 0},
        exploreButton = {x = 325, y = 350, w = 150, h = 40, text = "Explore Area", hover = false, scale = 1, pulse = 0},
        ascendButton = {x = 550, y = 350, w = 150, h = 40, text = "Ascend", hover = false, scale = 1, pulse = 0}
    }
    
    -- Card visuals
    cardVisuals = {
        width = 100,
        height = 140,
        cornerRadius = 10,
        hoverLift = 30,
        hoverScale = 1.15,
        suitSymbols = {"♠", "♥", "♦", "♣"},
        ranks = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"},
        colors = {
            attack = {0.8, 0.2, 0.2},
            defense = {0.2, 0.5, 0.8},
            utility = {0.4, 0.8, 0.4},
            special = {0.8, 0.6, 0.2}
        }
    }

    cards = {
        -- Player cards
        harpoon = {
            name = "Harpoon",
            description = "Deal 8 damage",
            type = "attack",
            cost = 1,
            suit = 1,  -- ♠
            rank = 7,
            play = function(target)
                local damage = 8 - (target.defense or 0)
                damage = math.max(1, damage)
                target.health = target.health - damage
                addDamageEffect(target, damage)
                return string.format("Harpoon strikes for %d damage!", damage)
            end
        },
        net = {
            name = "Net",
            description = "5 damage\n-2 enemy defense",
            type = "utility",
            cost = 2,
            suit = 3,  -- ♦
            rank = 5,
            play = function(target)
                local damage = 5 - math.floor((target.defense or 0) / 2)
                damage = math.max(1, damage)
                target.health = target.health - damage
                target.defense = math.max(0, (target.defense or 0) - 2)
                addDamageEffect(target, damage)
                return string.format("Net deals %d damage and reduces defense!", damage)
            end
        },
        -- Update other cards similarly with type/suit/rank/cost
    }
    
    -- Animation timers
    animations = {
        time = 0,
        cards = {},
        globalPulse = 0,
        damageNumbers = {},
        healNumbers = {}
    }
end

function initGameData()
    -- Player stats
    player = {
        health = 100,
        maxHealth = 100,
        depth = 0,
        pressure = 0,
        maxPressure = 100,
        oxygen = 100,
        maxOxygen = 100,
        inventory = {},
        deck = {},
        hand = {},
        discard = {},
        gold = 0,
        energy = 3,
        maxEnergy = 3
    }
    
    -- Enemy data
    enemies = {
        {
            name = "Abyssal Lurker",
            health = 30,
            maxHealth = 30,
            attack = 5,
            defense = 2,
            description = "A shadowy creature that hides in the darkness",
            cards = {"lurk", "dark_strike", "abyssal_gaze"},
            color = {0.2, 0.1, 0.3},
            type = 1
        },
        {
            name = "Pressure Wraith",
            health = 45,
            maxHealth = 45,
            attack = 7,
            defense = 3,
            description = "An ethereal entity formed from crushing depths",
            cards = {"pressure_surge", "crush", "drown"},
            color = {0.3, 0.1, 0.4},
            type = 2
        },
        {
            name = "Leviathan Spawn",
            health = 60,
            maxHealth = 60,
            attack = 10,
            defense = 5,
            description = "Offspring of ancient deep sea predators",
            cards = {"tentacle_lash", "abyssal_roar", "devour"},
            color = {0.4, 0.1, 0.2},
            type = 3
        }
    }
    
    -- Card definitions
    cards = {
        -- Player cards
        dive = {
            name = "Dive Deeper",
            description = "Go deeper (+10 depth, +5 pressure)",
            color = {0.2, 0.5, 0.8},
            rarity = 1,
            cost = 1,
            suit = 2,
            rank = 1,
            play = function()
                player.depth = player.depth + 10
                player.pressure = math.min(player.pressure + 5, player.maxPressure)
                return "You descend deeper into the abyss..."
            end
        },
        ascend = {
            name = "Ascend",
            description = "Go up (-5 depth, -10 pressure)",
            color = {0.2, 0.7, 0.9},
            rarity = 1,
            play = function()
                player.depth = math.max(0, player.depth - 5)
                player.pressure = math.max(0, player.pressure - 10)
                return "You rise toward the surface..."
            end
        },
        decompress = {
            name = "Decompress",
            description = "Reduce pressure (-15 pressure)",
            color = {0.4, 0.6, 0.9},
            rarity = 2,
            play = function()
                player.pressure = math.max(0, player.pressure - 15)
                return "You take time to decompress..."
            end
        },
        harpoon = {
            name = "Harpoon",
            description = "Attack (8 damage)",
            color = {0.8, 0.3, 0.2},
            rarity = 1,
            play = function(target)
                local damage = 8 - target.defense
                damage = math.max(1, damage)
                target.health = target.health - damage
                addDamageEffect(target, damage)
                return string.format("Harpoon strikes for %d damage!", damage)
            end
        },
        net = {
            name = "Entangling Net",
            description = "Attack (5 damage) and reduce enemy defense by 2",
            color = {0.5, 0.3, 0.8},
            rarity = 2,
            play = function(target)
                local damage = 5 - math.floor(target.defense / 2)
                damage = math.max(1, damage)
                target.health = target.health - damage
                target.defense = math.max(0, target.defense - 2)
                addDamageEffect(target, damage)
                return string.format("Net deals %d damage and reduces defense!", damage)
            end
        },
        lantern = {
            name = "Diving Lantern",
            description = "Heal 10 HP and reduce pressure by 5",
            color = {0.9, 0.9, 0.2},
            rarity = 2,
            play = function()
                player.health = math.min(player.health + 10, player.maxHealth)
                player.pressure = math.max(0, player.pressure - 5)
                addHealEffect(10)
                return "The lantern's glow comforts you..."
            end
        },
        salvage = {
            name = "Salvage",
            description = "Gain a random item and 5-15 gold",
            color = {0.8, 0.6, 0.3},
            rarity = 2,
            play = function()
                local items = {"oxygen_tank", "pressure_suit", "ancient_artifact"}
                local item = items[math.random(#items)]
                table.insert(player.inventory, item)
                local gold = math.random(5, 15)
                player.gold = player.gold + gold
                return string.format("You salvage %s and %d gold from the depths!", item:gsub("_", " "), gold)
            end
        },
        sonic_pulse = {
            name = "Sonic Pulse",
            description = "Deal 6 damage to enemy and reduce pressure by 8",
            color = {0.3, 0.5, 0.9},
            rarity = 3,
            play = function(target)
                local damage = 6
                target.health = target.health - damage
                player.pressure = math.max(0, player.pressure - 8)
                addDamageEffect(target, damage)
                return "Sonic waves disrupt the water around you!"
            end
        },
        
        -- Enemy cards
        lurk = {
            name = "Lurk",
            description = "Enemy gains 3 defense",
            color = {0.2, 0.2, 0.3},
            play = function(self)
                self.defense = self.defense + 3
                return string.format("%s lurks in the darkness...", self.name)
            end
        },
        dark_strike = {
            name = "Dark Strike",
            description = "Attack for 7 damage",
            color = {0.3, 0.1, 0.2},
            play = function(self)
                local damage = 7
                player.health = player.health - damage
                addPlayerDamageEffect(damage)
                return string.format("%s strikes for %d damage!", self.name, damage)
            end
        },
        abyssal_gaze = {
            name = "Abyssal Gaze",
            description = "Increase your pressure by 15",
            color = {0.1, 0.1, 0.3},
            play = function(self)
                player.pressure = math.min(player.pressure + 15, player.maxPressure)
                return string.format("%s's gaze increases your pressure!", self.name)
            end
        },
        pressure_surge = {
            name = "Pressure Surge",
            description = "Increase your pressure by 20",
            color = {0.2, 0.2, 0.4},
            play = function(self)
                player.pressure = math.min(player.pressure + 20, player.maxPressure)
                return "The crushing pressure intensifies!"
            end
        },
        crush = {
            name = "Crush",
            description = "Attack for 10 damage",
            color = {0.4, 0.1, 0.1},
            play = function(self)
                local damage = 10
                player.health = player.health - damage
                addPlayerDamageEffect(damage)
                return string.format("%s crushes you for %d damage!", self.name, damage)
            end
        },
        drown = {
            name = "Drown",
            description = "Lose 15 oxygen",
            color = {0.1, 0.3, 0.4},
            play = function(self)
                player.oxygen = math.max(0, player.oxygen - 15)
                return "You feel your breath slipping away..."
            end
        },
        tentacle_lash = {
            name = "Tentacle Lash",
            description = "Attack for 12 damage",
            color = {0.5, 0.2, 0.2},
            play = function(self)
                local damage = 12
                player.health = player.health - damage
                addPlayerDamageEffect(damage)
                return string.format("%s lashes out for %d damage!", self.name, damage)
            end
        },
        abyssal_roar = {
            name = "Abyssal Roar",
            description = "Attack for 8 damage and increase pressure by 10",
            color = {0.4, 0.2, 0.3},
            play = function(self)
                local damage = 8
                player.health = player.health - damage
                player.pressure = math.min(player.pressure + 10, player.maxPressure)
                addPlayerDamageEffect(damage)
                return string.format("%s roars, dealing %d damage!", self.name, damage)
            end
        },
        devour = {
            name = "Devour",
            description = "Attack for 15 damage and heal enemy for 10",
            color = {0.6, 0.1, 0.1},
            play = function(self)
                local damage = 15
                player.health = player.health - damage
                self.health = math.min(self.health + 10, self.maxHealth)
                addPlayerDamageEffect(damage)
                return string.format("%s devours part of you, healing itself!", self.name)
            end
        }
    }
    
    -- Starting deck
    startingDeck = {
        "dive", "dive", "dive",
        "ascend", "ascend",
        "decompress",
        "harpoon", "harpoon", "harpoon",
        "net", "net",
        "lantern",
        "salvage",
        "sonic_pulse"
    }
    
    -- Game variables
    currentEnemy = nil
    combatLog = {}
    exploreMessage = ""
    selectedCard = nil
end

function newGame()
    -- Reset player
    player.health = 100
    player.maxHealth = 100
    player.depth = 0
    player.pressure = 0
    player.oxygen = 100
    player.inventory = {}
    player.deck = {}
    player.discard = {}
    player.gold = 0
    
    -- Create deck from starting cards
    for _, cardName in ipairs(startingDeck) do
        table.insert(player.deck, cardName)
    end
    
    -- Shuffle deck
    shuffleDeck()
    
    -- Game variables
    currentEnemy = nil
    combatLog = {}
    exploreMessage = "You begin your descent into the abyss..."
    selectedCard = nil
    
    -- Reset animations
    animations.damageNumbers = {}
    animations.healNumbers = {}
    animations.cards = {}
    
    -- Draw initial hand
    drawHand()
end

function shuffleDeck()
    for i = #player.deck, 2, -1 do
        local j = math.random(i)
        player.deck[i], player.deck[j] = player.deck[j], player.deck[i]
    end
end

function dealHand()
    -- Move current hand to discard
    for _, card in ipairs(player.hand) do
        table.insert(player.discard, card)
    end
    player.hand = {}
    
    -- If deck is empty, shuffle discard into deck
    if #player.deck == 0 then
        if #player.discard == 0 then return end
        player.deck = player.discard
        player.discard = {}
        shuffleDeck()
        table.insert(combatLog, "Your discard pile is shuffled into your deck.")
    end
    
    -- Draw up to 5 cards
    for i = 1, 5 do
        if #player.deck > 0 then
            local card = table.remove(player.deck, 1)
            table.insert(player.hand, card)
            
            -- Initialize card animation state
            if not animations.cards[card] then
                animations.cards[card] = {
                    hover = false,
                    scale = 1,
                    rotation = (math.random() - 0.5) * 0.1,
                    offset = {x = 0, y = 0},
                    timer = 0
                }
            end
        end
    end
end

function drawCardFront(x, y, cardName, anim)
    local card = cards[cardName]
    local suitSymbol = cardVisuals.suitSymbols[card.suit or 1]
    local rank = cardVisuals.ranks[card.rank or 1]
    local color = cardVisuals.colors[card.type or "attack"]
    
    -- Card background
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.rectangle("fill", x, y, cardVisuals.width, cardVisuals.height, cardVisuals.cornerRadius)
    
    -- Border
    love.graphics.setColor(color)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, cardVisuals.width, cardVisuals.height, cardVisuals.cornerRadius)
    
    -- Suit and rank
    love.graphics.setFont(mediumFont)
    love.graphics.setColor(color)
    -- Top left
    love.graphics.print(rank, x + 8, y + 8)
    love.graphics.print(suitSymbol, x + 8, y + 28)
    -- Bottom right
    love.graphics.print(rank, x + cardVisuals.width - 28, y + cardVisuals.height - 38)
    love.graphics.print(suitSymbol, x + cardVisuals.width - 28, y + cardVisuals.height - 18)
    
    -- Card name
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setFont(smallFont)
    love.graphics.printf(card.name, x + 10, y + 60, cardVisuals.width - 20, "center")
    
    -- Description
    love.graphics.setFont(smallFont)
    love.graphics.printf(card.description, x + 15, y + 90, cardVisuals.width - 30, "center")
    
    -- Cost bubble
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.circle("fill", x + cardVisuals.width - 25, y + 20, 12)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setFont(smallFont)
    love.graphics.print(tostring(cards[cardName].cost), x + cardVisuals.width - 30, y + 13)
end

function drawHand()
    for i, cardName in ipairs(player.hand) do
        local card = cards[cardName]
        local anim = animations.cards[cardName] or {scale = 1, rotation = 0, offset = {x = 0, y = 0}}
        
        local baseX = 150 + (i-1)*110
        local baseY = 400
        local x = baseX + anim.offset.x
        local y = baseY - anim.offset.y
        
        -- Transform for hover/selection
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(anim.scale, anim.scale)
        love.graphics.rotate(anim.rotation)
        
        -- Draw card
        drawCardFront(-cardVisuals.width/2, -cardVisuals.height/2, cardName, anim)
        
        love.graphics.pop()
    end
end

function playCard(cardIndex, target)
    if cardIndex < 1 or cardIndex > #player.hand then return end
    
    local cardName = player.hand[cardIndex]
    local card = cards[cardName]
    
    if player.energy < card.cost then
        table.insert(combatLog, "Not enough energy!")
        return
    end
    
    player.energy = player.energy - card.cost
    
    local cardName = player.hand[cardIndex]
    local card = cards[cardName]
    local message
    
    -- Card play animation
    animations.cards[cardName].timer = 0
    animations.cards[cardName].scale = 1.5
    
    -- Execute card effect
    if target then
        message = card.play(target)
    else
        message = card.play()
    end
    
    -- Move card to discard
    table.insert(player.discard, cardName)
    table.remove(player.hand, cardIndex)
    
    -- Add to combat log
    table.insert(combatLog, message)
    
    -- Enemy turn if in combat
    if currentState == GAME_STATE.COMBAT then
        enemyTurn()
    end
    
    -- Check for death
    checkGameState()
end

function enemyTurn()
    if not currentEnemy or currentEnemy.health <= 0 then return end
    
    -- Enemy plays a random card
    local cardName = currentEnemy.cards[math.random(#currentEnemy.cards)]
    local card = cards[cardName]
    local message = card.play(currentEnemy)
    
    table.insert(combatLog, message)
    
    -- Check for death
    checkGameState()
end

function checkGameState()
    -- Check player death
    if player.health <= 0 or player.oxygen <= 0 or player.pressure >= player.maxPressure then
        currentState = GAME_STATE.GAME_OVER
        return
    end
    
    -- Check enemy death
    if currentState == GAME_STATE.COMBAT and currentEnemy and currentEnemy.health <= 0 then
        table.insert(combatLog, string.format("You defeated the %s!", currentEnemy.name))
        
        -- Award gold and possible items
        local goldReward = math.random(10, 20) + math.floor(player.depth / 10)
        player.gold = player.gold + goldReward
        table.insert(combatLog, string.format("You gain %d gold!", goldReward))
        
        -- Chance to find item
        if math.random() < 0.3 then
            local items = {"oxygen_tank", "pressure_suit", "ancient_artifact"}
            local item = items[math.random(#items)]
            table.insert(player.inventory, item)
            table.insert(combatLog, string.format("You found %s!", item:gsub("_", " ")))
        end
        
        currentState = GAME_STATE.EXPLORE
        exploreMessage = "The creature sinks into the darkness..."
        currentEnemy = nil
    end
end

function startCombat()
    -- Random enemy based on depth
    local enemyTier = math.min(math.floor(player.depth / 100) + 1, #enemies)
    currentEnemy = deepcopy(enemies[enemyTier])
    
    -- Scale enemy with depth
    local scale = 1 + (player.depth / 200)
    currentEnemy.health = math.floor(currentEnemy.health * scale)
    currentEnemy.maxHealth = currentEnemy.health
    currentEnemy.attack = math.floor(currentEnemy.attack * scale)
    
    currentState = GAME_STATE.COMBAT
    combatLog = {string.format("A %s appears from the depths!", currentEnemy.name)}
    
    -- Add combat entrance animation
    currentEnemy.animation = {
        entrance = true,
        timer = 0,
        duration = 1.0
    }
    
    drawHand()
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function addDamageEffect(target, amount)
    table.insert(animations.damageNumbers, {
        x = 650,
        y = 150,
        value = amount,
        color = {1, 0.3, 0.3},
        timer = 0,
        duration = 1.5,
        velocity = {x = (math.random() - 0.5) * 20, y = -30}
    })
end

function addPlayerDamageEffect(amount)
    table.insert(animations.damageNumbers, {
        x = 100,
        y = 80,
        value = amount,
        color = {1, 0.3, 0.3},
        timer = 0,
        duration = 1.5,
        velocity = {x = (math.random() - 0.5) * 20, y = -30}
    })
end

function addHealEffect(amount)
    table.insert(animations.healNumbers, {
        x = 100,
        y = 80,
        value = amount,
        color = {0.3, 1, 0.3},
        timer = 0,
        duration = 1.5,
        velocity = {x = (math.random() - 0.5) * 20, y = -30}
    })
end

function newGame()
    -- Reset player
    player.health = 100
    player.maxHealth = 100
    player.depth = 0
    player.pressure = 1
    player.oxygen = 100
    player.inventory = {}
    player.deck = {}
    player.discard = {}
    player.gold = 0
    
    -- Create deck from starting cards
    for _, cardName in ipairs(startingDeck) do
        table.insert(player.deck, cardName)
    end
    
    -- Shuffle deck
    shuffleDeck()
    
    -- Game variables
    currentEnemy = nil
    combatLog = {}
    exploreMessage = "You begin your descent into the abyss..."
    selectedCard = nil
    
    -- Reset animations
    animations.damageNumbers = {}
    animations.healNumbers = {}
    animations.cards = {}
    
    -- Draw initial hand
    dealHand()
end

function love.update(dt)
    -- Update animation timer
    animations.time = animations.time + dt
    animations.globalPulse = animations.globalPulse + dt
    
    -- Update particles
    effectsSettings.bubbles:update(dt)
    effectsSettings.dustParticles:update(dt)
    
    -- Update shader variables
    shaders.exploreBackground:send("iTime", love.timer.getTime())
    shaders.exploreBackground:send("iResolution", {love.graphics.getWidth(), love.graphics.getHeight()})
    shaders.fightBackground:send("iTime", love.timer.getTime())
    shaders.fightBackground:send("iResolution", {love.graphics.getWidth(), love.graphics.getHeight()})
    shaders.water:send("time", animations.time)
    shaders.water:send("depth", player.depth)
    
    -- Update button animations
    for _, button in pairs(buttons) do
        if button.hover then
            button.scale = math.min(button.scale + dt * 3, 1.1)
            button.pulse = math.min(button.pulse + dt * 2, 1)
        else
            button.scale = math.max(button.scale - dt * 3, 1.0)
            button.pulse = math.max(button.pulse - dt * 2, 0)
        end
    end
    
    -- Update card animations
    for i, cardName in ipairs(player.hand) do
        local anim = animations.cards[cardName]
        if anim then
            anim.timer = anim.timer + dt
            
            if anim.hover or selectedCard == i then
                anim.scale = math.min(anim.scale + dt * 3, cardVisuals.hoverScale)
                anim.offset.y = math.min(anim.offset.y + dt * 60, cardVisuals.hoverLift)
            else
                anim.scale = math.max(anim.scale - dt * 3, 1.0)
                anim.offset.y = math.max(anim.offset.y - dt * 60, 0)
            end
            
            -- Reset after play animation
            if anim.scale > 1.5 then
                anim.scale = math.max(anim.scale - dt * 5, 1.0)
            end
        end
    end
    
    -- Update enemy animations
    if currentEnemy and currentEnemy.animation then
        currentEnemy.animation.timer = currentEnemy.animation.timer + dt
        if currentEnemy.animation.timer > currentEnemy.animation.duration then
            currentEnemy.animation.entrance = false
        end
    end
    
    -- Update damage/heal number animations
    for i = #animations.damageNumbers, 1, -1 do
        local effect = animations.damageNumbers[i]
        effect.timer = effect.timer + dt
        effect.x = effect.x + effect.velocity.x * dt
        effect.y = effect.y + effect.velocity.y * dt
        effect.velocity.y = effect.velocity.y + 20 * dt -- Gravity
        if effect.timer >= effect.duration then
            table.remove(animations.damageNumbers, i)
        end
    end
    
    for i = #animations.healNumbers, 1, -1 do
        local effect = animations.healNumbers[i]
        effect.timer = effect.timer + dt
        effect.x = effect.x + effect.velocity.x * dt
        effect.y = effect.y + effect.velocity.y * dt
        effect.velocity.y = effect.velocity.y + 20 * dt -- Gravity
        if effect.timer >= effect.duration then
            table.remove(animations.healNumbers, i)
        end
    end
    
    -- Oxygen depletion
    if currentState ~= GAME_STATE.MENU and currentState ~= GAME_STATE.GAME_OVER then
        player.oxygen = math.max(0, player.oxygen - dt * 0.2)
        if player.oxygen <= 0 then
            currentState = GAME_STATE.GAME_OVER
        end
    end
    
    -- Mouse hover detection
    local mx, my = love.mouse.getPosition()
    
    -- Check button hovers
    for _, btn in pairs(buttons) do
        btn.hover = (mx >= btn.x and mx <= btn.x + btn.w and
                     my >= btn.y and my <= btn.y + btn.h)
    end
    
    -- Check card hovers in combat
    if currentState == GAME_STATE.COMBAT then
        local cardHovered = false
        for i, cardName in ipairs(player.hand) do
            local anim = animations.cards[cardName]
            if anim then
                local x = 150 + (i-1)*110
                local y = 400 + anim.offset.y
                local w = cardVisuals.width * anim.scale
                local h = cardVisuals.height * anim.scale
                
                local wasHovering = anim.hover
                anim.hover = (mx >= x - w/2 + cardVisuals.width/2 and 
                              mx <= x + w/2 + cardVisuals.width/2 and
                              my >= y - h/2 + cardVisuals.height/2 and 
                              my <= y + h/2 + cardVisuals.height/2)
                
                if anim.hover then cardHovered = true end
            end
        end
        
        if not cardHovered and selectedCard then
            -- Keep the selected card "hovering" visually
            local cardName = player.hand[selectedCard]
            if animations.cards[cardName] then
                animations.cards[cardName].hover = true
            end
        end
    end
    
    -- Generate bubbles based on depth
    if math.random() < 0.01 * (1 + player.depth/100) then
        effectsSettings.bubbles:emit(1)
    end
    
    -- Generate dust particles
    if math.random() < 0.02 then
        effectsSettings.dustParticles:emit(1)
    end
end

function love.draw()
    -- Draw particles
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(effectsSettings.bubbles)
    love.graphics.draw(effectsSettings.dustParticles)
    
    -- Reset shader for UI elements
    love.graphics.setShader()
    
    -- Draw based on game state
    if currentState == GAME_STATE.MENU then
        -- Apply water shader to everything
        love.graphics.setShader(shaders.water)
        
        -- Background with depth-based color
        local depthColor = {
            0.1 - math.min(0.08, player.depth / 1000),
            0.3 - math.min(0.25, player.depth / 800),
            0.5 - math.min(0.35, player.depth / 600)
        }
        love.graphics.setColor(depthColor)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        drawMenu()
    elseif currentState == GAME_STATE.EXPLORE then
        love.graphics.setShader(shaders.exploreBackground)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setShader()
        drawExplore()
    elseif currentState == GAME_STATE.COMBAT then
        love.graphics.setShader(shaders.fightBackground)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setShader()
        drawCombat()
    elseif currentState == GAME_STATE.GAME_OVER then
        drawGameOver()
    end
    
    -- Draw floating numbers
    drawFloatingNumbers()
end

function drawMenu()
    -- Title with procedural effect
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.8, 0.9, 1)
    
    local title = "THE DEPTHS"
    local titleWidth = titleFont:getWidth(title)
    local titleX = love.graphics.getWidth()/2 - titleWidth/2
    local titleY = 100
    
    -- Draw title with multiple layers for glow effect
    for i = 1, 3 do
        local scale = 1 + (i * 0.03)
        local alpha = 0.7 - (i * 0.2)
        love.graphics.setColor(0.5, 0.7, 1, alpha)
        love.graphics.print(title, titleX - (titleWidth * (scale-1))/2, 
                           titleY - (titleFont:getHeight() * (scale-1))/2, 
                           0, scale, scale)
    end
    
    love.graphics.setColor(0.8, 0.9, 1)
    love.graphics.print(title, titleX, titleY)
    
    -- Subtitle
    love.graphics.setFont(mediumFont)
    love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
    local subtitle = "A deep sea card adventure"
    local subtitleWidth = mediumFont:getWidth(subtitle)
    love.graphics.print(subtitle, love.graphics.getWidth()/2 - subtitleWidth/2, 170)
    
    -- Start button
    drawButton(buttons.startButton)
end

function drawExplore()
    -- Player stats
    drawPlayerStats()
    
    -- Explore message
    love.graphics.setFont(mediumFont)
    love.graphics.setColor(0.9, 0.9, 1, 0.8)
    love.graphics.printf(exploreMessage, 200, 100, 400, "center")
    
    -- Draw depth indicator
    love.graphics.setFont(largeFont)
    love.graphics.setColor(0.7, 0.8, 0.9)
    local depthText = string.format("%dm", player.depth)
    love.graphics.print(depthText, 350, 200)
    
    -- Exploration options
    drawButton(buttons.diveButton)
    drawButton(buttons.exploreButton)
    drawButton(buttons.ascendButton)
    
    -- Inventory display
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Inventory:", 50, 500)
    
    for i, item in ipairs(player.inventory) do
        love.graphics.print(item:gsub("_", " "), 50, 500 + i*20)
    end
    
    -- Gold display
    love.graphics.setColor(1, 0.9, 0.2)
    love.graphics.print(string.format("Gold: %d", player.gold), 200, 500)
end

function drawCombat()
    -- Player stats
    drawPlayerStats()
    
    -- Enemy
    if currentEnemy then
        -- Enemy name
        love.graphics.setFont(mediumFont)
        love.graphics.setColor(0.9, 0.4, 0.4)
        love.graphics.print(currentEnemy.name, 600, 20)
        
        -- Enemy health bar
        drawStatusBar(600, 50, 150, currentEnemy.health, currentEnemy.maxHealth, {0.8, 0.2, 0.2}, {0.6, 0.1, 0.1}, "HP")
        
        -- Draw enemy with shader
        love.graphics.setShader(shaders.enemyShader)
        shaders.enemyShader:send("time", animations.time)
        shaders.enemyShader:send("health", currentEnemy.health)
        shaders.enemyShader:send("maxHealth", currentEnemy.maxHealth)
        shaders.enemyShader:send("baseColor", currentEnemy.color)
        shaders.enemyShader:send("enemyType", currentEnemy.type)
        
        -- Calculate animation state
        local animState = 0
        if currentEnemy.animation then
            animState = currentEnemy.animation.timer / currentEnemy.animation.duration
            if currentEnemy.animation.entrance then
                animState = 1.0 - animState
            end
        end
        shaders.enemyShader:send("animState", animState)
        
        -- Draw enemy (using a quad that will be shaped by the shader)
        love.graphics.setColor(1, 1, 1)
        local enemyX, enemyY = 650, 150
        local enemyScale = 1.0
        
        if currentEnemy.animation and currentEnemy.animation.entrance then
            enemyX = enemyX + (1 - animState) * love.graphics.getWidth() * 0.5
            enemyScale = animState
        end
        
        love.graphics.rectangle("fill", enemyX - 50 * enemyScale, enemyY - 50 * enemyScale, 
                               100 * enemyScale, 100 * enemyScale)
        love.graphics.setShader()
        -- Draw energy
    love.graphics.setFont(mediumFont)
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.print("Energy: "..player.energy.."/"..player.maxEnergy, 30, 130)
    end
    
    -- Combat log
    love.graphics.setColor(0.1, 0.1, 0.2, 0.7)
    love.graphics.rectangle("fill", 550, 250, 200, 150, 5, 5)
    
    love.graphics.setColor(0.8, 0.8, 1, 0.8)
    love.graphics.setFont(smallFont)
    for i, message in ipairs(combatLog) do
        if i > #combatLog - 5 then -- Show last 5 messages
            love.graphics.printf(message, 560, 260 + (i - (#combatLog - 4)) * 20, 180, "left")
        end
    end
    
    -- Draw hand of cards
    drawHand()
    
    -- End turn button
    drawButton(buttons.endTurnButton)
end

function drawPlayerStats()
    -- Player stats background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.7)
    love.graphics.rectangle("fill", 20, 20, 200, 110, 5, 5)
    
    -- Health bar
    drawStatusBar(30, 30, 180, player.health, player.maxHealth, {0.8, 0.2, 0.2}, {0.6, 0.1, 0.1}, "HP")
    
    -- Oxygen bar
    drawStatusBar(30, 50, 180, player.oxygen, player.maxOxygen, {0.2, 0.6, 0.9}, {0.1, 0.3, 0.7}, "O₂")
    
    -- Pressure bar
    drawStatusBar(30, 70, 180, player.pressure, player.maxPressure, {0.4, 0.2, 0.8}, {0.2, 0.1, 0.6}, "Pressure")
    
    -- Depth indicator
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.print(string.format("Depth: %dm", player.depth), 30, 90)
    
    -- Card counts
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.print(string.format("Deck: %d   Discard: %d", #player.deck, #player.discard), 30, 110)
end

function drawStatusBar(x, y, width, value, maxValue, color1, color2, label)
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", x, y, width, 15, 5, 5)
    
    -- Value bar with gradient
    local ratio = value / maxValue
    love.graphics.setColor(color1[1], color1[2], color1[3], 0.8)
    love.graphics.rectangle("fill", x, y, width * ratio, 15, 5, 5)
    
    -- Outline
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, 15, 5, 5)
    
    -- Label
    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("%s: %d/%d", label, math.floor(value), maxValue), x + 5, y, 0, 1, 1)
end

function drawHand()
    love.graphics.setFont(smallFont)
    
    for i, cardName in ipairs(player.hand) do
        local card = cards[cardName]
        local anim = animations.cards[cardName] or {scale = 1, rotation = 0, offset = {x = 0, y = 0}}
        
        local x = 150 + (i-1)*100
        local y = 400
        
        -- Apply animation offset
        x = x + anim.offset.x
        y = y - anim.offset.y
        
        -- Set up card shader
        love.graphics.setShader(shaders.cardShader)
        shaders.cardShader:send("time", animations.time)
        shaders.cardShader:send("cardColor", card.color)
        shaders.cardShader:send("rarity", card.rarity)
        shaders.cardShader:send("hover", anim.hover and 1.0 or 0.0)
        shaders.cardShader:send("selected", (selectedCard == i) and 1.0 or 0.0)
        
        -- Draw card background
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 
            x - cardVisuals.width/2 * anim.scale, 
            y - cardVisuals.height/2 * anim.scale,
            cardVisuals.width * anim.scale, 
            cardVisuals.height * anim.scale, 
            cardVisuals.cornerRadius * anim.scale, 
            cardVisuals.cornerRadius * anim.scale)
        
        love.graphics.setShader()
        
        -- Draw card text (on top of shader)
        love.graphics.setFont(smallFont)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(card.name, 
            x - cardVisuals.width/2 * anim.scale, 
            y - cardVisuals.height/2 * anim.scale + 10 * anim.scale, 
            cardVisuals.width * anim.scale, 
            "center")
        
        -- Card description
        love.graphics.setColor(0.9, 0.9, 0.9, 0.8)
        love.graphics.printf(card.description, 
            x - cardVisuals.width/2 * anim.scale + 5 * anim.scale, 
            y - cardVisuals.height/2 * anim.scale + 30 * anim.scale, 
            (cardVisuals.width - 10) * anim.scale, 
            "center")
    end
end

function drawButton(button)
    -- Set up button shader
    love.graphics.setShader(shaders.buttonShader)
    shaders.buttonShader:send("time", animations.time)
    shaders.buttonShader:send("hover", button.hover and 1.0 or 0.0)
    shaders.buttonShader:send("pulse", button.pulse)
    
    -- Calculate button position with scale
    local centerX = button.x + button.w/2
    local centerY = button.y + button.h/2
    
    -- Draw button background
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 
        centerX - (button.w/2 * button.scale), 
        centerY - (button.h/2 * button.scale), 
        button.w * button.scale, 
        button.h * button.scale, 
        5 * button.scale, 
        5 * button.scale)
    
    love.graphics.setShader()
    
    -- Button text
    love.graphics.setFont(mediumFont)
    love.graphics.setColor(1, 1, 1, 0.9)
    
    local textWidth = mediumFont:getWidth(button.text)
    local textHeight = mediumFont:getHeight()
    
    love.graphics.print(button.text, 
        centerX - textWidth/2, 
        centerY - textHeight/2, 
        0, button.scale, button.scale)
end

function drawGameOver()
    -- Game over text with procedural effect
    love.graphics.setFont(titleFont)
    
    local title = "GAME OVER"
    local titleWidth = titleFont:getWidth(title)
    local titleX = love.graphics.getWidth()/2 - titleWidth/2
    local titleY = 100
    
    -- Draw title with multiple layers for glow effect
    for i = 1, 3 do
        local scale = 1 + (i * 0.03)
        local alpha = 0.7 - (i * 0.2)
        love.graphics.setColor(0.9, 0.3, 0.3, alpha)
        love.graphics.print(title, titleX - (titleWidth * (scale-1))/2, 
                           titleY - (titleFont:getHeight() * (scale-1))/2, 
                           0, scale, scale)
    end
    
    love.graphics.setColor(0.9, 0.3, 0.3)
    love.graphics.print(title, titleX, titleY)
    
    -- Stats
    love.graphics.setFont(mediumFont)
    love.graphics.setColor(0.8, 0.8, 0.9)
    
    local stats = string.format("Depth Reached: %dm\nGold Collected: %d\nItems Found: %d", 
        player.depth, player.gold, #player.inventory)
        
    love.graphics.printf(stats, 300, 200, 400, "left")
    
    -- Death reason
    love.graphics.setColor(0.9, 0.7, 0.7)
    local reason = "You were lost to the depths..."
    
    if player.health <= 0 then
        reason = "You were defeated in combat."
    elseif player.oxygen <= 0 then
        reason = "You ran out of oxygen."
    elseif player.pressure >= player.maxPressure then
        reason = "The pressure crushed you."
    end
    
    love.graphics.printf(reason, 300, 280, 400, "center")
    
    -- Restart button
    drawButton(buttons.restartButton)
end

function drawFloatingNumbers()
    -- Draw damage numbers
    love.graphics.setFont(mediumFont)
    
    for _, effect in ipairs(animations.damageNumbers) do
        local alpha = 1 - (effect.timer / effect.duration)
        love.graphics.setColor(effect.color[1], effect.color[2], effect.color[3], alpha)
        love.graphics.print("-" .. effect.value, effect.x, effect.y)
    end
    
    -- Draw heal numbers
    for _, effect in ipairs(animations.healNumbers) do
        local alpha = 1 - (effect.timer / effect.duration)
        love.graphics.setColor(effect.color[1], effect.color[2], effect.color[3], alpha)
        love.graphics.print("+" .. effect.value, effect.x, effect.y)
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end -- Only left mouse button
    
    -- Handle clicks based on game state
    if currentState == GAME_STATE.MENU then
        if buttons.startButton.hover then
            newGame()
            currentState = GAME_STATE.EXPLORE
        end
    elseif currentState == GAME_STATE.EXPLORE then
        -- Dive deeper button
        if buttons.diveButton.hover then
            player.depth = player.depth + 10
            player.pressure = math.min(player.pressure + 5, player.maxPressure)
            
            -- Chance of encounter increases with depth
            local encounterChance = 0.2 + player.depth / 500
            if math.random() < encounterChance then
                startCombat()
            else
                exploreMessage = "You dive deeper into the abyss..."
            end
        end
        
        -- Explore area button
        if buttons.exploreButton.hover then
            -- Higher chance of encounter
            if math.random() < 0.6 then
                startCombat()
            else
                local events = {
                    "You find nothing of interest.",
                    "Strange fish swim by, glowing faintly.",
                    "You notice an old shipwreck in the distance.",
                    "The water grows colder as you explore."
                }
                exploreMessage = events[math.random(#events)]
                
                -- Chance to find gold
                if math.random() < 0.3 then
                    local amount = math.random(5, 10)
                    player.gold = player.gold + amount
                    exploreMessage = exploreMessage .. "\nYou find " .. amount .. " gold!"
                end
            end
        end
        
        -- Ascend button
        if buttons.ascendButton.hover then
            player.depth = math.max(0, player.depth - 10)
            player.pressure = math.max(0, player.pressure - 10)
            player.oxygen = math.min(player.oxygen + 5, player.maxOxygen)
            exploreMessage = "You rise toward the surface..."
        end
    elseif currentState == GAME_STATE.COMBAT then
        -- Check card clicks
        for i, cardName in ipairs(player.hand) do
            local anim = animations.cards[cardName]
            if anim and anim.hover then
                selectedCard = i
                return
            end
        end
        
        -- Check enemy click when card is selected
        if selectedCard and currentEnemy then
            local card = cards[player.hand[selectedCard]]
            if x >= 550 and x <= 750 and y >= 100 and y <= 200 then
                playCard(selectedCard, currentEnemy)
                selectedCard = nil
            end
        end
        
        -- End turn button
        if buttons.endTurnButton.hover then
            player.energy = player.maxEnergy
            dealHand()
            enemyTurn()
            selectedCard = nil
            return
        end
    elseif currentState == GAME_STATE.GAME_OVER then
        if buttons.restartButton.hover then
            newGame()
            currentState = GAME_STATE.MENU
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" and currentState == GAME_STATE.GAME_OVER then
        newGame()
        currentState = GAME_STATE.MENU
    elseif key == "space" and currentState == GAME_STATE.COMBAT then
        drawHand()
        enemyTurn()
        selectedCard = nil
    end

end
