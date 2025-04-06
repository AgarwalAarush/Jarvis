import time
import objc
import AppKit
from AppKit import NSRunningApplication
from Quartz.ApplicationServices import AXUIElementCreateApplication, AXUIElementCopyAttributeValue
from Quartz import CGEventCreateKeyboardEvent, CGEventPost, kCGHIDEventTap
from Quartz import kVK_ANSI_W, kVK_ANSI_H, kVK_ANSI_A, kVK_ANSI_T, kVK_ANSI_I, kVK_ANSI_S, kVK_Space, kVK_Return


def type_key(key_code):
    CGEventPost(kCGHIDEventTap, CGEventCreateKeyboardEvent(None, key_code, True))
    CGEventPost(kCGHIDEventTap, CGEventCreateKeyboardEvent(None, key_code, False))

def type_prompt(prompt):
    from AppKit import NSEvent

    for char in prompt:
        key_event = NSEvent.keyEventWithType_location_modifierFlags_timestamp_windowNumber_context_characters_charactersIgnoringModifiers_isARepeat_keyCode_(
            10,  # NSKeyDown
            (0, 0),
            0,
            time.time(),
            0,
            None,
            char,
            char,
            False,
            0
        )
        key_event.postToQueue_(None)

    type_key(kVK_Return)

def get_claude_response():
    # Get Claude PID
    apps = NSRunningApplication.runningApplicationsWithBundleIdentifier_("com.anthropic.claude")
    if not apps:
        print("Claude not running")
        return
    pid = apps[0].processIdentifier()

    # Create accessibility reference
    app_ref = AXUIElementCreateApplication(pid)

    # Try to get main window
    result, main_window = AXUIElementCopyAttributeValue(app_ref, "AXMainWindow", None)
    if result != 0:
        print("Couldn't get main window")
        return

    # Get all child elements
    result, children = AXUIElementCopyAttributeValue(main_window, "AXChildren", None)
    if result != 0 or not children:
        print("No children found")
        return

    # Traverse to find AXStaticText or AXTextArea etc.
    for child in children:
        result, role = AXUIElementCopyAttributeValue(child, "AXRole", None)
        if role == "AXStaticText":
            result, value = AXUIElementCopyAttributeValue(child, "AXValue", None)
            print("Claude response:", value)
            return value

if __name__ == "__main__":
    workspace = AppKit.NSWorkspace.sharedWorkspace()
    workspace.launchApplication_("Claude")

    # # wait for the application to launch
    # time.sleep(3)

    # # simulate typing and enter
    # type_prompt("What is a resnet?")

    # # get response
    # response = get_claude_response()
    # print("Claude response:", response)


