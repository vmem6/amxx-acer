#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <cstrike>

#define PLUGIN  "Acer"
#define VERSION "1.0.1"
#define AUTHOR  "vmem6"

#define DICTIONARY_FILE "acer.txt"

#define MAX_PREFIX_LENGTH   16
#define MAX_CHAT_MSG_LENGTH 256

#define MAX_MENU_TITLE_LENGTH 64
#define MAX_MENU_ITEM_LENGTH  64

/* Enums */

enum (+= 1234)
{
  tid_mix_vote = 1257
};

/* CVars */

new g_prefix[MAX_PREFIX_LENGTH + 1];

new bool:g_show_restart_msg;

new g_mix_min_pcount;
new Float:g_mix_min_pcount_ratio;
new Float:g_mix_min_pcount_ratio_live;
new g_mix_round_num;

new g_mix_vote_timeout;
new Float:g_mix_vote_min_turnout;
new Float:g_mix_vote_min_ratio;
new g_mix_vote_repeat_delay;

new g_mix_repeat_delay;

/* State vars */

new g_bs_mix_voted;

new bool:g_mix_starting;
new bool:g_mix_started;
new g_mix_last_time;

new g_mix_t_score;
new g_mix_ct_score;
new g_mix_round;

new bool:g_mix_in_vote;
new g_mix_vote_time;
new g_mix_voted_in_favor;
new g_mix_voted_against;
new g_mix_last_vote_time;

new g_mix_vote_menu = 0;

public plugin_init()
{
  register_plugin(PLUGIN, VERSION, AUTHOR);
  register_dictionary(DICTIONARY_FILE);

  /* CVars */

  bind_pcvar_string(create_cvar("acer_prefix", "[ACER] ^1"), g_prefix, charsmax(g_prefix));
  bind_pcvar_num(create_cvar("acer_show_restart_msg", "0"), g_show_restart_msg);

  bind_pcvar_num(create_cvar("acer_mix_min_players", "2"), g_mix_min_pcount);
  bind_pcvar_float(create_cvar("acer_mix_min_pcount_ratio", "1.0"), g_mix_min_pcount_ratio);
  bind_pcvar_float(create_cvar("acer_mix_min_pcount_ratio_live", "0.75"), g_mix_min_pcount_ratio_live);
  bind_pcvar_num(create_cvar("acer_mix_round_num", "12"), g_mix_round_num);
  bind_pcvar_num(create_cvar("acer_mix_repeat_delay", "60"), g_mix_repeat_delay);

  bind_pcvar_num(create_cvar("acer_mix_vote_timeout", "10"), g_mix_vote_timeout);
  bind_pcvar_float(create_cvar("acer_mix_vote_min_turnout", "0.5"), g_mix_vote_min_turnout);
  bind_pcvar_float(create_cvar("acer_mix_vote_min_ratio", "0.75"), g_mix_vote_min_ratio);
  bind_pcvar_num(create_cvar("acer_mix_vote_repeat_delay", "30"), g_mix_vote_repeat_delay);

  /* Client commands */

  register_clcmd("say /votemix", "clcmd_votemix");
  register_clcmd("say_team /votemix", "clcmd_votemix");
  register_clcmd("jointeam", "clcmd_jointeam");

  /* Messages */

  register_message(get_user_msgid("ShowMenu"), "msg_showmenu");
  register_message(get_user_msgid("VGUIMenu"), "msg_vguimenu");
  register_message(get_user_msgid("TextMsg"), "msg_textmsg");

  /* Events */

  register_event_ex("HLTV", "event_new_round", RegisterEvent_Global, "1=0", "2=0");
  register_event_ex("SendAudio", "event_sendaudio",
    RegisterEvent_Global, "2=%!MRAD_terwin", "2=%!MRAD_ctwin");

  register_logevent("logevent_round_end", 2, "1=Round_End");

  /* Forwards */

  register_forward(FM_PlayerPreThink, "fwd_playerprethink_pre");
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
  if (!g_mix_started)
    return;

  new tnum = get_playersnum_ex(GetPlayers_MatchTeam, "TERRORIST");
  new ctnum = get_playersnum_ex(GetPlayers_MatchTeam, "CT");

  new CsTeams:team = cs_get_user_team(pid);
  if (team == CS_TEAM_T)
    --tnum;
  else if (team == CS_TEAM_CT)
    --ctnum;

  if (tnum == 0 || ctnum == 0) {
    print(0, print_team_red, 3,
      "%L", LANG_PLAYER, "CHAT_MIX_TEAM_ALL_LEFT", tnum == 0 ? "T" : "CT");
    end_mix();
    return;
  }

  if (1.0*min(tnum, ctnum)/max(tnum, ctnum) < g_mix_min_pcount_ratio_live) {
    print(0, print_team_red, 3,
      "%L", LANG_PLAYER, "CHAT_MIX_PLAYER_DIFF_TOO_LARGE",
      max(tnum, ctnum) - floatround(g_mix_min_pcount_ratio_live*max(tnum, ctnum), floatround_ceil));
    end_mix();
  }
}

