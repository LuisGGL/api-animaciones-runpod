# 1. Usamos la imagen base oficial de RunPod Serverless para ComfyUI
FROM runpod/worker-comfyui:5.2.0-base

# 2. Entramos como administrador (root) para instalar programas del sistema
USER root

# 3. Instalamos ffmpeg (VITAL para que el nodo VHS pueda armar el video .mp4)
RUN apt-get update && apt-get install -y ffmpeg libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*

# 4. Nos movemos a la carpeta de nodos personalizados
WORKDIR /comfyui/custom_nodes/

# 5. Descargamos (clonamos) las extensiones que usa tu flujo.
#    OJO: se quitó ComfyUI-KJNodes. Ningún nodo del workflow la usa y además
#    no carga con esta versión de ComfyUI (ModuleNotFoundError: comfy_api.latest),
#    solo ensuciaba el log y sumaba tiempo de build/cold start.
RUN git clone https://github.com/kijai/ComfyUI-CogVideoXWrapper.git
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
RUN git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git

# 6. Instalamos los requisitos (dependencias de Python) de cada extensión
RUN pip install --no-cache-dir -r ComfyUI-CogVideoXWrapper/requirements.txt
RUN pip install --no-cache-dir -r ComfyUI-VideoHelperSuite/requirements.txt
RUN pip install --no-cache-dir -r ComfyUI-Frame-Interpolation/requirements-no-cupy.txt

# 7. Actualizamos PyTorch a un build con soporte para Blackwell (sm_120: RTX 5090,
#    RTX PRO 6000 y variantes, B300). El torch que trae la imagen base (2.7.1+cu126)
#    NO corre en esas GPUs -- por eso el log mostraba el warning de incompatibilidad
#    y la ejecución moría en silencio antes de llegar al sampler.
#    Va al final para que ningún requirements.txt de arriba lo reinstale/pise después.
RUN pip install --no-cache-dir --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# 8. El nodo DownloadAndLoadCogVideoModel guarda el modelo en /comfyui/models/CogVideo,
#    que vive en el disco EFÍMERO del contenedor -> se re-descargaba (varios GB) en
#    cada cold start. Lo redirigimos a tu Network Volume (montado en /runpod-volume,
#    igual que ya haces con el CLIP) para que se descargue una sola vez y quede
#    persistido entre ejecuciones.
RUN mkdir -p /comfyui/models && rm -rf /comfyui/models/CogVideo \
    && ln -s /runpod-volume/models/CogVideo /comfyui/models/CogVideo

# 9. Regresamos al directorio principal para que RunPod arranque feliz
WORKDIR /

# 9.5. El handler.py de la imagen base solo recolecta salidas con la clave
#      "images". El nodo VHS_VideoCombine reporta el video bajo la clave
#      "gifs", así que el job terminaba en "success_no_images": corría todo
#      bien pero el mp4 nunca llegaba a la respuesta ni al webhook. Parcheamos
#      el handler para que también procese "gifs" (ver patch_handler.py,
#      debe estar junto a este Dockerfile al hacer el build).
COPY patch_handler.py /patch_handler.py
RUN python3 /patch_handler.py && rm /patch_handler.py

# 10. El symlink de arriba se crea en BUILD TIME, cuando /runpod-volume todavía no
#     existe (el volumen solo se monta cuando el contenedor ya está corriendo).
#     Si la carpeta real /runpod-volume/models/CogVideo nunca se ha creado, Python
#     revienta con "FileExistsError: File exists: '/comfyui/models/CogVideo'" al
#     intentar descargar el modelo (ve el symlink "roto" y no lo puede tratar como
#     directorio). Por eso creamos la carpeta real ANTES de arrancar ComfyUI.
#     La imagen base (runpod/worker-comfyui) solo define CMD ["/start.sh"], sin
#     ENTRYPOINT, así que es seguro sobreescribir el CMD: hacemos el mkdir y
#     luego cedemos el control al start.sh original, sin tocar nada más de cómo
#     arranca el worker.
CMD ["/bin/bash", "-c", "mkdir -p /runpod-volume/models/CogVideo && exec /start.sh"]
