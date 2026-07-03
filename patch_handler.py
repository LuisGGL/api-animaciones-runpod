"""
Parche para /handler.py de la imagen runpod/worker-comfyui.

El handler oficial solo recolecta salidas bajo la clave "images". El nodo
VHS_VideoCombine (ComfyUI-VideoHelperSuite) reporta el video que arma bajo la
clave "gifs" (convencion historica de ese nodo, se usa igual para mp4/webp/gif).
Como el handler no la reconoce, el job termina en "success_no_images" y el
video nunca llega ni en la respuesta ni en el webhook.

Este script modifica /handler.py en build time para tratar "gifs" igual que
"images". Si la imagen base cambia de version y el bloque de codigo esperado
ya no coincide, el build falla explicitamente en vez de fallar en silencio.
"""

path = "/handler.py"

with open(path, "r") as f:
    content = f.read()

old = '''            if "images" in node_output:
                print(
                    f"worker-comfyui - Node {node_id} contains {len(node_output['images'])} image(s)"
                )
                for image_info in node_output["images"]:'''

new = '''            if "images" in node_output or "gifs" in node_output:
                combined_outputs = node_output.get("images", []) + node_output.get("gifs", [])
                print(
                    f"worker-comfyui - Node {node_id} contains {len(combined_outputs)} image(s)/video(s)"
                )
                for image_info in combined_outputs:'''

if old not in content:
    raise SystemExit(
        "patch_handler.py: no se encontro el bloque esperado en /handler.py. "
        "La imagen base runpod/worker-comfyui probablemente cambio de version "
        "y este parche necesita revisarse a mano."
    )

content = content.replace(old, new)
content = content.replace(
    'other_keys = [k for k in node_output.keys() if k != "images"]',
    'other_keys = [k for k in node_output.keys() if k not in ("images", "gifs")]',
)

with open(path, "w") as f:
    f.write(content)

print("handler.py parcheado: ahora tambien procesa salidas 'gifs' (video) de VHS_VideoCombine.")
