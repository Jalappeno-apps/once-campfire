# Sidebar on mobile

This document explains how the sidebar behaves on small viewports and how it interacts with the top navigation, so layout changes stay intentional.

## Layout model

- The app shell is a **CSS grid** (`layout.css`): the main column holds `#nav` and `#main-content`; the sidebar sits in the **`sidebar` grid area** on the right on wide screens.
- Below **`100ch`**, `--sidebar-width` is `0` for the grid, so the main column uses the full width. The sidebar is **not** a grid column anymore; it becomes a **fixed overlay** (`#sidebar` with `position: fixed` and `inset: 0`).

## Open and close

- **`.sidebar-shell`** wraps the drawer and hosts a **`sidebar-drawer`** Stimulus controller. Toggling adds/removes the class **`open`** on **`#sidebar`**, which slides the drawer on-screen (`transform: translate(0)`). When closed, the drawer is translated off the **inline end** (off the right edge in LTR).
- **`button.sidebar__toggle-fab`** lives **outside** `#sidebar` (still inside `.sidebar-shell`) so it is **not** moved off-screen with the drawer’s transform. That is the primary **open** control on small viewports when the drawer is closed.
- When **`#sidebar.open`**, the FAB is **hidden** so only **`button.sidebar__toggle`** in the workspace header shows (no double hamburger). When closed, **`sidebar__toggle-fab`** is **fixed** to the **trailing corner** (with `env(safe-area-inset-right)`), and **`#nav`** reserves **`padding-inline-end`** for that control column so room actions (⋯, bell) do not sit underneath it.
- **`button.sidebar__toggle`** in the workspace header toggles the drawer whenever that header is visible. When the drawer is closed, the **inset-end** padding on `#nav` keeps main-column titles clear of the **fixed** menu affordance on the right edge of the screen.

## Why the nav reserves space on the right

When the drawer is closed, that menu control still occupies the **top-right** visual area. The room title and other nav content live in `#nav`, which is full width on mobile. Without extra **inline-end padding**, the title can run under the menu button.

`nav.css` adds `padding-inline-end` on `.sidebar #nav` for `max-width: 100ch` so text and chips clear the button and **safe-area** (`env(safe-area-inset-right)`) on notched devices.

## Full-bleed drawer

- `turbo-frame#user_sidebar` uses `display: contents` (`base.css`), so flex layout on `#sidebar` applies to **`.sidebar__container`** and **`.sidebar__tools`** directly.
- On mobile, **`.sidebar__container`** is **`inline-size: 100%`**, so the dark rail fills the overlay instead of a narrow strip.
- **Safe-area (top):** use **`env(safe-area-inset-top)`** only on **`.sidebar__workspace-header`** (folded into `padding-block-start`). Do **not** also pad **`.sidebar__container`** on top, or the open drawer shows **double** top spacing above the workspace row.
- **`.sidebar__tools`** (profile + settings) is **fixed to the bottom** of the viewport; on small screens its width is **100%** of the overlay, with safe-area padding on the bottom.

## Collapsible sections

- Section bodies (Channels, Direct messages, Chat bots) use **`sidebar-sections`** Stimulus. Collapse state is stored in **`localStorage`** under keys like `sidebar-section:channels`, `sidebar-section:direct_messages`, and `sidebar-section:bots`.
- If a section looks “missing”, check whether it was **collapsed** in that browser; expanding the section header restores the list.

## Native app (React Native WebView)

- The shell uses **`SafeAreaView`** with **`edges={["bottom"]}`** around the main **WebView** so the home indicator is inset, while the web page owns **top** safe area via **`env(safe-area-inset-top)`** on **`#nav`**, **`.sidebar__toggle-fab`**, and **`.sidebar__workspace-header`** (small viewports). Previously **`edges={["top"]}`** on `SafeAreaView` **and** `env(safe-area-inset-top)` in CSS applied the same top inset twice, which looked like extra padding above the open sidebar.
- **`--navbar-height`** on **`body`** under **`100ch`** includes **`env(safe-area-inset-top)`** (not only when **`body.sidebar`**), so panels (e.g. room edit) and **`#nav`** stay aligned on notched native WebViews.

## Related files

| Concern | File |
|--------|------|
| Shell around drawer + FAB, Stimulus hook | `app/views/layouts/application.html.erb` |
| Drawer open/close | `app/javascript/controllers/sidebar_drawer_controller.js` |
| Grid, `#sidebar` overlay, desktop width | `app/assets/stylesheets/layout.css` |
| Nav padding, menu overlap | `app/assets/stylesheets/nav.css` |
| Sidebar chrome, rows, tools | `app/assets/stylesheets/sidebar.css` |
| Sidebar markup | `app/views/users/sidebars/show.html.erb` |
| Section toggle / persistence | `app/javascript/controllers/sidebar_sections_controller.js` |
