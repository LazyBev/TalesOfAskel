module combat;

import std.stdio;
import std.string;
import std.format;
import std.math;
import std.algorithm;
import std.random;
import raylib;

const int screenWidth = 1000;
const int screenHeight = 800;

Color GetColor(uint hex) {
    Color color;
    color.r = (hex >> 24) & 0xFF;
    color.g = (hex >> 16) & 0xFF;
    color.b = (hex >> 8) & 0xFF;
    color.a = hex & 0xFF;
    return color;
}

enum : uint {
    BLACK    = 0x000000FF,  // Black: #000000FF
    WHITE    = 0xFFFFFFFF,  // White: #FFFFFFFF
    GRAY     = 0x808080FF,  // Gray: #808080FF
    RED      = 0xFF0000FF,  // Red: #FF0000FF
    RAYWHITE = 0xF5F5F5FF   // RayWhite: #F5F5F5FF
}

struct Options {
    string name;
}

enum Animation_State {
    Idle,
    Attack,
    Hurt,
    Death
}

enum Combat_State {
    PlayerTurn,
    PlayerActionExecuting,
    EnemyTurn,
    EnemyActionExecuting,
    BattleOver
}

struct Animation {
    Texture2D texture;
    int num_frames;
    float frame_timer;
    int current_frame;
    float frame_length;
    Animation_State state;
}

struct SpriteTextures {
    Texture2D idle;
    Texture2D attack;
    Texture2D hurt;
    Texture2D death;
}

struct SpriteAnimations {
    Animation idle;
    Animation attack;
    Animation hurt;
    Animation death;
}

void update_animation(ref Animation a) {
    a.frame_timer += GetFrameTime();
    if (a.frame_timer >= a.frame_length) {
        a.frame_timer -= a.frame_length;
        a.current_frame += 1;
        if (a.current_frame >= a.num_frames) {
            a.current_frame = 0;
        }
    }
}

struct Enemy {
    Vector2 position;
    Animation* animation;
    int health;
    int* damage;
    int max_health;
    bool dead;
    string name;
}

struct Player {
    int health;
    int strength;
    int defense;
    int agility;
    int dexterity;
    int intelligence;
    bool dead;
    int level;
    int current_xp;
    int max_xp;
    bool defending;
}

Player init_player() {
    return Player(
        100,    // health
        10,     // strength
        5,      // defense
        3,      // agility
        5,      // dexterity
        1,      // intelligence
        false,  // dead
        1,      // level
        0,      // current_xp
        100,    // max_xp
        false   // defending
    );
}

Enemy spawn_enemy(Vector2 pos, Animation* anim, string enemy_name) {
    int damage_value = 5;
    return Enemy(
        pos,
        anim,
        100,
        &damage_value,
        100,
        false,
        enemy_name
    );
}

void draw_animation(Animation a, Vector2 pos, bool flip) {
    float width = cast(float)a.texture.width / cast(float)a.num_frames;
    float height = cast(float)a.texture.height;
    Rectangle source = Rectangle(
        cast(float)a.current_frame * width,
        0,
        flip ? -width : width,
        height
    );
    Rectangle dest = Rectangle(
        pos.x,
        pos.y,
        width * 4,
        height * 4
    );
    DrawTexturePro(a.texture, source, dest, Vector2(dest.width / 2, dest.height / 2), 0, WHITE);
}

Animation load_animation(Texture2D tex, int frames, float frame_time, Animation_State state) {
    if (tex.id == 0) {
        writeln("ERROR: Texture is not loaded properly!");
    }
    return Animation(
        tex,
        frames,
        0,
        0,
        frame_time,
        state
    );
}

// Improved error checking for texture loading
bool check_sprite_textures(SpriteTextures textures) {
    if (textures.idle.id == 0 ||
        textures.attack.id == 0 ||
        textures.hurt.id == 0 ||
        textures.death.id == 0) {
        writeln("ERROR: One or more enemy sprite textures failed to load!");
        return false;
    }
    return true;
}

