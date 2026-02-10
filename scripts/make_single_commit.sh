#!/usr/bin/env bash
set -euo pipefail

# 1) Comprueba estado
git status --porcelain
echo "Si hay cambios no confirmados, haz stash o commit antes de continuar."
read -p "Continuar? (y/N) " yn
if [[ "${yn,,}" != "y" ]]; then
  echo "Abortando."
  exit 1
fi

# 2) guarda el nombre de la rama actual y el mensaje del último commit
ORIG_BRANCH=$(git rev-parse --abbrev-ref HEAD)
LAST_MSG=$(git log -1 --pretty=%B)

# 3) asegurarse de que el working tree coincide con el último commit
git reset --hard HEAD

# 4) crea rama huérfana y haz un único commit con el árbol actual
git checkout --orphan temp_single_commit
git reset --hard
git add -A
git commit -m "$LAST_MSG"

# 5) eliminar la rama original localmente y renombrar la nueva a la original
git branch -D "$ORIG_BRANCH"
git branch -m "$ORIG_BRANCH"

# 6) forzar push al remoto (sobrescribe historia remota)
echo "Realizando push forzado. Esto sobrescribirá la rama remota '$ORIG_BRANCH'."
read -p "¿Forzar push al remoto origin/$ORIG_BRANCH? (y/N) " yn2
if [[ "${yn2,,}" == "y" ]]; then
  git push -f origin "$ORIG_BRANCH"
  echo "Push forzado completado."
else
  echo "No se ha realizado el push. Para subir la nueva historia ejecute: git push -f origin $ORIG_BRANCH"
fi

# Nota: si el push es bloqueado por reglas de seguridad (secret scanning), elimina el secreto del historial y rote las credenciales.
