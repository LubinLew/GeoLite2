# 如何制作 mmdb 文件

mmdb 的制作需要使用官方工具 [MaxMind-DB-Writer-perl](https://github.com/maxmind/MaxMind-DB-Writer-perl)。这是一个 Perl 语言编写的工具。

## 工具安装

执行下面的命令进行安装，时间可能较长，会自动下载各种依赖包

```bash
yum install -y cpanminus
cpanm MaxMind::DB::Writer
```


