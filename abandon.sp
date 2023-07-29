#include <sdktools>

//Built in variables
//const int DOTA_CONNECTION_STATE_UNKNOWN = 0;
//const int DOTA_CONNECTION_STATE_NOT_YET_CONNECTED = 1;
const int DOTA_CONNECTION_STATE_CONNECTED = 2;
//const int DOTA_CONNECTION_STATE_DISCONNECTED = 3;
const int DOTA_CONNECTION_STATE_ABANDONED = 4;
//const int DOTA_CONNECTION_STATE_LOADING = 5;
//const int DOTA_CONNECTION_STATE_FAILED = 6;

const float TIMER_INTERVAL = 1.0;
const int ABANDON_TIMEOUT = 300; //5 Minutes

const char DEFAULT_COLOR = '';
const char RED_COLOR = '';

bool pluginIsActive = false;

int disconnectTime[10];

char clientNames[10][32]; //Workaround for SourceMod bug https://forums.alliedmods.net/showthread.php?t=327642

Handle FORWARD_ON_ABANDON = INVALID_HANDLE;

char playerColors[10];
void InitPlayerColors()
{
    //Radiant
    playerColors[0] = '';
    playerColors[1] = '';
    playerColors[2] = '';
    playerColors[3] = '';
    playerColors[4] = '';

    //Dire
    playerColors[5] = '';
    playerColors[6] = '';
    playerColors[7] = '';
    playerColors[8] = '';
    playerColors[9] = '';
}

char GetPlayerColor(int playerID)
{
    if(playerID > 9)
        return DEFAULT_COLOR;
    
    return playerColors[playerID];
}

int GetPlayerSteamID(int playerID)
{
    int steamIdOffset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
    
    int resource = GetPlayerResourceEntity();
    
    return GetEntData(resource, playerID * 8 + steamIdOffset, 4);
}

int GetPlayerIndex(int steamID32)
{
    int steamIdOffset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
    
    int resource = GetPlayerResourceEntity();

    int i = 0;
    while (i < 10)
    {
        int id = GetEntData(resource, i * 8 + steamIdOffset, 4);
        if (id == steamID32)
        {
            return i;
        }
        
        i++;
    }
    
    return -1;
}

bool IsPaused()
{
    return GameRules_GetProp("m_bGamePaused");
}

//Init
public void OnPluginStart()
{
    FORWARD_ON_ABANDON = CreateGlobalForward("OnPlayerAbandoned", ET_Ignore, Param_Cell);

    InitPlayerColors();
    
    CreateTimer(5.0, HookGameRulesStateChange);
}

public void OnMapStart()
{
    //Set to -1 so initial increment will print 5 minutes left to reconnect
	for(int i = 0; i < sizeof(disconnectTime); i++)
        disconnectTime[i] = -1;
}

//Events
public Action:HookGameRulesStateChange(Handle:timer)
{
    HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
}

public Action:OnGameStateChange(Handle:event, String:name[], bool:dontBroadcast)
{
    int gameState = GameRules_GetProp("m_nGameState", 4, 0);
    pluginIsActive = gameState > 1 && gameState < 6;
}

public void OnClientDisconnect(int client)
{
    if (!pluginIsActive || IsFakeClient(client))
        return;
    
    int teamId = GetClientTeam(client);
    bool isPlayer = teamId == 2 || teamId == 3;

    if(!isPlayer)
        return;
    
    int steamID32 = GetSteamAccountID(client, true); //Careful, this may fail in some scenarios
    if (steamID32 <= 0)
        return;
        
    int playerIndex = GetPlayerIndex(steamID32);
    if (playerIndex == -1)
        return;
    
    //Cache their username
    GetClientName(client, clientNames[playerIndex], 32);

    CreateTimer(TIMER_INTERVAL, Timer_CountMinutesDisconnected, playerIndex, TIMER_REPEAT);
}


public Action Timer_CountMinutesDisconnected(Handle timer, int playerID)
{
    bool isConnected = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iConnectionState", 4, playerID) == DOTA_CONNECTION_STATE_CONNECTED;
    if (isConnected)
        return Plugin_Stop;

    if (IsPaused())
        return Plugin_Continue;

    //Increment
    disconnectTime[playerID]++;

    ////Game Over
    if (disconnectTime[playerID] >= ABANDON_TIMEOUT)
    {
        AbandonPlayer(playerID);
        return Plugin_Stop;
    }
    
    //Only print once a minute
    if((ABANDON_TIMEOUT - disconnectTime[playerID]) % 60 == 0)
    {
        int minutesRemaining = (ABANDON_TIMEOUT - disconnectTime[playerID]) / 60;
        PrintCenterTextAll("%c%s has %i minutes left to reconnect.", GetPlayerColor(playerID), clientNames[playerID], minutesRemaining);
    }

    return Plugin_Continue;
}

public void AbandonPlayer(int playerID)
{
    int steamID32 = GetPlayerSteamID(playerID);
    
    SetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iConnectionState", DOTA_CONNECTION_STATE_ABANDONED, 4, playerID);
    
    PrintCenterTextAll("%c%s has abandoned the game.", GetPlayerColor(playerID), clientNames[playerID]);
    ServerLogInfo("Player Abandoned: %i, %s", steamID32, clientNames[playerID]);
    
    //Fire event
    ForwardOnAbandon(playerID);
}

public int ForwardOnAbandon(int playerID)
{
    int result = false;
    
    Call_StartForward(FORWARD_ON_ABANDON);
    Call_PushCell(playerID);
    Call_Finish(result);
    
    return result;
}

//Logging
void ServerLogInfo(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    
    PrintToServer("[Info] [Abandon] %s", buffer);
}

void ServerLogWarning(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToServer("[Warning] [Abandon] %s", buffer);
}

void ServerLogError(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToServer("[Error] [Abandon] %s", buffer);
}
