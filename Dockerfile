FROM elixir:1.17-alpine AS builder

# Instalar dependencias del sistema
RUN apk add --no-cache build-base git

# Configurar directorio de trabajo
WORKDIR /app

# Copiar archivos de configuración
COPY mix.exs mix.lock ./
COPY config config

# Instalar dependencias
RUN mix local.hex --force && \
    mix local.rebar --force
RUN mix deps.get --only prod
RUN mix deps.compile

# Copiar código fuente
COPY lib lib
COPY priv priv

# Compilar release
RUN mix compile
RUN mix release

# Imagen final
FROM alpine:3.18

# Instalar dependencias de runtime
RUN apk add --no-cache openssl ncurses-libs

# Crear usuario no-root
RUN adduser -D -s /bin/sh rent_bot

WORKDIR /app

# Copiar release desde builder
COPY --from=builder --chown=rent_bot:rent_bot /app/_build/prod/rel/rent_bot ./

# Crear directorio para datos
RUN mkdir -p /app/data && chown rent_bot:rent_bot /app/data

USER rent_bot

# Variables de entorno
ENV HOME=/app/data

# Puerto (si fuera necesario en el futuro)
EXPOSE 4000

# Comando por defecto
CMD ["./bin/rent_bot", "start"]
