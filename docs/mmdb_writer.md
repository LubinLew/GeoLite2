# 如何制作 mmdb 文件

> [MaxMind-DB-Writer - Create MaxMind DB database files](https://metacpan.org/release/MaxMind-DB-Writer)
> 
> [MaxMind::DB::Writer::Tree - API Doc](https://metacpan.org/pod/MaxMind::DB::Writer::Tree)

mmdb 的制作需要使用官方工具 [MaxMind-DB-Writer-perl](https://github.com/maxmind/MaxMind-DB-Writer-perl)。这是一个 Perl 语言编写的工具。

## 为什么要自己制作 mmdb 文件

- 可以添加自定义配置, 例如官方提供的mmdb中没有保留的局域网地址(10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)

- 可以对官方提供的 mmdb 进行精简, 官方提供的mmdb包含多国语言, city库70M,我们可以只保留中文,减小mmdb文件大小

- 相当于一个通用的搜素模板，可以自己制作其他的搜索数据

## 工具安装

执行下面的命令进行安装，时间可能较长，会自动下载各种依赖包

```bash
yum install -y cpanminus
cpanm MaxMind::DB::Writer
```

另外可以安装 mmdblookup 工具用来做测试

```bash
wget https://github.com/maxmind/libmaxminddb/releases/download/1.4.3/libmaxminddb-1.4.3.tar.gz
tar xf libmaxminddb-1.4.3.tar.gz
cd libmaxminddb-1.4.3
./configure
make
make install
```

## 

## 安装测试

先使用官方例子, 新建一个 test.pl 文件， 写入下面内容

```perl
use MaxMind::DB::Writer::Tree;
 
my %types = (
    color => 'utf8_string',
    dogs  => [ 'array', 'utf8_string' ],
    size  => 'uint16',
);
 
my $tree = MaxMind::DB::Writer::Tree->new(
    ip_version            => 6,
    record_size           => 24,
    database_type         => 'My-IP-Data',
    languages             => ['en'],
    description           => { en => 'My database of IP data' },
    map_key_type_callback => sub { $types{ $_[0] } },
);
 
$tree->insert_network(
    '8.8.8.0/24',
    {
        color => 'blue',
        dogs  => [ 'Fido', 'Ms. Pretty Paws' ],
        size  => 42,
    },
);
 
open my $fh, '>:raw', 'test.mmdb';
$tree->write_tree($fh);
```

执行 `perl test.pl` 生成 test.mmdb 文件，然后使用 mmdblookup 工具查看

```bash
mmdblookup -f test.mmdb --ip 8.8.8.8 -v

  Database metadata
    Node count:    353
    Record size:   24 bits
    IP version:    IPv6
    Binary format: 2.0
    Build epoch:   1608085675 (2020-12-16 02:27:55 UTC)
    Type:          My-IP-Data
    Languages:     en
    Description:
      en:   My database of IP data


  Record prefix length: 120

  {
    "color": 
      "blue" <utf8_string>
    "dogs": 
      [
        "Fido" <utf8_string>
        "Ms. Pretty Paws" <utf8_string>
      ]
    "size": 
      42 <uint16>
  }
```


