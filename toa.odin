package combat

import rl "vendor:raylib"
import "core:fmt"
import "core:mem"
import "core:slice"

// ==================== CONSTANTS =====================

SCREEN_WIDTH :: 1000;
SCREEN_HEIGHT :: 800;

// ==================== TYPES AND STRUCTS ======================

// Configuration and UI Structs
Options :: struct {
    name: cstring,
}

Menu :: struct {
    x, y: i32,
    width, height: i32,
    options: []Options,
    selected_index: i32,
    padding: i32,
    spacing: i32,
    visible: bool,
}

// Animation System
Animation_State :: enum {
    Idle,
    Attack,
    Hurt,
    Death,
}

Animation :: struct {
    texture: rl.Texture2D,
    num_frames: int,
    frame_timer: f32,
    current_frame: int,
    frame_length: f32,
    state: Animation_State,
}

// Combat System
Combat_State :: enum {
    PlayerTurn,         
    PlayerActionExecuting,  
    EnemyTurn,          
    EnemyActionExecuting,   
    BattleOver          
}

// Character System 
Character_Type :: enum {
    Player,
    Enemy,
}

// Sprite System
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

// Enemy System
Enemy :: struct {
    position: rl.Vector2,
    animation: ^Animation,
    health: int,
    damage: ^int,
    max_health: int,
    dead: bool,
    name: cstring,
}

// Player System
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

// Game State
Game_State :: struct {
    player: Player,
    enemies: []^Enemy,
    active_enemy_index: int,
    combat_state: Combat_State,
    combat_timer: f32,
    status_message: cstring,
    controls_visible: bool,
    item_inventory: [dynamic]Options,
    menu_system: struct {
        main: Menu,
        stats: Menu,
        items: Menu,
        settings: Menu,
    },
}

// ==================== INITIALIZATION FUNCTIONS =======================

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
    };
}

