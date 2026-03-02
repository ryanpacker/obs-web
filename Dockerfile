FROM node:lts-alpine
COPY ./ ./
RUN npm ci && npm run build
EXPOSE 3000
ENTRYPOINT ["node", "build"]
LABEL org.opencontainers.image.source="https://github.com/Niek/obs-web"
