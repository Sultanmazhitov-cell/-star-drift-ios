"""Recreate the small, dependency-free Xcode project. No macOS tools required."""
from pathlib import Path
import json
import plistlib
import wave
import math
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "StarDrift"
files = ["StarDriftApp.swift", "GameModel.swift", "GameView.swift", "GameScene.swift",
         "Assets.xcassets", "PrivacyInfo.xcprivacy", "start.wav", "star.wav", "hit.wav", "gameOver.wav"]

def uid(n):
    return f"{n:024X}"

objects = []
def obj(n, body):
    objects.append(f"\t\t{uid(n)} = {{ {body} }};")

for i, name in enumerate(files):
    file_type = ("sourcecode.swift" if name.endswith(".swift") else
                 "folder.assetcatalog" if name.endswith(".xcassets") else
                 "text.xml" if name.endswith(".xcprivacy") else "audio.wav")
    obj(100 + i, f'isa = PBXFileReference; lastKnownFileType = {file_type}; path = "{name}"; sourceTree = "<group>";')
    obj(200 + i, f"isa = PBXBuildFile; fileRef = {uid(100+i)};")
obj(120, 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>";')
obj(121, 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = StarDrift.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj(122, 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = FlightUITests.swift; sourceTree = "<group>";')
obj(123, 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = StarDriftUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj(222, f'isa = PBXBuildFile; fileRef = {uid(122)};')
obj(1, f'isa = PBXGroup; children = ({uid(2)}, {uid(4)}, {uid(3)},); sourceTree = "<group>";')
obj(2, f'isa = PBXGroup; children = ({", ".join(uid(100+i) for i in range(len(files)))}, {uid(120)},); path = StarDrift; sourceTree = "<group>";')
obj(3, f'isa = PBXGroup; children = ({uid(121)}, {uid(123)},); name = Products; sourceTree = "<group>";')
obj(4, f'isa = PBXGroup; children = ({uid(122)},); path = StarDriftUITests; sourceTree = "<group>";')
obj(10, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join(uid(200+i) for i in range(4))},); runOnlyForDeploymentPostprocessing = 0;')
obj(11, f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join(uid(200+i) for i in range(4,len(files)))},); runOnlyForDeploymentPostprocessing = 0;')
obj(12, 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj(13, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({uid(222)},); runOnlyForDeploymentPostprocessing = 0;')
obj(14, 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj(15, 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj(20, f'isa = PBXNativeTarget; buildConfigurationList = {uid(32)}; buildPhases = ({uid(10)}, {uid(12)}, {uid(11)},); buildRules = (); dependencies = (); name = StarDrift; productName = StarDrift; productReference = {uid(121)}; productType = "com.apple.product-type.application";')
obj(21, f'isa = PBXNativeTarget; buildConfigurationList = {uid(33)}; buildPhases = ({uid(13)}, {uid(14)}, {uid(15)},); buildRules = (); dependencies = ({uid(23)},); name = StarDriftUITests; productName = StarDriftUITests; productReference = {uid(123)}; productType = "com.apple.product-type.bundle.ui-testing";')
obj(22, f'isa = PBXContainerItemProxy; containerPortal = {uid(30)}; proxyType = 1; remoteGlobalIDString = {uid(20)}; remoteInfo = StarDrift;')
obj(23, f'isa = PBXTargetDependency; target = {uid(20)}; targetProxy = {uid(22)};')
obj(30, f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {uid(20)} = {{ CreatedOnToolsVersion = 16.0; ProvisioningStyle = Automatic; }}; {uid(21)} = {{ CreatedOnToolsVersion = 16.0; ProvisioningStyle = Automatic; TestTargetID = {uid(20)}; }}; }}; }}; buildConfigurationList = {uid(31)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ru; hasScannedForEncodings = 0; knownRegions = (ru, Base,); mainGroup = {uid(1)}; productRefGroup = {uid(3)}; projectDirPath = ""; projectRoot = ""; targets = ({uid(20)}, {uid(21)},);')
obj(31, f'isa = XCConfigurationList; buildConfigurations = ({uid(40)}, {uid(41)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj(32, f'isa = XCConfigurationList; buildConfigurations = ({uid(42)}, {uid(43)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj(33, f'isa = XCConfigurationList; buildConfigurations = ({uid(44)}, {uid(45)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
common = 'CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; SWIFT_STRICT_CONCURRENCY = minimal;'
target = 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; DEVELOPMENT_TEAM = ""; ENABLE_PREVIEWS = YES; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = StarDrift/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks",); MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = com.example.StarDrift; PRODUCT_NAME = "$(TARGET_NAME)"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO; SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO; SWIFT_EMIT_LOC_STRINGS = YES; TARGETED_DEVICE_FAMILY = "1,2";'
obj(40, f'isa = XCBuildConfiguration; buildSettings = {{ {common} DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; GCC_OPTIMIZATION_LEVEL = 0; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; }}; name = Debug;')
obj(41, f'isa = XCBuildConfiguration; buildSettings = {{ {common} DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; SWIFT_COMPILATION_MODE = wholemodule; SWIFT_OPTIMIZATION_LEVEL = "-O"; VALIDATE_PRODUCT = YES; }}; name = Release;')
obj(42, f'isa = XCBuildConfiguration; buildSettings = {{ {target} }}; name = Debug;')
obj(43, f'isa = XCBuildConfiguration; buildSettings = {{ {target} }}; name = Release;')
test_target = 'CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = ""; GENERATE_INFOPLIST_FILE = YES; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks",); PRODUCT_BUNDLE_IDENTIFIER = com.example.StarDrift.UITests; PRODUCT_NAME = "$(TARGET_NAME)"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; TARGETED_DEVICE_FAMILY = "1,2"; TEST_TARGET_NAME = StarDrift;'
obj(44, f'isa = XCBuildConfiguration; buildSettings = {{ {test_target} }}; name = Debug;')
obj(45, f'isa = XCBuildConfiguration; buildSettings = {{ {test_target} }}; name = Release;')
project = '// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + f'\n\t}};\n\trootObject = {uid(30)};\n}}\n'
(ROOT / 'StarDrift.xcodeproj/project.pbxproj').write_text(project)

scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(20)}" BuildableName="StarDrift.app" BlueprintName="StarDrift" ReferencedContainer="container:StarDrift.xcodeproj"/></BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(21)}" BuildableName="StarDriftUITests.xctest" BlueprintName="StarDriftUITests" ReferencedContainer="container:StarDrift.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(21)}" BuildableName="StarDriftUITests.xctest" BlueprintName="StarDriftUITests" ReferencedContainer="container:StarDrift.xcodeproj"/></TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(20)}" BuildableName="StarDrift.app" BlueprintName="StarDrift" ReferencedContainer="container:StarDrift.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(20)}" BuildableName="StarDrift.app" BlueprintName="StarDrift" ReferencedContainer="container:StarDrift.xcodeproj"/></BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(ROOT / 'StarDrift.xcodeproj/xcshareddata/xcschemes/StarDrift.xcscheme').write_text(scheme)

assets = SOURCE / 'Assets.xcassets'
(assets / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2))
(assets / 'AppIcon.appiconset/Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2))
colors = assets / 'LaunchBackground.colorset'
colors.mkdir(exist_ok=True)
(colors / 'Contents.json').write_text(json.dumps({'colors': [{'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': {'alpha': '1.000', 'blue': '0.106', 'green': '0.059', 'red': '0.031'}}}], 'info': {'author': 'xcode', 'version': 1}}, indent=2))

# Original synthesized effects; no media dependencies or network calls.
notes = {'start': [(440, .13), (660, .18)], 'star': [(780, .09), (1170, .16)], 'hit': [(110, .13), (65, .18)], 'gameOver': [(330, .16), (220, .18), (165, .23)]}
for name, sequence in notes.items():
    samples = []
    rate = 22050
    for frequency, duration in sequence:
        count = int(duration * rate)
        for i in range(count):
            envelope = min(1, i / (rate * .008)) * (1-i/count)**2
            value = math.sin(2*math.pi*frequency*i/rate) * envelope * .42
            samples.append(struct.pack('<h', int(value * 32767)))
    with wave.open(str(SOURCE / f'{name}.wav'), 'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(rate)
        output.writeframes(b''.join(samples))
print('Xcode project, scheme, asset metadata and original sound effects generated.')
