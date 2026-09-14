# DriveOrRide

A Malaysian commute decision app built for BMIT2073 (Mobile Application Development). DriveOrRide helps users compare driving versus public transport for a given trip — real cost, real duration, and real savings tracking over time.

## Features

- **Route comparison** — real driving routes (OpenStreetMap/OSRM) and real rail journeys (GTFS Rapid Rail KL data), compared side by side
- **Live fuel pricing** — real RON95/RON97 prices fetched from Malaysia's official open data API
- **Live trip tracking** — real GPS-based progress for both driving and public transport
- **Savings goals** — set a goal, track progress automatically as trips are logged
- **Trip history** — full record of past trips, synced across devices for logged-in accounts
- **Road & rail issue reporting** — users can report accidents, breakdowns, or delays; a reviewer role approves reports before they're shown to others

## Tech Stack

- **Flutter** — cross-platform mobile framework
- **SQLite** (`sqflite`) — local on-device storage
- **Supabase** — authentication and remote data sync
- **OpenStreetMap** — Nominatim (geocoding) and OSRM (routing)
- **GTFS** — real Rapid Rail KL transit data

## Getting Started

1. `flutter pub get`
2. Set up a Supabase project and add your URL/anon key in `main.dart`
3. Run the required SQL setup in Supabase (see comments in `supabase_service.dart` and `report_service.dart` for table structures)
4. `flutter run`

## Team

Built by a 3-person team for BMIT2073, Academic Session 202605.