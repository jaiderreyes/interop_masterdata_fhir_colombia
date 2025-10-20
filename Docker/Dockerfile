# Imagen base ligera con Python 3.8
FROM python:3.8-slim

# Variables de entorno para UTF-8
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Crear carpeta de trabajo
WORKDIR /work

# Copiar el proyecto completo
COPY . /work

# Instalar dependencias necesarias
RUN pip install --no-cache-dir psycopg2-binary pandas matplotlib

# Crear carpeta de reportes
RUN mkdir -p /reports

# Ajustar el host de conexión en validate_data.py para entorno Docker
RUN sed -i "s/\"host\": \"localhost\"/\"host\": \"postgres\"/" tests/validate_data.py

# Ejecutar validación automáticamente al iniciar
CMD ["python", "tests/validate_data.py"]
