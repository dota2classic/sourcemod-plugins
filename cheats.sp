#include <sourcemod>
#include <sdktools>
#include <sdkhooks> 

bool pluginIsActive;

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

//Init
public void OnPluginStart()
{
    pluginIsActive = FindCommandLineParam("-cheats");

    if (!pluginIsActive)
        return;
    
    RegConsoleCmd("d2c_gold", GiveGold);
    //AddCommandListener(GiveGold, "gold");
    
    //AddCommandListener(GiveGold, "say");
}

Action GiveGold(int client, int args)
{
    if(!pluginIsActive || IsFakeClient(client))
        return Plugin_Continue;
    
    int additionalGold = GetCmdArgInt(1);

    int teamID = GetClientTeam(client);
    int DATA_TEAM;
    if(teamID == 2)
        DATA_TEAM = FindEntityByClassname(-1, "dota_data_radiant");
    else if(teamID == 3)
        DATA_TEAM = FindEntityByClassname(-1, "dota_data_dire");
    else
        return Plugin_Continue;
    
    int steamID32 = GetSteamAccountID(client, true); //Careful, this may fail in some scenarios
    if (steamID32 <= 0)
        return Plugin_Continue;
    
    int playerIndex = GetPlayerIndex(steamID32);
    if (playerIndex == -1)
        return Plugin_Continue;
    
    int unreliableGold = GetEntProp(DATA_TEAM, Prop_Send, "m_iUnreliableGold", _, playerIndex);
    int reliableGold = GetEntProp(DATA_TEAM, Prop_Send, "m_iReliableGold", _, playerIndex);
    
    ServerLogInfo("Giving Gold to Client: %i, Team: %i, playerID: %i, SteamID: %i, Current Gold: %i, Additional Gold: %i", client, teamID, playerIndex, steamID32, unreliableGold + reliableGold, additionalGold);
    unreliableGold += additionalGold;
    
    if(unreliableGold + reliableGold > 99999)
        unreliableGold = 99999 - reliableGold;
    
    SetEntProp(DATA_TEAM, Prop_Send, "m_iUnreliableGold", unreliableGold, _, playerIndex);
    
    return Plugin_Continue;
}

int GetCmdArgInt(int arg)
{
  char sBuffer[32];
  GetCmdArg(arg, sBuffer, sizeof(sBuffer));
  return StringToInt(sBuffer);
}

//Logging
void ServerLogInfo(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    
    PrintToServer("[Info] [Cheats] %s", buffer);
}

void ServerLogWarning(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToServer("[Warning] [Cheats] %s", buffer);
}

void ServerLogError(const char[] format, any...)
{
    char buffer[1024];
    
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToServer("[Error] [Cheats] %s", buffer);
}
