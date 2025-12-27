#!/usr/bin/env python3
"""
Add new Swift files to Xcode project
More precise group matching
"""
import re
import uuid

PROJECT_FILE = "/Users/markgentry/Projects/VoiceDay/VoiceDay.xcodeproj/project.pbxproj"

# Files to add with their relative paths and group locations
NEW_FILES = [
    # (filename, group_name)
    ("VoiceDayTask.swift", "Models"),
    ("TaskAttackAdvisor.swift", "Services"),
    ("TaskCoach.swift", "Services"),
    ("TaskAttackView.swift", "Views"),
    ("TaskBreakdownView.swift", "Views"),
    # Location-based checkout checklists
    ("LocationService.swift", "Services"),
    ("CheckoutChecklistService.swift", "Services"),
    ("CheckoutChecklistView.swift", "Views"),
    ("LocationsManagerView.swift", "Views"),
    # Voice cloning (standalone - was duplicated in ElevenLabsService.swift)
    ("VoiceCloningService.swift", "Services"),
]

def generate_uuid():
    """Generate a 24-character hex UUID like Xcode uses"""
    return uuid.uuid4().hex[:24].upper()

def read_project():
    with open(PROJECT_FILE, 'r') as f:
        return f.read()

def write_project(content):
    # Backup first
    backup = PROJECT_FILE + '.backup2'
    with open(PROJECT_FILE, 'r') as f:
        original = f.read()
    with open(backup, 'w') as f:
        f.write(original)

    with open(PROJECT_FILE, 'w') as f:
        f.write(content)
    print(f"✅ Wrote updated project file")

def find_group_children_location(content, group_name):
    """
    Find the exact position to insert a new file reference into a group.
    Returns the position right after 'children = (' for the specified group.
    """
    # Pattern matches a PBXGroup block with the specific path name
    # Looking for pattern like:
    #   isa = PBXGroup;
    #   children = (
    #       ...files...
    #   );
    #   path = GroupName;

    # First find all PBXGroup blocks
    group_pattern = r'(\w{24}) /\* ' + re.escape(group_name) + r' \*/ = \{\s*isa = PBXGroup;\s*children = \('

    match = re.search(group_pattern, content)
    if match:
        return match.end()

    # Alternative: search backwards from "path = GroupName;"
    path_pattern = rf'path = {group_name};\s*sourceTree'
    path_match = re.search(path_pattern, content)
    if path_match:
        # Now find the "children = (" before this
        search_start = max(0, path_match.start() - 2000)  # Search in preceding 2000 chars
        search_area = content[search_start:path_match.start()]

        children_pattern = r'children = \('
        children_matches = list(re.finditer(children_pattern, search_area))
        if children_matches:
            # Take the last one (closest to our path marker)
            last_match = children_matches[-1]
            return search_start + last_match.end()

    return None

def add_files():
    content = read_project()

    # Check which files are already added
    files_to_add = []
    for filename, group in NEW_FILES:
        if filename in content:
            print(f"⏭️  {filename} already in project, skipping")
        else:
            files_to_add.append((filename, group))

    if not files_to_add:
        print("All files already in project!")
        return

    # Generate UUIDs for each file
    file_refs = {}  # filename -> file_ref_uuid
    build_refs = {}  # filename -> build_file_uuid

    for filename, group in files_to_add:
        file_refs[filename] = generate_uuid()
        build_refs[filename] = generate_uuid()

    # 1. Add PBXBuildFile entries (after existing entries)
    build_file_section = "/* Begin PBXBuildFile section */"
    build_file_entries = ""
    for filename, group in files_to_add:
        entry = f"\t\t{build_refs[filename]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[filename]} /* {filename} */; }};\n"
        build_file_entries += entry

    content = content.replace(
        build_file_section,
        build_file_section + "\n" + build_file_entries.rstrip("\n")
    )
    print("✅ Added PBXBuildFile entries")

    # 2. Add PBXFileReference entries
    file_ref_section = "/* Begin PBXFileReference section */"
    file_ref_entries = ""
    for filename, group in files_to_add:
        entry = f'\t\t{file_refs[filename]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'
        file_ref_entries += entry

    content = content.replace(
        file_ref_section,
        file_ref_section + "\n" + file_ref_entries.rstrip("\n")
    )
    print("✅ Added PBXFileReference entries")

    # 3. Add to appropriate PBXGroup
    for filename, group in files_to_add:
        insert_pos = find_group_children_location(content, group)
        if insert_pos:
            new_entry = f"\n\t\t\t\t{file_refs[filename]} /* {filename} */,"
            content = content[:insert_pos] + new_entry + content[insert_pos:]
            print(f"✅ Added {filename} to {group} group")
        else:
            print(f"⚠️  Could not find {group} group for {filename}")

    # 4. Add to PBXSourcesBuildPhase for main VoiceDay target
    # Find "/* Sources */ = {" followed by "isa = PBXSourcesBuildPhase"
    sources_pattern = r'/\* Sources \*/ = \{[^}]*isa = PBXSourcesBuildPhase;[^}]*files = \('

    match = re.search(sources_pattern, content)
    if match:
        insert_pos = match.end()
        new_entries = ""
        for filename, group in files_to_add:
            new_entries += f"\n\t\t\t\t{build_refs[filename]} /* {filename} in Sources */,"
        content = content[:insert_pos] + new_entries + content[insert_pos:]
        print(f"✅ Added {len(files_to_add)} files to Sources build phase")
    else:
        print("⚠️  Could not find Sources build phase")

    write_project(content)
    print(f"\n✅ Added {len(files_to_add)} new files to Xcode project")

if __name__ == "__main__":
    add_files()
