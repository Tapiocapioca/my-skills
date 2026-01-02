# Whisper Server - Audio transcription with OpenAI Whisper
# Heavier container with faster-whisper for CPU transcription

FROM python:3.11-slim

LABEL maintainer="Tapiocapioca"
LABEL description="REST API for audio transcription using faster-whisper"
LABEL version="1.0.0"

# Install system dependencies for audio processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python dependencies
# Note: faster-whisper downloads model on first use (~150MB for base model)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Create directories for temp files and model cache
RUN mkdir -p /app/temp /app/models

# Set environment variables
ENV WHISPER_MODEL=base
ENV XDG_CACHE_HOME=/app/models

# Expose port
EXPOSE 8502

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8502/health || exit 1

# Run the server
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8502"]
