# 1. Usamos la imagen base oficial de RunPod Serverless para ComfyUI
FROM runpod/worker-comfyui:main

# 2. Entramos como administrador (root) para instalar programas del sistema
USER root

# 3. Instalamos ffmpeg (VITAL para que el nodo VHS pueda armar el video .mp4)
RUN apt-get update && apt-get install -y ffmpeg libgl1-mesa-glx && rm -rf /var/lib/apt/lists/*

# 4. Nos movemos a la carpeta de nodos personalizados
WORKDIR /comfyui/custom_nodes/

# 5. Descargamos (clonamos) las 3 extensiones que necesita tu flujo
RUN git clone https://github.com/kijai/ComfyUI-CogVideoXWrapper.git
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
RUN git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git

# 6. Instalamos los requisitos (dependencias de Python) de cada extensión
RUN pip install --no-cache-dir -r ComfyUI-CogVideoXWrapper/requirements.txt
RUN pip install --no-cache-dir -r ComfyUI-VideoHelperSuite/requirements.txt
RUN pip install --no-cache-dir -r ComfyUI-Frame-Interpolation/requirements.txt

# 7. Regresamos al directorio principal para que RunPod arranque feliz
WORKDIR /
