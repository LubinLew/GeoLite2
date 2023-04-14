# GeoLite2

## Description

使用官方 perl 工具编写代码生成自定义的 geoip 数据库。

本项目的例子 [release/rebuild.pl](release/rebuild.pl) 生成一个具有下面特性的数据库:

- 只有中文
- 只支持IPv4
- 支持常用[保留地址](https://en.wikipedia.org/wiki/Reserved_IP_addresses)(127.0.0.1/8等)

并使用 [Github Action](.github/workflows/release.yml) 功能每天自动检查 [MaxMind](https://www.maxmind.com/) 官网更新，并自动发布最新版本。

> MaxMind 下载数据需要注册账号, 可以申请 API key 用于脚本下载文件。

----

## Docs

[mmdb文件格式说明](docs/mmdb_format_spec.md)

[自己制作mmdb文件](docs/make_mmdb.md)

[API 接口文档](docs/mmdb_writer_API.md)

----

## References

### Offical

[MaxMind DB File Format Specification](http://maxmind.github.io/MaxMind-DB/)

[MaxMind-DB-Writer-perl](https://github.com/maxmind/MaxMind-DB-Writer-perl)

[maxmind/libmaxminddb: C library for the MaxMind DB file format](https://github.com/maxmind/libmaxminddb)

### Other

[Geoip MaxMind DB 生成指南](https://blog.csdn.net/openex/article/details/53487465)

[[翻译] MaxMind DB 文件格式规范](https://www.cnblogs.com/yufengs/p/6606609.html)
