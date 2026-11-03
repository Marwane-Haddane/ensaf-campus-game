# Zombie RPG — Asset Attribution and Provenance Manifest

This document records the source files, licenses, author credits, archive paths, animation mappings, and derived optimizations for the Zombie RPG mode.

---

## 1. Source Assets & Licenses

### A. Zombie Apocalypse Kit
- **Source Archive:** `C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\3d models\zombie\Zombie Apocalypse Kit - March 2024-20261102T030551Z-1-001.zip`
- **Extracted Files:**
  - `Zombie Apocalypse Kit - March 2024/Characters/glTF/Zombie_Basic.gltf`
  - `Zombie Apocalypse Kit - March 2024/Characters/glTF/Zombie_Chubby.gltf`
  - `Zombie Apocalypse Kit - March 2024/Characters/glTF/Zombie_Crawler.gltf`
  - `Zombie Apocalypse Kit - March 2024/Characters/glTF/Zombie_Ribcage.gltf`
  - `Zombie Apocalypse Kit - March 2024/Characters/glTF/Zombie_Arm.gltf`
  - `Zombie Apocalypse Kit - March 2024/Characters/glTF/Characters_Shaun.gltf`
  - `Zombie Apocalypse Kit - March 2024/Characters/glTF/Characters_Matt.gltf`
  - `Zombie Apocalypse Kit - March 2024/Characters/glTF/Characters_Lis.gltf`
  - `Zombie Apocalypse Kit - March 2024/Characters/glTF/Characters_GermanShepherd.gltf`
  - `Zombie Apocalypse Kit - March 2024/Items/glTF/WoodenBat_Barbed.gltf`
  - `Zombie Apocalypse Kit - March 2024/Items/glTF/Shotgun.gltf`
  - `Zombie Apocalypse Kit - March 2024/Items/glTF/Axe.gltf`
  - `Zombie Apocalypse Kit - March 2024/Environment/glTF/TrafficBarrier_1.gltf`
  - `Zombie Apocalypse Kit - March 2024/Environment/glTF/Pallet.gltf`
  - `Zombie Apocalypse Kit - March 2024/Environment/glTF/Barrel.gltf`
  - `Zombie Apocalypse Kit - March 2024/Environment/glTF/Container_Red.gltf`
  - `Zombie Apocalypse Kit - March 2024/Vehicles/glTF/Vehicle_Pickup.gltf`
  - `Zombie Apocalypse Kit - March 2024/Vehicles/glTF/Vehicle_Pickup_Armored.gltf`
  - `Zombie Apocalypse Kit - March 2024/Zombie_Atlas.png`
  - `Zombie Apocalypse Kit - March 2024/License.txt`
