#!/usr/bin/env python3
"""
my-new-app Live OTA Demonstration Web Backend
Handles status reporting, persistent state initialization, and runtime health checks.
"""

import http.server
import json
import os
import socketserver
import subprocess
import sys
import threading
import time

STATE_FILE = "/var/lib/my-new-app/state.json"
CONFIG_FILE = "/etc/my-new-app/my-new-app.conf"
DEMO_FILE = "/tmp/demo.txt"


def file_watchdog():
    """
    Periodically checks if /tmp/demo.txt exists.
    Exits with code 1 immediately if deleted, forcing systemd to intervene.
    """
    while True:
        if not os.path.exists(DEMO_FILE):
            print("CRITICAL: /tmp/demo.txt was deleted! Terminating service immediately...", flush=True)
            sys.exit(1)  # Triggers systemd failure restart
        time.sleep(2)


def load_config():
    config = {"PORT": "9000", "VERSION": "1.0"}
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, v = line.split("=", 1)
                        config[k.strip()] = v.strip().strip('"').strip("'")
        except Exception:
            pass
    return config


def get_boot_slot():
    """
    Detects Jetson Orin boot slot via nvbootctrl, with cmdline fallback.
    """
    # 1. Primary: Use NVIDIA nvbootctrl tool
    try:
        out = subprocess.check_output(["nvbootctrl", "dump-slots-info"], text=True, stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            if "Current bootloader slot:" in line:
                slot = line.split(":")[-1].strip()
                if slot in ["A", "B"]:
                    return slot
    except Exception:
        pass

    # 2. Fallback: Check /proc/cmdline
    try:
        with open("/proc/cmdline", "r") as f:
            cmd = f.read()
            if "slot_suffix=_b" in cmd or "slot=B" in cmd:
                return "B"
            elif "slot_suffix=_a" in cmd or "slot=A" in cmd:
                return "A"
    except Exception:
        pass

    return "UNKNOWN"

def get_os_version():
    try:
        with open("/etc/os-release", "r") as f:
            lines = f.readlines()
            # 1. Look for VERSION_ID="2.0"
            for line in lines:
                if line.startswith("VERSION_ID="):
                    return line.split("=", 1)[1].strip().strip('"')
            # 2. Fallback: Look for VERSION="2.0"
            for line in lines:
                if line.startswith("VERSION="):
                    return line.split("=", 1)[1].strip().strip('"')
    except Exception:
        pass
    return "1.0"


def get_app_version():
    app_ver_file = "/usr/lib/my-new-app/version"
    if os.path.exists(app_ver_file):
        try:
            with open(app_ver_file, "r") as f:
                return f.read().strip()
        except Exception:
            pass
    return "1.0"


def init_persistent_state():
    """
    Calculates updates and increments boot counter ONLY at service startup.
    API GET calls will strictly perform READ-ONLY operations on this state.
    """
    os.makedirs("/var/lib/my-new-app", exist_ok=True)

    state = {
        "device_id": "my-new-app-001",
        "deployment": "FACTORY-07",
        "boot_counter": 1,
        "last_event_title": "SYSTEM INITIALIZED",
        "last_event_details": "Baseline system loaded successfully.",
        "last_event_type": "info",
        "last_app_v": "1.0",
        "last_cfg_v": "1.0",
        "last_os_v": "1.0",
        "last_slot": "A",
        "last_port": "9000"
    }

    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                loaded = json.load(f)
                state.update(loaded)
                state["boot_counter"] = state.get("boot_counter", 0) + 1
        except Exception:
            pass

    current_app_v = get_app_version()
    cfg_conf = load_config()
    current_cfg_v = cfg_conf.get("VERSION", "1.0")
    current_port = cfg_conf.get("PORT", "9000")
    current_os_v = get_os_version()
    current_slot = get_boot_slot()

    last_app_v = state.get("last_app_v", "1.0")
    last_cfg_v = state.get("last_cfg_v", "1.0")
    last_os_v = state.get("last_os_v", "1.0")
    last_slot = state.get("last_slot", "A")
    last_port = state.get("last_port", "9000")

    # Detect independent component updates
    if last_app_v != current_app_v:
        state["last_event_title"] = "APPLICATION UPDATED"
        state["last_event_details"] = f"v{last_app_v} → v{current_app_v} (Method: system extension)"
        state["last_event_type"] = "app"
    elif last_cfg_v != current_cfg_v or last_port != current_port:
        state["last_event_title"] = "CONFIGURATION UPDATED"
        state["last_event_details"] = f"v{last_cfg_v} → v{current_cfg_v} | Port {last_port} → {current_port} (Method: confext)"
        state["last_event_type"] = "config"
    elif last_os_v != current_os_v or (last_slot != "UNKNOWN" and current_slot != "UNKNOWN" and last_slot != current_slot):
        state["last_event_title"] = "OPERATING SYSTEM UPDATED"
        state["last_event_details"] = f"v{last_os_v} → v{current_os_v} | Boot Slot {last_slot} → {current_slot} (Method: SWUpdate A/B)"
        state["last_event_type"] = "os"

    # Update state trackers
    state["last_app_v"] = current_app_v
    state["last_cfg_v"] = current_cfg_v
    state["last_port"] = current_port
    state["last_os_v"] = current_os_v
    state["last_slot"] = current_slot

    try:
        with open(STATE_FILE, "w") as f:
            json.dump(state, f, indent=2)
    except Exception:
        pass

    return state


def read_persistent_state():
    """
    Read-only fetch for state file during web polling.
    """
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "device_id": "my-new-app-001",
        "deployment": "FACTORY-07",
        "boot_counter": 1,
        "last_event_title": "SYSTEM OPERATIONAL",
        "last_event_details": "Running nominal baseline.",
        "last_event_type": "info"
    }


