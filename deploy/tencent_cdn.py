#!/usr/bin/env python3
"""Tencent Cloud CDN helper for dl.banshengcomp.com, installed as /usr/local/sbin/tencent-cdn.

  deploy-cert  certbot deploy hook: push the renewed certificate and keep HTTPS forced.
  refresh      after an APK release: purge the stable download URL, then prefetch it.

Credentials live in /etc/letsencrypt/tencentcloud.env (root-only, 0600):
  TENCENTCLOUD_SECRET_ID=...
  TENCENTCLOUD_SECRET_KEY=...
The CAM sub-account only needs cdn:UpdateDomainConfig, cdn:PurgeUrlsCache and
cdn:PushUrlsCache on this domain. URLs are fixed here so sudo callers cannot
purge or prefetch anything else.
"""
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.request
from datetime import datetime, timezone

DOMAIN = "dl.banshengcomp.com"
STABLE_APK_URL = f"https://{DOMAIN}/downloads/android/bansheng-latest.apk"
ENV_FILE = "/etc/letsencrypt/tencentcloud.env"
HOST = "cdn.tencentcloudapi.com"


def load_credentials():
    creds = {}
    with open(ENV_FILE, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                creds[key.strip()] = value.strip().strip("'\"")
    return creds["TENCENTCLOUD_SECRET_ID"], creds["TENCENTCLOUD_SECRET_KEY"]


def _hmac(key, msg):
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()


def call(action, payload):
    """Tencent Cloud API 3.0 request signed with TC3-HMAC-SHA256."""
    secret_id, secret_key = load_credentials()
    body = json.dumps(payload)
    timestamp = int(time.time())
    date = datetime.fromtimestamp(timestamp, timezone.utc).strftime("%Y-%m-%d")
    canonical = "\n".join([
        "POST", "/", "",
        f"content-type:application/json; charset=utf-8\nhost:{HOST}\n",
        "content-type;host",
        hashlib.sha256(body.encode("utf-8")).hexdigest(),
    ])
    scope = f"{date}/cdn/tc3_request"
    to_sign = "\n".join([
        "TC3-HMAC-SHA256", str(timestamp), scope,
        hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
    ])
    key = _hmac(_hmac(_hmac(("TC3" + secret_key).encode("utf-8"), date), "cdn"), "tc3_request")
    signature = hmac.new(key, to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
    request = urllib.request.Request(
        f"https://{HOST}",
        data=body.encode("utf-8"),
        method="POST",
        headers={
            "Authorization": (
                f"TC3-HMAC-SHA256 Credential={secret_id}/{scope}, "
                f"SignedHeaders=content-type;host, Signature={signature}"
            ),
            "Content-Type": "application/json; charset=utf-8",
            "Host": HOST,
            "X-TC-Action": action,
            "X-TC-Version": "2018-06-06",
            "X-TC-Timestamp": str(timestamp),
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        result = json.load(response)["Response"]
    if "Error" in result:
        raise RuntimeError(f"{action} failed: {result['Error']['Code']}: {result['Error']['Message']}")
    return result


def deploy_cert():
    lineage = os.environ.get("RENEWED_LINEAGE", f"/etc/letsencrypt/live/{DOMAIN}")
    if os.path.basename(lineage) != DOMAIN:
        return  # Hook fired for another certificate.
    with open(f"{lineage}/fullchain.pem", encoding="utf-8") as fh:
        certificate = fh.read()
    with open(f"{lineage}/privkey.pem", encoding="utf-8") as fh:
        private_key = fh.read()
    result = call("UpdateDomainConfig", {
        "Domain": DOMAIN,
        "Https": {
            "Switch": "on",
            "Http2": "on",
            "CertInfo": {
                "Certificate": certificate,
                "PrivateKey": private_key,
                "Message": "letsencrypt via certbot",
            },
        },
        "ForceRedirect": {"Switch": "on", "RedirectType": "https", "RedirectStatusCode": 301},
    })
    print(f"{DOMAIN}: certificate pushed to CDN (RequestId {result['RequestId']})")


def refresh():
    # Purge first: the stable URL is force-cached for 30 days and would keep
    # serving the previous APK. Prefetch then warms nodes before users arrive.
    purge = call("PurgeUrlsCache", {"Urls": [STABLE_APK_URL]})
    push = call("PushUrlsCache", {"Urls": [STABLE_APK_URL], "Area": "mainland"})
    print(json.dumps({"purge_task": purge["TaskId"], "push_task": push["TaskId"], "url": STABLE_APK_URL}))


if __name__ == "__main__":
    commands = {"deploy-cert": deploy_cert, "refresh": refresh}
    if len(sys.argv) != 2 or sys.argv[1] not in commands:
        sys.exit(f"Usage: {sys.argv[0]} {{{'|'.join(commands)}}}")
    try:
        commands[sys.argv[1]]()
    except (OSError, KeyError, RuntimeError, ValueError) as exc:
        sys.exit(f"tencent-cdn {sys.argv[1]} failed: {exc}")
