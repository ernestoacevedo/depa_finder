defmodule Mix.Tasks.RentBot.Release do
  @moduledoc """
  Construye un release de producción de RentBot.

  ## Uso

      mix rent_bot.release

  Este comando:
  - Configura el entorno de producción
  - Instala dependencias
  - Compila la aplicación
  - Genera el release
  - Muestra información sobre cómo deployar

  ## Opciones

      --clean     Limpia la compilación anterior antes de construir
      --test      Ejecuta las pruebas antes de construir el release
  """

  use Mix.Task

  @requirements ["app.config"]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [clean: :boolean, test: :boolean])

    Mix.shell().info("🔨 Construyendo release de RentBot...")

    if opts[:clean] do
      Mix.shell().info("🧹 Limpiando compilación anterior...")
      Mix.Task.run("clean")
    end

    if opts[:test] do
      Mix.shell().info("🧪 Ejecutando pruebas...")
      Mix.Task.run("test")
    end

    # Configurar entorno de producción
    Mix.env(:prod)
    System.put_env("MIX_ENV", "prod")

    Mix.shell().info("📦 Instalando dependencias de producción...")
    Mix.Task.run("deps.get", ["--only", "prod"])

    Mix.shell().info("⚙️  Compilando dependencias...")
    Mix.Task.run("deps.compile")

    Mix.shell().info("🔧 Compilando aplicación...")
    Mix.Task.run("compile")

    Mix.shell().info("📦 Generando release...")
    Mix.Task.run("release", ["--overwrite"])

    Mix.shell().info("""

    ✅ Release construido exitosamente!

    📁 El release está disponible en: _build/prod/rel/rent_bot/

    🚀 Para deployar en producción:

    1. Configura las variables de entorno en tu servidor:
       export TG_BOT_TOKEN="tu_bot_token"
       export TG_CHAT_ID="tu_chat_id"

    2. Copia el proyecto al servidor y ejecuta:
       chmod +x deploy.sh
       sudo ./deploy.sh

    🧪 Para probar localmente:
       _build/prod/rel/rent_bot/bin/rent_bot start

    📋 Archivos importantes:
       - deploy.sh: Script de deployment automático
       - _build/prod/rel/rent_bot/: Release completo
       - config/prod.exs: Configuración de producción

    """)
  end
end
