# --------
# Builder stage
# --------
FROM python:3.11-slim AS builder

# Set working directory for builder
WORKDIR /app

# Copy the entire project first
COPY . /app/

# Upgrade pip and build wheels for all dependencies
RUN pip install --upgrade pip \
    && mkdir /wheels \
    && pip wheel --wheel-dir=/wheels -r requirements.txt

# --------
# Final runtime stage
# --------
FROM python:3.11-slim

WORKDIR /app

# Copy the entire project
COPY . /app/

# Copy the wheels built in the builder stage
COPY --from=builder /wheels /wheels

# Install Python dependencies from the local wheel cache
RUN pip install --upgrade pip \
    && pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt \
    && rm -rf /wheels

# Create models directory
RUN mkdir -p /app/models

# Default embedding model (can be overridden at build time)
ARG EMBEDDING_MODEL_NAME=intfloat/multilingual-e5-base

# Pre-download embedding model
RUN python -c "import os; from sentence_transformers import SentenceTransformer; \
    model_name='${EMBEDDING_MODEL_NAME}'; \
    model=SentenceTransformer(model_name); \
    model.save('/app/models/' + model_name.split('/')[-1])"

# Set environment variables
ENV SENTENCE_TRANSFORMERS_HOME=/app/models
ENV PYTHONPATH=/app/src
ENV EMBEDDING_MODEL_NAME=${EMBEDDING_MODEL_NAME}

# Expose port
EXPOSE 8000

# Run the server directly
ENTRYPOINT ["python", "src/mcp_server_any_openapi/server.py"]
