***Imperfect Gamers***


Update: We have abandoned this project and started private development for IG.
This will remain public for free-usage.

I will not be providing support unfortunately due to limited time but it does not hurt to shoot me a message if you are stuck.

It is fully working and ready with Influx Timer.


# Custom Modular Plugins
>This repository includes the scripting / translation files for imperfectgamers.org as well as the Influx timer includes necessary for compiling. Only time Influx will get in the way is when the forwards change, which is highly unlikely.
- When installing an update of influx, you'll have to remove one plugin in particular if it is present: influx_simpleranks.
- influx_simpleranks should be kept on the server but requires the convar in server.cfg: influx_simpleranks_useclantag 0 so it doesn't interfere with the VIP scoreboard titles.

Most of these features were decoupled from the modified surftimer by SonicSNES, more information here: https://github.com/imperfectgamers/Surftimer
Part of this process involved the creation of a migration script, will add and update readme tomorrow with it included with steps.

## Features

> Each feature is broken up into components
- [Point Check](#points)
- [Records](#records)
- [Reports](#reports)
- [VIP](#vip)
- [Migration Script](#migration)
- [Converted Features](#converted)
---



## Points
> Configurable point check for skill server. Check client timer points on connect, if they don't have more than a configurable point count, they will be kicked from the server.  If set to 0, all clients can join.
>> *cvar on the test server is ig_pointcheck_min, defaults to 0*
- **Comments**
    - 🍴 Check client timer points on connect
    - 🍴 If they don't have more than a configurable point count, they will be kicked from the server. 
    - 🍴 If set to 0, all clients can join.

## Records
> Configurable point check for skill server. Check client timer points on connect, if they don't have more than a configurable point count, they will be kicked from the server.  If set to 0, all clients can join.
- **Comments**
    - 🍴 ig_records_webhook_announce is the records webhook convar
## Reports
> Allows players to be proactive in documenting important information for us. Gives us something to work with and reference.
- **Comments**   
    - 🍴 ig_reports_webhook_bugs !bugs menu (discord)
    - 🍴 ig_reports_webhook_calladmin !calladmin -> message (discord)
## Vip
> VIP perks are available for players purchase. Provides extra aesthetics and features (no game advantage).
- **Comments**
    - 🍴 VIP Vote Extend cvar: ig_chat_prefix
    - 🍴 Color is formatting available {colourname} 
    - 🍴 !vmute is hooked with sourcebans and is logged to prevent abuse
    - 🍴 !ve runs ExtendMapTimeLimit(600) if vote is passed. Only allowed to initiate the last 5 minutes of timeleft.
    - 🍴 ?!title opens up a menu allowing VIP to cycle through their titles and change their name and text color seperately.
    

## Migration
>Releasing migration script to go from Surftimer to InfluxTimer off of Imperfect Gamers Schema
****Migration script:**
 - Migrate map / bonus zones, and their tp locations
 - Migrate map / bonus / checkpoint times
 - surftimer and influx both have a "points" system, these points can be copied over directly, but may have unintended side effects since the point systems are different.  To do a proper full conversion would be quite complex and therefore add time and cost, not sure if that's worth it for you.
 - surftimer has a more sophisticated custom "zone outlines" structure, while influx has 3 presets "None", "Normal" and "Full", so hidden zone lines can be preserved if that is required but otherwise all will default to "Normal"

## Converted
>Converted timer features:
Loading player VIP status
>VIP titles, and assignable titles including rapper, dj, beat, etc.
 - loading player titles,
 - givetitle, removetitle, nexttitle, mytitle, title Commands
Vmute command
VE extend command

>Discord integrations:
- Record announcements (send a discord message when a new map record is set through influx timer integration)
- Bg report / Call admin (send a message in the #reports channel

All features are preserved as-is with influx compatibility,
Record announcements are modified to integrate with the new timer, but output equivalent messages

---
> Credits
SonicSNES - Custom features and modifications to Surftimer for imperfectgamers.org

- <a href="https://imperfectgamers.org"><img src="https://cdn.imperfectgamers.org/inc/assets/img/textlogo.png" width="15" height="15" title="Imperfect Gamers" alt="Logo"></a> Copyright 2020 © <a href="https://imperfectgamers.org" target="_blank">Imperfect and Company</a>.
