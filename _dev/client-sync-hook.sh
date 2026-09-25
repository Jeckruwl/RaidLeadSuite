#!/bin/sh
# RLSuite — sync del client dell'utente.
#
# *** SCARTATO DALL'UTENTE (25/09/2026): niente hook, niente script. ***
# Vuole solo "git pull" sulla repo intera. File tenuto come riferimento
# tecnico, NON riproporlo (vedi _dev/handoff.MD, in testa).
#
# PROBLEMA: l'addon vive in Release/RaidLeadSuite/ dentro il repo, ma il gioco
# carica SOLO la cartella AddOns/RaidLeadSuite/ (il .toc deve stare li').
# Git non sa "promuovere" una sottocartella a radice del checkout: non esiste
# nessuna impostazione di remote/source che lo faccia.
#
# SOLUZIONE: questo hook copia il contenuto di Release/RaidLeadSuite nella
# RADICE del clone (che e' la cartella che il gioco carica). Si installa una
# volta sola come .git/hooks/post-merge: da li' in poi basta "git pull".
#
# INSTALLAZIONE (dalla cartella del clone, tipicamente Interface/AddOns/RaidLeadSuite):
#   printf '%s\n' '/*' '!/Release/' '!/_dev/' '!/.gitignore' '!/.gitattributes' '!/README.md' > .git/info/exclude
#   cp /percorso/repo/_dev/client-sync-hook.sh .git/hooks/post-merge
#   chmod +x .git/hooks/post-merge
#   sh .git/hooks/post-merge
#
# (se non hai _dev/ nel clone — con sparse-checkout non c'e' — incolla la
#  versione "printf" del comando che sta in _dev/handoff.MD)

cd "$(git rev-parse --show-toplevel)" || exit 0
SRC=Release/RaidLeadSuite
[ -d "$SRC" ] || exit 0
MANIFEST=.git/rls-synced
# 1) togli i file copiati al giro precedente (compresi quelli rimossi dall'addon)
if [ -f "$MANIFEST" ]; then
    while read -r name; do
        [ -n "$name" ] && rm -rf "./$name"
    done < "$MANIFEST"
fi
: > "$MANIFEST"
# 2) ricopia l'addon nella radice (rm -rf prima di cp -R: evita cartelle annidate)
for item in "$SRC"/*; do
    name=$(basename "$item")
    rm -rf "./$name"
    cp -R "$item" "./$name"
    printf "%s\n" "$name" >> "$MANIFEST"
done
