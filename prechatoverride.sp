#include <sdktools>
#include <json>

bool pluginEnabled;

char playerColors[11];
void InitializePlayerColors()
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

    // Default color
    playerColors[10] = '';
}

public OnPluginStart()
{
    pluginEnabled = true;

    InitializePlayerColors();
}

public OnMapStart()
{
    HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
}

public Action:OnGameStateChange(Handle:event, String:name[], bool:dontBroadcast)
{
    //If we are in the connection state
    pluginEnabled = GameRules_GetProp("m_nGameState", 4, 0) == 1;
    
    return Plugin_Continue;
}

public Action:OnClientSayCommand(int client, const String:command[], const String:sArgs[])
{
    if(!pluginEnabled || IsFakeClient(client))
        return Plugin_Continue;
    
    int teamID = GetClientTeam(client);
    
    //They're already assigned to Radiant/Dire
    if(teamID > 0)
        return Plugin_Continue;
        
    char plainUsername[MAX_NAME_LENGTH];
    GetClientName(client, plainUsername, MAX_NAME_LENGTH);
    
    char coloredUsername[MAX_NAME_LENGTH + 2];
    ColorUsername(plainUsername, coloredUsername, MAX_NAME_LENGTH + 2, client);
    
    if (StrEqual(command, "say_team"))
        SayAll(client, coloredUsername, sArgs);
        //SayTeam(client, teamID, coloredUsername, sArgs);
    else
        SayAll(client, coloredUsername, sArgs);
    
    return Plugin_Handled;
}

void SayTeam(int sayerClientId, int teamID, char[] username, const char[] text)
{
    for (int i = 1; i < 32; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;
        
        int pTeamID = GetClientTeam(i);
        
        if(pTeamID != teamID)
            continue;
        
        PrintToChat(i, "[ALLIES] %s: %s", username, text);
    }
}

void SayAll(int client, char[] username, const char[] text)
{
    for (int i = 1; i < 32; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;
        
        PrintToChat(i, "%s: %s", username, text);
    }
}

// maxLength should be username.Length + 2 to place the two formatting characters
void ColorUsername(char[] username, char[] output_buffer, int maxLength, int client)
{
    int colorID = client;
    if(colorID > 10)
        colorID = client % 10;

    if(colorID == 10)
        colorID--;
    
    int teamID = GetClientTeam(client);
    
    char playerColor = playerColors[colorID];
    Format(output_buffer, maxLength, "%s%s", playerColor, username);
}
