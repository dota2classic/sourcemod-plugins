#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public PlVers:__version =
{
    version = 5,
    filevers = "1.6.3",
    date = "04/26/2015",
    time = "13:16:59"
};


new indicator;
new adt_log;
new global_stats[10];
new adt_clients;
new Handle:SQLcon;
new index_g;
new index_b;
new count_g;
new count_b = 4;

public Plugin:myinfo =
{
    name = "Dota 2 - Stats",
    description = "Dota 2 - Stats",
    author = "Sittingbull",
    version = "1.0",
    url = ""
};

public GetHeroIdByLogName(String:HeroName[])
{
    new id = -1;
    if (!strcmp(HeroName, "\nCOMBAT SUMMARY\n", true))
    {
        id = 0;
    }
    if (!strcmp(HeroName, "--- Anti-Mage ---\n", true))
    {
        id = 1;
    }
    if (!strcmp(HeroName, "--- Axe ---\n", true))
    {
        id = 2;
    }
    if (!strcmp(HeroName, "--- Bane ---\n", true))
    {
        id = 3;
    }
    if (!strcmp(HeroName, "--- Bloodseeker ---\n", true))
    {
        id = 4;
    }
    if (!strcmp(HeroName, "--- Crystal Maiden ---\n", true))
    {
        id = 5;
    }
    if (!strcmp(HeroName, "--- Drow Ranger ---\n", true))
    {
        id = 6;
    }
    if (!strcmp(HeroName, "--- Earthshaker ---\n", true))
    {
        id = 7;
    }
    if (!strcmp(HeroName, "--- Juggernaut ---\n", true))
    {
        id = 8;
    }
    if (!strcmp(HeroName, "--- Mirana ---\n", true))
    {
        id = 9;
    }
    if (!strcmp(HeroName, "--- Shadow Fiend ---\n", true))
    {
        id = 11;
    }
    if (!strcmp(HeroName, "--- Morphling ---\n", true))
    {
        id = 10;
    }
    if (!strcmp(HeroName, "--- Phantom Lancer ---\n", true))
    {
        id = 12;
    }
    if (!strcmp(HeroName, "--- Puck ---\n", true))
    {
        id = 13;
    }
    if (!strcmp(HeroName, "--- Pudge ---\n", true))
    {
        id = 14;
    }
    if (!strcmp(HeroName, "--- Razor ---\n", true))
    {
        id = 15;
    }
    if (!strcmp(HeroName, "--- Sand King ---\n", true))
    {
        id = 16;
    }
    if (!strcmp(HeroName, "--- Storm Spirit ---\n", true))
    {
        id = 17;
    }
    if (!strcmp(HeroName, "--- Sven ---\n", true))
    {
        id = 18;
    }
    if (!strcmp(HeroName, "--- Tiny ---\n", true))
    {
        id = 19;
    }
    if (!strcmp(HeroName, "--- Vengeful Spirit ---\n", true))
    {
        id = 20;
    }
    if (!strcmp(HeroName, "--- Windranger ---\n", true))
    {
        id = 21;
    }
    if (!strcmp(HeroName, "--- Zeus ---\n", true))
    {
        id = 22;
    }
    if (!strcmp(HeroName, "--- Kunkka ---\n", true))
    {
        id = 23;
    }
    if (!strcmp(HeroName, "--- Lina ---\n", true))
    {
        id = 25;
    }
    if (!strcmp(HeroName, "--- Lich ---\n", true))
    {
        id = 31;
    }
    if (!strcmp(HeroName, "--- Lion ---\n", true))
    {
        id = 26;
    }
    if (!strcmp(HeroName, "--- Shadow Shaman ---\n", true))
    {
        id = 27;
    }
    if (!strcmp(HeroName, "--- Slardar ---\n", true))
    {
        id = 28;
    }
    if (!strcmp(HeroName, "--- Tidehunter ---\n", true))
    {
        id = 29;
    }
    if (!strcmp(HeroName, "--- Witch Doctor ---\n", true))
    {
        id = 30;
    }
    if (!strcmp(HeroName, "--- Riki ---\n", true))
    {
        id = 32;
    }
    if (!strcmp(HeroName, "--- Enigma ---\n", true))
    {
        id = 33;
    }
    if (!strcmp(HeroName, "--- Tinker ---\n", true))
    {
        id = 34;
    }
    if (!strcmp(HeroName, "--- Sniper ---\n", true))
    {
        id = 35;
    }
    if (!strcmp(HeroName, "--- Necrophos ---\n", true))
    {
        id = 36;
    }
    if (!strcmp(HeroName, "--- Warlock ---\n", true))
    {
        id = 37;
    }
    if (!strcmp(HeroName, "--- Beastmaster ---\n", true))
    {
        id = 38;
    }
    if (!strcmp(HeroName, "--- Queen of Pain ---\n", true))
    {
        id = 39;
    }
    if (!strcmp(HeroName, "--- Venomancer ---\n", true))
    {
        id = 40;
    }
    if (!strcmp(HeroName, "--- Faceless Void ---\n", true))
    {
        id = 41;
    }
    if (!strcmp(HeroName, "--- Wraith King ---\n", true))
    {
        id = 42;
    }
    if (!strcmp(HeroName, "--- Death Prophet ---\n", true))
    {
        id = 43;
    }
    if (!strcmp(HeroName, "--- Phantom Assassin ---\n", true))
    {
        id = 44;
    }
    if (!strcmp(HeroName, "--- Pugna ---\n", true))
    {
        id = 45;
    }
    if (!strcmp(HeroName, "--- Templar Assassin ---\n", true))
    {
        id = 46;
    }
    if (!strcmp(HeroName, "--- Viper ---\n", true))
    {
        id = 47;
    }
    if (!strcmp(HeroName, "--- Luna ---\n", true))
    {
        id = 48;
    }
    if (!strcmp(HeroName, "--- Dragon Knight ---\n", true))
    {
        id = 49;
    }
    if (!strcmp(HeroName, "--- Dazzle ---\n", true))
    {
        id = 50;
    }
    if (!strcmp(HeroName, "--- Clockwerk ---\n", true))
    {
        id = 51;
    }
    if (!strcmp(HeroName, "--- Leshrac ---\n", true))
    {
        id = 52;
    }
    if (!strcmp(HeroName, "--- Nature's Prophet ---\n", true))
    {
        id = 53;
    }
    if (!strcmp(HeroName, "--- Lifestealer ---\n", true))
    {
        id = 54;
    }
    if (!strcmp(HeroName, "--- Dark Seer ---\n", true))
    {
        id = 55;
    }
    if (!strcmp(HeroName, "--- Clinkz ---\n", true))
    {
        id = 56;
    }
    if (!strcmp(HeroName, "--- Omniknight ---\n", true))
    {
        id = 57;
    }
    if (!strcmp(HeroName, "--- Enchantress ---\n", true))
    {
        id = 58;
    }
    if (!strcmp(HeroName, "--- Huskar ---\n", true))
    {
        id = 59;
    }
    if (!strcmp(HeroName, "--- Night Stalker ---\n", true))
    {
        id = 60;
    }
    if (!strcmp(HeroName, "--- Broodmother ---\n", true))
    {
        id = 61;
    }
    if (!strcmp(HeroName, "--- Bounty Hunter ---\n", true))
    {
        id = 62;
    }
    if (!strcmp(HeroName, "--- Weaver ---\n", true))
    {
        id = 63;
    }
    if (!strcmp(HeroName, "--- Jakiro ---\n", true))
    {
        id = 64;
    }
    if (!strcmp(HeroName, "--- Batrider ---\n", true))
    {
        id = 65;
    }
    if (!strcmp(HeroName, "--- Chen ---\n", true))
    {
        id = 66;
    }
    if (!strcmp(HeroName, "--- Spectre ---\n", true))
    {
        id = 67;
    }
    if (!strcmp(HeroName, "--- Doom ---\n", true))
    {
        id = 69;
    }
    if (!strcmp(HeroName, "--- Ancient Apparition ---\n", true))
    {
        id = 68;
    }
    if (!strcmp(HeroName, "--- Ursa ---\n", true))
    {
        id = 70;
    }
    if (!strcmp(HeroName, "--- Spirit Breaker ---\n", true))
    {
        id = 71;
    }
    if (!strcmp(HeroName, "--- Gyrocopter ---\n", true))
    {
        id = 72;
    }
    if (!strcmp(HeroName, "--- Alchemist ---\n", true))
    {
        id = 73;
    }
    if (!strcmp(HeroName, "--- Invoker ---\n", true))
    {
        id = 74;
    }
    if (!strcmp(HeroName, "--- Silencer ---\n", true))
    {
        id = 75;
    }
    if (!strcmp(HeroName, "--- Outworld Devourer ---\n", true))
    {
        id = 76;
    }
    if (!strcmp(HeroName, "--- Lycan ---\n", true))
    {
        id = 77;
    }
    if (!strcmp(HeroName, "--- Brewmaster ---\n", true))
    {
        id = 78;
    }
    if (!strcmp(HeroName, "--- Shadow Demon ---\n", true))
    {
        id = 79;
    }
    if (!strcmp(HeroName, "--- Lone Druid ---\n", true))
    {
        id = 80;
    }
    if (!strcmp(HeroName, "--- Chaos Knight ---\n", true))
    {
        id = 81;
    }
    if (!strcmp(HeroName, "--- Meepo ---\n", true))
    {
        id = 82;
    }
    if (!strcmp(HeroName, "--- Treant Protector ---\n", true))
    {
        id = 83;
    }
    if (!strcmp(HeroName, "--- Ogre Magi ---\n", true))
    {
        id = 84;
    }
    if (!strcmp(HeroName, "--- Undying ---\n", true))
    {
        id = 85;
    }
    if (!strcmp(HeroName, "--- Rubick ---\n", true))
    {
        id = 86;
    }
    if (!strcmp(HeroName, "--- Disruptor ---\n", true))
    {
        id = 87;
    }
    if (!strcmp(HeroName, "--- Nyx Assassin ---\n", true))
    {
        id = 88;
    }
    if (!strcmp(HeroName, "--- Naga Siren ---\n", true))
    {
        id = 89;
    }
    if (!strcmp(HeroName, "--- Keeper of the Light ---\n", true))
    {
        id = 90;
    }
    if (!strcmp(HeroName, "--- Io ---\n", true))
    {
        id = 91;
    }
    if (!strcmp(HeroName, "--- Visage ---\n", true))
    {
        id = 92;
    }
    if (!strcmp(HeroName, "--- Slark ---\n", true))
    {
        id = 93;
    }
    if (!strcmp(HeroName, "--- Medusa ---\n", true))
    {
        id = 94;
    }
    if (!strcmp(HeroName, "--- Troll Warlord ---\n", true))
    {
        id = 95;
    }
    if (!strcmp(HeroName, "--- Centaur Warrunner ---\n", true))
    {
        id = 96;
    }
    if (!strcmp(HeroName, "--- Magnus ---\n", true))
    {
        id = 97;
    }
    if (!strcmp(HeroName, "--- Timbersaw ---\n", true))
    {
        id = 98;
    }
    if (!strcmp(HeroName, "--- Bristleback ---\n", true))
    {
        id = 99;
    }
    if (!strcmp(HeroName, "--- Tusk ---\n", true))
    {
        id = 100;
    }
    if (!strcmp(HeroName, "--- Skywrath Mage ---\n", true))
    {
        id = 101;
    }
    if (!strcmp(HeroName, "--- Abaddon ---\n", true))
    {
        id = 102;
    }
    if (!strcmp(HeroName, "--- Elder Titan ---\n", true))
    {
        id = 103;
    }
    if (!strcmp(HeroName, "--- Legion Commander ---\n", true))
    {
        id = 104;
    }
    if (!strcmp(HeroName, "--- Ember Spirit ---\n", true))
    {
        id = 106;
    }
    if (!strcmp(HeroName, "--- Earth Spirit ---\n", true))
    {
        id = 107;
    }
    if (!strcmp(HeroName, "--- Terrorblade ---\n", true))
    {
        id = 109;
    }
    if (!strcmp(HeroName, "--- Phoenix ---\n", true))
    {
        id = 110;
    }
    if (!strcmp(HeroName, "--- Oracle ---\n", true))
    {
        id = 111;
    }
    if (!strcmp(HeroName, "--- Techies ---\n", true))
    {
        id = 105;
    }
    if (!strcmp(HeroName, "npc_dota_hero_winter_wyvern", true))
    {
        id = 112;
    }
    return id;
}

