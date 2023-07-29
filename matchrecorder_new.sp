#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <steamworks>
#include <d2c>
#include <json>
#pragma newdecls required


int Steam3To32(char steam3[20])
{
	char parts[3][20];
	
	ExplodeString(steam3, ":", parts, sizeof(parts), sizeof(parts[]));
	
	int lastChar = strlen(parts[2]) - 1;
	
	if (lastChar > -1 && parts[2][lastChar] == ']')
	{
		parts[2][lastChar] = '\0';
	}
	
	return StringToInt(parts[2]);
}


int	 match_id;

JSON_Array	players;
JSON_Object	playerMap;



// Events
// player_connect
public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	// NetworkID
	// UserID
	// Name
	// Address
	char networkID[19];
	event.GetString("networkid", networkID, 19);
	
	PrintToServer("networkid %s", networkID)
	
		// Ignore Bots
	if (StrEqual(networkID, "BOT")) return Plugin_Handled;
	
	int steamID32 = Steam3To32(networkID);
	
	int userID	  = event.GetInt("userid", -1);
	
	PrintToServer("Player is connecting: NetworkID: %s, SteamID32: %i, UserID: %i", networkID, steamID32, userID);
	
	if (userID != -1)
	{
		char key[20];
		IntToString(userID, key, sizeof(key));
		playerMap.SetInt(key, steamID32);
	}
	
	return Plugin_Continue;
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if (IsFakeClient(client))
	return true;
	
	int userID	  = GetClientUserId(client);
	int steamID32 = GetMappedSteam32(userID);
	
	PrintToServer("USERID %d", userID);
	
	if (steamID32 == -1 || GetExpectedTeamForSteamID(steamID32) == -1)
	{
		PrintToServer("OnClientConnect DENIED Client: %i,SteamID32: %i", client, steamID32);
		return false;
	}
	
	PrintToServer("OnClientConnect ACCEPTED Client: %i, SteamID32: %i", client, steamID32);
	
	return true;
}

// player_connect_full
public Action OnPlayerFullyJoined(Handle event, const char[] name, bool dontBroadcast)
{
	int userID = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userID);
	int teamID = GetClientTeam(client);
	
	int steam32 = GetMappedSteam32(userID);
	
	PrintToServer("fully joined %d", userID);
	
	if (IsFakeClient(client))
	return Plugin_Continue;
	
	PrintToServer("OnPlayerFullyJoined ClientID: %i, UserID: %i", client, userID);
	
	if (IsClientInGame(client) && teamID < 2)
	{
		PrintToServer("Should assign to team now");
		
		int team = GetExpectedTeamForSteamID(steam32);
		if(team != -1){
			ChangeClientTeam(client, team);
		} else {
			KickClient(client, "Вы не участник игры");
		}
	}
	
	return Plugin_Continue;
}

public Action Command_jointeam(int client, const char[] command, int args)
{
	return Plugin_Handled;
}

public void OnPluginStart()
{
	playerMap = new JSON_Object();
	HookEvent("dota_match_done", OnMatchFinish, EventHookMode_Pre);
	
	AddCommandListener(Command_jointeam, "jointeam");
	
	LoadMatchInfo();
	
	// This hook is called very early
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);
	
	// The player joined the server fully
	HookEvent("player_connect_full", OnPlayerFullyJoined, EventHookMode_Post);
}

public void LoadMatchInfo()
{
	JSON_Object hObj = LoadMatchConfigJSON();
	
	match_id			 = hObj.GetInt("matchId");
	
	PrintToServer("Match ID: %d", match_id);
	
	players = view_as<JSON_Array>(hObj.GetObject("players"));
	SetPlayersToStart(players.Length);
}

public Action Command_Test(int args)
{
	PrintToServer("%d", match_id);
	return Plugin_Handled;
}

public Action OnMatchFinish(Handle event, char[] name, bool dontBroadcast)
{
	OnMatchFinished(true);
}

