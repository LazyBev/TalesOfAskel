-- Global variables
local shaderTime = 0
local debugMode = false -- Toggle for debug logging

function love.load()
    -- Initialize game with seed
    math.randomseed(os.time())
    local currentDate = os.date("*t")
    local dayOfWeek = currentDate.wday - 1
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Load fonts with error checking
    smallFont = love.graphics.newFont(12) or love.graphics.newFont()
    mediumFont = love.graphics.newFont(18) or love.graphics.newFont()
    largeFont = love.graphics.newFont(32) or love.graphics.newFont()
    titleFont = love.graphics.newFont(48) or love.graphics.newFont()
    
    -- Main shaders
    shaders = {
        lostBackground = love.graphics.newShader[[
            #define PI 3.14159265359
            #define RED1 1.0    // Full vibrant red
            #define RED2 0.7    // Slightly subdued red
            #define RED3 0.4    // Deeper, richer red
            #define SINE1 1.0   // Standard sine modulation
            #define SINE2 1.2   // Slightly faster modulation
            #define SINE3 0.5   // Softer sine effect
            #define MOD1 0.1    // Base modulation
            #define MOD2 0.3    // Enhanced variation
            #define MOD3 0.2    // Reduced modulation

            extern number iTime;
            extern number dayOfWeek;

            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec2 screenSize = love_ScreenSize.xy;
                vec2 uv = (screen_coords - 0.5 * screenSize) / length(screenSize);
                float uv_len = max(length(uv), 0.0001);
                
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
                    float jitter = 0.2 * sin(uv_len * 20.0 - iTime);
                    float a = atan(uv.y, uv.x);
                    uv += jitter * vec2(cos(a), sin(a));
                }
                else if(day < 6.0) {
                    float n = sin(dot(uv, vec2(12.9898,78.233)) + iTime * 3.0);
                    uv += 0.03 * vec2(n, cos(dot(uv, vec2(12.9898,78.233)) + iTime * 3.0));
                }
                else {
                    uv = fract(uv * 2.0 * (sin(iTime * 0.7 + 0.2) + 2.0) + (iTime * 0.25)) - 0.5;
                    uv *= 1.5;
                }
                
                vec2 uv_loop = uv * 30.0;
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

                vec4 red1 = vec4(RED1 + MOD1 * sin(iTime + SINE1), 0.0, 0.0, 1.0);
                vec4 red2 = vec4(RED2 + MOD2 * sin(iTime + SINE2), 0.0, 0.0, 1.0);
                vec4 red3 = vec4(RED3 + MOD3 * sin(iTime + SINE3), 0.0, 0.0, 1.0);

                return (0.3 / 3.5) * red1
                    + (1.0 - 0.3 / 3.5) * (red1 * c1p + red2 * c2p + vec4(c3p * red3.rgb, c3p * red1.a))
                    + light;
            }
        ]],

        exploreBackground = love.graphics.newShader[[
            #define halfsqrt3 0.86602540
            #define invsqrt3 0.57735026
            #define tau 6.28318530
            #define pi 3.14159265358979323846264338327950

            extern float iTime;
            extern vec2 iResolution;

            float hash1D(vec2 x) {
                vec2 p = fract(x * vec2(123.4, 234.5));
                p += dot(p, p + 23.45);
                return fract(p.x * p.y);
            }

            vec2 hash2D(vec2 x) {
                vec2 p = fract(vec2(x.x * 123.4, x.y * 234.5));
                p += dot(p, p + 23.45);
                return fract(vec2(p.x * p.y * 123.4, p.x * p.y * 345.6));
            }

            float hash(vec2 x, float time) {
                return 0.5+0.5*sin(tau*hash1D(x)+time);
            }

            float tri_noise(vec2 p, float time) {
                vec2 q = vec2(p.x-p.y*invsqrt3, p.y*2.0*invsqrt3);
                vec2 iq = floor(q);
                vec2 fq = fract(q);
                float v = 0.0;
                
                float h = step(1.0, fq.x+fq.y);
                vec2 c = iq+h;
                vec2 r = p-vec2(c.x+0.5*c.y, halfsqrt3*c.y);
                float s = 1.0-2.0*h;
                r *= s;
                
                vec3 lambda = vec3(1.0-r.x-invsqrt3*r.y, r.x-invsqrt3*r.y, 2.0*invsqrt3*r.y);
                vec3 lambda2 = lambda*lambda;
                vec3 a = 15.0*lambda2*lambda2.zxy*lambda.yzx;
                vec3 w = lambda*lambda2*(10.0-15.0*lambda+6.0*lambda2)+a+a.yzx;
                    
                v += w.x*hash(abs(c), time);
                v += w.y*hash(abs(iq+vec2(1.0-h,h)), time);
                v += w.z*hash(abs(iq+vec2(h,1.0-h)), time);
                
                return v;
            }

            float fbm(vec2 p, int octaves, float decay, float time) {
                vec2 fwp = fwidth(p);
                float w = dot(step(fwp.xy, fwp.yx), fwp);
                vec2 v = vec2(0.0);
                float weight = 1.0;
                for(int i = 0; i < octaves; i++) {
                    v += weight*vec2(tri_noise(p, time)*smoothstep(1.0,0.5,w), 1.0);
                    p *= 2.0*mat2(4.0/5.0, -3.0/5.0, 3.0/5.0, 4.0/5.0);
                    w *= 2.0;
                    weight *= decay;        
                    time *= 1.6;
                }
                return v.x/v.y;
            }

            float fcos(float x) {
                float w = fwidth(x);
                return cos(x)*sin(0.5*w)/(0.5*w);
            }

            float get_val(vec2 p) {
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

            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
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
            
            uniform vec2 iResolution;
            uniform float iTime;
            
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                vec4 fragColor;
                vec2 fragCoord = screen_coords;
                float pixel_size = length(iResolution.xy)/PIXEL_SIZE_FAC;
                vec2 uv = (floor(fragCoord.xy*(1.0/pixel_size))*pixel_size - 0.5*iResolution.xy)/length(iResolution.xy);
                float uv_len = length(uv);
                float speed = (iTime*SPIN_EASE*0.1) + 302.2;
                float new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE*20.*(1.*spin_amount*uv_len + (1. - 1.*spin_amount));
                vec2 mid = (iResolution.xy/length(iResolution.xy))/2.;
                uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);
                uv *= 30.;
                speed = iTime*(1.);
                vec2 uv2 = vec2(uv.x+uv.y);
                for(int i=0; i < 5; i++) {
                    uv2 += uv + cos(length(uv));
                    uv += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),sin(uv2.x - 0.113*speed));
                    uv -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
                }
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
                float distortionScale = 0.005 * min(depth / 200.0, 0.05);
                vec2 tc2 = tc;
                tc2.x += distortionScale * sin(tc.y * 10.0 + time);
                tc2.y += distortionScale * sin(tc.x * 10.0 + time * 0.5);
                
                vec4 pixel = Texel(tex, tc2);
                float depth_factor = min(depth / 500.0, 0.5);
                vec3 deep_color = vec3(0.05, 0.05, 0.1);
                pixel.rgb = mix(pixel.rgb, deep_color, depth_factor);
                
                return pixel * color;
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
                
                float radius = 0.4 + 0.1 * sin(time * 0.5 + uv.x * 5.0);
                float body = smoothstep(radius, radius-0.01, dist);
                
                float healthRatio = health / maxHealth;
                vec3 healthColor = mix(vec3(0.8, 0.2, 0.2), baseColor, healthRatio);
                
                float pulse = 0.05 * sin(time * 3.0) * (1.0 - animState);
                
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
                
                float eyes = 0.0;
                if (enemyType < 1.5) {
                    eyes += smoothstep(0.1, 0.09, distance(uv, center + vec2(-0.15, -0.1)));
                    eyes += smoothstep(0.1, 0.09, distance(uv, center + vec2(0.15, -0.1)));
                } else {
                    eyes += smoothstep(0.15, 0.14, distance(uv, center));
                }
                
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
                
                float radius = 0.4;
                float alpha = smoothstep(radius, radius-0.01, dist);
                
                float highlight = 0.0;
                highlight += smoothstep(0.3, 0.0, distance(uv, center + vec2(0.1, 0.1)));
                highlight *= 0.5 + 0.5 * sin(time * 2.0);
                
                vec2 refractedUV = uv + vec2(
                    sin(time + uv.y * 10.0) * 0.02,
                    cos(time + uv.x * 8.0) * 0.02
                );
                
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
                float edge = 0.1;
                float rounded = smoothstep(edge, 0.0, min(min(uv.x, uv.y), min(1.0-uv.x, 1.0-uv.y)));
                
                vec3 baseColor = vec3(0.2, 0.3, 0.5);
                float glow = hover * (0.2 + 0.1 * sin(time * 3.0));
                float pulseEffect = pulse * (0.1 + 0.05 * sin(time * 5.0));
                
                vec3 finalColor = mix(baseColor, vec3(0.3, 0.5, 0.7), glow);
                finalColor = mix(finalColor, vec3(1.0), pulseEffect);
                
                return vec4(finalColor, rounded * color.a);
            }
        ]]
    }
    
    -- Initialize particle systems
    effectsSettings = {
        bubbles = love.graphics.newParticleSystem(love.graphics.newCanvas(32, 32, {format = "normal"}), 100),
        dustParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(16, 16, {format = "normal"}), 100)
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

    -- Send initial dayOfWeek to shader with error checking
    if shaders.lostBackground:hasUniform("dayOfWeek") then
        shaders.lostBackground:send("dayOfWeek", dayOfWeek)
    end
    
    -- Initialize game states and data
    initGameStates()
    initGameData()
    newGame()
