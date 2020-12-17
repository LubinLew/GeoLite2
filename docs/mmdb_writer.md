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

# API

This class provides the following methods:

## MaxMind::DB::Writer::Tree->new()

This creates a new tree object. The constructor accepts the following parameters:

- ip_version
  
  The IP version for the database. It must be 4 or 6.
  
  This parameter is required.

- record_size
  
  This is the record size in *bits*. This should be one of 24, 28, 32 (in theory any number divisible by 4 up to 128 will work but the available readers all expect 24-32).
  
  This parameter is required.

- database_type
  
  This is a string containing the database type. This can be anything, really. MaxMind uses strings like "GeoIP2-City", "GeoIP2-Country", etc.
  
  This parameter is required.

- languages
  
  This should be an array reference of languages used in the database, like "en", "zh-TW", etc. This is useful as metadata for database readers and end users.
  
  This parameter is optional.

- description
  
  This is a hashref where the keys are language names and the values are descriptions of the database in that language. For example, you might have something like:
  
  `{`
  
   `en` `=>` `'My IP data'``,`
  
   `fr` `=>` `q{Mon Data d'IP}``,`
  
  `}`
  
  This parameter is required.

- map_key_type_callback
  
  This is a subroutine reference that is called in order to determine how to store each value in a map (hash) data structure. See ["DATA TYPES"](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#DATA-TYPES) below for more details.
  
  This parameter is required.

- merge_record_collisions
  
  By default, when an insert collides with a previous insert, the new data simply overwrites the old data where the two networks overlap.
  
  If this is set to true, then on a collision, the writer will merge the old data with the new data. The merge strategy employed is controlled by the `merge_strategy` attribute, described below.
  
  This parameter is optional. It defaults to false unless `merge_strategy` is set to something other than `none`.
  
  This parameter is deprecated. New code should just set `merge_strategy` directly.
  
  **This parameter is deprecated. Use `merge_strategy` instead.**

- merge_strategy
  
  Controls what merge strategy is employed.
  
  - none
    
    No merging will be done. `merge_record_collisions` must either be not set or set to false.
  
  - toplevel
    
    If both data structures are hashrefs then the data from the top level keys in the new data structure are copied over to the existing data structure, potentially replacing any existing values for existing keys completely.
  
  - recurse
    
    Recursively merges the new data structure with the old data structure. Hash values and array elements are either - in the case of simple values - replaced with the new values, or - in the case of complex structures - have their values recursively merged.
    
    For example if this data is originally inserted for an IP range:
    
    `{`
    
     `families` `=> [ {`
    
     `husband` `=>` `'Fred'``,`
    
     `wife`    `=>` `'Wilma'``,`
    
     `}, ],`
    
     `year` `=> 1960,`
    
    `}`
    
    And then this subsequent data is inserted for a range covered by the previous IP range:
    
    `{`
    
     `families` `=> [ {`
    
     `wife`    `=>` `'Wilma'``,`
    
     `child`   `=>` `'Pebbles'``,`
    
     `}, {`
    
     `husband` `=>` `'Barney'``,`
    
     `wife`    `=>` `'Betty'``,`
    
     `child`   `=>` `'Bamm-Bamm'``,`
    
     `}, ],`
    
     `company` `=>` `'Hanna-Barbera Productions'``,`
    
    `}`
    
    Then querying within the range will produce the results:
    
    `{`
    
     `families` `=> [ {`
    
     `husband` `=>` `'Fred'``,`
    
     `wife`    `=>` `'Wilma'``,` `# note replaced value`
    
     `child`   `=>` `'Pebbles'``,`
    
     `}, {`
    
     `husband` `=>` `'Barney'``,`
    
     `wife`    `=>` `'Betty'``,`
    
     `child`   `=>` `'Bamm-Bamm'``,`
    
     `}, ],`
    
     `year` `=> 1960,`
    
     `company` `=>` `'Hanna-Barbera Productions'``,`
    
    `}`
  
  - add-only-if-parent-exists
    
    With this merge strategy, data will only be inserted when there is already a record for the network (or sub-network). Similarly, when merging the data record with an existing data record, no new hash or array references will be created within the data record for the new data. For instance, if the original data record is `{parent_a =` {sibling => 1}}> and `{parent_a =` {child_a => 1}, parent_b => {child_b => 1}}> is inserted, only `child_a`, not `child_b`, will appear in the merged record.
    
    This option is intended to be used when inserting data that supplements existing data but that is not independently useful.

  In all merge strategies attempting to merge two differing data structures causes an exception.

  This parameter is optional. If `merge_record_collisions` is true, this defaults to `toplevel`; otherwise, it defaults to `none`.

