FROM registry.redhat.io/rhel8/buildah:latest

# Set the working directory
WORKDIR /app

# Copy dependencies
COPY deps/ ./

# Update and install dependencies
USER root
RUN yum update -y && \
    yum install -y rsync && \
    curl --silent --location https://rpm.nodesource.com/setup_18.x | bash - && \
    yum -y install nodejs && \
    yum -y install buildah

# Install pnpm and dependencies
RUN npm install -g pnpm && \
    pnpm install && \
    pnpm bootstrap

