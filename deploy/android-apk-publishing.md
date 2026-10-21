# Android APK 构建和发布

## 日常使用

所有 Flutter 构建、运行入口现在都强制执行 `flutter clean` 和 `flutter pub get`，
再编译当前脚本所在仓库的本地代码（包含未提交的 Dart 修改，不会自动拉取远端）。
不再支持 `CLEAN=0` 跳过清理。首次启动时间会增加，调试启动后的热重载仍然保留。

| 入口 | 构建和交付检查 |
| --- | --- |
| `run-android-device.sh` | debug/profile/release 均先构建 APK；AOT 模式逐 ABI 校验后，运行这个确定的 APK |
| `run-iphone-device.sh` | 先构建 `.app`，校验源码、文件和 bundle id，再安装/启动；debug 保留热重载 |
| `run-ipad-device.sh` | 选择 iPad 后复用 iPhone 同一条构建链路 |
| `run-iphone-simulator.sh` | 先构建模拟器 `.app`，校验后运行该文件，保留热重载 |
| `run-ipad-simulator.sh` | 指定 iPad 模拟器后复用 iPhone 模拟器构建链路 |
| `build-android-apk.sh` | 仅接受所选 flavor/mode 对应的准确文件名，禁止回退挑选其他 APK |
| `build-testflight.sh` | 清理后新建 IPA，检查身份、源码与文件指纹后才打开 Transporter |
| `publish-android-apk.sh` | 检查构建记录与当前源码、上传快照；上传及激活前再次检查 |

入口统一拒绝 `--no-build`、`--build=false`、外部 `--use-application-binary`、
`--config-only` 和自定义 `--build-dir` 等绕过当前构建的参数。
运行脚本内部的 `--use-application-binary` 只指向本次刚构建、已验证的固定产物。
每个仓库同时只允许运行一个脚本，防止另一个脚本清理或覆盖正在交付的构建。
调试会话结束后再运行其他构建脚本。

成功构建生成相邻的 `<产物>.source.json`，记录当前 Dart、资源、字体及依赖文件的
内容指纹和产物 SHA-256。构建期间源码改变会失败；构建后再次修改源码或产物，
安装/发布校验也会拒绝。版本号由构建参数和产物身份检查管理，不参与源码指纹。
发布 APK 时必须一起保留 `.source.json`；历史包或缺失记录的包须重新构建，不能直接发布。
这些记录仅保存在本地，不上传源文件或开发者路径。
Android 安装还会回读目标包的 `base.apk` 比对完整 SHA-256；不一致时拒绝启动。

在 Flutter 仓库根目录执行：

```bash
./scripts/build-android-apk.sh && \
./scripts/publish-android-apk.sh
```

默认构建 prod/release，并将 `versionName+versionCode` 用作完整版本号。
例如 `version: 0.6.1+8` 生成 `build/android/bansheng-0.6.1+8.apk`。
dev/debug 包带有额外后缀，发布脚本拒绝这些包。

只构建、不向 USB 设备安装或打开 Finder：

```bash
INSTALL_ANDROID=0 OPEN_OUTPUT=0 FLAVOR=prod ./scripts/build-android-apk.sh
```

发布脚本默认读取当前 `pubspec.yaml` 对应的 APK，不会挑选目录中的任意旧 APK。
也可以指定刚构建的文件：

```bash
./scripts/publish-android-apk.sh build/android/bansheng-0.6.1+8.apk
```

Release 构建结束后，脚本会逐个 ABI 比对 APK 与本次 Flutter 编译产物的
`.text` / `.rodata`，允许 Android 去掉调试符号，但拒绝旧 Dart 代码、缺失或多余架构。
此检查发生在复制发布包及安装之前；失败时不要直接发布旧文件。
Gradle 同时将每个完整 variant 的 Flutter JNI 生成任务接入 Android 打包依赖，
并强制重建 JNI 文件夹合并输出，防止 AGP 的增量合并保留旧 `libapp.so`。
后续任务继续根据内容判断是否需要重建；这一修复也覆盖直接运行 Flutter 命令的构建。

手动核对已有产物：

```bash
python3 scripts/verify_android_aot.py build/app/outputs/flutter-apk/app-prod-release.apk \
  build/app/intermediates/flutter/prodRelease/jniLibs
```

脚本校验 `com.bansheng.prod`、非 debuggable、内嵌版本号、文件名和正式签名证书，
上传暂存文件，核对 SHA-256，再原子发布。重复上传相同文件是幂等的；同版本不同内容
会被拒绝，须先增加 build number，防止已分发链接悄悄变成另一个包。

生成和上传固定的 `bansheng-latest.qr.svg`，二维码始终指向
`https://banshengcomp.com/downloads/android/bansheng-latest.apk`。
以后发布新版无需替换二维码，已保存或打印的这张固定二维码继续下载最新版本。
历史版本二维码仍保留其原有含义；迁移前已分发的版本二维码需要换成新的固定二维码一次。
QR 编码由本地固定版本 `qrcode==8.2` 生成，不使用第三方二维码服务。
首次运行发布脚本会自动准备小型 Python 工具环境，默认保存在
`${XDG_CACHE_HOME:-$HOME/.cache}/companion/apk-publish/<仓库路径哈希>`，
后续发布复用，不再被 `flutter clean` 删除。可通过 `APK_PUBLISH_TOOLS_DIR` 指定缓存目录。

发布分为 7 个阶段，依次显示来源/签名校验、准备工具、上传 APK、上传二维码、服务器校验、
更新下载入口和保存记录。每个阶段显示累计耗时；上传使用 SCP 的实际进度，显示百分比、
传输速率和预计剩余时间，长时间等待每 10 秒提示一次已用时间。