init_menu :: proc(x, y, width, height: i32, padding, spacing: i32, options: []Options) -> Menu {
    return Menu{
        x = x,
        y = y,
        width = width,
        height = height,
        options = options,
        selected_index = 0,
        padding = padding,
        spacing = spacing,
        visible = false,
    };
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

init_game_state :: proc() -> Game_State {
    // Initialize base menus
    menuX: i32 = 23;
    menuY: i32 = SCREEN_HEIGHT - 238;
    menuWidth: i32 = 175;
    menuHeight: i32 = 35;
    menuPadding: i32 = 20;
    spacing: i32 = 10;
    
    // Define menu options
    menuOptions := []Options{
        { name = "Attack"   }, 
        { name = "Defend"   },
        { name = "Stats"    },
        { name = "Items"    },
        { name = "Settings" },
    };
    
    statsOptions := []Options{
        { name = "Hp"  },
        { name = "Str" }, 
        { name = "Def" },
        { name = "Agi" },
        { name = "Dex" },
        { name = "Int" },
    };
    
    settingsOptions := []Options{
        { name = "Save" },
        { name = "Quit" },
    };
    
    // Create empty dynamic array for items
    itemOptions := make([dynamic]Options, 0, 10);
    add_item("Cloudy Vial", &itemOptions);
    
    // Initialize menus
    main_menu := init_menu(menuX, menuY, menuWidth, menuHeight, menuPadding, spacing, menuOptions);
    
    stats_menu := init_menu(
        menuX + menuWidth + menuPadding*2 + 6,
        menuY, 
        menuWidth, 
        menuHeight, 
        menuPadding, 
        spacing,
        statsOptions
    );
    
    items_menu := init_menu(
        menuX + menuWidth + menuPadding*2 + 6,
        menuY, 
        menuWidth, 
        menuHeight, 
        menuPadding, 
        spacing,
        make([]Options, len(itemOptions))
    );

    // Manually copy the items
    for i := 0; i < len(itemOptions); i += 1 {
        if i < len(items_menu.options) {
            items_menu.options[i] = itemOptions[i];
        }
    }
    
    settings_menu := init_menu(
        menuX + menuWidth + menuPadding*2 + 6,
        menuY, 
        menuWidth, 
        menuHeight, 
        menuPadding, 
        spacing,
        settingsOptions
    );
    
    return Game_State{
        player = init_player(),
        enemies = nil,  // Will be set after enemy initialization
        active_enemy_index = 0,
        combat_state = .PlayerTurn,
        combat_timer = 0,
        status_message = "Your turn! Choose an action.",
        controls_visible = false,
        item_inventory = itemOptions,
        menu_system = {
            main = main_menu,
            stats = stats_menu,
            items = items_menu,
            settings = settings_menu,
        },
    };
}

// ==================== ANIMATION SYSTEM =======================

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

draw_animation :: proc(a: Animation, pos: rl.Vector2, flip: bool) {
    using rl
    width := f32(a.texture.width) / f32(a.num_frames);
    height := f32(a.texture.height);
    source := Rectangle {
        x = f32(a.current_frame) * width,
        y = 0,
        width = flip ? -width : width,
        height = height,
    }
    dest := Rectangle {
        x = pos.x,
        y = pos.y,
        width = width * 4,
        height = height * 4,
    }
    DrawTexturePro(a.texture, source, dest, {dest.width / 2, dest.height / 2}, 0, WHITE);
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

// ==================== COMBAT SYSTEM =======================

damage_enemy :: proc(enemy: ^Enemy, amount: int, anims: ^SpriteAnimations) {
    if enemy.dead {
        return; // Don't process damage on a dead enemy
    }

    enemy.health -= amount
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
    animation_set := enemy.name == "Slime" ? slime_anims : plant_anims;

    enemy.animation = &animation_set.attack;
    enemy.animation.state = .Attack;
    enemy.animation.current_frame = 0;
    enemy.animation.frame_timer = 0;

    player.health -= amount^
    if player.health <= 0 {
        player.health = 0;
        player.dead = true;
        fmt.println("You died!");
    } else {
        fmt.printf("%s attacks! You take %d damage! %d health remaining\n", enemy.name, amount^, player.health);
    }
}

all_enemies_defeated :: proc(enemies: ..^Enemy) -> bool {
    for enemy in enemies {
        if !enemy.dead {
            return false;
        }
    }
    return true;
}

// ==================== ITEM SYSTEM =======================

use_item :: proc(item_name: cstring, target: ^Enemy, player: ^Player, slime_enemy: ^Enemy, slime_anims: ^SpriteAnimations, 
                plant_enemy: ^Enemy, plant_anims: ^SpriteAnimations) -> bool {
    if item_name == "Cloudy Vial" {
        // Healing potion
        if player.health < 100 {
            healing_amount := 30;
            player.health += healing_amount;
            if player.health > 100 {
                player.health = 100;
            }
            fmt.printf("Used %s! Healed for %d points. Health now: %d\n", 
                      item_name, healing_amount, player.health)
            return true;
        } else {
            fmt.println("Health is already full!")
            return false;
        }
    } else if item_name == "Vigor Vial" {
        // Strength boost
        strength_boost := 5;
        player.strength += strength_boost;
        fmt.printf("Used %s! Strength increased by %d points. Strength now: %d\n", 
                  item_name, strength_boost, player.strength)
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
                  item_name, damage_amount, target.name)
        return true;
    } else {
        fmt.printf("Unknown item: %s\n", item_name)
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

// ==================== UI SYSTEM =======================

draw_menu :: proc(menu: Menu, is_active: bool) {
    using rl;
    
    if !menu.visible {
        return;
    }
    
    box_width := menu.width + menu.padding * 2;
    total_menu_height := (menu.height + menu.spacing) * i32(len(menu.options)) - menu.spacing;
    box_height := total_menu_height + menu.padding * 2;
    
    // Draw menu background
    DrawRectangle(
        menu.x - menu.padding, 
        menu.y - menu.padding, 
        box_width, 
        box_height, 
        ColorAlpha(GRAY, 0.50)
    );

    DrawRectangleLines(
        menu.x - menu.padding, 
        menu.y - menu.padding, 
        box_width, 
        box_height, 
        BLACK
    );
    
    // Draw menu options
    for i: i32 = 0; i < i32(len(menu.options)); i += 1 {
        option_y := menu.y + (menu.height + menu.spacing) * i;
        
        if is_active && i == menu.selected_index {
            DrawRectangle(menu.x - 5, option_y - 3, menu.width, menu.height, BLUE);
            DrawRectangleLines(menu.x - 5, option_y - 3, menu.width, menu.height, BLACK);
            DrawText(menu.options[i].name, menu.x + 5, option_y + 5, 20, RAYWHITE);
        } else {
            DrawText(menu.options[i].name, menu.x + 5, option_y + 5, 20, BLACK);
        }
    }
}

draw_stats_menu :: proc(menu: Menu, player_stats: []int) {
    using rl;
    
    if !menu.visible {
        return;
    }
    
    box_width := menu.width + menu.padding * 2;
    total_menu_height := (menu.height + menu.spacing) * i32(len(menu.options)) - menu.spacing;
    box_height := total_menu_height + menu.padding * 2;
    
    // Draw menu background
    DrawRectangle(
        menu.x - menu.padding, 
        menu.y - menu.padding, 
        box_width, 
        box_height, 
        ColorAlpha(DARKGRAY, 0.50)
    );

    DrawRectangleLines(
        menu.x - menu.padding, 
        menu.y - menu.padding, 
        box_width, 
        box_height, 
        BLACK
    );
    
    // Draw stat entries
    for i: i32 = 0; i < i32(len(menu.options)); i += 1 {
        stat_y := menu.y + (menu.height + menu.spacing) * i;
        stats_num := fmt.ctprintf("%v", player_stats[i]);
        stats_wrd_num := fmt.ctprintf("%v : %v", menu.options[i].name, stats_num);
        DrawText(stats_wrd_num, menu.x + 5, stat_y + 6, 20, BLACK);
    }
}

draw_items_menu :: proc(menu: Menu, is_active: bool) {
    using rl;
    
    if !menu.visible {
        return;
    }
    
    box_width := menu.width + menu.padding * 2;
    total_menu_height := (menu.height + menu.spacing) * i32(len(menu.options)) - menu.spacing;
    box_height := total_menu_height + menu.padding * 2;
    
    // Draw menu background
    DrawRectangle(
        menu.x - menu.padding, 
        menu.y - menu.padding, 
        box_width, 
        box_height, 
        ColorAlpha(DARKGRAY, 0.50)
    );

    DrawRectangleLines(
        menu.x - menu.padding, 
        menu.y - menu.padding, 
        box_width, 
        box_height, 
        BLACK
    );
    
    // Draw item entries
    if len(menu.options) > 0 {
        for i: i32 = 0; i < i32(len(menu.options)); i += 1 {
            item_y := menu.y + (menu.height + menu.spacing) * i;
            
            if is_active && i == menu.selected_index {
                DrawRectangle(menu.x - 5, item_y - 3, menu.width, menu.height, BLUE);
                DrawRectangleLines(menu.x - 5, item_y - 3, menu.width, menu.height, BLACK);
                DrawText(menu.options[i].name, menu.x + 5, item_y + 5, 20, RAYWHITE);
            } else {
                DrawText(menu.options[i].name, menu.x + 5, item_y + 5, 20, BLACK);
            }
        }
    } else {
        DrawText("No items available", menu.x + 5, menu.y + 5, 20, BLACK);
    }
}

draw_health_bar :: proc(x, y, width, height: i32, current_health, max_health: int, show_text: bool) {
    using rl
    
    // Draw background (missing health)
    DrawRectangle(x, y, width, height, RED);
    
    // Calculate current health width
    current_width := width * i32(current_health) / i32(max_health);
    
    // Draw current health
    DrawRectangle(x, y, current_width, height, GREEN);
    
    // Draw border
    DrawRectangleLines(x, y, width, height, BLACK);
    
    // Draw text if needed
    if show_text {
        health_text := fmt.ctprintf("HP: %d/%d", current_health, max_health);
        DrawText(health_text, x + 4, y + (height - 18) / 2, 18, BLACK);
    }
}

draw_status_message :: proc(message: cstring) {
    using rl;
    
    // Draw status message box
    DrawRectangle(SCREEN_WIDTH/2 - 200, 20, 400, 40, ColorAlpha(GRAY, 0.65));
    DrawRectangleLines(SCREEN_WIDTH/2 - 200, 20, 400, 40, BLACK);
    DrawText(message, SCREEN_WIDTH/2 - 190, 30, 20, BLACK);
}

draw_controls_help :: proc(visible: bool) {
    using rl;
    
    if visible {
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
}

// ==================== GAME LOOP FUNCTIONS =======================

handle_player_turn :: proc(game: ^Game_State, slime_enemy, plant_enemy: ^Enemy, 
                          slime_anims, plant_anims: ^SpriteAnimations, player_stats: ^[]int) {
    using rl;
    
    // Main menu is visible and active during player turn
    game.menu_system.main.visible = true;
    
    // Handle sub-menu visibilities
    in_stats_menu := game.menu_system.stats.visible;
    in_item_menu := game.menu_system.items.visible  ;
    in_settings_menu := game.menu_system.settings.visible;
    
    if !in_stats_menu && !in_item_menu && !in_settings_menu {
        // Main menu navigation
        if IsKeyPressed(.W) {
            game.menu_system.main.selected_index -= 1;
            if game.menu_system.main.selected_index < 0 {
                game.menu_system.main.selected_index = i32(len(game.menu_system.main.options)) - 1;
            }
        }

        if IsKeyPressed(.S) {
            game.menu_system.main.selected_index += 1;
            if game.menu_system.main.selected_index >= i32(len(game.menu_system.main.options)) {
                game.menu_system.main.selected_index = 0;
            }
        }

        if IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D) {
            if game.menu_system.main.selected_index == 0 { // Attack
                fmt.println("Selected:", game.menu_system.main.options[game.menu_system.main.selected_index].name);
                
                // Get the active enemy
                active_enemy := game.enemies[game.active_enemy_index];
                
                if active_enemy == slime_enemy {
                    damage_enemy(active_enemy, game.player.strength, slime_anims);
                } else {
                    damage_enemy(active_enemy, game.player.strength, plant_anims);
                }
                
                game.status_message = "You attack!";
                game.combat_state = .PlayerActionExecuting;
            } else if game.menu_system.main.selected_index == 1 { // Defend
                fmt.println("Selected:", game.menu_system.main.options[game.menu_system.main.selected_index].name)
                game.status_message = "You take a defensive stance!";
                game.player.defense += 5;
                game.player.defending = true;
                game.combat_state = .EnemyTurn;
                game.combat_timer = 0;
            } else if game.menu_system.main.selected_index == 2 { // Stats
                fmt.println("Selected:", game.menu_system.main.options[game.menu_system.main.selected_index].name);
                game.menu_system.stats.visible = true;
            } else if game.menu_system.main.selected_index == 3 { // Items
                fmt.println("Selected:", game.menu_system.main.options[game.menu_system.main.selected_index].name);
                
                // Update items menu with current inventory contents
                game.menu_system.items.options = slice.clone(game.item_inventory[:])
                game.menu_system.items.visible = true;
            } else if game.menu_system.main.selected_index == 4 { // Settings
                fmt.println("Selected:", game.menu_system.main.options[game.menu_system.main.selected_index].name)
                game.menu_system.settings.visible = true;
            }
        }
    } else if in_stats_menu {
        // Stats menu navigation
        if IsKeyPressed(.W) {
            game.menu_system.stats.selected_index -= 1
            if game.menu_system.stats.selected_index < 0 {
                game.menu_system.stats.selected_index = i32(len(game.menu_system.stats.options)) - 1;
            }
        }

        if IsKeyPressed(.S) {
            game.menu_system.stats.selected_index += 1
            if game.menu_system.stats.selected_index >= i32(len(game.menu_system.stats.options)) {
                game.menu_system.stats.selected_index = 0;
            }
        }

        if IsKeyPressed(.A) || IsKeyPressed(.ESCAPE) {
            game.menu_system.stats.visible = false;
        }
    } else if in_item_menu {
        // Item menu navigation
        if IsKeyPressed(.W) {
            game.menu_system.items.selected_index -= 1;
            if game.menu_system.items.selected_index < 0 {
                game.menu_system.items.selected_index = i32(len(game.menu_system.items.options)) - 1;
            }
        }

        if IsKeyPressed(.S) {
            game.menu_system.items.selected_index += 1
            if game.menu_system.items.selected_index >= i32(len(game.menu_system.items.options)) {
                game.menu_system.items.selected_index = 0;
            }
        }

        if IsKeyPressed(.A) || IsKeyPressed(.ESCAPE) {
            game.menu_system.items.visible = false;
        }

        if (IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D)) && len(game.menu_system.items.options) > 0 {
            item_name := game.menu_system.items.options[game.menu_system.items.selected_index].name
            fmt.println("Used item:", item_name);
            
            active_enemy := game.enemies[game.active_enemy_index];
            
            if use_item(item_name, active_enemy, &game.player, slime_enemy, slime_anims, plant_enemy, plant_anims) {
                // If item was used successfully, remove it from inventory
                remove_item(int(game.menu_system.items.selected_index), &game.item_inventory);
                game.menu_system.items.visible = false;
                game.combat_state = .EnemyTurn;
                game.combat_timer = 0;
            }
        }
    } else if in_settings_menu {
        // Settings menu navigation
        if IsKeyPressed(.W) {
            game.menu_system.settings.selected_index -= 1;
            if game.menu_system.settings.selected_index < 0 {
                game.menu_system.settings.selected_index = i32(len(game.menu_system.settings.options)) - 1;
            }
        }

        if IsKeyPressed(.S) {
            game.menu_system.settings.selected_index += 1
            if game.menu_system.settings.selected_index >= i32(len(game.menu_system.settings.options)) {
                game.menu_system.settings.selected_index = 0;
            }
        }

        if IsKeyPressed(.A) || IsKeyPressed(.ESCAPE) {
            game.menu_system.settings.visible = false;
        }

        if IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D) {
            fmt.println("Used setting:", game.menu_system.settings.options[game.menu_system.settings.selected_index].name)
            if game.menu_system.settings.options[game.menu_system.settings.selected_index].name == "Save" {
                // Save game functionality
                save_game(game.player, slime_enemy^, plant_enemy^);
            } else if game.menu_system.settings.options[game.menu_system.settings.selected_index].name == "Quit" {
                CloseWindow();
            }
        }
    }
    
    // Handle enemy targeting with TAB during attack selection
    if game.menu_system.main.selected_index == 0 && 
       !in_stats_menu && !in_item_menu && !in_settings_menu && 
       IsKeyPressed(.TAB) {
        // Toggle active enemy
        game.active_enemy_index = (game.active_enemy_index + 1) % len(game.enemies);
        
        // Skip dead enemies
        for game.enemies[game.active_enemy_index].dead && len(game.enemies) > 1 {
            game.active_enemy_index = (game.active_enemy_index + 1) % len(game.enemies);
        }
    }
    
    // Update player stats for display
    update_player_stats(game.player, player_stats);
}

handle_player_action_executing :: proc(game: ^Game_State, slime_anim_completed, plant_anim_completed: bool) {
    active_enemy := game.enemies[game.active_enemy_index];
    anim_completed := false;
    
    if active_enemy.name == "Slime" {
        anim_completed = slime_anim_completed;
    } else {
        anim_completed = plant_anim_completed;
    }
    
    // Also add a timeout in case animation gets stuck
    if anim_completed || game.combat_timer > 1.0 {
        if active_enemy.dead {
            // Check if all enemies are defeated
            if all_enemies_defeated(game.enemies[0], game.enemies[1]) {
                game.status_message = "All enemies defeated!";
                game.combat_state = .BattleOver;
            } else {
                // Find next enemy
                next_enemy_index := (game.active_enemy_index + 1) % len(game.enemies);
                if game.enemies[next_enemy_index].dead {
                    // If the next enemy is also dead, find another one
                    for i := 0; i < len(game.enemies); i += 1 {
                        if !game.enemies[i].dead {
                            game.active_enemy_index = i;
                            break;
                        }
                    }
                } else {
                    game.active_enemy_index = next_enemy_index;
                }
                game.status_message = "Your turn! Choose an action.";
                game.combat_state = .PlayerTurn;
            }
        } else {
            game.status_message = "Enemy's turn...";
            game.combat_state = .EnemyTurn;
        }                       
        game.combat_timer = 0;
    } else {
        game.combat_timer += rl.GetFrameTime();
    }
}

handle_enemy_turn :: proc(game: ^Game_State, slime_enemy, plant_enemy: ^Enemy, slime_anims, plant_anims: ^SpriteAnimations) {
    // Reset any defending bonus from previous turn
    if game.player.defending {
        game.player.defense -= 5;
        game.player.defending = false;
    }
                                
    // Enemy selection logic
    active_enemy: ^Enemy;
                                
    // Find a living enemy to attack
    for i := 0; i < len(game.enemies); i += 1 {
        if !game.enemies[i].dead {
            active_enemy = game.enemies[i];
            break;
        }
    }
                                
    if active_enemy != nil {
        game.status_message = fmt.ctprintf("%s prepares to attack!", active_enemy.name)
        game.combat_state = .EnemyActionExecuting;
        game.combat_timer = 0;
                                        
        if active_enemy == slime_enemy {
            damage_player(active_enemy, &game.player, active_enemy.damage, slime_anims, plant_anims);
        } else {
            damage_player(active_enemy, &game.player, active_enemy.damage, slime_anims, plant_anims);
        }
    } else {
        // Should not happen, but as a failsafe
        game.combat_state = .PlayerTurn;
    }
}

handle_enemy_action_executing :: proc(game: ^Game_State, slime_anim_completed, plant_anim_completed: bool) {
    if (slime_anim_completed || plant_anim_completed) || game.combat_timer > 1.0 {
        if game.player.dead {
            game.status_message = "You have been defeated!";
            game.combat_state = .BattleOver;
        } else {
            game.status_message = "Your turn! Choose an action.";
            game.combat_state = .PlayerTurn;
        }
        game.combat_timer = 0;
    } else {
        game.combat_timer += rl.GetFrameTime();
    }
}

// ==================== UTILITY FUNCTIONS =======================

update_player_stats :: proc(player: Player, stats: ^[]int) {
    stats^[0] = player.health;
    stats^[1] = player.strength;
    stats^[2] = player.defense;
    stats^[3] = player.agility;
    stats^[4] = player.dexterity;
    stats^[5] = player.intelligence;
}

// ==================== SAVE/LOAD SYSTEM =======================

save_game :: proc(player: Player, slime: Enemy, plant: Enemy) {
    using rl
    
    // Create a save struct
    save_data := struct {
        player_health: int,
        player_strength: int,
        player_defense: int,
        player_level: int,
        player_xp: int,
        slime_health: int,
        plant_health: int,
    }{
        player_health = player.health,
        player_strength = player.strength,
        player_defense = player.defense,
        player_level = player.level,
        player_xp = player.current_xp,
        slime_health = slime.health,
        plant_health = plant.health,
    };
    
    // Convert save data to bytes
    save_bytes := make([]byte, size_of(save_data));
    mem.copy(&save_bytes[0], &save_data, size_of(save_data));
    
    // Save to file
    SaveFileData("save.dat", raw_data(save_bytes), i32(len(save_bytes)));
    fmt.println("Game saved!");
}

load_game :: proc(player: ^Player, slime, plant: ^Enemy) -> bool {
    using rl;
    
    save_data := struct {
        player_health: int,
        player_strength: int,
        player_defense: int,
        player_level: int,
        player_xp: int,
        slime_health: int,
        plant_health: int,
    }{};
    
    if FileExists("save.dat") {
        file_size: i32;
        data := LoadFileData("save.dat", &file_size);
        if file_size == size_of(save_data) {
            mem.copy(&save_data, data, size_of(save_data));
            UnloadFileData(data);
            
            // Apply saved data
            player.health = save_data.player_health;
            player.strength = save_data.player_strength;
            player.defense = save_data.player_defense;
            player.level = save_data.player_level;
            player.current_xp = save_data.player_xp;
            
            slime.health = save_data.slime_health;
            if slime.health <= 0 {
                slime.health = 0;
                slime.dead = true;
            }
            
            plant.health = save_data.plant_health;
            if plant.health <= 0 {
                plant.health = 0;
                plant.dead = true;
            }
            
            fmt.println("Game loaded!");
            return true;
        }
        UnloadFileData(data);
    }
    
    fmt.println("No save file found or save file corrupt.");
    return false;
}

// ==================== MAIN FUNCTION =======================

main :: proc() {
    using rl;
    
    // Initialize window
    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Turn-Based Combat Game");
    SetTargetFPS(60);
    
    // Initialize game state
    game_state := init_game_state();

    if !FileExists("assets/Slime_Idle.png") || !FileExists("assets/Slime_Attack.png") || !FileExists("assets/Slime_Hurt.png") || !FileExists("assets/Slime_Death.png") || !FileExists("assets/Plant_Idle.png") || !FileExists("assets/Plant_Attack.png") || !FileExists("assets/Plant_Hurt.png") || !FileExists("assets/Plant_Death.png") || !FileExists("assets/Levels/LevelNormal.png") {
        fmt.println("ERROR: One or more asset files are missing. Please check the assets directory.");
        CloseWindow();
        return;
    }
    
    // Load sprite sheets
    slime_idle_texture := LoadTexture("assets/Slime_Idle.png");
    slime_attack_texture := LoadTexture("assets/Slime_Attack.png");
    slime_hurt_texture := LoadTexture("assets/Slime_Hurt.png");
    slime_death_texture := LoadTexture("assets/Slime_Death.png");
    
    plant_idle_texture := LoadTexture("assets/Plant_Idle.png");
    plant_attack_texture := LoadTexture("assets/Plant_Attack.png");
    plant_hurt_texture := LoadTexture("assets/Plant_Hurt.png");
    plant_death_texture := LoadTexture("assets/Plant_Death.png");

    bg_texture := LoadTexture("assets/Levels/LevelNormal.png");

    if slime_idle_texture.id == 0 || slime_attack_texture.id == 0 || slime_hurt_texture.id == 0 || slime_death_texture.id == 0 || plant_idle_texture.id == 0 || plant_attack_texture.id == 0 || plant_hurt_texture.id == 0 || plant_death_texture.id == 0 || bg_texture.id == 0 {
        fmt.println("ERROR: Failed to load one or more textures. Make sure all asset files exist.");
        CloseWindow();
        return;
    }
    
    // Check textures loaded correctly
    slime_textures := SpriteTextures{
        idle = slime_idle_texture,
        attack = slime_attack_texture,
        hurt = slime_hurt_texture,
        death = slime_death_texture,
    };
    
    plant_textures := SpriteTextures{
        idle = plant_idle_texture,
        attack = plant_attack_texture,
        hurt = plant_hurt_texture,
        death = plant_death_texture,
    };
    
    if !check_sprite_textures(slime_textures) || !check_sprite_textures(plant_textures) {
        fmt.println("Failed to load sprite textures!");
        CloseWindow();
        return;
    }
    
    // Create animations
    slime_idle_anim := load_animation(slime_idle_texture, 6, 0.15, .Idle);
    slime_attack_anim := load_animation(slime_attack_texture, 7, 0.12, .Attack);
    slime_hurt_anim := load_animation(slime_hurt_texture, 3, 0.15, .Hurt);
    slime_death_anim := load_animation(slime_death_texture, 7, 0.15, .Death);
    
    plant_idle_anim := load_animation(plant_idle_texture, 4, 0.2, .Idle);
    plant_attack_anim := load_animation(plant_attack_texture, 8, 0.12, .Attack);
    plant_hurt_anim := load_animation(plant_hurt_texture, 3, 0.15, .Hurt);
    plant_death_anim := load_animation(plant_death_texture, 10, 0.15, .Death);

    fmt.println("Slime idle animation ID:", slime_idle_anim.texture.id);
    fmt.println("Plant idle animation ID:", plant_idle_anim.texture.id);
    
    // Group animations
    slime_animations := SpriteAnimations{
        idle = slime_idle_anim,
        attack = slime_attack_anim,
        hurt = slime_hurt_anim,
        death = slime_death_anim,
    };
    
    plant_animations := SpriteAnimations{
        idle = plant_idle_anim,
        attack = plant_attack_anim,
        hurt = plant_hurt_anim,
        death = plant_death_anim,
    };
    
    // Create enemies
    slime_enemy := spawn_enemy({300, 400}, &slime_idle_anim, "Slime");
    plant_enemy := spawn_enemy({600, 400}, &plant_idle_anim, "Plant");
    
    // Add enemies to game state
    game_state.enemies = make([]^Enemy, 2);
    game_state.enemies[0] = &slime_enemy;
    game_state.enemies[1] = &plant_enemy;
    
    // Player stats array for display
    player_stats := make([]int, 6);
    defer delete(player_stats);
    update_player_stats(game_state.player, &player_stats);
    
    // Game loop
    for !WindowShouldClose() {
        // Update animations
        slime_anim_completed := update_enemy_animation(&slime_enemy, &slime_animations);
        plant_anim_completed := update_enemy_animation(&plant_enemy, &plant_animations);
        
        // Toggle controls help
        if IsKeyPressed(.H) {
            game_state.controls_visible = !game_state.controls_visible;
        }
        
        // Debug keys
        if IsKeyPressed(.ONE) {
            add_item("Vigor Vial", &game_state.item_inventory);
        }
        if IsKeyPressed(.TWO) {
            add_item("Bomb", &game_state.item_inventory);
        }
        
        // Handle combat state
        switch game_state.combat_state {
            case .PlayerTurn:
                handle_player_turn(&game_state, &slime_enemy, &plant_enemy, 
                                  &slime_animations, &plant_animations, &player_stats);
            
            case .PlayerActionExecuting:
                handle_player_action_executing(&game_state, slime_anim_completed, plant_anim_completed);
                
            case .EnemyTurn:
                handle_enemy_turn(&game_state, &slime_enemy, &plant_enemy, 
                                 &slime_animations, &plant_animations);
                
            case .EnemyActionExecuting:
                handle_enemy_action_executing(&game_state, slime_anim_completed, plant_anim_completed);
                
            case .BattleOver:
                // Just waiting for user to quit or restart
                game_state.menu_system.main.visible = false;
                if IsKeyPressed(.R) {
                    // Reinitialize the game state
                    game_state = init_game_state();
                    
                    // Reset enemies
                    slime_enemy = spawn_enemy({300, 400}, &slime_idle_anim, "Slime");
                    plant_enemy = spawn_enemy({600, 400}, &plant_idle_anim, "Plant");
                    
                    // Update game state with new enemies
                    enemies := [2]^Enemy{&slime_enemy, &plant_enemy};
                    game_state.enemies = enemies[:];
                    
                    // Update player stats display
                    update_player_stats(game_state.player, &player_stats);
                }
        }
        
        // Drawing
        BeginDrawing();
        ClearBackground(RAYWHITE);
        
        // Draw background
        DrawTexture(bg_texture, 0, 0, WHITE);
        
        // Draw enemies
        if !slime_enemy.dead {
            draw_animation(slime_enemy.animation^, slime_enemy.position, false)
            draw_health_bar(
                i32(slime_enemy.position.x - 50),
                i32(slime_enemy.position.y - 100),
                100, 
                15,
                slime_enemy.health,
                slime_enemy.max_health,
                false
            );

            DrawText(
                slime_enemy.name,
                i32(slime_enemy.position.x - 30),
                i32(slime_enemy.position.y - 120),
                20,
                BLACK
            );
            
            // Draw targeting arrow
            if game_state.active_enemy_index == 0 && game_state.combat_state == .PlayerTurn {
                DrawTriangle(
                    {slime_enemy.position.x, slime_enemy.position.y - 150},
                    {slime_enemy.position.x - 10, slime_enemy.position.y - 130},
                    {slime_enemy.position.x + 10, slime_enemy.position.y - 130},
                    RED
                );
            }
        }
        
        if !plant_enemy.dead {
            draw_animation(plant_enemy.animation^, plant_enemy.position, false);

            draw_health_bar(
                i32(plant_enemy.position.x - 50),
                i32(plant_enemy.position.y - 100),
                100, 
                15,
                plant_enemy.health,
                plant_enemy.max_health,
                false
            );

            DrawText(
                plant_enemy.name,
                i32(plant_enemy.position.x - 30),
                i32(plant_enemy.position.y - 120),
                20,
                BLACK
            );
            
            // Draw targeting arrow
            if game_state.active_enemy_index == 1 && game_state.combat_state == .PlayerTurn {
                DrawTriangle(
                    {plant_enemy.position.x, plant_enemy.position.y - 150},
                    {plant_enemy.position.x - 10, plant_enemy.position.y - 130},
                    {plant_enemy.position.x + 10, plant_enemy.position.y - 130},
                    RED
                );
            }
        }
        
        // Draw player UI
        draw_health_bar(20, SCREEN_HEIGHT - 80, 200, 30, game_state.player.health, 100, true);
        
        // Draw combat menu
        draw_menu(game_state.menu_system.main, 
                 game_state.combat_state == .PlayerTurn && 
                 !game_state.menu_system.stats.visible && 
                 !game_state.menu_system.items.visible &&
                 !game_state.menu_system.settings.visible);
        
        // Draw stats menu if visible
        draw_stats_menu(game_state.menu_system.stats, player_stats);
        
        // Draw items menu if visible
        draw_items_menu(game_state.menu_system.items, 
                       game_state.combat_state == .PlayerTurn && 
                       game_state.menu_system.items.visible);
        
        // Draw settings menu if visible
        draw_menu(game_state.menu_system.settings, 
                 game_state.combat_state == .PlayerTurn && 
                 game_state.menu_system.settings.visible);
        
        // Draw status message
        draw_status_message(game_state.status_message);
        
        // Draw controls help
        draw_controls_help(game_state.controls_visible);
                                    
        // Game over message
        if game_state.combat_state == .BattleOver {
            message: cstring;
                                        
            if game_state.player.dead {
                message = "Game Over! Press R to restart."
            } else {
                message = "Victory! Press R to restart."
            }
                                    
            DrawRectangle(
                SCREEN_WIDTH/2 - 200,
                SCREEN_HEIGHT/2 - 25,
                400,
                50,
                ColorAlpha(DARKGRAY, 0.8)
            );
            
            DrawRectangleLines(
                SCREEN_WIDTH/2 - 200,
                SCREEN_HEIGHT/2 - 25,
                400,
                50,
                BLACK
            );
            
            DrawText(
                message,
                SCREEN_WIDTH/2 - 190,
                SCREEN_HEIGHT/2 - 15,
                24,
                WHITE
            );
        }
                                    
        EndDrawing();
    }
                                
    // Unload textures
    UnloadTexture(slime_idle_texture);
    UnloadTexture(slime_attack_texture);
    UnloadTexture(slime_hurt_texture);
    UnloadTexture(slime_death_texture);
                                
    UnloadTexture(plant_idle_texture);
    UnloadTexture(plant_attack_texture);
    UnloadTexture(plant_hurt_texture);
    UnloadTexture(plant_death_texture);
                                
    UnloadTexture(bg_texture);
                                
    // Cleanup
    delete(player_stats);
                                
    // Close window
    CloseWindow();
}
