# yt-dlp Server - YouTube transcript extraction
# Lightweight container for extracting YouTube subtitles/transcripts

FROM python:3.11-slim

LABEL maintainer="Tapiocapioca"
LABEL description="REST API for YouTube transcript extraction using yt-dlp"
LABEL version="1.0.0"

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .
COPY utils/ ./utils/

# Expose port
EXPOSE 8501

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8501/health || exit 1

# Run the server
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8501"]
