#!/bin/bash


echo '--- help option ---'

bash $1 -h  > /dev/null
echo -n $?

bash $1 --help > /dev/null
echo -n $?

bash $1 -h a > /dev/null
echo -n $?

bash $1 --help a > /dev/null
echo -n $?

echo -e "\n0011"

echo '--- build command ---'

touch f1
mkdir d1

bash $1 build --output f0 d1 > /dev/null
echo -n $?

bash $1 build --output f1 d1 > /dev/null
echo -n $?

bash $1 build --output f0 d0 > /dev/null
echo -n $?

bash $1 build --output f1 d0 > /dev/null
echo -n $?

echo -e "\n0011"

echo '--- gen-proof command ---'

touch f2

bash $1 gen-proof --output f0 --tree f2 d1 > /dev/null
echo -n $?

bash $1 gen-proof --output f1  --tree f2 d1 > /dev/null
echo -n $?

bash $1 gen-proof --output f0 --tree f0 d1 > /dev/null
echo -n $?

bash $1 gen-proof --output f1 --tree f0 d1 > /dev/null
echo -n $?

echo -e "\n0011"

echo '--- verify-proof ---'

bash $1 verify-proof --proof f1 --root 0a f1 > /dev/null
echo -n $?

bash $1 verify-proof --proof f1  --root 0A f1 > /dev/null
echo -n $?

bash $1 verify-proof --proof f0 --root 0a f1 > /dev/null
echo -n $?

bash $1 verify-proof --proof f0 --root 0A f1 > /dev/null
echo -n $?

bash $1 verify-proof --proof f1 --root 0aA f1 > /dev/null
echo -n $?

bash $1 verify-proof --proof f1  --root 0aA f1 > /dev/null
echo -n $?

echo -e "\n001111"

rm f1 f2
rm -r d1