Insert_Players(Handle:Connection, Handle:adt_array[], String:endtime[])
{
    new String:error[1024];
    new String:query[1024];
    Connection = SQL_DefConnect(error, 1024, true);
    if (Connection)
    {
        new String:steamid[32];
        new i;
        while (i < 10)
        {
        	GetArrayString(adt_array[i], 20, steamid, 32);
            Format(query, 1024, "INSERT INTO dotaplayers (endtime,steamid,result,team,hero,kills,deaths,assists,networth,level,lhs,denies,healing) VALUES ('%s','%s','%d','%d','%d','%d','%d','%d','%d','%d','%d','%d','%d')", endtime, steamid, GetArrayCell(adt_array[i], 14, 0, false), GetArrayCell(adt_array[i], 14, 0, false), GetArrayCell(adt_array[i], 1, 0, false), GetArrayCell(adt_array[i], 8, 0, false), GetArrayCell(adt_array[i], 9, 0, false), GetArrayCell(adt_array[i], 10, 0, false), GetArrayCell(adt_array[i], 19, 0, false), GetArrayCell(adt_array[i], 13, 0, false), GetArrayCell(adt_array[i], 11, 0, false), GetArrayCell(adt_array[i], 12, 0, false), GetArrayCell(adt_array[i], 25, 0, false),  GetArrayCell(adt_array[i], 2, 0, false), GetArrayCell(adt_array[i], 3, 0, false), GetArrayCell(adt_array[i], 4, 0, false), GetArrayCell(adt_array[i], 5, 0, false), GetArrayCell(adt_array[i], 6, 0, false), GetArrayCell(adt_array[i], 7, 0, false));
            if (!(SQL_Query(Connection, query, -1)))
            {
                    SQL_GetError(Connection, error, 1024);
                    PrintToServer("Failed to Insert in dotaplayers (error: %s)", error);
            }
		    i++;
        }
      }
    else
    {
        PrintToServer("Could not connect: %s", error);
    }
    CloseHandle(Connection);
    return 0;
}