服务器校验 APK 大小、APK/二维码 SHA-256，并在发布锁内切换
`/downloads/android/latest.json`；脚本核对 SSH 返回的激活结果后打印成功，
并写入本地 `build/android/bansheng-<version>.apk.publish.json` 发布记录。
脚本不再自动下载公网 APK、二维码或元数据，也不检查公网 HTTP 状态和 MIME，
避免发布时额外完整下载两次 APK；公网下载由发布者手动测试。
记录明确包含 `verification_scope: "server_files"` 和 `download_verified: false`，
其中 `verified_at` 只代表服务器文件校验时间。
控制台同时打印版本 APK 地址、固定下载地址、二维码图片地址和可直接扫描的字符二维码；本地也保留 SVG。
Web 首页读取同一份 latest.json，下载按钮显示当前版本，二维码图片和编码内容保持不变。
版本化 APK 保持不可变；验证通过后，在发布锁内原子替换固定下载入口的相对符号链接，
再原子替换 latest.json；旧版本不能覆盖最新入口。固定入口直接提供 APK（无需跳转），
支持 HEAD 和断点续传，使用 no-store、关闭 ETag/修改时间条件缓存及 open_file_cache，
避免沿用上个版本。日常发布无需 Nginx reload。
失败时脚本非零退出并尝试删除自身暂存目录；清理失败会显示警告。
已发布的不可变版本不会因后续步骤失败被删除。
发布脚本不会自动 commit、push 或修改应用版本。

下载链接：

```text
https://banshengcomp.com/downloads/android/bansheng-0.6.1%2B8.apk
https://banshengcomp.com/downloads/android/bansheng-0.6.1%2B8.apk.sha256
https://banshengcomp.com/downloads/android/bansheng-latest.apk
https://banshengcomp.com/downloads/android/bansheng-latest.qr.svg
https://banshengcomp.com/downloads/android/latest.json
```

可以把链接中的 `%2B` 写成 `+`。微信内置浏览器可能限制 APK 下载，可选择在系统浏览器中打开。

## 服务器与凭据

- SSH：`ubuntu@106.52.115.80`，端口 22。
- 本机密钥：`~/.ssh/companion_tencent`；脚本不读取或输出私钥内容。
- 正式证书 SHA-256：`9d9845f19d19dd953edcd1ddd08628a9e5374f1dad12c40df86e61c48243a658`。
- 公开文件：`/mnt/datadisk0/companion/downloads/android/`。
- 私有上传暂存：`/mnt/datadisk0/companion/downloads/.android-upload-*`（0700）。
- 数据盘必须单独挂载在 `/mnt/datadisk0`；未挂载或路径含符号链接时拒绝发布。
- 支持 `APK_SSH_HOST`、`APK_SSH_PORT`、`APK_SSH_KEY`、`APK_PUBLIC_BASE_URL` 环境变量。
  数据目录保持固定，避免误传系统盘。证书轮换须明确更新脚本中的公有指纹。

SSH 使用已信任的 known_hosts，保持主机校验；新机器先单独核验服务器公钥。
日常上传不需要 sudo。发布主流程由 `publish-android-apk.sh` 直接执行，原 Python 发布器已移除。
构建机需要 Bash、Python 3、jq、SSH/SCP、shasum、Android SDK 的 aapt/apksigner。
Python 仅用于已有构建指纹校验、二维码编码、命令超时/进度监管和远端原子文件操作；发布编排在 Shell 中。

## 首次 Nginx 配置 / 新服务器恢复

从版本二维码迁移到固定二维码时，也需先执行下面的幂等配置脚本，启用固定入口的缓存策略。

由现有 HTTPS server include `android-downloads.nginx.conf`。首次安装可运行：

```bash
SNIPPET_BASE64="$(base64 < deploy/android-downloads.nginx.conf | tr -d '\n')"
ssh -i ~/.ssh/companion_tencent -o BatchMode=yes -o StrictHostKeyChecking=yes \
  ubuntu@106.52.115.80 "sudo -n python3 - '$SNIPPET_BASE64'" \
  < deploy/setup_android_downloads.py
```

配置脚本检查数据盘，创建独立下载目录，备份原站点配置，再执行 `nginx -t` 和平滑 reload。
失败时恢复原配置。配置已一致时不重复 reload。备份在数据盘 downloads 下的私有
`.nginx-backups/`；日常发布不会产生配置备份。

路由由 Nginx 直接提供 APK MIME、attachment、nosniff、no-cache，允许 GET/HEAD、断点续传，
禁止目录列表和写请求，不经过 API 或 Web 构建目录。现有 Web 发布不会覆盖该配置或文件。
排障时查看脚本错误、发布验证记录及现有 Nginx access/error log，无需独立后台页面。

发布后的手动检查示例（需要 curl）：

```bash
curl -I 'https://banshengcomp.com/downloads/android/bansheng-0.6.1%2B8.apk'
curl -f 'https://banshengcomp.com/downloads/android/bansheng-0.6.1%2B8.apk.sha256'
```

## 自动化验证

```bash
for script in scripts/*.sh; do bash -n "$script" || exit; done
python3 -m venv build/android/.publish-venv
build/android/.publish-venv/bin/python -m pip install -r scripts/requirements-android-publish.txt
build/android/.publish-venv/bin/python -m unittest discover -s scripts/tests -v
```

上面的 `build/android/.publish-venv` 仅是测试环境，与发布器的持久工具缓存独立。
单元/脚本测试覆盖命名、错误签名、debug/dev 拒绝、上传校验、同版本冲突、数据盘约束、
私有暂存清理、上传进度、等待提示和激活响应不一致；同时确认不会发起公网下载。
测试使用隔离的 SSH/SCP 替身，不执行真实发布；生产下载由发布者手动验收。
