default:
    @just --list

build:
    xcodebuild -project huuuiii.xcodeproj -scheme huuuiii -configuration Debug -destination 'platform=macOS' -derivedDataPath build -onlyUsePackageVersionsFromResolvedFile build

run: build
    open build/Build/Products/Debug/huuuiii.app

test:
    mkdir -p build
    xcrun swiftc -swift-version 6 huuuiii/ModifierBinding.swift tests/ModifierBindingTests.swift -o build/ModifierBindingTests
    build/ModifierBindingTests
    xcrun swiftc -swift-version 6 huuuiii/ModifierBinding.swift huuuiii/ModifierRecorder.swift tests/ModifierRecorderTests.swift -o build/ModifierRecorderTests
    build/ModifierRecorderTests

release:
    xcodebuild -project huuuiii.xcodeproj -scheme huuuiii -configuration Release -destination 'platform=macOS' -derivedDataPath build -onlyUsePackageVersionsFromResolvedFile CODE_SIGN_IDENTITY=- build

install:
    cp -rf ./build/Build/Products/Release/huuuiii.app ~/Applications/

clean:
    xcodebuild -project huuuiii.xcodeproj -scheme huuuiii -derivedDataPath build -onlyUsePackageVersionsFromResolvedFile clean