bool update_enemy_animation(ref Enemy enemy, ref SpriteAnimations anims) {
    bool animation_completed = false;
    
    if (enemy.dead) {
        return false;
    }

    update_animation(*enemy.animation);

    // Check if attack animation completed
    if (enemy.animation.state == Animation_State.Attack) {
        if (enemy.animation.current_frame == enemy.animation.num_frames - 1) {
            enemy.animation = &anims.idle;
            enemy.animation.state = Animation_State.Idle;
            enemy.animation.current_frame = 0;
            enemy.animation.frame_timer = 0;
            animation_completed = true;
        }
    }

    // Handle Death Animation Completion
    if (enemy.animation.state == Animation_State.Death) {
        if (enemy.animation.current_frame == enemy.animation.num_frames - 1) {
            enemy.animation.current_frame = enemy.animation.num_frames - 1;
            enemy.dead = true;
            animation_completed = true;
        }
        return animation_completed;
    }

    // Handle Hurt Animation Completion
    if (enemy.animation.state == Animation_State.Hurt) {
        if (enemy.animation.current_frame == enemy.animation.num_frames - 1) {
            enemy.animation = &anims.idle;
            enemy.animation.state = Animation_State.Idle;
            enemy.animation.current_frame = 0;
            enemy.animation.frame_timer = 0;
            animation_completed = true;
        }
    }
    
    return animation_completed;
}

void damage_enemy(ref Enemy enemy, int amount, ref SpriteAnimations anims) {
    if (enemy.dead) {
        return; // Don't process damage on a dead enemy
    }

    enemy.health -= amount;
    if (enemy.health <= 0) {
        enemy.health = 0;
        enemy.animation = &anims.death; // Switch to death animation
        enemy.animation.state = Animation_State.Death;
        writefln("%s was defeated!", enemy.name);
    } else {
        enemy.animation = &anims.hurt; // Switch to hurt animation
        enemy.animation.state = Animation_State.Hurt;
        writefln("%s took %d damage! %d HP remaining.", enemy.name, amount, enemy.health);
    }
    enemy.animation.current_frame = 0;
    enemy.animation.frame_timer = 0;
}

void damage_player(ref Enemy enemy, ref Player player, int* amount, ref SpriteAnimations slime_anims, ref SpriteAnimations plant_anims) {
    if (player.dead) {
        return;
    }
    
    // Choose correct animation set based on enemy
    auto animation_set = enemy.name == "Slime" ? slime_anims : plant_anims;

    enemy.animation = &animation_set.attack;
    enemy.animation.state = Animation_State.Attack;
    enemy.animation.current_frame = 0;
    enemy.animation.frame_timer = 0;

    player.health -= *amount;
    if (player.health <= 0) {
        player.health = 0;
        player.dead = true;
        writeln("You died!");
    } else {
        writefln("%s attacks! You take %d damage! %d health remaining", enemy.name, *amount, player.health);
    }
}

// Utility functions added/improved
bool use_item(string item_name, ref Enemy target, ref Player player, ref Enemy slime_enemy, ref SpriteAnimations slime_anims, ref Enemy plant_enemy, ref SpriteAnimations plant_anims) {
    if (item_name == "Cloudy Vial") {
        // Healing potion
        if (player.health < 100) {
            int healing_amount = 30;
            player.health += healing_amount;
            if (player.health > 100) {
                player.health = 100;
            }
            writefln("Used %s! Healed for %d points. Health now: %d", 
                    item_name, healing_amount, player.health);
            return true;
        } else {
            writeln("Health is already full!");
            return false;
        }
    } else if (item_name == "Vigor Vial") {
        // Strength boost
        int strength_boost = 5;
        player.strength += strength_boost;
        writefln("Used %s! Strength increased by %d points. Strength now: %d", 
                item_name, strength_boost, player.strength);
        return true;
    } else if (item_name == "Bomb") {
        // Damage item
        int damage_amount = 25;
        
        if (&target == &slime_enemy) {
            damage_enemy(target, damage_amount, slime_anims);
        } else {
            damage_enemy(target, damage_amount, plant_anims);
        }
        
        writefln("Used %s! Dealt %d damage to %s", 
                item_name, damage_amount, target.name);
        return true;
    } else {
        writefln("Unknown item: %s", item_name);
        return false;
    }
}

void add_item(string item_name, ref Options[] item_options) {
    Options new_item = Options(item_name);
    item_options ~= new_item;
}

void remove_item(int index, ref Options[] item_options) {
    if (index >= 0 && index < item_options.length) {
        item_options = item_options[0..index] ~ item_options[index+1..$];
    }
}

void update_player_stats(Player player, ref int[] stats) {
    stats[0] = player.health;
    stats[1] = player.strength;
    stats[2] = player.defense;
    stats[3] = player.agility;
    stats[4] = player.dexterity;
    stats[5] = player.intelligence;
}

bool all_enemies_defeated(Enemy[] enemies...) {
    foreach (enemy; enemies) {
        if (!enemy.dead) {
            return false;
        }
    }
    return true;
}

bool save_game(Player player, Enemy slime_enemy, Enemy plant_enemy) {
    // Placeholder for save game functionality
    writeln("Game saved successfully!");
    return true;
}

