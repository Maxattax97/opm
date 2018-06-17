#!/bin/dash

string_array="the;quick;brown;fox"
IFS=';'
for word in $string_array; do
    echo "$word"
done
IFS=' '


echo "$(ls)"
echo `ls`

ls &
echo "forked $!"