- alias_ipv6_to_ipv4
  
  If this is true then the final database will map some IPv6 ranges to the IPv4 range. These ranges are:
  
  - ::ffff:0:0/96
    
    This is the IPv4-mapped IPv6 range
  
  - 2001::/32
    
    This is the Teredo range. Note that lookups for Teredo ranges will find the Teredo server's IPv4 address, not the client's IPv4.
  
  - 2002::/16
    
    This is the 6to4 range

  When aliasing is enabled, insertions into the aliased locations will throw an exception. Inserting a network containing them does not throw an exception, but no information will be stored for the aliased locations.

  To insert an IPv4 address, insert it using IPv4 notation or insert directly into ::/96.

  Aliased nodes are *not* followed when merging nodes. Only merges into the original IPv4 location, ::/96, will be followed.

  This parameter is optional. It defaults to false.

- remove_reserved_networks
  
  If this is true, reserved networks may not be inserted.
  
  Attempts to insert these networks or any inside them will be silently ignored. Inserting a network containing them does not throw an exception, but no information will be stored for the reserved sections.
  
  Reserved networks that are globally routable to an individual device, such as Teredo, may still be added.
  
  This parameter is optional. It defaults to true.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Einsert_network(-$network,-$data,-$additional_args-))$tree->insert_network( $network, $data, $additional_args )

This method expects two parameters. The first is a network in CIDR notation. The second can be any Perl data structure (except a coderef, glob, or filehandle).

The `$data` payload is encoded according to the [MaxMind DB database format spec](http://maxmind.github.io/MaxMind-DB/). The short overview is that anything that can be encoded in JSON can be stored in an MMDB file. It can also handle unsigned 64-bit and 128-bit integers if they are passed as [Math::UInt128](https://metacpan.org/pod/Math::Int128) objects.

`$additional_args` is a hash reference containing additional arguments that change the behavior of the insert. The following arguments are supported:

- `merge_strategy`
  
  When set, the tree's default merge strategy will be overridden for the insertion with this merge strategy.

- `force_overwrite`
  
  This make the merge strategy for the insert `none`.
  
  **This option is deprecated.**

- `insert_only_if_parent_exists`
  
  This make the merge strategy for the insert `add-only-if-parent-exists`.
  
  **This option is deprecated.**

### [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#Insert-Order,-Merging,-and-Overwriting)Insert Order, Merging, and Overwriting

When `merge_strategy` is *none*, the last insert "wins". This means that if you insert `1.2.3.255/32` and then `1.2.3.0/24`, the data for `1.2.3.255/24` will overwrite the data you previously inserted for `1.2.3.255/232`. On the other hand, if you insert `1.2.3.255/32` last, then the tree will be split so that the `1.2.3.0 - 1.2.3.254` range has different data than `1.2.3.255`.

In this scenario, if you want to make sure that no data is overwritten then you need to sort your input by network prefix length.

When `merge_strategy` is not *none*, then records will be merged based on the particular strategy. For instance, the `1.2.3.255/32` network will end up with its data plus the data provided for the `1.2.3.0/24` network, while `1.2.3.0 - 1.2.3.254` will have the expected data. The merge strategy can be changed on a per-insert basis by using the `merge_strategy` argument when inserting a network as discussed above.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Einsert_range(-$first_ip,-$last_ip,-$data,-$additional_args-))$tree->insert_range( $first_ip, $last_ip, $data, $additional_args )

This method is similar to `insert_network()`, except that it takes an IP range rather than a network. The first parameter is the first IP address in the range. The second is the last IP address in the range. The third is a Perl data structure containing the data to be inserted. The final parameter are additional arguments, as outlined for `insert_network()`.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Eremove_network(-$network-))$tree->remove_network( $network )

This method removes the network from the database. It takes one parameter, the network in CIDR notation.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Ewrite_tree($fh))$tree->write_tree($fh)

Given a filehandle, this method writes the contents of the tree as a MaxMind DB database to that filehandle.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Eiterate($object))$tree->iterate($object)

This method iterates over the tree by calling methods on the passed object. The object must have at least one of the following three methods: `process_empty_record`, `process_node_record`, `process_data_record`.

The iteration is done in depth-first order, which means that it visits each network in order.

Each method on the object is called with the following position parameters:

- The node number as a 64-bit number.

- A boolean indicating whether or not this is the right or left record for the node. True for right, false for left.

- The first IP number in the node's network as a 128-bit number.

- The prefix length for the node's network.

- The first IP number in the record's network as a 128-bit number.

- The prefix length for the record's network.

If the record is a data record, the final argument will be the Perl data structure associated with the record.

The record's network is what matches with a given data structure for data records.

