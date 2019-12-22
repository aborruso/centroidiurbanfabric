#!/bin/bash

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set -x

mkdir -p "$folder"/processing "$folder"/output

rm "$folder"/processing/*
rm "$folder"/output/*

# `mapshaper data/CLC18_IT.shp -filter-fields CODE_18 -simplify 0.8 visvalingam -o data/corine_2018.topojson`

# estrai "Continuous urban fabric" e "Discontinuous urban fabric" e fanne il dissolve
mapshaper "$folder"/data/corine_2018.topojson -filter 'CODE_18 == "111"' -dissolve2 -proj from=EPSG:32632 -o "$folder"/processing/111.shp
mapshaper "$folder"/data/corine_2018.topojson -filter 'CODE_18 == "112"' -dissolve2 -proj from=EPSG:32632 -o "$folder"/processing/112.shp

# clippa i limiti comunali ISTAT con 111 e 112
mapshaper "$folder"/data/Comuni01012019_g_WGS84.topojson -clip "$folder"/processing/111.shp -explode -each 'code="111"' -proj from=EPSG:32632 -o "$folder"/processing/comuni_111.shp
mapshaper "$folder"/data/Comuni01012019_g_WGS84.topojson -clip "$folder"/processing/112.shp -explode -each 'code="112"' -proj from=EPSG:32632 -o "$folder"/processing/comuni_112.shp

# se allo stesso comune sono associati più poligoni con lo stesso codice Corine, estrai quello di area maggiore
mapshaper "$folder"/processing/comuni_111.shp -each "this.PRO_COM_T" -sort "this.area" descending -uniq "PRO_COM_T" -o "$folder"/processing/out_111.shp
mapshaper "$folder"/processing/comuni_112.shp -each "this.PRO_COM_T" -sort "this.area" descending -uniq "PRO_COM_T" -o "$folder"/processing/out_112.shp

# combina i poligoni 111 e 112 dei vari comuni in unico layer
mapshaper -i "$folder"/processing/out_111.shp "$folder"/processing/out_112.shp combine-files -merge-layers -o "$folder"/processing/comuni_11X.shp

# se allo stesso comune sono associati più poligoni con diverso codice Corine (111 o 112), estrai quello con codice 111
mapshaper "$folder"/processing/comuni_11X.shp -each "this.PRO_COM_T" -sort "this.code" ascending -uniq "PRO_COM_T" -o "$folder"/processing/out_11X.shp

# estrai per ogni comune, un punto che ricada all'interno del poligono classificato come "Urban fabric"; in CSV e in shp in EPSG:4326
mapshaper "$folder"/processing/out_11X.shp -proj wgs84 -each 'x=this.innerX,y=this.innerY' -each 'delete area' -o "$folder"/output/comuni_11X.csv
mapshaper "$folder"/processing/out_11X.shp -points inner -proj wgs84 -o "$folder"/output/comuni_11X.geojson

# estrai comuni senza 111 e 112 associati
mapshaper "$folder"/data/Comuni01012019_g_WGS84.topojson -proj from=EPSG:32632 \
  -join "$folder"/output/comuni_11X.geojson keys=PRO_COM,PRO_COM \
  -filter 'code != 111' -filter 'code != 112 && code != 111' \
  -each 'delete code' -proj wgs84 -o "$folder"/output/comuni_NO_11X.geojson
mapshaper "$folder"/data/Comuni01012019_g_WGS84.topojson -proj from=EPSG:32632 \
  -join "$folder"/output/comuni_11X.geojson keys=PRO_COM,PRO_COM \
  -filter 'code != 112 && code != 111' \
  -each 'delete code' -o "$folder"/output/comuni_NO_11X.csv

# estrai comuni con 111 e 112 associati
mapshaper "$folder"/data/Comuni01012019_g_WGS84.topojson -proj from=EPSG:32632 \
  -join "$folder"/output/comuni_11X.geojson keys=PRO_COM,PRO_COM \
  -filter 'code == "112" || code == "111"' \
  -each 'delete code' -proj wgs84 -o "$folder"/output/comuni_11X_poly.geojson
