# MINI WORLD TYCOON

A mobile-first 3D shop-management tycoon prototype built with Godot 4.7.

## Current milestone

**Milestone 7 — checkout and customer-driven sales**
- Added a checkout counter, cash register, cashier character and three queue markers.
- Moved the product shelves inside the MINI MARKET building.
- Customers now trigger a purchase when they reach the entrance; sales no longer happen on an independent timer.
- Each customer purchase deducts one stocked item and credits the sale price to the shared wallet.

**Milestone 6 — store inventory and sales**
- Added three visible product shelves: bread, drinks and snacks.
- Added restocking in batches of five, with purchase costs deducted from cash.
- Customers automatically buy stocked products every five seconds.
- Sales revenue returns to the shared city wallet; sales and profit counters update live.

**Milestone 5 — player and customers**
- Added a controllable third-person character with keyboard and on-screen directional buttons.
- Camera follows the player while keeping the city visible.
- Customers periodically walk toward the MINI MARKET entrance and leave.
- Added a live visitor counter.

**Milestone 4 — land purchase, construction and economy**
- Added four selectable plots in the city.
- Players can buy land, then build a shop, cafe or apartments.
- Buildings generate passive income every 10 seconds; upgrades increase income.
- Added a HUD with cash, plot details and affordability checks.
- Added local save/load for cash, ownership, building type and level.

**Milestone 1 — procedural city environment**
- Replaced the starter floor with a stylized 3D city blockout.
- Added a cross-shaped road network, sidewalks, lane markings and crosswalks.
- Added a player-owned MINI MARKET building with a glass storefront and delivery area.
- Added surrounding commercial and apartment buildings.
- Added a small park, trees and street lamps.
- Set an elevated camera and the Compatibility renderer for mobile-friendly rendering.

The environment is generated from lightweight Godot meshes. It is a visual foundation, not yet a complete playable tycoon game. It has not yet been tested on a device.

## Open on Android

1. In Termux, go to the local repository folder:
   `cd ~/storage/shared/Documents/MINI-WORLD-TYCOON-GIT`
2. Pull the latest project:
   `git pull --ff-only`
3. Open Godot Android Editor.
4. Open the project that points to this folder's `project.godot`.
5. Run the main scene.

## Next milestones

1. Player character and mobile touch controls
2. Interactive shop, shelves and stockable products
3. Customer spawning and navigation
4. Checkout, income and in-game currency
5. Shop upgrades, expansion and local save data
6. Android performance pass and export

Target: Android first, iOS later.