class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/api/status":
            config = load_config()
            state = read_persistent_state()
            
            # Check if /tmp/demo.txt is missing
            demo_file_missing = not os.path.exists(DEMO_FILE)

            payload = {
                "os_version": get_os_version(),
                "application_version": get_app_version(),
                "configuration_version": config.get("VERSION", "1.0"),
                "boot_slot": get_boot_slot(),
                "rootfs": "READ-ONLY",
                "server_port": int(config.get("PORT", 9000)),
                "persistent_storage": "/var",
                "persistent_status": "PRESERVED",
                "device_id": state.get("device_id", "my-new-app-001"),
                "deployment": state.get("deployment", "FACTORY-07"),
                "boot_counter": state.get("boot_counter", 1),
                "last_event_title": state.get("last_event_title", "SYSTEM OPERATIONAL"),
                "last_event_details": state.get("last_event_details", "System running normally."),
                "last_event_type": state.get("last_event_type", "info"),
                "last_app_v": state.get("last_app_v", "1.0"),
                "last_cfg_v": state.get("last_cfg_v", "1.0"),
                "last_os_v": state.get("last_os_v", "1.0"),
                "last_slot": state.get("last_slot", "A"),
                "last_port": state.get("last_port", "9000"),
                "runtime_status": "failure_injected" if demo_file_missing else "healthy",
                "failure_marker": demo_file_missing,
                "runtime_storage": "/tmp"
            }

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.end_headers()
            self.wfile.write(json.dumps(payload).encode())
        else:
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode())

    def log_message(self, format, *args):
        # Mute standard access logging to keep console/journal clean
        return


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>my-new-app Demo Dashboard</title>
<style>
  :root { 
    --bg-ocean: #0a4373; 
    --bg-navy: #091c38; 
    --card-bg: #0d284a; 
    --card-border: #143b6b; 
    --yellow-accent: #ffcb05; 
    --text-main: #ffffff; 
    --text-muted: #9bb5d1; 
    --green-status: #00e676; 
    --red-status: #ff5252;
    --blue-accent: #00b0ff;
  }
  * { box-sizing: border-box; }
  body { 
    background: linear-gradient(135deg, var(--bg-navy) 0%, var(--bg-ocean) 100%); 
    color: var(--text-main); 
    font-family: 'Montserrat', 'Segoe UI', Arial, sans-serif; 
    margin: 0; 
    padding: 24px; 
    min-height: 100vh;
  }
  .header { 
    border-bottom: 3px solid var(--yellow-accent); 
    padding-bottom: 16px; 
    margin-bottom: 24px; 
    display: flex; 
    justify-content: space-between; 
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
  }
  .header h1 {
    font-weight: 800;
    letter-spacing: 1px;
    text-transform: uppercase;
    margin: 0;
    font-size: 1.8em;
  }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
  .card { 
    background: var(--card-bg); 
    border: 1px solid var(--card-border); 
    border-top: 4px solid var(--yellow-accent);
    border-radius: 6px; 
    padding: 20px; 
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    position: relative;
  }
  
  .v2-accent { 
    border-top-color: var(--green-status) !important; 
    background: linear-gradient(180deg, #0f3d3e 0%, var(--card-bg) 100%); 
  }
  
  .badge { 
    background: var(--yellow-accent); 
    color: var(--bg-navy); 
    font-weight: bold;
    padding: 6px 12px; 
    border-radius: 4px; 
    font-size: 0.85em; 
    letter-spacing: 0.5px;
  }
  
  .status-tag {
    display: inline-block;
    padding: 3px 8px;
    border-radius: 3px;
    font-size: 0.75em;
    font-weight: 800;
    letter-spacing: 0.5px;
    margin-top: 6px;
  }
  .tag-unchanged { background: rgba(155, 181, 209, 0.2); color: var(--text-muted); }
  .tag-updated { background: rgba(0, 230, 118, 0.2); color: var(--green-status); border: 1px solid var(--green-status); }
  .tag-preserved { background: rgba(0, 176, 255, 0.2); color: var(--blue-accent); border: 1px solid var(--blue-accent); }
  .tag-failure { background: rgba(255, 82, 82, 0.2); color: var(--red-status); border: 1px solid var(--red-status); }

  .stat { 
    font-size: 2.2em; 
    font-weight: 800; 
    color: var(--yellow-accent); 
    margin: 8px 0; 
    line-height: 1.1;
  }
  .label { 
    font-size: 0.8em; 
    color: var(--text-muted); 
    text-transform: uppercase; 
    font-weight: 700;
    letter-spacing: 1px;
  }
  
  .event-banner {
    background: #092240;
    border: 2px solid var(--yellow-accent);
    border-radius: 6px;
    padding: 16px 20px;
    margin-bottom: 24px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.4);
  }
  .event-title {
    font-size: 1.2em;
    font-weight: 800;
    color: var(--yellow-accent);
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .event-details {
    color: var(--text-main);
    margin-top: 4px;
    font-size: 0.95em;
  }

  code {
    background: rgba(255, 203, 5, 0.15);
    color: var(--yellow-accent);
    padding: 2px 6px;
    border-radius: 3px;
    font-family: monospace;
  }

  .table-reboot {
    width: 100%;
    border-collapse: collapse;
    margin-top: 10px;
  }
  .table-reboot td, .table-reboot th {
    padding: 8px 12px;
    text-align: left;
    border-bottom: 1px solid var(--card-border);
    font-size: 0.85em;
  }
  .table-reboot th {
    color: var(--text-muted);
    text-transform: uppercase;
  }
</style>
</head>
<body>

  <div class="header">
    <div>
      <h1>my-new-app DEMO DASHBOARD</h1>
      <small style="color:var(--text-muted); font-weight: 600;">NVIDIA Jetson Orin Nano — Driven by Commitment</small>
    </div>
    <div><span class="badge" id="system-badge">● SYSTEM ONLINE</span></div>
  </div>

  <div class="event-banner">
    <div class="label">LATEST ARCHITECTURE EVENT</div>
    <div class="event-title" id="event-title">✓ SYSTEM INITIALIZED</div>
    <div class="event-details" id="event-details">Baseline system operational. Monitoring independent updates...</div>
  </div>

  <div class="grid">
    <div class="card">
      <div class="label">Operating System</div>
      <div class="stat" id="os_v">v1.0</div>
      <div id="os-tag" class="status-tag tag-unchanged">UNCHANGED</div>
      <div style="margin-top:12px;">BOOT SLOT: <strong id="slot" style="color:var(--yellow-accent);">A</strong></div>
      <div style="margin-top:4px;">ROOTFS: <span style="color:#ff5252; font-weight:bold;">IMMUTABLE</span></div>
      <p style="font-size:0.75em; color:var(--text-muted); margin-top:8px; margin-bottom:0;">Updated via A/B image updates (SWUpdate).</p>
    </div>

    <div id="app-card" class="card">
      <div class="label">Application</div>
      <div class="stat" id="app_v">v1.0</div>
      <div id="app-tag" class="status-tag tag-unchanged">UNCHANGED</div>
      <div style="margin-top:12px;">DEPLOYMENT: <code>sysext</code></div>
      <div id="app-banner" style="margin-top:12px; padding:10px; background:rgba(255, 203, 5, 0.1); border:1px solid var(--yellow-accent); border-radius:4px; text-align:center; font-weight:bold; color:var(--yellow-accent);">
        my-new-app WEB SERVICE (v1.0)
      </div>
    </div>

    <div class="card">
      <div class="label">Configuration</div>
      <div class="stat" id="cfg_v">v1.0</div>
      <div id="cfg-tag" class="status-tag tag-unchanged">UNCHANGED</div>
      <div style="margin-top:12px;">SERVER PORT: <strong id="port" style="color:var(--yellow-accent);">9000</strong></div>
      <div style="margin-top:4px;">DEPLOYMENT: <code>confext</code></div>
      <p style="font-size:0.75em; color:var(--text-muted); margin-top:8px; margin-bottom:0;">Decoupled config update without touching app binaries.</p>
    </div>

    <div class="card">
      <div class="label">Persistent Device Data</div>
      <div class="stat" id="counter">1</div>
      <div class="status-tag tag-preserved">✓ PRESERVED</div>
      <div style="margin-top:12px;">DEVICE ID: <strong id="dev_id" style="color:var(--text-main);">my-new-app-001</strong></div>
      <div style="margin-top:4px;">STORAGE: <code>/var/lib/my-new-app</code></div>
      <p style="font-size:0.75em; color:var(--text-muted); margin-top:8px; margin-bottom:0;">State survives reboot, extension refresh, and A/B rootfs updates.</p>
    </div>

    <!-- Updated Runtime Status Card -->
    <div class="card" id="runtime-card">
      <div class="label">Runtime Status</div>
      <div class="stat" id="runtime-stat" style="color:var(--green-status);">● HEALTHY</div>
      <div id="runtime-tag" class="status-tag tag-preserved">DEMO FILE PRESENT</div>
      <div style="margin-top:12px;">VOLATILE PATH: <code>/tmp/demo.txt</code></div>
      <p style="font-size:0.75em; color:var(--text-muted); margin-top:8px; margin-bottom:0;" id="runtime-desc">
        Runtime state is healthy. /tmp/demo.txt is active.
      </p>
    </div>

    <div class="card">
      <div class="label">Reboot Behavior</div>
      <table class="table-reboot">
        <thead>
          <tr>
            <th>Path</th>
            <th>Type</th>
            <th>Behavior</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><code>/tmp</code></td>
            <td><span style="color:var(--yellow-accent);">VOLATILE</span></td>
            <td>Cleared on reboot</td>
          </tr>
          <tr>
            <td><code>/run</code></td>
            <td><span style="color:var(--yellow-accent);">VOLATILE</span></td>
            <td>Cleared on reboot</td>
          </tr>
          <tr>
            <td><code>/var</code></td>
            <td><span style="color:var(--green-status);">PERSISTENT</span></td>
            <td>Survives reboot & A/B</td>
          </tr>
          <tr>
            <td><code>ROOTFS</code></td>
            <td><span style="color:var(--red-status);">IMMUTABLE</span></td>
            <td>Protected write-lock</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <div class="card" style="margin-top:20px; text-align:center; color:var(--text-muted);">
    <strong style="color:var(--text-main); text-transform:uppercase; letter-spacing:0.5px;">
      Immutable OS &bull; Independent Extension Updates &bull; Ephemeral Runtime State
    </strong>
  </div>

<script>
async function update() {
  try {
    const res = await fetch('/api/status');
    const data = await res.json();

    document.getElementById('os_v').innerText = 'v' + data.os_version;
    document.getElementById('slot').innerText = data.boot_slot;
    const osTag = document.getElementById('os-tag');
    if (data.last_os_v && data.last_os_v !== data.os_version) {
      osTag.className = 'status-tag tag-updated';
      osTag.innerText = `UPDATED (v${data.last_os_v} → v${data.os_version})`;
    } else {
      osTag.className = 'status-tag tag-unchanged';
      osTag.innerText = 'UNCHANGED';
    }

    document.getElementById('app_v').innerText = 'v' + data.application_version;
    const appCard = document.getElementById('app-card');
    const appBanner = document.getElementById('app-banner');
    const appTag = document.getElementById('app-tag');

    if (data.application_version === "2.0") {
      appCard.classList.add('v2-accent');
      appBanner.style.background = "rgba(0, 230, 118, 0.15)";
      appBanner.style.borderColor = "var(--green-status)";
      appBanner.style.color = "var(--green-status)";
      appBanner.innerHTML = '✔ OTA UPDATE SUCCESS — my-new-app WEB SERVICE (v2.0)';
    } else {
      appCard.classList.remove('v2-accent');
      appBanner.style.background = "rgba(255, 203, 5, 0.1)";
      appBanner.style.borderColor = "var(--yellow-accent)";
      appBanner.style.color = "var(--yellow-accent)";
      appBanner.innerHTML = 'my-new-app WEB SERVICE (v1.0)';
    }

    if (data.last_app_v && data.last_app_v !== data.application_version) {
      appTag.className = 'status-tag tag-updated';
      appTag.innerText = `UPDATED (v${data.last_app_v} → v${data.application_version})`;
    } else {
      appTag.className = 'status-tag tag-unchanged';
      appTag.innerText = 'UNCHANGED';
    }

    document.getElementById('cfg_v').innerText = 'v' + data.configuration_version;
    document.getElementById('port').innerText = data.server_port;
    const cfgTag = document.getElementById('cfg-tag');
    if (data.last_cfg_v && data.last_cfg_v !== data.configuration_version) {
      cfgTag.className = 'status-tag tag-updated';
      cfgTag.innerText = `UPDATED (v${data.last_cfg_v} → v${data.configuration_version})`;
    } else {
      cfgTag.className = 'status-tag tag-unchanged';
      cfgTag.innerText = 'UNCHANGED';
    }

    document.getElementById('counter').innerText = 'BOOT #' + data.boot_counter;
    document.getElementById('dev_id').innerText = data.device_id;

    document.getElementById('event-title').innerText = '✓ ' + data.last_event_title;
    document.getElementById('event-details').innerText = data.last_event_details;

    // Dynamic update for missing /tmp/demo.txt
    const rtStat = document.getElementById('runtime-stat');
    const rtTag = document.getElementById('runtime-tag');
    const rtDesc = document.getElementById('runtime-desc');
    
    if (data.failure_marker || data.runtime_status === "failure_injected") {
      rtStat.innerText = '⚠ FAILURE INJECTED';
      rtStat.style.color = 'var(--red-status)';
      rtTag.className = 'status-tag tag-failure';
      rtTag.innerText = '/tmp/demo.txt MISSING';
      rtDesc.innerText = 'File /tmp/demo.txt was deleted! Restarting the service will crash and trigger a reboot in 10s.';
    } else {
      rtStat.innerText = '● HEALTHY';
      rtStat.style.color = 'var(--green-status)';
      rtTag.className = 'status-tag tag-preserved';
      rtTag.innerText = 'DEMO FILE PRESENT';
      rtDesc.innerText = 'Runtime status is healthy. File /tmp/demo.txt exists.';
    }

  } catch(e) {
    document.getElementById('system-badge').innerText = '● SYSTEM RESTARTING...';
    document.getElementById('system-badge').style.background = 'var(--red-status)';
  }
}

setInterval(update, 2000);
update();
</script>
</body>
</html>
"""

if __name__ == "__main__":
    init_persistent_state()

    # Start the watchdog thread to monitor /tmp/demo.txt
    watchdog_thread = threading.Thread(target=file_watchdog, daemon=True)
    watchdog_thread.start()

    cfg = load_config()
    port = int(cfg.get("PORT", 9000))
    print(f"Starting my-new-app Demo Application on port {port}...")

    class ReusableTCPServer(socketserver.TCPServer):
        allow_reuse_address = True

    with ReusableTCPServer(("", port), DashboardHandler) as httpd:
        httpd.serve_forever()