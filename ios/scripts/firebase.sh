#!/bin/sh
set -eu
SOURCE_PLIST="${SRCROOT}/Runner/GoogleService-Info.plist"
DEST_PLIST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"
if [ ! -f "$SOURCE_PLIST" ]; then
  rm -f "$DEST_PLIST"
  echo "Workshop: no Firebase plist; local-only build."
  exit 0
fi
cp "$SOURCE_PLIST" "$DEST_PLIST"
# CocoaPods and Flutter's Swift Package Manager integrations are supported.
if [ -n "${PODS_ROOT:-}" ] && [ -f "${PODS_ROOT}/FirebaseCrashlytics/run" ]; then
  "${PODS_ROOT}/FirebaseCrashlytics/run"
else
  CRASHLYTICS_RUN="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
  if [ -f "$CRASHLYTICS_RUN" ]; then
    "$CRASHLYTICS_RUN"
  else
    echo "error: Cannot find Crashlytics symbol uploader. Run flutterfire configure after installing iOS dependencies."
    exit 1
  fi
fi
