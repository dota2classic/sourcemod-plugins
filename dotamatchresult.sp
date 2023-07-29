public PlVers:__version =
{
    version = 5,
    filevers = "1.6.3",
    date = "04/26/2015",
    time = "13:16:59"
};

public Extension:__ext_core =
{
    name = "Core",
    file = "core",
    autoload = 0,
    required = 0,
};

public Extension:__ext_sdktools =
{
    name = "SDKTools",
    file = "sdktools.ext",
    autoload = 1,
    required = 1,
};
public Extension:__ext_sdkhooks =
{
    name = "SDKHooks",
    file = "sdkhooks.ext",
    autoload = 1,
    required = 1,
}; 
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ripext>

//Constants
const TEAM_RADIANT = 2;
const TEAM_DIRE = 3;

bool pluginEnabled = true;

int instanceID;

char logFile[256];
char replayFile[256];
char dateTime[24];

float xpmLvl25Timestamp[10];

bool playerAbandonStatus[10];

//Http Endpoints
char ENDPOINT_PREFIX_INSTANCE[] = "Instance/";
char ENDPOINT_SUFFIX_SUBMIT_STATS[] = "SubmitStats";
 
char httpRootAddress[128];
char httpSuffixSubmitAddress[256];

//Getters and Setters
public bool GetWinner()
{
    int winner = GameRules_GetProp("m_nGameWinner", 4, 0);
    return winner == 3;
}

public int GetGameMode()
{
    int gameMode = GameRules_GetProp("m_iGameMode", 4, 0);
    return gameMode;
}

public int GetGameState()
{
    int gameState = GameRules_GetProp("m_nGameState", 4, 0);
    return gameState;
}

public float GetPostGameTime()
{
    float startTime = GameRules_GetPropFloat("m_flGameStartTime", 0);
    float gameTime = GameRules_GetPropFloat("m_fGameTime", 0) - startTime;
    if(gameTime < 0.0)
        gameTime = 0.0;
    return gameTime - 90.0;
}

public float GetGameEndTime()
{
    //Used to offset endtime
    float startTime = GameRules_GetPropFloat("m_flGameStartTime", 0);
    float endTime = GameRules_GetPropFloat("m_flGameEndTime", 0) - startTime;
    
    if(endTime < 0.0)
        endTime = 0.0;
    return endTime;
}

public int GetPlayerIndex(int steamID32)
{
    int DATA_PR = GetPlayerResourceEntity();
    int DATA_PR_STEAMID_OFFSET = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
    
    int offset;
    for(int i = 0; i < 10; i++)
    {
        offset = DATA_PR_STEAMID_OFFSET + (8 * i);
        steamID32 = GetEntData(DATA_PR, offset);
        //int rb = GetEntData(DATA_PR, offset + 4);
        
        if(steamID32 == GetEntData(DATA_PR, offset))
            return i;
    }
    
    return -1;
}

//Initializer
public void OnPluginStart()
{ 
    pluginEnabled = FindCommandLineParam("-d2c_record_stats");
    
    if(!pluginEnabled)
        return;
    
    //Initialize DateTime
    FormatTime(dateTime, 21, "%Y-%m-%d_%H%M%S", -1);
    
    instanceID = GetCommandLineParamInt("-d2c_instanceID", -1);
    
    //Configure our http endpoints
    GetCommandLineParamSpace("-d2c_host_address", httpRootAddress, sizeof(httpRootAddress), "http://localhost:8080");
    
    //Trim the last forward slash
    if(httpRootAddress[strlen(httpRootAddress) - 1] == '/')
        httpRootAddress[strlen(httpRootAddress) - 1] = '\0';
    
    //We need to add the instance id to the path
    Format(httpSuffixSubmitAddress, sizeof(httpSuffixSubmitAddress), "%s%i/%s", ENDPOINT_PREFIX_INSTANCE, instanceID, ENDPOINT_SUFFIX_SUBMIT_STATS);
    
    ServerLogInfo("Root Address: %s - Submit Address: %s", httpRootAddress, httpSuffixSubmitAddress);
    
    HookEvent("dota_match_done", OnGameEnd, EventHookMode_Post);
    
    HookEvent("dota_player_gained_level", OnHeroLevelUp, EventHookMode_Post);
}

