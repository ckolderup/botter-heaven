#!/bin/bash

pic=$1
width=$(identify -format "%w" $pic)
height=$(identify -format "%h" $pic)
new_dim=$((width > height ? width  + 10 : height + 10))
convert -background transparent -gravity "Center" -extent "${new_dim}x${new_dim}" $pic $pic
