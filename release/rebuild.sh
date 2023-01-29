#!/usr/bin/bash
cd `dirname $0`
set -e
#####################################################

if which dpkg &> /dev/null; then
  INSTALLER="apt"
else
  INSTALLER="yum"
fi



${INSTALLER} install -y cpanminus perl
cpanm MaxMind::DB::Writer cpanm Text::CSV



./rebuild.pl