public void OnMapStart()
{
    if(!pluginEnabled)
        return;

    //Logging setup
    RecordLogs();
    
    //Replay Setup
    RecordReplay();
    
    //CDOTAGCServerSystem::MatchSignOut();
}

//Events
public Action:OnHeroLevelUp(Handle:event, String:name[], bool:dontBroadcast)
{
    //player
    //level
    
    //Says PlayerID in the event resource, but that's wrong. Also it's a client id
    int clientID = GetEventInt(event, "player", -1);
    int level = GetEventInt(event, "level", -1);

    if(level < 25)
        return Plugin_Continue;
    
    int steamID32 = GetSteamAccountID(clientID);
    
    if(steamID32 == -1)
    {
        ServerLogWarning("Unable to retrieve SteamID for XP Timestamping - Client: %i, Username: %N", clientID, clientID);
        return Plugin_Continue;
    }
    
    int playerID = GetPlayerIndex(steamID32);
    
    float gameTime = GetPostGameTime(); //m_fGameTime
    
    xpmLvl25Timestamp[playerID] = gameTime;
    
    return Plugin_Continue;
}

//Forward From Abandon Plugin
public void OnPlayerAbandoned(int playerID)
{
    if(playerID < 0 || playerID > 9)
    {
        ServerLogInfo("Unable to set abandon status, PlayerID: %i", playerID);
        return;
    }
    
    playerAbandonStatus[playerID] = true;
}

public Action:OnGameEnd(Handle:event, String:name[], bool:dontBroadcast)
{
    CreateTimer(3.0, OnGameEndDelayed);
}

public Action:OnGameEndDelayed(Handle:timer)
{
    JSONObject data = GetMatchStats();
    data.SetString("ReplayFile", replayFile); 
    data.SetString("LogFile", logFile);

    JSONObject logStats = ParseMatchStatsFromLog();
    data.Set("LogStats", logStats);
    
    SubmitMatchResults(data);
    delete data;
}

//Methods
void RecordLogs()
{ 
    if(!DirExists("logs/"))
    {
        ServerLogInfo("logs/ does not exists - Creating folder");
        CreateDirectory("logs/", 511);
    }
        
    Format(logFile, sizeof(logFile), "logs/console_%i_%s.log", instanceID, dateTime);
    
    if(FindCommandLineParam("+con_logfile"))
        ServerLogWarning("Overriding con_logfile - Please find log file at %s", logFile);
    
    ServerCommand("con_logfile %s", logFile);
}

void RecordReplay()
{ 
    if(!DirExists("replays/"))
    {
        ServerLogInfo("replays/ does not exists - Creating folder");
        CreateDirectory("replays/", 511);
    }

    Format(replayFile, sizeof(replayFile), "match_%d_%s", instanceID, dateTime);
    
    if(FindCommandLineParam("+tv_record"))
        ServerLogWarning("Overriding tv_record - Please find replay file at %s", replayFile);
    
    ServerCommand("tv_record replays/%s", replayFile);
}

public void SubmitMatchResults(JSONObject data)
{
    HTTPClient httpClient;
    httpClient = new HTTPClient(httpRootAddress);
    
    ServerLogInfo("Submitting stats to %s/%s", httpRootAddress, httpSuffixSubmitAddress);
    
    //Send data
    httpClient.Post(httpSuffixSubmitAddress, data, HttpResponseCallback);
}

void HttpResponseCallback(HTTPResponse response, any value)
{
    if(response.Status != HTTPStatus_OK)
       ServerLogError("Failed Response %i", response.Status); 
}

