#include <sourcemod>
#include <sdktools>

StringMap playerUsedBanMap;
StringMap internalHeroNameByAlias;
StringMap actualHeroNames;
ArrayList nominatedHeroes;
ArrayList bannedHeroes;
bool pluginIsActive;

public OnPluginStart() {
    AddCommandListener(restrictPickingBannedHero, "dota_select_hero");
    RegConsoleCmd("ban", nominate);
}

public OnMapStart()
{
    if (GameRules_GetProp("m_iGameMode", 4, 0) == 22) {
        CreateTimer(5.0, HookGameRulesStateChange);
        pluginIsActive = true;
    } else {
        pluginIsActive = false;
    }

    nominatedHeroes = CreateArray(64)
    bannedHeroes = CreateArray(64)
    playerUsedBanMap = CreateTrie();
    fillInternalHeroNameByAlias();
    fillActualHeroNames();
}


public Action:HookGameRulesStateChange(Handle:timer) {
    HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
}

public Action:OnGameStateChange(Handle:event, String:name[], bool:dontBroadcast) {
    CreateTimer(2.0, printInstructionsMsgToAll);
    CreateTimer(15.0, OnGameStateChangeDelayed);
    UnhookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);

    return Plugin_Continue;
}

public Action:OnGameStateChangeDelayed(Handle:timer) {
    if (hasDraftStageStarted() && pluginIsActive) {
        banHeroes();
        pluginIsActive = false;
    }
    return Plugin_Continue;
}

public Action:printInstructionsMsgToAll(Handle:timer) {
    PrintToChatAll("[SM] Nominate a hero for banning: /ban [hero name or abbreviation]");
    return Plugin_Continue;
}

hasDraftStageStarted() {
    return GameRules_GetProp("m_nGameState", 4, 0) > 1;
}

banHeroes() {
    // Ban half of the nominated heroes
    // Odd numbers are rounded randomly, so if 9 heroes are nominated then either 4 or 5 will be
    // banned
    int num_heroes_to_ban = nominatedHeroes.Length / 2;
    if (nominatedHeroes.Length % 2 == 1) {
        num_heroes_to_ban += RoundToNearest(GetURandomFloat());
    }

    if (num_heroes_to_ban == 0) {
        PrintToChatAll("[SM] No heroes were banned");
    }

    for (; num_heroes_to_ban > 0; num_heroes_to_ban--) {
        int index = GetRandomInt(0, nominatedHeroes.Length - 1);
        char heroName[64];
        nominatedHeroes.GetString(index, heroName, sizeof(heroName));

        char actualHeroName[64];
        actualHeroNames.GetString(heroName, actualHeroName, sizeof(actualHeroName));
        PrintToChatAll("[SM] %s has been banned", actualHeroName);

        bannedHeroes.PushString(heroName);
        nominatedHeroes.Erase(index);
    }
}

public Action nominate(int client, int args) {
    if (!pluginIsActive) {
        return Plugin_Handled;
    }

    int client_team = GetClientTeam(client);

    // Only players on radiant/dire can ban heroes
    if (!(client_team == 2 || client_team == 3)) {
        return Plugin_Handled;
    }

    char steamid[32];
    GetClientAuthId(client, AuthIdType:2, steamid, 32, true);

    bool buffer;
    if (playerUsedBanMap.GetValue(steamid, buffer)) {
        PrintToChat(client, "[SM] You have already nominated a hero");
        return Plugin_Handled;
    }

    char heroKey[32];
    GetCmdArgString(heroKey, sizeof(heroKey));

    char heroName[64];
    bool heroExists = internalHeroNameByAlias.GetString(heroKey, heroName, sizeof(heroName));
    if (!heroExists) {
        PrintToChat(client, "[SM] Unknown hero");
        return Plugin_Handled;
    }

    bool heroIsNominated = nominatedHeroes.FindString(heroName) != -1;

    if (!heroIsNominated) {
        playerUsedBanMap.SetValue(steamid, true);
        nominatedHeroes.PushString(heroName);

        char actualHeroName[64];
        actualHeroNames.GetString(heroName, actualHeroName, sizeof(actualHeroName));
        PrintToChatAll("[SM] A hero has been nominated for banning");
        PrintToChat(client, "[SM] %s has been nominated for banning", actualHeroName);
    } else {
        PrintToChat(client, "[SM] This hero was already nominated");
    }

    return Plugin_Handled;
}

