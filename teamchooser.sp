#include <sourcemod>
#include <sdktools>

public void OnPluginStart()
{
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

public void OnClientPutInServer(client)
{
    if(GameRules_GetProp("m_nGameState", 4, 0) != 1)
        return;

	CreateTimer(1.0, TimerCallBack, client);
}	

public Action:TimerCallBack(Handle:timer, any:client)
{
	PrintToChat(client, "Join team chat commands: | '-r' (Radiant) | '-d' (Dire)");
}

public Action:Command_Say(int client, const String:command[], int args)
{
	decl String:sayString[32];
	
	GetCmdArg(1, sayString, sizeof(sayString));
	GetCmdArgString(sayString, sizeof(sayString));
	
	StripQuotes(sayString);
	
	if(!strcmp(sayString, "-r", false))
		FakeClientCommand(client, "jointeam good");
    else if(!strcmp(sayString, "-d", false))
		FakeClientCommand(client, "jointeam bad");
    
    return Plugin_Continue;
}
