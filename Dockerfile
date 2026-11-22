# syntax=docker/dockerfile:1

# 构建阶段：复用 SDK 镜像拉依赖、跑构建；最终镜像只留 JRE 与产物。
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY core/backend/ ./core/backend/
WORKDIR /src/core/backend
RUN ./gradlew clean :server:fatJar --no-daemon

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/core/backend/server/build/libs/server-*-all.jar /app/tapmc-server.jar

# 存档与模组挂卷：容器内路径固定，宿主按需 -v 覆盖。
RUN mkdir -p /data/world /data/mods
ENV TAPMC_HOST=0.0.0.0 \
    TAPMC_PORT=8777 \
    TAPMC_SAVE_FILE=/data/world/world.json \
    TAPMC_MOD_DIR=/data/mods

EXPOSE 8777

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["java", "-cp", "/app/tapmc-server.jar", "cn.ntars.tapmc.server.HealthProbe", "127.0.0.1", "8777"]

ENTRYPOINT ["java", "-jar", "/app/tapmc-server.jar"]
CMD ["--host", "0.0.0.0", "--port", "8777", "--save-file", "/data/world/world.json", "--autosave", "60", "--mods", "/data/mods"]