public Action:restrictPickingBannedHero(client, char[] command, args) {
    char heroName[64];
    GetCmdArg(1, heroName, sizeof(heroName));

    bool heroIsBanned = bannedHeroes.FindString(heroName) != -1;
    if (heroIsBanned) {
        PrintToChat(client, "[SM] This hero is banned");
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public OnClientPutInServer(client)
{
    if (pluginIsActive) {
	    CreateTimer(2.0, TimerCallBack, client);
    }
}	

public Action:TimerCallBack(Handle:timer, any:client)
{
    if (pluginIsActive && IsClientInGame(client)) {
        PrintToChat(client, "[SM] Nominate a hero for banning: /ban [hero name or abbreviation]");

        // Print nominated heroes for players who connected later
        // for (int i = 0; i < nominatedHeroes.Length; i++) {
        //     char heroName[64];
        //     nominatedHeroes.GetString(i, heroName, sizeof(heroName));

        //     char actualHeroName[64];
        //     actualHeroNames.GetString(heroName, actualHeroName, sizeof(actualHeroName));
        //     PrintToChat(client, "[SM] %s has been nominated for banning", actualHeroName);
        // }
    }
}

public fillInternalHeroNameByAlias() {
    internalHeroNameByAlias = CreateTrie();

    internalHeroNameByAlias.SetString("abaddon", "npc_dota_hero_abaddon")
    internalHeroNameByAlias.SetString("abadon", "npc_dota_hero_abaddon")
    internalHeroNameByAlias.SetString("aba", "npc_dota_hero_abaddon")

    internalHeroNameByAlias.SetString("alchemist", "npc_dota_hero_alchemist")
    internalHeroNameByAlias.SetString("alch", "npc_dota_hero_alchemist")
    internalHeroNameByAlias.SetString("alc", "npc_dota_hero_alchemist")

    internalHeroNameByAlias.SetString("aa", "npc_dota_hero_ancient_apparition")
    internalHeroNameByAlias.SetString("ancient apparition", "npc_dota_hero_ancient_apparition")

    internalHeroNameByAlias.SetString("am", "npc_dota_hero_antimage")
    internalHeroNameByAlias.SetString("antimage", "npc_dota_hero_antimage")
    internalHeroNameByAlias.SetString("anti-mage", "npc_dota_hero_antimage")
    internalHeroNameByAlias.SetString("anti mage", "npc_dota_hero_antimage")

    internalHeroNameByAlias.SetString("axe", "npc_dota_hero_axe")
    internalHeroNameByAlias.SetString("bane", "npc_dota_hero_bane")

    internalHeroNameByAlias.SetString("batrider", "npc_dota_hero_batrider")
    internalHeroNameByAlias.SetString("bat", "npc_dota_hero_batrider")

    internalHeroNameByAlias.SetString("beastmaster", "npc_dota_hero_beastmaster")
    internalHeroNameByAlias.SetString("beast", "npc_dota_hero_beastmaster")

    internalHeroNameByAlias.SetString("blood", "npc_dota_hero_bloodseeker")
    internalHeroNameByAlias.SetString("bs", "npc_dota_hero_bloodseeker")
    internalHeroNameByAlias.SetString("bloodseeker", "npc_dota_hero_bloodseeker")
    internalHeroNameByAlias.SetString("seeker", "npc_dota_hero_bloodseeker")

    internalHeroNameByAlias.SetString("bounty hunter", "npc_dota_hero_bounty_hunter")
    internalHeroNameByAlias.SetString("bh", "npc_dota_hero_bounty_hunter")
    internalHeroNameByAlias.SetString("bounty", "npc_dota_hero_bounty_hunter")

    internalHeroNameByAlias.SetString("brewmaster", "npc_dota_hero_brewmaster")
    internalHeroNameByAlias.SetString("brew", "npc_dota_hero_brewmaster")

    internalHeroNameByAlias.SetString("brist", "npc_dota_hero_bristleback")
    internalHeroNameByAlias.SetString("bristle", "npc_dota_hero_bristleback")
    internalHeroNameByAlias.SetString("bristleback", "npc_dota_hero_bristleback")
    internalHeroNameByAlias.SetString("bb", "npc_dota_hero_bristleback")

    internalHeroNameByAlias.SetString("brood", "npc_dota_hero_broodmother")
    internalHeroNameByAlias.SetString("broodmother", "npc_dota_hero_broodmother")

    internalHeroNameByAlias.SetString("cent", "npc_dota_hero_centaur")
    internalHeroNameByAlias.SetString("centaur", "npc_dota_hero_centaur")

    internalHeroNameByAlias.SetString("ck", "npc_dota_hero_chaos_knight")
    internalHeroNameByAlias.SetString("chaos", "npc_dota_hero_chaos_knight")
    internalHeroNameByAlias.SetString("chaos knight", "npc_dota_hero_chaos_knight")

    internalHeroNameByAlias.SetString("chen", "npc_dota_hero_chen")

    internalHeroNameByAlias.SetString("clinkz", "npc_dota_hero_clinkz")
    internalHeroNameByAlias.SetString("bone fletcher", "npc_dota_hero_clinkz")

    internalHeroNameByAlias.SetString("cm", "npc_dota_hero_crystal_maiden")
    internalHeroNameByAlias.SetString("crystal maiden", "npc_dota_hero_crystal_maiden")

    internalHeroNameByAlias.SetString("ds", "npc_dota_hero_dark_seer")
    internalHeroNameByAlias.SetString("dark seer", "npc_dota_hero_dark_seer")

    internalHeroNameByAlias.SetString("dazzle", "npc_dota_hero_dazzle")

    internalHeroNameByAlias.SetString("dp", "npc_dota_hero_death_prophet")
    internalHeroNameByAlias.SetString("death prophet", "npc_dota_hero_death_prophet")

    internalHeroNameByAlias.SetString("disruptor", "npc_dota_hero_disruptor")

    internalHeroNameByAlias.SetString("doom", "npc_dota_hero_doom_bringer")

    internalHeroNameByAlias.SetString("dk", "npc_dota_hero_dragon_knight")
    internalHeroNameByAlias.SetString("dragon knight", "npc_dota_hero_dragon_knight")

    internalHeroNameByAlias.SetString("drow", "npc_dota_hero_drow_ranger")
    internalHeroNameByAlias.SetString("drow ranger", "npc_dota_hero_drow_ranger")

    internalHeroNameByAlias.SetString("earth spirit", "npc_dota_hero_earth_spirit")
    internalHeroNameByAlias.SetString("earthspirit", "npc_dota_hero_earth_spirit")

    internalHeroNameByAlias.SetString("earthshaker", "npc_dota_hero_earthshaker")
    internalHeroNameByAlias.SetString("shaker", "npc_dota_hero_earthshaker")

    internalHeroNameByAlias.SetString("elder titan", "npc_dota_hero_elder_titan")
    internalHeroNameByAlias.SetString("et", "npc_dota_hero_elder_titan")

    internalHeroNameByAlias.SetString("ember", "npc_dota_hero_ember_spirit")
    internalHeroNameByAlias.SetString("ember spirit", "npc_dota_hero_ember_spirit")

    internalHeroNameByAlias.SetString("ench", "npc_dota_hero_enchantress")
    internalHeroNameByAlias.SetString("enchantress", "npc_dota_hero_enchantress")

    internalHeroNameByAlias.SetString("enigma", "npc_dota_hero_enigma")

    internalHeroNameByAlias.SetString("void", "npc_dota_hero_faceless_void")
    internalHeroNameByAlias.SetString("fv", "npc_dota_hero_faceless_void")
    internalHeroNameByAlias.SetString("faceless void", "npc_dota_hero_faceless_void")

    internalHeroNameByAlias.SetString("furion", "npc_dota_hero_furion")
    internalHeroNameByAlias.SetString("np", "npc_dota_hero_furion")
    internalHeroNameByAlias.SetString("natures prophet", "npc_dota_hero_furion")

    internalHeroNameByAlias.SetString("gyrocopter", "npc_dota_hero_gyrocopter")
    internalHeroNameByAlias.SetString("gyro", "npc_dota_hero_gyrocopter")

    internalHeroNameByAlias.SetString("huskar", "npc_dota_hero_huskar")

    internalHeroNameByAlias.SetString("invoker", "npc_dota_hero_invoker")

    internalHeroNameByAlias.SetString("jakiro", "npc_dota_hero_jakiro")

    internalHeroNameByAlias.SetString("jug", "npc_dota_hero_juggernaut")
    internalHeroNameByAlias.SetString("jugg", "npc_dota_hero_juggernaut")
    internalHeroNameByAlias.SetString("juggernaut", "npc_dota_hero_juggernaut")

    internalHeroNameByAlias.SetString("kotl", "npc_dota_hero_keeper_of_the_light")
    internalHeroNameByAlias.SetString("keeper of the light", "npc_dota_hero_keeper_of_the_light")

    internalHeroNameByAlias.SetString("kunkka", "npc_dota_hero_kunkka")
    internalHeroNameByAlias.SetString("kunka", "npc_dota_hero_kunkka")

    internalHeroNameByAlias.SetString("lc", "npc_dota_hero_legion_commander")
    internalHeroNameByAlias.SetString("legion", "npc_dota_hero_legion_commander")
    internalHeroNameByAlias.SetString("legion commander", "npc_dota_hero_legion_commander")

    internalHeroNameByAlias.SetString("leshrac", "npc_dota_hero_leshrac")
    internalHeroNameByAlias.SetString("lesh", "npc_dota_hero_leshrac")

    internalHeroNameByAlias.SetString("lich", "npc_dota_hero_lich")

    internalHeroNameByAlias.SetString("naix", "npc_dota_hero_life_stealer")
    internalHeroNameByAlias.SetString("lifestealer", "npc_dota_hero_life_stealer")
    internalHeroNameByAlias.SetString("ls", "npc_dota_hero_life_stealer")
    internalHeroNameByAlias.SetString("life stealer", "npc_dota_hero_life_stealer")

    internalHeroNameByAlias.SetString("lina", "npc_dota_hero_lina")

    internalHeroNameByAlias.SetString("lion", "npc_dota_hero_lion")

    internalHeroNameByAlias.SetString("lone druid", "npc_dota_hero_lone_druid")
    internalHeroNameByAlias.SetString("ld", "npc_dota_hero_lone_druid")

    internalHeroNameByAlias.SetString("luna", "npc_dota_hero_luna")

    internalHeroNameByAlias.SetString("lycan", "npc_dota_hero_lycan")

    internalHeroNameByAlias.SetString("magnus", "npc_dota_hero_magnataur")

    internalHeroNameByAlias.SetString("medusa", "npc_dota_hero_medusa")
    internalHeroNameByAlias.SetString("dusa", "npc_dota_hero_medusa")

    internalHeroNameByAlias.SetString("meepo", "npc_dota_hero_meepo")

    internalHeroNameByAlias.SetString("mirana", "npc_dota_hero_mirana")

    internalHeroNameByAlias.SetString("morphling", "npc_dota_hero_morphling")
    internalHeroNameByAlias.SetString("morph", "npc_dota_hero_morphling")

    internalHeroNameByAlias.SetString("naga", "npc_dota_hero_naga_siren")
    internalHeroNameByAlias.SetString("naga siren", "npc_dota_hero_naga_siren")

    internalHeroNameByAlias.SetString("necrolyte", "npc_dota_hero_necrolyte")
    internalHeroNameByAlias.SetString("necro", "npc_dota_hero_necrolyte")
    internalHeroNameByAlias.SetString("necrophos", "npc_dota_hero_necrolyte")

    internalHeroNameByAlias.SetString("sf", "npc_dota_hero_nevermore")
    internalHeroNameByAlias.SetString("shadow fiend", "npc_dota_hero_nevermore")
    internalHeroNameByAlias.SetString("nevermore", "npc_dota_hero_nevermore")

    internalHeroNameByAlias.SetString("night stalker", "npc_dota_hero_night_stalker")
    internalHeroNameByAlias.SetString("ns", "npc_dota_hero_night_stalker")

    internalHeroNameByAlias.SetString("nyx", "npc_dota_hero_nyx_assassin")
    internalHeroNameByAlias.SetString("nyx assassin", "npc_dota_hero_nyx_assassin")

    internalHeroNameByAlias.SetString("od", "npc_dota_hero_obsidian_destroyer")

    internalHeroNameByAlias.SetString("ogre", "npc_dota_hero_ogre_magi")
    internalHeroNameByAlias.SetString("ogre magi", "npc_dota_hero_ogre_magi")

    internalHeroNameByAlias.SetString("omni", "npc_dota_hero_omniknight")
    internalHeroNameByAlias.SetString("omniknight", "npc_dota_hero_omniknight")

    internalHeroNameByAlias.SetString("oracle", "npc_dota_hero_oracle")

    internalHeroNameByAlias.SetString("phantom assassin", "npc_dota_hero_phantom_assassin")
    internalHeroNameByAlias.SetString("pa", "npc_dota_hero_phantom_assassin")

    internalHeroNameByAlias.SetString("pl", "npc_dota_hero_phantom_lancer")
    internalHeroNameByAlias.SetString("phantom lancer", "npc_dota_hero_phantom_lancer")
    internalHeroNameByAlias.SetString("lancer", "npc_dota_hero_phantom_lancer")

    internalHeroNameByAlias.SetString("phoenix", "npc_dota_hero_phoenix")

    internalHeroNameByAlias.SetString("puck", "npc_dota_hero_puck")

    internalHeroNameByAlias.SetString("pudge", "npc_dota_hero_pudge")

    internalHeroNameByAlias.SetString("pugna", "npc_dota_hero_pugna")

    internalHeroNameByAlias.SetString("queen of pain", "npc_dota_hero_queenofpain")
    internalHeroNameByAlias.SetString("qop", "npc_dota_hero_queenofpain")

    internalHeroNameByAlias.SetString("clockwerk", "npc_dota_hero_rattletrap")
    internalHeroNameByAlias.SetString("clock", "npc_dota_hero_rattletrap")

    internalHeroNameByAlias.SetString("razor", "npc_dota_hero_razor")

    internalHeroNameByAlias.SetString("riki", "npc_dota_hero_riki")

    internalHeroNameByAlias.SetString("rubick", "npc_dota_hero_rubick")

    internalHeroNameByAlias.SetString("sand king", "npc_dota_hero_sand_king")
    internalHeroNameByAlias.SetString("sk", "npc_dota_hero_sand_king")

    internalHeroNameByAlias.SetString("sd", "npc_dota_hero_shadow_demon")
    internalHeroNameByAlias.SetString("shadow demon", "npc_dota_hero_shadow_demon")

    internalHeroNameByAlias.SetString("ss", "npc_dota_hero_shadow_shaman")
    internalHeroNameByAlias.SetString("shadow shaman", "npc_dota_hero_shadow_shaman")

    internalHeroNameByAlias.SetString("timber", "npc_dota_hero_shredder")
    internalHeroNameByAlias.SetString("timbersaw", "npc_dota_hero_shredder")

    internalHeroNameByAlias.SetString("silencer", "npc_dota_hero_silencer")

    internalHeroNameByAlias.SetString("wk", "npc_dota_hero_skeleton_king")
    internalHeroNameByAlias.SetString("wraith king", "npc_dota_hero_skeleton_king")

    internalHeroNameByAlias.SetString("sky", "npc_dota_hero_skywrath_mage")
    internalHeroNameByAlias.SetString("skywrath", "npc_dota_hero_skywrath_mage")
    internalHeroNameByAlias.SetString("skywrath_mage", "npc_dota_hero_skywrath_mage")

    internalHeroNameByAlias.SetString("slardar", "npc_dota_hero_slardar")

    internalHeroNameByAlias.SetString("slark", "npc_dota_hero_slark")

    internalHeroNameByAlias.SetString("sniper", "npc_dota_hero_sniper")

    internalHeroNameByAlias.SetString("spectre", "npc_dota_hero_spectre")

    internalHeroNameByAlias.SetString("sb", "npc_dota_hero_spirit_breaker")
    internalHeroNameByAlias.SetString("spirit breaker", "npc_dota_hero_spirit_breaker")
    internalHeroNameByAlias.SetString("bara", "npc_dota_hero_spirit_breaker")

    internalHeroNameByAlias.SetString("storm", "npc_dota_hero_storm_spirit")
    internalHeroNameByAlias.SetString("storm spirit", "npc_dota_hero_storm_spirit")

    internalHeroNameByAlias.SetString("sven", "npc_dota_hero_sven")

    internalHeroNameByAlias.SetString("techies", "npc_dota_hero_techies")

    internalHeroNameByAlias.SetString("ta", "npc_dota_hero_templar_assassin")
    internalHeroNameByAlias.SetString("templar assassin", "npc_dota_hero_templar_assassin")
    internalHeroNameByAlias.SetString("templar", "npc_dota_hero_templar_assassin")

    internalHeroNameByAlias.SetString("tb", "npc_dota_hero_terrorblade")
    internalHeroNameByAlias.SetString("terrorblade", "npc_dota_hero_terrorblade")

    internalHeroNameByAlias.SetString("tide", "npc_dota_hero_tidehunter")
    internalHeroNameByAlias.SetString("tidehunter", "npc_dota_hero_tidehunter")

    internalHeroNameByAlias.SetString("tinker", "npc_dota_hero_tinker")

    internalHeroNameByAlias.SetString("tiny", "npc_dota_hero_tiny")

    internalHeroNameByAlias.SetString("treant", "npc_dota_hero_treant")

    internalHeroNameByAlias.SetString("troll", "npc_dota_hero_troll_warlord")
    internalHeroNameByAlias.SetString("troll warlord", "npc_dota_hero_troll_warlord")

    internalHeroNameByAlias.SetString("tusk", "npc_dota_hero_tusk")

    internalHeroNameByAlias.SetString("undying", "npc_dota_hero_undying")

    internalHeroNameByAlias.SetString("ursa", "npc_dota_hero_ursa")

    internalHeroNameByAlias.SetString("venge", "npc_dota_hero_vengefulspirit")
    internalHeroNameByAlias.SetString("vengeful spirit", "npc_dota_hero_vengefulspirit")

    internalHeroNameByAlias.SetString("venomancer", "npc_dota_hero_venomancer")
    internalHeroNameByAlias.SetString("veno", "npc_dota_hero_venomancer")

    internalHeroNameByAlias.SetString("viper", "npc_dota_hero_viper")
    internalHeroNameByAlias.SetString("visage", "npc_dota_hero_visage")

    internalHeroNameByAlias.SetString("warlock", "npc_dota_hero_warlock")

    internalHeroNameByAlias.SetString("weaver", "npc_dota_hero_weaver")

    internalHeroNameByAlias.SetString("windrunner", "npc_dota_hero_windrunner")
    internalHeroNameByAlias.SetString("windranger", "npc_dota_hero_windrunner")
    internalHeroNameByAlias.SetString("wr", "npc_dota_hero_windrunner")

    internalHeroNameByAlias.SetString("ww", "npc_dota_hero_winter_wyvern")
    internalHeroNameByAlias.SetString("wyvern", "npc_dota_hero_winter_wyvern")
    internalHeroNameByAlias.SetString("winter wyvern", "npc_dota_hero_winter_wyvern")

    internalHeroNameByAlias.SetString("io", "npc_dota_hero_wisp")
    internalHeroNameByAlias.SetString("wisp", "npc_dota_hero_wisp")

    internalHeroNameByAlias.SetString("wd", "npc_dota_hero_witch_doctor")
    internalHeroNameByAlias.SetString("witch doctor", "npc_dota_hero_witch_doctor")

    internalHeroNameByAlias.SetString("zeus", "npc_dota_hero_zuus")
}

fillActualHeroNames() {
    actualHeroNames  = CreateTrie();

    actualHeroNames.SetString("npc_dota_hero_abaddon", "Abaddon")
    actualHeroNames.SetString("npc_dota_hero_alchemist", "Alchemist")
    actualHeroNames.SetString("npc_dota_hero_ancient_apparition", "Ancient Apparition")
    actualHeroNames.SetString("npc_dota_hero_antimage", "Anti-Mage")
    actualHeroNames.SetString("npc_dota_hero_bane", "Bane")
    actualHeroNames.SetString("npc_dota_hero_batrider", "Batrider")
    actualHeroNames.SetString("npc_dota_hero_beastmaster", "Beastmaster")
    actualHeroNames.SetString("npc_dota_hero_bloodseeker", "Bloodseeker")
    actualHeroNames.SetString("npc_dota_hero_bounty_hunter", "Bounty Hunter")
    actualHeroNames.SetString("npc_dota_hero_brewmaster", "Brewmaster")
    actualHeroNames.SetString("npc_dota_hero_bristleback", "Bristleback")
    actualHeroNames.SetString("npc_dota_hero_broodmother", "Broodmother")
    actualHeroNames.SetString("npc_dota_hero_centaur", "Centaur")
    actualHeroNames.SetString("npc_dota_hero_chaos_knight", "Chaos Knight")
    actualHeroNames.SetString("npc_dota_hero_chen", "Chen")
    actualHeroNames.SetString("npc_dota_hero_clinkz", "Clinkz")
    actualHeroNames.SetString("npc_dota_hero_crystal_maiden", "Crystal Maiden")
    actualHeroNames.SetString("npc_dota_hero_dark_seer", "Dark Seer")
    actualHeroNames.SetString("npc_dota_hero_dazzle", "Dazzle")
    actualHeroNames.SetString("npc_dota_hero_death_prophet", "Death Prophet")
    actualHeroNames.SetString("npc_dota_hero_disruptor", "Disruptor")
    actualHeroNames.SetString("npc_dota_hero_doom_bringer", "Doom")
    actualHeroNames.SetString("npc_dota_hero_dragon_knight", "Dragon Knight")
    actualHeroNames.SetString("npc_dota_hero_drow_ranger", "Drow Ranger")
    actualHeroNames.SetString("npc_dota_hero_earth_spirit", "Earth Spirit")
    actualHeroNames.SetString("npc_dota_hero_earthshaker", "Earthshaker")
    actualHeroNames.SetString("npc_dota_hero_elder_titan", "Elder Titan")
    actualHeroNames.SetString("npc_dota_hero_ember_spirit", "Ember Spirit")
    actualHeroNames.SetString("npc_dota_hero_enchantress", "Enchantress")
    actualHeroNames.SetString("npc_dota_hero_enigma", "Enigma")
    actualHeroNames.SetString("npc_dota_hero_faceless_void", "Faceless Void")
    actualHeroNames.SetString("npc_dota_hero_furion", "Nature's Prophet")
    actualHeroNames.SetString("npc_dota_hero_gyrocopter", "Gyrocopter")
    actualHeroNames.SetString("npc_dota_hero_huskar", "Huskar")
    actualHeroNames.SetString("npc_dota_hero_invoker", "Invoker")
    actualHeroNames.SetString("npc_dota_hero_jakiro", "Jakiro")
    actualHeroNames.SetString("npc_dota_hero_juggernaut", "Juggernaut")
    actualHeroNames.SetString("npc_dota_hero_keeper_of_the_light", "Keeper of the Light")
    actualHeroNames.SetString("npc_dota_hero_kunkka", "Kunkka")
    actualHeroNames.SetString("npc_dota_hero_legion_commander", "Legion Commander")
    actualHeroNames.SetString("npc_dota_hero_leshrac", "Leshrac")
    actualHeroNames.SetString("npc_dota_hero_lich", "Lich")
    actualHeroNames.SetString("npc_dota_hero_life_stealer", "Lifestealer")
    actualHeroNames.SetString("npc_dota_hero_lina", "Lina")
    actualHeroNames.SetString("npc_dota_hero_lion", "Lion")
    actualHeroNames.SetString("npc_dota_hero_lone_druid", "Lone Druid")
    actualHeroNames.SetString("npc_dota_hero_luna", "Luna")
    actualHeroNames.SetString("npc_dota_hero_lycan", "Lycan")
    actualHeroNames.SetString("npc_dota_hero_magnataur", "Magnus")
    actualHeroNames.SetString("npc_dota_hero_medusa", "Medusa")
    actualHeroNames.SetString("npc_dota_hero_meepo", "Meepo")
    actualHeroNames.SetString("npc_dota_hero_mirana", "Mirana")
    actualHeroNames.SetString("npc_dota_hero_morphling", "Morphling")
    actualHeroNames.SetString("npc_dota_hero_naga_siren", "Naga Siren")
    actualHeroNames.SetString("npc_dota_hero_necrolyte", "Necrophos")
    actualHeroNames.SetString("npc_dota_hero_nevermore", "Shadow Fiend")
    actualHeroNames.SetString("npc_dota_hero_night_stalker", "Night Stalker")
    actualHeroNames.SetString("npc_dota_hero_nyx_assassin", "Nyx Assassin")
    actualHeroNames.SetString("npc_dota_hero_obsidian_destroyer", "Outworld Devourer")
    actualHeroNames.SetString("npc_dota_hero_ogre_magi", "Ogre Magi")
    actualHeroNames.SetString("npc_dota_hero_omniknight", "Omniknight")
    actualHeroNames.SetString("npc_dota_hero_oracle", "Oracle")
    actualHeroNames.SetString("npc_dota_hero_phantom_assassin", "Phantom Assassin")
    actualHeroNames.SetString("npc_dota_hero_phantom_lancer", "Phantom Lancer")
    actualHeroNames.SetString("npc_dota_hero_phoenix", "Phoenix")
    actualHeroNames.SetString("npc_dota_hero_puck", "Puck")
    actualHeroNames.SetString("npc_dota_hero_pudge", "Pudge")
    actualHeroNames.SetString("npc_dota_hero_pugna", "Pugna")
    actualHeroNames.SetString("npc_dota_hero_queenofpain", "Queen of Pain")
    actualHeroNames.SetString("npc_dota_hero_rattletrap", "Clockwerk")
    actualHeroNames.SetString("npc_dota_hero_razor", "Razor")
    actualHeroNames.SetString("npc_dota_hero_riki", "Riki")
    actualHeroNames.SetString("npc_dota_hero_rubick", "Rubick")
    actualHeroNames.SetString("npc_dota_hero_sand_king", "Sand King")
    actualHeroNames.SetString("npc_dota_hero_shadow_demon", "Shadow Demon")
    actualHeroNames.SetString("npc_dota_hero_shadow_shaman", "Shadow Shaman")
    actualHeroNames.SetString("npc_dota_hero_shredder", "Timbersaw")
    actualHeroNames.SetString("npc_dota_hero_silencer", "Silencer")
    actualHeroNames.SetString("npc_dota_hero_skeleton_king", "Wraith King")
    actualHeroNames.SetString("npc_dota_hero_skywrath_mage", "Skywrath Mage")
    actualHeroNames.SetString("npc_dota_hero_slardar", "Slardar")
    actualHeroNames.SetString("npc_dota_hero_slark", "Slark")
    actualHeroNames.SetString("npc_dota_hero_sniper", "Sniper")
    actualHeroNames.SetString("npc_dota_hero_spectre", "Spectre")
    actualHeroNames.SetString("npc_dota_hero_spirit_breaker", "Spirit Breaker")
    actualHeroNames.SetString("npc_dota_hero_storm_spirit", "Storm Spirit")
    actualHeroNames.SetString("npc_dota_hero_sven", "Sven")
    actualHeroNames.SetString("npc_dota_hero_techies", "Techies")
    actualHeroNames.SetString("npc_dota_hero_templar_assassin", "Templar Assassin")
    actualHeroNames.SetString("npc_dota_hero_terrorblade", "Terrorblade")
    actualHeroNames.SetString("npc_dota_hero_tidehunter", "Tidehunter")
    actualHeroNames.SetString("npc_dota_hero_tinker", "Tinker")
    actualHeroNames.SetString("npc_dota_hero_tiny", "Tiny")
    actualHeroNames.SetString("npc_dota_hero_treant", "Treant Protector")
    actualHeroNames.SetString("npc_dota_hero_troll_warlord", "Troll Warlord")
    actualHeroNames.SetString("npc_dota_hero_tusk", "Tusk")
    actualHeroNames.SetString("npc_dota_hero_undying", "Undying")
    actualHeroNames.SetString("npc_dota_hero_ursa", "Ursa")
    actualHeroNames.SetString("npc_dota_hero_vengefulspirit", "Vengeful Spirit")
    actualHeroNames.SetString("npc_dota_hero_venomancer", "Venomancer")
    actualHeroNames.SetString("npc_dota_hero_visage", "Visage")
    actualHeroNames.SetString("npc_dota_hero_warlock", "Warlock")
    actualHeroNames.SetString("npc_dota_hero_weaver", "Weaver")
    actualHeroNames.SetString("npc_dota_hero_windrunner", "Windranger")
    actualHeroNames.SetString("npc_dota_hero_winter_wyvern", "Winter Wyvern")
    actualHeroNames.SetString("npc_dota_hero_wisp", "Io")
    actualHeroNames.SetString("npc_dota_hero_witch_doctor", "Witch Doctor")
    actualHeroNames.SetString("npc_dota_hero_zuus", "Zeus")
}
