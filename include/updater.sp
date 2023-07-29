#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <steamworks>
#include <d2c>
#include <json>
#pragma newdecls required
#pragma dynamic 131072 

//class PlayerInfo {
//  hero: string;
//  team: number;
//  steam_id: string;
//  level: number;
//  pos_x: number;
//  bot: boolean;
//  pos_y: number;
//  items: string[];
//  kills: number;
//  deaths: number;
//  assists: number;
//}
//
//export class LiveMatchUpdateEvent {
//  matchId: number;
//  type: MatchmakingMode;
//  duration: number;
//  server: string;
//  timestamp: number;
//  heroes: PlayerInfo[];
//}

bool playerAbandonStatus[10];
int	match_id;
int game_mode;
char server_url[40];

public void OnPluginStart()
{
	ServerCommand("dota_wait_for_players_to_load_count %d", 1);
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	
	
	JSON_Object hObj = LoadMatchConfigJSON();
	
	match_id = hObj.GetInt("matchId");
	game_mode = hObj.GetInt("mode");
	
	
	hObj.GetString("server_url", server_url, sizeof(server_url));
	
	
	
	CreateTimer(3.0, OnGameUpdate, any:0, 1);
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

public Action Command_Say(int client, const char[] command, int argc)
{
	char sayString[32];
	GetCmdArg(1, sayString, sizeof(sayString));
	GetCmdArgString(sayString, sizeof(sayString));
	StripQuotes(sayString);
	if (!strcmp(sayString, "-save", false))
	{
		OnUpdate();
	}
}

JSON_Object FillEntity(int index){
	JSON_Object hObj = new JSON_Object();
	
	PrintToServer("Index of %d", index);
	
	char heroName[40];
	GetEntityClassname(index, heroName, sizeof(heroName));
	
	
	float vec[3];
	GetPosition(index, vec);
	
	int pid = GetEntProp(index, Prop_Send, "m_iPlayerID", 4, 0);
	index = pid;
	
	char steamid[20];
	GetSteamid(index, steamid);
	bool isBot = strlen(steamid) <= 10;
	
	hObj.SetString("hero", heroName);
	hObj.SetString("steam_id", steamid);
	
	hObj.SetBool("abandoned", playerAbandonStatus[index]);
	hObj.SetBool("did_random", GetDidRandom(index));
	hObj.SetBool("bot", isBot);
	
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
	
	
	
	PrintToServer("%f", vec[0]);
	PrintToServer("%f", vec[1]);
	PrintToServer("%f", vec[2]);
	
	hObj.SetFloat("pos_x", (vec[0] + 7500.0) / 15000.0)
	hObj.SetFloat("pos_y", (vec[1] + 7500.0) / 15000.0)
	
	
	
	JSON_Array hArray = GetItems(index);
	
	hObj.SetObject("items", hArray);
	
	return hObj;
}

public void OnUpdate(){
	JSON_Object event = new JSON_Object();
	
	event.SetInt("matchId", match_id);
	event.SetInt("duration", GetDuration());
	event.SetInt("type", game_mode);
	event.SetInt("timestamp", GetTime({0,0}));
	event.SetString("server", server_url)
	
	
	JSON_Array players = new JSON_Array();
	for (int i = 0; i < 5000; i++)
	{
		if (!IsValidEntity(i)) continue;
		
		char hero[40];
		GetEntityNetClass(i, hero, 40);
		if (StrContains(hero, "CDOTA_Unit_Hero_", true) != -1)
		{
			bool isIllusion = GetEntProp(i, Prop_Data, "m_bIsIllusion", 4, 0);
			bool isHeroUnit = GetEntProp(i, Prop_Data, "m_bHasInventory", 4, 0);
			if (isIllusion || isHeroUnit)
			{
				JSON_Object pObj = FillEntity(i);
				players.PushObject(pObj);
			}
		}
	}
	
	
	event.SetObject("heroes", players);
	
	char sJSON[10000];
	event.Encode(sJSON, sizeof(sJSON))
	
	
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, "http://localhost:5001/live_match");
	if (request == null)
	{
		PrintToServer("Request is null.");
		return;
	}
	
	SteamWorks_SetHTTPRequestRawPostBody(request, "application/json; charset=UTF-8", sJSON, strlen(sJSON));
	SteamWorks_SetHTTPRequestNetworkActivityTimeout(request, 30);
	SteamWorks_SetHTTPCallbacks(request, HTTPCompleted, HeadersReceived, HTTPDataReceive);
	
	SteamWorks_SendHTTPRequest(request);
}


public Action OnGameUpdate(Handle timer)
{
	int gameState = GameRules_GetProp("m_nGameState", 4, 0);
	PrintToServer("%d", gameState);
	if (gameState != 4 && gameState != 5)
	{
		return Plugin_Continue;
	}
	
	OnUpdate();	
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
		
	}
	delete request;
}

public int HeadersReceived(Handle request, bool failure, any data, any datapack)
{
	PrintToServer("Headers received")
}