public OnPluginStart()
{
    HookEvent("player_team", Joined, EventHookMode:1);
    HookUserMessage(UserMsg:24, MsgHook3, true, MsgPostHook:-1);
    HookEvent("dota_match_done", get_stats, EventHookMode:0);
    adt_log = CreateArray(32, 0);
    new i;
    while (i < 10)
    {
        global_stats[i] = CreateArray(32, 28);
        SetArrayCell(global_stats[i], 0, -1, 0, false);
        i++;
    }
    adt_clients = CreateArray(1, 0);
}

public OnClientConnected(client)
{
    new i;
    while (i < 10)
    {
        if (client == GetArrayCell(global_stats[i], 0, 0, false))
        {
            SetArrayCell(global_stats[i], 17, 0, 0, false);
        }
        i++;
    }
}

public OnClientDisconnect(client)
{
    new float:start_time = GameRules_GetPropFloat("m_flGameStartTime", 0);
    new float:game_time = GameRules_GetPropFloat("m_fGameTime", 0);
    new float:time = game_time - start_time;
    new i;
    while (i < 10)
    {
        if (client == GetArrayCell(global_stats[i], 0, 0, false))
        {
            SetArrayCell(global_stats[i], 17, RoundToNearest(time), 0, false);
        }
        i++;
    }
}