end

function cleanup()
    -- Properly release resources
    for _, shader in pairs(shaders or {}) do
        shader:release()
    end
    shaders = nil
    
    if effectsSettings then
        if effectsSettings.bubbles then effectsSettings.bubbles:release() end
        if effectsSettings.dustParticles then effectsSettings.dustParticles:release() end
    end
    effectsSettings = nil
    
    collectgarbage()
end

function getBrightness(color)
    return 0.299 * color[1] + 0.587 * color[2] + 0.114 * color[3]
end

function initGameStates()
    GAME_STATE = {
        MENU = 1,
        EXPLORE = 2,
        COMBAT = 3,
        GAME_OVER = 4,
        TRANSITION = 5
    }
    currentState = GAME_STATE.MENU
    transitionAlpha = 0
    
    buttons = {
        startButton = {x = 300, y = 300, w = 200, h = 50, text = "Dive In", hover = false, scale = 1, pulse = 0},
        quitButton = {x = 300, y = 600, w = 200, h = 50, text = "Stay on land", hover = false, scale = 1, pulse = 0},
        restartButton = {x = 300, y = 350, w = 200, h = 50, text = "Try Again", hover = false, scale = 1, pulse = 0},
        diveButton = {x = 100, y = 350, w = 150, h = 40, text = "Dive Deeper", hover = false, scale = 1, pulse = 0},
        exploreButton = {x = 325, y = 350, w = 150, h = 40, text = "Explore Area", hover = false, scale = 1, pulse = 0},
        ascendButton = {x = 550, y = 350, w = 150, h = 40, text = "Ascend", hover = false, scale = 1, pulse = 0},
        -- New combat buttons
        attackButton = {x = 50, y = 400, w = 100, h = 40, text = "Attack", hover = false, scale = 1, pulse = 0},
        defendButton = {x = 160, y = 400, w = 100, h = 40, text = "Defend", hover = false, scale = 1, pulse = 0},
        regenButton = {x = 270, y = 400, w = 100, h = 40, text = "Regen O₂", hover = false, scale = 1, pulse = 0},
        runButton = {x = 380, y = 400, w = 100, h = 40, text = "Run", hover = false, scale = 1, pulse = 0},
        endTurnButton = {x = 650, y = 400, w = 100, h = 40, text = "End Turn", hover = false, scale = 1, pulse = 0}
    }
    
    -- Remove cardVisuals since we won't need cards
    animations = {
        time = 0,
        globalPulse = 0,
        damageNumbers = {},
        healNumbers = {},
        stateTransition = nil,
        playerDefense = false, -- Track defense state
        defenseTimer = 0      -- Track defense duration
    }
