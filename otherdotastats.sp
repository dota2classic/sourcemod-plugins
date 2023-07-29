public Action:GameEnd(Handle:event, String:name[], bool:dontBroadcast)
{    
    resource = GetPlayerResourceEntity();
    new WinTeam = GetEventInt(event, "winningteam");
    new String:sWinTeam[10];
    if(WinTeam == 2)
    {
        sWinTeam = "Radiant";
    }
    else if(WinTeam == 3)
    {
        sWinTeam = "Dire";
    }
    new String:sqlQuery[255];
    Format(sqlQuery, sizeof(sqlQuery), "UPDATE `D2Matches` SET `WinTeam`='%s' WHERE (`MatchID`='%i')", sWinTeam, D2MatchID)
    new Handle:query = SQL_Query(db, sqlQuery)
    if (query == INVALID_HANDLE)
    {
        new String:error[255]
        SQL_GetError(db, error, sizeof(error))
        PrintToServer("Failed to query (error: %s)", error)
    }
    CloseHandle(query)
    
    for(new i = 0; i < 10; i++)
    {    
        GameEndCont(i, WinTeam);
    }
    ServerCommand("quit")
    //CreateTimer(5.0, killServer);
    return Plugin_Continue;
}

public GameEndCont(i, WinTeam)
{
    new HeroID = GetEntPropEnt(resource, Prop_Send, "m_hSelectedHero", i);
    new ClientID = -1;
    new Kills = 0;
    new Deaths = 0;
    new AssistsCount = 0;
    new WinCnt = 0;
    new LoseCnt = 0;
    new CreepsKilled = 0;
    new CreepsDenied = 0;
    
    for(new j = 1; j < 11; j++)
    {
        new jHeroID = GetEntPropEnt(j, Prop_Send, "m_hAssignedHero");
        if(HeroID == jHeroID)
        {
            ClientID = j;
            Kills = GetEntProp(resource, Prop_Send, "m_iKills", _, i);
            Deaths = GetEntProp(resource, Prop_Send, "m_iDeaths", _, i);
            AssistsCount = GetEntProp(resource, Prop_Send, "m_iAssists", _, i);
            CreepsKilled = GetEntProp(resource, Prop_Send, "m_iLastHitCount", _, i);
            CreepsDenied = GetEntProp(resource, Prop_Send, "m_iDenyCount", _, i);
            if(WinTeam == GetClientTeam(ClientID))
            {
                WinCnt++;
            }
            else
            {
                LoseCnt++;
            }
            break;
        }
    }
    if(ClientID != -1)
    {
        new id = d2playerid[ClientID];
        
        new String:secondSqlQuery[1024];
        Format(secondSqlQuery, sizeof(secondSqlQuery), "INSERT INTO `D2Stats` (`ForumID`, `Kills`, `Deaths`, `Assists`, `MatchesPlayed`, `Wins`, `Loses`, `CreepsKilled`, `CreepsDenied`) VALUES ('%i', '%i', '%i', '%i', '1', '%i', '%i', '%i', '%i') ON DUPLICATE KEY UPDATE Kills = Kills + %i, Deaths = Deaths + %i, Assists = Assists + %i, MatchesPlayed = MatchesPlayed + 1, Wins = Wins + %i, Loses = Loses + %i, CreepsKilled = CreepsKilled + %i, CreepsDenied = CreepsDenied + %i", ForumID[id], Kills, Deaths, AssistsCount, WinCnt, LoseCnt, CreepsKilled, CreepsDenied, Kills, Deaths, AssistsCount, WinCnt, LoseCnt, CreepsKilled, CreepsDenied)
        new Handle:secondQuery = SQL_Query(db, secondSqlQuery)
        if (secondQuery == INVALID_HANDLE)
        {
            new String:error[255]
            SQL_GetError(db, error, sizeof(error))
            PrintToServer("Failed to query (error: %s)", error)
        }
        CloseHandle(secondQuery)
    }