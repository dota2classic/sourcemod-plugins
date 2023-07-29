#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <json>

// 1 DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD
// 2 DOTA_GAMERULES_STATE_HERO_SELECTION
// 3 'DOTA_GAMERULES_STATE_STRATEGY_TIME //skipped?
// 4  DOTA_GAMERULES_STATE_PRE_GAME
// 5 DOTA_GAMERULES_STATE_GAME_IN_PROGRESS

//   DOTA_CONNECTION_STATE_UNKNOWN = 0,
//   DOTA_CONNECTION_STATE_NOT_YET_CONNECTED = 1,
//   DOTA_CONNECTION_STATE_CONNECTED = 2,
//   DOTA_CONNECTION_STATE_DISCONNECTED = 3,
//   DOTA_CONNECTION_STATE_ABANDONED = 4,
//   DOTA_CONNECTION_STATE_LOADING = 5,
//   DOTA_CONNECTION_STATE_FAILED = 6,

bool	   pluginIsActive = true;

JSON_Array assignedPlayers;

int		   steamPlayerMap[10][3];
void	   InitializeSteamPlayerMap()
{
	for (int i = 0; i < sizeof(steamPlayerMap); i++)
	{
		steamPlayerMap[i][0] = -1;
		steamPlayerMap[i][1] = -1;
		steamPlayerMap[i][2] = -1;
	}
}

// Gets
public int GetAssignedPlayerSteamID(int playerIndex)
{
	int steamID = assignedPlayers.GetObject(playerIndex).GetInt("SteamID32");
	return steamID;
}

public int GetAssignedPlayerTeamID(int playerIndex)
{
	int teamID = assignedPlayers.GetObject(playerIndex).GetInt("TeamID");
	return teamID;
}

public void GetAssignedPlayerName(int playerIndex, char[] nameRef, int size)
{
	assignedPlayers.GetObject(playerIndex).GetString("Name", nameRef, size);
}

public int GetMappedPlayerSteamID(int userID)
{
	for (int i = 0; i < sizeof(steamPlayerMap); i++)
	{
		if (steamPlayerMap[i][2] == userID)
			return steamPlayerMap[i][0];
	}

	return -1;
}

public int GetMappedPlayerTeamID(int steamID32)
{
	for (int i = 0; i < sizeof(steamPlayerMap); i++)
	{
		if (steamPlayerMap[i][0] == steamID32)
			return steamPlayerMap[i][1];
	}

	return -1;
}

public bool SetMappedPlayerUserID(int steamID32, int userID)
{
	for (int i = 0; i < sizeof(steamPlayerMap); i++)
	{
		if (steamPlayerMap[i][0] != steamID32)
			continue;

		steamPlayerMap[i][2] = userID;
		return true;
	}

	return false;
}

int GetClientTeamToJoin(int client)
{
	// Second param controls if it should return validated SteamID only
	int steamID32  = GetSteamAccountID(client, true);
	int teamToJoin = GetMappedPlayerTeamID(steamID32);

	return teamToJoin;
}

public bool IsClientPlayerAllowed(int client)
{
	return IsSteamPlayerAllowed(GetSteamAccountID(client, true));
}

public bool IsSteamPlayerAllowed(int steamID32)
{
	int teamID = GetMappedPlayerTeamID(steamID32);

	return teamID != -1;
}

// Init
public void OnPluginStart()
{
	pluginIsActive = FindCommandLineParam("-players");

	InitializeSteamPlayerMap();

	if (!pluginIsActive)
		return;

	char playerParam[2048];
	GetCommandLineBase64("-players", playerParam, sizeof(playerParam), "W10=");	   //[] in base64

	char playersStr[2048];
	DecodeBase64(playerParam, playersStr, sizeof(playersStr));
	ServerLogInfo("assignedPlayers: %s", playersStr);

	assignedPlayers = json_decode(playersStr);

	// Turns out, no one was assigned.
	// Manual assignment should take over
	if (assignedPlayers.Length == 0)
	{
		pluginIsActive = false;
		return;
	}

	// Disable jointeam command
	AddCommandListener(DisableJoinTeamCommand, "jointeam");

	// We need to wait for X players to join now
	ServerCommand("dota_wait_for_players_to_load_count %d", ExpectedPlayerCount());

	// Disable the manual team chooser
	ServerCommand("sm plugins unload teamchooser");

	// This hook is called very early
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);

	// The player joined the server fully
	HookEvent("player_connect_full", OnPlayerFullyJoined, EventHookMode : 1);
}

