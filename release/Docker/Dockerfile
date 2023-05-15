FROM alpine:3.17


RUN apk add build-base perl perl-dev perl-app-cpanminus perl-app-cpanminus-https

RUN cpanm -n -f -q Text::CSV
RUN cpanm -n -f -q MaxMind::DB::Writer
