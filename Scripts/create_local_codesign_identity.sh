#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIGNING_DIR="${LOCALVOICEFLOW_DEV_SIGNING_DIR:-$ROOT/.build/dev-signing}"
KEYCHAIN="$SIGNING_DIR/LocalVoiceFlowSigning.keychain-db"
PASSWORD_FILE="$SIGNING_DIR/keychain-password.txt"
IDENTITY_NAME="${LOCALVOICEFLOW_CODESIGN_IDENTITY:-LocalVoiceFlow Development}"
CERT_PEM="$SIGNING_DIR/LocalVoiceFlowDevelopment.cer"
KEY_PEM="$SIGNING_DIR/LocalVoiceFlowDevelopment.key"
P12_FILE="$SIGNING_DIR/LocalVoiceFlowDevelopment.p12"
OPENSSL_CONFIG="$SIGNING_DIR/openssl.cnf"

mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"

if [[ ! -f "$PASSWORD_FILE" ]]; then
  printf '%s%s' "$(uuidgen | tr -d '-')" "$(uuidgen | tr -d '-')" | cut -c 1-32 >"$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"
fi
KEYCHAIN_PASSWORD="$(cat "$PASSWORD_FILE")"

if [[ ! -f "$KEYCHAIN" ]]; then
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
fi
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
EXISTING_KEYCHAINS="$(security list-keychains -d user | sed 's/[" ]//g' | tr '\n' ' ')"
security list-keychains -d user -s "$KEYCHAIN" $EXISTING_KEYCHAINS

if security find-certificate -c "$IDENTITY_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "$IDENTITY_NAME"
  exit 0
fi

cat >"$OPENSSL_CONFIG" <<EOF
[req]
prompt = no
distinguished_name = dn
x509_extensions = code_signing

[dn]
CN = $IDENTITY_NAME
O = LocalVoiceFlow
OU = Local Development

[code_signing]
basicConstraints = critical,CA:true
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

openssl req \
  -new \
  -newkey rsa:2048 \
  -nodes \
  -x509 \
  -days 3650 \
  -keyout "$KEY_PEM" \
  -out "$CERT_PEM" \
  -config "$OPENSSL_CONFIG" >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -inkey "$KEY_PEM" \
  -in "$CERT_PEM" \
  -out "$P12_FILE" \
  -name "$IDENTITY_NAME" \
  -certpbe PBE-SHA1-3DES \
  -keypbe PBE-SHA1-3DES \
  -macalg sha1 \
  -passout pass:"$KEYCHAIN_PASSWORD" >/dev/null 2>&1

security import "$P12_FILE" \
  -k "$KEYCHAIN" \
  -P "$KEYCHAIN_PASSWORD" \
  -T /usr/bin/codesign >/dev/null

security add-trusted-cert \
  -d \
  -r trustRoot \
  -p codeSign \
  -k "$KEYCHAIN" \
  "$CERT_PEM" >/dev/null 2>&1 || true

security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN" >/dev/null 2>&1 || true

echo "$IDENTITY_NAME"
