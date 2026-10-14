#!/bin/sh
# Renames the template's project, targets, folders and bundle identifier.
# Run once, right after cloning:  scripts/rename.sh MyApp com.company.myapp
set -eu

OLD_NAME="swift_ui_template"
OLD_BUNDLE_ID="com.app.opt.swift-ui-template"
OLD_BUNDLE_ID_PATTERN='com\.app\.opt\.swift-ui-template'

if [ $# -ne 2 ]; then
  echo "Usage: $0 <NewName> <bundle.identifier>" >&2
  exit 1
fi
NEW_NAME="$1"
NEW_BUNDLE_ID="$2"

case "$NEW_NAME" in
  '' | [0-9_]* | *[!A-Za-z0-9_]*)
    echo "NewName must start with a letter and contain only letters, digits and _." >&2
    exit 1 ;;
esac
case "$NEW_BUNDLE_ID" in
  '' | .* | *. | *..* | *[!A-Za-z0-9.-]*)
    echo "Invalid bundle identifier: $NEW_BUNDLE_ID" >&2
    exit 1 ;;
esac

cd "$(dirname "$0")/.."

if [ ! -d "$OLD_NAME.xcodeproj" ]; then
  echo "$OLD_NAME.xcodeproj not found. Was the project already renamed?" >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is not clean. Commit or stash your changes first." >&2
  exit 1
fi

# 1. Rewrite names inside tracked files.
git ls-files | grep -E '\.(pbxproj|xcscheme|xcconfig|swift)$|^README\.md$' | while IFS= read -r file; do
  sed -i '' -e "s/$OLD_BUNDLE_ID_PATTERN/$NEW_BUNDLE_ID/g" -e "s/$OLD_NAME/$NEW_NAME/g" "$file"
done
sed -i '' -e "s/^APP_NAME = .*/APP_NAME = $NEW_NAME/" Configs/Base.xcconfig

# 2. Rename folders and the project bundle.
git mv "${OLD_NAME}Tests" "${NEW_NAME}Tests"
git mv "$OLD_NAME" "$NEW_NAME"
git mv "$OLD_NAME.xcodeproj" "$NEW_NAME.xcodeproj"

echo "Renamed $OLD_NAME ($OLD_BUNDLE_ID) to $NEW_NAME ($NEW_BUNDLE_ID)."
echo "Next steps:"
echo "  1. xcodebuild test -scheme Dev -destination 'platform=iOS Simulator,name=iPhone 17'"
echo "  2. git add -A && git commit -m \"chore: rename template to $NEW_NAME\""
echo "  3. Open $NEW_NAME.xcodeproj and pick your signing team."