//Parse for Stats
public JSONObject GetMatchStats()
{
    //Data
    JSONObject data = new JSONObject();
    data.SetBool("BotsEnabled", GetConVarBool(FindConVar("dota_start_ai_game")));

    //Manager entities
    //int DATA_GAME = FindEntityByClassname(-1, "dota_gamerules"); //CDOTAGamerulesProxy
    int DATA_PR = GetPlayerResourceEntity(); //dota_player_manager //CDOTA_PlayerResource
    //int DATA_RAD = FindEntityByClassname(-1, "dota_data_radiant"); //DT_DOTA_DataRadiant
    //int DATA_DIRE = FindEntityByClassname(-1, "dota_data_dire"); //CDOTA_DataDire
    int DATA_SPEC = FindEntityByClassname(-1, "dota_data_spectator"); //CDOTA_DataSpectator
    
    int DATA_PR_STEAMID_OFFSET = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
    
    //Game Rules
    float gameTime = GetGameEndTime(); //m_flGameEndTime
    data.SetInt("MatchDuration", RoundToFloor(gameTime));
    
    bool winner = GetWinner(); //m_nGameWinner
    data.SetBool("Winner", winner);
    
    int gameModeID = GetGameMode(); //m_iGameMode
    data.SetInt("GameModeID", gameModeID); 
    
    //Player Resource
    int steamID32; //m_iPlayerSteamIDs
    
    int teamID; //m_iPlayerTeams
    
    int heroID; //m_nSelectedHeroID
    int level; //m_iLevel
    int lastHits; //m_iLastHitCount
    int denies //m_iDenyCount
    int kills; //m_iKills
    int deaths; //m_iDeaths
    int assists; //m_iAssists
    //int heroDamage;
    //int towerDamage
    int totalGold //m_iTotalEarnedGold
    int totalXP; //m_iTotalEarnedXP
    
    float healing; //m_fHealing
    
    bool randomed; //m_bHasRandomed
    bool repicked; //m_bHasRepicked
    
    int heroEnt; //m_hSelectedHero - This is an entity for the players hero data
    
    //Hero Entity
    int item; //m_hItems
    char itemName[64]; //ClassName
    
    //Radiant/Dire Data
    //int un //m_iUnreliableGold
    //int re; //m_iReliableGold
    
    //Spectator Data
    int netWorth; //m_iNetWorth
    
    JSONArray playersStatsList = new JSONArray();
    JSONObject playerStats;
    
    //Get Player Data
    for(int i = 0; i < 10; i++)
    {
        ServerLogInfo("Player Index: %i", i);
        
        //Get SteamID
        int offset = DATA_PR_STEAMID_OFFSET + (8 * i);
        steamID32 = GetEntData(DATA_PR, offset);
        //int rb = GetEntData(DATA_PR, offset + 4);
        if(steamID32 == 0)
            continue;
        
        ServerLogInfo("Gathering Stats for Player: %i, SteamID32: %i", i, steamID32);
        
        teamID = GetEntProp(DATA_PR, Prop_Send, "m_iPlayerTeams", _, i);
        
        heroID = GetEntProp(DATA_PR, Prop_Send, "m_nSelectedHeroID", _, i);
        
        //Prepare to write data
        playerStats = new JSONObject();
        playerStats.SetInt("SteamID32", steamID32);
        playerStats.SetInt("Team", teamID);
        
        //Has Abandoned
        playerStats.SetBool("Abandoned", playerAbandonStatus[i]);
        
        if(heroID == -1)
            continue;
        
        playerStats.SetInt("HeroID", heroID);
        
        randomed = GetEntProp(DATA_PR, Prop_Send, "m_bHasRandomed", _, i);
        playerStats.SetBool("Randomed", randomed);
        
        repicked = GetEntProp(DATA_PR, Prop_Send, "m_bHasRepicked", _, i);
        playerStats.SetBool("Repicked", repicked);
        
        level = GetEntProp(DATA_PR, Prop_Send, "m_iLevel", _, i);
        playerStats.SetInt("Level", level);
        
        lastHits = GetEntProp(DATA_PR, Prop_Send, "m_iLastHitCount", _, i);
        playerStats.SetInt("LastHits", lastHits);
        
        denies = GetEntProp(DATA_PR, Prop_Send, "m_iDenyCount", _, i);
        playerStats.SetInt("Denies", denies);
        
        kills = GetEntProp(DATA_PR, Prop_Send, "m_iKills", _, i);
        playerStats.SetInt("Kills", kills);
        
        deaths = GetEntProp(DATA_PR, Prop_Send, "m_iDeaths", _, i);
        playerStats.SetInt("Deaths", deaths);
        
        assists = GetEntProp(DATA_PR, Prop_Send, "m_iAssists", _, i);
        playerStats.SetInt("Assists", assists);
        
        //Hero and Tower damage -> Look for log file
        
        healing = GetEntPropFloat(DATA_PR, Prop_Send, "m_fHealing", i);
        playerStats.SetInt("Healing", RoundFloat(healing));
        
        totalGold = GetEntProp(DATA_PR, Prop_Send, "m_iTotalEarnedGold", _, i);
        //playerStats.Set("TotalGold", totalGold);
        
        totalXP = GetEntProp(DATA_PR, Prop_Send, "m_iTotalEarnedXP", _, i);
        //playerStats.Set("TotalXP", totalXP);
        
        netWorth = GetEntProp(DATA_SPEC, Prop_Send, "m_iNetWorth", _, i);
        playerStats.SetInt("NetWorth", netWorth);
        
        //Team specific, and unnecessary
        //un = GetEntProp(DATA_RAD, Prop_Send, "m_iUnreliableGold", _, i);
        //re = GetEntProp(DATA_RAD, Prop_Send, "m_iReliableGold", _, i);
    
        //Calculate based on duration
        float gpm = float(totalGold) / (gameTime / 60.0);
        playerStats.SetFloat("GPM", gpm);
        
        //Calculates based on duration, or the moment you became level 25
        float xpm = float(totalXP);
        if(xpmLvl25Timestamp[i] > 0.0)
            xpm = float(totalXP) / (xpmLvl25Timestamp[i] / 60.0);
        else
            xpm = float(totalXP) / (gameTime / 60.0);
        playerStats.SetFloat("XPM", xpm);
    
        //Items
        heroEnt = GetEntPropEnt(DATA_PR, Prop_Send, "m_hSelectedHero", i);
        if(heroEnt == -1)
            continue;
        
        //0
        item = GetEntPropEnt(heroEnt, Prop_Send, "m_hItems", 0);
        
        if(IsValidEntity(item))
            GetEntPropString(item, Prop_Send, "m_iName", itemName, sizeof(itemName));
        else
            itemName = "";
        playerStats.SetString("Item0", itemName);
         
         //1
        item = GetEntPropEnt(heroEnt, Prop_Send, "m_hItems", 1);
        if(IsValidEntity(item))
            GetEntPropString(item, Prop_Send, "m_iName", itemName, sizeof(itemName));
        else
            itemName = "";
        playerStats.SetString("Item1", itemName);
         
         //2
        item = GetEntPropEnt(heroEnt, Prop_Send, "m_hItems", 2);
        if(IsValidEntity(item))
            GetEntPropString(item, Prop_Send, "m_iName", itemName, sizeof(itemName));
        else
            itemName = "";
        playerStats.SetString("Item2", itemName);

        //3
        item = GetEntPropEnt(heroEnt, Prop_Send, "m_hItems", 3);
        if(IsValidEntity(item))
            GetEntPropString(item, Prop_Send, "m_iName", itemName, sizeof(itemName));
        else
            itemName = "";
        playerStats.SetString("Item3", itemName);
        
        //4
        item = GetEntPropEnt(heroEnt, Prop_Send, "m_hItems", 4);
        if(IsValidEntity(item))
            GetEntPropString(item, Prop_Send, "m_iName", itemName, sizeof(itemName));
        else
            itemName = "";
        playerStats.SetString("Item4", itemName);
        
        //5
        item = GetEntPropEnt(heroEnt, Prop_Send, "m_hItems", 5);
        if(IsValidEntity(item))
            GetEntPropString(item, Prop_Send, "m_iName", itemName, sizeof(itemName));
        else
            itemName = "";
        playerStats.SetString("Item5", itemName);
        
        //Todo: Parse for Lone Druide bear inventory
//        if(heroID == 80)
//        {
//            int bearEnt = FindEntityByClassname(-1, "CDOTA_Unit_SpiritBear");
//
//            ServerLogInfo("Hero Entity: %i - Bear Entity %i", heroEnt, bearEnt);
//
//            if(bearEnt != -1)
//            {
//                item = GetEntPropEnt(bearEnt, Prop_Send, "m_hItems", 0);
//                if(IsValidEntity(item))
//                    GetEntPropString(item, Prop_Send, "m_iName", itemName, sizeof(itemName));
//                else
//                    itemName = "";
//                ServerLogInfo("Druid Bear: %s", itemName);
//
//                int ownerEnt = GetEntPropEnt(bearEnt, Prop_Send, "m_hOwnerEntity");
//
//                ServerLogInfo("Bear Entity Owner: %i", ownerEnt);
//
//                //playerStats.SetString("Item0", itemName);
//            }
//        }
        
        //Add the player stats
        playersStatsList.Push(playerStats);
    }
    
    data.Set("PlayerStats", playersStatsList);
    
    return data;
}

