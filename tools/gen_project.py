#!/usr/bin/env python3
"""Generates Tallyho.xcodeproj (Xcode 16+ synchronized-folder format).

Targets:
  Tallyho                 iOS app          folders: Tallyho/, Shared/
  TallyhoWidgetsExtension widget extension folder: TallyhoWidgets/ (+ listed Shared/ files)
  Tallyho Watch App       watchOS app      folder: TallyhoWatch/  (+ listed Shared/ files)

Re-run after adding a file to Shared/ that the widget or watch also needs:
  python3 tools/gen_project.py
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEAM = "AT4H4G56UK"
BUNDLE = "MMT.Tallyho"
IOS_MIN = "26.0"
WATCH_MIN = "26.0"


def oid(name):
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()


def shared_files(exclude_dirs=()):
    out = []
    base = os.path.join(ROOT, "Shared")
    for dirpath, _, files in os.walk(base):
        rel_dir = os.path.relpath(dirpath, base)
        if any(rel_dir == d or rel_dir.startswith(d + os.sep) for d in exclude_dirs):
            continue
        for f in files:
            if f.endswith(".swift"):
                out.append(os.path.normpath(os.path.join(rel_dir, f)))
    return sorted(out)


# Shared/ files the widget and the watch also compile.
WIDGET_SHARED = shared_files()
WATCH_SHARED = shared_files(exclude_dirs=("Intents", "Storage"))

P = {k: oid(k) for k in [
    "project", "main_group", "products_group", "proj_conf_list", "proj_debug", "proj_release",
    "app", "app_product", "app_sources", "app_frameworks", "app_resources", "app_embed_ext", "app_embed_watch",
    "app_conf_list", "app_debug", "app_release",
    "wid", "wid_product", "wid_sources", "wid_frameworks", "wid_resources", "wid_conf_list", "wid_debug", "wid_release",
    "wat", "wat_product", "wat_sources", "wat_frameworks", "wat_resources", "wat_conf_list", "wat_debug", "wat_release",
    "grp_app", "grp_shared", "grp_wid", "grp_wat",
    "exc_shared_wid", "exc_shared_wat",
    "bf_wid_embed", "bf_wat_embed", "proxy_wid", "proxy_wat", "dep_wid", "dep_wat",
]}

COMMON = """				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				COPY_PHASE_STRIP = NO;
				DEVELOPMENT_TEAM = %(team)s;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = %(ios)s;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				WATCHOS_DEPLOYMENT_TARGET = %(watch)s;
""" % {"team": TEAM, "ios": IOS_MIN, "watch": WATCH_MIN}

DEBUG_EXTRA = """				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""
RELEASE_EXTRA = """				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
"""

APP = """				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = Config/Tallyho.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = %(team)s;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "Config/Tallyho-Info.plist";
				INFOPLIST_KEY_CFBundleDisplayName = Tallyho;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = %(bundle)s;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
""" % {"team": TEAM, "bundle": BUNDLE}

WIDGET = """				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;
				CODE_SIGN_ENTITLEMENTS = Config/TallyhoWidgets.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = %(team)s;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "Config/TallyhoWidgets-Info.plist";
				INFOPLIST_KEY_CFBundleDisplayName = Tallyho;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = %(bundle)s.Widgets;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
""" % {"team": TEAM, "bundle": BUNDLE}

WATCH = """				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = %(team)s;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Tallyho;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown";
				INFOPLIST_KEY_WKCompanionAppBundleIdentifier = %(bundle)s;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = %(bundle)s.watchkitapp;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 4;
""" % {"team": TEAM, "bundle": BUNDLE}


def conf(key, name, body):
    return "\t\t%s /* %s */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n%s\t\t\t};\n\t\t\tname = %s;\n\t\t};\n" % (P[key], name, body, name)


def phase(key, isa, name, files=""):
    return "\t\t%s /* %s */ = {\n\t\t\tisa = %s;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n%s\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n" % (P[key], name, isa, files)