/* Client commands */

public clcmd_votemix(pid)
{
  if (g_mix_started) {
    print(pid, print_team_red, 3, "%L", LANG_PLAYER, "CHAT_MIX_VOTE_MIX_IN_PROGRESS");
    return PLUGIN_HANDLED;
  }

  if (g_mix_in_vote) {
    print(pid, print_team_red, 3, "%L", LANG_PLAYER, "CHAT_MIX_VOTE_IN_PROGRESS");
    return PLUGIN_HANDLED;
  }

  if (get_systime() - g_mix_last_time < g_mix_repeat_delay) {
    print(pid, print_team_red, 3,
      "%L", LANG_PLAYER, "CHAT_MIX_TOO_RECENT",
      g_mix_repeat_delay - (get_systime() - g_mix_last_time));
    return PLUGIN_HANDLED;
  }

  if (get_systime() - g_mix_last_vote_time < g_mix_vote_repeat_delay) {
    print(pid, print_team_red, 3,
      "%L", LANG_PLAYER, "CHAT_MIX_VOTE_TOO_RECENT",
      g_mix_vote_repeat_delay - (get_systime() - g_mix_last_vote_time));
    return PLUGIN_HANDLED;
  }

  new tnum = get_playersnum_ex(GetPlayers_MatchTeam, "TERRORIST");
  new ctnum = get_playersnum_ex(GetPlayers_MatchTeam, "CT");

  if (tnum + ctnum < g_mix_min_pcount) {
    print(pid, print_team_red, 3,
      "%L", LANG_PLAYER, "CHAT_MIX_VOTE_NOT_ENOUGH_PLAYERS", tnum + ctnum, g_mix_min_pcount);
    return PLUGIN_HANDLED;
  }

  if (1.0*min(tnum, ctnum)/max(tnum, ctnum) < g_mix_min_pcount_ratio) {
    print(pid, print_team_red, 3,
      "%L", LANG_PLAYER, "CHAT_MIX_VOTE_PLAYER_DIFF_TOO_LARGE",
      abs(tnum - ctnum), floatround(g_mix_min_pcount_ratio*max(tnum, ctnum), floatround_ceil));
    return PLUGIN_HANDLED;
  }

  new name[MAX_NAME_LENGTH + 1];
  get_user_name(pid, name, charsmax(name));
  print(pid, pid, 4, "%L", LANG_PLAYER, "CHAT_MIX_VOTE_X_STARTED", name, g_mix_round_num);

  g_bs_mix_voted = 0;

  g_mix_in_vote = true;
  g_mix_vote_time = 0;
  g_mix_voted_in_favor = 0;
  g_mix_voted_against = 0;
  g_mix_last_vote_time = get_systime();

  display_mix_vote_menu();
  set_task_ex(1.0, "display_mix_vote_menu", tid_mix_vote, .flags = SetTask_Repeat);

  return PLUGIN_HANDLED;
}

public clcmd_jointeam(pid)
{
  return g_mix_started || g_mix_in_vote ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}

public display_mix_vote_menu()
{
  if (g_mix_vote_menu != 0) {
    menu_destroy(g_mix_vote_menu);
    g_mix_vote_menu = 0;
  }

  if (g_mix_vote_time == g_mix_vote_timeout) {
    close_mix_vote();
    return;
  }

  new menu_title[MAX_MENU_TITLE_LENGTH + 1];
  formatex(menu_title, charsmax(menu_title), "%L", LANG_PLAYER, "MENU_MIX_VOTE_TITLE");
  g_mix_vote_menu = menu_create(menu_title, "handle_mix_vote_menu");

  new item[MAX_MENU_ITEM_LENGTH + 1];

  formatex(item, charsmax(item), "%L", LANG_PLAYER, "MENU_YES");
  menu_additem(g_mix_vote_menu, item);
  formatex(item, charsmax(item), "%L", LANG_PLAYER, "MENU_NO");
  menu_additem(g_mix_vote_menu, item);

  menu_addblank(g_mix_vote_menu);

  formatex(item, charsmax(item),
    "%L", LANG_PLAYER, "MENU_TIME_LEFT", g_mix_vote_timeout - g_mix_vote_time);
  menu_addtext(g_mix_vote_menu, item);

  menu_setprop(g_mix_vote_menu, MPROP_EXIT, MEXIT_NEVER);

  for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
    if (!is_user_connected(pid) || is_user_bot(pid) || (g_bs_mix_voted & (1 << (pid & 31))))
      continue;
    new CsTeams:team = cs_get_user_team(pid);
    if (team == CS_TEAM_CT || team == CS_TEAM_T)
      menu_display(pid, g_mix_vote_menu, .time = g_mix_vote_timeout);
  }

  ++g_mix_vote_time;
}

public handle_mix_vote_menu(pid, menu, item)
{
  if (g_mix_in_vote && item >= 0) {
    g_bs_mix_voted |= (1 << (pid & 31));

    if (item == 0)
      ++g_mix_voted_in_favor;
    else if (item == 1)
      ++g_mix_voted_against;

    new total_votes = g_mix_voted_in_favor + g_mix_voted_against;
    new pnum = get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_MatchTeam, "TERRORIST") +
      get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_MatchTeam, "CT");

    if (total_votes >= pnum) {
      print(0, print_team_default, 4, "%L", LANG_PLAYER, "CHAT_MIX_VOTE_ALL_VOTED");
      close_mix_vote();
      menu_destroy(g_mix_vote_menu);
      g_mix_vote_menu = 0;
    }
  }

  return PLUGIN_HANDLED;
}

close_mix_vote()
{
  g_mix_in_vote = false;
  remove_task(tid_mix_vote);

  new total_votes = g_mix_voted_in_favor + g_mix_voted_against;
  new pnum = get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_MatchTeam, "TERRORIST") +
    get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_MatchTeam, "CT");

  if (1.0*total_votes/pnum < g_mix_vote_min_turnout) {
    print(0, print_team_red, 3,
      "%L", LANG_PLAYER, "CHAT_MIX_VOTE_INSUFFICIENT_TURNOUT",
      total_votes, floatround(g_mix_vote_min_turnout*pnum, floatround_ceil));
    return;
  }

  if (1.0*g_mix_voted_in_favor/total_votes >= g_mix_vote_min_ratio) {
    print(0, print_team_default, 4, "%L", LANG_PLAYER, "CHAT_MIX_VOTE_SUCCEEDED", g_mix_round_num);
    start_mix();
  } else {
    print(0, print_team_red, 3,
      "%L", LANG_PLAYER, "CHAT_MIX_VOTE_FAILED",
      g_mix_voted_in_favor, floatround(g_mix_vote_min_ratio*total_votes, floatround_ceil),
      g_mix_voted_against);
  }
}

