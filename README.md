# Macesque Taskbar

A macOS-flavored task manager applet for KDE Plasma, based on the upstream
Plasma Task Manager. Minimized (or otherwise eligible) windows are rendered
as live-captured window thumbnails right inside the task bar, dock-style.

![screenshot](screenshots/screenshot.png)

## Features

- **Window thumbnails in the task bar** — minimized tasks render a captured
  snapshot of the window instead of their icon, with the plain icon shrinking
  into a corner.
- **Thumbnail visibility modes** — show thumbnails for minimized windows only,
  all windows, unfocused windows, or windows on other virtual desktops.
- **Icon alignment** — left, centered or right within each task button
  (top/middle/bottom on vertical panels).
- **Optional: hide minimized tasks** — keep the bar free of minimized windows
  entirely; windows demanding attention still appear.
- All the usual task manager behavior: grouping with popup lists, launchers,
  drag & drop, middle-click actions, scroll cycling, audio indicators,
  media/volume controls in tooltips, recent documents, jump lists.

## Requirements

- Plasma 6.6+ / Plasma 6.7 development stack
- Qt 6.10+, KF6 6.26+
- Wayland session for window thumbnails (PipeWire screen casting); on X11 the
  applet falls back to plain icons

## Build

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
```

For a Plasma development environment, point `CMAKE_INSTALL_PREFIX` at your
kde prefix instead.

## Install

```sh
sudo cmake --install build     # system prefix
# or, without sudo for a user prefix:
cmake --install build --prefix ~/.local
```

Then restart the shell and add the widget ("Macesque Taskbar") from the panel
edit mode:

```sh
systemctl restart --user plasma-plasmashell.service
```

## Notes

### Window thumbnail sizing contract

The thumbnail rect is derived deterministically from the `widgets/tasks`
FrameSvg frame margins so that KWin minimize animations can land exactly on
it. [yet-another-magiclamp](https://github.com/user/yet-another-magiclamp)
pairs with this applet out of the box when its `iconMargins()` uses the full
frame margins (`TaskImage.qml` exposes the matching `thumbInsetFactor`).

### Vendored kcms/recentFiles

`applets/taskmanager/kcms/recentFiles/` is vendored from plasma-desktop; it
provides the KConfigXT settings used by the Recent Documents context menu.

### Translations

Translation infrastructure is stubbed (`Messages.sh`); the pot domain is
`plasma_applet_macesque.taskmanager`.

## License

GPL-2.0-or-later, see [LICENSE](LICENSE). Based on KDE's Plasma Task Manager
— copyright by its respective authors (Eike Hein, Kai Uwe Broulik, Nate
Graham and others).
