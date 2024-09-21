# Acer

An [AMX Mod X](https://www.amxmodx.org/) plugin for [Counter-Strike 1.6](https://store.steampowered.com/app/10/CounterStrike/) that provides a simple environment for running Acer-mode knife servers.

## Features

Currently, there are two features: slash block, and a simple mix/duel system.

Slash block is always active and forces a would-be slash into a stab.

The mix/duel system allows players to start a vote on whether they'd like to initiate a team-versus-team duel for a set amount of rounds (`acer_mix_round_num`), assuming that certain conditions are met (player ratio [`acer_mix_min_pcount_ratio`] and minimum number of players [`acer_mix_min_players`]).

## Requirements

- Metamod
- AMX Mod X (>= 1.9.0)

## Installation

1. Download the [latest release](https://github.com/vmem6/amxx-acer/releases/latest).
2. Extract the 7z archive into your HLDS folder.
3. Append `acer.amxx` to `configs/plugins.ini`.

## Configuration (CVars)

<details>
<summary>CVars (click to expand) </summary>

_Note: the min. and max. values are not currently enforced, and are only provided as sensible bounds._

<table>
  <tr>
    <td>CVar</td>
    <td align="center">Type</td>
    <td align="center">Def. value</td>
    <td align="center">Min. value</td>
    <td align="center">Max. value</td>
    <td>Description</td>
  </tr>
  <tr>
    <td><code>acer_prefix</code></td>
    <td align="center">string</td>
    <td align="center"><code>"[ACER] ^1"</code></td>
    <td align="center">-</td>
    <td align="center">-</td>
    <td>Prefix printed before every chat message issued by the plugin.</td>
  </tr>
  <tr>
    <td><code>acer_show_restart_msg</code></td>
    <td align="center">boolean</td>
    <td align="center">0</td>
    <td align="center">0</td>
    <td align="center">1</td>
    <td>
      Show "Game will restart in N seconds" messages.<br>
      <code>0</code> - disabled;<br>
      <code>1</code> - enabled.
    </td>
  </tr>
  <tr>
    <td><code>acer_mix_min_players</code></td>
    <td align="center">integer</td>
    <td align="center">2</td>
    <td align="center">1</td>
    <td align="center">32</td>
    <td>Minimum number of players necessary before a mix vote can be started.</td>
  </tr>
  <tr>
    <td><code>acer_mix_min_pcount_ratio</code></td>
    <td align="center">float</td>
    <td align="center">1.0</td>
    <td align="center">0.1</td>
    <td align="center">1.0</td>
    <td>Minimum player ratio that must be satisfied before a mix vote can be started.</td>
  </tr>
  <tr>
    <td><code>acer_mix_min_pcount_ratio_live</code></td>
    <td align="center">float</td>
    <td align="center">0.75</td>
    <td align="center">0.1</td>
    <td align="center">1.0</td>
    <td>Minimum player ratio that must be maintained throughout the mix. The mix will end prematurely otherwise.</td>
  </tr>
  <tr>
    <td><code>acer_mix_round_num</code></td>
    <td align="center">integer</td>
    <td align="center">12</td>
    <td align="center">1</td>
    <td align="center">-</td>
    <td>Number of rounds the mix will run for.</td>
  </tr>
  <tr>
    <td><code>acer_mix_repeat_delay</code></td>
    <td align="center">integer</td>
    <td align="center">60</td>
    <td align="center">0</td>
    <td align="center">-</td>
    <td>Number of seconds that must elapse before another mix can be started.</td>
  </tr>
  <tr>
    <td><code>acer_mix_vote_timeout</code></td>
    <td align="center">integer</td>
    <td align="center">10</td>
    <td align="center">2</td>
    <td align="center">-</td>
    <td>Number of seconds the mix vote will run for.</td>
  </tr>
  <tr>
    <td><code>acer_mix_vote_min_turnout</code></td>
    <td align="center">float</td>
    <td align="center">0.6</td>
    <td align="center">0.0</td>
    <td align="center">1.0</td>
    <td>Minimum turnout necessary to consider mix vote results.</td>
  </tr>
  <tr>
    <td><code>acer_mix_vote_min_ratio</code></td>
    <td align="center">float</td>
    <td align="center">0.75</td>
    <td align="center">0.1</td>
    <td align="center">1.0</td>
    <td>Minimum in-favor to total votes ratio necessary to start mix.</td>
  </tr>
  <tr>
    <td><code>acer_mix_vote_repeat_delay</code></td>
    <td align="center">integer</td>
    <td align="center">30</td>
    <td align="center">0</td>
    <td align="center">-</td>
    <td>Number of seconds that must elapse before a repeat vote can be started.</td>
  </tr>
</table>
</details>

## Modules

- FakeMeta
- Cstrike