public void OnMatchFinished(bool shutdown)
{
	if (shutdown)
	{
		CreateTimer(60.0, Shutdown);
		PrintToChatAll("Сервер отключится через минуту");
	}
}

public Action Shutdown(Handle timer)
{
	ServerCommand("exit");
}

public void OnMapStart()
{
	PopulatePlayerDataInPlayerResource();
}

public void PopulatePlayerDataInPlayerResource()
{
	int pr			= GetPlayerResourceEntity();
	int id_offset	= FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
	int team_offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerTeams");
	int name_offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iszPlayerNames");
	
	PrintToServer("%d %d %d %d", pr, id_offset, team_offset, name_offset);
	int	 radiantIndex = 0;
	int	 direIndex	  = 5;
	
	char name[MAX_NAME_LENGTH];
	
	for (int i = 0; i < players.Length; i++)
	{
		GetAssignedPlayerName(i, name, sizeof(name));
		
		int teamID = GetAssignedPlayerTeamID(i);
		
		// Are we Radiant?
		if (teamID == 2 && radiantIndex < 5)
		{
			AssignPlayerSlot(pr, id_offset, team_offset, name_offset, radiantIndex, GetAssignedPlayerSteamID(i), teamID, name);
			radiantIndex++;
		}
		else if (teamID == 3 && direIndex < 10)	   // Or Dire
		{
			AssignPlayerSlot(pr, id_offset, team_offset, name_offset, direIndex, GetAssignedPlayerSteamID(i), teamID, name);
			direIndex++;
		}
	}
}

public void AssignPlayerSlot(int pr, int steamIdOffset, int teamOffset, int nameOffset, int playerIndex, int steam32, int team, char name[32])
{
	// Set Steam ID for 64 bit
	// 17825793 magic number to complete SteamID64
	SetEntData(pr, (playerIndex * 8) + steamIdOffset, steam32, 4, true);
	SetEntData(pr, (playerIndex * 8) + steamIdOffset + 4, 17825793, 4, true);
	
	// Set Team
	SetEntData(pr, playerIndex * 4 + teamOffset, team, 4, true);
	
	// Set Name
	SetEntData(pr, playerIndex * 4 + nameOffset, UTIL_AllocPooledString(name), 4, true);
}


Handle UTIL_AllocPooledString(char value[32])
{
	int m_iName = -1;
	if (m_iName == -1)
	m_iName = FindSendPropInfo("CBaseEntity", "m_iName");
	
	int	   helperEnt = FindEntityByClassname(-1, "*");
	Handle backup	 = GetEntData(helperEnt, m_iName, 4);
	
	DispatchKeyValue(helperEnt, "targetname", value);
	
	Handle ret = GetEntData(helperEnt, m_iName, 4);
	
	SetEntData(helperEnt, m_iName, backup, 4);
	
	return ret;
}

// Gets
public int GetAssignedPlayerSteamID(int playerIndex)
{
	return players.GetObject(playerIndex).GetInt("steam32id");
}

public int GetAssignedPlayerTeamID(int playerIndex)
{
	int teamID = players.GetObject(playerIndex).GetInt("team");
	return teamID;
}

public void GetAssignedPlayerName(int playerIndex, char nameRef[32], int size)
{
	players.GetObject(playerIndex).GetString("name", nameRef, size);
}

public int GetExpectedTeamForSteamID(int steam32)
{
	for (int i = 0; i < players.Length; i++)
	{
		int _steam32 = GetAssignedPlayerSteamID(i);
		PrintToServer("Match? %d %d", _steam32, steam32);
		if (_steam32 == steam32)
		{
			return GetAssignedPlayerTeamID(i);
		}
	}
	
	return -1;
}

int GetMappedSteam32(int userID) {
	
	char key[20];
	IntToString(userID, key, sizeof(key));
	return playerMap.GetInt(key, -1);
}