#!/usr/bin/perl

use utf8;
use Text::CSV;
use MaxMind::DB::Writer::Tree;

use open qw(:std :encoding(UTF-8));

# 声明数据结构中的数据类型
my %types = (
    country       => 'map',
    city         => 'map',
    names        => 'map',
    continent    => 'map',
    location     => 'map',
    latitude     => 'double',
    longitude    => 'double',
    time_zone    => 'utf8_string',
    'zh-CN'      => 'utf8_string',
    'en'         => 'utf8_string',
    subdivisions => ['array', 'map'],
);


# 创建树
my $tree = MaxMind::DB::Writer::Tree->new(
    ip_version            => 4,
    record_size           => 28,
    database_type         => 'GeoLite2-City',
    languages             => ['zh-CN'],
    description           => { en => 'GeoLite2 City database', 'zh-CN' => "GeoCity中文" },
    map_key_type_callback => sub { $types{ $_[0] } },
    merge_strategy        => recurse,
    alias_ipv6_to_ipv4    => 1,
    remove_reserved_networks => 0
);

sub insert_cidr_and_info {

    my %geoinfo;

    if ($_[1]{country_name}) {
        $geoinfo{country} = {
            names => {
               'en' => $_[1]{country_name}
            }
        }
    }

    if ( $_[1]{subdivision_1_name} ) {
        $geoinfo{subdivisions} = [ {
            names => {
               'en' => $_[1]{subdivision_1_name}
            }
        }]
    }

    if ($_[1]{city_name}) {
        $geoinfo{city} = {
            names => {
                'en' => $_[1]{city_name}
            }
        }
    }

    if ($_[1]{continent_name}) {
        $geoinfo{continent} = {
            names => {
                'en' => $_[1]{continent_name}
            }
        }
    }

    if ($_[1]{time_zone}) {
        $geoinfo{location} = {
            'time_zone' => $_[1]{time_zone},
            latitude => $_[2],
            longitude => $_[3],
        }
    }

    #$json = JSON->new->utf8;
    #print "scalar var: ", $json->encode({%geoinfo}),"\n";

    $tree->insert_network($_[0], {%geoinfo});
}

# 插入保留地址
insert_cidr_and_info('10.0.0.0/8',     {continent_name => "*", country_name => "局域网", subdivision_1_name => "局域网", city_name => "局域网"});
insert_cidr_and_info('172.16.0.0/12',  {continent_name => "*", country_name => "局域网", subdivision_1_name => "局域网", city_name => "局域网"});
insert_cidr_and_info('192.168.0.0/16', {continent_name => "*", country_name => "局域网", subdivision_1_name => "局域网", city_name => "局域网"});
insert_cidr_and_info('127.0.0.1/8',    {continent_name => "*", country_name => "本机",   subdivision_1_name => "本机",   city_name => "本机"});

my $csv = Text::CSV->new ({
    binary                => 1,
    decode_utf8           => 1,
    auto_diag             => 1,
    diag_verbose          => 1,
    allow_loose_quotes    => 1,
    allow_loose_escapes   => 1,
    allow_unquoted_escape => 1,
    });

my $ipv4_block_file  = 'GeoLite2-City-Blocks-IPv4.csv';
my $location_file_en = 'GeoLite2-City-Locations-en.csv';
my $location_file_cn = 'GeoLite2-City-Locations-zh-CN.csv';

my $first = 1;
my %locationdb;

# 加载处理 Location-EN 文件
open(my $en_data, '<', $location_file_en) or die "Could not open '$location_file_en' $!\n";
while (my $line = <$en_data>) {
    if($first) {#skip first line
        $first = 0;
    } else {
        if ($csv->parse($line)) {
            my @fields = $csv->fields();
            $locationdb{$fields[0]} = {
                continent_name     => $fields[3]  ? $fields[3] :  'N/A',
                country_name       => $fields[5]  ? $fields[5] :  'N/A',
                subdivision_1_name => $fields[7]  ? $fields[7] :  'N/A',
                subdivision_2_name => $fields[9]  ? $fields[9] :  'N/A',
                city_name          => $fields[10] ? $fields[10] : 'N/A',
                time_zone          => $fields[12] ? $fields[10] : 'N/A',
            }
        } else {
            warn "Line could not be parsed: $line\n";
        }
    }
}

print("$location_file_en finished !\n");

# 加载处理 Location-zh-CN 文件, 如果存在中文存覆盖英文
$first = 1;
open(my $cn_data, '<', $location_file_cn) or die "Could not open '$location_file_cn' $!\n";
while (my $line = <$cn_data>) {
    if($first) {#skip first line
        $first = 0;
    } else {
        if ($csv->parse($line)) {
            my @fields = $csv->fields();
            if ($locationdb{$fields[0]}) {
                if ($fields[3]) {
                    $locationdb{$fields[0]}{continent_name} = $fields[3];
                }
                if ($fields[5]) {
                    $locationdb{$fields[0]}{country_name} = $fields[5];
                }
                if ($fields[7]) {
                    $locationdb{$fields[0]}{subdivision_1_name} = $fields[7];
                }
                if ($fields[9]) {
                    $locationdb{$fields[0]}{subdivision_2_name} = $fields[9];
                }
                if ($fields[10]) {
                    $locationdb{$fields[0]}{city_name} = $fields[10];
                }
            } else {
                warn "no match line: $line\n"
            }
        } else {
            warn "Line could not be parsed: $line\n";
        }
    }
}
print("$location_file_cn finished !\n");

# 加载处理 Blocks-IPv4 文件
$first = 1;
open(my $ipv4_data, '<', $ipv4_block_file) or die "Could not open '$ipv4_block_file' $!\n";
while (my $line = <$ipv4_data>) {
    if ($first) {#skip first line
        $first = 0;
    } else {
        chomp $line;
        if ($csv->parse($line)) {
            my @fields = $csv->fields();
            my $key;
            if ($fields[1]) {
                $key = $fields[1]
            } else {
                $key = $fields[2]
            }
            if ($locationdb{$key}) {
                if (length $fields[7] == 0){
                    $fields[7] = 0.00000
                }
                if (length $fields[8] == 0){
                    $fields[8] = 0.00000
                }

                insert_cidr_and_info($fields[0], $locationdb{$key}, $fields[7], $fields[8]);
            } else {
                warn "$fields[0] no match\n";
            }
        } else {
            warn "Line could not be parsed: $line\n";
        }
    }
}
print("$ipv4_block_file finished !\n");


open my $fh, '>:raw', 'result.mmdb';
$tree->write_tree($fh);