public JSONObject ParseMatchStatsFromLog()
{
    ServerLogInfo("Parsing Log: %s", logFile);
    
    new Handle:fileHandle = OpenFile(logFile, "r"); 
    char fileLine[512];
    
    bool readLine = false;
    
    //First locate the start of SIGNOUT results
    while(true)
    {
        readLine = ReadFileLine(fileHandle, fileLine, sizeof(fileLine));
        
        if(!readLine || IsEndOfFile(fileHandle))
            break;
        
        //SIGNOUT: Job created, Protobuf:
        if(StrContains(fileLine, "SIGNOUT: Job created") != -1)
            break;
    }
    
    //Start parsing for player data
    JSONObject results = new JSONObject();
    JSONArray playerResults = new JSONArray();
    
    JSONObject currentPlayer;
    
    JSONObject currentBearItems;
    
    int stringSplitCount;
    char stringSplit[5][32];
    
    while(true)
    {
        readLine = ReadFileLine(fileHandle, fileLine, sizeof(fileLine));
        
        if(!readLine || IsEndOfFile(fileHandle))
            break;
        
        //Check for end of SIGNOUT
        //SIGNOUT: Told to wait by GC for 323 seconds
        if(StrContains(fileLine, "SIGNOUT") != -1)
            break;
        
        //Player Found
        if(StrContains(fileLine, "steam_id") != -1)
        {
            currentPlayer = new JSONObject();
            
            //Split the steamid, get the latter
            //04/25/2023 - 13:49:35:     steam_id: 76561198047236556
            stringSplitCount = ExplodeString(fileLine, ":", stringSplit, sizeof(stringSplit), sizeof(stringSplit[]));
            
            TrimString(stringSplit[stringSplitCount - 1]);
            ServerLogInfo("Extended Log Stats for: SteamID: %s", stringSplit[stringSplitCount - 1]);
            
            currentPlayer.SetString("SteamID", stringSplit[stringSplitCount - 1]);
            
            //Fetch the players damage stats
            while(true)
            {
                readLine = ReadFileLine(fileHandle, fileLine, sizeof(fileLine));
                
                if(!readLine || IsEndOfFile(fileHandle))
                    break;
                
                //We're done with this player, Log his info
                if(StrContains(fileLine, "net_worth") != -1)
                {
                    playerResults.Push(currentPlayer);
                    break;
                }
                
                if(StrContains(fileLine, "hero_damage") != -1)
                {
                    //04/25/2023 - 13:49:35:     hero_damage: 0
                    ExplodeString(fileLine, ":", stringSplit, sizeof(stringSplit), sizeof(stringSplit[]));
                    TrimString(stringSplit[stringSplitCount - 1]);
                    currentPlayer.SetInt("HeroDamage", StringToInt(stringSplit[stringSplitCount - 1]));
                }
                else if(StrContains(fileLine, "tower_damage") != -1)
                {
                    //04/25/2023 - 13:49:35:     tower_damage: 1902
                    ExplodeString(fileLine, ":", stringSplit, sizeof(stringSplit), sizeof(stringSplit[]));
                    TrimString(stringSplit[stringSplitCount - 1]);
                    currentPlayer.SetInt("TowerDamage", StringToInt(stringSplit[stringSplitCount - 1]));
                }
                else if(StrContains(fileLine, "additional_units_inventory") != -1)
                {
                    //Lone Druid (or Rubick) Bear items
                    currentBearItems = new JSONObject();
                    char itemLabel[] = "Item0";
                    int iCount = 48; //Ascii Start
                    while(true)
                    {
                        readLine = ReadFileLine(fileHandle, fileLine, sizeof(fileLine)); //Unit Name
                        
                        if(!readLine || IsEndOfFile(fileHandle))
                            break;
                        
                        if(StrContains(fileLine, "}") != -1)
                            break;
                        
                        if(StrContains(fileLine, "items") == -1)
                            continue;
                        
                        ExplodeString(fileLine, ":", stringSplit, sizeof(stringSplit), sizeof(stringSplit[]));
                        TrimString(stringSplit[stringSplitCount - 1]);
                        currentBearItems.SetInt(itemLabel, StringToInt(stringSplit[stringSplitCount - 1]));
                        
                        //Whoa, hacky
                        iCount++;
                        itemLabel[4] = iCount;
                    }
                    
                    currentPlayer.Set("BearInventory", currentBearItems);
                }
            }
        }
        //Check for Building Status
        else if(StrContains(fileLine, "tower_status") != -1)
        {
            //04/25/2023 - 13:49:35: tower_status: 455
            //04/25/2023 - 13:49:35: tower_status: 2047
            ExplodeString(fileLine, ":", stringSplit, sizeof(stringSplit), sizeof(stringSplit[]));
            TrimString(stringSplit[stringSplitCount - 1]);
            results.SetInt("RadiantTowers", StringToInt(stringSplit[stringSplitCount - 1]));
            
            //Progress to the Dire Stats
            readLine = ReadFileLine(fileHandle, fileLine, sizeof(fileLine));
            if(!readLine || IsEndOfFile(fileHandle))
                break;
            
            ExplodeString(fileLine, ":", stringSplit, sizeof(stringSplit), sizeof(stringSplit[]));
            TrimString(stringSplit[stringSplitCount - 1]);
            results.SetInt("DireTowers", StringToInt(stringSplit[stringSplitCount - 1]));
        }
        else if(StrContains(fileLine, "barracks_status") != -1)
        {
            //04/25/2023 - 13:49:35: barracks_status: 51
            //04/25/2023 - 13:49:35: barracks_status: 63
            ExplodeString(fileLine, ":", stringSplit, sizeof(stringSplit), sizeof(stringSplit[]));
            TrimString(stringSplit[stringSplitCount - 1]);
            results.SetInt("RadiantBarracks", StringToInt(stringSplit[stringSplitCount - 1]));
            
            //Progress to the Dire Stats
            readLine = ReadFileLine(fileHandle, fileLine, sizeof(fileLine));
            if(!readLine || IsEndOfFile(fileHandle))
                break;
                
            ExplodeString(fileLine, ":", stringSplit, sizeof(stringSplit), sizeof(stringSplit[]));
            TrimString(stringSplit[stringSplitCount - 1]);
            results.SetInt("DireBarracks", StringToInt(stringSplit[stringSplitCount - 1]));
            
            break; //No more stats to fetch.
        }
        else if(StrContains(fileLine, "cluster:") != -1) //End it
        {
            //04/25/2023 - 13:49:35: cluster: 0
            break;
        }
    }
    
    CloseHandle(fileHandle);
    ServerLogInfo("Finished Reading log");
    
    results.Set("ExtendedPlayerStats", playerResults);
    
    return results;
}