start_mix()
{
  g_mix_t_score = g_mix_ct_score = g_mix_round = 0;
  g_mix_starting = true;
  server_cmd("sv_restart 3");
}

end_mix()
{
  g_mix_started = false;
  g_mix_last_time = get_systime();
  server_cmd("sv_restart 3");
}

/* Messages */

public msg_showmenu(msg_id, msg_dest, msg_ent)
{
  enum { arg_text = 4 };
  if (g_mix_started || g_mix_in_vote) {
    new text[32 + 1];
    get_msg_arg_string(arg_text, text, charsmax(text));
    if (contain(text, "Team_Select") != -1)
      return PLUGIN_HANDLED;
  }
  return PLUGIN_CONTINUE;
}

public msg_vguimenu(msg_id, msg_dest, msg_ent)
{
  enum { arg_menu_id = 1 };
  if (g_mix_started || g_mix_in_vote) {
#define MENU_ID_TEAM_SELECT 2
    if (get_msg_arg_int(arg_menu_id) == MENU_ID_TEAM_SELECT)
      return PLUGIN_HANDLED;
  }
  return PLUGIN_CONTINUE;
}

public msg_textmsg(msg_id, msg_dest, msg_ent)
{
  enum { arg_msg = 2 };
  if (!g_show_restart_msg) {
    new text[32 + 1];
    get_msg_arg_string(arg_msg, text, charsmax(text));
    if (contain(text, "#Game_will_restart_in") != -1)
      return PLUGIN_HANDLED;
  }
  return PLUGIN_CONTINUE;
}

/* Events */

public event_new_round()
{
  if (g_mix_starting) {
    g_mix_starting = false;
    g_mix_started = true;
  }

  if (!g_mix_started)
    return;

  ++g_mix_round;
  print(0, print_team_default, 4,
    "%L", LANG_PLAYER, "CHAT_MIX_SCORE",
    g_mix_round, g_mix_round_num, g_mix_t_score, g_mix_ct_score);
}

public event_sendaudio()
{
  enum { data_audiocode = 2 };

  if (!g_mix_started)
    return;

  new audiocode[32 + 1];
  read_data(data_audiocode, audiocode, charsmax(audiocode));
  if (contain(audiocode, "terwin") != -1)
    ++g_mix_t_score;
  else
    ++g_mix_ct_score;
}

public logevent_round_end()
{
  if (!g_mix_started || g_mix_round < g_mix_round_num)
    return;

  if (g_mix_t_score == g_mix_ct_score) {
    print(0, print_team_default, 4,
      "%L", LANG_PLAYER, "CHAT_MIX_DRAW", g_mix_t_score, g_mix_ct_score);
  } else {
    print(0, print_team_default, 4,
      "%L", LANG_PLAYER, "CHAT_MIX_WON",
      g_mix_t_score > g_mix_ct_score ? "T" : "CT", abs(g_mix_t_score - g_mix_ct_score));
  }

  end_mix();
}

/* Forwards */

public fwd_playerprethink_pre(pid)
{
  /* Slash -> stab */
  if (get_user_weapon(pid) == CSW_KNIFE) {
    static buttons; buttons = pev(pid, pev_button);
    if (buttons & IN_ATTACK)
      set_pev(pid, pev_button, (buttons & ~IN_ATTACK) | IN_ATTACK2);
  }
}

/* Utilities */

print(pid, team_color, prefix_color, fmt[], any:...)
{
  new prefix[MAX_PREFIX_LENGTH + 2];
  prefix[0] = prefix_color;
  copy(prefix[1], charsmax(prefix) - 1, g_prefix);

  new msg[MAX_CHAT_MSG_LENGTH + 1];
  vformat(msg, charsmax(msg), fmt, 5);

  client_print_color(pid, team_color, "%s%s", prefix, msg);
}
