package combat

import rl "vendor:raylib"
import "core:fmt"

screenWidth :: 1000;
screenHeight :: 800;

Options :: struct {
    name: cstring,
}

Animation_State :: enum {
    Idle,
    Attack,
    Hurt,
    Death,
}

Combat_State :: enum {
    PlayerTurn,         
    PlayerActionExecuting,  
    EnemyTurn,          
    EnemyActionExecuting,   
    BattleOver          
}

Animation :: struct {
    texture: rl.Texture2D,
    num_frames: int,
    frame_timer: f32,
    current_frame: int,
    frame_length: f32,
    state: Animation_State,
}

SpriteTextures :: struct {
    idle: rl.Texture2D,
    attack: rl.Texture2D,
    hurt: rl.Texture2D,
    death: rl.Texture2D,
}

SpriteAnimations :: struct {
    idle: Animation,
    attack: Animation,
    hurt: Animation,
    death: Animation,
}

update_animation :: proc(a: ^Animation) {
    using rl;
    a.frame_timer += GetFrameTime();
    if a.frame_timer >= a.frame_length {
        a.frame_timer -= a.frame_length;
        a.current_frame += 1;
        if a.current_frame >= a.num_frames {
            a.current_frame = 0;
        }
    }
}

Enemy :: struct {
    position: rl.Vector2,
    animation: ^Animation,
    health: int,
    damage: ^int,
    max_health: int,
    dead: bool,
    name: cstring,
}

Player :: struct {
    health: int,
    strength: int,
    defense: int,
    agility: int,
    dexterity: int,
    intelligence: int,
    dead: bool,
    level: int,
    current_xp: int,
    max_xp: int,
    defending: bool,
}

init_player :: proc() -> Player {
    return Player{
        health = 100,
        strength = 10,
        defense = 5,
        agility = 3,
        dexterity = 5,
        intelligence = 1,
        dead = false,
        level = 1,
        current_xp = 0,
        max_xp = 100,
        defending = false,
    }
}

spawn_enemy :: proc(pos: rl.Vector2, anim: ^Animation, enemy_name: cstring) -> Enemy {
    damage_value: int = 5
    return Enemy{
        position = pos,
        animation = anim,
        health = 100,
        damage = &damage_value,
        max_health = 100,
        dead = false,
        name = enemy_name,
    };
}

draw_animation :: proc(a: Animation, pos: rl.Vector2, flip: bool) {
    using rl;
    width := f32(a.texture.width) / f32(a.num_frames);
    height := f32(a.texture.height);
    source := Rectangle {
        x = f32(a.current_frame) * width,
        y = 0,
        width = flip ? -width : width,
        height = height,
    };
    dest := Rectangle {
        x = pos.x,
        y = pos.y,
        width = width * 4,
        height = height * 4,
    };
    DrawTexturePro(a.texture, source, dest, {dest.width / 2, dest.height / 2}, 0, WHITE);
}

load_animation :: proc(tex: rl.Texture2D, frames: int, frame_time: f32, state: Animation_State) -> Animation {
    if tex.id == 0 {
        fmt.println("ERROR: Texture is not loaded properly!");
    }
    return Animation {
        texture = tex,
        num_frames = frames,
        frame_timer = 0,
        current_frame = 0,
        frame_length = frame_time,
        state = state,
    };
}

// Improved error checking for texture loading
check_sprite_textures :: proc(textures: SpriteTextures) -> bool {
    if textures.idle.id == 0 || 
       textures.attack.id == 0 || 
       textures.hurt.id == 0 || 
       textures.death.id == 0 {
        fmt.println("ERROR: One or more enemy sprite textures failed to load!");
        return false;
    }
    return true;
}

update_enemy_animation :: proc(enemy: ^Enemy, anims: ^SpriteAnimations) -> bool {
    animation_completed := false;
    
    if enemy.dead {
        return false;
    }

    update_animation(enemy.animation);

    // Check if attack animation completed
    if enemy.animation.state == .Attack {
        if enemy.animation.current_frame == enemy.animation.num_frames - 1 {
            enemy.animation = &anims.idle;
            enemy.animation.state = .Idle;
            enemy.animation.current_frame = 0;
            enemy.animation.frame_timer = 0;
            animation_completed = true;
        }
    }

    // Handle Death Animation Completion
    if enemy.animation.state == .Death {
        if enemy.animation.current_frame == enemy.animation.num_frames - 1 {
            enemy.animation.current_frame = enemy.animation.num_frames - 1;
            enemy.dead = true;
            animation_completed = true;
        }
        return animation_completed;
    }

    // Handle Hurt Animation Completion
    if enemy.animation.state == .Hurt {
        if enemy.animation.current_frame == enemy.animation.num_frames - 1 {
            enemy.animation = &anims.idle;
            enemy.animation.state = .Idle;
            enemy.animation.current_frame = 0;
            enemy.animation.frame_timer = 0;
            animation_completed = true;
        }
    }
    
    return animation_completed;
}