//Helpers
void GetCommandLineParamSpace(const char[] param, char[] value, int maxlen, const char[] defValue)
{
    if (!FindCommandLineParam(param))
    {
        Format(value, maxlen, "%s", defValue);
        return;
    }         
                         
    char commandLine[4000];                              
    bool isValidCommandLine = GetCommandLine(commandLine, sizeof(commandLine))
    if (!isValidCommandLine)
    {
        Format(value, maxlen, "%s", defValue);
        return;
    }
    
    int i = StrContains(commandLine, param) + strlen(param);
    
    //We're invalid here, probably print a message
    if(i == strlen(commandLine))
    {
        Format(value, maxlen, "%s", defValue);
        return;
    }
    
    //Skip the starting space
    if(commandLine[i] == ' ')
        i++;

    int stringLength = strlen(commandLine);

    for(int j = 0; i < stringLength; i++)
    {
        if(commandLine[i] == '\0' || commandLine[i] == ' ')
            break;

        //Add the command value
        value[j] = commandLine[i];
        j++;
    }
}

//Logging
void ServerLogInfo(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    
    PrintToServer("[Info] [DotaMatchResult] %s", buffer);
}

void ServerLogWarning(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToServer("[Warning] [DotaMatchResult] %s", buffer);
}

void ServerLogError(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToServer("[Error] [DotaMatchResult] %s", buffer);
}
