# Environment for tools/make_audio.py (Silero TTS on CPU + ffmpeg).
FROM docker.io/library/python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir torch==2.5.1 --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir numpy omegaconf