damage_enemy :: proc(enemy: ^Enemy, amount: int, anims: ^SpriteAnimations) {
    if enemy.dead {
        return; // Don't process damage on a dead enemy
    }

    enemy.health -= amount;
    if enemy.health <= 0 {
        enemy.health = 0;
        enemy.animation = &anims.death; // Switch to death animation
        enemy.animation.state = .Death;
        fmt.printf("%s was defeated!\n", enemy.name);
    } else {
        enemy.animation = &anims.hurt; // Switch to hurt animation
        enemy.animation.state = .Hurt;
        fmt.printf("%s took %d damage! %d HP remaining.\n", enemy.name, amount, enemy.health);
    }
    enemy.animation.current_frame = 0;
    enemy.animation.frame_timer = 0;
}

damage_player :: proc(enemy: ^Enemy, player: ^Player, amount: ^int, slime_anims, plant_anims: ^SpriteAnimations) {
    if player.dead {
        return;
    }
    
    // Choose correct animation set based on enemy
    animation_set := enemy.name == "Slime" ? slime_anims : plant_anims

    enemy.animation = &animation_set.attack;
    enemy.animation.state = .Attack;
    enemy.animation.current_frame = 0;
    enemy.animation.frame_timer = 0;

    player.health -= amount^;
    if player.health <= 0 {
        player.health = 0;
        player.dead = true;
        fmt.println("You died!");
    } else {
        fmt.printf("%s attacks! You take %d damage! %d health remaining\n", enemy.name, amount^, player.health);
    }
}

// Utility functions added/improved
use_item :: proc(item_name: cstring, target: ^Enemy, player: ^Player, slime_enemy: ^Enemy, slime_anims: ^SpriteAnimations, plant_enemy: ^Enemy, plant_anims: ^SpriteAnimations) -> bool {
    if item_name == "Cloudy Vial" {
        // Healing potion
        if player.health < 100 {
            healing_amount := 30;
            player.health += healing_amount;
            if player.health > 100 {
                player.health = 100;
            }
            fmt.printf("Used %s! Healed for %d points. Health now: %d\n", 
                      item_name, healing_amount, player.health);
            return true;
        } else {
            fmt.println("Health is already full!");
            return false;
        }
    } else if item_name == "Vigor Vial" {
        // Strength boost
        strength_boost := 5;
        player.strength += strength_boost;
        fmt.printf("Used %s! Strength increased by %d points. Strength now: %d\n", 
                  item_name, strength_boost, player.strength);
        return true;
    } else if item_name == "Bomb" {
        // Damage item
        damage_amount := 25;
        
        if target == slime_enemy {
            damage_enemy(target, damage_amount, slime_anims);
        } else {
            damage_enemy(target, damage_amount, plant_anims);
        }
        
        fmt.printf("Used %s! Dealt %d damage to %s\n", 
                  item_name, damage_amount, target.name);
        return true;
    } else {
        fmt.printf("Unknown item: %s\n", item_name);
        return false;
    }
}

add_item :: proc(item_name: cstring, item_options: ^[dynamic]Options) {
    new_item := Options{name = item_name};
    append(item_options, new_item);
}

remove_item :: proc(index: int, item_options: ^[dynamic]Options) {
    if index >= 0 && index < len(item_options) {
        ordered_remove(item_options, index);
    }
}

update_player_stats :: proc(player: Player, stats: ^[]int) {
    stats[0] = player.health;
    stats[1] = player.strength;
    stats[2] = player.defense;
    stats[3] = player.agility;
    stats[4] = player.dexterity;
    stats[5] = player.intelligence;
}

all_enemies_defeated :: proc(enemies: ..^Enemy) -> bool {
    for enemy in enemies {
        if !enemy.dead {
            return false;
        }
    }
    return true;
}

save_game :: proc(player: Player, slime_enemy: Enemy, plant_enemy: Enemy) -> bool {
    // Placeholder for save game functionality
    fmt.println("Game saved successfully!");
    return true;
}


