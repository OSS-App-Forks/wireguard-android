#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Build the unsigned release APK
echo "Building unsigned release APK with Gradle..."
./gradlew assembleRelease

# Find the unsigned APK in the build directory
mapfile -t CANDIDATES < <(find . -type f -path "*/build/outputs/apk/release/*-unsigned.apk")

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
    echo "Error: No unsigned release APK found."
    exit 1
elif [ "${#CANDIDATES[@]}" -gt 1 ]; then
    echo "Error: Multiple unsigned APKs found, please specify which one:"
    printf '%s\n' "${CANDIDATES[@]}"
    exit 1
fi

UNSIGNED_APK="${CANDIDATES[0]}"
echo "Found unsigned APK at: $UNSIGNED_APK"

# 3. Extract real packageName and versionCode from the built APK itself
BADGING=$(aapt2 dump badging "$UNSIGNED_APK")
PACKAGE_NAME=$(echo "$BADGING" | grep -oP "package: name='\K[^']+")
VERSION_CODE=$(echo "$BADGING" | grep -oP "versionCode='\K[0-9]+")
VERSION_NAME=$(echo "$BADGING" | grep -oP "versionName='\K[^']+")

OUTPUT_APK="${PACKAGE_NAME}_${VERSION_CODE}.apk"

# 4. Sign the APK using the PKCS12 keystore
KEYSTORE="keystore.p12"
if [ ! -f "$KEYSTORE" ]; then
    echo "Error: Keystore file '$KEYSTORE' not found in the project root directory."
    exit 1
fi

# Check if KEY_ALIAS is set, otherwise ask for it
if [ -z "$KEY_ALIAS" ]; then
    read -p "Enter key alias: " KEY_ALIAS
fi

# Check if KEYSTORE_PASSWORD is set, otherwise prompt for it securely
if [ -z "$KEYSTORE_PASSWORD" ]; then
    read -sp "Enter keystore password: " KEYSTORE_PASSWORD
    echo "" # Add newline after secure input
fi

# Export KEYSTORE_PASSWORD so apksigner can read it securely from the environment
export KEYSTORE_PASSWORD

echo "Signing APK with keystore '$KEYSTORE' and alias '$KEY_ALIAS'..."
apksigner sign --ks "$KEYSTORE" \
               --ks-type PKCS12 \
               --ks-key-alias "$KEY_ALIAS" \
               --ks-pass env:KEYSTORE_PASSWORD \
               --out "$OUTPUT_APK" \
               "$UNSIGNED_APK"

echo "------------------------------------------------"
echo "Success! Signed APK created: $OUTPUT_APK"
echo "------------------------------------------------"
