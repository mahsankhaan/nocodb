FROM registry.redhat.io/rhel8/buildah:latest
WORKDIR /app
COPY . .
RUN yum update -y && \
    yum install -y rsync

RUN curl --silent --location https://rpm.nodesource.com/setup_18.x | bash - && \
    yum -y install nodejs && \
    yum -y install buildah

RUN npm install -g pnpm && \
    pnpm install &&\
    pnpm bootstrap