def exc(key, label, target_key, files):
    lines = "".join("\t\t\t\t%s,\n" % (('"%s"' % f) if (" " in f or "/" in f or "+" in f) else f) for f in files)
    return "\t\t%s /* %s */ = {\n\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;\n\t\t\tmembershipExceptions = (\n%s\t\t\t);\n\t\t\ttarget = %s;\n\t\t};\n" % (P[key], label, lines, P[target_key])


def target(key, name, conf_list, phases, deps, groups, product, ptype):
    return """		%(id)s /* %(name)s */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = %(cl)s;
			buildPhases = (
%(phases)s			);
			buildRules = (
			);
			dependencies = (
%(deps)s			);
			fileSystemSynchronizedGroups = (
%(groups)s			);
			name = "%(name)s";
			packageProductDependencies = (
			);
			productName = "%(name)s";
			productReference = %(product)s;
			productType = "%(ptype)s";
		};
""" % {"id": P[key], "name": name, "cl": P[conf_list],
       "phases": "".join("\t\t\t\t%s,\n" % P[p] for p in phases),
       "deps": "".join("\t\t\t\t%s,\n" % P[d] for d in deps),
       "groups": "".join("\t\t\t\t%s,\n" % P[g] for g in groups),
       "product": P[product], "ptype": ptype}


out = []
out.append("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 77;\n\tobjects = {\n\n")

out.append("/* Begin PBXBuildFile section */\n")
out.append('\t\t%s /* TallyhoWidgetsExtension.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = %s; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\n' % (P["bf_wid_embed"], P["wid_product"]))
out.append('\t\t%s /* Tallyho Watch App.app in Embed Watch Content */ = {isa = PBXBuildFile; fileRef = %s; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\n' % (P["bf_wat_embed"], P["wat_product"]))
out.append("/* End PBXBuildFile section */\n\n")

out.append("/* Begin PBXContainerItemProxy section */\n")
for k, t, n in [("proxy_wid", "wid", "TallyhoWidgetsExtension"), ("proxy_wat", "wat", "Tallyho Watch App")]:
    out.append('\t\t%s /* PBXContainerItemProxy */ = {\n\t\t\tisa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = %s;\n\t\t\tproxyType = 1;\n\t\t\tremoteGlobalIDString = %s;\n\t\t\tremoteInfo = "%s";\n\t\t};\n' % (P[k], P["project"], P[t], n))
out.append("/* End PBXContainerItemProxy section */\n\n")

out.append("/* Begin PBXCopyFilesBuildPhase section */\n")
out.append('\t\t%s /* Embed Foundation Extensions */ = {\n\t\t\tisa = PBXCopyFilesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tdstPath = "";\n\t\t\tdstSubfolderSpec = 13;\n\t\t\tfiles = (\n\t\t\t\t%s,\n\t\t\t);\n\t\t\tname = "Embed Foundation Extensions";\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n' % (P["app_embed_ext"], P["bf_wid_embed"]))
out.append('\t\t%s /* Embed Watch Content */ = {\n\t\t\tisa = PBXCopyFilesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tdstPath = "$(CONTENTS_FOLDER_PATH)/Watch";\n\t\t\tdstSubfolderSpec = 16;\n\t\t\tfiles = (\n\t\t\t\t%s,\n\t\t\t);\n\t\t\tname = "Embed Watch Content";\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n' % (P["app_embed_watch"], P["bf_wat_embed"]))
out.append("/* End PBXCopyFilesBuildPhase section */\n\n")

out.append("/* Begin PBXFileReference section */\n")
out.append('\t\t%s /* Tallyho.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Tallyho.app; sourceTree = BUILT_PRODUCTS_DIR; };\n' % P["app_product"])
out.append('\t\t%s /* TallyhoWidgetsExtension.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = TallyhoWidgetsExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; };\n' % P["wid_product"])
out.append('\t\t%s /* Tallyho Watch App.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "Tallyho Watch App.app"; sourceTree = BUILT_PRODUCTS_DIR; };\n' % P["wat_product"])
out.append("/* End PBXFileReference section */\n\n")

