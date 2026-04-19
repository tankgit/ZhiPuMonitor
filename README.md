<p align="center">
  <img src="Sources/ZhiPuMonitor/Resources/AppIcon.png" width="128" height="128" alt="ZBar Icon" style="border-radius: 24px;">
</p>

<h1 align="center">ZBar</h1>

<p align="center">
  <strong>ZhiPu Coding Plan Usage Monitor for macOS</strong>
</p>

<p align="center">
  <a href="https://github.com/tankgit/ZhiPuMonitor/releases/latest">
    <img src="https://img.shields.io/github/v/release/tankgit/ZhiPuMonitor?style=flat-square&label=Release" alt="Release">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/arch-Apple%20Silicon%20%28M1%2B%29--purple?style=flat-square" alt="Architecture">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-Native-green?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/github/license/tankgit/ZhiPuMonitor?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/PRs-Welcome-brightgreen?style=flat-square" alt="PRs Welcome">
</p>

<p align="center">
  <a href="./README.md">English</a> · <a href="./README_zh.md">中文</a>
</p>

---

## Features

- **Notch Overlay** — Displays usage ring indicators and a pixel-art mascot directly in the MacBook notch area. Hover to see percentages, click to expand the full monitoring panel.

- **Island Mode** — A floating capsule bar below the menu bar, designed to avoid conflicts with other notch-based apps. Toggle via customizable global hotkey (default `Ctrl`+`Option`+`0`).

- **Three Quota Cards** — 5-Hour Quota, Weekly Quota, and MCP Calls, each with progress bars, reset timers, and safety predictions.

- **Usage Safety Prediction** — Calculates whether your current consumption rate will exhaust quotas before their next reset, with SAFE/ALARM badges and estimated time remaining.

- **Pixel Mascot** — An animated pixel-art monster that changes state (happy / nervous / exhausted / sleepy) and color (green / orange / red) based on your usage thresholds.

- **Global Hotkey** — Fully customizable system-wide shortcut via Carbon `RegisterEventHotKey`. Works regardless of which application is in the foreground.

- **Right-Click Context Menu** — Quick access to toggle capsule visibility, open settings, or quit — directly from the island mode view.

- **Bilingual UI** — Full support for Chinese (中文) and English, switchable in Settings.

- **Auto Refresh** — Data refreshes every 5 minutes automatically, with manual refresh on demand.

## Screenshots

### Notch Mode — Hover & Expand

Hover over the notch area to see real-time usage percentages for each quota. Click to expand the full monitoring panel with progress bars, safety badges, and the animated mascot.

<img src="docs/zbar_overall.gif" width="600" alt="Notch Mode Overview">

### Island Mode — Capsule Bar

Enable Island Mode to show a floating capsule bar below the menu bar. It displays ring indicators for 5-hour and weekly quotas, plus the mascot — all without interfering with other notch apps.

<img src="docs/zbar_island_overall.gif" width="600" alt="Island Mode Overview">

### Island Mode — Global Hotkey Toggle

Press the customizable global hotkey (default `Ctrl`+`Option`+`0`) to instantly show or hide the capsule bar, with a smooth slide animation. Works system-wide, no matter which app you're in.

<img src="docs/zbar_island_toggle.gif" width="600" alt="Island Mode Toggle">

### Mascot States

The pixel-art monster reacts to your usage: happy dancing when safe, sweating when approaching limits, and flickering when exhausted. Its color shifts from green → orange → red as usage rises.

<img src="docs/zbar_little_monsters.gif" width="300" alt="Little Monsters">

## Download

> **Apple Silicon (M1/M2/M3/M4) only** — macOS 13 Ventura or later required.

### AI-Assisted Install

Copy the prompt below and paste it to any AI assistant (Claude, ChatGPT, etc.) — it will guide you through the installation:

```
Help me install ZBar, a macOS menu bar app. Read the instructions from this GitHub README and guide me step by step: https://github.com/tankgit/ZhiPuMonitor/blob/main/README.md
```

### Manual Install

Download the latest release from the [Releases](https://github.com/tankgit/ZhiPuMonitor/releases/latest) page, then drag `ZBar.app` to `/Applications`.

## Getting Started

### 1. Get your API Key

You need a ZhiPu (智谱) API Key. If you don't have one, get it from the ZhiPu platform.

### 2. Configure

Click the gear icon in the expanded panel, or right-click the island capsule → **Settings**:

- Paste your API Key and click **Update**
- Adjust **Usage Alert Thresholds** (orange / red)
- Toggle **Island Mode** if you use other notch-based apps
- Customize the **Hotkey** for toggling the capsule

### 3. Usage

| Action | Effect |
|--------|--------|
| Hover notch / capsule | Show usage percentages |
| Click notch / capsule | Expand full monitoring panel |
| Press hotkey | Show / hide island capsule |
| Right-click island view | Context menu (toggle, settings, quit) |

## Tech Stack

- **Language:** Swift 5.9
- **UI Framework:** SwiftUI + AppKit (NSPanel, NSMenu)
- **Hotkey:** Carbon `RegisterEventHotKey` for system-wide shortcut
- **Architecture:** MVVM with `ObservableObject` / `@Published`
- **Build:** Swift Package Manager

## License

This project is licensed under the [MIT License](LICENSE).
