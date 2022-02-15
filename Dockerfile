# Multi-stage
# 1) Node image for building frontend assets
# 2) nginx stage to serve frontend assets

# Name the node stage "builder"
FROM node:12.21.0-alpine AS builder
WORKDIR /usr/src/app
COPY . ./
RUN rm package-lock.json
RUN yarn cache clean && yarn --update-checksums
RUN yarn && yarn build
# to check files
RUN ls -l

# Stage - Production
FROM nginx:1.19.1-alpine
EXPOSE 80
COPY nginx.conf /etc/nginx/nginx.conf
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/build /usr/share/nginx/html
CMD ["nginx", "-g", "daemon off;"]

#docker build -t git-action-react-app .
#docker run -d --rm --name git-action-react-ui -p 8088:80 git-action-react-app