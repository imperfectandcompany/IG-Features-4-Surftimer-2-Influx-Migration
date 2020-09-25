# clearing all the influx data that may exist


TRUNCATE REPLACEWDBNAME.inf_maps;
# populate the influx maps table
INSERT INTO REPLACEWDBNAME.inf_maps (mapname)
SELECT DISTINCT mapname FROM igfastdl_surftimer.ck_zones;

TRUNCATE REPLACEWDBNAME.inf_runs;

INSERT INTO REPLACEWDBNAME.inf_runs (mapid, runid, rundata)
SELECT
    join_runs.mapid,
    join_runs.zonegroup+1,
CONCAT(
    CASE
        WHEN join_runs.zonegroup = 0 THEN '"Main"'
        ELSE CONCAT('"Bonus #', join_runs.zonegroup, '"')
    END,
' {
 	"id"		"', join_runs.zonegroup+1, '"
 	"resflags"		"0"
 	"modeflags"		"0"
 }
 ')

FROM(
     SELECT DISTINCT inf_maps.mapid, ck_zones.zonegroup FROM igfastdl_surftimer.ck_zones JOIN REPLACEWDBNAME.inf_maps ON inf_maps.mapname = ck_zones.mapname
    ) as join_runs;


TRUNCATE REPLACEWDBNAME.inf_zones;
INSERT INTO REPLACEWDBNAME.inf_zones (mapid, zoneid, zonedata)
SELECT
    REPLACEWDBNAME.inf_maps.mapid, # mapid
    igfastdl_surftimer.ck_zones.zoneid+1, # zoneid (add 1 because surftimer starts at 0 which is invalid in influx)
