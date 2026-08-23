# DriveOrRide — Starter Codebase (v2 — matches your syllabus)

Rebuilt to match your actual practical notes: **SQLite** (Practical 9) for
local storage, **Supabase** (Practical 11) for remote storage, **OpenStreetMap**
(Practical 12) for maps, and the `location`/`permission_handler` packages
(Practical 13) for GPS — not generic alternatives.

## ⏰ Your real timeline (be honest with yourself about this)

Today: Week 10 Sunday. Week 11 Wed/Thu is eaten by DSA + Advanced Database.
Submission: end of Week 12. That's roughly 8-9 real working days.

**Priority order — do NOT try to build everything. Build in this order and
stop when you run out of time:**

1. **Must have (rubric-critical):** Home → Compare (real data) → SQLite CRUD
   for all 3 modules (Saved Locations ✅ done, Goals, Trip History) → Supabase
   sync for trip_logs (satisfies "local AND remote" for top marks)
2. **Should have:** Route Details (map + schedule), Trip Summary, History
   dashboard
3. **Nice to have, cut first if short on time:** Trip In Progress live GPS,
   biometric lock, notifications, share feature, toll/fare precise calculation

## ✅ What's real and working right now

- `DatabaseService` — real SQLite, exact pattern from Practical 9
- `SupabaseService` — real remote CRUD, exact pattern from Practical 11
- `SavedLocationsScreen` — **complete working CRUD** — copy this exact
  structure for Savings Goals and Trip History screens
- `RoutingService` — real Nominatim + OSRM (any address, not hardcoded)
- `FuelPriceService` — real data.gov.my call (verify field names once run)
- `GtfsService` — parses your real verified stops.txt/stop_times.txt
- `LocationTrackingService` — real GPS, matches Practical 13 exactly

## ⚠️ Required setup steps (do these first, before writing more code)

1. `flutter pub get`
2. Extract your `gtfs_rapid_rail_kl.zip` → copy the 5 .txt files into
   `assets/gtfs/`
3. Create a free Supabase project (supabase.com) → create a `trip_logs`
   table (see comments in `supabase_service.dart` for exact columns) →
   paste your URL + anon key into `main.dart`
4. Run `flutter analyze` to catch typos before testing on a device —
   I cannot compile/run Flutter in my environment to verify this for you.

## 🔨 Still needs to be built

- Savings Goals CRUD screen (copy SavedLocationsScreen's pattern)
- Trip History CRUD screen (copy SavedLocationsScreen's pattern) + Supabase
  sync call after each insert
- Route Details screen (flutter_map + shapes.txt polyline + vertical
  schedule list)
- Trip In Progress screens (Drive: LocationTrackingService live dot;
  Transit: schedule-based highlight)
- Trip Summary, History/Impact dashboard (fl_chart), Profile,
  About/Terms/Privacy static pages
- Toll formula (rate × distance), transit fare (from Prasarana calculator),
  interchange-station lookup table

## Splitting work across your 3 team members, given limited time

Given the deadline, assign ONE full vertical slice per person rather than
splitting by layer — each person can work independently without blocking:

- **Person A:** Savings Goals screen (SQLite CRUD, copy the template)
- **Person B:** Trip History screen (SQLite CRUD + Supabase sync, copy the
  template + supabase_service.dart)
- **Person C:** Route Details + Trip In Progress screens (map, GTFS,
  location tracking — the most complex piece, needs the most experienced
  coder)

Commit and push regularly, individually, under each person's own GitHub
account — this is required for your "active contributions from all
members" grading requirement.

## Keep building with Claude

Ask for the next piece specifically and I'll write it — e.g. "write the
Savings Goals CRUD screen" or "write the Route Details screen with the map".
Building one real, tested piece at a time is safer than everything at once,
especially with your timeline.
