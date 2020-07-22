filepath=$1
from=$2
to=$3
is_add=$4

mode=$(git ls-files -s $filepath | awk '{ print $1 }')
hash=$(git ls-files -s $filepath | awk '{ print $2 }')

git cat-file -p $hash > /tmp/neogitfile

if $is_add; then
  head=$(head -n $(expr $from - 1) /tmp/neogitfile)
  tail=$(tail -n +$(expr $from) /tmp/neogitfile)
  if test "$head" = ''; then
    cat $filepath | head -n $to | tail -n+$from > /tmp/neogitnewfile
    echo "$tail" >> /tmp/neogitnewfile
  elif test "$tail" = ''; then
    echo "$head" > /tmp/neogitnewfile
    cat $filepath | head -n $to | tail -n+$from >> /tmp/neogitnewfile
  else
    echo "$head" > /tmp/neogitnewfile
    cat $filepath | head -n $to | tail -n+$from >> /tmp/neogitnewfile
    echo "$tail" >> /tmp/neogitnewfile
  fi
else
  head=$(head -n $(expr $from - 1) /tmp/neogitfile)
  tail=$(tail -n +$(expr $to + 1) /tmp/neogitfile)
  if test "$head" = ''; then
    echo "$tail" > /tmp/neogitnewfile
  elif test "$tail" = ''; then
    echo "$head" > /tmp/neogitnewfile
  else
    echo "$head" > /tmp/neogitnewfile
    echo "$tail" >> /tmp/neogitnewfile
  fi
fi
newhash=$(git hash-object -w /tmp/neogitnewfile)
git update-index --cacheinfo $mode $newhash $filepath
