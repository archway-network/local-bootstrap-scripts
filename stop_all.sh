#!/bin/bash

set -e

function kill_tmux_session() {
  session=$1

#  for name in `tmux list-windows -F '#{window_name}' -t ${session}`; do
#    tmux select-window -t ${name}

    for pane in `tmux list-panes -F '#{pane_id}' -t ${session}`; do
      # send SIGINT to all panes in selected window
      tmux send-keys -t $pane C-c
      echo ${session}:$name.${pane//%}
    done

    for pane in `tmux list-panes -F '#{pane_pid}' -t ${session}`; do
      # terminate pane
      kill -TERM ${pane}
    done

#  done
}

# tmux
sessions=($(tmux ls -F "#{session_name}"))
for session in "${sessions[@]}"; do
  terminate=false
	if [[ $session == node_* ]]; then terminate=true; fi

	if [ "$terminate" = true ]; then
	  echo "-> Stopping ${session} tmux session"
	  kill_tmux_session "${session}"
	fi
done

# Docker
# dvm_containers=$(docker ps --filter "name=dvm_*" --filter "status=running" --filter "status=exited" -q)
# [ ! -z "${dvm_containers}" ] && echo "-> Stopping DVM containers" && docker rm -f ${dvm_containers}