end

function initGameData()
    player = {
        health = 100,
        maxHealth = 100,
        depth = 0,
        pressure = 0,
        maxPressure = 100,
        oxygen = 100,
        maxOxygen = 100,
        inventory = {},
        gold = 0,
        energy = 3,
        maxEnergy = 3,
        attack = 10,  -- Base attack damage
        defense = 0   -- Base defense (modified by Defend action)
    }
    
    enemies = {
        {
            name = "Abyssal Lurker",
            health = 30,
            maxHealth = 30,
            attack = 5,
            defense = 2,
            description = "A shadowy creature that hides in the darkness",
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
            color = {0.4, 0.1, 0.2},
            type = 3
        }
    }
    
    currentEnemy = nil
    combatLog = {}
    exploreMessage = "You begin your descent into the abyss..."
    gameStateTimer = 0
end

function isMouseOverCard(x, y, cardX, cardY, scale)
    local scaledWidth = cardVisuals.width * (scale or 1)
    local scaledHeight = cardVisuals.height * (scale or 1)
    local halfWidth = scaledWidth / 2
    local halfHeight = scaledHeight / 2
    
    return (x >= cardX - halfWidth and x <= cardX + halfWidth and
            y >= cardY - halfHeight and y <= cardY + halfHeight)
end

function playerAttack()
    if not currentEnemy then return end
    
    if player.energy < 1 then
        table.insert(combatLog, "Not enough energy to attack!")
        return
    end
    
    player.energy = player.energy - 1
    local missChance = 0.2
    if math.random() < missChance then
        table.insert(combatLog, "Your attack missed!")
    else
        local damage = math.max(1, player.attack - currentEnemy.defense)
        currentEnemy.health = math.max(0, currentEnemy.health - damage)
        addDamageEffect(currentEnemy, damage)
        table.insert(combatLog, string.format("You deal %d damage to %s!", damage, currentEnemy.name))
    end
    enemyTurn()
    checkGameState()