void main() {
    InitWindow(screenWidth, screenHeight, "Tales Of Askel");
    scope(exit) CloseWindow();
    SetTargetFPS(60);
    SetExitKey(KeyboardKey.KEY_Q);

    // Main menu options
    Options[] menuOptions = [
        Options("Attack"),
        Options("Defend"),
        Options("Stats"),
        Options("Items"),
        Options("Settings")
    ];

    // Stats menu options
    Options[] statsOptions = [
        Options("Hp"),
        Options("Str"),
        Options("Def"),
        Options("Agi"),
        Options("Dex"),
        Options("Int")
    ];
    
    Player mchar = init_player();
    int[] player_stats = [mchar.health, mchar.strength, mchar.defense, mchar.agility, mchar.dexterity, mchar.intelligence];
    
    // Available items in game
    Options[] itemsDict = [
        Options("Cloudy Vial"),
        Options("Vigor Vial"),
        Options("Bomb")
    ];

    // Item menu options
    Options[] itemOptions = [];
    add_item("Cloudy Vial", itemOptions);

    // Settings menu options
    Options[] settingsOptions = [
        Options("Save"),
        Options("Quit")
    ];

    Texture2D Level1 = LoadTexture("assets/Levels/LevelNormal.png");
    scope(exit) UnloadTexture(Level1);

    if (Level1.width == 0 || Level1.height == 0) {
        writeln("ERROR: Failed to load Level1 texture!");
    } else {
        writefln("Loaded Level1 texture: %dx%d", Level1.width, Level1.height);
    }

    // Main menu
    int menuSelectedIndex = 0;
    int menuX = 23;
    int menuY = screenHeight - 238;
    int menuWidth = 175;
    int menuHeight = 35;
    int spacing = 10;
    int menuPadding = 20;
    int totalMenuHeight = (menuHeight + spacing) * cast(int)menuOptions.length - spacing;
    int menuBoxHeight = totalMenuHeight + menuPadding * 2;
    int menuBoxWidth = menuWidth + menuPadding * 2;

    // Stats menu 
    int statsSelectedIndex = 0;
    bool inStatsMenu = false;
    int statsMenuX = menuX + menuBoxWidth + 6;
    int statsMenuY = menuY;
    int statsMenuWidth = 175;
    int statsMenuHeight = 35;
    int statsMenuBoxWidth = statsMenuWidth + menuPadding * 2;
    int statsTotalHeight = (statsMenuHeight + spacing) * cast(int)statsOptions.length - spacing;
    int statsMenuBoxHeight = statsTotalHeight + menuPadding * 2;

    // Item menu
    int itemSelectedIndex = 0;
    bool inItemMenu = false;
    int itemMenuX = menuX + menuBoxWidth + 6;
    int itemMenuY = menuY;
    int itemMenuWidth = 175;
    int itemMenuHeight = 35;
    int itemMenuBoxWidth = itemMenuWidth + menuPadding * 2;
    int itemTotalHeight = (itemMenuHeight + spacing) * cast(int)itemOptions.length - spacing;
    int itemMenuBoxHeight = itemTotalHeight + menuPadding * 2;
    
    // Settings menu
    int settingsSelectedIndex = 0;
    bool inSettingsMenu = false;
    int settingsMenuX = menuX + menuBoxWidth + 6;
    int settingsMenuY = menuY;
    int settingsMenuWidth = 175;
    int settingsMenuHeight = 35;
    int settingsMenuBoxWidth = settingsMenuWidth + menuPadding * 2;
    int settingsTotalHeight = (settingsMenuHeight + spacing) * cast(int)settingsOptions.length - spacing;
    int settingsMenuBoxHeight = settingsTotalHeight + menuPadding * 2;

    // Xp bar
    int xpBarX = menuX;
    int xpBarY = menuY - 50;
    int xpBarWidth = 180;
    int xpBarHeight = 10;

    // Enemies
    SpriteTextures slime_textures = SpriteTextures(
        LoadTexture("assets/Slime_Idle.png"),
        LoadTexture("assets/Slime_Attack.png"),
        LoadTexture("assets/Slime_Hurt.png"),
        LoadTexture("assets/Slime_Death.png")
    );

    if (!check_sprite_textures(slime_textures)) {
        writeln("Failed to load slime textures. Exiting...");
        CloseWindow();
        return;
    }

    SpriteAnimations slime_animations = SpriteAnimations(
        load_animation(slime_textures.idle, 6, 0.2, Animation_State.Idle),
        load_animation(slime_textures.attack, 10, 0.1, Animation_State.Attack),
        load_animation(slime_textures.hurt, 5, 0.1, Animation_State.Hurt),
        load_animation(slime_textures.death, 10, 0.15, Animation_State.Death)
    );

    SpriteTextures plant_textures = SpriteTextures(
        LoadTexture("assets/Plant_Idle.png"),
        LoadTexture("assets/Plant_Attack.png"),
        LoadTexture("assets/Plant_Hurt.png"),
        LoadTexture("assets/Plant_Death.png")
    );

    if (!check_sprite_textures(plant_textures)) {
        writeln("Failed to load plant textures. Exiting...");
        CloseWindow();
        return;
    }

    SpriteAnimations plant_animations = SpriteAnimations(
        load_animation(plant_textures.idle, 4, 0.2, Animation_State.Idle),
        load_animation(plant_textures.attack, 7, 0.1, Animation_State.Attack),
        load_animation(plant_textures.hurt, 5, 0.1, Animation_State.Hurt),
        load_animation(plant_textures.death, 10, 0.15, Animation_State.Death)
    );

    scope(exit) {
        UnloadTexture(slime_textures.idle);
        UnloadTexture(slime_textures.attack);
        UnloadTexture(slime_textures.hurt);
        UnloadTexture(slime_textures.death);
        UnloadTexture(plant_textures.idle);
        UnloadTexture(plant_textures.attack);
        UnloadTexture(plant_textures.hurt);
        UnloadTexture(plant_textures.death);
    }

    Animation* current_slime_anim = &slime_animations.idle;
    Vector2 slime_pos = Vector2(cast(float)GetScreenWidth() / 2 - 50, cast(float)GetScreenHeight() / 2);
    Enemy slime_enemy = spawn_enemy(slime_pos, current_slime_anim, "Slime");
    
    Animation* current_plant_anim = &plant_animations.idle;
    Vector2 plant_pos = Vector2(cast(float)GetScreenWidth() / 2 + 100, cast(float)GetScreenHeight() / 2);
    Enemy plant_enemy = spawn_enemy(plant_pos, current_plant_anim, "Plant");

    bool controlsVisible = false;
    
    // Initialize combat state to player's turn
    Combat_State combat_state = Combat_State.PlayerTurn;
    
    // Create an active enemy reference for easier targeting
    Enemy* active_enemy = &slime_enemy;
    
    // Status message for UI feedback
    string status_message = "Your turn! Choose an action.";
    
    // Combat timer for pacing animations and actions
    float combat_timer = 0;
    float enemy_turn_delay = 0.1; // Seconds to wait before enemy attacks

    // Main game loop
    while (!WindowShouldClose()) {
        float dt = GetFrameTime();
        combat_timer += dt;
        
        // Update animations for both enemies
        bool slime_animation_completed = update_enemy_animation(slime_enemy, slime_animations);
        bool plant_animation_completed = update_enemy_animation(plant_enemy, plant_animations);
        
        // Combat state machine
        switch (combat_state) {
        case Combat_State.PlayerTurn:
            // Allow menu navigation during player's turn
            if (!inItemMenu && !inSettingsMenu && !inStatsMenu) {
                if (IsKeyPressed(KeyboardKey.KEY_W)) {
                    menuSelectedIndex -= 1;
                    if (menuSelectedIndex < 0) {
                        menuSelectedIndex = cast(int)menuOptions.length - 1;
                    }
                }

                if (IsKeyPressed(KeyboardKey.KEY_S)) {
                    menuSelectedIndex += 1;
                    if (menuSelectedIndex >= cast(int)menuOptions.length) {
                        menuSelectedIndex = 0;
                    }
                }

                if (IsKeyPressed(KeyboardKey.KEY_ENTER) || IsKeyPressed(KeyboardKey.KEY_SPACE) || IsKeyPressed(KeyboardKey.KEY_D)) {
                    if (menuSelectedIndex == 0) { // Attack
                        writefln("Selected: %s", menuOptions[menuSelectedIndex].name);
                        damage_enemy(*active_enemy, mchar.strength, slime_animations);
                        status_message = "You attack!";
                        combat_state = Combat_State.PlayerActionExecuting;
                    } else if (menuSelectedIndex == 1) { // Defend
                        writefln("Selected: %s", menuOptions[menuSelectedIndex].name);
                        status_message = "You take a defensive stance!";
                        mchar.defense += 5;
                        mchar.defending = true;
                        combat_state = Combat_State.EnemyTurn;
                        combat_timer = 0;
                    } else if (menuSelectedIndex == 2) { // Stats
                        writefln("Selected: %s", menuOptions[menuSelectedIndex].name);
                        inStatsMenu = true;
                    } else if (menuSelectedIndex == 3) { // Items
                        writefln("Selected: %s", menuOptions[menuSelectedIndex].name);
                        inItemMenu = true;
                    } else if (menuSelectedIndex == 4) { // Settings
                        writefln("Selected: %s", menuOptions[menuSelectedIndex].name);
                        inSettingsMenu = true;
                    }
                }
            } else if (inStatsMenu) {
                // Stats menu controls
                if (IsKeyPressed(KeyboardKey.KEY_W)) {
                    statsSelectedIndex -= 1;
                    if (statsSelectedIndex < 0) {
                        statsSelectedIndex = cast(int)statsOptions.length - 1;
                    }
                }

                if (IsKeyPressed(KeyboardKey.KEY_S)) {
                    statsSelectedIndex += 1;
                    if (statsSelectedIndex >= cast(int)statsOptions.length) {
                        statsSelectedIndex = 0;
                    }
                }

                if (IsKeyPressed(KeyboardKey.KEY_A) || IsKeyPressed(KeyboardKey.KEY_ESCAPE)) {
                    inStatsMenu = false;
                }
            } else if (inItemMenu) {
                // Item menu controls
                if (IsKeyPressed(KeyboardKey.KEY_W)) {
                    itemSelectedIndex -= 1;
                    if (itemSelectedIndex < 0) {
                        itemSelectedIndex = cast(int)itemOptions.length - 1;
                    }
                }

                if (IsKeyPressed(KeyboardKey.KEY_S)) {
                    itemSelectedIndex += 1;
                    if (itemSelectedIndex >= cast(int)itemOptions.length) {
                        itemSelectedIndex = 0;
                    }
                }

                if (IsKeyPressed(KeyboardKey.KEY_A) || IsKeyPressed(KeyboardKey.KEY_ESCAPE)) {
                    inItemMenu = false;
                }

                if ((IsKeyPressed(KeyboardKey.KEY_ENTER) || IsKeyPressed(KeyboardKey.KEY_SPACE) || IsKeyPressed(KeyboardKey.KEY_D)) && itemOptions.length > 0) {
                    string item_name = itemOptions[itemSelectedIndex].name;
                    writefln("Used item: %s", item_name);
    
                    if (use_item(item_name, *active_enemy, mchar, slime_enemy, slime_animations, plant_enemy, plant_animations)) {
                        // If item was used successfully, remove it from inventory
                        remove_item(cast(int)itemSelectedIndex, itemOptions);
                        inItemMenu = false;
                        combat_state = Combat_State.EnemyTurn;
                        combat_timer = 0;
                    }
                }
            } else if (inSettingsMenu) {
                // Settings menu controls
                if (IsKeyPressed(KeyboardKey.KEY_W)) {
                    settingsSelectedIndex -= 1;
                    if (settingsSelectedIndex < 0) {
                        settingsSelectedIndex = cast(int)settingsOptions.length - 1;
                    }
                }

                if (IsKeyPressed(KeyboardKey.KEY_S)) {
                    settingsSelectedIndex += 1;
                    if (settingsSelectedIndex >= cast(int)settingsOptions.length) {
                        settingsSelectedIndex = 0;
                    }
                }

                if (IsKeyPressed(KeyboardKey.KEY_A) || IsKeyPressed(KeyboardKey.KEY_ESCAPE)) {
                    inSettingsMenu = false;
                }

                if (IsKeyPressed(KeyboardKey.KEY_ENTER) || IsKeyPressed(KeyboardKey.KEY_SPACE) || IsKeyPressed(KeyboardKey.KEY_D)) {
                    writefln("Used setting: %s", settingsOptions[settingsSelectedIndex].name);
                    if (settingsOptions[settingsSelectedIndex].name == "Quit") {
                        CloseWindow();
                    }
                }
            }
            break;
            
        case Combat_State.PlayerActionExecuting:
            // Check if animation has completed or enough time has passed
            bool anim_completed = false;
            
            if (active_enemy == &slime_enemy) {
                anim_completed = slime_animation_completed;
            } else if (active_enemy == &plant_enemy) {
                anim_completed = plant_animation_completed;
            }
            
            // Also add a timeout in case animation gets stuck
            if (anim_completed || combat_timer > 1.0) {
                if (active_enemy.dead) {
                    // Check if all enemies are defeated
                    if (all_enemies_defeated(slime_enemy, plant_enemy)) {
                        status_message = "All enemies defeated!";
                        combat_state = Combat_State.BattleOver;
                    } else {
                        // Find next enemy
                        if (active_enemy == &slime_enemy && !plant_enemy.dead) {
                            active_enemy = &plant_enemy;
                        } else if (active_enemy == &plant_enemy && !slime_enemy.dead) {
                            active_enemy = &slime_enemy;
                        }
                        status_message = "Enemy's turn...";
                        combat_state = Combat_State.EnemyTurn;
                        combat_timer = 0;
                    }
                } else {
                    status_message = "Enemy's turn...";
                    combat_state = Combat_State.EnemyTurn;
                    combat_timer = 0;
                }
            }
            break;

        case Combat_State.EnemyTurn:
            // Ensure we have a timer delay before enemy attacks
            if (combat_timer >= enemy_turn_delay) {
                // Find a live enemy to attack if current one is dead
                if (active_enemy.dead) {
                    if (!slime_enemy.dead) {
                        active_enemy = &slime_enemy;
                    } else if (!plant_enemy.dead) {
                        active_enemy = &plant_enemy;
                    } else {
                        // All enemies dead
                        status_message = "Victory!";
                        combat_state = Combat_State.BattleOver;
                        break;
                    }
                }
                
                if (!active_enemy.dead) {
                    status_message = "Enemy is attacking!";
                    if (mchar.defending) {
                        // Use a reduced damage amount
                        int reduced_damage = max(1, *active_enemy.damage - mchar.defense);
                        int temp_damage = reduced_damage;
                        damage_player(*active_enemy, mchar, &temp_damage, slime_animations, plant_animations);
                        mchar.defending = false; // Reset defending flag
                        mchar.defense -= 5; // Remove temporary defense boost
                    } else {
                        damage_player(*active_enemy, mchar, active_enemy.damage, slime_animations, plant_animations);
                    }
                    
                    combat_state = Combat_State.EnemyActionExecuting;
                    combat_timer = 0;
                }
            }
            break;

        case Combat_State.EnemyActionExecuting:
            // Add timeout mechanism
            bool animation_completed = false;
            
            if (active_enemy == &slime_enemy) {
                animation_completed = slime_animation_completed;
            } else if (active_enemy == &plant_enemy) {
                animation_completed = plant_animation_completed;
            }
            
            // Force completion after reasonable timeout
            if (animation_completed || combat_timer > 1.0) {
                if (mchar.dead) {
                    status_message = "You have been defeated!";
                    combat_state = Combat_State.BattleOver;
                } else {
                    status_message = "Your turn! Choose an action.";
                    combat_state = Combat_State.PlayerTurn;
                }
            }
            break;

        case Combat_State.BattleOver:
            // Battle is over, player can view results
            if (IsKeyPressed(KeyboardKey.KEY_SPACE) || IsKeyPressed(KeyboardKey.KEY_ENTER)) {
                // If player wants to start a new battle, reset state
                if (mchar.dead) {
                    // Reset player
                    mchar = init_player();
                    player_stats[0] = mchar.health;
                }
                
                // Reset both enemies
                slime_enemy.dead = false;
                slime_enemy.health = slime_enemy.max_health;
                slime_enemy.animation = &slime_animations.idle;
                slime_enemy.animation.state = Animation_State.Idle;

                plant_enemy.dead = false;
                plant_enemy.health = plant_enemy.max_health;
                plant_enemy.animation = &plant_animations.idle;
                plant_enemy.animation.state = Animation_State.Idle;

                // Set active enemy back to slime as default
                active_enemy = &slime_enemy;
                
                status_message = "Your turn! Choose an action.";
                combat_state = Combat_State.PlayerTurn;
            }
            break;
            
        default:
            break;
        }

        // Draw
        BeginDrawing();
        ClearBackground(RAYWHITE);

        // Draw background texture
        if (Level1.width > 0 && Level1.height > 0) {
            DrawTexturePro(
                Level1,
                Rectangle(0, 0, cast(float)Level1.width, cast(float)Level1.height), 
                Rectangle(0, 0, cast(float)screenWidth, cast(float)screenHeight),
                Vector2(0, 0),  
                0,                
                WHITE             
            );
        }
        
        // Display combat status
        DrawRectangle(screenWidth/2 - 200, 20, 400, 40, ColorAlpha(GRAY, 0.65));
        DrawRectangleLines(screenWidth/2 - 200, 20, 400, 40, BLACK);
        DrawText(status_message.ptr, screenWidth/2 - 190, 30, 20, BLACK);
        
        // Display control help
        if (IsKeyPressed(KeyboardKey.KEY_H)) {
            controlsVisible = !controlsVisible;
        }

        if (controlsVisible) {
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
        DrawRectangle(xpBarX - 20, xpBarY - 50, 200, 20, ColorAlpha(BLACK, 0.3));
        DrawRectangle(xpBarX - 20, xpBarY - 50, 200 * (mchar.health / 100.0), 20, RED);
        DrawRectangleLines(xpBarX - 20, xpBarY - 50, 200, 20, BLACK);
        DrawText(format("HP: %d/100", mchar.health).ptr, xpBarX + 75, xpBarY - 46, 16, WHITE);

        // Draw XP bar
        DrawRectangle(xpBarX, xpBarY, xpBarWidth, xpBarHeight, ColorAlpha(BLACK, 0.3));
        DrawRectangle(xpBarX, xpBarY, xpBarWidth * (mchar.current_xp / cast(float)mchar.max_xp), xpBarHeight, YELLOW);
        DrawRectangleLines(xpBarX, xpBarY, xpBarWidth, xpBarHeight, BLACK);
        DrawText(format("Level: %d", mchar.level).ptr, xpBarX, xpBarY - 20, 20, BLACK);

        // Draw enemy health bars
        if (!slime_enemy.dead) {
            DrawRectangle(slime_pos.x - 50, slime_pos.y - 90, 100, 10, ColorAlpha(BLACK, 0.3));
            DrawRectangle(slime_pos.x - 50, slime_pos.y - 90, 100 * (slime_enemy.health / cast(float)slime_enemy.max_health), 10, RED);
            DrawRectangleLines(slime_pos.x - 50, slime_pos.y - 90, 100, 10, BLACK);
            DrawText(slime_enemy.name.ptr, slime_pos.x - 50, slime_pos.y - 110, 20, BLACK);
        }

        if (!plant_enemy.dead) {
            DrawRectangle(plant_pos.x - 50, plant_pos.y - 90, 100, 10, ColorAlpha(BLACK, 0.3));
            DrawRectangle(plant_pos.x - 50, plant_pos.y - 90, 100 * (plant_enemy.health / cast(float)plant_enemy.max_health), 10, RED);
            DrawRectangleLines(plant_pos.x - 50, plant_pos.y - 90, 100, 10, BLACK);
            DrawText(plant_enemy.name.ptr, plant_pos.x - 50, plant_pos.y - 110, 20, BLACK);
        }

        // Draw enemies
        if (!slime_enemy.dead || slime_enemy.animation.state == Animation_State.Death) {
            draw_animation(*slime_enemy.animation, slime_enemy.position, false);
        }

        if (!plant_enemy.dead || plant_enemy.animation.state == Animation_State.Death) {
            draw_animation(*plant_enemy.animation, plant_enemy.position, false);
        }

        // Highlight active enemy with an indicator
        if (active_enemy == &slime_enemy && !slime_enemy.dead) {
            DrawText("▼", slime_pos.x, slime_pos.y - 130, 30, RED);
        } else if (active_enemy == &plant_enemy && !plant_enemy.dead) {
            DrawText("▼", plant_pos.x, plant_pos.y - 130, 30, RED);
        }

        // Allow player to switch targets with TAB if both enemies are alive
        if (IsKeyPressed(KeyboardKey.KEY_TAB) && combat_state == Combat_State.PlayerTurn) {
            if (active_enemy == &slime_enemy && !plant_enemy.dead) {
                active_enemy = &plant_enemy;
            } else if (active_enemy == &plant_enemy && !slime_enemy.dead) {
                active_enemy = &slime_enemy;
            }
        }

        // Draw main menu box
        DrawRectangle(menuX - menuPadding, menuY - menuPadding, menuBoxWidth, menuBoxHeight, ColorAlpha(SKYBLUE, 0.5));
        DrawRectangleLines(menuX - menuPadding, menuY - menuPadding, menuBoxWidth, menuBoxHeight, BLACK);

        // Draw main menu options
        for (int i = 0; i < menuOptions.length; i++) {
            if (i == menuSelectedIndex) {
                DrawRectangle(menuX, menuY + i * (menuHeight + spacing), menuWidth, menuHeight, SKYBLUE);
            } else {
                DrawRectangle(menuX, menuY + i * (menuHeight + spacing), menuWidth, menuHeight, ColorAlpha(LIGHTGRAY, 0.5));
            }
            
            DrawRectangleLines(menuX, menuY + i * (menuHeight + spacing), menuWidth, menuHeight, BLACK);
            DrawText(menuOptions[i].name.ptr, menuX + 15, menuY + i * (menuHeight + spacing) + 8, 20, BLACK);
        }

        // Draw stats menu if active
        if (inStatsMenu) {
            // Update player stats before drawing
            update_player_stats(mchar, player_stats);
            
            DrawRectangle(statsMenuX - menuPadding, statsMenuY - menuPadding, statsMenuBoxWidth, statsMenuBoxHeight, ColorAlpha(SKYBLUE, 0.5));
            DrawRectangleLines(statsMenuX - menuPadding, statsMenuY - menuPadding, statsMenuBoxWidth, statsMenuBoxHeight, BLACK);
            
            for (int i = 0; i < statsOptions.length; i++) {
                if (i == statsSelectedIndex) {
                    DrawRectangle(statsMenuX, statsMenuY + i * (statsMenuHeight + spacing), statsMenuWidth, statsMenuHeight, SKYBLUE);
                } else {
                    DrawRectangle(statsMenuX, statsMenuY + i * (statsMenuHeight + spacing), statsMenuWidth, statsMenuHeight, ColorAlpha(LIGHTGRAY, 0.5));
                }
                
                DrawRectangleLines(statsMenuX, statsMenuY + i * (statsMenuHeight + spacing), statsMenuWidth, statsMenuHeight, BLACK);
                DrawText(format("%s: %d", statsOptions[i].name, player_stats[i]).ptr, 
                         statsMenuX + 15, statsMenuY + i * (statsMenuHeight + spacing) + 8, 20, BLACK);
            }
        }

        // Draw item menu if active
        if (inItemMenu) {
            // Update item menu box height based on number of items
            itemTotalHeight = (itemMenuHeight + spacing) * cast(int)itemOptions.length - spacing;
            if (itemTotalHeight <= 0) itemTotalHeight = itemMenuHeight; // Ensure at least one row height
            itemMenuBoxHeight = itemTotalHeight + menuPadding * 2;
            
            DrawRectangle(itemMenuX - menuPadding, itemMenuY - menuPadding, itemMenuBoxWidth, itemMenuBoxHeight, ColorAlpha(SKYBLUE, 0.5));
            DrawRectangleLines(itemMenuX - menuPadding, itemMenuY - menuPadding, itemMenuBoxWidth, itemMenuBoxHeight, BLACK);
            
            if (itemOptions.length == 0) {
                DrawText("No items", itemMenuX + 15, itemMenuY + 8, 20, BLACK);
            } else {
                for (int i = 0; i < itemOptions.length; i++) {
                    if (i == itemSelectedIndex) {
                        DrawRectangle(itemMenuX, itemMenuY + i * (itemMenuHeight + spacing), itemMenuWidth, itemMenuHeight, SKYBLUE);
                    } else {
                        DrawRectangle(itemMenuX, itemMenuY + i * (itemMenuHeight + spacing), itemMenuWidth, itemMenuHeight, ColorAlpha(LIGHTGRAY, 0.5));
                    }
                    
                    DrawRectangleLines(itemMenuX, itemMenuY + i * (itemMenuHeight + spacing), itemMenuWidth, itemMenuHeight, BLACK);
                    DrawText(itemOptions[i].name.ptr, itemMenuX + 15, itemMenuY + i * (itemMenuHeight + spacing) + 8, 20, BLACK);
                }
            }
        }

        // Draw settings menu if active
        if (inSettingsMenu) {
            DrawRectangle(settingsMenuX - menuPadding, settingsMenuY - menuPadding, settingsMenuBoxWidth, settingsMenuBoxHeight, ColorAlpha(SKYBLUE, 0.5));
            DrawRectangleLines(settingsMenuX - menuPadding, settingsMenuY - menuPadding, settingsMenuBoxWidth, settingsMenuBoxHeight, BLACK);
            
            for (int i = 0; i < settingsOptions.length; i++) {
                if (i == settingsSelectedIndex) {
                    DrawRectangle(settingsMenuX, settingsMenuY + i * (settingsMenuHeight + spacing), settingsMenuWidth, settingsMenuHeight, SKYBLUE);
                } else {
                    DrawRectangle(settingsMenuX, settingsMenuY + i * (settingsMenuHeight + spacing), settingsMenuWidth, settingsMenuHeight, ColorAlpha(LIGHTGRAY, 0.5));
                }
                
                DrawRectangleLines(settingsMenuX, settingsMenuY + i * (settingsMenuHeight + spacing), settingsMenuWidth, settingsMenuHeight, BLACK);
                DrawText(settingsOptions[i].name.ptr, settingsMenuX + 15, settingsMenuY + i * (settingsMenuHeight + spacing) + 8, 20, BLACK);
            }
        }

        // Draw game over or victory state if battle is over
        if (combat_state == Combat_State.BattleOver) {
            string result_message = mchar.dead ? "Game Over! Press ENTER to restart" : "Victory! Press ENTER to continue";
            DrawRectangle(screenWidth/2 - 250, screenHeight/2 - 30, 500, 60, ColorAlpha(BLACK, 0.7));
            DrawRectangleLines(screenWidth/2 - 250, screenHeight/2 - 30, 500, 60, WHITE);
            DrawText(result_message.ptr, screenWidth/2 - 240, screenHeight/2 - 20, 30, WHITE);
        }

        EndDrawing();
    }
}
