#!/bin/bash

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set -x

# estrai "Continuous urban fabric" e "Discontinuous urban fabric" e fanne il dissolve
mapshaper "$folder"/data/CLC18_IT.shp -filter 'CODE_18 == "111"' -dissolve2 -o "$folder"/output/111.shp
mapshaper "$folder"/data/CLC18_IT.shp -filter 'CODE_18 == "112"' -dissolve2 -o "$folder"/output/112.shp

# clippa i limiti comunali ISTAT con 111 e 112
mapshaper "$folder"/data/Com01012019_g_WGS84.shp -clip "$folder"/output/111.shp -explode -each 'code="111"' -o "$folder"/output/comuni_111.shp
mapshaper "$folder"/data/Com01012019_g_WGS84.shp -clip "$folder"/output/112.shp -explode -each 'code="112"' -o "$folder"/output/comuni_112.shp

# se allo stesso comune sono associati più poligoni con lo stesso codice Corine, estrai quello di area maggiore
mapshaper "$folder"/output/comuni_111.shp -each "this.PRO_COM_T" -sort "this.area" descending -uniq "PRO_COM_T" -o "$folder"/output/out_111.shp
mapshaper "$folder"/output/comuni_112.shp -each "this.PRO_COM_T" -sort "this.area" descending -uniq "PRO_COM_T" -o "$folder"/output/out_112.shp

# combina i poligoni 112 e 112 dei vari comuni in unico layer
mapshaper -i "$folder"/output/out_111.shp "$folder"/output/out_112.shp combine-files -merge-layers -o "$folder"/output/comuni_11X.shp

# se allo stesso comune sono associati più poligoni con diverso codice Corine (111 o 112), estrai quello con codice 111
mapshaper "$folder"/output/comuni_11X.shp -each "this.PRO_COM_T" -sort "this.code" ascending -uniq "PRO_COM_T" -o "$folder"/output/out_11X.shp

# estrai per ogni comune, punto che cade all'interno del poligono classificato come "Urban fabric", in CSV e in GEOJSON in EPSG:4326
mapshaper "$folder"/output/out_11X.shp -proj wgs84 -each 'x=this.innerX,y=this.innerY' -each 'delete area' -o "$folder"/output/comuni_11X.csv
mapshaper "$folder"/output/out_11X.shp -points inner -proj wgs84 -o "$folder"/output/comuni_11X.geojson