CONCAT(
    # Zone name
    CASE
        WHEN zonegroup = 0 THEN '"Main'
        ELSE CONCAT('"Bonus #', zonegroup)
    END,
    ' ',
    CASE
        WHEN ck_zones.zonetype IN (1, 5) THEN 'Start'
        WHEN ck_zones.zonetype = 3 THEN CONCAT('Stage ', ck_zones.zonetypeid+2)
        WHEN ck_zones.zonetype = 2 THEN 'End'
        WHEN ck_zones.zonetype = 0 THEN 'Block'
        WHEN ck_zones.zonetype = 6 THEN 'Block'
        ELSE 'Block'
    END
, '"
 {
 	"run_id"		"', ck_zones.zonegroup+1, '"
 	"id"		"', igfastdl_surftimer.ck_zones.zoneid+1, '"
 	"type"		"',
    CASE
        WHEN ck_zones.zonetype IN (1, 5) THEN 'start'
        WHEN ck_zones.zonetype = 3 THEN 'stage'
        WHEN ck_zones.zonetype = 2 THEN 'end'
        WHEN ck_zones.zonetype = 0 THEN 'block'
        WHEN ck_zones.zonetype = 6 THEN 'block'
        WHEN ck_zones.zonetype = 4 THEN 'checkpoint'
        ELSE 'block'
    END
    ,'"
',
CASE
WHEN ck_zones.zonetype = 3 THEN
    CONCAT(
' 	"stage_num"		"', ck_zones.zonetypeid+2, '"
 	"stage_telepos"		"', (ck_zones.pointa_x + ck_zones.pointb_x) / 2, ' ', (ck_zones.pointa_y + ck_zones.pointb_y) / 2, ' ', (ck_zones.pointa_z + ck_zones.pointb_z) / 2,'"'
        )
WHEN ck_zones.zonetype = 0 THEN
' 	"punishtype"		"disabletimer"'
WHEN ck_zones.zonetype = 6 THEN
' 	"punishtype"		"teletostart"'
WHEN ck_zones.zonetype = 4 THEN
CONCAT(' 	"cp_num"		"', ck_zones.zonetypeid+1, '"')
ELSE ''
END,
'
',
' 	"mins"		"', LEAST(ck_zones.pointa_x, ck_zones.pointb_x), ' ', LEAST(ck_zones.pointa_y, ck_zones.pointb_y), ' ', LEAST(ck_zones.pointa_z, ck_zones.pointb_z),'"
 	"maxs"		"', GREATEST(ck_zones.pointa_x, ck_zones.pointb_x), ' ', GREATEST(ck_zones.pointa_y, ck_zones.pointb_y), ' ', GREATEST(ck_zones.pointa_z, ck_zones.pointb_z),'"
 }
 ')
FROM igfastdl_surftimer.ck_zones JOIN REPLACEWDBNAME.inf_maps WHERE inf_maps.mapname = ck_zones.mapname;



#
#  PLAYERS
#

TRUNCATE REPLACEWDBNAME.inf_users;

INSERT INTO REPLACEWDBNAME.inf_users (steamid, name, joindate)
SELECT
    p.steamid,
    p.name,
    FROM_UNIXTIME(p.joined)
FROM
        igfastdl_surftimer.ck_playerrank p
    INNER JOIN
        ( SELECT
              steamid, MAX(joined) AS latest
          FROM
              igfastdl_surftimer.ck_playerrank
          GROUP BY
              steamid
        ) AS groupedp
      ON  groupedp.steamid = p.steamid
      AND groupedp.latest = p.joined;


#### MAIN TIMES
TRUNCATE REPLACEWDBNAME.inf_times;

INSERT INTO REPLACEWDBNAME.inf_times (uid, mapid, runid, mode, style, rectime, recdate)
SELECT
    inf_users.uid,
    inf_maps.mapid,
    1, # RUN ID 1 == Main
    0, # MODE !!! surftimer doesn't have equivalent for "mode"
    CASE # Style ID mapping from Surftimer to Influx
        WHEN ck_playertimes.style = 0 THEN 0 # Normal
        WHEN ck_playertimes.style = 1 THEN 1 # Sideways
        WHEN ck_playertimes.style = 2 THEN 4 # HSW
        WHEN ck_playertimes.style = 3 THEN 7 # Backwards
        WHEN ck_playertimes.style = 4 THEN 6 # Low G
    END,
    ck_playertimes.runtimepro,
    CURRENT_DATE()

FROM igfastdl_surftimer.ck_playertimes
    JOIN REPLACEWDBNAME.inf_users ON ck_playertimes.steamid = inf_users.steamid
    JOIN REPLACEWDBNAME.inf_maps ON ck_playertimes.mapname = inf_maps.mapname
WHERE ck_playertimes.style IN (0, 1, 2, 3, 4)
# ORDER BY RAND()
# LIMIT 1000
;


### BONUS TIMES
INSERT INTO REPLACEWDBNAME.inf_times (uid, mapid, runid, mode, style, rectime, recdate)
SELECT
    inf_users.uid,
    inf_maps.mapid,
    ck_bonus.zonegroup+1,
    0, # MODE !!! surftimer doesn't have equivalent for "mode"
    CASE # Style ID mapping from Surftimer to Influx
        WHEN ck_bonus.style = 0 THEN 0 # Normal
        WHEN ck_bonus.style = 1 THEN 1 # Sideways
        WHEN ck_bonus.style = 2 THEN 4 # HSW
        WHEN ck_bonus.style = 3 THEN 7 # Backwards
        WHEN ck_bonus.style = 4 THEN 6 # Low G
    END,
    ck_bonus.runtime,
    CURRENT_DATE()

FROM igfastdl_surftimer.ck_bonus
    JOIN REPLACEWDBNAME.inf_users ON ck_bonus.steamid = inf_users.steamid
    JOIN REPLACEWDBNAME.inf_maps ON ck_bonus.mapname = inf_maps.mapname
WHERE ck_bonus.style IN (0, 1, 2, 3, 4)
# ORDER BY RAND()
# LIMIT 1000
;

### Change inf_users to dummy accounts, so they won't match real steamIDs
UPDATE REPLACEWDBNAME.inf_users
SET steamid = CONCAT('[OLD] ', steamid), name = CONCAT('[OLD] ', name);

##### CP time query takes far too long to run, we've decided to ditch this table
/*
TRUNCATE REPLACEWDBNAME.inf_cptimes;
INSERT INTO REPLACEWDBNAME.inf_cptimes (uid, mapid, runid, mode, style, cpnum, cptime)
SELECT
    inf_users.uid,
    inf_maps.mapid,
    1, # RUN ID 1 == Main !!! FIX THIS,
    0, # MODE !!! fix?
    CASE # Style ID mapping from Surftimer to Influx
        WHEN ck_wrcps.style = 0 THEN 0 # Normal
        WHEN ck_wrcps.style = 1 THEN 1 # Sideways
        WHEN ck_wrcps.style = 2 THEN 4 # HSW
        WHEN ck_wrcps.style = 3 THEN 7 # Backwards
        WHEN ck_wrcps.style = 4 THEN 6 # Low G
        END,
    ck_wrcps.stage,
    ck_wrcps.runtimepro

FROM igfastdl_surftimer.ck_wrcps
    JOIN REPLACEWDBNAME.inf_maps ON ck_wrcps.mapname = inf_maps.mapname
    JOIN REPLACEWDBNAME.inf_users ON ck_wrcps.steamid = inf_users.steamid
WHERE ck_wrcps.style IN (0, 1, 2, 3, 4)
AND ck_wrcps.mapname = 'surf_beginner'
# ORDER BY RAND()
LIMIT 1000
;




/*

SELECT
    inf_users.uid,
    inf_maps.mapid,
    source_table.runtimepro
    #source_table.stage

FROM igfastdl_surftimer.ck_playertimes AS source_table
    JOIN REPLACEWDBNAME.inf_users ON source_table.steamid = inf_users.steamid
    JOIN REPLACEWDBNAME.inf_maps ON source_table.mapname = inf_maps.mapname
    JOIN (SELECT RANGE(100), *) AS stage_nums ON stage_nums.num
WHERE source_table.style IN (0, 1, 2, 3, 4)
;
