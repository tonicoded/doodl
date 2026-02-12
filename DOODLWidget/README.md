# doodl. widget

this widget shows the latest doodl (image + “from <username>”) using shared app-group storage.

## xcode steps (one-time)

1. **create a widget extension target**
   - xcode → file → new → target → **widget extension**
   - name it e.g. `DOODLWidget`
   - remove the template files if you want, then add the files from `DOODLWidget/` to the widget target.

2. **enable app groups**
   - in **both** targets (app + widget extension):
     - signing & capabilities → **+ capability** → **app groups**
     - add: `group.com.anthonyverruijt.doodl`
   - make sure the identifier matches `DOODL./AppGroup.swift`.

3. **share the storage helpers with the widget**
   - add these files to the widget target membership:
     - `DOODL./AppGroup.swift`
     - `DOODL./SharedWidgetStore.swift`

4. **enable background refresh for pushes**
   - app target → signing & capabilities → **background modes**
   - enable **remote notifications**

## how it updates

- when a push arrives, the app’s `AppDelegate` fetches the latest doodl, stores it in the app-group, and calls `WidgetCenter.shared.reloadAllTimelines()`.
- the widget reads `SharedWidgetStore.loadLatestDoodle()` to render.