end

function playerDefend()
    if player.energy < 1 then
        table.insert(combatLog, "Not enough energy to defend!")
        return
    end
    
    player.energy = player.energy - 1
    animations.playerDefense = true
    animations.defenseTimer = 1.0 -- Lasts for one turn
    local negateChance = 0.3
    if math.random() < negateChance then
        player.defense = math.huge -- Fully negate next damage
        table.insert(combatLog, "You brace yourself, ready to negate all damage!")
    else
        player.defense = 0.5 -- 50% damage reduction
        table.insert(combatLog, "You prepare to reduce incoming damage!")
    end
    enemyTurn()
    checkGameState()
end

function playerRegenOxygen()
    if player.energy < 1 then
        table.insert(combatLog, "Not enough energy to regenerate oxygen!")
        return
    end
    
    player.energy = player.energy - 1
    local regenAmount = 20
    player.oxygen = math.min(player.maxOxygen, player.oxygen + regenAmount)
    addHealEffect(regenAmount)
    table.insert(combatLog, string.format("You regenerate %d oxygen!", regenAmount))
    enemyTurn()
    checkGameState()
end

function playerRun()
    if player.energy < 1 then
        table.insert(combatLog, "Not enough energy to run!")
        return
    end
    
    player.energy = player.energy - 1
    local runChance = 0.2
    if math.random() < runChance then
        table.insert(combatLog, "You successfully flee from combat!")
        currentEnemy = nil
        changeGameState(GAME_STATE.EXPLORE)
        exploreMessage = "You escape back to the depths..."
    else
        table.insert(combatLog, "You failed to escape!")
        enemyTurn()
    end
    checkGameState()
end

function enemyTurn()
    if not currentEnemy or currentEnemy.health <= 0 then return end
    
    local damage = currentEnemy.attack
    if animations.playerDefense then
        if player.defense == math.huge then
            damage = 0
            table.insert(combatLog, string.format("%s's attack was completely blocked!", currentEnemy.name))
        else
            damage = math.max(1, math.floor(damage * (1 - player.defense)))
            table.insert(combatLog, string.format("%s's attack was reduced!", currentEnemy.name))
        end
    end
    
    player.health = player.health - damage
    addPlayerDamageEffect(damage)
    table.insert(combatLog, string.format("%s attacks you for %d damage!", currentEnemy.name, damage))
    checkGameState()
end