public Action:Joined(Handle:event, String:name[], bool:dontBroadcast)
{
    new team = GetEventInt(event, "team");
    new user = GetEventInt(event, "userid");
    new client_index = GetClientOfUserId(user);
    new String:steamid[32];
    new String:ip[32];
    if (team == 2 && FindValueInArray(adt_clients, client_index) == -1 && index_g < 5)
    {
        GetClientAuthId(client_index, AuthIdType:2, steamid, 32, true);
        GetClientIP(client_index, ip, 32, true);
        SetArrayString(global_stats[index_g], 20, steamid);
        SetArrayString(global_stats[index_g], 24, ip);
        SetArrayCell(global_stats[index_g], 0, client_index, 0, false);
        SetArrayCell(global_stats[index_g], 17, 0, 0, false);
        SetArrayCell(global_stats[index_g], 27, GetSteamAccountID(client_index, true), 0, false);
        index_g = index_g + 1;
        PushArrayCell(adt_clients, client_index);
    }

    if (team == 3 && FindValueInArray(adt_clients, client_index) == -1 && index_b < 5)
    {
        GetClientAuthId(client_index, AuthIdType:2, steamid, 32, true);
        GetClientIP(client_index, ip, 32, true);
        SetArrayString(global_stats[index_b + 5], 20, steamid);
        SetArrayString(global_stats[index_b + 5], 24, ip);
        SetArrayCell(global_stats[index_b + 5], 0, client_index, 0, false);
        SetArrayCell(global_stats[index_b + 5], 17, 0, 0, false);
        SetArrayCell(global_stats[index_b + 5], 27, GetSteamAccountID(client_index, true), 0, false);
        index_b = index_b + 1;
        PushArrayCell(adt_clients, client_index);
    }
    return Action:0;
}

