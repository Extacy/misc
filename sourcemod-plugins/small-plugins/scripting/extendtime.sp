// Made this in one go while i was rlly tired, don't expect good

#include <sourcemod>
#include <kztimer>

#pragma semicolon 1
#pragma newdecls required

#define CHAT_PREFIX " \x0C➤➤➤\x0B"
#define CHAT_COLOR "\x0B"
#define CHAT_ACCENT "\x0F"

ConVar g_VoteCooldown;

int g_iCooldown[MAXPLAYERS + 1];

ConVar mp_timelimit;

public Plugin myinfo = 
{
    name = "Extend Time", 
    author = "Extacy", 
    description = "", 
    version = "1.0", 
    url = "https://steamcommunity.com/profiles/76561198183032322"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_extendvote", CMD_ExtendTimeVote);
    RegConsoleCmd("sm_extendtimevote", CMD_ExtendTimeVote);

    RegAdminCmd("sm_extend", CMD_ExtendTime, ADMFLAG_CHANGEMAP);
    RegAdminCmd("sm_extendtime", CMD_ExtendTime, ADMFLAG_CHANGEMAP);

    mp_timelimit = FindConVar("mp_timelimit");
    SetConVarFlags(mp_timelimit, GetConVarFlags(mp_timelimit) & ~FCVAR_NOTIFY);

    g_VoteCooldown = CreateConVar("sm_extendtime_vote_cooldown", "60", "In seconds");
}

public Action CMD_ExtendTime(int client, int args)
{
    if (args != 1)
    {
        PrintToChat(client, "%s Usage: sm_extend <[+/-] minutes>", CHAT_PREFIX);
        return Plugin_Handled;
    }

    char arg[10];
    GetCmdArg(1, arg, sizeof(arg));

    int increase = StringToInt(arg);
    mp_timelimit.SetInt(mp_timelimit.IntValue + increase);

    int timeleft;
    GetMapTimeLeft(timeleft);

    int mins, secs;
    mins = timeleft / 60;
    secs = timeleft % 60;

    PrintToChatAll("%s %s%N%s extended the map by %s%i minutes%s! (Time left: %s%i:%02i%s)", CHAT_PREFIX, CHAT_ACCENT, client, CHAT_COLOR, CHAT_ACCENT, increase, CHAT_COLOR, CHAT_ACCENT, mins, secs, CHAT_COLOR);
    return Plugin_Handled;
}

public Action CMD_ExtendTimeVote(int client, int args)
{
    int cooldown = GetTime() - g_iCooldown[client];

    if (cooldown < g_VoteCooldown.IntValue)
    {
        PrintToChat(client, "%s You must wait %s%i%s seconds before calling another vote.", CHAT_PREFIX, CHAT_ACCENT, g_VoteCooldown.IntValue - cooldown, CHAT_COLOR);
        return Plugin_Handled;
    }

    Menu menu = new Menu(ExtendTimeMenuHandler);

    int timeleft;
    GetMapTimeLeft(timeleft);

    int mins, secs;
    mins = timeleft / 60;
    secs = timeleft % 60;

    char title[64];
    Format(title, sizeof(title), "Extend Map? (Timeleft: %i:%02i)", mins, secs);

    menu.SetTitle(title);
    menu.AddItem("1", "1 minute");
    menu.AddItem("2", "2 minutes");
    menu.AddItem("5", "5 minutes");
    menu.AddItem("10", "10 minutes");
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int ExtendTimeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        int extend = StringToInt(info);

        DataPack pack;
        CreateDataTimer(1.0, Timer_VoteCountdown, pack, TIMER_REPEAT);
        pack.WriteCell(param1);
        pack.WriteCell(extend);
        
        g_iCooldown[param1] = GetTime();
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return;
}

public Action Timer_VoteCountdown(Handle timer, DataPack pack)
{
    static int countdown = 15;

    if (countdown == 0)
    {
        pack.Reset();
        int client = pack.ReadCell();
        int extend = pack.ReadCell();

        char info[32];
        IntToString(extend, info, sizeof(info));
    
        int timeleft;
        GetMapTimeLeft(timeleft);

        int mins, secs;
        mins = timeleft / 60;
        secs = timeleft % 60;

        char title[64];
        Format(title, sizeof(title), "Extend Map by %i minutes? (Timeleft: %i:%02i)", extend, mins, secs);

        KZTimer_StopUpdatingOfClimbersMenu(client);

        Menu vote = new Menu(VoteMenuHandler);
        vote.SetTitle(title);
        vote.AddItem(info, "Yes");
        vote.AddItem("no", "No");
        vote.ExitButton = false;
        vote.DisplayVoteToAll(20);

        PrintToChatAll("%s %s%N%s is voting to extend the map by %s%i%s minutes!", CHAT_PREFIX, CHAT_ACCENT, client, CHAT_COLOR, CHAT_ACCENT, extend, CHAT_COLOR);
        return Plugin_Stop;
    }

    PrintToChatAll("%s %sWARNING%s - Extend time vote in %s%i seconds%s. Pause your timers!", CHAT_PREFIX, CHAT_ACCENT, CHAT_COLOR, CHAT_ACCENT, countdown, CHAT_COLOR);

    countdown--;
    return Plugin_Continue;
}

public int VoteMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        ClientCommand(param1, "sm_menu");
    }
    else if (action == MenuAction_VoteEnd)
    {
        /* 0=yes, 1=no */
        if (param1 == 0)
        {
            char info[10];
            menu.GetItem(param1, info, sizeof(info));

            int time = StringToInt(info);

            mp_timelimit.SetInt(mp_timelimit.IntValue + time);

            int timeleft;
            GetMapTimeLeft(timeleft);

            int mins, secs;
            mins = timeleft / 60;
            secs = timeleft % 60;

            PrintToChatAll("%s Vote passed! The map has been extended by %s%i%s minutes. (Timeleft: %s%i:%02i%s)", CHAT_PREFIX, CHAT_ACCENT, time, CHAT_COLOR, CHAT_ACCENT, mins, secs, CHAT_COLOR);
        }
        else
        {
            PrintToChatAll("%s Not enough people voted to extend the map!", CHAT_PREFIX);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}