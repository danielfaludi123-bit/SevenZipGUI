#!/usr/bin/env python3
"""
Generiert SevenZipGUI.xcodeproj (OpenStep-Format) für macOS:
- App-Target (SwiftUI)
- Unit-Test-Target (XCTest, hostet auf der App)
Ausführen vom Projektroot:  python3 scripts/generate_xcodeproj.py
"""

import os, uuid

PROJECT_NAME = "SevenZipGUI"
BUNDLE_ID = "com.danielfaludi.SevenZipGUI"
DEPLOYMENT_TARGET = "14.0"
SWIFT_VERSION = "5.0"

app_files = [
    ("SevenZipGUI/App/SevenZipGUIApp.swift", "Sources"),
    ("SevenZipGUI/Models/AppState.swift", "Sources"),
    ("SevenZipGUI/Models/ArchiveFormat.swift", "Sources"),
    ("SevenZipGUI/Models/ArchiveEntry.swift", "Sources"),
    ("SevenZipGUI/Models/SevenZipError.swift", "Sources"),
    ("SevenZipGUI/Services/SevenZipLocator.swift", "Sources"),
    ("SevenZipGUI/Services/SevenZipArguments.swift", "Sources"),
    ("SevenZipGUI/Services/SevenZipRunner.swift", "Sources"),
    ("SevenZipGUI/Services/ArchiveInspector.swift", "Sources"),
    ("SevenZipGUI/Services/SevenZipService.swift", "Sources"),
    ("SevenZipGUI/ViewModels/JobViewModel.swift", "Sources"),
    ("SevenZipGUI/ViewModels/CreateArchiveViewModel.swift", "Sources"),
    ("SevenZipGUI/ViewModels/OpenArchiveViewModel.swift", "Sources"),
    ("SevenZipGUI/ViewModels/ExtractArchiveViewModel.swift", "Sources"),
    ("SevenZipGUI/Views/RootView.swift", "Sources"),
    ("SevenZipGUI/Views/HomeView.swift", "Sources"),
    ("SevenZipGUI/Views/CreateArchiveView.swift", "Sources"),
    ("SevenZipGUI/Views/OpenArchiveView.swift", "Sources"),
    ("SevenZipGUI/Views/ExtractArchiveView.swift", "Sources"),
    ("SevenZipGUI/Views/SettingsView.swift", "Sources"),
    ("SevenZipGUI/Views/Components/JobProgressView.swift", "Sources"),
    ("SevenZipGUI/Assets.xcassets", "Resources"),
    ("Info.plist", None),
]

test_files = [
    ("SevenZipGUITests/ArgumentBuilderTests.swift", "Sources"),
    ("SevenZipGUITests/ListParserTests.swift", "Sources"),
    ("SevenZipGUITests/ErrorAndLocatorTests.swift", "Sources"),
]

uuids = {}
def uid(key):
    if key not in uuids:
        uuids[key] = uuid.uuid4().hex.upper()[:24]
    return uuids[key]

def esc(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def fmt(v, indent=1):
    if isinstance(v, str):
        return esc(v)
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, list):
        if not v:
            return "( )"
        items = [fmt(x, indent + 1) for x in v]
        return "(\n" + "\t" * indent + (",\n" + "\t" * indent).join(items) + "\n" + "\t" * (indent - 1) + ")"
    if isinstance(v, dict):
        lines = ["{"]
        for k, val in v.items():
            lines.append("\t" * indent + f"{k} = {fmt(val, indent + 1)};")
        lines.append("\t" * (indent - 1) + "}")
        return "\n".join(lines)
    return str(v)

objects = {}
all_files = app_files + test_files

# --- UUIDs ---
project_uid = uid("project")
main_group_uid = uid("main_group")
products_group_uid = uid("products_group")
app_target_uid = uid("app_target")
test_target_uid = uid("test_target")
app_sources_uid = uid("app_sources")
app_resources_uid = uid("app_resources")
app_frameworks_uid = uid("app_frameworks")
test_sources_uid = uid("test_sources")
test_frameworks_uid = uid("test_frameworks")
project_cl_uid = uid("project_cl")
app_cl_uid = uid("app_cl")
test_cl_uid = uid("test_cl")
app_product_uid = uid("app_product")
test_product_uid = uid("test_product")
dependency_uid = uid("dependency")
target_proxy_uid = uid("target_proxy")

# --- PBXBuildFile + PBXFileReference ---
file_refs = {}
build_files = {}
for path, kind in all_files:
    file_refs[path] = uid("fr_" + path)
    if kind:
        build_files[path] = uid("bf_" + path)

for path, kind in all_files:
    if kind:
        objects[build_files[path]] = {"isa": "PBXBuildFile", "fileRef": file_refs[path]}

