#!/bin/bash

PATH="/usr/bin:$PATH"

NOUN=$(shuf -n 1 words.txt)
VERB=$(curl -s https://api.datamuse.com/words\?rel_bgb\=$NOUN\&md\=p | jq '.[] | select(.tags[0]=="v") | .word ' | tr -d \" | awk 'length($0) > 3' | shuf -n 1)
[ -z "$VERB" ] && VERB=$(curl -s https://api.datamuse.com/words\?rel_bgb\=$NOUN\&md\=p | jq '.[] | select(.tags[0]=="v") | .word ' | tr -d \" | shuf -n 1)
CONJUGATION=$(wget -qO - http://conjugator.reverso.net/conjugation-english-verb-$VERB.html | sed -n "/>Present\| >Preterite</{s@<[^>]*>@ @g;s/\s\+/ /g;p}" | awk 'match($0, /he\/she\/it (.*) we/, a) { print a[1]}' | cut -f 1 -d " ")

convert -size 600x200 \
xc:white \
-fill "rgb(82,134,215)" \
-draw 'color 0,0 reset' \
-fill white \
-pointsize 28 \
-font ./roboto.ttf \
-draw "text 40, 55 'Select any square that $CONJUGATION'" \
-pointsize 36 \
-font ./roboto-bold.ttf \
-draw "text 40, 100 '$NOUN'" \
-pointsize 28 \
-font ./roboto.ttf \
-draw "text 40, 140 'Click verify once there are none left.'" \
head.png

curl -sL https://source.unsplash.com/600x600 | \
convert -size 600x600 - \
-stroke white -strokewidth 3 \
-draw "line 149,0 149,600" \
-draw "line 299,0 299,600" \
-draw "line 449,0 449,600" \
-draw "line 0,149 600,149" \
-draw "line 0,299 600,299" \
-draw "line 0,449 600,449" \
grid.png

convert -size 600x100 \
	xc:white \
  -fill "rgb(82, 134, 215)" \
	-stroke "rgb(82, 134, 215)" \
	-draw "rectangle 451,10 590,90" \
	-font ./roboto.ttf \
	-pointsize 28 \
  -stroke white \
	-fill white \
	-draw "text 472, 60 'VERIFY'" \
button.png

convert head.png grid.png button.png \
 -background white \
 -bordercolor white \
 -splice 10x10+0+0 \
 -append \
 -chop 10x10+0+0 \
 -border 10x10 \
 result.png
