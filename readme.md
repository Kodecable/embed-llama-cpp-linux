# 为 Steam Runtime 3 'sniper' 编译 Llama.cpp

此为在 amd64 平台上，为 Steam Runtime 3 'sniper' (glibc 2.31) 编译 llama.cpp 和其依赖的笔记。
llama.cpp 使用 `blas` 和 `vulkan` 后端。

注意：vulkan 后端需要主机有 vulkan 驱动，在主机完全缺失 vulkan 环境时请避免加载对应后端（cli 工具有时会自动加载，无法阻止，除非你直接删掉）。

注意：脚本均为在 sniper sdk 容器里运行设计。不适用于其他环境或非一次性环境。

版本：
 - steamrt-sniper  3.0.20250826.159138
 - OpenBLAS        由 git submodule 管理
 - llama.cpp       由 git submodule 管理
 - vulkansdk       1.4.321.1
 
## 获取环境/源代码

steamrt-sniper 官方提供了 SDK 容器环境，参阅[此处](https://gitlab.steamos.cloud/steamrt/steamrt/-/blob/steamrt/sniper/README.md)。

对于 OpenBLAS 和 llama.cpp，确保获取 submodule:
```bash
git submodule update --init --recursive
```

对于 vulkansdk，参阅[此处](https://vulkan.lunarg.com/doc/sdk/latest/linux/getting_started.html)。下载并把它解压到仓库根目录下的 `vulkan-sdk/`。解压后目录结构应满足：
```text
./vulkan-sdk/setup-env.sh
```

## 编译/安装

### 进入 steamrt-sniper

建议直接 podman 运行，distrobox/toolbox 多事又麻烦。

```bash
#!/bin/bash
# File: /usr/local/bin/sniper

podman run -t -i --rm \
  -v `pwd`:/io \
  registry.gitlab.steamos.cloud/steamrt/sniper/sdk \
  bash -c "cd /io && bash"
```

### build.sh & collect.sh (NEW)

先 build 在 collect。

产出为：
 - `output/bin`：可执行文件，以及安装到 `bin` 下的运行时共享库。
 - `output/lib`：常规共享库目录；`output/bin` 下的 ELF 可执行文件和共享库会被写入相对 `rpath`，即从 `bin` 侧使用 `$ORIGIN/../lib` 找到这里，而 `output/lib` 下的共享库自身则写入 `$ORIGIN`。
 - `output/include`：收集出来的头文件，供二次开发或重新链接时参考。
 - `output/embed_lib`：额外整理出的扁平共享库目录；会把带版本号的 `.so.*` 尽量规整成无版本号的 `.so`，把每个库的 `SONAME` 也改成对应的无版本号文件名，并把库之间 `NEEDED` 里的依赖名一并改写成无版本号形式；这些库自身的 `rpath` 也会被写成 `$ORIGIN`，适合做嵌入式分发或集中打包。

恭喜，这就是成果了。

## （测试）

你可以用 llama-cli 加载个模型试下确认工作是否正常。没有自动化检查，我懒得再塞个模型进来了，8B 量化也要几个 GiB 呢。你都要用 llama.cpp 了自己肯定有模型不需要我塞个。

## 后记

所有 .so 大概 100MiB 左右。符号链接不占空间请不要搞错。

`build.sh` 里的参数参考自对应的官方文档和 Arch Linux 的编译脚本。
对于能把 `glslc` 预编译版本搞到 1 GiB+ 还莫名其妙要求 glibc 版本贼高的 Google 致以纯粹的诅咒。