public int ExpectedPlayerCount()
{
	if (assignedPlayers.Length - 10 > 0)
		ServerLogWarning("Players Count > 10 - Count: %i", assignedPlayers.Length);

	int count = 0;
	for (int i = 0; i < assignedPlayers.Length; i++)
	{
		int teamID	  = GetAssignedPlayerTeamID(i);
		int steamID32 = GetAssignedPlayerSteamID(i);

		if (steamID32 <= 0 || teamID < 2)
			continue;

		steamPlayerMap[count][0] = steamID32;
		steamPlayerMap[count][1] = teamID;

		if (++count == 10)
			break;
	}

	return count;
}

public void OnMapStart()
{
	if (!pluginIsActive)
		return;

	PopulatePlayerDataInPlayerResource();
}

public void PopulatePlayerDataInPlayerResource()
{
	new pr			  = GetPlayerResourceEntity();
	int	 id_offset	  = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
	int	 team_offset  = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerTeams");
	int	 name_offset  = FindSendPropInfo("CDOTA_PlayerResource", "m_iszPlayerNames");

	int	 radiantIndex = 0;
	int	 direIndex	  = 5;

	char name[MAX_NAME_LENGTH];

	for (int i = 0; i < assignedPlayers.Length; i++)
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

public AssignPlayerSlot(int pr, int steamIdOffset, int teamOffset, int nameOffset, int playerIndex, int steamID32, int team, char[] name)
{
	// Set Steam ID for 64 bit
	// 17825793 magic number to complete SteamID64
	SetEntData(pr, (playerIndex * 8) + steamIdOffset, steamID32, 4, true);
	SetEntData(pr, (playerIndex * 8) + steamIdOffset + 4, 17825793, 4, true);

	// Set Team
	SetEntData(pr, playerIndex * 4 + teamOffset, team, 4, true);

	// Set Name
	SetEntData(pr, playerIndex * 4 + nameOffset, UTIL_AllocPooledString(name), 4, true);
}

void ClearPlayerSlot(int playerID)
{
	int pr	   = GetPlayerResourceEntity();
	int offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");

	// Steam ID is 64-bit, so need to zero all 8 bytes. Same reason that we can't use SetEntProp here
	SetEntData(pr, (offset * playerID), 0);
	SetEntData(pr, (offset * playerID) + 4, 0);
}

UTIL_AllocPooledString(const String
					   : value[])
{
	static m_iName = -1;
	if (m_iName == -1)
		m_iName = FindSendPropInfo("CBaseEntity", "m_iName");

	new helperEnt = FindEntityByClassname(-1, "*");
	new backup	  = GetEntData(helperEnt, m_iName, 4);

	DispatchKeyValue(helperEnt, "targetname", value);

	new ret = GetEntData(helperEnt, m_iName, 4);

	SetEntData(helperEnt, m_iName, backup, 4);

	return ret;
}

public Action : DisableJoinTeamCommand(client, char[] command, args)
{
	return Plugin_Handled;
}

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

	// Ignore Bots
	if (StrEqual(networkID, "BOT"))
		return Plugin_Handled;

	int steamID32 = Steam3To32(networkID);

	int userID	  = event.GetInt("userid", -1);

	ServerLogInfo("Player is connecting: NetworkID: %s, SteamID32: %i, UserID: %i", networkID, steamID32, userID);

	SetMappedPlayerUserID(steamID32, userID);

	return Plugin_Continue;
}

public bool : OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if (!pluginIsActive || IsFakeClient(client))
		return true;

	int userID	  = GetClientUserId(client);
	int steamID32 = GetMappedPlayerSteamID(userID);

	if (steamID32 == -1 || !IsSteamPlayerAllowed(steamID32))
	{
		ServerLogInfo("OnClientConnect DENIED Client: %i, UserID: %i, SteamID32: %i", client, userID, steamID32);
		return false;
	}

	ServerLogInfo("OnClientConnect ACCEPTED Client: %i, UserID: %i, SteamID32: %i", client, userID, steamID32);

	return true;
}