public Action:Command_Say(client, String:command[], args)
{
    return Action:0;
}

public Action:get_stats(Handle:event, String:name[], bool:dontBroadcast)
{
    new pr = GetPlayerResourceEntity();
    new spec = FindEntityByClassname(-1, "dota_data_spectator");
    new radiant = FindEntityByClassname(-1, "dota_data_radiant");
    new dire = FindEntityByClassname(-1, "dota_data_dire");
    new radiant_gold[10];
    new dire_gold[10];
    new hero_ids[10];
    new hero_ent[10];
    new team[10];
    new level[10];
    new kills[10];
    new assists[10];
    new deaths[10];
    new last_hits[10];
    new denies[10];
    new towerk[10];
    new roshank[10];
    new networth[10];
    new hhealing[10];
    new accounts[10];
    new id_offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
    new i;
    while (i < 10)
    {
        hero_ids[i] = GetEntProp(pr, PropType:0, "m_nSelectedHeroID", 4, i);
        hero_ent[i] = GetEntPropEnt(pr, PropType:0, "m_hSelectedHero", i);
        team[i] = GetEntProp(pr, PropType:0, "m_iPlayerTeams", 4, i);
        level[i] = GetEntProp(pr, PropType:0, "m_iLevel", 4, i);
        kills[i] = GetEntProp(pr, PropType:0, "m_iKills", 4, i);
        assists[i] = GetEntProp(pr, PropType:0, "m_iAssists", 4, i);
        deaths[i] = GetEntProp(pr, PropType:0, "m_iDeaths", 4, i);
        last_hits[i] = GetEntProp(pr, PropType:0, "m_iLastHitCount", 4, i);
        denies[i] = GetEntProp(pr, PropType:0, "m_iDenyCount", 4, i);
        towerk[i] = GetEntProp(pr, PropType:0, "m_iTowerKills", 4, i);
        roshank[i] = GetEntProp(pr, PropType:0, "m_iRoshanKills", 4, i);
        networth[i] = GetEntProp(spec, PropType:0, "m_iNetWorth", 4, i);
        hhealing[i] = GetEntPropFloat(pr, PropType:0, "m_fHealing", i);
        accounts[i] = GetEntData(pr, i * 8 + id_offset, 4);
        radiant_gold[i] = GetEntProp(radiant, PropType:0, "m_iUnreliableGold", 4, i) + GetEntProp(radiant, PropType:0, "m_iReliableGold", 4, i);
        dire_gold[i] = GetEntProp(dire, PropType:0, "m_iUnreliableGold", 4, i) + GetEntProp(dire, PropType:0, "m_iReliableGold", 4, i);
        i++;
    }
    new j;
    new winner = GameRules_GetProp("m_nGameWinner", 4, 0);
    new result
    while (j < 10)
    {
        if (team[j] == 2)
        {
        	 if(winner == 2)
                {
                	result = 1;
               	}
             else
               	{
               		result = -1;
               	}
            SetArrayCell(global_stats[count_g], 1, hero_ids[j], 0, false);
            SetArrayCell(global_stats[count_g], 8, kills[j], 0, false);
            SetArrayCell(global_stats[count_g], 9, deaths[j], 0, false);
            SetArrayCell(global_stats[count_g], 10, assists[j], 0, false);
            SetArrayCell(global_stats[count_g], 11, last_hits[j], 0, false);
            SetArrayCell(global_stats[count_g], 12, denies[j], 0, false);
            SetArrayCell(global_stats[count_g], 13, level[j], 0, false);
            SetArrayCell(global_stats[count_g], 14, team[j], 0, false);
            SetArrayCell(global_stats[count_g], 15, towerk[j], 0, false);
            SetArrayCell(global_stats[count_g], 16, roshank[j], 0, false);
            SetArrayCell(global_stats[count_g], 18, radiant_gold[j], 0, false);
            SetArrayCell(global_stats[count_g], 19, networth[j], 0, false);
            SetArrayCell(global_stats[count_g], 21, hero_ent[j], 0, false);
            SetArrayCell(global_stats[count_g], 23, result, 0, false);
			SetArrayCell(global_stats[count_g], 25, RoundToNearest(hhealing[j]), 0, false);
            SetArrayCell(global_stats[count_g], 26, accounts[j], 0, false);
            count_g = count_g + 1;
        }
        if (team[j] == 3)
        {
        	if(winner == 3)
             {
                	result = 1;
             }
             else
             {
               		result = -1;
             }
            SetArrayCell(global_stats[count_b], 1, hero_ids[j], 0, false);
            SetArrayCell(global_stats[count_b], 8, kills[j], 0, false);
            SetArrayCell(global_stats[count_b], 9, deaths[j], 0, false);
            SetArrayCell(global_stats[count_b], 10, assists[j], 0, false);
            SetArrayCell(global_stats[count_b], 11, last_hits[j], 0, false);
            SetArrayCell(global_stats[count_b], 12, denies[j], 0, false);
            SetArrayCell(global_stats[count_b], 13, level[j], 0, false);
            SetArrayCell(global_stats[count_b], 14, team[j], 0, false);
            SetArrayCell(global_stats[count_b], 15, towerk[j], 0, false);
            SetArrayCell(global_stats[count_b], 16, roshank[j], 0, false);
            SetArrayCell(global_stats[count_b], 18, dire_gold[j], 0, false);
            SetArrayCell(global_stats[count_b], 19, networth[j], 0, false);
            SetArrayCell(global_stats[count_b], 21, hero_ent[j], 0, false);
            SetArrayCell(global_stats[count_g], 23, result, 0, false);
            SetArrayCell(global_stats[count_b], 25, RoundToNearest(hhealing[j]), 0, false);
            SetArrayCell(global_stats[count_b], 26, accounts[j], 0, false);
            count_b = count_b + 1;
        }
        j++;
    }
    new float:end_time = GameRules_GetPropFloat("m_flGameEndTime", 0);
    new float:start_time = GameRules_GetPropFloat("m_flGameStartTime", 0);
    new duration = RoundToNearest(end_time - start_time);
    new String:endtime[45];
	FloatToString(end_time,endtime,45);
    Insert_Players(SQLcon, global_stats, endtime);
    return Action:0;
}

public Action:MsgHook3(UserMsg:msg_id, Handle:bf, players[], playersNum, bool:reliable, bool:init)
{
    if (GameRules_GetProp("m_nGameState", 4, 0) > 5)
    {
        if (indicator && indicator == 1)
        {
            new String:buffer[32];
            PbReadString(bf, "param", buffer, 32, 0);
            PushArrayString(adt_log, buffer);
            if (GetHeroIdByLogName(buffer))
            {
            }
            else
            {
                indicator = indicator + 1;
            }
        }
    }
    return Action:0;
}
