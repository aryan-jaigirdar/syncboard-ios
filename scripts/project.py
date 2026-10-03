#!/usr/bin/env python3
"""Generate a small, dependency-free Xcode project from the app source files."""
import hashlib
import pathlib

root = pathlib.Path(__file__).resolve().parents[1]
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def q(value): return '"' + value.replace('"', '\\"') + '"'
objects = []
def obj(name, body): objects.append(f'{uid(name)} = {{ {body} }};'); return uid(name)
files = sorted((root / 'App').glob('*.swift'))
refs, builds = [], []
for file in files:
    ref = obj(file.name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(file.name)}; sourceTree = "<group>";')
    refs.append(ref)
    builds.append(obj(file.name + '-build', f'isa = PBXBuildFile; fileRef = {ref};'))
appgroup = obj('appgroup', f'isa = PBXGroup; children = ({",".join(refs)}); path = App; sourceTree = "<group>";')
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Syncboard.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({product}); name = Products; sourceTree = "<group>";')
main = obj('main', f'isa = PBXGroup; children = ({appgroup},{products}); sourceTree = "<group>";')
source = obj('source', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
package = obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = ".";')
dependency = obj('dependency', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = SyncboardCore;')
frameworkBuild = obj('frameworkBuild', f'isa = PBXBuildFile; productRef = {dependency};')
frameworks = obj('frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({frameworkBuild}); runOnlyForDeploymentPostprocessing = 0;')
projectconfigs, targetconfigs = [], []
for mode in ['Debug', 'Release']:
    settings = 'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 26.0; SWIFT_VERSION = 6.0; CLANG_ENABLE_MODULES = YES;'
    settings += ' SWIFT_OPTIMIZATION_LEVEL = "-Onone"; ONLY_ACTIVE_ARCH = YES;' if mode == 'Debug' else ' SWIFT_OPTIMIZATION_LEVEL = "-O";'
    projectconfigs.append(obj('project-' + mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{{settings}}};'))
    settings = '''PRODUCT_NAME = Syncboard; PRODUCT_BUNDLE_IDENTIFIER = com.aryanjaigirdar.syncboard;
        GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = App/Info.plist; INFOPLIST_KEY_CFBundleDisplayName = Syncboard;
        INFOPLIST_KEY_UILaunchScreen_Generation = YES;
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO;
        INFOPLIST_KEY_NSAppTransportSecurity_NSAllowsLocalNetworking = YES;
        TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic;
        CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 0.1.0;
        SWIFT_STRICT_CONCURRENCY = complete; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
        '''
    targetconfigs.append(obj('target-' + mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{{settings}}};'))
pc = obj('projectconfig', f'isa = XCConfigurationList; buildConfigurations = ({",".join(projectconfigs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
tc = obj('targetconfig', f'isa = XCConfigurationList; buildConfigurations = ({",".join(targetconfigs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {tc}; buildPhases = ({source},{frameworks}); buildRules = (); dependencies = (); name = Syncboard; packageProductDependencies = ({dependency}); productName = Syncboard; productReference = {product}; productType = "com.apple.product-type.application";')
uiRef = obj('uiTestFile', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OfflineJourneyTests.swift; sourceTree = "<group>";')
uiGroup = obj('uiGroup', f'isa = PBXGroup; children = ({uiRef}); path = UITests; sourceTree = "<group>";')
uiBuild = obj('uiBuild', f'isa = PBXBuildFile; fileRef = {uiRef};')
uiSources = obj('uiSources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({uiBuild}); runOnlyForDeploymentPostprocessing = 0;')
uiProduct = obj('uiProduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = SyncboardUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
uiConfigs = []
for mode in ['Debug', 'Release']:
    uiConfigs.append(obj('ui-' + mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ PRODUCT_NAME = SyncboardUITests; PRODUCT_BUNDLE_IDENTIFIER = com.aryanjaigirdar.syncboard.uitests; GENERATE_INFOPLIST_FILE = YES; TEST_TARGET_NAME = Syncboard; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; }};'))
uiConfigList = obj('uiConfigList', f'isa = XCConfigurationList; buildConfigurations = ({",".join(uiConfigs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
uiTarget = obj('uiTarget', f'isa = PBXNativeTarget; buildConfigurationList = {uiConfigList}; buildPhases = ({uiSources}); buildRules = (); dependencies = (); name = SyncboardUITests; productName = SyncboardUITests; productReference = {uiProduct}; productType = "com.apple.product-type.bundle.ui-testing";')
objects = [item.replace(f'children = ({appgroup},{products});', f'children = ({appgroup},{uiGroup},{products});').replace(f'children = ({product});', f'children = ({product},{uiProduct});') for item in objects]
project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; packageReferences = ({package}); productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},{uiTarget});')
folder = root / 'Syncboard.xcodeproj'
folder.mkdir(exist_ok=True)
(folder / 'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 60; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {project};}}\n')
schemes = folder / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
(schemes / 'Syncboard.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Syncboard.app" BlueprintName="Syncboard" ReferencedContainer="container:Syncboard.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uiTarget}" BuildableName="SyncboardUITests.xctest" BlueprintName="SyncboardUITests" ReferencedContainer="container:Syncboard.xcodeproj"/></TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Syncboard.app" BlueprintName="Syncboard" ReferencedContainer="container:Syncboard.xcodeproj"/></BuildableProductRunnable></LaunchAction></Scheme>''')
print(folder)