main :: proc() {
    using rl;
    InitWindow(screenWidth, screenHeight, "Tales Of Askel");
    defer CloseWindow();
    SetTargetFPS(60);
    SetExitKey(.Q);

    // Main menu options
    menuOptions: []Options = {
        { name = "Attack"   }, 
        { name = "Defend"   },
        { name = "Stats"    },
        { name = "Items"    },
        { name = "Settings" },
    };

    // Stats menu options
    statsOptions: []Options = {
        { name = "Hp"  },
        { name = "Str" }, 
        { name = "Def" },
        { name = "Agi" },
        { name = "Dex" },
        { name = "Int" },
    };
    mchar := init_player();
    player_stats: []int = {mchar.health, mchar.strength, mchar.defense, mchar.agility, mchar.dexterity, mchar.intelligence};
    
    // Available items in game
    itemsDict: []Options = {
        { name = "Cloudy Vial" },
        { name = "Vigor Vial"  },
        { name = "Bomb"        },
    };

    // Item menu options
    itemOptions: [dynamic]Options = make([dynamic]Options, 0, 10);   
    add_item("Cloudy Vial", &itemOptions);

    // Settings menu options
    settingsOptions: []Options = {
        { name = "Save" },
        { name = "Quit" },
    };

    Level1 := LoadTexture("assets/Levels/LevelNormal.png");
    defer UnloadTexture(Level1);

    if Level1.width == 0 || Level1.height == 0 {
        fmt.println("ERROR: Failed to load Level1 texture!");
    } else {
        fmt.println("Loaded Level1 texture:", Level1.width, "x", Level1.height);
    }

    // Main menu
    menuSelectedIndex: i32 = 0;
    menuX: i32 = 23;
    menuY: i32 = screenHeight - 238;
    menuWidth: i32 = 175;
    menuHeight: i32 = 35;
    spacing: i32 = 10;
    menuPadding: i32 = 20;
    totalMenuHeight: i32 = (menuHeight + spacing) * i32(len(menuOptions)) - spacing;
    menuBoxHeight: i32 = totalMenuHeight + menuPadding * 2;
    menuBoxWidth: i32 = menuWidth + menuPadding * 2;

    // Stats menu 
    statsSelectedIndex: i32 = 0;
    inStatsMenu: bool = false;
    statsMenuX: i32 = menuX + menuBoxWidth + 6;
    statsMenuY: i32 = menuY;
    statsMenuWidth: i32 = 175;
    statsMenuHeight: i32 = 35;
    statsMenuBoxWidth: i32 = statsMenuWidth + menuPadding * 2;
    statsTotalHeight: i32 = (statsMenuHeight + spacing) * i32(len(statsOptions)) - spacing;
    statsMenuBoxHeight: i32 = statsTotalHeight + menuPadding * 2;

    // Item menu
    itemSelectedIndex: i32 = 0;
    inItemMenu: bool = false;
    itemMenuX: i32 = menuX + menuBoxWidth + 6;
    itemMenuY: i32 = menuY;
    itemMenuWidth: i32 = 175;
    itemMenuHeight: i32 = 35;
    itemMenuBoxWidth: i32 = itemMenuWidth + menuPadding * 2;
    itemTotalHeight: i32 = (itemMenuHeight + spacing) * i32(len(itemOptions)) - spacing;
    itemMenuBoxHeight: i32 = itemTotalHeight + menuPadding * 2;
    
    // Settings menu
    settingsSelectedIndex: i32 = 0;
    inSettingsMenu: bool = false;
    settingsMenuX: i32 = menuX + menuBoxWidth + 6;
    settingsMenuY: i32 = menuY;
    settingsMenuWidth: i32 = 175;
    settingsMenuHeight: i32 = 35;
    settingsMenuBoxWidth: i32 = settingsMenuWidth + menuPadding * 2;
    settingsTotalHeight: i32 = (settingsMenuHeight + spacing) * i32(len(settingsOptions)) - spacing;
    settingsMenuBoxHeight: i32 = settingsTotalHeight + menuPadding * 2;

    // Xp bar
    xpBarX: i32 = menuX;
    xpBarY: i32 = menuY - 50;
    xpBarWidth: i32 = 180;
    xpBarHeight: i32 = 10;

    // Enemies
    slime_textures := SpriteTextures {
        idle = LoadTexture("assets/Slime_Idle.png"),
        attack = LoadTexture("assets/Slime_Attack.png"),
        hurt = LoadTexture("assets/Slime_Hurt.png"),
        death = LoadTexture("assets/Slime_Death.png"),
    };

    if !check_sprite_textures(slime_textures) {
        fmt.println("Failed to load slime textures. Exiting...");
        CloseWindow();
        return;
    }

    slime_animations := SpriteAnimations {
        idle = load_animation(slime_textures.idle, 6, 0.2, .Idle),
        attack = load_animation(slime_textures.attack, 10, 0.1, .Attack),
        hurt = load_animation(slime_textures.hurt, 5, 0.1, .Hurt),
        death = load_animation(slime_textures.death, 10, 0.15, .Death),
    };

    plant_textures := SpriteTextures {
        idle = LoadTexture("assets/Plant_Idle.png"),
        attack = LoadTexture("assets/Plant_Attack.png"),
        hurt = LoadTexture("assets/Plant_Hurt.png"),
        death = LoadTexture("assets/Plant_Death.png"),
    };

    if !check_sprite_textures(plant_textures) {
        fmt.println("Failed to load plant textures. Exiting...");
        CloseWindow();
        return;
    }

    plant_animations := SpriteAnimations {
        idle = load_animation(plant_textures.idle, 4, 0.2, .Idle),
        attack = load_animation(plant_textures.attack, 7, 0.1, .Attack),
        hurt = load_animation(plant_textures.hurt, 5, 0.1, .Hurt),
        death = load_animation(plant_textures.death, 10, 0.15, .Death),
    };

    defer UnloadTexture(slime_textures.idle);
    defer UnloadTexture(slime_textures.attack);
    defer UnloadTexture(slime_textures.hurt);
    defer UnloadTexture(slime_textures.death);
    defer UnloadTexture(plant_textures.idle);
    defer UnloadTexture(plant_textures.attack);
    defer UnloadTexture(plant_textures.hurt);
    defer UnloadTexture(plant_textures.death);

    current_slime_anim: ^Animation = &slime_animations.idle;
    slime_pos := Vector2{ f32(GetScreenWidth()) / 2 - 50, f32(GetScreenHeight()) / 2 };
    slime_enemy := spawn_enemy(slime_pos, current_slime_anim, "Slime");
    
    current_plant_anim: ^Animation = &plant_animations.idle;
    plant_pos := Vector2{ f32(GetScreenWidth()) / 2 + 100, f32(GetScreenHeight()) / 2 };
    plant_enemy := spawn_enemy(plant_pos, current_plant_anim, "Plant");

    controlsVisible := false;
    
    // Initialize combat state to player's turn
    combat_state := Combat_State.PlayerTurn;
    
    // Create an active enemy reference for easier targeting
    active_enemy := &slime_enemy;
    
    // Status message for UI feedback
    status_message: cstring = "Your turn! Choose an action.";
    
    // Combat timer for pacing animations and actions
    combat_timer: f32 = 0;
    enemy_turn_delay: f32 = 0.1; // Seconds to wait before enemy attacks

    // Main game loop
    for !WindowShouldClose() {
        dt := GetFrameTime();
        combat_timer += dt;
        
        // Update animations for both enemies
        slime_animation_completed := update_enemy_animation(&slime_enemy, &slime_animations);
        plant_animation_completed := update_enemy_animation(&plant_enemy, &plant_animations);
        
        // Combat state machine
        switch combat_state {
        case .PlayerTurn:
            // Allow menu navigation during player's turn
            if !inItemMenu && !inSettingsMenu && !inStatsMenu {
                if IsKeyPressed(.W) {
                    menuSelectedIndex -= 1;
                    if menuSelectedIndex < 0 {
                        menuSelectedIndex = i32(len(menuOptions)) - 1;
                    }
                }

                if IsKeyPressed(.S) {
                    menuSelectedIndex += 1;
                    if menuSelectedIndex >= i32(len(menuOptions)) {
                        menuSelectedIndex = 0;
                    }
                }

                if IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D) {
                    if menuSelectedIndex == 0 { // Attack
                        fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                        damage_enemy(active_enemy, mchar.strength, &slime_animations);
                        status_message = "You attack!";
                        combat_state = .PlayerActionExecuting;
                    } else if menuSelectedIndex == 1 { // Defend
                        fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                        status_message = "You take a defensive stance!";
                        mchar.defense += 5;
                        mchar.defending = true;
                        combat_state = .EnemyTurn;
                        combat_timer = 0;
                    } else if menuSelectedIndex == 2 { // Stats
                        fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                        inStatsMenu = true;
                    } else if menuSelectedIndex == 3 { // Items
                        fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                        inItemMenu = true;
                    } else if menuSelectedIndex == 4 { // Settings
                        fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                        inSettingsMenu = true;
                    }
                }
            } else if inStatsMenu {
                // Stats menu controls
                if IsKeyPressed(.W) {
                    statsSelectedIndex -= 1;
                    if statsSelectedIndex < 0 {
                        statsSelectedIndex = i32(len(statsOptions)) - 1;
                    }
                }

                if IsKeyPressed(.S) {
                    statsSelectedIndex += 1;
                    if statsSelectedIndex >= i32(len(statsOptions)) {
                        statsSelectedIndex = 0;
                    }
                }

                if IsKeyPressed(.A) || IsKeyPressed(.ESCAPE) {
                    inStatsMenu = false;
                }
            } else if inItemMenu {
                // Item menu controls
                if IsKeyPressed(.W) {
                    itemSelectedIndex -= 1;
                    if itemSelectedIndex < 0 {
                        itemSelectedIndex = i32(len(itemOptions)) - 1;
                    }
                }

                if IsKeyPressed(.S) {
                    itemSelectedIndex += 1;
                    if itemSelectedIndex >= i32(len(itemOptions)) {
                        itemSelectedIndex = 0;
                    }
                }

                if IsKeyPressed(.A) || IsKeyPressed(.ESCAPE) {
                    inItemMenu = false;
                }

                if IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D) && len(itemOptions) > 0 {
                    item_name := itemOptions[itemSelectedIndex].name;
                    fmt.println("Used item:", item_name);
    
                    if use_item(item_name, active_enemy, &mchar, &slime_enemy, &slime_animations, &plant_enemy, &plant_animations) {
                        // If item was used successfully, remove it from inventory
                        remove_item(int(itemSelectedIndex), &itemOptions);
                        inItemMenu = false;
                        combat_state = .EnemyTurn;
                        combat_timer = 0;
                        }
                }
            } else if inSettingsMenu {
                // Settings menu controls
                if IsKeyPressed(.W) {
                    settingsSelectedIndex -= 1;
                    if settingsSelectedIndex < 0 {
                        settingsSelectedIndex = i32(len(settingsOptions)) - 1;
                    }
                }

                if IsKeyPressed(.S) {
                    settingsSelectedIndex += 1;
                    if settingsSelectedIndex >= i32(len(settingsOptions)) {
                        settingsSelectedIndex = 0;
                    }
                }

                if IsKeyPressed(.A) || IsKeyPressed(.ESCAPE) {
                    inSettingsMenu = false;
                }

                if IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D) {
                    fmt.println("Used setting:", settingsOptions[settingsSelectedIndex].name);
                    if settingsOptions[settingsSelectedIndex].name == "Quit" {
                        CloseWindow();
                    }
                }
            }
            
        case .PlayerActionExecuting:
            // Check if animation has completed or enough time has passed
            anim_completed := false;
            
            if active_enemy == &slime_enemy {
                anim_completed = slime_animation_completed;
            } else if active_enemy == &plant_enemy {
                anim_completed = plant_animation_completed;
            }
            
            // Also add a timeout in case animation gets stuck
            if anim_completed || combat_timer > 1.0 {
                if active_enemy.dead {
                    // Check if all enemies are defeated
                    if all_enemies_defeated(&slime_enemy, &plant_enemy) {
                        status_message = "All enemies defeated!";
                        combat_state = .BattleOver;
                    } else {
                        // Find next enemy
                        if active_enemy == &slime_enemy && !plant_enemy.dead {
                            active_enemy = &plant_enemy;
                        } else if active_enemy == &plant_enemy && !slime_enemy.dead {
                            active_enemy = &slime_enemy;
                        }
                        status_message = "Enemy's turn...";
                        combat_state = .EnemyTurn;
                        combat_timer = 0;
                    }
                } else {
                    status_message = "Enemy's turn...";
                    combat_state = .EnemyTurn;
                    combat_timer = 0;
                }
            }

        // In the EnemyTurn case:
        case .EnemyTurn:
            // Ensure we have a timer delay before enemy attacks
            if combat_timer >= enemy_turn_delay {
                // Find a live enemy to attack if current one is dead
                if active_enemy.dead {
                    if !slime_enemy.dead {
                        active_enemy = &slime_enemy;
                    } else if !plant_enemy.dead {
                        active_enemy = &plant_enemy;
                    } else {
                        // All enemies dead
                        status_message = "Victory!";
                        combat_state = .BattleOver;
                        break;
                    }
                }
                
                if !active_enemy.dead {
                    status_message = "Enemy is attacking!";
                    if mchar.defending {
                        // Use a reduced damage amount
                        reduced_damage := max(1, active_enemy.damage^ - mchar.defense);
                        temp_damage := reduced_damage;
                        damage_player(active_enemy, &mchar, &temp_damage, &slime_animations, &plant_animations);
                        mchar.defending = false; // Reset defending flag
                        mchar.defense -= 5; // Remove temporary defense boost
                    } else {
                        damage_player(active_enemy, &mchar, active_enemy.damage, &slime_animations, &plant_animations);
                    }
                    
                    combat_state = .EnemyActionExecuting;
                    combat_timer = 0;
                }
            }

        // In the EnemyActionExecuting case:
        case .EnemyActionExecuting:
            // Add timeout mechanism
            animation_completed := false;
            
            if active_enemy == &slime_enemy {
                animation_completed = slime_animation_completed;
            } else if active_enemy == &plant_enemy {
                animation_completed = plant_animation_completed;
            }
            
            // Force completion after reasonable timeout
            if animation_completed || combat_timer > 1.0 {
                if mchar.dead {
                    status_message = "You have been defeated!";
                    combat_state = .BattleOver;
                } else {
                    status_message = "Your turn! Choose an action.";
                    combat_state = .PlayerTurn;
                }
            }

        case .BattleOver:
            // Battle is over, player can view results
            if IsKeyPressed(.SPACE) || IsKeyPressed(.ENTER) {
                // If player wants to start a new battle, reset state
                if mchar.dead {
                    // Reset player
                    mchar = init_player();
                    player_stats[0] = mchar.health;
                }
                
                // Reset both enemies
                slime_enemy.dead = false;
                slime_enemy.health = slime_enemy.max_health;
                slime_enemy.animation = &slime_animations.idle;
                slime_enemy.animation.state = .Idle;

                plant_enemy.dead = false;
                plant_enemy.health = plant_enemy.max_health;
                plant_enemy.animation = &plant_animations.idle;
                plant_enemy.animation.state = .Idle;

                // Set active enemy back to slime as default
                active_enemy = &slime_enemy;
                
                status_message = "Your turn! Choose an action.";
                combat_state = .PlayerTurn;
            }
        }

        // Draw
        BeginDrawing();
        ClearBackground(RAYWHITE);

        // Draw background texture
        if Level1.width > 0 && Level1.height > 0 {
            DrawTexturePro(
                Level1,
                Rectangle{ 0, 0, f32(Level1.width), f32(Level1.height) }, 
                Rectangle{ 0, 0, f32(screenWidth), f32(screenHeight) },
                Vector2{ 0, 0 },  
                0,                
                WHITE             
            );
        }
        
        // Display combat status
        DrawRectangle(screenWidth/2 - 200, 20, 400, 40, ColorAlpha(GRAY, 0.65));
        DrawRectangleLines(screenWidth/2 - 200, 20, 400, 40, BLACK);
        DrawText(status_message, screenWidth/2 - 190, 30, 20, BLACK);
        
        // Display control help
        if IsKeyPressed(.H) {
            controlsVisible = !controlsVisible;
        }

        if controlsVisible {
            DrawRectangle(5, 5, 250, 110, ColorAlpha(GRAY, 0.65));
            DrawRectangleLines(5, 5, 250, 110, BLACK);
            DrawText("W/S to navigate", 10, 10, 17, BLACK);
            DrawText("ENTER/SPACE/D to select", 10, 30, 17, BLACK);
            DrawText("A/ESCAPE to deselect", 10, 50, 17, BLACK);
            DrawText("Q to quit", 10, 70, 17, BLACK);
            DrawText("TAB to toggle between enemy", 10, 90, 17, BLACK);
        } else {
            DrawText("Press H to show controls", 10, 10, 17, BLACK);
        }

        // Draw player health bar
        DrawRectangle(xpBarX - 20, xpBarY - 50, 200, 20, RED);
        DrawRectangle(xpBarX - 20, xpBarY - 50, i32(200 * mchar.health) / 100, 20, GREEN);
        DrawRectangleLines(xpBarX - 20, xpBarY - 50, 200, 20, BLACK);
        health_text := fmt.ctprintf("HP: %d/%d", mchar.health, 100);
        DrawText(health_text, xpBarX - 16, xpBarY - 50, 18, BLACK);

        // Draw enemy health bar
        if !slime_enemy.dead {
            enemy_bar_width := 100
            enemy_bar_x := i32(slime_enemy.position.x) - i32(enemy_bar_width / 2)
            enemy_bar_y := i32(slime_enemy.position.y + 100)  // Position below the sprite

            // Background (missing health) bar
            DrawRectangle(enemy_bar_x, enemy_bar_y, i32(enemy_bar_width), 10, RED)
    
            // Current health bar
            current_bar_width := i32((enemy_bar_width * slime_enemy.health) / slime_enemy.max_health)
            DrawRectangle(enemy_bar_x, enemy_bar_y, i32(current_bar_width), 10, GREEN)
    
            // Outline
            DrawRectangleLines(enemy_bar_x, enemy_bar_y, i32(enemy_bar_width), 10, BLACK)
        }

        // Draw the plant enemy health bar
        if !plant_enemy.dead {
            enemy_bar_width := 100
            enemy_bar_x := i32(plant_enemy.position.x) - i32(enemy_bar_width / 2)
            enemy_bar_y := i32(plant_enemy.position.y + 100)  // Position below the sprite

            // Background (missing health) bar
            DrawRectangle(enemy_bar_x, enemy_bar_y, i32(enemy_bar_width), 10, RED)
    
            // Current health bar
            current_bar_width := i32((enemy_bar_width * plant_enemy.health) / plant_enemy.max_health)
            DrawRectangle(enemy_bar_x, enemy_bar_y, current_bar_width, 10, GREEN)
    
            // Outline
            DrawRectangleLines(enemy_bar_x, enemy_bar_y, i32(enemy_bar_width), 10, BLACK)
        }

        // Draw main menu
        DrawRectangle(menuX - menuPadding, menuY - menuPadding, menuBoxWidth, menuBoxHeight, ColorAlpha(GRAY, 0.50));
        DrawRectangleLines(menuX - menuPadding, menuY - menuPadding, menuBoxWidth, menuBoxHeight, BLACK);

        // Display main menu options
        i: i32 = 0;
        for option in menuOptions {
            optionY := menuY + (menuHeight + spacing) * i;

            if i == menuSelectedIndex {
                DrawRectangle(menuX - 5, optionY - 3, menuWidth, menuHeight, BLUE);
                DrawRectangleLines(menuX - 5, optionY - 3, menuWidth, menuHeight, BLACK);
                DrawText(option.name, menuX + 5, optionY + 5, 20, RAYWHITE);
            } else {
                DrawText(option.name, menuX + 5, optionY + 5, 20, BLACK);
            }

            i += 1;
        }

        // Draw stats menu
        if inStatsMenu {
            DrawRectangle(statsMenuX - menuPadding, statsMenuY - menuPadding, statsMenuBoxWidth, statsMenuBoxHeight, ColorAlpha(DARKGRAY, 0.50));
            DrawRectangleLines(statsMenuX - menuPadding, statsMenuY - menuPadding, statsMenuBoxWidth, statsMenuBoxHeight, BLACK);

            // Display item menu options
            i = 0;
            for stats in statsOptions {
                statsY := statsMenuY + (statsMenuHeight + spacing) * i;
                statsNum := fmt.ctprintf("%v", player_stats[i]);
                statsWrdNum := fmt.ctprintf("%v : %v", stats.name, statsNum); 
                DrawText(statsWrdNum, statsMenuX + 5, statsY + 6, 20, BLACK);
                i += 1;
            }
        }

        // Draw item menu
        if inItemMenu {
            DrawRectangle(itemMenuX - menuPadding, itemMenuY - menuPadding, itemMenuBoxWidth, itemMenuBoxHeight, ColorAlpha(DARKGRAY, 0.50));
            DrawRectangleLines(itemMenuX - menuPadding, itemMenuY - menuPadding, itemMenuBoxWidth, itemMenuBoxHeight, BLACK);

            // Display item menu options
            if len(itemOptions) > 0 {
                for i: i32 = 0; i < i32(len(itemOptions)); i += 1 {
                    itemY := i32(itemMenuY + i32(itemMenuHeight + spacing) * i);
            
                    if i == itemSelectedIndex {
                        DrawRectangle(
                            itemMenuX - 5, 
                            itemY - 3, 
                            itemMenuWidth, 
                            itemMenuHeight, 
                            BLUE
                        )
                        DrawRectangleLines(
                            itemMenuX - 5, 
                            itemY - 3, 
                            itemMenuWidth, 
                            itemMenuHeight, 
                            BLACK
                        )
                        DrawText(
                            itemOptions[i].name, 
                            itemMenuX + 5, 
                            itemY + 5, 
                            20, 
                            RAYWHITE
                        )
                    } else {
                        DrawText(
                            itemOptions[i].name, 
                            itemMenuX + 5, 
                            itemY + 5, 
                            20, 
                            BLACK
                        )
                    }
                }
            } else {
                DrawText(
                    "No items available", 
                    itemMenuX + 5, 
                    itemMenuY + 5, 
                    20, 
                    BLACK
                )
            }
        }

        // Draw settings menu
        if inSettingsMenu {
            DrawRectangle(settingsMenuX - menuPadding, settingsMenuY - menuPadding, settingsMenuBoxWidth, settingsMenuBoxHeight, ColorAlpha(DARKGRAY, 0.50));
            DrawRectangleLines(settingsMenuX - menuPadding, settingsMenuY - menuPadding, settingsMenuBoxWidth, settingsMenuBoxHeight, BLACK);

            // Display settings menu options
            i = 0;
            for setting in settingsOptions {
                settingsY := settingsMenuY + (settingsMenuHeight + spacing) * i;

                if i == settingsSelectedIndex {
                    DrawRectangle(settingsMenuX - 5, settingsY - 3, settingsMenuWidth, settingsMenuHeight, BLUE);
                    DrawRectangleLines(settingsMenuX - 5, settingsY - 3, settingsMenuWidth, settingsMenuHeight, BLACK);
                    DrawText(setting.name, settingsMenuX + 5, settingsY + 5, 20, RAYWHITE);
                } else {
                    DrawText(setting.name, settingsMenuX + 5, settingsY + 5, 20, BLACK);
                }

                i += 1;
            }
        }
 
        // Draw the slime enemy if it's not dead or if the death animation isn't complete
        // Draw both enemies before battle over message
        if !(slime_enemy.dead && slime_enemy.animation.state == .Death && 
            slime_enemy.animation.current_frame == slime_enemy.animation.num_frames - 1) {
            draw_animation(slime_enemy.animation^, slime_enemy.position, false);
        }

        if !(plant_enemy.dead && plant_enemy.animation.state == .Death && 
            plant_enemy.animation.current_frame == plant_enemy.animation.num_frames - 1) {
            draw_animation(plant_enemy.animation^, plant_enemy.position, false);
        }

        // Draw battle over message
        if combat_state == .BattleOver {
            DrawRectangle(screenWidth/2 - 200, screenHeight/2 - 50, 400, 100, ColorAlpha(DARKBLUE, 0.8));
            DrawRectangleLines(screenWidth/2 - 200, screenHeight/2 - 50, 400, 100, BLACK);
            
            if mchar.dead {
                DrawText("You have been defeated!", screenWidth/2 - 150, screenHeight/2 - 30, 20, WHITE);
            } else {
                DrawText("Victory!", screenWidth/2 - 40, screenHeight/2 - 30, 20, WHITE);
            }
            
            DrawText("Press ENTER to continue", screenWidth/2 - 140, screenHeight/2 + 10, 20, WHITE);
        }

        // Draw plant enemy if it's not dead or if the death animation isn't complete
        if !(plant_enemy.dead && plant_enemy.animation.state == .Death && 
             plant_enemy.animation.current_frame == plant_enemy.animation.num_frames - 1) {
            draw_animation(plant_enemy.animation^, plant_enemy.position, false);
        }

        // Target selection indicator when attacking
        if combat_state == .PlayerTurn && menuSelectedIndex == 0 && !inStatsMenu && !inItemMenu && !inSettingsMenu {
            // Draw a target indicator over the active enemy
            if !active_enemy.dead {
                DrawCircle(
                    i32(active_enemy.position.x),
                    i32(active_enemy.position.y - 40), 
                    7, 
                    RED
                );     
                
                // Handle target switching
                if IsKeyPressed(.TAB) {
                    if active_enemy == &slime_enemy && !plant_enemy.dead {
                        active_enemy = &plant_enemy;
                    } else if active_enemy == &plant_enemy && !slime_enemy.dead {
                        active_enemy = &slime_enemy;
                    }
                }
            }
        }
        
        if combat_state == .EnemyActionExecuting {
            // Draw attack effect from enemy to player
            DrawLine(
                i32(active_enemy.position.x - 40), 
                i32(active_enemy.position.y), 
                160, 
                screenHeight / 2, 
                ORANGE
            );
            
            // Draw attack particles
            for i := 0; i < 5; i += 1 {
                DrawCircle(
                    160 + GetRandomValue(-20, 20), 
                    screenHeight / 2 + GetRandomValue(-20, 20), 
                    f32(GetRandomValue(2, 5)), 
                    ORANGE
                );
            }
        }
        
        // Draw item and ability cooldowns
        /*if combat_state == .PlayerTurn {
            // Add cooldown indicators for abilities (if implemented)
            cooldown_x : i32 = 20;
            cooldown_y : i32 = 130;

            DrawRectangle(cooldown_x - 3, cooldown_y - 3, 165, 125, ColorAlpha(GRAY, 0.50));
            DrawRectangleLines(cooldown_x - 3, cooldown_y - 3, 165, 125, BLACK);
            DrawText("Abilities:", cooldown_x, cooldown_y, 18, BLACK);
            
            // Sample ability cooldowns (can be integrated with actual ability system)
            ability_names := []cstring{"Attack", "Fireball", "Heal"};
            ability_cooldowns := []i32{0, 2, 1}; // Turns remaining

            for i := 0; i < len(ability_names); i += 1 {
                y_pos := i32(cooldown_y + 25 + i32(i * 25));
                DrawText(ability_names[i], cooldown_x, y_pos, 16, BLACK);
                
                if ability_cooldowns[i] > 0 {
                    cooldown_text := fmt.ctprintf("(%d)", ability_cooldowns[i]);
                    DrawText(cooldown_text, cooldown_x + 100, y_pos, 16, RED);
                } else {
                    DrawText("(Ready)", cooldown_x + 100, y_pos, 16, GREEN);
                }
            }
        }*/
        
        // Draw battle log
        DrawRectangle(screenWidth - 250, screenHeight - 150, 230, 130, ColorAlpha(GRAY, 0.50));
        DrawRectangleLines(screenWidth - 250, screenHeight - 150, 230, 130, BLACK);
        DrawText("Battle Log:", screenWidth - 240, screenHeight - 140, 18, BLACK);
        
        // Sample battle log entries (can be integrated with actual logging system)
        /*log_entries := []cstring{
            "You attacked the enemy!",
            "Enemy took 10 damage",
            "Enemy attacked you",
            "You took 5 damage"
        };*/
        
        /*for i := 0; i < len(log_entries); i += 1 {
            y_pos := screenHeight - 115 + (i * 20);
            DrawText(log_entries[i], screenWidth - 240, i32(y_pos), 14, BLACK);
        }*/
        
        // Add experience and level information
        DrawRectangle(xpBarX - 20, xpBarY - 24, xpBarWidth + 20, xpBarHeight + 39, ColorAlpha(GRAY, 0.50));
        DrawRectangleLines(xpBarX - 20, xpBarY - 24, xpBarWidth + 20, xpBarHeight + 39, BLACK);
        
        player_level := mchar.level; // Sample level
        player_exp: i32 = 0; // Current XP
        exp_needed: i32 = 100; // XP needed for next level
        
        level_text := fmt.ctprintf("Level: %d", player_level);
        DrawText(level_text, xpBarX - 18, xpBarY - 24, 18, BLACK);
        
        // Draw XP bar
        DrawRectangle(xpBarX - 15, xpBarY - 5, xpBarWidth, xpBarHeight, GRAY);
        xp_bar_width : i32 = (xpBarWidth * player_exp) / exp_needed;
        DrawRectangle(xpBarX - 15, xpBarY - 5, xp_bar_width, xpBarHeight, PURPLE);     
        DrawRectangleLines(xpBarX - 15, xpBarY - 5, xpBarWidth, xpBarHeight, BLACK);
        
        exp_text := fmt.ctprintf("XP: %d/%d", player_exp, exp_needed);
        DrawText(exp_text, xpBarX - 18, xpBarY + 10, 18, BLACK);
        
        EndDrawing();
      }
}