for path, kind in all_files:
    last = os.path.basename(path)
    if path.endswith(".swift"):
        ftype = "sourcecode.swift"
        ref = {"isa": "PBXFileReference", "lastKnownFileType": ftype,
               "path": last, "sourceTree": "<group>"}
    elif path.endswith(".xcassets"):
        ref = {"isa": "PBXFileReference", "lastKnownFileType": "folder.assetcatalog",
               "path": last, "sourceTree": "<group>"}
    elif path.endswith(".plist"):
        ref = {"isa": "PBXFileReference", "lastKnownFileType": "text.plist.xml",
               "path": last, "sourceTree": "<group>"}
    else:
        continue
    objects[file_refs[path]] = ref

objects[app_product_uid] = {
    "isa": "PBXFileReference", "explicitFileType": "wrapper.application",
    "includeInIndex": 0, "path": f"{PROJECT_NAME}.app", "sourceTree": "BUILT_PRODUCTS_DIR",
}
objects[test_product_uid] = {
    "isa": "PBXFileReference", "explicitFileType": "wrapper.cfbundle",
    "includeInIndex": 0, "path": f"{PROJECT_NAME}Tests.xctest", "sourceTree": "BUILT_PRODUCTS_DIR",
}

# --- PBXGroup: physische Ordnerstruktur spiegeln ---
group_uuids = {"": main_group_uid, "Products": products_group_uid}
for path, kind in all_files:
    d = os.path.dirname(path)
    # Verschachtelte Pfade vollständig registrieren
    parts = d.split("/") if d else []
    for i in range(1, len(parts) + 1):
        sub = "/".join(parts[:i])
        if sub and sub not in group_uuids:
            group_uuids[sub] = uid("g_" + sub)

children = {g: [] for g in group_uuids}
for path, kind in all_files:
    children[os.path.dirname(path)].append(file_refs[path])

for d, guid in group_uuids.items():
    if d == "":
        name = PROJECT_NAME
    elif d == "Products":
        name = "Products"
    else:
        name = os.path.basename(d)
    obj = {"isa": "PBXGroup", "children": children[d], "name": name, "sourceTree": "<group>"}
    if d not in ("", "Products"):
        obj["path"] = name
    objects[guid] = obj

# Verschachtelung der Gruppen
for d in group_uuids:
    parent = os.path.dirname(d)
    if parent in children and d not in ("", "Products"):
        children[parent].append(group_uuids[d])

objects[main_group_uid]["children"] = [
    group_uuids.get("SevenZipGUI"),
    group_uuids.get("SevenZipGUITests"),
    uid("g_root_plist_placeholder") if False else None,
    products_group_uid,
]
# Info.plist an Root-Gruppe hängen
objects[main_group_uid]["children"] = [
    c for c in objects[main_group_uid]["children"] if c
] + [file_refs["Info.plist"]]
objects[products_group_uid]["children"] = [app_product_uid, test_product_uid]

# --- Build Phases ---
objects[app_sources_uid] = {
    "isa": "PBXSourcesBuildPhase", "buildActionMask": "2147483647",
    "files": [build_files[p] for p, k in app_files if k == "Sources"],
    "runOnlyForDeploymentPostprocessing": 0,
}
objects[app_resources_uid] = {
    "isa": "PBXResourcesBuildPhase", "buildActionMask": "2147483647",
    "files": [build_files[p] for p, k in app_files if k == "Resources"],
    "runOnlyForDeploymentPostprocessing": 0,
}
objects[app_frameworks_uid] = {
    "isa": "PBXFrameworksBuildPhase", "buildActionMask": "2147483647",
    "files": [], "runOnlyForDeploymentPostprocessing": 0,
}
objects[test_sources_uid] = {
    "isa": "PBXSourcesBuildPhase", "buildActionMask": "2147483647",
    "files": [build_files[p] for p, k in test_files if k == "Sources"],
    "runOnlyForDeploymentPostprocessing": 0,
}
objects[test_frameworks_uid] = {
    "isa": "PBXFrameworksBuildPhase", "buildActionMask": "2147483647",
    "files": [], "runOnlyForDeploymentPostprocessing": 0,
}

# --- Targets ---
objects[target_proxy_uid] = {
    "isa": "PBXContainerItemProxy", "containerPortal": project_uid,
    "proxyType": 1, "remoteGlobalIDString": app_target_uid, "remoteInfo": PROJECT_NAME,
}
objects[dependency_uid] = {
    "isa": "PBXTargetDependency", "target": app_target_uid, "targetProxy": target_proxy_uid,
}
objects[app_target_uid] = {
    "isa": "PBXNativeTarget", "buildConfigurationList": app_cl_uid,
    "buildPhases": [app_sources_uid, app_frameworks_uid, app_resources_uid],
    "buildRules": [], "dependencies": [], "name": PROJECT_NAME,
    "productName": PROJECT_NAME, "productReference": app_product_uid,
    "productType": "com.apple.product-type.application",
}
objects[test_target_uid] = {
    "isa": "PBXNativeTarget", "buildConfigurationList": test_cl_uid,
    "buildPhases": [test_sources_uid, test_frameworks_uid],
    "buildRules": [], "dependencies": [dependency_uid], "name": f"{PROJECT_NAME}Tests",
    "productName": f"{PROJECT_NAME}Tests", "productReference": test_product_uid,
    "productType": "com.apple.product-type.bundle.unit-test",
}

