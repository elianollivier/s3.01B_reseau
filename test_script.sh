#!/bin/bash
PASS_COUNT=0
FAIL_COUNT=0


function test_ping() {
  echo -n "[$1 -> ping $2] attendu : $3 ... "
  #c1 -> envoie 1 paquet / W1 -> attend 1 seucond /
  #2>&1 pour meme prendre les messages d'erreur dans output
  output=$(kathara exec $1 -- ping -c1 -W1 $2 2>&1)
  #-q pour ne pas afficher dans la console la ligne
  if echo "$output" | grep -q "1 received"; then
    GREP_RET=0
  else
    GREP_RET=1
  fi
  if [[ "$3" == "ALLOW" && "$GREP_RET" -eq 0 ]]; then
    echo "RÉUSSI (paquet reçu)"
    ((PASS_COUNT++))
  elif [[ "$3" == "DENY" && "$GREP_RET" -ne 0 ]]; then
    echo "RÉUSSI (bloqué)"
    ((PASS_COUNT++))
  else
    echo "ÉCHEC"
    ((FAIL_COUNT++))
  fi
}


function test_nc() {
  echo -n "[$1 -> $2:$3] attendu : $4 ... "
  #-v pour avoir plus de détail /-z juste pour voir si le port est ouvert / -w on attend 3sec d'avoir la réponse
  output=$(kathara exec $1 -- nc -vz -w 3 $2 $3 2>&1)
  if echo "$output" | grep -q "Connection refused"; then
    GOT="ALLOW"
  elif echo "$output" | grep -q "succeeded"; then
    GOT="ALLOW"
  elif echo "$output" | grep -q "open"; then
    GOT="ALLOW"
  elif echo "$output" | grep -q "timed out"; then
    GOT="DENY"
  else
    GOT="DENY"
  fi
  if [[ "$4" == "$GOT" ]]; then
    echo "RÉUSSI ($GOT)"
    ((PASS_COUNT++))
  else
    echo "ÉCHEC (obtenu $GOT, attendu $4)"
    ((FAIL_COUNT++))
  fi
}


function test_ssh() {


  echo -n "[$1 -> ssh $2] attendu : $3 ... "


  output=$(kathara exec "$1" -- ssh -o ConnectTimeout=3 root@"$2" "exit" 2>&1)
 
  if echo "$output" | grep -q "Connection refused"; then
    GOT="ALLOW"
  elif echo "$output" | grep -q "timed out"; then
    GOT="DENY"
  else
    GOT="DENY"
  fi


  if [[ "$GOT" == "$3" ]]; then
    echo "RÉUSSI ($GOT)"
    ((PASS_COUNT++))
  else
    echo "ÉCHEC (obtenu $GOT, attendu $3)"
    ((FAIL_COUNT++))
  fi
}


function test_curl_internet() {
  echo -n "[$1 -> http://216.58.214.14] attendu : $2 ... "
  #-I pour avoir uniquement l'entête de la réponse
  output=$(kathara exec "$1" -- curl -I http://216.58.214.14 2>&1)
  if echo "$output" | grep -q 'HTTP'; then
    GOT="ALLOW"
  else
    GOT="DENY"
  fi
  if [[ "$GOT" == "$2" ]]; then
    echo "RÉUSSI ($GOT)"
    ((PASS_COUNT++))
  else
    echo "ÉCHEC (obtenu $GOT, attendu $2)"
    ((FAIL_COUNT++))
  fi
}


function test_curl_server_s() {
  echo -n "[$1 -> http://$2] attendu : $3 ... "
  #-I pour avoir uniquement l'entête de la réponse
  output=$(kathara exec "$1" -- curl -I http://$2 2>&1)


  if echo "$output" | grep -q "Failed to connect"; then
    GOT="ALLOW"
  elif echo "$output" | grep -q "timed out"; then
    GOT="DENY"
  else
    GOT="DENY"
  fi


  if [[ "$GOT" == "$3" ]]; then
    echo "RÉUSSI ($GOT)"
    ((PASS_COUNT++))
  else
    echo "ÉCHEC (obtenu $GOT, attendu $3)"
    ((FAIL_COUNT++))
  fi
}
#Test sur pc employé


#pour voir ses mails
test_nc "pcaetudiant" "172.16.21.2" "993" "ALLOW"
#pour aller sur le site public
test_nc "pcaetudiant" "172.16.3.28" "80" "ALLOW"
#ne peut pas acceder à la bdd
test_nc "pcaetudiant" "172.16.21.3" "3306" "DENY"


#Test sur la machine d'un admin (ici)


#peut ping n'importe qui (ici pca ec)
test_ping "rssi" "172.16.12.2" "ALLOW"
#peut accéder en ssh à toutes machines (ici pcavisiteur)
test_ssh "rssi" "172.16.22.2" "ALLOW"
#ne peut pas acceder à la bdd (depuis mail)
test_nc "mail" "172.16.21.3" "3306" "DENY"


#Test du serveur S


#peut atteindre aux en sftp
test_nc "s" "172.16.21.4" "22" "ALLOW"
#on peut atteindre S sur le serveur public depuis un autre sous-réseau
test_curl_server_s "pcavisiteur" "172.16.3.28" "ALLOW"
#on ne peut pas ping serveur S depuis une machine hors DSI
test_ping "pcapatient" "172.16.3.28" "DENY"


#Test du routeur qui donne accès à internet


#on test si on a internet depuis le réseau low


test_curl_internet "pcavisiteur" "ALLOW"
#on test si on a internet depuis le réseau education
test_curl_internet "pcaetudiant" "ALLOW"
#on test si on a internet depuis le réseau low
test_curl_internet "pcapsoignant" "ALLOW"




echo
echo "=== RÉSUMÉ DES TESTS ==="
echo "RÉUSSIS : $PASS_COUNT"
echo "ÉCHECS : $FAIL_COUNT"
exit 0