// Called once a client is authorized and fully in-game, and after all post-connection authorizations have been performed.
// Sometime this doesn't trigger.
public void OnClientPostAdminCheck(client)
{
	if (!pluginIsActive || IsFakeClient(client))
		return;

	// Secondary validation
	// This method is triggered when SteamID is validated
	// So let's make sure you're not spoofing
	int steamID32 = GetSteamAccountID(client, true);

	if (!IsSteamPlayerAllowed(steamID32))
	{
		ServerLogWarning("OnClientPostAdminCheck UNVERIFIED ClientID: %i, SteamID32: %i", client, steamID32);
		KickClient(client);
		return;
	}

	ServerLogWarning("OnClientPostAdminCheck VERIFIED ClientID: %i, SteamID32: %i", client, steamID32);
}

// player_connect_full
public Action OnPlayerFullyJoined(Handle
						   : event, String
						   : name[], bool
						   : dontBroadcast)
{
	int userID = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userID);
	int teamID = GetClientTeam(client);

	if (!pluginIsActive || IsFakeClient(client))
		return Plugin_Continue;

	ServerLogInfo("OnPlayerFullyJoined ClientID: %i, UserID: %i", client, userID);

	if (IsClientInGame(client) && teamID < 2)
		AssignToTeam(client, userID);

	return Plugin_Continue;
}

// Methods
public void AssignToTeam(int client, int userID)
{
	int teamToJoin = GetClientTeamToJoin(client);

	if (teamToJoin == -1)
	{
		int steamID32 = GetMappedPlayerSteamID(userID);
		teamToJoin	  = GetMappedPlayerTeamID(steamID32);

		ServerLogWarning("Retrieved Team -1 for Client %i, UserID %i - Fallback to cached SteamID %i - Found TeamID: %i", client, userID, steamID32, teamToJoin);
	}

	// They're not an assigned player, kick?
	if (teamToJoin == -1)
		return;

	ServerLogInfo("Assigning Client %i, UserID %i, Team %i", client, userID, teamToJoin);

	ChangeClientTeam(client, teamToJoin);
}

public Action ReconnectUser(Handle
					 : timer, any
					 : client)
{
	if (!IsClientInGame(client) || GetClientTeam(client) < 2)
		return;

	ServerLogInfo("Reconnecting client %i", client)
		ClientCommand(client, "disconnect; retry");
}

int Steam3To32(char steam3[20])
{
	char parts[3][20];

	ExplodeString(steam3, ":", parts, sizeof(parts), sizeof(parts[]));

	new lastChar = strlen(parts[2]) - 1;

	if (lastChar > -1 && parts[2][lastChar] == ']')
	{
		parts[2][lastChar] = '\0';
	}

	return StringToInt(parts[2]);
}

void GetCommandLineBase64(const char[] param, char[] buffer, int maxLength, const char[] defValue)
{
	if (!FindCommandLineParam(param))
	{
		Format(buffer, maxLength, "%s", defValue);
		return;
	}

	char commandLine[4096];
	bool isValidCommandLine = GetCommandLine(commandLine, sizeof(commandLine));
	if (!isValidCommandLine)
	{
		Format(buffer, maxLength, "%s", defValue);
		return;
	}

	int i = StrContains(commandLine, param) + strlen(param);
	// We're invalid here, probably print a message
	if (i == strlen(commandLine))
	{
		Format(buffer, maxLength, "%s", defValue);
		return;
	}

	// Skip the starting space
	if (commandLine[i] == ' ')
		i++;

	int stringLength = strlen(commandLine);

	for (int j = 0; i < stringLength && j < maxLength; i++)
	{
		if (commandLine[i] == '\0' || commandLine[i] == ' ')
			break;

		// Add to buffer
		buffer[j] = commandLine[i];
		j++;
	}
}

