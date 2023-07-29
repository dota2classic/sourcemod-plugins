#include <sourcemod>
#include <sdktools>

public OnPluginStart()
{
    RegConsoleCmd("roll", Roll);
}

public OnMapStart()
{
    HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
}

public Action:OnGameStateChange(Handle:event, String:name[], bool:dontBroadcast)
{
    if(GameRules_GetProp("m_nGameState", 4, 0) == 2)
    {
        CreateTimer(2.5, PrintInstructionsMsgToAll);
        UnhookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
    }

    return Plugin_Continue;
}

public Action:PrintInstructionsMsgToAll(Handle:timer)
{
    PrintToChatAll("[RNG] Roll (1-100): /roll");
    return Plugin_Continue;
}

public Action Roll(int client, int args)
{
    if(IsFakeClient(client))
        return Plugin_Handled;

    int teamID = GetClientTeam(client);
    
    if(teamID != 2 && teamID != 3)
        return Plugin_Handled;
    
    //RNG
    int rollValue = GetRandomInt(1, 100);
    
    char username[MAX_NAME_LENGTH];
    GetClientName(client, username, MAX_NAME_LENGTH);
    
    for(int i = 1; i < 32; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i) || teamID != GetClientTeam(i))
            continue;
        
        PrintToChat(i, "[RNG] %s rolled a %i", username, rollValue);
    }
    
    PrintToServer("[RNG][%d] %s rolled a %i", teamID, username, rollValue);

    return Plugin_Handled;
}
