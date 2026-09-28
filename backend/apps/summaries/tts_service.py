import asyncio
import edge_tts
import os

async def generate_audio_async(text, output_path, voice="en-US-ChristopherNeural"):
    """
    Generates an MP3 file from text using edge-tts.
    """
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(output_path)

def generate_audio(text, output_path, voice="en-US-ChristopherNeural"):
    """
    Synchronous wrapper for generate_audio_async.
    """
    asyncio.run(generate_audio_async(text, output_path, voice))