For node (and alias) records, the final argument will be the number of the node that this record points to.

For empty records, there are no additional arguments.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Efreeze_tree($filename))$tree->freeze_tree($filename)

Given a file name, this method freezes the tree to that file. Unlike the `write_tree()` method, this method does write out a MaxMind DB file. Instead, it writes out something that can be quickly thawed via the `MaxMind::DB::Writer::Tree->new_from_frozen_tree` constructor. This is useful if you want to pass the in-memory representation of the tree between processes.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Eip_version())$tree->ip_version()

Returns the tree's IP version, as passed to the constructor.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Erecord_size())$tree->record_size()

Returns the tree's record size, as passed to the constructor.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Emerge_record_collisions())$tree->merge_record_collisions()

Returns a boolean indicating whether the tree will merge colliding records, as determined by the merge strategy.

**This is deprecated.**

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Emerge_strategy())$tree->merge_strategy()

Returns the merge strategy used when two records collide.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Emap_key_type_callback())$tree->map_key_type_callback()

Returns the callback used to determine the type of a map's values, as passed to the constructor.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Edatabase_type())$tree->database_type()

Returns the tree's database type, as passed to the constructor.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Elanguages())$tree->languages()

Returns the tree's languages, as passed to the constructor.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Edescription())$tree->description()

Returns the tree's description hashref, as passed to the constructor.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#$tree-%3Ealias_ipv6_to_ipv4())$tree->alias_ipv6_to_ipv4()

Returns a boolean indicating whether the tree will alias some IPv6 ranges to their corresponding IPv4 ranges when the tree is written to disk.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#MaxMind::DB::Writer::Tree-%3Enew_from_frozen_tree())MaxMind::DB::Writer::Tree->new_from_frozen_tree()

This method constructs a tree from a file containing a frozen tree.

This method accepts the following parameters:

- filename
  
  The filename containing the frozen tree.
  
  This parameter is required.

- map_key_type_callback
  
  This is a subroutine reference that is called in order to determine how to store each value in a map (hash) data structure. See ["DATA TYPES"](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#DATA-TYPES) below for more details.
  
  This needs to be passed because subroutine references cannot be reliably serialized and restored between processes.
  
  This parameter is required.

- database_type
  
  Override the `<database_type`> of the frozen tree. This accepts a string of the same form as the `<new()`> constructor.
  
  This parameter is optional.

- description
  
  Override the `<description`> of the frozen tree. This accepts a hashref of the same form as the `<new()`> constructor.
  
  This parameter is optional.

- merge_strategy
  
  Override the `<merge_strategy`> setting for the frozen tree.
  
  This parameter is optional.

## [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#Caveat-for-Freeze/Thaw)Caveat for Freeze/Thaw

The frozen tree is more or less the raw C data structures written to disk. As such, it is very much not portable, and your ability to thaw a tree on a machine not identical to the one on which it was written is not guaranteed.

In addition, there is no guarantee that the freeze/thaw format will be stable across different versions of this module.

# [](https://metacpan.org/pod/MaxMind::DB::Writer::Tree#DATA-TYPES)DATA TYPES

The MaxMind DB file format is strongly typed. Because Perl is not strongly typed, you will need to explicitly specify the types for each piece of data. Currently, this class assumes that your top-level data structure for an IP address will always be a map (hash). You can then provide a `map_key_type_callback` subroutine that will be called as the data is serialized. This callback is given a key name and is expected to return that key's data type.

Let's use the following structure as an example:

`{`

 `names` `=> {`

 `en` `=>` `'United States'``,`

 `es` `=>` `'Estados Unidos'``,`

 `},`

 `population`    `=> 319_000_000,`

 `fizzle_factor` `=> 65.7294,`

 `states`        `=> [` `'Alabama'``,` `'Alaska'``, ... ],`

`}`

Given this data structure, our `map_key_type_callback` might look something like this:

`my` `%types` `= (`

 `names`         `=>` `'map'``,`

 `en`            `=>` `'utf8_string'``,`

 `es`            `=>` `'utf8_string'``,`

 `population`    `=>` `'uint32'``,`

 `fizzle_factor` `=>` `'double'``,`

 `states`        `=> [` `'array'``,` `'utf8_string'` `],`

`);`

`sub` `{`

 `my` `$key` `=` `shift``;`

 `return` `$type``{``$key``};`

`}`

If the callback returns `undef`, the serialization code will throw an error. Note that for an array we return a 2 element arrayref where the first element is `'array'` and the second element is the type of content in the array.

The valid types are:

- utf8_string

- uint16

- uint32

- uint64

- uint128

- int32

- double
  
  64 bits of precision.

- float
  
  32 bits of precision.

- boolean

- map

- array
