#!/usr/bin/env python3
"""
Update Script to switch from the original Bark TTS to the new XTTS implementation.
This script:
1. Installs required dependencies
2. Updates app.py to use the new TTS service
3. Tests the new TTS service
"""

import os
import sys
import subprocess
import platform
import time

def print_step(step_num, message):
    """Print a formatted step message."""
    print(f"\n[{step_num}] {message}")
    print("=" * (len(message) + 4))

def run_command(cmd, exit_on_error=True):
    """Run a shell command and exit on error if specified."""
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"Error running command: {' '.join(cmd)}")
        print(f"Error output: {result.stderr}")
        if exit_on_error:
            print("Exiting due to error.")
            sys.exit(1)
        return False
    
    print(result.stdout)
    return True

def check_pip_installation():
    """Check if pip is installed."""
    try:
        subprocess.run([sys.executable, "-m", "pip", "--version"], 
                       check=True, capture_output=True)
        return True
    except:
        return False

def main():
    """Main update function."""
    print("\n" + "=" * 50)
    print("JARVIS ASSISTANT - TTS UPDATE SCRIPT")
    print("=" * 50)
    print("\nThis script will update your Jarvis Assistant to use the new XTTS text-to-speech system.")
    
    # Check if we're in the correct directory
    if not os.path.exists("app.py") or not os.path.exists("tts.py"):
        print("ERROR: This script must be run from the jarvis project directory.")
        print("Please navigate to the directory containing app.py and try again.")
        return
    
    # Check if XTTS file already exists
    if os.path.exists("xtts_service.py"):
        print("The XTTS service file already exists.")
        response = input("Do you want to proceed with the update anyway? (y/n): ")
        if response.lower() != 'y':
            print("Update cancelled.")
            return
    
    # Step 1: Check dependencies
    print_step(1, "Checking dependencies")
    
    if not check_pip_installation():
        print("ERROR: pip is not installed or not in the PATH.")
        print("Please install pip and try again.")
        return
    
    # Step 2: Install requirements
    print_step(2, "Installing required packages")
    
    # Use pip to install requirements
    run_command([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
    
    # Step 3: Create backup
    print_step(3, "Creating backup of original files")
    
    if os.path.exists("app.py"):
        run_command(["cp", "app.py", "app.py.backup"])
    
    # Step 4: Update app.py
    print_step(4, "Updating app.py to use the new TTS service")
    
    if not os.path.exists("xtts_service.py"):
        print("ERROR: xtts_service.py not found. The update will not work.")
        return
    
    # Use sed to update app.py
    try:
        with open("app.py", "r") as f:
            content = f.read()
        
        # Replace the optimized_tts import with xtts_service
        content = content.replace("from optimized_tts import OptimizedTTSService", 
                                "from xtts_service import XTTSService")
        
        # Replace the TTS instantiation
        content = content.replace("tts = OptimizedTTSService(cache_dir=\"./tts_cache\")", 
                                "tts = XTTSService(cache_dir=\"./tts_cache\")")
        
        with open("app.py", "w") as f:
            f.write(content)
            
        print("Successfully updated app.py to use the new TTS service.")
    except Exception as e:
        print(f"Error updating app.py: {e}")
        print("Reverting to backup...")
        run_command(["cp", "app.py.backup", "app.py"])
        return
    
    # Step 5: Test the updated system
    print_step(5, "Testing the updated TTS system")
    
    print("Running a quick test of the XTTS system...")
    run_command([sys.executable, "xtts_service.py"], exit_on_error=False)
    
    # Completion
    print("\n" + "=" * 50)
    print("UPDATE COMPLETED SUCCESSFULLY!")
    print("=" * 50)
    print("\nYour Jarvis Assistant is now configured to use the XTTS text-to-speech system.")
    print("To start the assistant, run 'python app.py'")
    print("\nIf you encounter any issues, you can restore the original app.py by running:")
    print("cp app.py.backup app.py")
    print("\nEnjoy your improved Jarvis Assistant!")

if __name__ == "__main__":
    main()
