#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <chat-processor>
#include <vip>
#include <restorecvars>
#include <sdkhooks>

enum struct Color {
	char Color_ChatTag[64];
	char Color_Name[64];
	char Color_Chat[64];
}

enum struct VIPType {
	char ChatTag[64];
	char ClanTag[64];
	char JoinMsg[64];
}

Handle g_hOnClientPutInServer;
Handle g_hOnKeyExchange;
Handle g_hOnClientStateChanged;

Database g_Database = null;

ConVar gc_ChatTag;
ConVar gc_ChatTagColor;
ConVar gc_ChatColor;
ConVar gc_NameColor;
ConVar gc_JoinMsg;
ConVar gc_VIPClanTag;
ConVar gc_PreFix;

bool g_Change[MAXPLAYERS + 1];
bool g_ClanTag[MAXPLAYERS + 1];
bool g_ChatTag[MAXPLAYERS + 1];
bool g_JoinMsg[MAXPLAYERS + 1];
bool g_VIPClanTag[MAXPLAYERS + 1];

int g_LeftDays[MAXPLAYERS + 1] = 0;

Color g_Color[MAXPLAYERS + 1];
VIPType g_VIP[MAXPLAYERS + 1];

VIPState g_State[MAXPLAYERS + 1] = VIPState_NoVIP;

#include "vip/natives.sp"

public Plugin myinfo = {
	name = "VIP System - Main",
	author = "Xc_ace",
	description = "VIP System",
	version = PLUGIN_VERSION,
	url = "https://github.com/Cola-Ace/VIP-Plugin"
}

