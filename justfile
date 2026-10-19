default:
    @just --list

build:
    xcodebuild -project huuuiii.xcodeproj -scheme huuuiii -configuration Debug -destination 'platform=macOS' -derivedDataPath build -onlyUsePackageVersionsFromResolvedFile build

run: build
    open build/Build/Products/Debug/huuuiii.app

release:
    xcodebuild -project huuuiii.xcodeproj -scheme huuuiii -configuration Release -destination 'platform=macOS' -derivedDataPath build -onlyUsePackageVersionsFromResolvedFile CODE_SIGN_IDENTITY=- build

clean:
    xcodebuild -project huuuiii.xcodeproj -scheme huuuiii -derivedDataPath build -onlyUsePackageVersionsFromResolvedFile clean
