#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <steamworks>
#include <d2c>
#include <json>
#pragma newdecls required
#pragma dynamic 131072 
/**
	This plugin only for game data transfer
*/



bool playerAbandonStatus[10];

public void OnPluginStart()
{
	HookEvent("dota_match_done", OnMatchFinish, EventHookMode_Pre);

//	ServerCommand("dota_wait_for_players_to_load_count %d", 1);
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}


//Forward From Abandon Plugin
public void OnPlayerAbandoned(int playerID)
{
    if(playerID < 0 || playerID > 9)
    {
        PrintToServer("Unable to set abandon status, PlayerID: %i", playerID);
        return;
    }
    
    playerAbandonStatus[playerID] = true;
}

public Action OnMatchFinish(Handle event, char[] name, bool dontBroadcast)
{
	SaveGameData();
}

public Action Command_Say(int client, const char[] command, int argc)
{
	char sayString[32];
	GetCmdArg(1, sayString, sizeof(sayString));
	GetCmdArgString(sayString, sizeof(sayString));
	StripQuotes(sayString);
	if (!strcmp(sayString, "-save", false))
	{
		SaveGameData();
	}
}

public JSON_Object PlayerInMatchJSON(int index)
{
    int DATA_PR = GetPlayerResourceEntity();
    int DATA_PR_STEAMID_OFFSET = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
    
	JSON_Object hObj = new JSON_Object();
	char steamid[20];
	bool hasPlayer = GetSteamid(index, steamid)
	
	//Get SteamID
    int offset = DATA_PR_STEAMID_OFFSET + (8 * index);
    int steamID32 = GetEntData(DATA_PR, offset);
    
//    if(steamID32 == 0)
//    	return null;
	
	char heroName[40];
	GetHero(index, heroName);	
	hObj.SetString("hero", heroName);
	hObj.SetString("steam_id", steamid);
	
	hObj.SetBool("abandoned", playerAbandonStatus[index]);
	hObj.SetBool("did_random", GetDidRandom(index));
	
	hObj.SetInt("team", GetTeam(index));
	hObj.SetInt("level", GetLevel(index));
	
	hObj.SetInt("kills", GetKills(index));
	hObj.SetInt("deaths", GetDeaths(index));
	hObj.SetInt("assists", GetAssists(index));
	
	hObj.SetInt("healing", GetHealing(index));
	hObj.SetInt("networth", GetNetWorth(index));
	
	hObj.SetInt("gpm",  GetGPM(index));
	hObj.SetInt("xpm",  GetXPM(index));
	
	hObj.SetInt("last_hits",  GetLasthits(index));
	hObj.SetInt("denies", GetDenies(index));
	
	JSON_Array hArray = GetItems(index);
	
	hObj.SetObject("items", hArray);
	
	return hObj;
}

public JSON_Object GenerateMatchResults(int match_id, int game_mode, const char[] server_url)
{
	int	winnerTeam	= GameRules_GetProp("m_nGameWinner", 4, 0);
	bool isRadiantWin = winnerTeam == 2;
	
	JSON_Object obj	= new JSON_Object();
	obj.SetInt("matchId", match_id);
	obj.SetBool("radiantWin", isRadiantWin);
	obj.SetInt("duration", GetDuration());
	obj.SetInt("type", game_mode);
	obj.SetInt("timestamp", GetTime());
	obj.SetString("server", server_url);
	
	JSON_Array hArray = new JSON_Array();
	
	for (int i = 0; i < 10; i++)
	{
		JSON_Object pObj = PlayerInMatchJSON(i);
		PrintToServer("%d %d", i, pObj);
		hArray.PushObject(pObj);
	}
	
	obj.SetObject("players", hArray);
	
	return obj;
}


public void SaveGameData(){
	JSON_Object hObj = LoadMatchConfigJSON();
	
	int	match_id = hObj.GetInt("matchId");
	int game_mode = hObj.GetInt("mode");
	
	char server_url[40];	
	hObj.GetString("server_url", server_url, sizeof(server_url));
	
	
	JSON_Object event = GenerateMatchResults(match_id, game_mode, server_url);
	
	char sJSON[16384];
	
	event.Encode(sJSON, sizeof(sJSON));
	PrintToServer(sJSON)
	
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, "http://localhost:5001/match_results");
	if (request == null)
	{
		PrintToServer("Request is null.");
		return;
	}
	
	SteamWorks_SetHTTPRequestRawPostBody(request, "application/json; charset=UTF-8", sJSON, strlen(sJSON));
	SteamWorks_SetHTTPRequestNetworkActivityTimeout(request, 30);
	SteamWorks_SetHTTPCallbacks(request, HTTPCompleted, HeadersReceived, HTTPDataReceive);
	
	SteamWorks_SendHTTPRequest(request);
	
	
	
	char path[500];
	BuildPath(Path_SM, path, sizeof(path), "configs/hoho.json")
	Handle file = OpenFile(path, "w+");
	if (!file)
	{
		PrintToServer("Can't read file... :( %s", path);
		return;
	}
	
	WriteFileString(file, sJSON, false);
	
	CloseHandle(file);
	
}

public int HTTPCompleted(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statuscode, any data, any data2)
{
	PrintToServer("HTTP Complted")
}

public int HTTPDataReceive(Handle request, bool failure, int offset, int statuscode, any dp)
{
	PrintToServer("Data received %d", statuscode);
	if (statuscode == 200)
	{
		PrintToChatAll("Матч сохранен.")
	}
	delete request;
}

public int HeadersReceived(Handle request, bool failure, any data, any datapack)
{
	PrintToServer("Headers received")
}