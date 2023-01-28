#!/usr/bin/bash
cd `dirname $0`
set -e
#####################################################

yum install -y cpanminus perl
cpanm MaxMind::DB::Writer cpanm Text::CSV

./rebuild.pl

