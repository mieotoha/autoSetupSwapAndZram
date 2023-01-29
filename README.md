# autoSetupSwapAndZram

**日语及英语版本准备中**

<!-- 描述 -->

## 使用方法

``` shell
./autoSetSwapAndZram.sh [swap_size] [zram_size] [zram_algorithm]
```

`[]`表示选填，因此您完全可以

``` shell
./autoSetSwapAndZram.sh
```

或

``` shell
./autoSetSwapAndZram.sh 4194304 2G
```

但必须按照顺序填入参数，如

``` shell
./autoSetSwapAndZram.sh auto default zstd
```

**而不是**

```shell
./autoSetSwapAndZram.sh zst 4194304
```

## 注意事项

此脚本在输入合法参数后将要求root权限以保证结果正常

此脚本已在Ubuntu 20.04上验证过可用性，其它Linux发行版暂未测试