void GetCommandLineParamJson(const char[] param, char[] value, int maxlen, const char[] defValue)
{
	if (!FindCommandLineParam(param))
	{
		Format(value, maxlen, "%s", defValue);
		return;
	}

	char commandLine[4000];
	bool isValidCommandLine = GetCommandLine(commandLine, sizeof(commandLine));
	if (!isValidCommandLine)
	{
		Format(value, maxlen, "%s", defValue);
		return;
	}

	int i = StrContains(commandLine, param) + strlen(param);

	// We're invalid here, probably print a message
	if (i == strlen(commandLine))
	{
		Format(value, maxlen, "%s", defValue);
		return;
	}

	// Skip the starting space
	if (commandLine[i] == ' ')
		i++;

	int	 openCount	= 0;
	char openSymbol = commandLine[i];
	char closeSymbol;

	if (openSymbol == '[')
		closeSymbol = ']';
	else if (openSymbol == '{')
		closeSymbol = '}';
	else
	{
		openSymbol	= '\0';
		closeSymbol = ' ';
		openCount++;	// Counteract the free space
	}

	int stringLength = strlen(commandLine);

	for (int j = 0; i < stringLength; i++)
	{
		if (commandLine[i] == '\0')
			break;

		if (commandLine[i] == openSymbol)
			openCount++;
		else if (commandLine[i] == closeSymbol)
			openCount--;

		// Add the command value
		value[j] = commandLine[i];
		j++;

		if (openCount == 0)
			break;
	}
}

// https://forums.alliedmods.net/showthread.php?t=101764
//  The decoding table
new const DecodeTable[] = {
	//  0   1   2   3   4   5   6   7   8   9
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   //   0 -   9
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   //  10 -  19
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   //  20 -  29
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   //  30 -  39
	0, 0, 0, 62, 0, 0, 0, 63, 52, 53,		   //  40 -  49
	54, 55, 56, 57, 58, 59, 60, 61, 0, 0,	   //  50 -  59
	0, 0, 0, 0, 0, 0, 1, 2, 3, 4,			   //  60 -  69
	5, 6, 7, 8, 9, 10, 11, 12, 13, 14,		   //  70 -  79
	15, 16, 17, 18, 19, 20, 21, 22, 23, 24,	   //  80 -  89
	25, 0, 0, 0, 0, 0, 0, 26, 27, 28,		   //  90 -  99
	29, 30, 31, 32, 33, 34, 35, 36, 37, 38,	   // 100 - 109
	39, 40, 41, 42, 43, 44, 45, 46, 47, 48,	   // 110 - 119
	49, 50, 51, 0, 0, 0, 0, 0, 0, 0,		   // 120 - 129
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 130 - 139
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 140 - 149
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 150 - 159
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 160 - 169
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 170 - 179
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 180 - 189
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 190 - 199
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 200 - 209
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 210 - 219
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 220 - 229
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 230 - 239
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,			   // 240 - 249
	0, 0, 0, 0, 0, 0						   // 250 - 256
};

void DecodeBase64(const String
				  : sString[], String
				  : sResult[], int len)
{
	int nLength = strlen(sString);	  // The string length to be read from the input
	int resPos;						  // The string position in the result buffer

	// Loop through and generate the Base64 encoded string
	// NOTE: This performs the standard encoding process.  Do not manipulate the logic within this loop.
	for (int nPos = 0; nPos < nLength; nPos++)
	{
		new c, c1;

		c  = DecodeTable[sString[nPos++]];
		c1 = DecodeTable[sString[nPos]];

		c  = (c << 2) | ((c1 >> 4) & 0x3);

		resPos += FormatEx(sResult[resPos], len - resPos, "%c", c);

		if (++nPos < nLength)
		{
			c = sString[nPos];

			if (c == '=')
				break;

			c  = DecodeTable[sString[nPos]];
			c1 = ((c1 << 4) & 0xf0) | ((c >> 2) & 0xf);

			resPos += FormatEx(sResult[resPos], len - resPos, "%c", c1);
		}

		if (++nPos < nLength)
		{
			c1 = sString[nPos];

			if (c1 == '=')
				break;

			c1 = DecodeTable[sString[nPos]];
			c  = ((c << 6) & 0xc0) | c1;

			resPos += FormatEx(sResult[resPos], len - resPos, "%c", c);
		}
	}

	return resPos;
}

void ServerLogInfo(const char[] format, any...)
{
	char buffer[1024];

	VFormat(buffer, sizeof(buffer), format, 2);

	PrintToServer("[Info] [TeamChooserAuto] %s", buffer);
}

void ServerLogWarning(const char[] format, any...)
{
	char buffer[1024];

	VFormat(buffer, sizeof(buffer), format, 2);
	PrintToServer("[Warning] [TeamChooserAuto] %s", buffer);
}

void ServerLogError(const char[] format, any...)
{
	char buffer[1024];

	VFormat(buffer, sizeof(buffer), format, 2);
	PrintToServer("[Error] [TeamChooserAuto] %s", buffer);
}
