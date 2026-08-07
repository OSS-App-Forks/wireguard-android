#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Detect Docker workspace or fallback
WORKSPACE="/tmp"
[[ -d /workspace ]] && WORKSPACE="/workspace"

# 1. Build the unsigned release APK
echo "Building unsigned release APK with Gradle..."
./gradlew assembleRelease --max-workers=8 --no-daemon -Dorg.gradle.jvmargs="-Xmx8g -XX:MaxMetaspaceSize=1024m"

# 2. Find unsigned release APK(s) anywhere in the tree.
# Only real application modules ever produce this file pattern.
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

if [ -z "$PACKAGE_NAME" ] || [ -z "$VERSION_CODE" ]; then
    echo "Error: Could not extract packageName/versionCode from APK."
    exit 1
fi

# 4. Name the file the way fdroidserver expects: <packageName>_<versionCode>.apk
OUTPUT_APK="${PACKAGE_NAME}_${VERSION_CODE}.apk"

# 5. Copy and rename the unsigned APK to the project root
cp "$UNSIGNED_APK" "$OUTPUT_APK"

echo "------------------------------------------------"
echo "Success! Unsigned APK ready at: $OUTPUT_APK"
echo "------------------------------------------------"

# 6. Write build metadata as a sourceable env file for the next step.
#    Using `export KEY=VALUE` lines lets subsequent steps just run
#    `source /workspace/build.env` instead of parsing text manually.
BUILD_ENV_FILE="${WORKSPACE}/build.env"
{
    echo "export PACKAGE_NAME=\"${PACKAGE_NAME}\""
    echo "export VERSION_CODE=\"${VERSION_CODE}\""
    echo "export VERSION_NAME=\"${VERSION_NAME}\""
    echo "export OUTPUT_APK=\"${OUTPUT_APK}\""
    echo "export OUTPUT_APK_PATH=\"${OUTPUT_APK_PATH}\""
} > "$BUILD_ENV_FILE"

echo "Wrote build metadata to $BUILD_ENV_FILE:"
cat "$BUILD_ENV_FILE"