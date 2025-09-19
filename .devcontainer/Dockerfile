# Build on top of the official OpenStudio image for Python 3.8.0
FROM nrel/openstudio:3.10.0

# Set environment variable to avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV OPENSTUDIO_HOME = /usr/local/openstudio-3.10.0
ENV OPENSTUDIO_CLI=${OPENSTUDIO_HOME}/bin/openstudio

# Set working directory to /usr/src/app, where our application code will reside
WORKDIR /usr/src/app

# Install system dependencies for Ruby + gem
RUN apt-get update && apt-get install -y \
    build-essential \
    ruby-dev \
    git \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libffi-dev \
    libssl-dev \
    curl \
 && rm -rf /var/lib/apt/lists/*

# Ensure bundler is installed
RUN gem install bundler

# Copy your application code (optional for devcontainer setup)
# COPY ..

CMD [ "sleep", "infinity" ]