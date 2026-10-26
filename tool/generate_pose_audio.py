"""Regenerate bundled camera prompts: pip install edge-tts, then run this file.

Only the static phrases in phrases.json are sent to the synthesis service.
The application plays the resulting local files without contacting that service.
"""
import asyncio
import json
from pathlib import Path

import edge_tts

OUTPUT = Path(__file__).resolve().parents[1] / "web" / "pose-audio" / "vi"


async def main():
    phrases = json.loads((OUTPUT / "phrases.json").read_text(encoding="utf-8"))
    limit = asyncio.Semaphore(3)

    async def generate(key, text):
        destination = OUTPUT / f"{key}.mp3"
        if destination.exists() and destination.stat().st_size > 0:
            return
        async with limit:
            for attempt in range(3):
                try:
                    await edge_tts.Communicate(text, "vi-VN-HoaiMyNeural", rate="-5%").save(str(destination))
                    print(key, flush=True)
                    return
                except Exception:
                    if attempt == 2:
                        raise
                    await asyncio.sleep(2)

    await asyncio.gather(*(generate(key, text) for key, text in phrases.items()))


if __name__ == "__main__":
    asyncio.run(main())