out.append("/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */\n")
out.append(exc("exc_shared_wid", 'Exceptions for "Shared" folder in "TallyhoWidgetsExtension" target', "wid", WIDGET_SHARED))
out.append(exc("exc_shared_wat", 'Exceptions for "Shared" folder in "Tallyho Watch App" target', "wat", WATCH_SHARED))
out.append("/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */\n\n")

out.append("/* Begin PBXFileSystemSynchronizedRootGroup section */\n")
for g, path, excs in [("grp_app", "Tallyho", []), ("grp_shared", "Shared", ["exc_shared_wid", "exc_shared_wat"]),
                      ("grp_wid", "TallyhoWidgets", []), ("grp_wat", "TallyhoWatch", [])]:
    ex = ""
    if excs:
        ex = "\t\t\texceptions = (\n" + "".join("\t\t\t\t%s,\n" % P[e] for e in excs) + "\t\t\t);\n"
    out.append('\t\t%s /* %s */ = {\n\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n%s\t\t\tpath = %s;\n\t\t\tsourceTree = "<group>";\n\t\t};\n' % (P[g], path, ex, path))
out.append("/* End PBXFileSystemSynchronizedRootGroup section */\n\n")

out.append("/* Begin PBXFrameworksBuildPhase section */\n")
for k in ["app_frameworks", "wid_frameworks", "wat_frameworks"]:
    out.append(phase(k, "PBXFrameworksBuildPhase", "Frameworks"))
out.append("/* End PBXFrameworksBuildPhase section */\n\n")

out.append("/* Begin PBXGroup section */\n")
out.append('\t\t%s = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t%s,\n\t\t\t\t%s,\n\t\t\t\t%s,\n\t\t\t\t%s,\n\t\t\t\t%s,\n\t\t\t);\n\t\t\tsourceTree = "<group>";\n\t\t};\n' % (P["main_group"], P["grp_app"], P["grp_shared"], P["grp_wid"], P["grp_wat"], P["products_group"]))
out.append('\t\t%s /* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t%s,\n\t\t\t\t%s,\n\t\t\t\t%s,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = "<group>";\n\t\t};\n' % (P["products_group"], P["app_product"], P["wid_product"], P["wat_product"]))
out.append("/* End PBXGroup section */\n\n")

out.append("/* Begin PBXNativeTarget section */\n")
out.append(target("app", "Tallyho", "app_conf_list", ["app_sources", "app_frameworks", "app_resources", "app_embed_ext", "app_embed_watch"],
                  ["dep_wid", "dep_wat"], ["grp_app", "grp_shared"], "app_product", "com.apple.product-type.application"))
out.append(target("wid", "TallyhoWidgetsExtension", "wid_conf_list", ["wid_sources", "wid_frameworks", "wid_resources"],
                  [], ["grp_wid"], "wid_product", "com.apple.product-type.app-extension"))
out.append(target("wat", "Tallyho Watch App", "wat_conf_list", ["wat_sources", "wat_frameworks", "wat_resources"],
                  [], ["grp_wat"], "wat_product", "com.apple.product-type.application"))
out.append("/* End PBXNativeTarget section */\n\n")

out.append("/* Begin PBXProject section */\n")
out.append("""		%(project)s /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2660;
				LastUpgradeCheck = 2660;
				TargetAttributes = {
					%(app)s = {
						CreatedOnToolsVersion = 26.6;
					};
					%(wid)s = {
						CreatedOnToolsVersion = 26.6;
					};
					%(wat)s = {
						CreatedOnToolsVersion = 26.6;
					};
				};
			};
			buildConfigurationList = %(proj_conf_list)s;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = %(main_group)s;
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = %(products_group)s;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				%(app)s,
				%(wid)s,
				%(wat)s,
			);
		};
""" % P)
out.append("/* End PBXProject section */\n\n")

out.append("/* Begin PBXResourcesBuildPhase section */\n")
for k in ["app_resources", "wid_resources", "wat_resources"]:
    out.append(phase(k, "PBXResourcesBuildPhase", "Resources"))
