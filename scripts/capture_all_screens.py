#!/usr/bin/env python3
"""
VoiceDay Screen Capture Automation
Navigates through the app and captures screenshots of all screens.
Simulates a user's full day journey for documentation.
"""

import subprocess
import time
import os
from datetime import datetime

# Configuration
SCREENSHOT_DIR = "/Users/markgentry/Projects/VoiceDay/screenshots/automated"
BUNDLE_ID = "com.gadfly.adhd"
SIMULATOR_NAME = "iPhone 17 Pro"

# Window position (update if simulator moves)
WINDOW_X = 626
WINDOW_Y = 53
WINDOW_WIDTH = 391
WINDOW_HEIGHT = 841

class VoiceDayAutomation:
    def __init__(self):
        self.screenshot_count = 0
        self.screenshots = []
        os.makedirs(SCREENSHOT_DIR, exist_ok=True)

    def run_cmd(self, cmd, shell=True):
        """Run a shell command and return output."""
        result = subprocess.run(cmd, shell=shell, capture_output=True, text=True)
        return result.stdout.strip()

    def screenshot(self, name, description=""):
        """Capture a screenshot with a numbered prefix."""
        self.screenshot_count += 1
        filename = f"{self.screenshot_count:03d}_{name}.png"
        filepath = os.path.join(SCREENSHOT_DIR, filename)

        self.run_cmd(f'xcrun simctl io booted screenshot "{filepath}"')
        self.screenshots.append({
            "number": self.screenshot_count,
            "name": name,
            "filename": filename,
            "description": description,
            "path": filepath
        })
        print(f"📸 [{self.screenshot_count:03d}] {name}: {description}")
        return filepath

    def activate_simulator(self):
        """Bring simulator to front."""
        self.run_cmd('osascript -e \'tell application "Simulator" to activate\'')
        time.sleep(0.3)

    def click(self, x, y):
        """Click at absolute screen coordinates."""
        self.activate_simulator()
        self.run_cmd(f'cliclick c:{x},{y}')
        time.sleep(0.5)

    def click_relative(self, rel_x, rel_y):
        """Click relative to simulator window (0-1 range)."""
        abs_x = int(WINDOW_X + WINDOW_WIDTH * rel_x)
        abs_y = int(WINDOW_Y + WINDOW_HEIGHT * rel_y)
        self.click(abs_x, abs_y)

    def tap_center(self):
        """Tap center of screen."""
        self.click_relative(0.5, 0.5)

    def tap_bottom_button(self):
        """Tap bottom action button area."""
        self.click_relative(0.5, 0.92)

    def tap_tab(self, index):
        """Tap a tab bar item (0-4)."""
        # Tab bar is at bottom, divide into 5 sections
        tab_x = 0.1 + (index * 0.2)
        self.click_relative(tab_x, 0.97)

    def swipe_up(self):
        """Swipe up gesture."""
        self.activate_simulator()
        start_y = int(WINDOW_Y + WINDOW_HEIGHT * 0.8)
        end_y = int(WINDOW_Y + WINDOW_HEIGHT * 0.3)
        x = int(WINDOW_X + WINDOW_WIDTH * 0.5)
        self.run_cmd(f'cliclick dd:{x},{start_y} du:{x},{end_y}')
        time.sleep(0.5)

    def type_text(self, text):
        """Type text using keyboard."""
        self.activate_simulator()
        # Escape special characters for osascript
        escaped = text.replace('"', '\\"').replace("'", "\\'")
        self.run_cmd(f'osascript -e \'tell application "System Events" to keystroke "{escaped}"\'')
        time.sleep(0.3)

    def press_key(self, key):
        """Press a specific key."""
        self.activate_simulator()
        self.run_cmd(f'osascript -e \'tell application "System Events" to keystroke {key}\'')

    def launch_app(self, fresh=False):
        """Launch the VoiceDay app."""
        if fresh:
            # Terminate if running
            self.run_cmd(f'xcrun simctl terminate booted {BUNDLE_ID}')
            time.sleep(0.5)

        self.run_cmd(f'xcrun simctl launch booted {BUNDLE_ID}')
        time.sleep(2)
        self.activate_simulator()

    def complete_onboarding(self):
        """Navigate through onboarding screens."""
        print("\n🎬 Starting Onboarding Flow...")

        # Screen 1: Voice Selection
        time.sleep(1)
        self.screenshot("onboarding_01_voice", "Voice selection - Choose your voice")

        # Tap Quick Start with Defaults (around 35% down)
        self.click_relative(0.5, 0.35)
        time.sleep(1)

        # Screen 2: Personality
        self.screenshot("onboarding_02_personality", "Personality selection")
        self.tap_bottom_button()
        time.sleep(1)

        # Screen 3: Daily Structure
        self.screenshot("onboarding_03_structure", "Daily check-in schedule")
        self.tap_bottom_button()
        time.sleep(1)

        # Screen 4: Continue through
        self.screenshot("onboarding_04_features", "Feature introduction")
        self.tap_bottom_button()
        time.sleep(1)

        # Screen 5: Final
        self.screenshot("onboarding_05_complete", "Onboarding complete")
        self.tap_bottom_button()
        time.sleep(2)

        print("✅ Onboarding complete!")

    def capture_main_tabs(self):
        """Capture all main tab screens."""
        print("\n📱 Capturing Main Tab Screens...")

        tabs = [
            ("home", "Focus Home - Main dashboard"),
            ("recording", "Voice Recording - Capture tasks"),
            ("tasks", "Tasks List - Todo management"),
            ("goals", "Goals - Track objectives"),
            ("settings", "Settings - App configuration")
        ]

        for i, (name, desc) in enumerate(tabs):
            self.tap_tab(i)
            time.sleep(1.5)
            self.screenshot(f"tab_{i}_{name}", desc)

        print("✅ All tabs captured!")

    def simulate_morning_routine(self):
        """Simulate morning check-in and task creation."""
        print("\n🌅 Simulating Morning Routine...")

        # Go to home tab
        self.tap_tab(0)
        time.sleep(1)
        self.screenshot("morning_home", "Home screen at start of day")

        # Go to tasks
        self.tap_tab(2)
        time.sleep(1)
        self.screenshot("morning_tasks_empty", "Tasks before adding morning items")

        # Simulate adding a task (tap + area)
        self.click_relative(0.9, 0.85)  # Floating action button area
        time.sleep(1)
        self.screenshot("add_task_modal", "Add task modal/sheet")

    def simulate_midday(self):
        """Simulate midday activities."""
        print("\n🌞 Simulating Midday...")

        self.tap_tab(2)  # Tasks
        time.sleep(1)
        self.screenshot("midday_tasks", "Tasks at midday")

        self.tap_tab(3)  # Goals
        time.sleep(1)
        self.screenshot("midday_goals", "Goals progress")

    def simulate_evening(self):
        """Simulate evening wind-down."""
        print("\n🌙 Simulating Evening...")

        self.tap_tab(0)  # Home
        time.sleep(1)
        self.screenshot("evening_home", "Home at end of day")

        self.tap_tab(4)  # Settings
        time.sleep(1)
        self.screenshot("evening_settings", "Settings view")

        # Scroll down to see more settings
        self.swipe_up()
        time.sleep(0.5)
        self.screenshot("settings_scrolled", "Settings (scrolled)")

    def explore_settings(self):
        """Explore various settings screens."""
        print("\n⚙️ Exploring Settings...")

        self.tap_tab(4)
        time.sleep(1)

        # Tap on different settings items
        settings_positions = [
            (0.5, 0.30, "settings_item_1", "First settings section"),
            (0.5, 0.40, "settings_item_2", "Second settings section"),
            (0.5, 0.50, "settings_item_3", "Third settings section"),
        ]

        for x, y, name, desc in settings_positions:
            self.click_relative(x, y)
            time.sleep(1)
            self.screenshot(name, desc)
            # Go back
            self.click_relative(0.1, 0.08)  # Back button area
            time.sleep(0.5)

    def run_full_capture(self):
        """Run complete screen capture workflow."""
        print("=" * 60)
        print("🚀 VoiceDay Automated Screen Capture")
        print(f"📁 Output: {SCREENSHOT_DIR}")
        print("=" * 60)

        self.launch_app(fresh=True)
        self.complete_onboarding()
        self.capture_main_tabs()
        self.simulate_morning_routine()
        self.simulate_midday()
        self.simulate_evening()
        self.explore_settings()

        print("\n" + "=" * 60)
        print(f"✅ Complete! Captured {self.screenshot_count} screenshots")
        print(f"📁 Saved to: {SCREENSHOT_DIR}")
        print("=" * 60)

        return self.screenshots

    def generate_html_report(self):
        """Generate HTML report of captured screenshots."""
        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>VoiceDay Screenshot Report</title>
    <style>
        body {{ font-family: -apple-system, sans-serif; background: #1a1a1a; color: white; padding: 40px; }}
        h1 {{ color: #22c55e; text-align: center; }}
        .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }}
        .card {{ background: #252525; border-radius: 12px; padding: 16px; }}
        .card img {{ width: 100%; border-radius: 8px; }}
        .card h3 {{ color: #4ade80; margin: 10px 0 5px; }}
        .card p {{ color: #a1a1aa; font-size: 14px; }}
        .timestamp {{ text-align: center; color: #666; margin-bottom: 30px; }}
    </style>
</head>
<body>
    <h1>VoiceDay Screenshots</h1>
    <p class="timestamp">Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
    <div class="grid">
"""
        for shot in self.screenshots:
            html += f"""
        <div class="card">
            <img src="{shot['filename']}" alt="{shot['name']}">
            <h3>{shot['number']:03d}. {shot['name'].replace('_', ' ').title()}</h3>
            <p>{shot['description']}</p>
        </div>
"""
        html += """
    </div>
</body>
</html>
"""
        report_path = os.path.join(SCREENSHOT_DIR, "report.html")
        with open(report_path, "w") as f:
            f.write(html)
        print(f"📄 HTML report: {report_path}")
        return report_path


if __name__ == "__main__":
    automation = VoiceDayAutomation()
    automation.run_full_capture()
    automation.generate_html_report()
