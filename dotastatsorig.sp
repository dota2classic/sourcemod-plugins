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
new count_b = 5;

subSTR(String:str[], inc, fin, _arg3)
{
    new String:result[16];
    new i = inc;
    while (i < fin)
    {
        StrCat(result, fin - inc, str[i]);
        i++;
    }
    return result;
}

Insert_Winner(Handle:Connection, winner, gameid[])
{
    new String:error[256];
    new String:query[256];
    Connection = SQL_DefConnect(error, 255, true);
    if (Connection)
    {
        if (winner == 2)
        {
            Format(query, 255, "INSERT INTO dotagames (id,botid,gameid,winner,min,sec) VALUES (NULL,1,'%s', 1, 0, 0)", gameid);
            if (SQL_Query(Connection, query, -1))
            {
            }
            else
            {
                SQL_GetError(Connection, error, 255);
                PrintToServer("Failed to Insert in dotagames (error: %s)", error);
            }
        }
        Format(query, 255, "INSERT INTO dotagames (id,botid,gameid,winner,min,sec) VALUES (NULL,1,'%s', 2, 0, 0)", gameid);
        if (!(SQL_Query(Connection, query, -1)))
        {
            SQL_GetError(Connection, error, 255);
            PrintToServer("Failed to Insert in dotagames (error: %s)", error);
        }
    }
    else
    {
        PrintToServer("Could not connect: %s", error);
    }
    CloseHandle(Connection);
    return 0;
}

Insert_Game(Handle:Connection, gameid[], gamename[], duration)
{
    new String:error[256];
    new String:query[256];
    Connection = SQL_DefConnect(error, 255, true);
    if (Connection)
    {
        new String:datetime[24];
        FormatTime(datetime, 21, "%Y-%m-%d %H:%M:%S", -1);
        Format(query, 255, "INSERT INTO games ( id, botid, server, datetime, gamename, ownername, duration, gamestate, creatorname,stats, views) VALUES ( %s, 1,'192.168.96.2','%s','%s','DOTA 2', %d, 16, 'DOTA 2', 0, 0 )", gameid, datetime, gamename, duration);
        if (SQL_Query(Connection, query, -1))
        {
        }
        else
        {
            SQL_GetError(Connection, error, 255);
            PrintToServer("Failed to Insert in games (error: %s)", error);
        }
    }
    else
    {
        PrintToServer("Could not connect: %s", error);
    }
    CloseHandle(Connection);
    return 0;
}