out.append("/* End PBXResourcesBuildPhase section */\n\n")

out.append("/* Begin PBXSourcesBuildPhase section */\n")
for k in ["app_sources", "wid_sources", "wat_sources"]:
    out.append(phase(k, "PBXSourcesBuildPhase", "Sources"))
out.append("/* End PBXSourcesBuildPhase section */\n\n")

out.append("/* Begin PBXTargetDependency section */\n")
for d, t, p in [("dep_wid", "wid", "proxy_wid"), ("dep_wat", "wat", "proxy_wat")]:
    out.append("\t\t%s /* PBXTargetDependency */ = {\n\t\t\tisa = PBXTargetDependency;\n\t\t\ttarget = %s;\n\t\t\ttargetProxy = %s;\n\t\t};\n" % (P[d], P[t], P[p]))
out.append("/* End PBXTargetDependency section */\n\n")

out.append("/* Begin XCBuildConfiguration section */\n")
out.append(conf("proj_debug", "Debug", COMMON + DEBUG_EXTRA))
out.append(conf("proj_release", "Release", COMMON + RELEASE_EXTRA))
out.append(conf("app_debug", "Debug", APP))
out.append(conf("app_release", "Release", APP))
out.append(conf("wid_debug", "Debug", WIDGET))
out.append(conf("wid_release", "Release", WIDGET))
out.append(conf("wat_debug", "Debug", WATCH))
out.append(conf("wat_release", "Release", WATCH))
out.append("/* End XCBuildConfiguration section */\n\n")

out.append("/* Begin XCConfigurationList section */\n")
for cl, d, r, label in [("proj_conf_list", "proj_debug", "proj_release", 'PBXProject "Tallyho"'),
                        ("app_conf_list", "app_debug", "app_release", 'PBXNativeTarget "Tallyho"'),
                        ("wid_conf_list", "wid_debug", "wid_release", 'PBXNativeTarget "TallyhoWidgetsExtension"'),
                        ("wat_conf_list", "wat_debug", "wat_release", 'PBXNativeTarget "Tallyho Watch App"')]:
    out.append("\t\t%s /* Build configuration list for %s */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t%s,\n\t\t\t\t%s,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t};\n" % (P[cl], label, P[d], P[r]))
out.append("/* End XCConfigurationList section */\n")
out.append("\t};\n\trootObject = %s /* Project object */;\n}\n" % P["project"])

proj = os.path.join(ROOT, "Tallyho.xcodeproj")
os.makedirs(os.path.join(proj, "project.xcworkspace"), exist_ok=True)
os.makedirs(os.path.join(proj, "xcshareddata", "xcschemes"), exist_ok=True)
with open(os.path.join(proj, "project.pbxproj"), "w") as f:
    f.write("".join(out))
with open(os.path.join(proj, "project.xcworkspace", "contents.xcworkspacedata"), "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n')


def buildable(key, name, product):
    return """<BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "%s"
               BuildableName = "%s"
               BlueprintName = "%s"
               ReferencedContainer = "container:Tallyho.xcodeproj">
            </BuildableReference>""" % (P[key], product, name)


scheme = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2660"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            %(app)s
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         %(app)s
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         %(app)s
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""" % {"app": buildable("app", "Tallyho", "Tallyho.app")}
with open(os.path.join(proj, "xcshareddata", "xcschemes", "Tallyho.xcscheme"), "w") as f:
    f.write(scheme)

watch_scheme = scheme.replace(buildable("app", "Tallyho", "Tallyho.app"), buildable("wat", "Tallyho Watch App", "Tallyho Watch App.app"))
with open(os.path.join(proj, "xcshareddata", "xcschemes", "Tallyho Watch App.xcscheme"), "w") as f:
    f.write(watch_scheme)

print("Generated Tallyho.xcodeproj")
print("  widget shares:", len(WIDGET_SHARED), "files; watch shares:", len(WATCH_SHARED), "files")
