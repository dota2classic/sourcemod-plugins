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

//1 DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD
//2 DOTA_GAMERULES_STATE_HERO_SELECTION
//3 'DOTA_GAMERULES_STATE_STRATEGY_TIME //skipped?
//4  DOTA_GAMERULES_STATE_PRE_GAME
//5 DOTA_GAMERULES_STATE_GAME_IN_PROGRESS
//
//7 Failed


//   DOTA_CONNECTION_STATE_UNKNOWN = 0,
//   DOTA_CONNECTION_STATE_NOT_YET_CONNECTED = 1,
//   DOTA_CONNECTION_STATE_CONNECTED = 2,
//   DOTA_CONNECTION_STATE_DISCONNECTED = 3,
//   DOTA_CONNECTION_STATE_ABANDONED = 4,
//   DOTA_CONNECTION_STATE_LOADING = 5,
//   DOTA_CONNECTION_STATE_FAILED = 6,

bool pluginEnabled = true;

int instanceID;

//Http Endpoints
char ENDPOINT_PREFIX_INSTANCE[] = "Instance/";
char ENDPOINT_SUFFIX_MATCH_COMPLETE[] = "Complete";
char ENDPOINT_SUFFIX_MATCH_FAILED[] = "Failed";
 
char httpRootAddress[128];

char httpSuffixCompleteAddress[256];
char httpSuffixFailAddress[256];

public int GetWinner()
{
    int winner = GameRules_GetProp("m_nGameWinner", 4, 0);
    return winner - 2;
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

//Initializer
public void OnPluginStart()
{
    char commandLine[4000];                              
    bool isValidCommandLine = GetCommandLine(commandLine, sizeof(commandLine))
    if(isValidCommandLine)
        ServerLogInfo("Command Line: %s", commandLine);
    else
        ServerLogError("Invalid Command Line");

    HookEvent("dota_match_done", OnGameEnd, EventHookMode_Post);
    
    instanceID = GetCommandLineParamInt("-d2c_instanceID", -1);
    
    pluginEnabled = instanceID != -1;
    if(!pluginEnabled)
        return;
    
    //Configure our http endpoints
    GetCommandLineParamSpace("-d2c_host_address", httpRootAddress, sizeof(httpRootAddress), "http://localhost:8080");
    
    //Trim the last forward slash
    if(httpRootAddress[strlen(httpRootAddress) - 1] == '/')
        httpRootAddress[strlen(httpRootAddress) - 1] = '\0';
    
    //We need to add the instance id to the path
    char httpInstanceAddress[256];
    Format(httpInstanceAddress, sizeof(httpInstanceAddress), "%s%i/", ENDPOINT_PREFIX_INSTANCE, instanceID);
    
    Format(httpSuffixCompleteAddress, sizeof(httpSuffixCompleteAddress), "%s%s", httpInstanceAddress, ENDPOINT_SUFFIX_MATCH_COMPLETE);
    Format(httpSuffixFailAddress, sizeof(httpSuffixFailAddress), "%s%s", httpInstanceAddress, ENDPOINT_SUFFIX_MATCH_FAILED);
    
    ServerLogInfo("Root Address: %s - Instance Address: %s", httpRootAddress, httpInstanceAddress);
}

public void OnMapStart()
{
    HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode_Post);
}

//Events
public Action:OnGameStateChange(Handle:event, String:name[], bool:dontBroadcast)
{
    //Todo: What is this for?
    //GameMode 2 is Captains Mode
    //Not sure what this check is for
    if (GetWinner() < 2 && GetGameMode() == 2)
        return Plugin_Continue;

    //GameState 7
    bool playerFailedToLoad = GetGameState() == 7;
    if(!playerFailedToLoad)
        return Plugin_Continue;
    
    ServerLogInfo("Match Failed");
    CreateTimer(5.0, ShutdownServer); //Give it a couple seconds, then stop the server
    MatchFailed();
    
    return Plugin_Continue;
}

public Action:OnGameEnd(Handle:event, String:name[], bool:dontBroadcast)
{
    ServerLogInfo("Match Completed");
    
    ConVar specVar = FindConVar("tv_delay");
    float shutdownDelay = 30.0 + GetConVarFloat(specVar);
    //Server will shutdown automatically after 6 minutes
    //This is because of a comms failure with Valve GC
    if(shutdownDelay > 360.0)
        shutdownDelay = 360.0;
    else if(shutdownDelay < 30.0)
        shutdownDelay = 30.0;
    
    CreateTimer(shutdownDelay, ShutdownServer); //Give it a couple seconds, then stop the server
    
    MatchComplete();
}

public void MatchComplete()
{
    if(!pluginEnabled)
        return;

    HTTPClient httpClient;
    httpClient = new HTTPClient(httpRootAddress);
    
    JSONObject data = new JSONObject();
    
    //Send data
    httpClient.Post(httpSuffixCompleteAddress, data, HttpResponseCallback);
    delete data;
}

//If we failed, this may fail too?
public void MatchFailed()
{
    if(!pluginEnabled)
        return;
    //Todo: Notify GC of failed to connect players
    
    HTTPClient httpClient; 
    httpClient = new HTTPClient(httpRootAddress);

    JSONObject data = new JSONObject();
    
    //Send data
    httpClient.Post(httpSuffixFailAddress, data, HttpResponseCallback);
    
    delete data; 
}

void HttpResponseCallback(HTTPResponse response, any value)
{
    if(response.Status != HTTPStatus_OK)
       ServerLogError("Failed Response %i", response.Status); 
}

public Action:ShutdownServer(Handle:timer)
{
    ServerLogInfo("Sending Shutdown Command");
    ServerCommand("quit");
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
    
    PrintToServer("[Info] [MatchManager] %s", buffer);
}

void ServerLogWarning(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToServer("[Warning] [MatchManager] %s", buffer);
}

void ServerLogError(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToServer("[Error] [MatchManager] %s", buffer);
}