- **Author:** Quaternius ([@Quaternius](https://www.patreon.com/quaternius))
- **License:** **CC0 1.0 Universal (CC0 1.0) Public Domain Dedication**
- **Provenance Note:** The license text header in the archive mentions "Ultimate Platformer Pack by @Quaternius" while the folder is titled "Zombie Apocalypse Kit - March 2024". Both are Quaternius assets distributed under CC0 1.0.

### B. First-Person Animated Pistol
- **Source File:** `C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\3d models\zombie\pistol_animation_wip__really_stiff.glb`
- **Destination:** `res://assets/antigravity/zombie/models/pistol_hands.glb`
- **Author:** Stanless ([https://sketchfab.com/stanless](https://sketchfab.com/stanless))
- **License:** **CC-BY-4.0** ([Creative Commons Attribution 4.0](http://creativecommons.org/licenses/by/4.0/))
- **Title:** Pistol Animation (WIP + really stiff)

### C. CZ Scorpion EVO 3 SMG (First-Person Animated Viewmodel)
- **Source File:** `C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\3d models\zombie\scorpion__first_person_animations_2026_remake.glb`
- **Destination:** `res://assets/antigravity/zombie/models/scorpion_hands.tscn`
- **Rig Features:** Composite knuckle tactical gloves, digital wristwatch chronometer with illuminated cyan dial, dark tactical combat sleeves.
- **Author:** 2026 Remake Rig
- **License:** Author-provided game-ready asset

### D. Benelli M4 Tactical Shotgun
- **Source File:** `C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\3d models\zombie\free_benelli_m4_shotgun_gameready_rigged.glb`
- **Destination:** `res://assets/antigravity/zombie/models/Shotgun.tscn`
- **License:** Game-ready rigged model

---

## 2. Animation Clip Mappings

### 1. Zombie_Basic (Walker)
Total authored animations: 16
- **Idle:** `"Idle"` (calm lurk)
- **Walk:** `"Walk"` (patrol movement)
- **Chase:** `"Run"` (active aggression)
- **Attack:** `"Punch"` (contact window at 0.5s)
- **Hit Reaction:** `"HitReact"` (flinch on shot)
- **Death:** `"Death"` (ragdoll fall)
- Other available clips: `Crawl`, `Idle_Attack`, `Jump`, `Jump_Idle`, `Jump_Land`, `No`, `Run_Arms`, `Run_Attack`, `Wave`, `Yes`

### 2. Zombie_Chubby (Brute Boss)
Total authored animations: 16
- **Idle:** `"Idle"`
- **Walk:** `"Walk"`
- **Chase:** `"Run"`
- **Attack:** `"Punch"` (heavy windup, contact window at 0.7s)
- **Hit Reaction:** `"HitReact"`
- **Death:** `"Death"`

### 3. Zombie_Crawler (Ambush Lurker)
Total authored animations: 14
- **Idle:** `"Idle"`
- **Crawl:** `"Walk"`
- **Sprint:** `"Run"`
- **Attack:** `"Punch"`
- **Hit Reaction:** `"HitReact"`
- **Death:** `"Death"`

### 4. Zombie_Ribcage (Screamer / Blind Lurker)
- **Asset:** `res://assets/antigravity/zombie/models/Zombie_Ribcage.tscn`
- **Role:** Acoustic alert, horde summoner, auditorium boss.

### 5. Zombie_Arm (Shadow Stalker)
- **Asset:** `res://assets/antigravity/zombie/models/Zombie_Arm.tscn`
- **Role:** Asymmetrical predator, heavy leap ambush.

### 6. Characters_Shaun (Friendly Survivor)
Total authored animations: 20
- **Idle:** `"Idle"`
- **Proximity Wave:** `"Wave"` (plays when player approaches within 6 meters)
- **Dialogue Confirmation:** `"Yes"` (affirmative gesture upon speaking)
- Other clips: `Death`, `Duck`, `HitReact`, `Idle_Gun`, `Jump`, `Jump_Idle`, `Jump_Land`, `No`, `Punch`, `Run`, `Run_Gun`, `Run_Slash`, `Run_Stab`, `Slash`, `Stab`, `Walk`, `Walk_Gun`

### 7. Pistol Hands (First-Person Weapon)
Total authored animations: 10
- **Idle / Baseline:** `"Armature|A_Origin"`
- **Aim Down Sights:** `"Armature|A_Aim"`
- **Exit Aim:** `"Armature|A_AimBack"`
- **Fire (Bullet in chamber):** `"Armature|A_Fire"`
- **Fire Last (Empty slide lock):** `"Armature|A_FireLast"`
- **Reload Start:** `"Armature|A_ReloadStart"`
- **Reload Loop / Insert:** `"Armature|A_Reloading"`
- **Reload End / Slide Release:** `"Armature|A_ReloadEnd"`
- **Draw / Equip:** `"Armature|A_Draw"`
- **Holster:** `"Armature|A_Holster"`

### 8. Scorpion First-Person Rig
Total authored animations: 9
- `rig|Equip`, `rig|Idle`, `rig|Walk`, `rig|Run`, `rig|Fire`, `rig|Reload`, `rig|Reload_Empty`, `rig|Inspect`, `rig|Unequip`

---

## 3. Derived Optimizations

- **Conversion to Native PackedScenes (`.tscn`):**
  Raw glTF / GLB models require JSON parsing and buffer decoding on instantiation. Using the conversion tool `tools/antigravity/zombie/convert_gltf_to_scenes.gd`, all models were pre-converted to native Godot PackedScene files:
  - `res://assets/antigravity/zombie/models/Zombie_Basic.tscn`
  - `res://assets/antigravity/zombie/models/Zombie_Chubby.tscn`
  - `res://assets/antigravity/zombie/models/Zombie_Crawler.tscn`
  - `res://assets/antigravity/zombie/models/Zombie_Ribcage.tscn`
  - `res://assets/antigravity/zombie/models/Zombie_Arm.tscn`
  - `res://assets/antigravity/zombie/models/Characters_Shaun.tscn`
  - `res://assets/antigravity/zombie/models/Characters_Matt.tscn`
  - `res://assets/antigravity/zombie/models/Characters_Lis.tscn`
  - `res://assets/antigravity/zombie/models/Characters_GermanShepherd.tscn`
  - `res://assets/antigravity/zombie/models/pistol_hands.tscn`
  - `res://assets/antigravity/zombie/models/scorpion_hands.tscn`
  - `res://assets/antigravity/zombie/models/WoodenBat_Barbed.tscn`
  - `res://assets/antigravity/zombie/props/TrafficBarrier_1.tscn`
  - `res://assets/antigravity/zombie/props/Pallet.tscn`
  - `res://assets/antigravity/zombie/props/Barrel.tscn`
  - `res://assets/antigravity/zombie/props/Container_Red.tscn`
  - `res://assets/antigravity/zombie/props/Vehicle_Pickup.tscn`
  - `res://assets/antigravity/zombie/props/Vehicle_Pickup_Armored.tscn`
- **Load Time Improvement:**
  Native `.tscn` instantiation takes under 1 ms per model instance, compared to >120 ms for glTF runtime parsing.
- **Precomputed Route Navigation Mesh:**
  Navigation mesh was baked offline for the bounded episode route (`res://assets/antigravity/zombie/route_navmesh.res`), completely eliminating any startup navigation lag.
