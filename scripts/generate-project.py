#!/usr/bin/env python3
"""Generate a dependency-free, conventional Xcode project from checked-in Swift sources."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
uid = lambda s: hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects = []
def obj(key, value):
    objects.append(f'{uid(key)} = {{ {value} }};')
    return uid(key)
sources = sorted((root/'ClipBro').rglob('*.swift'))
builds, refs = [], []
for path in sources:
    name = str(path.relative_to(root))
    ref = obj(name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = SOURCE_ROOT;')
    refs.append(ref)
    builds.append(obj(name+'build', f'isa = PBXBuildFile; fileRef = {ref};'))
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = ClipBro.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
obj('rootgroup', f'isa = PBXGroup; children = ({",".join(refs)},{uid("products")},); sourceTree = "<group>";')
obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
for config in ['Debug', 'Release']:
    obj('project'+config, f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES; }};')
    obj('target'+config, f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ PRODUCT_NAME = ClipBro; PRODUCT_BUNDLE_IDENTIFIER = com.usamam46.ClipBro; INFOPLIST_FILE = ClipBro/Resources/Info.plist; CODE_SIGN_STYLE = Automatic; CODE_SIGN_IDENTITY = "-"; ENABLE_HARDENED_RUNTIME = YES; SWIFT_OPTIMIZATION_LEVEL = {"-Onone" if config == "Debug" else "-O"}; }};')
for scope in ['project','target']:
    obj(scope+'configs', f'isa = XCConfigurationList; buildConfigurations = ({uid(scope+"Debug")},{uid(scope+"Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({uid("sources")},); buildRules = (); dependencies = (); name = ClipBro; productName = ClipBro; productReference = {product}; productType = "com.apple.product-type.application";')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {uid("rootgroup")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")},);')
(root/'ClipBro.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {uid("project")}; }}\n')
(root/'ClipBro.xcodeproj/xcshareddata/xcschemes/ClipBro.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="ClipBro.app" BlueprintName="ClipBro" ReferencedContainer="container:ClipBro.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="ClipBro.app" BlueprintName="ClipBro" ReferencedContainer="container:ClipBro.xcodeproj"/></BuildableProductRunnable></LaunchAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