Insert_Players(Handle:Connection, Handle:adt_array[], gameid[], duration)
{
    new String:error[1024];
    new String:query[1024];
    Connection = SQL_DefConnect(error, 1024, true);
    if (Connection)
    {
        new good;
        new bad = 6;
        new String:steamid[32];
        new String:ip[32];
        new String:hd[32];
        new i;
        while (i < 10)
        {
            if (GetArrayCell(adt_array[i], 14, 0, false) == 2)
            {
                good++;
                GetArrayString(adt_array[i], 24, ip, 32);
                GetArrayString(adt_array[i], 22, hd, 32);
                if (GetArrayCell(adt_array[i], 17, 0, false))
                {
                    Format(query, 1024, "INSERT INTO gameplayers ( botid,gameid,name,ip,spoofed,gameplayers.left,leftreason,team,colour,spoofedrealm ) VALUES ( 1,'%s','%d','%s',1,'%d','has disconnected',0,%d,'192.168.96.2')", gameid, GetArrayCell(adt_array[i], 26, 0, false), ip, GetArrayCell(adt_array[i], 17, 0, false), good);
                    if (SQL_Query(Connection, query, -1))
                    {
                    }
                    else
                    {
                        SQL_GetError(Connection, error, 1024);
                        PrintToServer("Failed to Insert in gameplayers good (error: %s)", error);
                    }
                }
                else
                {
                    Format(query, 1024, "INSERT INTO gameplayers ( botid,gameid,name,ip,spoofed,gameplayers.left,leftreason,team,colour,spoofedrealm ) VALUES ( 1,'%s','%d','%s',1,'%d','has left the game voluntarily',0,%d,'192.168.96.2')", gameid, GetArrayCell(adt_array[i], 26, 0, false), ip, duration, good);
                    if (!(SQL_Query(Connection, query, -1)))
                    {
                        SQL_GetError(Connection, error, 1024);
                        PrintToServer("Failed to Insert in gameplayers good (error: %s)", error);
                    }
                }
                Format(query, 1024, "INSERT INTO dotaplayers (botid,gameid,colour,kills,deaths,creepkills,creepdenies,assists,gold,neutralkills,hero,newcolour,towerkills,raxkills,courierkills ) VALUES ( 1,'%s','%d','%d','%d','%d','%d','%d','%d','%d','%d','%d','%s','%d','%d' )", gameid, good, GetArrayCell(adt_array[i], 8, 0, false), GetArrayCell(adt_array[i], 9, 0, false), GetArrayCell(adt_array[i], 11, 0, false), GetArrayCell(adt_array[i], 12, 0, false), GetArrayCell(adt_array[i], 10, 0, false), GetArrayCell(adt_array[i], 18, 0, false), GetArrayCell(adt_array[i], 16, 0, false), GetArrayCell(adt_array[i], 1, 0, false), good, hd, GetArrayCell(adt_array[i], 25, 0, false), GetArrayCell(adt_array[i], 15, 0, false));
                if (!(SQL_Query(Connection, query, -1)))
                {
                    SQL_GetError(Connection, error, 1024);
                    PrintToServer("Failed to Insert in dotaplayers good (error: %s)", error);
                }
                Format(query, 1024, "UPDATE dotaplayers SET item1=%d,item2=%d,item3=%d,item4=%d,item5=%d,item6=%d  WHERE gameid=%s AND colour=%d ", GetArrayCell(adt_array[i], 2, 0, false), GetArrayCell(adt_array[i], 3, 0, false), GetArrayCell(adt_array[i], 4, 0, false), GetArrayCell(adt_array[i], 5, 0, false), GetArrayCell(adt_array[i], 6, 0, false), GetArrayCell(adt_array[i], 7, 0, false), gameid, good);
                if (!(SQL_Query(Connection, query, -1)))
                {
                    SQL_GetError(Connection, error, 1024);
                    PrintToServer("Failed to update items in dotaplayers good (error: %s)", error);
                }
            }
            if (GetArrayCell(adt_array[i], 14, 0, false) == 3)
            {
                bad++;
                GetArrayString(adt_array[i], 20, steamid, 32);
                GetArrayString(adt_array[i], 24, ip, 32);
                GetArrayString(adt_array[i], 22, hd, 32);
                if (GetArrayCell(adt_array[i], 17, 0, false))
                {
                    Format(query, 1024, "INSERT INTO gameplayers ( botid,gameid,name,ip,spoofed,gameplayers.left,leftreason,team,colour,spoofedrealm ) VALUES ( 1,'%s','%d','%s',1,'%d','has disconnected',1,%d,'192.168.96.2')", gameid, GetArrayCell(adt_array[i], 26, 0, false), ip, GetArrayCell(adt_array[i], 17, 0, false), bad);
                    if (SQL_Query(Connection, query, -1))
                    {
                    }
                    else
                    {
                        SQL_GetError(Connection, error, 1024);
                        PrintToServer("Failed to Insert in gameplayers bad (error: %s)", error);
                    }
                }
                else
                {
                    Format(query, 1024, "INSERT INTO gameplayers ( botid,gameid,name,ip,spoofed,gameplayers.left,leftreason,team,colour,spoofedrealm ) VALUES ( 1,'%s','%d','%s',1,%d,'has left the game voluntarily',1,%d,'192.168.96.2')", gameid, GetArrayCell(adt_array[i], 26, 0, false), ip, duration, bad);
                    if (!(SQL_Query(Connection, query, -1)))
                    {
                        SQL_GetError(Connection, error, 1024);
                        PrintToServer("Failed to Insert in gameplayers bad (error: %s)", error);
                    }
                }
                Format(query, 1024, "INSERT INTO dotaplayers (botid,gameid,colour,kills,deaths,creepkills,creepdenies,assists,gold,neutralkills,hero,newcolour,towerkills,raxkills,courierkills ) VALUES ( 1,'%s','%d','%d','%d','%d','%d','%d','%d','%d','%d','%d','%s','%d','%d' )", gameid, bad, GetArrayCell(adt_array[i], 8, 0, false), GetArrayCell(adt_array[i], 9, 0, false), GetArrayCell(adt_array[i], 11, 0, false), GetArrayCell(adt_array[i], 12, 0, false), GetArrayCell(adt_array[i], 10, 0, false), GetArrayCell(adt_array[i], 18, 0, false), GetArrayCell(adt_array[i], 16, 0, false), GetArrayCell(adt_array[i], 1, 0, false), bad, hd, GetArrayCell(adt_array[i], 25, 0, false), GetArrayCell(adt_array[i], 15, 0, false));
                if (!(SQL_Query(Connection, query, -1)))
                {
                    SQL_GetError(Connection, error, 1024);
                    PrintToServer("Failed to Insert in dotaplayers bad (error: %s)", error);
                }
                Format(query, 1024, "UPDATE dotaplayers SET item1=%d,item2=%d,item3=%d,item4=%d,item5=%d,item6=%d  WHERE gameid=%s AND colour=%d ", GetArrayCell(adt_array[i], 2, 0, false), GetArrayCell(adt_array[i], 3, 0, false), GetArrayCell(adt_array[i], 4, 0, false), GetArrayCell(adt_array[i], 5, 0, false), GetArrayCell(adt_array[i], 6, 0, false), GetArrayCell(adt_array[i], 7, 0, false), gameid, bad);
                if (!(SQL_Query(Connection, query, -1)))
                {
                    SQL_GetError(Connection, error, 1024);
                    PrintToServer("Failed to update items in dotaplayers bad (error: %s)", error);
                }
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

Insert_Abilities(Handle:Connection, Handle:adt_array[], gameid[])
{
    new String:error[1024];
    new String:query[1024];
    Connection = SQL_DefConnect(error, 1024, true);
    if (Connection)
    {
        new good;
        new bad = 6;
        new String:abilitig[160] = "";
        new String:abilitib[160] = "";
        new String:ability[12];
        new i;
        while (i < 10)
        {
            if (GetArrayCell(adt_array[i], 14, 0, false) == 2)
            {
                good++;
                if (GetArraySize(adt_array[i]) > 28)
                {
                    new f = 28;
                    while (GetArraySize(adt_array[i]) > f)
                    {
                        IntToString(GetArrayCell(adt_array[i], f, 0, false), ability, 10);
                        StrCat(abilitig, 160, ability);
                        StrCat(abilitig, 160, ",");
                        f++;
                    }
                }
                Format(query, 1024, "UPDATE dotaplayers SET abilities='%s' WHERE gameid=%s AND colour=%d ", abilitig, gameid, good);
                if (SQL_Query(Connection, query, -1))
                {
                }
                else
                {
                    SQL_GetError(Connection, error, 1024);
                    PrintToServer("Failed to update abilities in dotaplayers good (error: %s)", error);
                }
            }
            if (GetArrayCell(adt_array[i], 14, 0, false) == 3)
            {
                bad++;
                if (GetArraySize(adt_array[i]) > 28)
                {
                    new f = 28;
                    while (GetArraySize(adt_array[i]) > f)
                    {
                        IntToString(GetArrayCell(adt_array[i], f, 0, false), ability, 10);
                        StrCat(abilitib, 160, ability);
                        StrCat(abilitib, 160, ",");
                        f++;
                    }
                }
                Format(query, 1024, "UPDATE dotaplayers SET abilities='%s' WHERE gameid=%s AND colour=%d ", abilitib, gameid, bad);
                if (SQL_Query(Connection, query, -1))
                {
                }
                else
                {
                    SQL_GetError(Connection, error, 1024);
                    PrintToServer("Failed to update abilities in dotaplayers bad (error: %s)", error);
                }
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
    HookEvent("dota_player_learned_ability", abi_up, EventHookMode:1);
    HookUserMessage(UserMsg:24, MsgHook3, true, MsgPostHook:-1);
    HookEvent("dota_match_done", get_stats, EventHookMode:0);
    adt_log = CreateArray(32, 0);
    new i;
    while (i < 10)
    {
        global_stats[i] = CreateArray(32, 28);
        SetArrayCell(global_stats[i], 0, any:-1, 0, false);
        i++;
    }
    adt_clients = CreateArray(1, 0);
    return 0;
}

public OnClientConnected(client)
{
    new i;
    while (i < 10)
    {
        if (client == GetArrayCell(global_stats[i], 0, 0, false))
        {
            SetArrayCell(global_stats[i], 17, any:0, 0, false);
        }
        i++;
    }
    return 0;
}

public OnClientDisconnect(client)
{
    new start_time = GameRules_GetPropFloat("m_flGameStartTime", 0);
    new game_time = GameRules_GetPropFloat("m_fGameTime", 0);
    new time = game_time - start_time;
    new i;
    while (i < 10)
    {
        if (client == GetArrayCell(global_stats[i], 0, 0, false))
        {
            SetArrayCell(global_stats[i], 17, RoundToNearest(time), 0, false);
        }
        i++;
    }
    return 0;
}

public Action:abi_up(Handle:event, String:name[], bool:dontBroadcast)
{
    new player_id = GetEventInt(event, "player");
    new abi_name[64];
    GetEventString(event, "abilityname", abi_name, 64);
    new i;
    while (i < 10)
    {
        if (player_id == GetArrayCell(global_stats[i], 0, 0, false))
        {
            PushArrayCell(global_stats[i], GetAbilityIdByName(abi_name));
        }
        i++;
    }
    return Action:0;
}

public Action:Joined(Handle:event, String:name[], bool:dontBroadcast)
{
    new team = GetEventInt(event, "team");
    new user = GetEventInt(event, "userid");
    new client_index = GetClientOfUserId(user);
    new String:steamid[32];
    new String:ip[32];
    new var1;
    if (team == 2 && FindValueInArray(adt_clients, client_index) == -1 && index_g < 5)
    {
        GetClientAuthId(client_index, AuthIdType:2, steamid, 32, true);
        GetClientIP(client_index, ip, 32, true);
        steamid[0] = MissingTAG:117;
        SetArrayString(global_stats[index_g], 20, steamid);
        SetArrayString(global_stats[index_g], 24, ip);
        SetArrayCell(global_stats[index_g], 0, client_index, 0, false);
        SetArrayCell(global_stats[index_g], 17, any:0, 0, false);
        SetArrayCell(global_stats[index_g], 27, GetSteamAccountID(client_index, true), 0, false);
        index_g = index_g + 1;
        PushArrayCell(adt_clients, client_index);
    }
    new var2;
    if (team == 3 && FindValueInArray(adt_clients, client_index) == -1 && index_b < 5)
    {
        GetClientAuthId(client_index, AuthIdType:2, steamid, 32, true);
        GetClientIP(client_index, ip, 32, true);
        steamid[0] = MissingTAG:117;
        SetArrayString(global_stats[index_b + 5], 20, steamid);
        SetArrayString(global_stats[index_b + 5], 24, ip);
        SetArrayCell(global_stats[index_b + 5], 0, client_index, 0, false);
        SetArrayCell(global_stats[index_b + 5], 17, any:0, 0, false);
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
    new id_offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs", 0, 0, 0);
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
    while (j < 10)
    {
        if (team[j] == 2)
        {
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
            SetArrayCell(global_stats[count_g], 25, RoundToNearest(hhealing[j]), 0, false);
            SetArrayCell(global_stats[count_g], 26, accounts[j], 0, false);
            count_g = count_g + 1;
        }
        if (team[j] == 3)
        {
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
            SetArrayCell(global_stats[count_b], 25, RoundToNearest(hhealing[j]), 0, false);
            SetArrayCell(global_stats[count_b], 26, accounts[j], 0, false);
            count_b = count_b + 1;
        }
        j++;
    }
    new z;
    while (z < 10)
    {
        if (GetArrayCell(global_stats[z], 14, 0, false) == 2)
        {
            new var1;
            if (GetArrayCell(global_stats[z], 0, 0, false) > 0 || GetArrayCell(global_stats[z], 0, 0, false) < 33)
            {
                new heroEnt = GetArrayCell(global_stats[z], 21, 0, false);
                new j;
                while (j < 6)
                {
                    new item = GetEntPropEnt(heroEnt, PropType:0, "m_hItems", j);
                    if (!IsValidEntity(item))
                    {
                        SetArrayCell(global_stats[z], j + 2, any:0, 0, false);
                    }
                    else
                    {
                        new itemname[64];
                        GetEdictClassname(item, itemname, 64);
                        SetArrayCell(global_stats[z], j + 2, GetItemIdByName(itemname), 0, false);
                    }
                    j++;
                }
            }
        }
        if (GetArrayCell(global_stats[z], 14, 0, false) == 3)
        {
            new var2;
            if (GetArrayCell(global_stats[z], 0, 0, false) > 0 || GetArrayCell(global_stats[z], 0, 0, false) < 33)
            {
                new heroEnt = GetArrayCell(global_stats[z], 21, 0, false);
                new j;
                while (j < 6)
                {
                    new item = GetEntPropEnt(heroEnt, PropType:0, "m_hItems", j);
                    if (!IsValidEntity(item))
                    {
                        SetArrayCell(global_stats[z], j + 2, any:0, 0, false);
                    }
                    else
                    {
                        new itemname[64];
                        GetEdictClassname(item, itemname, 64);
                        SetArrayCell(global_stats[z], j + 2, GetItemIdByName(itemname), 0, false);
                    }
                    j++;
                }
            }
        }
        z++;
    }
    CombatLogParser();
    new String:hostn[28];
    new String:gameid[16];
    new winner = GameRules_GetProp("m_nGameWinner", 4, 0);
    new Handle:DHhostname = FindConVar("hostname");
    GetConVarString(DHhostname, hostn, 25);
    new fin = FindCharInString(hostn, 95, false);
    subSTR(hostn, -1, fin);
    Insert_Winner(SQLcon, winner, gameid);
    new end_time = GameRules_GetPropFloat("m_flGameEndTime", 0);
    new start_time = GameRules_GetPropFloat("m_flGameStartTime", 0);
    new duration = RoundToNearest(end_time - start_time);
    new String:gamen[28];
    new String:gamename[28];
    subSTR(hostn, FindCharInString(hostn, 95, false) + 1, strlen(hostn) + 1);
    ReplaceString(gamen, 25, "_", " ", true);
    Format(gamename, 25, "%s %dvs%d #%s", gamen, index_g, index_b, gameid);
    Insert_Game(SQLcon, gameid, gamename, duration);
    Insert_Players(SQLcon, global_stats, gameid, duration);
    Insert_Abilities(SQLcon, global_stats, gameid);
    new String:log[100];
    Format(log, 100, "pluginlog/%s.txt", hostn);
    new Handle:file = OpenFile(log, "w");
    new i;
    while (i < 10)
    {
        WriteFileLine(file, "global_stats[%d]", i);
        WriteFileLine(file, "[Clientindex]: %d", GetArrayCell(global_stats[i], 0, 0, false));
        WriteFileLine(file, "[heroid]: %d", GetArrayCell(global_stats[i], 1, 0, false));
        WriteFileLine(file, "[item1]: %d", GetArrayCell(global_stats[i], 2, 0, false));
        WriteFileLine(file, "[item2]: %d", GetArrayCell(global_stats[i], 3, 0, false));
        WriteFileLine(file, "[item3]: %d", GetArrayCell(global_stats[i], 4, 0, false));
        WriteFileLine(file, "[item4]: %d", GetArrayCell(global_stats[i], 5, 0, false));
        WriteFileLine(file, "[item5]: %d", GetArrayCell(global_stats[i], 6, 0, false));
        WriteFileLine(file, "[item6]: %d", GetArrayCell(global_stats[i], 7, 0, false));
        WriteFileLine(file, "[kills]: %d", GetArrayCell(global_stats[i], 8, 0, false));
        WriteFileLine(file, "[deaths]: %d", GetArrayCell(global_stats[i], 9, 0, false));
        WriteFileLine(file, "[assists]: %d", GetArrayCell(global_stats[i], 10, 0, false));
        WriteFileLine(file, "[last hits]: %d", GetArrayCell(global_stats[i], 11, 0, false));
        WriteFileLine(file, "[denies]: %d", GetArrayCell(global_stats[i], 12, 0, false));
        WriteFileLine(file, "[level]: %d", GetArrayCell(global_stats[i], 13, 0, false));
        WriteFileLine(file, "[team]: %d", GetArrayCell(global_stats[i], 14, 0, false));
        WriteFileLine(file, "[towerkill]: %d", GetArrayCell(global_stats[i], 15, 0, false));
        WriteFileLine(file, "[roshankill]: %d", GetArrayCell(global_stats[i], 16, 0, false));
        WriteFileLine(file, "[last seen]: %d", GetArrayCell(global_stats[i], 17, 0, false));
        WriteFileLine(file, "[gold]: %d", GetArrayCell(global_stats[i], 18, 0, false));
        WriteFileLine(file, "[networth]: %d", GetArrayCell(global_stats[i], 19, 0, false));
        new String:str[32];
        GetArrayString(global_stats[i], 20, str, 32);
        WriteFileLine(file, "[SteamId]: %s", str);
        WriteFileLine(file, "[hero entity]: %d", GetArrayCell(global_stats[i], 21, 0, false));
        GetArrayString(global_stats[i], 22, str, 32);
        WriteFileLine(file, "[hero damage]: %s", str);
        GetArrayString(global_stats[i], 24, str, 32);
        WriteFileLine(file, "[player ip]: %s", str);
        WriteFileLine(file, "[hero healing]: %f", GetArrayCell(global_stats[i], 25, 0, false));
        WriteFileLine(file, "[account]: %d", GetArrayCell(global_stats[i], 26, 0, false));
        WriteFileLine(file, "[client account]: %d", GetArrayCell(global_stats[i], 27, 0, false));
        if (GetArraySize(global_stats[i]) > 28)
        {
            new f = 28;
            while (GetArraySize(global_stats[i]) > f)
            {
                WriteFileLine(file, "[Ability%d]: %d", f + -27, GetArrayCell(global_stats[i], f, 0, false));
                f++;
            }
        }
        WriteFileLine(file, "\n\n");
        i++;
    }
    CloseHandle(file);
    return Action:0;
}

public Action:MsgHook3(UserMsg:msg_id, Handle:bf, players[], playersNum, bool:reliable, bool:init)
{
    if (GameRules_GetProp("m_nGameState", 4, 0) > 5)
    {
        new var1;
        if (indicator && indicator == 1)
        {
            new buffer[32];
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

public CombatLogParser()
{
    new i;
    while (GetArraySize(adt_log) > i)
    {
        new String:current_log[32];
        GetArrayString(adt_log, i, current_log, 32);
        new var1;
        if (GetHeroIdByLogName(current_log) != -1 && GetHeroIdByLogName(current_log))
        {
            new j;
            while (j < 10)
            {
                if (GetArrayCell(global_stats[j], 1, 0, false) == GetHeroIdByLogName(current_log))
                {
                    new String:bufferino[32];
                    GetArrayString(adt_log, i + 1, bufferino, 32);
                    new String:total_damage[16];
                    subSTR(bufferino, FindCharInString(bufferino, 58, false) + 2, strlen(bufferino));
                    TrimString(total_damage);
                    SetArrayString(global_stats[j], 22, total_damage);
                }
                j++;
            }
        }
        i++;
    }
    return 0;
}