#!/usr/bin/env python3
"""
Rebuild Camera Database Bundles from Regional Files

This script combines all regional camera database files into the main bundle files:
- Camera_Database_Bundle.json
- Camera_Database_Bundle_Sorted.json
"""

import json
import os
import glob
from pathlib import Path

def rebuild_bundles():
    """Rebuild bundle files from all regional files"""
    
    # Find all regional database files
    regional_files = glob.glob('Camera_Database_*.json')
    
    # Exclude the bundle files themselves
    regional_files = [f for f in regional_files if 'Bundle' not in f]
    
    print(f"📁 Found {len(regional_files)} regional database files")
    
    # Collect all cameras from all regions
    all_cameras = []
    regions_processed = []
    
    for regional_file in sorted(regional_files):
        region_name = Path(regional_file).stem.replace('Camera_Database_', '')
        print(f"   Loading {region_name}...")
        
        try:
            with open(regional_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Extract cameras from the feed
            if 'feeds' in data and len(data['feeds']) > 0:
                feed = data['feeds'][0]
                if 'staticAlerts' in feed:
                    cameras = feed['staticAlerts']
                    all_cameras.extend(cameras)
                    regions_processed.append(region_name)
                    print(f"      ✅ Added {len(cameras)} cameras from {region_name}")
                else:
                    print(f"      ⚠️ No staticAlerts in {region_name}")
            else:
                print(f"      ⚠️ No feeds in {region_name}")
        
        except Exception as e:
            print(f"      ❌ Error loading {region_name}: {e}")
            continue
    
    print(f"\n📊 Total cameras collected: {len(all_cameras)}")
    print(f"📍 Regions processed: {', '.join(regions_processed)}")
    
    # Create bundle structure
    bundle = {
        "feeds": [
            {
                "id": "dukes-r8-camera-database",
                "name": "Dukes R8 Camera Database",
                "description": "Community-sourced camera locations for Dukes R8 app",
                "type": "camera",
                "refreshIntervalMinutes": 1440,
                "staticAlerts": all_cameras
            }
        ]
    }
    
    # Write unsorted bundle
    bundle_path = 'Camera_Database_Bundle.json'
    print(f"\n💾 Writing {bundle_path}...")
    with open(bundle_path, 'w', encoding='utf-8') as f:
        json.dump(bundle, f, indent=2, ensure_ascii=False)
    print(f"   ✅ Saved {len(all_cameras)} cameras to bundle")
    
    # Sort cameras by state, then city, then street
    print(f"\n🔀 Sorting cameras...")
    sorted_cameras = sorted(
        all_cameras,
        key=lambda x: (
            x.get('state', '').upper(),
            x.get('city', '').upper(),
            x.get('street', '').upper()
        )
    )
    
    bundle_sorted = {
        "feeds": [
            {
                "id": "dukes-r8-camera-database",
                "name": "Dukes R8 Camera Database",
                "description": "Community-sourced camera locations for Dukes R8 app (sorted)",
                "type": "camera",
                "refreshIntervalMinutes": 1440,
                "staticAlerts": sorted_cameras
            }
        ]
    }
    
    # Write sorted bundle
    sorted_bundle_path = 'Camera_Database_Bundle_Sorted.json'
    print(f"💾 Writing {sorted_bundle_path}...")
    with open(sorted_bundle_path, 'w', encoding='utf-8') as f:
        json.dump(bundle_sorted, f, indent=2, ensure_ascii=False)
    print(f"   ✅ Saved {len(sorted_cameras)} sorted cameras to bundle")
    
    print("\n✅ Bundle rebuild complete!")
    return len(all_cameras)

if __name__ == '__main__':
    try:
        camera_count = rebuild_bundles()
        print(f"\n🎉 Successfully rebuilt bundles with {camera_count} cameras")
    except Exception as e:
        print(f"\n❌ Error rebuilding bundles: {e}")
        exit(1)

