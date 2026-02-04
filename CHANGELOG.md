# Changelog

All notable changes to COOK will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.11.9] - 2026-02-04

### Changed
- new-project output now recommends `/cook:pm-start` (autonomous mode) as primary next step

## [1.11.8] - 2026-02-04

### Added
- Plan-checker validates parallel file isolation (same-wave plans must not modify overlapping files)
- PM merges completed wave branches to base_branch before dispatching next wave
- PM merges all phase branches before advancing to next phase