function checkGameState()
    if player.health <= 0 or player.oxygen <= 0 or player.pressure >= player.maxPressure then
        changeGameState(GAME_STATE.GAME_OVER)
        return
    end
    
    if currentState == GAME_STATE.COMBAT and currentEnemy and currentEnemy.health <= 0 then
        table.insert(combatLog, string.format("You defeated the %s!", currentEnemy.name))
        local goldReward = math.random(10, 20) + math.floor(player.depth / 10)
        player.gold = player.gold + goldReward
        table.insert(combatLog, string.format("You gain %d gold!", goldReward))
        
        if math.random() < 0.3 then
            local items = {"oxygen_tank", "pressure_suit", "ancient_artifact"}
            local item = items[math.random(#items)]
            table.insert(player.inventory, item)
            table.insert(combatLog, string.format("You found %s!", item:gsub("_", " ")))
        end
        
        changeGameState(GAME_STATE.EXPLORE)
        exploreMessage = "The creature sinks into the darkness..."
        currentEnemy = nil
    end
end

function startCombat()
    local enemyTier = math.min(math.floor(player.depth / 100) + 1, #enemies)
    currentEnemy = deepcopy(enemies[enemyTier])
    
    local scale = 1 + (player.depth / 200)
    currentEnemy.health = math.floor(currentEnemy.health * scale)
    currentEnemy.maxHealth = currentEnemy.health
    currentEnemy.attack = math.floor(currentEnemy.attack * scale)
    
    changeGameState(GAME_STATE.COMBAT)
    combatLog = {string.format("A %s appears from the depths!", currentEnemy.name)}
    
    currentEnemy.animation = {
        entrance = true,
        timer = 0,
        duration = 1.0
    }
    
    player.energy = player.maxEnergy
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
    player.health = 100
    player.maxHealth = 100
    player.depth = 0
    player.pressure = 0
    player.oxygen = 100
    player.inventory = {}
    player.gold = 0
    player.energy = 3
    player.attack = 10
    player.defense = 0
    
    currentEnemy = nil
    combatLog = {}
    exploreMessage = "You begin your descent into the abyss..."
    
    animations.damageNumbers = {}
    animations.healNumbers = {}
    animations.playerDefense = false
    animations.defenseTimer = 0
end

function changeGameState(newState)
    currentState = GAME_STATE.TRANSITION
    animations.stateTransition = {
        from = currentState,
        to = newState,
        timer = 0,
        duration = 0.5
    }
end

function love.update(dt)
    gameStateTimer = gameStateTimer + dt
    animations.time = animations.time + dt
    animations.globalPulse = math.sin(animations.time * 2)
    
    if currentState == GAME_STATE.TRANSITION and animations.stateTransition then
        local trans = animations.stateTransition
        trans.timer = trans.timer + dt
        transitionAlpha = trans.timer / trans.duration
        if trans.timer >= trans.duration then
            currentState = trans.to
            animations.stateTransition = nil
            transitionAlpha = 0
        end
    end
    
    effectsSettings.bubbles:update(dt)
    effectsSettings.dustParticles:update(dt)
    
    shaderTime = shaderTime + dt
    local function safeSend(shader, uniform, value)
        if shader and shader:hasUniform(uniform) then shader:send(uniform, value) end
    end
    
    safeSend(shaders.exploreBackground, "iTime", love.timer.getTime())
    safeSend(shaders.exploreBackground, "iResolution", {love.graphics.getWidth(), love.graphics.getHeight()})
    safeSend(shaders.fightBackground, "iTime", love.timer.getTime())
    safeSend(shaders.fightBackground, "iResolution", {love.graphics.getWidth(), love.graphics.getHeight()})
    safeSend(shaders.water, "time", animations.time)
    safeSend(shaders.water, "depth", player.depth)
    safeSend(shaders.lostBackground, "iTime", shaderTime)
    
    for _, button in pairs(buttons) do
        if button.hover then
            button.scale = math.min(button.scale + dt * 3, 1.1)
            button.pulse = math.min(button.pulse + dt * 2, 1)
        else
            button.scale = math.max(button.scale - dt * 3, 1.0)
            button.pulse = math.max(button.pulse - dt * 2, 0)
        end
    end
    
    if animations.playerDefense then
        animations.defenseTimer = animations.defenseTimer - dt
        if animations.defenseTimer <= 0 then
            animations.playerDefense = false
            player.defense = 0
        end
    end
    
    if currentEnemy and currentEnemy.animation then
        currentEnemy.animation.timer = currentEnemy.animation.timer + dt
        if currentEnemy.animation.timer > currentEnemy.animation.duration then
            currentEnemy.animation.entrance = false
        end
    end
    
    for i = #animations.damageNumbers, 1, -1 do
        local effect = animations.damageNumbers[i]
        effect.timer = effect.timer + dt
        effect.x = effect.x + effect.velocity.x * dt
        effect.y = effect.y + effect.velocity.y * dt
        effect.velocity.y = effect.velocity.y + 20 * dt
        if effect.timer >= effect.duration then
            table.remove(animations.damageNumbers, i)
        end
    end
    
    for i = #animations.healNumbers, 1, -1 do
        local effect = animations.healNumbers[i]
        effect.timer = effect.timer + dt
        effect.x = effect.x + effect.velocity.x * dt
        effect.y = effect.y + effect.velocity.y * dt
        effect.velocity.y = effect.velocity.y + 20 * dt
        if effect.timer >= effect.duration then
            table.remove(animations.healNumbers, i)
        end
    end
    
    if currentState ~= GAME_STATE.MENU and currentState ~= GAME_STATE.GAME_OVER and currentState ~= GAME_STATE.EXPLORE then
        player.oxygen = math.max(0, player.oxygen - dt * (0.2 + (player.pressure / 10)))
        if player.oxygen <= 0 then
            changeGameState(GAME_STATE.GAME_OVER)
        end
    end
    
    local mx, my = love.mouse.getPosition()
    for _, btn in pairs(buttons) do
        if type(btn.x) == "number" and type(btn.y) == "number" and 
           type(btn.w) == "number" and type(btn.h) == "number" then
            local scaledW = btn.w * btn.scale
            local scaledH = btn.h * btn.scale
            local centerX = btn.x + btn.w/2
            local centerY = btn.y + btn.h/2
            btn.hover = (mx >= centerX - scaledW/2 and mx <= centerX + scaledW/2 and
                        my >= centerY - scaledH/2 and my <= centerY + scaledH/2)
        end
    end
    
    if math.random() < 0.01 * (1 + player.depth/100) then
        effectsSettings.bubbles:emit(1)
    end
    if math.random() < 0.02 then
        effectsSettings.dustParticles:emit(1)
    end
    
    if debugMode then
        print(string.format("FPS: %d, Memory: %.2f MB", love.timer.getFPS(), collectgarbage("count")/1024))
    end
end

function love.draw()
    if currentState == GAME_STATE.TRANSITION then
        local fromShader = {
            [GAME_STATE.MENU] = shaders.water,
            [GAME_STATE.EXPLORE] = shaders.exploreBackground,
            [GAME_STATE.COMBAT] = shaders.fightBackground,
            [GAME_STATE.GAME_OVER] = shaders.lostBackground
        }[animations.stateTransition.from]
        
        local toShader = {
            [GAME_STATE.MENU] = shaders.water,
            [GAME_STATE.EXPLORE] = shaders.exploreBackground,
            [GAME_STATE.COMBAT] = shaders.fightBackground,
            [GAME_STATE.GAME_OVER] = shaders.lostBackground
        }[animations.stateTransition.to]
        
        love.graphics.setShader(fromShader)
        love.graphics.setColor(1, 1, 1, 1 - transitionAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        love.graphics.setShader(toShader)
        love.graphics.setColor(1, 1, 1, transitionAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    else
        local stateShader = {
            [GAME_STATE.MENU] = shaders.water,
            [GAME_STATE.EXPLORE] = shaders.exploreBackground,
            [GAME_STATE.COMBAT] = shaders.fightBackground,
            [GAME_STATE.GAME_OVER] = shaders.lostBackground
        }[currentState]
        
        love.graphics.setShader(stateShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
    
    love.graphics.setShader()
    
    local stateDraw = {
        [GAME_STATE.MENU] = drawMenu,
        [GAME_STATE.EXPLORE] = drawExplore,
        [GAME_STATE.COMBAT] = drawCombat,
        [GAME_STATE.GAME_OVER] = drawGameOver,
        [GAME_STATE.TRANSITION] = function()
            local alpha = transitionAlpha
            love.graphics.setColor(0, 0, 0, alpha)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        end
    }
    
    if stateDraw[currentState] then stateDraw[currentState]() end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(effectsSettings.bubbles)
    love.graphics.draw(effectsSettings.dustParticles)
    drawFloatingNumbers()
end

function drawMenu()
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.8, 0.9, 1)
    
    local title = "THE DEPTHS"
    local titleWidth = titleFont:getWidth(title)
    local titleX = love.graphics.getWidth()/2 - titleWidth/2
    local titleY = 100
    
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
    
    love.graphics.setFont(mediumFont)
    love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
    local subtitle = "A deep sea card adventure"
    local subtitleWidth = mediumFont:getWidth(subtitle)
    love.graphics.print(subtitle, love.graphics.getWidth()/2 - subtitleWidth/2, 170)
    
    drawButton(buttons.startButton)
    drawButton(buttons.quitButton)
end

function drawExplore()
    drawPlayerStats()
    
    love.graphics.setFont(mediumFont)
    love.graphics.setColor(0.9, 0.9, 1, 0.8)
    love.graphics.printf(exploreMessage, 200, 100, 400, "center")
    
    love.graphics.setFont(largeFont)
    love.graphics.setColor(0.7, 0.8, 0.9)
    local depthText = string.format("%dm", player.depth)
    love.graphics.print(depthText, 350, 200)
    
    drawButton(buttons.diveButton)
    drawButton(buttons.exploreButton)
    drawButton(buttons.ascendButton)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Inventory:", 50, 500)
    
    for i, item in ipairs(player.inventory) do
        love.graphics.print(item:gsub("_", " "), 50, 500 + i*20)
    end
    
    love.graphics.setColor(1, 0.9, 0.2)
    love.graphics.print(string.format("Gold: %d", player.gold), 200, 500)
end

function drawCombat()
    drawPlayerStats()
    
    if currentEnemy then
        love.graphics.setFont(mediumFont)
        love.graphics.setColor(0.5, 0.4, 0.4)
        love.graphics.print(currentEnemy.name, 600, 20)
        
        drawStatusBar(600, 50, 150, currentEnemy.health, currentEnemy.maxHealth, {0.8, 0.2, 0.2}, {0.6, 0.1, 0.1}, "HP")
        
        love.graphics.setShader(shaders.enemyShader)
        shaders.enemyShader:send("time", animations.time)
        shaders.enemyShader:send("health", currentEnemy.health)
        shaders.enemyShader:send("maxHealth", currentEnemy.maxHealth)
        shaders.enemyShader:send("baseColor", currentEnemy.color)
        shaders.enemyShader:send("enemyType", currentEnemy.type)
        
        local animState = 0
        if currentEnemy and currentEnemy.animation then
            animState = currentEnemy.animation.timer / currentEnemy.animation.duration
            if currentEnemy.animation.entrance then
                animState = 1.0 - animState
            end
        end
        shaders.enemyShader:send("animState", animState)
        
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
        
        love.graphics.setFont(mediumFont)
        love.graphics.setColor(0.9, 0.8, 0.2)
        love.graphics.print("Energy: "..player.energy.."/"..player.maxEnergy, 30, 130)
    end
    
    love.graphics.setColor(0.1, 0.1, 0.2, 0.7)
    love.graphics.rectangle("fill", 590, 70, 200, 150, 5, 5)
    
    love.graphics.setColor(0.8, 0.8, 1, 0.8)
    love.graphics.setFont(smallFont)
    for i, message in ipairs(combatLog) do
        if i > #combatLog - 4 then
            love.graphics.printf(message, 595, 48 + (i - (#combatLog - 4)) * 35, 180, "left")
        end
    end
    
    -- Draw new combat buttons
    drawButton(buttons.attackButton)
    drawButton(buttons.defendButton)
    drawButton(buttons.regenButton)
    drawButton(buttons.runButton)
    drawButton(buttons.endTurnButton)
end

function drawPlayerStats()
    love.graphics.setColor(0.1, 0.1, 0.2, 0.7)
    love.graphics.rectangle("fill", 20, 20, 200, 90, 5, 5)
    
    drawStatusBar(30, 30, 180, player.health, player.maxHealth, {0.8, 0.2, 0.2}, {0.6, 0.1, 0.1}, "HP")
    drawStatusBar(30, 50, 180, player.oxygen, player.maxOxygen, {0.2, 0.6, 0.9}, {0.1, 0.3, 0.7}, "O₂")
    drawStatusBar(30, 70, 180, player.pressure, player.maxPressure, {0.4, 0.2, 0.8}, {0.2, 0.1, 0.6}, "Pressure")
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.print(string.format("Depth: %dm", player.depth), 30, 90)
end

function drawStatusBar(x, y, width, value, maxValue, color1, color2, label)
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", x, y, width, 15, 5, 5)
    
    local ratio = value / maxValue
    love.graphics.setColor(color1[1], color1[2], color1[3], 0.8)
    love.graphics.rectangle("fill", x, y, width * ratio, 15, 5, 5)
    
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, 15, 5, 5)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("%s: %d/%d", label, math.floor(value), maxValue), x + 5, y)
end

function drawButton(button)
    love.graphics.setShader(shaders.buttonShader)
    shaders.buttonShader:send("time", animations.time)
    shaders.buttonShader:send("hover", button.hover and 1.0 or 0.0)
    shaders.buttonShader:send("pulse", button.pulse)
    
    local centerX = button.x + button.w/2
    local centerY = button.y + button.h/2
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 
        centerX - (button.w/2 * button.scale), 
        centerY - (button.h/2 * button.scale), 
        button.w * button.scale, 
        button.h * button.scale, 
        5 * button.scale)
    
    love.graphics.setShader()
    
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
    local alpha = math.min(gameStateTimer * 2, 1)  -- Fade in over 0.5 seconds
    
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.9, 0.3, 0.3, alpha)
    local title = "GAME OVER"
    local titleWidth = titleFont:getWidth(title)
    love.graphics.print(title, love.graphics.getWidth()/2 - titleWidth/2, 100)
    love.graphics.setFont(mediumFont)
    love.graphics.setColor(0.8, 0.8, 0.9, 0.8 * alpha)
    love.graphics.print(title, love.graphics.getWidth()/2 - titleWidth/2, 100)
    
    local deathMessage = "The depths claimed you..."
    if player.health <= 0 then
        deathMessage = "Your body succumbed to the abyss..."
    elseif player.oxygen <= 0 then
        deathMessage = "You ran out of air in the darkness..."
    elseif player.pressure >= player.maxPressure then
        deathMessage = "The pressure crushed you..."
    end
    
    local messageWidth = mediumFont:getWidth(deathMessage)
    love.graphics.print(deathMessage, love.graphics.getWidth()/2 - messageWidth/2, 200)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.7, 0.7, 0.8)
    local stats = string.format("Maximum Depth: %dm\nGold Collected: %d", player.depth, player.gold)
    love.graphics.printf(stats, love.graphics.getWidth()/2 - 100, 300, 200, "center")
    
    drawButton(buttons.restartButton)
end

function drawFloatingNumbers()
    love.graphics.setFont(smallFont)
    
    for _, effect in ipairs(animations.damageNumbers) do
        local alpha = 1 - (effect.timer / effect.duration)
        love.graphics.setColor(effect.color[1], effect.color[2], effect.color[3], alpha)
        love.graphics.print(tostring(-effect.value), effect.x, effect.y)
    end
    
    for _, effect in ipairs(animations.healNumbers) do
        local alpha = 1 - (effect.timer / effect.duration)
        love.graphics.setColor(effect.color[1], effect.color[2], effect.color[3], alpha)
        love.graphics.print("+"..effect.value, effect.x, effect.y)
    end
    
    if animations.playedCard then
        local card = animations.playedCard
        local t = card.timer
        local scale = card.scale * (1 + math.min(t * 2, 0.5))
        local alpha = card.alpha
        
        love.graphics.push()
        love.graphics.translate(card.startX + (card.targetX - card.startX) * math.min(t, 1),
                              card.startY + (card.targetY - card.startY) * math.min(t, 1))
        love.graphics.scale(scale)
        love.graphics.rotate(card.rotation * math.min(t * 2, 1))
        
        love.graphics.setColor(1, 1, 1, alpha)
        drawCard(0, 0, card.name, {hover = false, scale = 1, rotation = 0, offset = {x = 0, y = 0}})
        
        love.graphics.pop()
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 or currentState == GAME_STATE.TRANSITION then return end
    
    local actions = {
        [GAME_STATE.MENU] = function()
            if buttons.startButton.hover then
                newGame()
                changeGameState(GAME_STATE.EXPLORE)
            elseif buttons.quitButton.hover then
                love.event.quit()
            end
        end,
        [GAME_STATE.EXPLORE] = function()
            if buttons.diveButton.hover then
                player.depth = player.depth + 10
                player.pressure = math.min(player.pressure + 5, player.maxPressure)
                exploreMessage = "You dive deeper into the darkness..."
                if math.random() < (0.2 + player.depth / 500) then
                    startCombat()
                else
                    changeGameState(GAME_STATE.EXPLORE)
                end
            elseif buttons.exploreButton.hover then
                if math.random() < 0.4 then
                    local gold = math.random(5, 15)
                    player.gold = player.gold + gold
                    exploreMessage = string.format("You find %d gold in the depths!", gold)
                else
                    exploreMessage = "You find nothing but darkness..."
                end
                changeGameState(GAME_STATE.EXPLORE)
            elseif buttons.ascendButton.hover then
                if player.depth < 5 then
                    exploreMessage = "You're too close to the surface to ascend further!"
                else
                    player.depth = math.max(0, player.depth - 5)
                    player.pressure = math.max(0, player.pressure - 10)
                    exploreMessage = "You rise toward the surface..."
                end
                changeGameState(GAME_STATE.EXPLORE)
            end
        end,
        [GAME_STATE.COMBAT] = function()
            if buttons.attackButton.hover then
                playerAttack()
            elseif buttons.defendButton.hover then
                playerDefend()
            elseif buttons.regenButton.hover then
                playerRegenOxygen()
            elseif buttons.runButton.hover then
                playerRun()
            elseif buttons.endTurnButton.hover then
                player.energy = player.maxEnergy
                enemyTurn()
            end
        end,
        [GAME_STATE.GAME_OVER] = function()
            if buttons.restartButton.hover then
                newGame()
                changeGameState(GAME_STATE.MENU)
            end
        end
    }
    
    if actions[currentState] then actions[currentState]() end
end

function love.keypressed(key)
    if key == "escape" then
        if currentState == GAME_STATE.MENU then
            love.event.quit()
        else
            changeGameState(GAME_STATE.MENU)
        end
    end
    
    if key == "d" then
        debugMode = not debugMode
    end
end

function love.quit()
    cleanup()
    return false
end

