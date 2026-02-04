# Changelog

All notable changes to COOK will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.11.11] - 2026-02-04

### Changed
- VK connection is now unconditional during new-project (always assumes VK is available)

## [1.11.10] - 2026-02-04

### Added
- new-project asks autonomous vs manual PM mode upfront
- Auto-connects to Vibe Kanban during new-project (autonomous mode)
- Auto-launches `/cook:pm-start` after project init (autonomous mode)
- PM config section included in config.json from the start

### Changed
- Renamed "plans" to "tickets" in user-facing depth/execution questions
- config.json template now includes pm section with VK defaults

## [1.11.9] - 2026-02-04

### Changed
- new-project output now recommends `/cook:pm-start` (autonomous mode) as primary next step

## [1.11.8] - 2026-02-04

### Added
- Plan-checker validates parallel file isolation (same-wave plans must not modify overlapping files)
- PM merges completed wave branches to base_branch before dispatching next wave
- PM merges all phase branches before advancing to next phase