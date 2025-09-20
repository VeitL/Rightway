# Rightway To‑Do List

## Sprint Backlog
- [x] Integrate TÜV/DEKRA official question bank loader and Supabase sync stubs (local fallback)
- [x] Restore learning screen to single-column layout with inline zh-Hans hints
- [x] Add driving practice audio waypoints, persistent media storage, and map annotations
- [ ] Implement Supabase-backed sync pipeline for questions, notes, and progress
- [ ] Flesh out Core Data entities and migrations for offline caching
- [ ] Add localized copy review workflow for zh-Hans/de/en strings
- [ ] Replace placeholder SVG icons with production-ready vector assets
- [ ] Integrate speech-to-text pipeline for practice recordings and surface transcripts on map/audio waypoints

## QA & Testing
- [ ] Expand unit tests to cover SRS scheduling edge cases
- [ ] Add coverage for DrivingSession audio waypoint builder and media persistence helpers
- [ ] Add UI test flows for learning session, exam start, and note creation
- [ ] Configure automated build pipeline (CI) with linting and test execution

## Compliance & Operations
- [ ] Draft App Store privacy nutrition labels based on data collection scope
- [ ] Prepare GDPR data export/delete tooling and documentation
- [ ] Document TÜV/DEKRA license terms and update cadence handling

## Nice-to-Have
- [ ] Prototype Apple Pencil support for iPad note annotations
- [ ] Explore adaptive learning insights (heatmaps, radar charts) on Analytics dashboard
- [ ] Build cross-session “practice map” overview with transcript search & playback filters
