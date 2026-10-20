# companion_flutter

A new Flutter project.

## Android APK 发布

```bash
./scripts/build-android-apk.sh && \
./scripts/publish-android-apk.sh
```

默认构建 prod/release，生成 `build/android/bansheng-<版本号+build号>.apk`。
发布脚本上传到腾讯服务器数据盘，验证公网完整下载后输出 HTTPS 下载链接。
签名校验、服务器配置及排障说明见 [Android APK 发布文档](deploy/android-apk-publishing.md)。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
