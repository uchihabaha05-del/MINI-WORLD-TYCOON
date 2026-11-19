# MINI WORLD TYCOON

## Current milestone

**Milestone 24 — simple quests, stars and rewards**
- Added five clear goals: buy land, build a first building, upgrade a building, hire a worker and build three buildings.
- Completing each goal grants one star and a coin reward; the next unfinished goal is shown in the HUD.
- Star totals and completed goals are saved locally, so progress survives closing the game.
- Quest checks are connected to the actual land, construction, upgrade and hiring actions.

**Milestone 23 — child-friendly onboarding and simpler game language**
- Added a short first-business guide directly to the main HUD: choose green land, buy it, build a shop, then collect the first income.
- The guide advances automatically as the player completes each action and celebrates the first successful payout.
- Tutorial progress is saved locally, so returning players do not need to repeat the introduction.
- Reworded key prompts with simple, friendly language such as “монетки”, “земля” and “заработок”; clarified that the shop is the easiest first building.
- Kept the deeper management systems available for players who want to explore them after learning the basics.


A mobile-first 3D shop-management tycoon prototype built with Godot 4.7.

## Current milestone

**Milestone 22 — rival businesses and district competition**
- Added four independent rival storefronts across the expanded city: CITY MART, URBAN CAFE, NORTH FOOD and QUICK FIX.
- Customers now choose between player-owned businesses and rival destinations using appeal-weighted demand; visits to rivals do not credit the player's wallet.
- Rival visitor totals and each competitor's visit count are tracked and saved in `user://rival_market.cfg`.
- Added a business-district rating that responds to the player's number of commercial businesses, their average appeal and the strength of rival competitors.
- Corrected customer service routing so each customer is served once after reaching the selected destination, and the correct owned plot's appeal affects its revenue.

**Milestone 21 — municipal finance, taxes and city budget**
- Added a configurable business tax rate from 0% to 20%, adjustable in 2-point steps.
- Municipal tax revenue is calculated from the current passive income of owned businesses and credited to the shared city wallet every 30 seconds.
- City operating expenses scale with population and the number of constructed buildings.
- The finance HUD reports the tax rate, latest tax collection, city expenses, cumulative tax revenue and cumulative spending.
- Tax settings and financial history persist in `user://municipal_finance.cfg`; wallet changes use the existing tycoon save system.

**Milestone 20 — major city expansion**
- Expanded the playable ground and road grid to a 220 × 220 city footprint with two outer ring-road axes and four new outer districts.
- Expanded land development from four to twelve buildable plots while retaining the original four plot positions and saved ownership/building data.
- Added new district buildings, landscaped green squares, sidewalks and street lighting to make the outer city readable.
- Increased the player exploration bounds so the expanded map can be traversed.
- Increased road traffic to ten vehicles and extended vehicle travel routes into the outer districts.
- Expanded parking from eight to sixteen bays, with up to twelve occupied at once.
- Utility connection controls now generate for all twelve plots, and the HUD reports the actual city-wide connection count.
- Existing businesses, workers, appeal, population, saves and city economy remain part of the same project.

**Milestone 19 — business appeal and city demand**
- Each commercial plot has an appeal score from 0 to 100, saved independently.
- Marketing raises appeal by 10 points for a fee of 120 coins plus 20 coins per building level.
- Customer destination selection is weighted: businesses with higher appeal receive a larger share of visits.
- Service revenue at commercial businesses is adjusted by both appeal and city happiness.
- City happiness is exposed to the demand system; apartment buildings remain residential.
**Milestone 18 — customers visit city businesses**
- Customer destinations are selected from the MINI MARKET and owned commercial plots.
- Customers travel to built shops, cafes, restaurants and workshops; apartment buildings are residential and are not treated as commercial destinations.
- Visits to MINI MARKET continue to trigger stock-based retail sales.
- Other commercial visits credit a small service/transaction amount to the shared city wallet (cafe 16, restaurant 28, workshop 24, shop 18 coins).
- Added live visitor counters by business type while retaining the six-customer active limit.

**Milestone 17 — workforce for owned businesses**
- Each owned commercial plot can hire its own workers for 250 coins per hire.
- Each worker costs 8 coins in payroll per 10-second income cycle and adds 12 coins to that business's cycle income when the total payroll is affordable.
- Worker capacity is two per building level; upgrading a building increases its staff capacity.
- Staff counts are saved per plot and restored with the city save.
- Apartments do not hire commercial workers; the existing MINI MARKET employee system remains separate.

**Milestone 16 — expanded city businesses**
- Added two new construction options: restaurant (1,100 coins, 125 income per cycle) and workshop (800 coins, 105 income per cycle).
- Both businesses use the existing plot purchase, upgrade, save/load and passive-income systems.
- Added a portfolio summary showing the number of operating enterprises and combined income per 10-second cycle.
- Existing shop, cafe and apartment construction remains available.

**Milestone 15 — electricity and water utilities**
- Added per-plot utility connections for electricity and water.
- Connecting an owned plot costs 120 coins.
- Connected buildings add recurring electricity and water operating costs.
- Utility charges are deducted from the shared wallet every 20 seconds when there are connected buildings.
- Utility connection choices persist locally in `user://city_utilities.cfg`.

**Milestone 14 — parking lots and occupancy**
- Added eight marked parking bays alongside the outer streets.
- Simulates cars arriving and leaving, with a maximum of six occupied spaces at a time.
- Parked vehicles are generated with simple low-cost meshes.
- Added live occupancy, arrival and departure counters.

**Milestone 13 — public transport**
- Added a four-stop city bus route and a procedural city bus.
- Passenger queues fluctuate at stops; the bus boards up to three passengers per stop.
- Each passenger pays a four-coin fare, credited to the shared city wallet.
- Added a transport HUD for waiting passengers, total passengers carried and fare income.

**Milestone 12 — city road traffic**
- Added six lightweight procedural cars with bodywork, cabin, wheels and headlights.
- Cars travel along the existing secondary east-west and north-south roads.
- Added a traffic HUD counter.
- Traffic is visual-only and does not add physics bodies, keeping the system lightweight for mobile.

**Milestone 9 — visitor population and crowd control**
- The city now tracks customers currently walking through the scene separately from the lifetime visitor total.
- A maximum of six active customers prevents unbounded scene growth on mobile.
- New visitors pause spawning while the city is at capacity; the counter refreshes when customers leave.
- Customers continue to walk to the MINI MARKET, trigger a stock-based sale, and then leave.

**Milestone 8 — employee hiring and automatic restocking**
- Added a staff hire action costing 350 coins.
- A hired employee is paid 15 coins every 10 seconds; if the business cannot cover payroll, the salary is not deducted.
- The employee checks shelves every 12 seconds and buys one unit of any product whose stock is below two, if funds allow.
- Inventory and employee status are saved locally and restored when the game starts.
- Manual restocking remains available in batches of five.

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
