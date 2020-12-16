# MaxMind DB 文件格式说明

> 翻译 [MaxMind DB File Format Specification](http://maxmind.github.io/MaxMind-DB/)
> 
> 参考 [MaxMind DB 文件格式规范](https://www.cnblogs.com/yufengs/p/6606609.html)
> 
> 日期 2020-12-02

## 目录

* [简介](#简介)
  * [版本](#版本)
  * [概述](#概述)
* [元数据段](#元数据段)
  * [结构组成](#结构组成)
* [二进制搜索树段](#二进制搜索树段)
  * [节点布局](#节点布局)
  * [搜索算法](#搜索算法)
* [数据段](#数据段)
* [Authors && License](#Authors-and-License)

## 简介

MaxMind DB 文件格式是一种使用`二叉搜索树`(binary search tree)方式将IPv4 和 IPv6地址映射到`数据记录`(data records)的数据格式。数据可以到 www.maxmind.com 下载，不过需要注册登录才能下载。

### 版本

这个文档描述的是 **version 2.0** 版本的数据格式。版本号由主版本(major)号和次版本(minor)号组成，版本号不应该用十进制方式解读，例如 2.10 版本大于 2.9 版本。数据格式保持主版本兼容，次版本不会改变数据格式。

### 概述

数据文件可以分为3个部分:

- 二进制搜索树(binary search tree). 每个级别的树都对应一个比特位，这个比特位是一个表示IPv6地址的128位数据中的一位。
- 数据段(data section)。这里保存的是指定IP对应的详细信息。
- 元数据(Database metadata)。数据文件的自身描述信息。

--------

## 元数据段

元数据存储在文件的最末端，可以通过寻找二进制序列 `\xab\xcd\xefMaxMind.com`来定位元数据的开始位置。 文件中最后一次出现这个二进制序列，标志了数据段结束，元数据的开始。 因为数据段是允许用户自定义的，所以为了保险起见，需要找最后一次出现的位置。元数据部分最大不能超过128KiB(包含前面的二进制序列标记)  元数据存储在Map数据结构中。这种结构后面会详细介绍。

### 结构组成

元数据有许多关键数据，这些关键数据改变数据类型或者删除都会导致主版本升级。下面是这些关键数据的介绍：

```c
typedef struct MMDB_metadata_s {
    uint32_t node_count;
    uint16_t record_size;
    uint16_t ip_version;

    const char *database_type;

    struct {
        size_t count;
        const char **names;
    } languages;

    uint16_t binary_format_major_version;
    uint16_t binary_format_minor_version;
    uint64_t build_epoch;

    struct {
        size_t count;
        MMDB_description_s **descriptions;
    } description;

} MMDB_metadata_s;
```

#### node_count

无符号的32位整型，表示搜索树的节点个数。

#### record_size

无符号的16位整型， 表示搜索树中一个记录中的比特位数，每个节点都有2个记录(record).

#### ip_version

无符号的16位整型，取值范围为4和6；4表示仅有IPv4地址， 6表示包含IPv4和IPv6地址。

```c
//函数 MMDB_lookup_sockaddr 中
if (mmdb->metadata.ip_version == 4) {
    if (sockaddr->sa_family == AF_INET6) {
        *mmdb_error = MMDB_IPV6_LOOKUP_IN_IPV4_DATABASE_ERROR;
        return result;
    }
}
```

#### database_type

一个字符串，表示每一个IP地址对应的数据记录的结构。这些结构的实际定义由数据库创建者决定。以 “GeoIP” 开头的字符串保留给 MaxMind 公司，并且 “GeoIP” 是注册商标。

#### languages

字符串数组，每一个字符串表示一种语言(例如`zh-CN`表示简体中文)。一个记录中某个项目(例如名字)可能包含多种语言，注意不是`languages`声明的所有语言种类都会有， 并且不允许包含未声明的语言种类。这是一个可选的键，因为这并不适用于所有的数据类型。

#### binary_format_major_version

无符号的16位整型， 表示该文件格式的主版本号。

#### binary_format_minor_version

无符号的16位整型， 表示该文件格式的次版本号。

#### build_epoch

无符号的64位整型， 表示该文件生成的UNIX纪元(epoch)时间戳(从[协调世界时](https://baike.baidu.com/item/%E5%8D%8F%E8%B0%83%E4%B8%96%E7%95%8C%E6%97%B6)1970年1月1日0时0分0秒起至现在的总秒数，不考虑闰秒)。

#### description

指向一个map(key-value对结构)。map中所有的key都是一种语言代码，value是UTF-8格式的描述字符串。这是一个可选的键，但是建议创建者最少描述一种语言。

### Calculating the Search Tree Section Size

The formula for calculating the search tree section size *in bytes* is as follows:

```bash
$search_tree_size_in_bytes = ( ( $record_size * 2 ) / 8 ) * $number_of_nodes
```

The end of the search tree marks the beginning of the data section.

---------------

## 二进制搜索树段

二进制搜索树段在文件的开头。树中节点的个数由多少个唯一的网段(netblock)决定。例如，城市级别的库比国家级别库需要更多小的网段，来区分不同的城市。最顶端的节点始终位于搜索树部分的地址空间的开头。头节点是 `节点0`。每个节点包含2个记录，每个记录都是一个指向本文件地址的指针。指针可以指向3中事物：

- 指向另一个节点。指针作为IP地址搜索算法的一部分，后面会介绍。

- 指向一个等于 `$number_of_nodes` 的值。表示要搜索的IP地址未找到。

- 指向一个数据段的地址，指向给定网段相关的数据。

### 节点布局

每一个节点包含2个记录，一个记录就是一个指针。记录的大小在相同的文件中一定相等(不同文件可能会不同)。 A record may be anywhere from 24 to 128 bits long, depending on the number of nodes in the tree. 这些指针都是以大端(big-endian)的方式存储的。

Here are some examples of how the records are laid out in a node for 24, 28, and 32 bit records. Larger record sizes follow this same pattern.

#### 24 bits (small database), 一个节点6个字节(24<sub>bit</sub> x 2<sub>record</sub> / 8<sub>bit</sub> = 6<sub>byte</sub>)

```
| <------------- node --------------->|
| 23 .. 0          |          23 .. 0 |
```

#### 28 bits (medium database), 一个节点7个字节(28 x 2 / 8 = 7)

```
| <------------- node --------------->|
| 23 .. 0 | 27..24 | 27..24 | 23 .. 0 |
```

Note 4 bits of each pointer are combined into the middle byte. For both records, they are prepended and end up in the most significant position.

#### 32 bits (large database), 一个节点8个字节(32 x 2 / 8 = 8)

```
| <------------- node --------------->|
| 31 .. 0          |          31 .. 0 |
```

### 搜索算法

第一步是将IP地址转换成大端二进制模式。对于IPv4地址这是一个32比特(4个字节)，IPv6是128比特(8个字节)。最左边的位对应于搜索树中的第一个节点。对于每一个比特位来说，0表示选择节点的左记录，1表示选择右记录。记录的值使用无符号整型表示，这个整型的最大值由记录中比特位数(24, 28, or 32)决定。

- 如果记录的值小于小于节点的总数，那么这个值是节点序号，继续从这个节点开始执行搜索。

- 如果记录的值等于节点总数，表示没有找到指定的IP地址，搜索结束。

- 如果记录的值大于节点总数，那么这个值是一个指向数据段的指针。这个指针表示的是相对数据段开始的指针，而不是从文件的开始。

In order to determine where in the data section we should start looking, we use the following formula:

```bash
$data_section_offset = ( $record_value - $node_count ) - 16
```

16是数据段分隔符(连续16个NULL)的大小，减去它是想要指向数据段的第一个字节。上面说过，记录值等于节点总数表示未搜索到，所以选择数据段从 `$node_count + 16` 开始。 (这导致的副作用是记录值从 `$node_count + 1` 到 `$node_count + 15` 是无效的).

为了更好理解上面所说的内容，举一个例子：

假设有一个1000个节点24-bit 的树。每个节点包含48比特(6字节)，整个树的大小为 6,000 字节。当一个记录中的值小于1000，那么这个值是节点序号，继续从这个节点搜索。如果记录的值大于等于1016，我们知道这是数据段的值。首先减去1000(节点个数)，然后减去数据段分隔符的16字节，我们就得到了数据段开始的值。如果记录的值是6000，那么根据公式，我们知道偏移量是4984(6000 - 1000 - 16)。

为了知道数据段的开始(相对文件的偏移量)，我们可以是二进制搜索树的大小加上 16 就可以得出:

```bash
$offset_in_file = $data_section_offset
                  + $search_tree_size_in_bytes
                  + 16
```

因为加一次16减去一次16，所有最终简化为下面的公式：

```bash
$offset_in_file = ( $record_value - $node_count )
                  + $search_tree_size_in_bytes
```

### IPv4 addresses in an IPv6 tree

当把IPv4地址存储到IPv6树中时, IPv4地址按照原样存储, 所以需要占用开始的 32个比特 of the address space (from 0 to 2**32 - 1).

Creators of databases should decide on a strategy for handling the various mappings between IPv4 and IPv6.

The strategy that MaxMind uses for its GeoIP databases is to include a pointer from the `::ffff:0:0/96` subnet to the root node of the IPv4 address space in the tree. This accounts for the [IPv4-mapped IPv6 address](http://en.wikipedia.org/wiki/IPv6#IPv4-mapped_IPv6_addresses).

MaxMind also includes a pointer from the `2002::/16` subnet to the root node of the IPv4 address space in the tree. This accounts for the [6to4 mapping](http://en.wikipedia.org/wiki/6to4) subnet.

Database creators are encouraged to document whether they are doing something similar for their databases.

The Teredo subnet cannot be accounted for in the tree. Instead, code that searches the tree can offer to decode the IPv4 portion of a Teredo address and look that up.

---------------

## 数据段

每一个数据域都有一个类型， 并且类型在数据域开头使用数字表示。一些类型长度不固定，这些类型会标示长度，长度变量紧跟在数据类型变量之后。数据负载在数据域之后,所有的二进制数据都以大端的方式存储。

```bash
| 数据类型 | 数据长度 | 数据负载 |
```

Note that the *interpretation* of a given data type’s meaning is decided by higher-level APIs, not by the binary format itself.

```c
#define MMDB_DATA_TYPE_EXTENDED    (0)
#define MMDB_DATA_TYPE_POINTER     (1)
#define MMDB_DATA_TYPE_UTF8_STRING (2)
#define MMDB_DATA_TYPE_DOUBLE      (3)
#define MMDB_DATA_TYPE_BYTES       (4)
#define MMDB_DATA_TYPE_UINT16      (5)
#define MMDB_DATA_TYPE_UINT32      (6)
#define MMDB_DATA_TYPE_MAP         (7)
/* 下面是扩展类型 */
#define MMDB_DATA_TYPE_INT32       (8)
#define MMDB_DATA_TYPE_UINT64      (9)
#define MMDB_DATA_TYPE_UINT128    (10)
#define MMDB_DATA_TYPE_ARRAY      (11)
#define MMDB_DATA_TYPE_CONTAINER  (12)
#define MMDB_DATA_TYPE_END_MARKER (13)
#define MMDB_DATA_TYPE_BOOLEAN    (14)
#define MMDB_DATA_TYPE_FLOAT      (15)
```

每一个的 field 都是从一个控制字节开始。控制字节包含了数据类型和数据长度信息。

```c
/* 获取控制字节(数据段+偏移地址) */
uint8_t ctrl = mem[offset++]; //此时 offset 指向控制字节的下一个字节
```

控制字节前三个比特位表示数据类型，计算方法如下:

```c
int type = (ctrl >> 5) & 7; /* 7 = 0111 */
```

前三位取值为0~7。如果是0表示这是个扩展类型，意味着下一个字节开始包含真实类型。

```c
/* 获取 扩展类型 */
int get_ext_type(int raw_ext_type) {
    return 7 + raw_ext_type;
}

/* 扩展类型的情况下,控制字节的下一个字节用来计算数据类型 */
if (type == MMDB_DATA_TYPE_EXTENDED) {
    type = get_ext_type(mem[offset++]);
}
```

解析过程在函数 `decode_one()` 中实现。

### 指针类型(pointer)

指针,指向数据段的地址空间。这个指针会指向一个数据域的开始。不能够将一个指针指向另一个指针。指针值是从数据段开始计算，而不是从文件开始。

指针的值使用控制字节的后五个比特位计算。需要将这五个比特位分成两部分。前两个比特位表示大小(size)，后三个比特位是值(value)的一部分。控制字节是 `001SSVVV` 的形式。

| size 取值 | 指针计算方法                                   | 指针比特位数 | 寻址范围      |
| ------- | ---------------------------------------- | ------ | --------- |
| 0       | 控制字节的后1个字节加上控制字节中的3个比特位组成的11位数据          | 11     | 2047      |
| 1       | 控制字节的后2个字节加上控制字节中的3个比特位组成的19位数据 + 2048   | 19     | 526335    |
| 2       | 控制字节的后3个字节加上控制字节中的3个比特位组成的27位数据 + 526336 | 27     | 134744063 |
| 3       | 控制字节的后4个字节组成的32位数据(控制字节中的3个比特位被忽略)       | 32     | 4GB       |

由上面可以看出，指针的寻址范围为 4GB，所以数据段不能超过 4GB.

```c
/* 指针类型计算 */
if (type == MMDB_DATA_TYPE_POINTER) {
    uint8_t psize = ((ctrl >> 3) & 3) + 1; //注意这里给size加1了
    entry_data->pointer = get_ptr_from(ctrl, &mem[offset], psize);
}

/* 获取指针的值 */
uint32_t get_ptr_from(uint8_t ctrl, uint8_t const *const ptr, int ptr_size)
{
    uint32_t new_offset;
    switch (ptr_size) {
    case 1: //size 为 0 的情况
        new_offset = ( (ctrl & 7) << 8) + ptr[0];
        break;
    case 2://size 为 1 的情况
        new_offset = 2048 + ( (ctrl & 7) << 16 ) + ( ptr[0] << 8) + ptr[1];
        break;
    case 3://size 为 2 的情况
        new_offset = 2048 + 524288 + ( (ctrl & 7) << 24 ) + get_uint24(ptr);
        break;
    case 4: //size 为 3 的情况
    default:
        new_offset = get_uint32(ptr);
        break;
    }
    return new_offset;
}


```



### 字符串类型(string)

一个不定长的字节序列其中含有UTF8的内容，如果长度为0，表示是一个空字符串。

```c
if (type == MMDB_DATA_TYPE_UTF8_STRING) {
    entry_data->utf8_string = size == 0 ? "" : (char *)&mem[offset];
    entry_data->data_size = size;
}
```

### 双精度浮点类型(double)

This is stored as an IEEE-754 double (binary64) . double 类型永远都是8个字节，以大端形式存储。

```c
if (type == MMDB_DATA_TYPE_DOUBLE) {
    size = 8;
    entry_data->double_value = get_ieee754_double(&mem[offset]);
}

/* 还原 double 类型 */
double get_ieee754_double(const uint8_t *restrict p)
{
    volatile double d;
    uint8_t *q = (void *)&d;
#if MMDB_LITTLE_ENDIAN || _WIN32
    q[7] = p[0];
    q[6] = p[1];
    q[5] = p[2];
    q[4] = p[3];
    q[3] = p[4];
    q[2] = p[5];
    q[1] = p[6];
    q[0] = p[7];
#else
    memcpy(q, p, 8);
#endif
    return d;
}
```

### 字节类型(bytes)

一个不确定长度的字节序列可以包含任何二进制数据。如果长度为0，说明是一个空的字节序列。<u>这个类型当前还未使用</u>，以后可能会用于嵌入非文本数据，例如图像等。

```c
if (type == MMDB_DATA_TYPE_BYTES) {
    entry_data->bytes = &mem[offset];
    entry_data->data_size = size;
}
```

### integer formats

Integers are stored in variable length binary fields.

We support 16-bit, 32-bit, 64-bit, and 128-bit unsigned integers. We also support 32-bit signed integers.

A 128-bit integer can use up to 16 bytes, but may use fewer. Similarly, a 32-bit integer may use from 0-4 bytes. The number of bytes used is determined by the length specifier in the control byte. See below for details.

A length of zero always indicates the number 0.

When storing a signed integer, the left-most bit is the sign. A 1 is negative and a 0 is positive.

The type numbers for our integer types are:

- unsigned 16-bit int - 5
- unsigned 32-bit int - 6
- signed 32-bit int - 8
- unsigned 64-bit int - 9
- unsigned 128-bit int - 10

The unsigned 32-bit and 128-bit types may be used to store IPv4 and IPv6 addresses, respectively.

The signed 32-bit integers are stored using the 2’s complement representation.

### map - 7

A map data type contains a set of key/value pairs. Unlike other data types, the length information for maps indicates how many key/value pairs it contains, not its length in bytes. This size can be zero.

See below for the algorithm used to determine the number of pairs in the hash. This algorithm is also used to determine the length of a field’s payload.

### array - 11

An array type contains a set of ordered values. The length information for arrays indicates how many values it contains, not its length in bytes. This size can be zero.

This type uses the same algorithm as maps for determining the length of a field’s payload.

### data cache container - 12

This is a special data type that marks a container used to cache repeated data. For example, instead of repeating the string “United States” over and over in the database, we store it in the cache container and use pointers *into* this container instead.

Nothing in the database will ever contain a pointer to this field itself. Instead, various fields will point into the container.

The primary reason for making this a separate data type versus simply inlining the cached data is so that a database dumper tool can skip this cache when dumping the data section. The cache contents will end up being dumped as pointers into it are followed.

### end marker - 13

The end marker marks the end of the data section. It is not strictly necessary, but including this marker allows a data section deserializer to process a stream of input, rather than having to find the end of the section before beginning the deserialization.

This data type is not followed by a payload, and its size is always zero.

### boolean - 14

A true or false value. The length information for a boolean type will always be 0 or 1, indicating the value. There is no payload for this field.

### float - 15

This is stored as an IEEE-754 float (binary32) in big-endian format. The length of a float is always 4 bytes.

This type is provided primarily for completeness. Because of the way floating point numbers are stored, this type can easily lose precision when serialized and then deserialized. If this is an issue for you, consider using a double instead.

### Data Field Format

每一个的 field 都是从一个控制字节开始。控制字节包含了数据类型和数据长度信息。前三个比特位表示数据类型，如果三位都是0表示这是个扩展类型，意味着下一个字节开始包含 actual type。否则前三位取值为1~7。~Otherwise, the first three bits will contain a number from 1 to 7, the actual type for the field.

We’ve tried to assign the most commonly used types as numbers 1-7 as an optimization.

With an extended type, the type number in the second byte is the number minus 7. In other words, an array (type 11) will be stored with a 0 for the type in the first byte and a 4 in the second.

Here is an example of how the control byte may combine with the next byte to tell us the type:

```pure
001XXXXX          pointer
010XXXXX          UTF-8 string
110XXXXX          unsigned 32-bit int (ASCII)
000XXXXX 00000011 unsigned 128-bit int (binary)
000XXXXX 00000100 array
000XXXXX 00000110 end marker
```

#### Payload Size

The next five bits in the control byte tell you how long the data field’s payload is, except for maps and pointers. Maps and pointers use this size information a bit differently. See below.

If the five bits are smaller than 29, then those bits are the payload size in bytes. For example:

```
01000010          UTF-8 string - 2 bytes long
01011100          UTF-8 string - 28 bytes long
11000001          unsigned 32-bit int - 1 byte long
00000011 00000011 unsigned 128-bit int - 3 bytes long
```

If the five bits are equal to 29, 30, or 31, then use the following algorithm to calculate the payload size.

If the value is 29, then the size is 29 + *the next byte after the type specifying bytes as an unsigned integer*.

If the value is 30, then the size is 285 + *the next two bytes after the type specifying bytes as a single unsigned integer*.

If the value is 31, then the size is 65,821 + *the next three bytes after the type specifying bytes as a single unsigned integer*.

Some examples:

```
01011101 00110011 UTF-8 string - 80 bytes long
```

In this case, the last five bits of the control byte equal 29. We treat the next byte as an unsigned integer. The next byte is 51, so the total size is (29 + 51) = 80.

```
01011110 00110011 00110011 UTF-8 string - 13,392 bytes long
```

The last five bits of the control byte equal 30. We treat the next two bytes as a single unsigned integer. The next two bytes equal 13,107, so the total size is (285 + 13,107) = 13,392.

```
01011111 00110011 00110011 00110011 UTF-8 string - 3,421,264 bytes long
```

The last five bits of the control byte equal 31. We treat the next three bytes as a single unsigned integer. The next three bytes equal 3,355,443, so the total size is (65,821 + 3,355,443) = 3,421,264.

This means that the maximum payload size for a single field is 16,843,036 bytes.

The binary number types always have a known size, but for consistency’s sake, the control byte will always specify the correct size for these types.

#### Maps

map 类型控制字节中的数据长度表示的是键值对(key/value pairs)的个数。

This means that the maximum number of pairs for a single map is 16,843,036.

map类型的键值对布局是 每一个键后面紧跟着其值，后面就是亮一个键值对。键永远都是 UTF-8 字符串，值可以是任意类型，甚至是map 和 指针。一旦我们知道了键值对的数量，我们就可以一对一对的按照顺序解析出来。

-----------

## Authors-and-License

This specification was created by the following authors:

- Greg Oschwald <goschwald@maxmind.com>
- Dave Rolsky <drolsky@maxmind.com>
- Boris Zentner <bzentner@maxmind.com>

This work is licensed under the Creative Commons Attribution-ShareAlike 3.0 Unported License. To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/3.0/ or send a letter to Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA
