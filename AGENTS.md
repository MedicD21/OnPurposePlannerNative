# OnPurpose Planner Native — Agent Context

This document exists so future AI agents (and developers) have full context on what
this project is, why it was built the way it was, and how everything fits together.

---

## Why This Exists

This project is a **ground-up native iOS rewrite** of a web-based digital planner that
previously ran as a React + TypeScript app wrapped in Capacitor (WKWebView).

The web version had a fundamental, unfixable problem: WKWebView does not provide
OS-level palm rejection for Apple Pencil. Every attempt to fix it in JavaScript —
time-based heuristics, pressure checks, swipe cancellation timers — was a band-aid
on a platform limitation. The root cause was that WKWebView fires `pointerType: "touch"`
for palm contacts even while Apple Pencil is active, and there is no reliable way to
distinguish palm from finger in the browser layer.

**The single most important line in this entire codebase:**
```swift
canvas.drawingPolicy = .pencilOnly   // DrawingCanvasView.swift
```
This tells PencilKit to accept input only from Apple Pencil. Fingers are ignored for
drawing and used exclusively for pan/zoom. Palm rejection becomes an OS concern, not
a JavaScript concern.

---

## Project Structure

```
OnPurposePlannerNative/
├── project.yml                          xcodegen spec — run `xcodegen generate` to rebuild .xcodeproj
├── OnPurposePlannerNative.xcodeproj     Xcode project (generated, do not hand-edit)
└── OnPurposePlannerNative/
    ├── OnPurposePlannerNativeApp.swift  @main entry point
    ├── PlannerTheme.swift               Colours, paper sizes, default palette
    ├── CalendarData.swift               Calendar math (Sunday-first, 6-week grid)
    ├── PlannerStore.swift               ObservableObject: state + persistence + PKToolPicker
    ├── DrawingCanvasView.swift          UIViewRepresentable wrapping PKCanvasView
    ├── ZoomableView.swift               UIScrollView pinch-zoom / pan container
    ├── MonthPaperView.swift             Left paper: full month calendar grid
    ├── WeekPaperView.swift              Right paper: week view with ruled lines
    ├── PlanningSpreadView.swift         Planning spread (intentions + dot grid)
    ├── NotesSpreadView.swift            Notes spread (ruled + dot grid)
    ├── PlannerSpreadContainerView.swift Spread switcher + 2-finger swipe nav
    ├── MonthTabsView.swift              Vertical 12-month tab strip
    ├── FloatingToolbarView.swift        Minimal nav overlay (spread + month/week arrows)
    └── ContentView.swift               Root ZStack composing all layers
```

---

## Architecture

### State (`PlannerStore`)

Single `ObservableObject` injected at the root via `.environmentObject`. Owns:
- `currentYear`, `currentMonth`, `currentWeekIndex` — navigation position
- `activeSpread: SpreadType` — which of the three spreads is showing
- `toolPicker: PKToolPicker` — **one shared instance** for the entire app

All navigation (`goToNextWeek`, `goToPreviousMonth`, etc.) lives here.

### Three Spreads

| Spread | Left paper | Right paper |
|---|---|---|
| `.monthWeek` | Full month calendar grid | Selected week with ruled lines |
| `.planning`  | Weekly intentions (7 rows) | Dot-grid to-do |
| `.notes`     | 24-line ruled notes | Dot-grid ideas |

Each paper has a `DrawingCanvasView` overlaid as a transparent `ZStack` layer.

### Drawing (`DrawingCanvasView` + `PKToolPicker`)

`DrawingCanvasView` is a `UIViewRepresentable` wrapping `PKCanvasView`. Key setup:
```swift
canvas.drawingPolicy   = .pencilOnly  // palm rejection
canvas.isScrollEnabled = false        // ZoomableView owns scroll
canvas.backgroundColor = .clear       // transparent over paper layout

store.toolPicker.setVisible(true, forFirstResponder: canvas)
store.toolPicker.addObserver(canvas)
canvas.becomeFirstResponder()
```

`PKToolPicker` is Apple's native floating tool palette. It provides everything:
- All 7 ink types (pen, pencil, marker, monoline, fountain pen, watercolor, crayon)
- Eraser with pixel and object modes
- Lasso tool (select, move, resize, delete, copy strokes)
- Ruler
- Full colour picker with opacity
- Per-tool stroke width
- Tool favourites
- Built-in undo/redo wired to the canvas responder chain

Because `PKToolPicker` talks directly to `PKCanvasView`, there is **no custom tool
state in `PlannerStore`**. The store does not track the active tool, colour, or stroke
width — the picker handles all of that internally.

### Persistence

Each page has a stable string ID (e.g. `"y2025-month-3-week-1"`). `PKDrawing` is
serialised via `drawing.dataRepresentation()` and written to:
```
Documents/drawings/{pageId}.drawing
```
An in-memory `[String: PKDrawing]` cache avoids redundant disk reads within a session.

### Zoom / Pan (`ZoomableView`)

`ZoomableView` is a `UIViewRepresentable` wrapping `UIScrollView`. It:
- Hosts the SwiftUI spread content via `UIHostingController`
- Enables pinch-zoom (`minimumZoomScale`, `maximumZoomScale`)
- Centres the content when smaller than the viewport
- Exposes `@Binding var zoomScale` back to SwiftUI

Two-finger swipe navigation (separate from zoom) is handled by
`TwoFingerSwipeGestureRecognizer` — a custom `UIGestureRecognizer` subclass in
`PlannerSpreadContainerView.swift`. It requires exactly 2 touches and fires on
horizontal (→ week) or vertical (→ month) movement above 50 pt.

### Navigation Overlay (`FloatingToolbarView`)

Intentionally minimal. The `PKToolPicker` covers all drawing controls so this view
only needs to expose:
- Spread selector (Cal / Plan / Notes)
- Month prev/next
- Week prev/next (only on `.monthWeek` spread)

It is draggable via `DragGesture` and positioned to the left of the month tab strip.

---

## Page ID Scheme

```
Month grid (left paper):    y{year}-month-{month}-left
Week paper (right paper):   y{year}-month-{month}-week-{weekIndex}
Planning left:              y{year}-month-{month}-planning-left
Planning right:             y{year}-month-{month}-planning-right
Notes left:                 y{year}-month-{month}-notes-left
Notes right:                y{year}-month-{month}-notes-right
```

Week index is 0-based. A month always has 5–6 weeks in the calendar grid.

---

## Calendar (`CalendarData.swift`)

Sunday-first, always 6 weeks (42 cells). Days before the 1st of the month and after
the last day are filled from adjacent months with `isInMonth = false`.

Key functions:
- `generateCalendar(year:month:) -> CalendarMonth`
- `shiftMonth(year:month:by:) -> (year, month)` — handles year wrapping
- `formatWeekRange(_ week:) -> String` — e.g. `"Mar 3 – Mar 9"`
- `weekIndex(for date:in calendarMonth:) -> Int` — finds which week contains a date

---

## Theme (`PlannerTheme.swift`)

All colours match the original web app:

| Token | Hex | Use |
|---|---|---|
| `paper` | `#fbfaf7` | Page background |
| `ink` | `#2d2928` | Text, icons |
| `line` | `#9f9a94` | Ruled lines |
| `hairline` | `#d2cdc5` | Calendar grid lines |
| `dot` | `#cfc8bf` | Dot grid |
| `cover` | `#412f33` | Active tab, selected state |
| `accent` | `#b7828e` | Today highlight |
| `tab` | `#f3eee8` | Tab strip background |

Default 8-colour drawing palette:
`#2f2b2a` `#1f3a64` `#0f6f67` `#0f8f43` `#a05f13` `#8d2525` `#7f3c9a` `#5f5f63`

Spread dimensions: **1600 × 1200 pt**. Left paper takes `1.55 / 2.55` of the width.

---

## Build & Regen

```bash
# Regenerate Xcode project after editing project.yml
cd /Users/dustinschaaf/Code/OnPurposePlannerNative
xcodegen generate

# Verify it compiles (no device needed)
xcodebuild \
  -project OnPurposePlannerNative.xcodeproj \
  -scheme OnPurposePlannerNative \
  -destination 'generic/platform=iOS' \
  build CODE_SIGNING_ALLOWED=NO
```

Requirements: Xcode 16+, iOS 17 deployment target, no third-party dependencies.

---

## What Is NOT Yet Implemented

The following features existed in the web version and have not been ported:

- **Sticky notes** — draggable, collapsible floating notes on any page
- **Lasso cut/copy/paste** — lasso is available via PKToolPicker but the UI for
  acting on a selection (cut, duplicate, colour-change) is not custom-built
- **Bucket fill** — flood-fill regions with colour
- **Image stamps** — place images onto pages
- **Symbol stamps** — checkmarks, stars, arrows, etc.
- **Favourite styles** — saved pen/colour/width combos as quick-access slots
- **iCloud / cross-device sync** — drawings are local-only (Documents directory)
- **Export** — PDF or image export of pages
- **Dark mode** — all colours are hardcoded to the light paper theme

---

## Key Decisions Log

| Decision | Rationale |
|---|---|
| Native SwiftUI over continued WKWebView work | WKWebView palm rejection is unfixable in JS; `drawingPolicy = .pencilOnly` solves it at the OS level |
| `PKToolPicker` instead of custom toolbar | Provides all 7 ink types, lasso, eraser modes, ruler, colour picker, undo/redo for free — no custom tool state needed |
| File-based persistence (`Documents/drawings/`) | Simple, reliable, no Core Data schema migrations; each page is an independent file |
| Single `PKToolPicker` instance in `PlannerStore` | One picker follows the first-responder canvas; multiple instances would show multiple pickers |
| `UIScrollView` for zoom (not `MagnificationGesture`) | `MagnificationGesture` in SwiftUI doesn't give the bounce/deceleration physics of `UIScrollView`; also allows `PKCanvasView` to correctly receive pointer events at the zoomed scale |
| xcodegen for project file | Keeps the `.xcodeproj` regeneratable from a readable `project.yml`; avoids merge conflicts in the binary project file |
