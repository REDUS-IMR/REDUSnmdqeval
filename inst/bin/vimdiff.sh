#!/bin/bash
htmldiff () {
vimdiff -c TOhtml -c "wqa $1 | qall\!" $2 $3 &> /dev/null
}

htmldiff $1 $2 $3
