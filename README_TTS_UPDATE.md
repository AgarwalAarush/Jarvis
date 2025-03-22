# Jarvis Assistant - TTS Update

This document provides information about the new Text-to-Speech (TTS) system for the Jarvis Assistant.

## What's New

The Jarvis Assistant has been updated to use the XTTS (XTalk) TTS system, which provides several advantages over the previous Bark-based TTS:

- **Improved Voice Quality**: More natural-sounding voice synthesis
- **Better Performance**: Faster generation times
- **Multilingual Support**: Support for multiple languages (not just English)
- **Improved Caching**: Enhanced caching system for faster responses
- **Streaming Capability**: Ability to start playback before the entire response is generated

## How to Update

You can update your Jarvis Assistant in two ways:

### Automatic Update

1. Run the provided update script:
   ```bash
   python update_to_xtts.py
   ```

2. The script will:
   - Install required dependencies
   - Update app.py to use the new TTS service
   - Test the system
   - Create backup files in case you need to revert

### Manual Update

If you prefer to update manually:

1. Install required dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. In `app.py`, change:
   ```python
   from optimized_tts import OptimizedTTSService
   tts = OptimizedTTSService(cache_dir="./tts_cache")
   ```
   to:
   ```python
   from xtts_service import XTTSService
   tts = XTTSService(cache_dir="./tts_cache")
   ```

## Reverting to the Original TTS

If you encounter any issues or prefer the original TTS system:

1. If you used the automatic update, restore the backup:
   ```bash
   cp app.py.backup app.py
   ```

2. If you manually updated, change the imports back to the original:
   ```python
   from optimized_tts import OptimizedTTSService
   tts = OptimizedTTSService(cache_dir="./tts_cache")
   ```

## Troubleshooting

If you encounter any issues with the new TTS system:

1. **Missing Dependencies**: Ensure you have all required packages installed:
   ```bash
   pip install -r requirements.txt
   ```

2. **Compatibility Issues**: The new TTS system requires Python 3.8 or newer.

3. **Performance Issues**: If performance is slow, check if CUDA is available for your system.
   You can modify `xtts_service.py` to use CPU-only mode if needed.

4. **Audio Quality Issues**: You may need to adjust audio normalization in `xtts_service.py`.