# --- PBXProject ---
objects[project_uid] = {
    "isa": "PBXProject",
    "attributes": {
        "BuildIndependentTargetsInParallel": "1",
        "LastSwiftUpdateCheck": "1620",
        "LastUpgradeCheck": "2700",
        "TargetAttributes": {
            app_target_uid: {"CreatedOnToolsVersion": "26.2"},
            test_target_uid: {"CreatedOnToolsVersion": "26.2", "TestTargetID": app_target_uid},
        },
    },
    "buildConfigurationList": project_cl_uid,
    "compatibilityVersion": "Xcode 14.0",
    "developmentRegion": "de",
    "hasScannedForEncodings": 0,
    "knownRegions": ["de", "Base", "en"],
    "mainGroup": main_group_uid,
    "productRefGroup": products_group_uid,
    "projectDirPath": "",
    "projectRoot": "",
    "targets": [app_target_uid, test_target_uid],
}

# --- Build Settings ---
proj_debug = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_TESTABILITY": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MACOSX_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "ONLY_ACTIVE_ARCH": "YES",
    "SDKROOT": "macosx",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}
proj_release = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_NS_ASSERTIONS": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_OPTIMIZATION_LEVEL": "s",
    "MACOSX_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "SDKROOT": "macosx",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
    "VALIDATE_PRODUCT": "YES",
}
app_base = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "ENABLE_HARDENED_RUNTIME": "NO",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks"],
    "MACOSX_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "MARKETING_VERSION": "1.0.0",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": SWIFT_VERSION,
}
app_debug = dict(app_base)
app_debug["DEBUG_INFORMATION_FORMAT"] = "dwarf"
app_debug["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
app_release = dict(app_base)
app_release["DEBUG_INFORMATION_FORMAT"] = "dwarf-with-dsym"

test_base = {
    "BUNDLE_LOADER": "$(TEST_HOST)",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "YES",
    "MACOSX_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID + ".tests",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "SWIFT_VERSION": SWIFT_VERSION,
    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/" + PROJECT_NAME + ".app/Contents/MacOS/" + PROJECT_NAME,
}
test_debug = dict(test_base)
test_release = dict(test_base)

objects[uid("proj_debug")] = {"isa": "XCBuildConfiguration", "buildSettings": proj_debug, "name": "Debug"}
objects[uid("proj_release")] = {"isa": "XCBuildConfiguration", "buildSettings": proj_release, "name": "Release"}
objects[uid("app_debug")] = {"isa": "XCBuildConfiguration", "buildSettings": app_debug, "name": "Debug"}
objects[uid("app_release")] = {"isa": "XCBuildConfiguration", "buildSettings": app_release, "name": "Release"}
objects[uid("test_debug")] = {"isa": "XCBuildConfiguration", "buildSettings": test_debug, "name": "Debug"}
objects[uid("test_release")] = {"isa": "XCBuildConfiguration", "buildSettings": test_release, "name": "Release"}

objects[project_cl_uid] = {
    "isa": "XCConfigurationList",
    "buildConfigurations": [uid("proj_debug"), uid("proj_release")],
    "defaultConfigurationIsVisible": 0, "defaultConfigurationName": "Release",
}
objects[app_cl_uid] = {
    "isa": "XCConfigurationList",
    "buildConfigurations": [uid("app_debug"), uid("app_release")],
    "defaultConfigurationIsVisible": 0, "defaultConfigurationName": "Release",
}
objects[test_cl_uid] = {
    "isa": "XCConfigurationList",
    "buildConfigurations": [uid("test_debug"), uid("test_release")],
    "defaultConfigurationIsVisible": 0, "defaultConfigurationName": "Release",
}

# --- Schreiben ---
proj_dir = os.path.join(os.getcwd(), f"{PROJECT_NAME}.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)

with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
    f.write("// !$*UTF8*$!\n")
    f.write("{\n")
    f.write("\tarchiveVersion = 1;\n")
    f.write("\tclasses = {\n\t};\n")
    f.write("\tobjectVersion = 56;\n")
    f.write("\tobjects = {\n")

    grouped = {}
    for obj_id, obj in objects.items():
        grouped.setdefault(obj["isa"], []).append((obj_id, obj))

    order = ["PBXBuildFile", "PBXContainerItemProxy", "PBXFileReference", "PBXFrameworksBuildPhase",
             "PBXGroup", "PBXNativeTarget", "PBXProject", "PBXResourcesBuildPhase",
             "PBXSourcesBuildPhase", "PBXTargetDependency", "XCBuildConfiguration", "XCConfigurationList"]
    for isa in order:
        items = grouped.get(isa)
        if not items:
            continue
        f.write(f"\n/* Begin {isa} section */\n")
        for obj_id, obj in items:
            f.write(f"\t\t{obj_id} /* {obj.get('name', isa)} */ = {fmt(obj, 2)};\n")
        f.write(f"/* End {isa} section */\n")

    f.write("\t};\n")
    f.write(f"\trootObject = {project_uid} /* Project object */;\n")
    f.write("}\n")

print(f"Generated: {proj_dir}")
