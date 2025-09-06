FROM python:3.11-slim

# Work at /app (package will live in /app/bot_hub)
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \n    curl \n    gcc \n    libc6-dev \n    && rm -rf /var/lib/apt/lists/*

# Copy requirements (context is ./bot_hub)
COPY requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \n    pip install --no-cache-dir -r /app/requirements.txt

# Copy application code into /app/bot_hub so it becomes a real package
COPY . /app/bot_hub

# Create necessary directories (outside package for mounts)
RUN mkdir -p /app/logs /app/uploads && \n    chmod 755 /app/logs /app/uploads

# Create non-root user
RUN useradd -m -u 1000 botuser && \n    chown -R botuser:botuser /app

# Switch to non-root user
USER botuser

# Expose port
EXPOSE 8080

# Run application as package entry
CMD ["python", "-m", "uvicorn", "bot_hub.main:app", "--host", "0.0.0.0", "--port", "8080"]
