# API - MaxMind::DB::Writer::Tree

建立内存中 MaxMind DB 数据库的树然后将其写入文件

## SYNOPSIS

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

open my $fh, '>:raw', '/path/to/my-ip-data.mmdb';
$tree->write_tree($fh);
```

## API

### MaxMind::DB::Writer::Tree->new()

这将创建一个新的树对象。 构造函数接受以下参数:

- **ip_version** (required)
  
  数据库的 IP 地址版本, 它必须是 4 或 6, 表示 IPv4 或 IPv6。

- **record_size** (required)
  
  用 `bit` 表示的 record size. 取值范围为 24, 28, 32.

- **database_type** (required)
  
  这是一个包含数据库类型的字符串, 可以是任何东西。 MaxMind 使用 "GeoIP2-City"、"GeoIP2-Country" 等字符串。

- **languages** (optional)
  
  首先这是一个数据, 数组的元素为数据库中使用的语言代号，如"en"、"zh-TW"(台湾)等。这对于数据库读者和最终用户来说作为元数据很有用。

- **description** (required)
  
  这是一组键值对(hashref), 键为语言的代号, 值为该种语言描述当前这个的数据的简介,写法如下:
  
  ```perl
  {
      en => 'My IP data',
      fr => q{Mon Data d'IP},
  }
  ```

- **map_key_type_callback** (required)
  
  这是一个子例程(subroutine)引用，它被调用以确定如何将每个值存储在映射（散列）数据结构中。
  
  下面的数据类型章节会详细描述.

- **merge_strategy** (optional)
  
  控制采用什么合并策略.
  
  - ***none*** (default)
    
    什么也不合并, 这是默认选项。
  
  - ***toplevel***
    
    如果两个数据结构都是 hashrefs，那么来自新数据结构中顶级键的数据将被复制到现有数据结构，可能会完全替换现有键的任何现有值。
  
  - ***recurse***
    
    递归地将新数据结构与旧数据结构合并。 哈希值和数组元素要么 - 在简单值的情况下用新值替换，要么在复杂结构的情况下递归合并它们的值。
    
    For example if this data is originally inserted for an IP range:
    
    例如，如果此数据最初是为 IP 范围插入的:
    
    ```perl
    {
        families => [ {
            husband => 'Fred',
            wife    => 'Wilma',
        }, ],
        year => 1960,
    }
    ```
    
    然后为先前 IP 范围所涵盖的范围插入此后续数据:
    
    ```perl
    {
        families => [ {
            wife    => 'Wilma',
            child   => 'Pebbles',
        }, {
            husband => 'Barney',
            wife    => 'Betty',
            child   => 'Bamm-Bamm',
        }, ],
        company => 'Hanna-Barbera Productions',
    }
    ```
    
    然后在范围内查询就会产生结果:
    
    ```perl
    {
        families => [ {
            husband => 'Fred',
            wife    => 'Wilma',    # note replaced value
            child   => 'Pebbles',
        }, {
            husband => 'Barney',
            wife    => 'Betty',
            child   => 'Bamm-Bamm',
        }, ],
        year => 1960,
        company => 'Hanna-Barbera Productions',
    }
    ```
  
  - **add-only-if-parent-exists**
    
    With this merge strategy, data will only be inserted when there is already a record for the network (or sub-network). Similarly, when merging the data record with an existing data record, no new hash or array references will be created within the data record for the new data. For instance, if the original data record is `{parent_a =` {sibling => 1}}> and `{parent_a =` {child_a => 1}, parent_b => {child_b => 1}}> is inserted, only `child_a`, not `child_b`, will appear in the merged record.
    
    此选项旨在插入补充现有数据但不是独立有用的数据时使用。在所有尝试合并两个不同数据结构的合并策略中都会导致异常。

- **alias_ipv6_to_ipv4** (optional)
  
  取值为
  
  如果这是真的，那么最终数据库会将一些 IPv6 范围映射到 IPv4 范围。 这些范围是:
  
  - `::ffff:0:0/96`
    
    这是 IPv4 映射 IPv6 地址的范围, 例如IPv4地址 `17.0.0.1` 映射成IPv6地址为`[::ffff:127.0.0.1]`
  
  - `2001::/32`
    
    这是 Teredo 范围。  Teredo 是一项 IPv6/IPv4 转换技术，能够实现在处于单个或者多个 IPv4 NAT 后的主机之间的 IPv6 自动隧道。来自 Teredo 主机的 IPv6 数据流能够通过 NAT，因为它是以 IPv4 UDP 数据格式发送的。请注意，查找 Teredo 范围将找到 Teredo 服务器的 IPv4 地址，而不是客户端的 IPv4。
  
  - `2002::/16`
    
    这是 6to4 范围, 6to4 定义了一个网络前缀`2002::/16`用于表达这是一个6to4网络整体，任何一个公共IPv4地址将地址的十六进制值加在6to4网络前缀之后，从而产生一个前缀数为48的相应IPv4的6to4子网的网络前缀，而且其仍然可以继续分割至最小前缀数为64的子网段用于区分出这个6to4子网的子网。另外，[RFC](https://baike.baidu.com/item/RFC)[1918](https://baike.baidu.com/item/1918)所定义的专用网络地址不能用于6to4子网的申请，因为通信回应时无法将按照IPv4专用网络地址送回发起处。
  
  启用别名后，插入别名位置将引发异常。 插入包含它们的网络不会引发异常，但不会为别名位置存储任何信息。
  
  要插入 IPv4 地址，请使用 IPv4 表示法插入或直接插入 ::/96。合并节点时*不*跟随别名节点。 只有合并到原始 IPv4 位置 ::/96 才会被遵循。 它默认为假。

- **remove_reserved_networks** (optional)
  
  如果这是真的，则可能不会插入保留网络。
  
  尝试插入这些网络或其中的任何内容将被默默忽略。 插入包含它们的网络不会引发异常，但不会为保留部分存储任何信息。
  
  仍可添加可全局路由到单个设备（例如 Teredo）的保留网络。
  
  它默认为真。

### \$tree->insert_network(\$network, \$data, \$additional_args)

This method expects two parameters. The first is a network in CIDR notation. The second can be any Perl data structure (except a coderef, glob, or filehandle).

The `$data` payload is encoded according to the [MaxMind DB database format spec](http://maxmind.github.io/MaxMind-DB/). The short overview is that anything that can be encoded in JSON can be stored in an MMDB file. It can also handle unsigned 64-bit and 128-bit integers if they are passed as [Math::UInt128](https://metacpan.org/pod/Math::Int128) objects.

`$additional_args` is a hash reference containing additional arguments that change the behavior of the insert. The following arguments are supported:

- `merge_strategy`
  
  When set, the tree's default merge strategy will be overridden for the insertion with this merge strategy.

##### Insert Order, Merging, and Overwriting

When `merge_strategy` is *none*, the last insert "wins". This means that if you insert `1.2.3.255/32` and then `1.2.3.0/24`, the data for `1.2.3.255/24` will overwrite the data you previously inserted for `1.2.3.255/232`. On the other hand, if you insert `1.2.3.255/32` last, then the tree will be split so that the `1.2.3.0 - 1.2.3.254` range has different data than `1.2.3.255`.

In this scenario, if you want to make sure that no data is overwritten then you need to sort your input by network prefix length.

When `merge_strategy` is not *none*, then records will be merged based on the particular strategy. For instance, the `1.2.3.255/32` network will end up with its data plus the data provided for the `1.2.3.0/24` network, while `1.2.3.0 - 1.2.3.254` will have the expected data. The merge strategy can be changed on a per-insert basis by using the `merge_strategy` argument when inserting a network as discussed above.

### \$tree->insert_range(\$first_ip, \$last_ip, \$data, \$additional_args )

This method is similar to `insert_network()`, except that it takes an IP range rather than a network. The first parameter is the first IP address in the range. The second is the last IP address in the range. The third is a Perl data structure containing the data to be inserted. The final parameter are additional arguments, as outlined for `insert_network()`.

### \$tree->remove_network(\$network)

This method removes the network from the database. It takes one parameter, the network in CIDR notation.

### \$tree->write_tree($fh)

Given a filehandle, this method writes the contents of the tree as a MaxMind DB database to that filehandle.

### \$tree->iterate($object)

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

### \$tree->freeze_tree($filename)

Given a file name, this method freezes the tree to that file. Unlike the `write_tree()` method, this method does write out a MaxMind DB file. Instead, it writes out something that can be quickly thawed via the `MaxMind::DB::Writer::Tree->new_from_frozen_tree` constructor. This is useful if you want to pass the in-memory representation of the tree between processes.

### $tree->ip_version()

Returns the tree's IP version, as passed to the constructor.

### $tree->record_size()

Returns the tree's record size, as passed to the constructor.

### $tree->merge_strategy()

Returns the merge strategy used when two records collide.

### $tree->map_key_type_callback()

Returns the callback used to determine the type of a map's values, as passed to the constructor.

### $tree->database_type()

Returns the tree's database type, as passed to the constructor.

### $tree->languages()

Returns the tree's languages, as passed to the constructor.

### $tree->description()

Returns the tree's description hashref, as passed to the constructor.

### $tree->alias_ipv6_to_ipv4()

Returns a boolean indicating whether the tree will alias some IPv6 ranges to their corresponding IPv4 ranges when the tree is written to disk.

### MaxMind::DB::Writer::Tree->new_from_frozen_tree()

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
  
  Override the `<database_type>` of the frozen tree. This accepts a string of the same form as the `<new()`> constructor.
  
  This parameter is optional.

- description
  
  Override the `<description>` of the frozen tree. This accepts a hashref of the same form as the `<new()`> constructor.
  
  This parameter is optional.

- merge_strategy
  
  Override the `<merge_strategy>` setting for the frozen tree.
  
  This parameter is optional.

## 数据类型

MaxMind DB 文件格式是强类型的。 因为 Perl 不是强类型的，所以您需要显式指定每条数据的类型。 目前，此类假设您的 IP 地址的顶级数据结构将始终是映射（哈希）。 然后，您可以提供一个 `map_key_type_callback` 子例程，该子例程将在数据序列化时被调用。 此回调被赋予一个键名，并预期返回该键的数据类型。

我们以下面的结构为例:

```perl
{
    names => {
        en => 'United States',
        es => 'Estados Unidos',
    },
    population    => 319_000_000,
    fizzle_factor => 65.7294,
    states        => [ 'Alabama', 'Alaska', ... ],
}
```

鉴于此数据结构, 我们的 `map_key_type_callback` 可能看起来像这样:

```perl
my %types = (
    names         => 'map',
    en            => 'utf8_string',
    es            => 'utf8_string',
    population    => 'uint32',
    fizzle_factor => 'double',
    states        => [ 'array', 'utf8_string' ],
);
 
sub {
    my $key = shift;
    return $type{$key};
}
```

如果回调返回 `undef`，序列化代码将抛出错误。 请注意，对于数组，我们返回一个 2 元素的 arrayref，其中第一个元素是“array”，第二个元素是数组中的内容类型。

有效的类型是：

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
