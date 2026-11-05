import asyncio
import json
import os
import sys
from pathlib import Path

import aiohttp

TOKEN = os.environ["HA_TOKEN"]
HTTP = "http://localhost:8123/api"
WS = "ws://localhost:8123/api/websocket"
DIR = Path(sys.argv[1])
DASHBOARD = "dashboard-home"
THEME = "ios-dark-mode-dark-blue"


async def wait_running(session):
    for _ in range(60):
        try:
            async with session.get(f"{HTTP}/config") as r:
                if r.status == 200 and (await r.json())["state"] == "RUNNING":
                    return
        except aiohttp.ClientError:
            pass
        await asyncio.sleep(5)
    raise SystemExit("Home Assistant did not reach RUNNING")


async def seed_automations(session):
    for automation in json.loads((DIR / "automations.json").read_text()):
        url = f"{HTTP}/config/automation/config/{automation['id']}"
        async with session.get(url) as r:
            if r.status == 200:
                continue
        async with session.post(url, json=automation) as r:
            r.raise_for_status()
        print(f"automation {automation['id']}: created")


async def seed_frontend(session):
    async with session.ws_connect(WS) as ws:
        await ws.receive_json()
        await ws.send_json({"type": "auth", "access_token": TOKEN})
        if (await ws.receive_json())["type"] != "auth_ok":
            raise SystemExit("WebSocket auth failed")
        msg_id = 0

        async def call(**msg):
            nonlocal msg_id
            msg_id += 1
            await ws.send_json({"id": msg_id, **msg})
            while True:
                r = await ws.receive_json()
                if r.get("id") == msg_id:
                    if not r["success"]:
                        raise SystemExit(f"{msg['type']}: {r['error']}")
                    return r.get("result")

        dashboards = await call(type="lovelace/dashboards/list")
        if not any(d["url_path"] == DASHBOARD for d in dashboards):
            await call(
                type="lovelace/dashboards/create",
                url_path=DASHBOARD,
                title="Home",
                icon="mdi:home",
                show_in_sidebar=True,
                require_admin=False,
                mode="storage",
            )
            config = json.loads((DIR / "dashboard-home.json").read_text())
            await call(type="lovelace/config/save", url_path=DASHBOARD, config=config)
            print(f"dashboard {DASHBOARD}: created")

        core = (await call(type="frontend/get_system_data", key="core"))["value"] or {}
        if not core.get("default_panel"):
            await call(type="frontend/set_system_data", key="core", value={**core, "default_panel": DASHBOARD})
            print(f"default dashboard: {DASHBOARD}")

        await call(type="call_service", domain="frontend", service="reload_themes")
        themes = await call(type="frontend/get_themes")
        if THEME not in themes["themes"]:
            print(f"theme {THEME}: not installed, skipping")
            return
        if themes["default_theme"] == "default":
            await call(type="call_service", domain="frontend", service="set_theme", service_data={"name": THEME})
            print(f"default theme: {THEME}")
        if not themes.get("default_dark_theme"):
            await call(
                type="call_service",
                domain="frontend",
                service="set_theme",
                service_data={"name": THEME, "mode": "dark"},
            )
            print(f"default dark theme: {THEME}")


async def main():
    async with aiohttp.ClientSession(headers={"Authorization": f"Bearer {TOKEN}"}) as session:
        await wait_running(session)
        await seed_automations(session)
        await seed_frontend(session)


asyncio.run(main())