public void OnPluginStart(){
	RegConsoleCmd("sm_vip", Command_VIP);
	
	gc_ChatTag = CreateConVar("sm_vip_chat_tag", "1", "0 - disabled , 1 - enable", _, true, 0.0, true, 1.0);
	gc_ChatTagColor = CreateConVar("sm_vip_chat_tag_color", "1", "0 - disabled , 1 - enable", _, true, 0.0, true, 1.0);
	gc_VIPClanTag = CreateConVar("sm_vip_private_clan_tag", "1", "0 - disabled , 1 - enable", _, true, 0.0, true, 1.0);
	gc_ChatColor = CreateConVar("sm_vip_chat_color", "1", "0 - disabled , 1 - enable", _, true, 0.0, true, 1.0);
	gc_NameColor = CreateConVar("sm_vip_name_color", "1", "0 - disabled , 1 - enable", _, true, 0.0, true, 1.0);
	gc_JoinMsg = CreateConVar("sm_vip_join_msg", "1", "0 - disabled , 1 - enable", _, true, 0.0, true, 1.0);
	gc_PreFix = CreateConVar("sm_vip_prefix", "[{green}VIP{normal}]", "Message Prefix");
	AutoExecConfig(true, "vip");
	
	char szError[512];
	g_Database = SQL_Connect("vip", true, szError, sizeof(szError));
	if (g_Database == null)
	{
		SetFailState("Can't connect to database, Error: %s", szError);
	}
	g_Database.SetCharset("utf8mb4");

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say2");
	AddCommandListener(Command_Say, "say_team");
	ExecuteAndSaveCvars("sourcemod/vip.cfg");
	HookEvent("player_spawn", Hook_PlayerSpawn);
	
	g_hOnClientPutInServer = CreateGlobalForward("VIP_OnClientPutInServer", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnKeyExchange = CreateGlobalForward("VIP_OnKeyExchange", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	g_hOnClientStateChanged = CreateGlobalForward("VIP_OnClientStateChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
}

public void VIP_OnClientStateChanged(int client, VIPState Before_State, VIPState After_State){
	if (Before_State == VIPState_NoVIP){
		RegClientPerks(client);
	}
}

public Action Hook_PlayerSpawn(Event event, const char[] name, bool dontBroadcast){
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (VIP_IsVIP(client) && gc_VIPClanTag.BoolValue && g_VIPClanTag[client]){
		if (VIP_GetClientState(client) == VIPState_IsYearVIP){
			CS_SetClientClanTag(client, "✧年VIP✧");
		} else {
			CS_SetClientClanTag(client, "✧VIP✧");
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (IsPlayer(client)){
		LogMessage("Client Post Admin Check");
		char query[256];
		Format(query, sizeof(query), "SELECT * FROM vipUsers WHERE authId='%s'", GetAuthId(client));
		g_Database.Query(SQL_CheckVIP, query, client);
	}
}

public void OnClientDisconnect(int client)
{
	if (VIP_IsVIP(client)){
		char auth[64];
		Format(auth, sizeof(auth), GetAuthId(client));
		char query[256];
		Format(query, sizeof(query), "UPDATE vipPerks SET chatTag='%s' WHERE authId='%s'", g_VIP[client].ChatTag, auth);
		g_Database.Query(SQL_CheckForErrors, query);
		Format(query, sizeof(query), "UPDATE vipPerks SET joinMsg='%s' WHERE authId='%s'", g_VIP[client].JoinMsg, auth);
		g_Database.Query(SQL_CheckForErrors, query);
		Format(query, sizeof(query), "UPDATE vipPerks SET tagColor='%s' WHERE authId='%s'", g_Color[client].Color_ChatTag, auth)
		g_Database.Query(SQL_CheckForErrors, query);
		Format(query, sizeof(query), "UPDATE vipPerks SET nameColor='%s' WHERE authId='%s'", g_Color[client].Color_Name, auth)
		g_Database.Query(SQL_CheckForErrors, query);
		Format(query, sizeof(query), "UPDATE vipPerks SET chatColor='%s' WHERE authId='%s'", g_Color[client].Color_Chat, auth)
		g_Database.Query(SQL_CheckForErrors, query);
		Format(query, sizeof(query), "UPDATE vipPerks SET clanTag='%s' WHERE authId='%s'", view_as<int>(g_VIPClanTag[client]), auth);
		g_Database.Query(SQL_CheckForErrors, query);
		int isyear = 0;
		if (VIP_GetClientState(client) == VIPState_IsYearVIP)isyear = 1;
		Format(query, sizeof(query), "UPDATE vipUsers SET year='%i' WHERE authId='%s'", isyear, auth);
		g_Database.Query(SQL_CheckForErrors, query);
	}
	g_State[client] = VIPState_NoVIP;
	g_Change[client] = false;
	g_VIPClanTag[client] = false;
}

public void SQL_GetChatTag(Database db, DBResultSet results, const char [] error, int userid){
	int client = GetClientOfUserId(userid);
	if (results.FetchRow()){
		results.FetchString(0, g_VIP[client].ChatTag, sizeof(g_VIP));
	}
}

public void SQL_GetJoinMsg(Database db, DBResultSet results, const char [] error, int userid){
	int client = GetClientOfUserId(userid);
	if (results.FetchRow()){
		results.FetchString(0, g_VIP[client].JoinMsg, sizeof(g_VIP));
		SetHudTextParams(-1.0, 0.1, 7.0, 0, 255, 150, 255, 2, 6.0, 0.1, 0.2);
		for (int i = 0; i < MaxClients; i++){
			if (IsPlayer(i)){
				ShowHudText(i, 0, "VIP %N 正在连接服务器...\n%s", client, g_VIP[client].JoinMsg);
			}
		}
	}
}

public void SQL_GetNameColor(Database db, DBResultSet results, const char [] error, int userid){
	int client = GetClientOfUserId(userid);
	if (results.FetchRow()){
		results.FetchString(0, g_Color[client].Color_Name, sizeof(g_Color));
	}
}

public void SQL_GetTagColor(Database db, DBResultSet results, const char [] error, int userid){
	int client = GetClientOfUserId(userid);
	if (results.FetchRow()){
		results.FetchString(0, g_Color[client].Color_ChatTag, sizeof(g_Color));
	}
}

public void SQL_GetChatColor(Database db, DBResultSet results, const char [] error, int userid){
	int client = GetClientOfUserId(userid);
	if (results.FetchRow()){
		results.FetchString(0, g_Color[client].Color_Chat, sizeof(g_Color));
	}
}

public void SQL_CheckClanTag(Database db, DBResultSet results, const char [] error, int userid){
	int client = GetClientOfUserId(userid);
	if (results.FetchRow()){
		g_VIPClanTag[client] = view_as<bool>(results.FetchInt(0));
	}
}

public Action Command_Say(int client, const char [] command, int argc){
	char args[256];
	GetCmdArg(1, args, sizeof(args));
	if (g_JoinMsg[client] || g_ChatTag[client] || g_ClanTag[client]){
		if (StrEqual(args, "-1") == true){
			VIP_Message(client, "你已经取消设置");
			g_JoinMsg[client] = false;
			g_ChatTag[client] = false;
			g_ClanTag[client] = false;
			return Plugin_Stop;
		}
		if (g_JoinMsg[client]){
			g_JoinMsg[client] = false;
			Format(g_VIP[client].JoinMsg, sizeof(g_VIP), args);
			VIP_Message(client, "你已成功修改你的进服提示为 {DARK_RED}%s", args);
		} else {
			g_ChatTag[client] = false;
			Format(g_VIP[client].ChatTag, sizeof(g_VIP), args);
			VIP_Message(client, "你已成功修改你的聊天前缀为 {DARK_RED}%s", args);
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void SQL_CheckVIP(Database db, DBResultSet results, const char[] error, int client)
{
	if (results.FetchRow()){
		int Stamp = results.FetchInt(1);
		int NowStamp = GetTime();
		if (Stamp < NowStamp){
			LogMessage("Del Client VIP");
			char query[256];
			Format(query, sizeof(query), "DELETE FROM vipUsers WHERE authId='%s'", GetAuthId(client))
			g_Database.Query(SQL_CheckForErrors, query);
			VIP_SetClientState(client, VIPState_NoVIP);
		}
		else {
			g_LeftDays[client] = (Stamp - NowStamp) / 86400;
			ShowVIPInfo(client);
		}
	}
	else {
		VIP_SetClientState(client, VIPState_NoVIP);
		Call_StartForward(g_hOnClientPutInServer);
		Call_PushCell(client);
		Call_PushCell(VIPState_NoVIP);
		Call_Finish();
	}
	
}

public Action CP_OnChatMessage(int& client, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool & processcolors, bool & removecolors)
{
	if (VIP_IsVIP(client)){
		if (StrEqual(g_Color[client].Color_Name, "") == false){
			if (StrEqual(g_Color[client].Color_Name, "rgb") == true){
				StripQuotes(name);
				char rgb[256];
				RGB(name, rgb, sizeof(rgb));
				Format(name, MAXLENGTH_NAME, rgb);
			}
			else {
				Format(name, MAXLENGTH_NAME, "%s%s", g_Color[client].Color_Name, name);
			}
		}
		else {
			Format(name, MAXLENGTH_NAME, "{normal}%s", name);
		}
		if (StrEqual(g_VIP[client].ChatTag, "") == false){
			if (StrEqual(g_Color[client].Color_ChatTag, "") == false && StrEqual(g_Color[client].Color_ChatTag, "null") == false){
				if (StrEqual(g_Color[client].Color_ChatTag, "rgb") == true){
					char tag[64];
					char rgb[256];
					Format(tag, sizeof(tag), "[%s]", g_VIP[client].ChatTag);
					StripQuotes(tag);
					RGB(tag, rgb, sizeof(rgb));
					Format(name, MAXLENGTH_NAME, "%s %s", rgb, name);
				}
				else {
					Format(name, MAXLENGTH_NAME, "%s[%s] %s", g_Color[client].Color_ChatTag, g_VIP[client].ChatTag, name);
				}
			}
			else {
				Format(name, MAXLENGTH_NAME, "[%s] %s", g_VIP[client].ChatTag, name);
			}
		}
		if (StrEqual(g_Color[client].Color_Chat, "") == false){
			if (StrEqual(g_Color[client].Color_Chat, "rgb") == true){
				StripQuotes(message);
				char rgb[256];
				RGB(message, rgb, sizeof(rgb));
				Format(message, MAXLENGTH_MESSAGE, rgb);
			}
			else {
				Format(message, MAXLENGTH_MESSAGE, "%s%s", g_Color[client].Color_Chat, message);
			}
		}
		Colorize(name, MAXLENGTH_NAME);
		Colorize(message, MAXLENGTH_MESSAGE);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action Command_VIP(int client, int args)
{
	char key[256];
	GetCmdArg(1, key, sizeof(key));
	if (StrEqual(key, "") == false){
		VIPKEY(client, key);
		return Plugin_Stop;
	}
	char query[256];
	Format(query, sizeof(query), "SELECT DAYS FROM vipPrivateCode WHERE authId='%s'", GetAuthId(client));
	g_Database.Query(SQL_PrivateCode, query, client);
	if (VIP_IsVIP(client)){
		Menus_Main(client);
	}
	else {
		VIP_Message(client, "你不是VIP");
	}
	return Plugin_Continue;
}

public void SQL_PrivateCode(Database db, DBResultSet results, const char [] error, int client)
{
	if (results.FetchRow()){
		char query[256];
		int days = results.FetchInt(0);
		char Stamp[64];
		char NewStamp[64];
		Format(Stamp, sizeof(Stamp), "%i", GetTime() + (days * 86400));
		Format(NewStamp, sizeof(NewStamp), "%i", GetTime() + ((days+g_LeftDays[client]) * 86400));
		if (VIP_IsVIP(client)){
			Format(query, sizeof(query), "UPDATE vipUsers SET expireStamp='%s' WHERE authId='%s'", NewStamp, GetAuthId(client));
			g_LeftDays[client] += days;
		} else {
			Format(query, sizeof(query), "INSERT INTO vipUsers (authId, expireStamp) VALUES ('%s', '%s')", GetAuthId(client), Stamp);
			g_LeftDays[client] = days;
			RegClientPerks(client);
		}
		g_Database.Query(SQL_CheckForErrors, query);
		VIP_Message(client, "检测到你有一张未使用的卡密，已自动兑换，卡密天数：%i", days);
		if (days >= 365){
			VIP_Message(client, "成功开通年费VIP服务");
			VIP_SetClientState(client, VIPState_IsYearVIP);
		} else {
			VIP_SetClientState(client, VIPState_IsVIP);
		}
		Format(query, sizeof(query), "DELETE FROM vipPrivateCode WHERE authId='%s'", GetAuthId(client));
		g_Database.Query(SQL_CheckForErrors, query);
	}
}

public void SQL_CheckYearVIP(Database db, DBResultSet results, const char [] error, int userid){
	int client = GetClientOfUserId(userid);
	if (results.FetchRow()){
		int result = results.FetchInt(0);
		if (result == 1){
			VIP_SetClientState(client, VIPState_IsYearVIP);
		} else {
			VIP_SetClientState(client, VIPState_IsVIP);
		}
		Call_StartForward(g_hOnClientPutInServer);
		Call_PushCell(client)
		Call_PushCell(g_State[client]);
		Call_Finish();
	}
}

void VIPKEY(int client, const char [] key)
{
	char query[256];
	Format(query, sizeof(query), "SELECT DAYS FROM vipCode WHERE VIPKEY='%s'", key);
	ArrayList g_ArrayList = new ArrayList(64);
	g_ArrayList.Push(client);
	g_ArrayList.PushString(key);
	g_Database.Query(SQL_VIPKEY, query, g_ArrayList)
}

public void SQL_VIPKEY(Database db, DBResultSet results, const char [] error, ArrayList g_ArrayList)
{
	int client = g_ArrayList.Get(0);
	char key[64];
	g_ArrayList.GetString(1, key, sizeof(key));
	if (results.FetchRow()){
		int days = results.FetchInt(0);
		if (days > 0){
			char Stamp[64];
			char NewStamp[64];
			Format(Stamp, sizeof(Stamp), "%i", GetTime() + (days * 86400));
			Format(NewStamp, sizeof(NewStamp), "%i", GetTime() + ((days+g_LeftDays[client]) * 86400));
			char query[256];
			if (VIP_IsVIP(client)){
				Format(query, sizeof(query), "UPDATE vipUsers SET expireStamp='%s' WHERE authId='%s'", NewStamp, GetAuthId(client));
			} else {
				Format(query, sizeof(query), "INSERT INTO vipUsers (authId, expireStamp) VALUES ('%s', '%s')", GetAuthId(client), Stamp);
				RegClientPerks(client);
			}
			g_Database.Query(SQL_CheckForErrors, query);
			VIP_Message(client, "你的VIP已兑换成功，天数为 %i 天", days);
			if (days >= 365){
				VIP_Message(client, "成功开通年费VIP服务");
				VIP_SetClientState(client, VIPState_IsYearVIP);
			} else {
				VIP_SetClientState(client, VIPState_IsVIP);
			}
			g_LeftDays[client] += days;
			Call_StartForward(g_hOnKeyExchange);
			Call_PushCell(client);
			Call_PushString(key);
			Call_PushCell(days);
			Call_Finish();
			Format(query, sizeof(query), "DELETE FROM vipCode WHERE VIPKEY='%s'", key);
			g_Database.Query(SQL_CheckForErrors, query);
		}
	} else {
		VIP_Message(client, "卡密不存在");
	}
}

void RegClientPerks(int client){
	char query[256];
	Format(query, sizeof(query), "INSERT INTO vipPerks (authId) VALUES ('%s')", GetAuthId(client));
	g_Database.Query(SQL_CheckForErrors, query);
}

public int Handler_Main(Menu menu, MenuAction action, int client, int select){
	if (action == MenuAction_Select){
		switch(select){
			case 0:ChatTagChange(client);
			case 1:ChatColorChange(client);
			case 2:ChatTagColorChange(client);
			case 3:NameColorChange(client);
			case 4:JoinMessageChange(client);
			case 5:{
				if (g_VIPClanTag[client]){
					g_VIPClanTag[client] = false;
					VIP_Message(client, "你已关闭VIP组名显示");
				} else {
					g_VIPClanTag[client] = true;
					VIP_Message(client, "你已开启VIP组名显示");
				}
			}
		}
	}
}

public int Handler_ChatTagMain(Menu menu, MenuAction action, int client, int select){
	if (action == MenuAction_Select){
		menu.GetItem(select, g_Color[client].Color_ChatTag, sizeof(g_Color));
	}
}

public int Handler_ChatMain(Menu menu, MenuAction action, int client, int select){
	if (action == MenuAction_Select){
		menu.GetItem(select, g_Color[client].Color_Chat, sizeof(g_Color));
	}
}

public int Handler_NameMain(Menu menu, MenuAction action, int client, int select){
	if (action == MenuAction_Select){
		menu.GetItem(select, g_Color[client].Color_Name, sizeof(g_Color));
	}
}

void ChatTagChange(int client){
	g_Change[client] = true;
	g_ChatTag[client] = true;
	VIP_Message(client, "请输入你想要更改的聊天前缀 输入 {DARK_RED}-1{NORMAL} 取消，输入 {DARK_RED}null{NORMAL} 为空");
}

void ChatTagColorChange(int client){
	Menu menu = new Menu(Handler_ChatTagMain);
	menu.SetTitle("选择聊天前缀颜色");
	menu.AddItem("{normal}", "默认");
	menu.AddItem("{dark_red}", "红色");
	menu.AddItem("{pink}", "粉色");
	menu.AddItem("{green}", "绿色");
	menu.AddItem("{yellow}", "黄色");
	menu.AddItem("{light_green}", "亮绿色");
	menu.AddItem("{light_red}", "亮红色");
	menu.AddItem("{grey}", "灰色");
	menu.AddItem("{orange}", "橙色");
	menu.AddItem("{light_blue}", "亮蓝色");
	menu.AddItem("{dark_blue}", "深蓝色");
	menu.AddItem("{purple}", "紫色");
	menu.AddItem("rgb", "RGB");
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

void ChatColorChange(int client){
	Menu menu = new Menu(Handler_ChatMain);
	menu.SetTitle("选择聊天颜色");
	menu.AddItem("{normal}", "默认");
	menu.AddItem("{dark_red}", "红色");
	menu.AddItem("{pink}", "粉色");
	menu.AddItem("{green}", "绿色");
	menu.AddItem("{yellow}", "黄色");
	menu.AddItem("{light_green}", "亮绿色");
	menu.AddItem("{light_red}", "亮红色");
	menu.AddItem("{grey}", "灰色");
	menu.AddItem("{orange}", "橙色");
	menu.AddItem("{light_blue}", "亮蓝色");
	menu.AddItem("{dark_blue}", "深蓝色");
	menu.AddItem("{purple}", "紫色");
	menu.AddItem("rgb", "RGB");
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

void NameColorChange(int client){
	Menu menu = new Menu(Handler_NameMain);
	menu.SetTitle("选择名字颜色");
	menu.AddItem("{normal}", "默认");
	menu.AddItem("{dark_red}", "红色");
	menu.AddItem("{pink}", "粉色");
	menu.AddItem("{green}", "绿色");
	menu.AddItem("{yellow}", "黄色");
	menu.AddItem("{light_green}", "亮绿色");
	menu.AddItem("{light_red}", "亮红色");
	menu.AddItem("{grey}", "灰色");
	menu.AddItem("{orange}", "橙色");
	menu.AddItem("{light_blue}", "亮蓝色");
	menu.AddItem("{dark_blue}", "深蓝色");
	menu.AddItem("{purple}", "紫色");
	menu.AddItem("rgb", "RGB");
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

void JoinMessageChange(int client){
	g_Change[client] = true;
	g_JoinMsg[client] = true;
	VIP_Message(client, "请输入你想要更改的进服提示 输入 {DARK_RED}-1{NORMAL} 取消，输入 {DARK_RED}null{NORMAL} 为空");
}

void Menus_Main(int client)
{
	Menu menu = new Menu(Handler_Main);
	menu.SetTitle("[VIP] 主菜单\n距离过期还有 %i 天", g_LeftDays[client]);
	menu.AddItem("chat tag", "更改聊天前缀", gc_ChatTag.BoolValue ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem("chat color", "更改聊天颜色", gc_ChatColor.BoolValue ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem("chat tag color", "更改聊天前缀颜色", gc_ChatTagColor.BoolValue ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem("name color", "更改名字颜色", gc_NameColor.BoolValue ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem("join msg", "更改进服提示", gc_JoinMsg.BoolValue ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem("clantag", "开关VIP组名", gc_VIPClanTag.BoolValue ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public void SQL_CheckForErrors(Database db, DBResultSet results, const char[] error, any data)
{
	if (!StrEqual(error, ""))
	{
		LogError("Database error, %s", error);
		return;
	}
}

stock char GetAuthId(int client){
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	return steamid;
}

stock void RGB(const char[] source, char[] buffer, int size)
{
	static char color[][] = {
			"\x01",
			"\x02",
			"\x03",
			"\x04",
			"\x05",
			"\x06",
			"\x07",
			"\x08",
			"\x09",
			"\x10",
			"\x0A",
			"\x0B",
			"\x0C",
			"\x0E",
			"\x0F"
	};

	int last = 0;
	int len = strlen(source) + 1;
	for(int i = 1; i < len; i++)
	{
		if (i == len || (source[i] & 0xc0) != 0x80)
		{
			char temp[5];
			strcopy(temp, i - last + 1, source[last]);
			Format(buffer, size, "%s%s%s", buffer, color[GetRandomInt(0, sizeof(color) - 1)], temp);
			last = i;
		}
	}
}

stock void ShowVIPInfo(int client){
	char auth[64];
	Format(auth, sizeof(auth), GetAuthId(client));
	char query[256];
	int userid = GetClientUserId(client);
	Format(query, sizeof(query), "SELECT chatTag FROM vipPerks WHERE authId='%s'", auth);
	g_Database.Query(SQL_GetChatTag, query, userid);
	Format(query, sizeof(query), "SELECT JoinMsg FROM vipPerks WHERE authId='%s'", auth);
	g_Database.Query(SQL_GetJoinMsg, query, userid);
	Format(query, sizeof(query), "SELECT tagColor FROM vipPerks WHERE authId='%s'", auth);
	g_Database.Query(SQL_GetTagColor, query, userid);
	Format(query, sizeof(query), "SELECT nameColor FROM vipPerks WHERE authId='%s'", auth);
	g_Database.Query(SQL_GetNameColor, query, userid);
	Format(query, sizeof(query), "SELECT chatColor FROM vipPerks WHERE authId='%s'", auth);
	g_Database.Query(SQL_GetChatColor, query, userid);
	Format(query, sizeof(query), "SELECT year FROM vipUsers WHERE authId='%s'", auth);
	g_Database.Query(SQL_CheckYearVIP, query, userid);
	Format(query, sizeof(query), "SELECT clanTag FROM vipPerks WHERE authId='%s'", auth);
	g_Database.Query(SQL_CheckClanTag, query, userid);
	
}