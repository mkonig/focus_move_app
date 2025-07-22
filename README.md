# focus_move_app

**focus_move_app** is a script to enable an app focused workflow.

## Requirements

- [i3wm](https://i3wm.org)
- [jq](https://github.com/jqlang/jq)
- [toml-cli](https://github.com/gnprice/toml-cli)

## App focused workflow

In the past I used a workspace based workflow where each app was 'bound' to a
certain workspace.
For example, nvim would reside on workspace 1, tmux on workspace 2 and the browser on workspace 3.
I would then have shortcuts to switch to each app.

## The problem

The problem with this arose when I wanted to have 2 apps side by side.

For example: Coding in nvim while seeing live output in tmux.

Moving nvim to the tmux workspace mixed up the workspace assignment.
Using shortcuts to go to another app and back to nvim did not work
because nvim was no longer on its 'bound' workspace.
I moved it to the tmux workspace and I would first have to move nvim back to its 'bound' workspace
to make the shortcut's work.

## The solution

Instead of a shortcut to got to workspace xy, have a shortcut to go to an app no
matter its location.

In comes **focus_move_app**. It has 3 actions.

- **focus**
  - Focus an app if it is already running.
  - If the app is not started it will start it on a new workspace.
- **move**
  - Move an app to the current workspace.
  - Start it if it is not running yet.
- **only**
  - Make the currently focused app the only one on the workspace.
  - Only works if app is already running.

## Example setup

Using [sxhkd](https://github.com/baskerville/sxhkd) as hotkey daemon.

```config
mod4 + o
    focus_move_app "" "only"

mod4 + {_, control + } {n,t,z,c,f}
    mode={"focus","move"}; \
    app={"nvim","tmux","zen-browser","chrome","firefox"}; \
    focus_move_app "$app" "$mode"
```

This would make mod4+n focus nvim. Mod4+ctrl+n move nvim to the current
workspace.
So you are working in tmux (mod4+t) and want to have nvim beside it,
mod4+ctrl+n and nvim is moved to your current workspace.
Want to continue working in tmux full-screen.
Focus tmux and mod4+o will move nvim away again.

## Configuration

See [focus_move_app.toml](focus_move_app.toml).

```toml
[nvim]
class = "terminal.nvim"
cmd = "xterm -class ${app_class} -e nvim"

[tmux]
class = "terminal.tmux"
cmd = "xterm -class ${app_class} -e tmux"
```
