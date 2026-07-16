---
name: device-control-ha
description: |
  Home Assistant device control via MCP. Teaches the agent how to discover and
  control smart home devices exposed through Home Assistant's MCP Server
  integration. Covers entity naming, state queries, command execution, and
  safety rules for irreversible actions. Use when the user asks to control
  lights, switches, climate, locks, covers, or other HA-exposed devices.
---

# Home Assistant Device Control

## Overview

Home Assistant exposes its Assist API as MCP tools via the official `mcp_server`
integration at `/api/mcp`. This skill teaches you how to use those tools
effectively and safely.

## Important Constraints

1. **Tools Only** — HA MCP supports **only the Tools capability**. Do NOT
   attempt to use Resources, Prompts, Sampling, or Notifications.
2. **Exposed Entities Only** — You can only interact with entities the user has
   explicitly exposed via Settings > Voice Assistants > Expose. If a device is
   not found, inform the user it may not be exposed.
3. **Irreversible Actions Require Confirmation** — Before executing any of the
   following, you MUST call `render_ui` with a `ConfirmDialog` component and
   wait for explicit user approval:
   - Locking / unlocking doors
   - Disarming security systems
   - Opening / closing garage doors or covers
   - Turning off HVAC in extreme weather
   - Any action the user has flagged as high-impact

## Discovery

When the user asks about their devices, first call the HA MCP tools to list
available entities. Present results using `render_ui` with `DeviceTile`
components in a `ListView`.

## Controlling Devices

### Lights
- Turn on/off: Use the appropriate Assist tool
- Adjust brightness: Include brightness percentage in the command
- Set color: Include color name or RGB values

### Switches & Plugs
- Simple on/off toggle
- Present state with `DeviceTile(type: "switch", controllable: true)`

### Climate (Thermostat / AC)
- Set target temperature
- Change HVAC mode (heat, cool, auto, off)
- ⚠️ Turning off climate in extreme temperatures requires HITL confirmation

### Locks
- ⚠️ ALL lock/unlock actions require HITL confirmation
- Present with `ConfirmDialog` before executing

### Covers (Blinds, Garage Doors)
- Open/close/set position
- ⚠️ Garage door actions require HITL confirmation

## State Reporting

When reporting device states, use `render_ui` with appropriate components:
- Single device → `DeviceTile`
- Multiple devices → `ListView` of `DeviceTile` components
- Device with metrics → `DeviceTile` + `MetricChart`

## Error Handling

- If a device is not found, respond with an `InfoCard` suggesting the user
  check their HA Expose settings.
- If an action fails, show an `InfoCard` with the error details and suggest
  troubleshooting steps.
- Never retry failed irreversible actions automatically.

## Example Interaction

User: "Turn on the living room lights"

1. Call HA MCP tool to execute the action
2. Call `render_ui` with:
   ```json
   {
     "surfaceId": "main",
     "root": {
       "component": "DeviceTile",
       "props": {
         "name": "Living Room Lights",
         "state": true,
         "type": "light",
         "controllable": true
       },
       "events": {
         "onToggle": "device.toggle.light.living_room"
       }
     }
   }
   ```
