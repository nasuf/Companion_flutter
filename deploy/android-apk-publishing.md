# Android APK 构建和发布

## 日常使用

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

脚本校验 `com.bansheng.prod`、非 debuggable、内嵌版本号、文件名和正式签名证书，
上传暂存文件，核对 SHA-256，再原子发布。重复上传相同文件是幂等的；同版本不同内容
会被拒绝，须先增加 build number，防止已分发链接悄悄变成另一个包。

只有公网完整下载的 SHA-256、HTTP 状态、APK MIME 和校验文件都通过，才打印成功，
并写入本地 `build/android/bansheng-<version>.apk.publish.json` 验证记录。
失败时脚本非零退出，删除自身暂存目录；已发布的不可变版本不会因下载验证失败被删除。
发布脚本不会自动 commit、push 或修改应用版本。

下载链接：

```text
https://banshengcomp.com/downloads/android/bansheng-0.6.1%2B8.apk
https://banshengcomp.com/downloads/android/bansheng-0.6.1%2B8.apk.sha256
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
日常上传不需要 sudo。构建机需要 Python 3、SSH/SCP、curl、Android SDK 的 aapt/apksigner。

## 首次 Nginx 配置 / 新服务器恢复

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

发布后的检查示例：

```bash
curl -I 'https://banshengcomp.com/downloads/android/bansheng-0.6.1%2B8.apk'
curl -f 'https://banshengcomp.com/downloads/android/bansheng-0.6.1%2B8.apk.sha256'
```

## 自动化验证

```bash
bash -n scripts/build-android-apk.sh scripts/publish-android-apk.sh
python3 -m unittest discover -s scripts/tests -v
```

单元/脚本测试覆盖命名、错误签名、debug/dev 拒绝、上传校验、同版本冲突、数据盘约束、
私有暂存清理及公网校验失败；真实上传/HTTPS 下载验证由发布脚本完成。
