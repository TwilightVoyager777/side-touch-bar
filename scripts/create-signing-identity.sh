#!/usr/bin/env bash
# Creates a self-signed code signing certificate, "SideTouchBar Local Signing",
# in your login keychain. build-app.sh uses it automatically when present, so
# rebuilt apps keep the same signature and macOS keeps their permissions
# (Accessibility, microphone…) instead of treating every build as a new app.
#
# Run once. The first build afterwards asks to let codesign use the key:
# choose "Always Allow". Remove it any time in Keychain Access.
set -euo pipefail

NAME="SideTouchBar Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning "$KEYCHAIN" | grep -q "$NAME"; then
    echo "\"$NAME\" already exists."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$WORK/cert.conf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
# macOS's LibreSSL writes PKCS#12 in a format `security import` accepts.
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -name "$NAME" -out "$WORK/identity.p12" -passout pass:sidetouchbar

security import "$WORK/identity.p12" -k "$KEYCHAIN" -P sidetouchbar -T /usr/bin/codesign

echo "Created \"$NAME\". Rebuild with scripts/build-app.sh; it will be used automatically."
echo "macOS will ask for Accessibility permission once more for the newly signed app."
